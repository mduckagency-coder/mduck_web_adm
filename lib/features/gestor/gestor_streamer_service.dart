import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "../recruiter/recruiter_streamers_page.dart" show computeStreamerStatus;
import "streamer_tasks_service.dart";

/// Uma linha da lista de streamers do CRM (Novatos, e depois Streamers) --
/// junta o que ja existe espalhado (profiles/streamer_stats, o mesmo status
/// calculado que gestor_my_streamers_page.dart ja usa) com o que e novo
/// desta fase (potencial global, ultimo acompanhamento, proxima acao).
///
/// Nao reaproveita StreamerSnapshot (program_eligibility_service.dart)
/// porque aquela classe foi desenhada pro motor de elegibilidade dos
/// Programas de Desenvolvimento (sem nick/gestor/potencial/proxima acao,
/// que sao exatamente os campos que faltam aqui) -- estender ela so pra
/// caber neste uso diferente arriscaria quebrar o calculo de elegibilidade
/// que ja depende da forma atual dela.
class GestorStreamerRow {
  final String id;
  final String displayName;
  final String? tiktokUsername;
  final String? tiktokCreatorId;
  final String? avatarUrl;
  final String? categoryName;
  final DateTime joinedAt;
  final DateTime? lastLiveAt;
  final bool isActive;
  final bool hasOnboarding;
  final num diamonds;
  final num? diamondsLastMonth;
  final int daysLive;
  final double hoursLive;
  final String? potentialLevel;
  final String? assignedManagerId;
  final String? assignedManagerEmail;
  final DateTime? lastContactAt;
  final StreamerTask? nextAction;

  const GestorStreamerRow({
    required this.id,
    required this.displayName,
    this.tiktokUsername,
    this.tiktokCreatorId,
    this.avatarUrl,
    this.categoryName,
    required this.joinedAt,
    this.lastLiveAt,
    required this.isActive,
    required this.hasOnboarding,
    required this.diamonds,
    this.diamondsLastMonth,
    required this.daysLive,
    required this.hoursLive,
    this.potentialLevel,
    this.assignedManagerId,
    this.assignedManagerEmail,
    this.lastContactAt,
    this.nextAction,
  });

  String get nick => tiktokUsername ?? tiktokCreatorId ?? "-";
  int get daysInAgency => DateTime.now().difference(joinedAt).inDays;

  /// Crescimento = diamantes deste mes menos o mes anterior fechado (mesma
  /// fonte -- monthly_stats -- ja usada em Metricas Streamers/Programas).
  /// Sem mes anterior fechado ainda pro streamer, retorna 0 (nao dá pra
  /// comparar, mas nao deve quebrar a ordenacao).
  num get growth =>
      diamondsLastMonth != null ? diamonds - diamondsLastMonth! : 0;

  int get daysSinceLastContact => lastContactAt != null
      ? DateTime.now().difference(lastContactAt!).inDays
      : 1 << 30;

  (String, Color, String) get status => computeStreamerStatus({
    "hasOnboarding": hasOnboarding,
    "is_active": isActive,
    "last_live_at": lastLiveAt?.toIso8601String(),
  });
}

const _potentialLabels = {"alto": "Alto", "medio": "Médio", "baixo": "Baixo"};

String potentialLabel(String? level) =>
    _potentialLabels[level] ?? "Não avaliado";

Color potentialColor(String? level) {
  switch (level) {
    case "alto":
      return Colors.greenAccent;
    case "medio":
      return Colors.amber;
    case "baixo":
      return Colors.redAccent;
    default:
      return Colors.white38;
  }
}

/// Busca todos os streamers ativos da agencia com tudo que as listas do CRM
/// precisam, num numero fixo e pequeno de consultas (independente de quantos
/// streamers existam) -- mesmo padrao de "junta em memoria" ja usado em
/// gestor_my_streamers_page.dart pro hasOnboarding.
Future<List<GestorStreamerRow>> fetchGestorStreamerRows({
  required String agencyId,
}) async {
  final client = Supabase.instance.client;
  final rows = await client
      .from("profiles")
      .select(
        "id, display_name, tiktok_username, tiktok_creator_id, avatar_url, joined_at, last_live_at, is_active, assigned_manager_id, potential_level, streamer_categories(name), managers!profiles_assigned_manager_id_fkey(login_email), streamer_stats(days_live, hours_live, diamonds)",
      )
      .eq("agency_id", agencyId)
      .eq("is_active", true);
  final list = (rows as List).cast<Map<String, dynamic>>();
  if (list.isEmpty) return [];

  final ids = list.map((r) => r["id"] as String).toList();

  final onboardingRows = await client
      .from("onboarding")
      .select("streamer_id")
      .inFilter("streamer_id", ids);
  final onboardingSet = (onboardingRows as List)
      .map((o) => o["streamer_id"] as String)
      .toSet();

  final contactRows = await client
      .from("streamer_contact_logs")
      .select("streamer_id, created_at")
      .inFilter("streamer_id", ids)
      .order("created_at", ascending: false);
  final lastContactByStreamer = <String, DateTime>{};
  for (final r in (contactRows as List).cast<Map<String, dynamic>>()) {
    final sid = r["streamer_id"] as String;
    // A consulta ja vem ordenada do mais recente pro mais antigo -- o
    // primeiro valor visto por streamer_id ja e o ultimo acompanhamento.
    lastContactByStreamer.putIfAbsent(
      sid,
      () => DateTime.parse(r["created_at"] as String),
    );
  }

  final nextActionByStreamer = await fetchNextActionByStreamerIds(ids);

  // Mes anterior fechado, mesma fonte (monthly_stats) que Metricas
  // Streamers/Programas ja usam pra "Ver mes passado" -- da o numero pra
  // calcular crescimento sem depender de snapshot diario nenhum.
  final now = DateTime.now();
  final prevMonth = now.month == 1 ? 12 : now.month - 1;
  final prevYear = now.month == 1 ? now.year - 1 : now.year;
  final prevPeriodKey =
      prevYear.toString() + "-" + prevMonth.toString().padLeft(2, "0");
  final monthlyRows = await client
      .from("monthly_stats")
      .select("streamer_id, diamonds")
      .eq("period_key", prevPeriodKey)
      .inFilter("streamer_id", ids);
  final lastMonthByStreamer = {
    for (final r in (monthlyRows as List).cast<Map<String, dynamic>>())
      r["streamer_id"] as String: r["diamonds"] as num?,
  };

  return list.map((r) {
    final id = r["id"] as String;
    final catData = r["streamer_categories"];
    final managerData = r["managers"];
    final statsData = r["streamer_stats"];
    Map<String, dynamic>? stats;
    if (statsData is List && statsData.isNotEmpty) {
      stats = statsData.first as Map<String, dynamic>;
    } else if (statsData is Map) {
      stats = statsData as Map<String, dynamic>;
    }
    return GestorStreamerRow(
      id: id,
      displayName: r["display_name"] as String? ?? "-",
      tiktokUsername: r["tiktok_username"] as String?,
      tiktokCreatorId: r["tiktok_creator_id"] as String?,
      avatarUrl: r["avatar_url"] as String?,
      categoryName: catData is Map ? catData["name"] as String? : null,
      joinedAt: DateTime.parse(r["joined_at"] as String),
      lastLiveAt: r["last_live_at"] != null
          ? DateTime.parse(r["last_live_at"] as String)
          : null,
      isActive: r["is_active"] == true,
      hasOnboarding: onboardingSet.contains(id),
      diamonds: (stats?["diamonds"] as num?) ?? 0,
      diamondsLastMonth: lastMonthByStreamer[id],
      daysLive: (stats?["days_live"] as num?)?.toInt() ?? 0,
      hoursLive: (stats?["hours_live"] as num?)?.toDouble() ?? 0,
      potentialLevel: r["potential_level"] as String?,
      assignedManagerId: r["assigned_manager_id"] as String?,
      assignedManagerEmail: managerData is Map
          ? managerData["login_email"] as String?
          : null,
      lastContactAt: lastContactByStreamer[id],
      nextAction: nextActionByStreamer[id],
    );
  }).toList();
}

Future<void> updateStreamerPotential({
  required String streamerId,
  required String? level,
}) async {
  await Supabase.instance.client
      .from("profiles")
      .update({"potential_level": level})
      .eq("id", streamerId);
}
