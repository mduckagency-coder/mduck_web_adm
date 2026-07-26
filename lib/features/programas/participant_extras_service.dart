import "package:supabase_flutter/supabase_flutter.dart";

enum ParticipantTag { destaque, altoPotencial, precisaAcompanhamento, muitoEngajado, premiacaoEspecial }

(String key, String emoji, String label) tagInfo(ParticipantTag t) {
  switch (t) {
    case ParticipantTag.destaque:
      return ("destaque", "\u{2B50}", "Destaque");
    case ParticipantTag.altoPotencial:
      return ("alto_potencial", "\u{1F525}", "Alto potencial");
    case ParticipantTag.precisaAcompanhamento:
      return ("precisa_acompanhamento", "\u{26A0}", "Precisa de acompanhamento");
    case ParticipantTag.muitoEngajado:
      return ("muito_engajado", "\u{2764}", "Muito engajado");
    case ParticipantTag.premiacaoEspecial:
      return ("premiacao_especial", "\u{1F381}", "Premiacao especial");
  }
}

ParticipantTag? tagFromKey(String key) {
  for (final t in ParticipantTag.values) {
    if (tagInfo(t).$1 == key) return t;
  }
  return null;
}

Future<void> setParticipantTags({required String progressId, required List<String> tags}) async {
  await Supabase.instance.client.from("streamer_phase_progress").update({"tags": tags}).eq("id", progressId);
}

Future<void> setPinnedNote({required String progressId, required String? note}) async {
  await Supabase.instance.client.from("streamer_phase_progress").update({"pinned_note": note}).eq("id", progressId);
}

/// Garante que exista um snapshot de hoje pro streamer (idempotente --
/// unique streamer_id+snapshot_date). Chamado sob demanda ao abrir a tela,
/// sem depender de tarefa agendada; com o tempo isso constroi um historico
/// diario suficiente pra comparar semana a semana.
Future<void> ensureTodaySnapshot({required String streamerId, required String agencyId}) async {
  final client = Supabase.instance.client;
  final stats = await client.from("streamer_stats").select("hours_live, diamonds, heart_me, battles").eq("streamer_id", streamerId).maybeSingle();
  if (stats == null) return;
  try {
    await client.from("streamer_stat_snapshots").insert({
      "streamer_id": streamerId,
      "agency_id": agencyId,
      "snapshot_date": DateTime.now().toIso8601String().substring(0, 10),
      "hours_live": stats["hours_live"],
      "diamonds": stats["diamonds"],
      "heart_me": stats["heart_me"],
      "battles": stats["battles"],
    });
  } catch (_) {
    // Ja existe snapshot de hoje -- ignora (unique constraint).
  }
}

class WeekDelta {
  final double? hoursDelta;
  final num? diamondsDelta;
  final num? heartMeDelta;
  const WeekDelta({this.hoursDelta, this.diamondsDelta, this.heartMeDelta});
  bool get isEmpty => hoursDelta == null && diamondsDelta == null && heartMeDelta == null;
}

/// Compara o snapshot mais recente com o mais proximo de 7 dias atras.
/// Sem pelo menos 2 snapshots guardados ainda (agencia/streamer novo no
/// recurso), retorna vazio -- os indicadores simplesmente nao aparecem
/// ainda, sem erro.
Future<WeekDelta> fetchWeekOverWeekDelta({required String streamerId}) async {
  final client = Supabase.instance.client;
  final rows = await client
      .from("streamer_stat_snapshots")
      .select("snapshot_date, hours_live, diamonds, heart_me")
      .eq("streamer_id", streamerId)
      .order("snapshot_date", ascending: false)
      .limit(30);
  final list = (rows as List).cast<Map<String, dynamic>>();
  if (list.length < 2) return const WeekDelta();

  final latest = list.first;
  final targetDate = DateTime.parse(latest["snapshot_date"] as String).subtract(const Duration(days: 7));
  Map<String, dynamic>? closest;
  Duration? closestDiff;
  for (final r in list.skip(1)) {
    final date = DateTime.parse(r["snapshot_date"] as String);
    final diff = date.difference(targetDate).abs();
    if (closestDiff == null || diff < closestDiff) {
      closest = r;
      closestDiff = diff;
    }
  }
  if (closest == null) return const WeekDelta();

  double? hoursDelta;
  if (latest["hours_live"] != null && closest["hours_live"] != null) {
    hoursDelta = (latest["hours_live"] as num).toDouble() - (closest["hours_live"] as num).toDouble();
  }
  num? diamondsDelta;
  if (latest["diamonds"] != null && closest["diamonds"] != null) {
    diamondsDelta = (latest["diamonds"] as num) - (closest["diamonds"] as num);
  }
  num? heartMeDelta;
  if (latest["heart_me"] != null && closest["heart_me"] != null) {
    heartMeDelta = (latest["heart_me"] as num) - (closest["heart_me"] as num);
  }
  return WeekDelta(hoursDelta: hoursDelta, diamondsDelta: diamondsDelta, heartMeDelta: heartMeDelta);
}

/// Filtros salvos da aba Participantes: pessoais do gestor, reutilizaveis em
/// qualquer um dos 6 programas (o conjunto de filtro/ordenacao e o mesmo em
/// todos, so muda quem esta na lista).
Future<List<Map<String, dynamic>>> fetchSavedFilters() async {
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) return const [];
  final rows = await client.from("program_saved_filters").select().eq("manager_id", userId).order("created_at");
  return (rows as List).cast<Map<String, dynamic>>();
}

Future<void> saveFilterPreset({required String name, required String filterKey, required String sortKey, required String searchTerm}) async {
  final client = Supabase.instance.client;
  await client.from("program_saved_filters").insert({
    "manager_id": client.auth.currentUser!.id,
    "name": name,
    "filter_key": filterKey,
    "sort_key": sortKey,
    "search_term": searchTerm.isEmpty ? null : searchTerm,
  });
}

Future<void> deleteSavedFilter(String id) async {
  await Supabase.instance.client.from("program_saved_filters").delete().eq("id", id);
}

/// Preferencia de colunas visiveis na visualizacao em Tabela -- por gestor,
/// reutilizada em qualquer programa. null = mostra todas as colunas.
Future<List<String>?> fetchVisibleColumns() async {
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) return null;
  final row = await client.from("managers").select("participant_table_columns").eq("id", userId).maybeSingle();
  final columns = row?["participant_table_columns"] as List?;
  return columns?.cast<String>();
}

Future<void> setVisibleColumns(List<String> columns) async {
  final client = Supabase.instance.client;
  await client.from("managers").update({"participant_table_columns": columns}).eq("id", client.auth.currentUser!.id);
}
