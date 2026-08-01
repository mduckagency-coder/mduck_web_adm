import "package:supabase_flutter/supabase_flutter.dart";
import "program_eligibility_service.dart";

const _monthNames = [
  "Janeiro",
  "Fevereiro",
  "Marco",
  "Abril",
  "Maio",
  "Junho",
  "Julho",
  "Agosto",
  "Setembro",
  "Outubro",
  "Novembro",
  "Dezembro",
];

String monthLabel(int year, int month) =>
    _monthNames[month - 1] + " de " + year.toString();

String _periodKey(int year, int month) =>
    year.toString() + "-" + month.toString().padLeft(2, "0");

/// Preenche diamondsThisMonth/diamondsLastMonth (e os equivalentes de horas/
/// dias validados) direto das tabelas ja confiaveis do resto do app --
/// streamer_stats pro mes atual (mesmo numero corrente que "total" ja usa) e
/// monthly_stats pro mes anterior (fechado pela importacao da planilha
/// mensal -- mesma fonte que a aba Metricas Streamers usa em "Ver mes
/// passado"). Sem calculo de delta, sem depender de snapshot diario nenhum:
/// antes disso comparava snapshots capturados sob demanda em
/// streamer_stat_snapshots, que só existem se alguem abrir a tela todo santo
/// dia -- com gaps, o "ganho" podia abranger varios meses sem se dar conta.
Future<List<StreamerSnapshot>> resolveMonthlySnapshots({
  required List<StreamerSnapshot> snapshots,
  required ProgramCriteria criteria,
  required String agencyId,
  required int year,
  required int month,
}) async {
  final needsMonthly =
      criteria.diamondsPeriod != "total" ||
      criteria.hoursPeriod != "total" ||
      criteria.daysValidatedPeriod != "total";
  if (!needsMonthly || snapshots.isEmpty) return snapshots;

  final prevMonth = month == 1 ? 12 : month - 1;
  final prevYear = month == 1 ? year - 1 : year;
  final prevPeriodKey = _periodKey(prevYear, prevMonth);

  final client = Supabase.instance.client;
  final streamerIds = snapshots.map((s) => s.id).toList();
  final rows = await client
      .from("monthly_stats")
      .select("streamer_id, diamonds, hours_live, days_live")
      .eq("period_key", prevPeriodKey)
      .inFilter("streamer_id", streamerIds);
  final lastMonthByStreamer = {
    for (final r in (rows as List).cast<Map<String, dynamic>>())
      r["streamer_id"] as String: r,
  };

  return snapshots.map((s) {
    final last = lastMonthByStreamer[s.id];
    return s.copyWithMonthly(
      diamondsThisMonth: s.diamonds,
      diamondsLastMonth: last?["diamonds"] as num?,
      hoursThisMonth: s.hoursLive,
      hoursLastMonth: (last?["hours_live"] as num?)?.toDouble(),
      daysValidatedThisMonth: s.daysValidated,
      daysValidatedLastMonth: (last?["days_live"] as num?)?.toInt(),
    );
  }).toList();
}
