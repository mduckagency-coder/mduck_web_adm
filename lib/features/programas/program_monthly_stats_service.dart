import "package:supabase_flutter/supabase_flutter.dart";
import "program_eligibility_service.dart";
import "participant_extras_service.dart";

const _monthNames = ["Janeiro", "Fevereiro", "Marco", "Abril", "Maio", "Junho", "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"];

String monthLabel(int year, int month) => _monthNames[month - 1] + " de " + year.toString();

class MonthlyGain {
  final num? diamonds;
  final double? hours;
  final int? daysValidated;
  const MonthlyGain({this.diamonds, this.hours, this.daysValidated});
}

Map<String, dynamic>? _closestBefore(List<Map<String, dynamic>> snapshots, DateTime cutoffExclusive) {
  Map<String, dynamic>? best;
  DateTime? bestDate;
  for (final s in snapshots) {
    final date = DateTime.parse(s["snapshot_date"] as String);
    if (!date.isBefore(cutoffExclusive)) continue;
    if (bestDate == null || date.isAfter(bestDate)) {
      best = s;
      bestDate = date;
    }
  }
  return best;
}

/// Calcula o ganho de diamantes/horas/dias validados de cada streamer num
/// mes especifico, a partir dos snapshots diarios (streamer_stat_snapshots,
/// capturados sob demanda -- ensureTodaySnapshot). Compara o snapshot mais
/// proximo do FIM do mes (hoje, se for o mes atual) com o mais proximo do
/// INICIO do mes -- sem snapshot de um dos dois lados (ou sem nenhum
/// snapshot dentro do proprio mes pedido, quando ja passou), o ganho fica
/// null (sem dado ainda, nao vira zero).
Future<Map<String, MonthlyGain>> fetchMonthlyGains({
  required List<String> streamerIds,
  required int year,
  required int month,
}) async {
  if (streamerIds.isEmpty) return {};
  final client = Supabase.instance.client;
  final now = DateTime.now();
  final isCurrentMonth = year == now.year && month == now.month;
  final monthStart = DateTime(year, month, 1);
  final nextMonthStart = DateTime(year, month + 1, 1);
  final endCutoff = isCurrentMonth ? now.add(const Duration(days: 1)) : nextMonthStart;

  final rows = await client
      .from("streamer_stat_snapshots")
      .select("streamer_id, snapshot_date, diamonds, hours_live, days_live")
      .inFilter("streamer_id", streamerIds)
      .lt("snapshot_date", endCutoff.toIso8601String().substring(0, 10))
      .order("snapshot_date");

  final byStreamer = <String, List<Map<String, dynamic>>>{};
  for (final r in (rows as List).cast<Map<String, dynamic>>()) {
    byStreamer.putIfAbsent(r["streamer_id"] as String, () => []).add(r);
  }

  final result = <String, MonthlyGain>{};
  byStreamer.forEach((streamerId, snapshots) {
    final start = _closestBefore(snapshots, monthStart);
    var end = _closestBefore(snapshots, endCutoff);
    // Pra um mes ja fechado, o snapshot de "fim" precisa ter acontecido
    // DENTRO do proprio mes -- senao nao houve visita/snapshot naquele mes
    // e o ganho fica desconhecido, em vez de "0" (o que pareceria "nao fez
    // nada" quando na verdade e "sem dado").
    if (!isCurrentMonth && end != null && DateTime.parse(end["snapshot_date"] as String).isBefore(monthStart)) {
      end = null;
    }
    if (start == null || end == null) {
      result[streamerId] = const MonthlyGain();
      return;
    }
    num? diamonds;
    if (start["diamonds"] != null && end["diamonds"] != null) {
      diamonds = (end["diamonds"] as num) - (start["diamonds"] as num);
      if (diamonds < 0) diamonds = 0;
    }
    double? hours;
    if (start["hours_live"] != null && end["hours_live"] != null) {
      hours = (end["hours_live"] as num).toDouble() - (start["hours_live"] as num).toDouble();
      if (hours < 0) hours = 0;
    }
    int? daysValidated;
    if (start["days_live"] != null && end["days_live"] != null) {
      daysValidated = (end["days_live"] as num).toInt() - (start["days_live"] as num).toInt();
      if (daysValidated < 0) daysValidated = 0;
    }
    result[streamerId] = MonthlyGain(diamonds: diamonds, hours: hours, daysValidated: daysValidated);
  });
  return result;
}

/// Garante o snapshot de hoje e acrescenta os campos mensais (mes
/// selecionado + mes anterior a ele) em cada StreamerSnapshot, quando o
/// criterio usa algum periodo diferente de "total" -- compartilhado entre
/// Visao Geral e Participantes (que antes duplicavam esse bloco cada um por
/// conta propria). Sem nenhuma meta periodica no criterio, retorna os
/// snapshots como vieram (sem custo extra de rede).
Future<List<StreamerSnapshot>> resolveMonthlySnapshots({
  required List<StreamerSnapshot> snapshots,
  required ProgramCriteria criteria,
  required String agencyId,
  required int year,
  required int month,
}) async {
  final needsMonthly = criteria.diamondsPeriod != "total" || criteria.hoursPeriod != "total" || criteria.daysValidatedPeriod != "total";
  if (!needsMonthly || snapshots.isEmpty) return snapshots;

  final streamerIds = snapshots.map((s) => s.id).toList();
  await Future.wait(streamerIds.map((id) async {
    try {
      await ensureTodaySnapshot(streamerId: id, agencyId: agencyId);
    } catch (_) {}
  }));

  final refDate = DateTime(year, month, 1);
  final prevRefDate = DateTime(year, month - 1, 1);
  final currentGains = await fetchMonthlyGains(streamerIds: streamerIds, year: refDate.year, month: refDate.month);
  final previousGains = await fetchMonthlyGains(streamerIds: streamerIds, year: prevRefDate.year, month: prevRefDate.month);

  return snapshots.map((s) {
    final cur = currentGains[s.id];
    final prev = previousGains[s.id];
    return s.copyWithMonthly(
      diamondsThisMonth: cur?.diamonds,
      diamondsLastMonth: prev?.diamonds,
      hoursThisMonth: cur?.hours,
      hoursLastMonth: prev?.hours,
      daysValidatedThisMonth: cur?.daysValidated,
      daysValidatedLastMonth: prev?.daysValidated,
    );
  }).toList();
}
