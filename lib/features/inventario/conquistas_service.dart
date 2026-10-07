import "package:file_picker/file_picker.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "../eventos/event_upload_helpers.dart";

/// Familias / categorias (mesmos nomes do app).
const achievementFamilyLabels = {
  "mensal": "Diamantes (primeira vez de cada marco)",
  "grande_marco": "Meses completos",
  "consistencia": "Constância (meses seguidos)",
  "dias": "Frequência",
  "horas": "Horas acumuladas",
  "merito": "Programa de Mérito",
  "marco": "Marcos da história (desativadas)",
  "primeira": "Primeiros passos (desativadas)",
};

const achievementRuleLabels = {
  "total_diamonds": "Soma histórica de diamantes",
  "month_diamonds": "Diamantes em um único mês",
  "consecutive_months_diamonds": "Meses seguidos acima de X diamantes",
  "month_hours": "Horas de live em um mês",
  "total_hours": "Soma histórica de horas",
  "month_days": "Dias de live em um mês",
  "month_combo": "Diamantes + dias + horas no mesmo mês",
};

/// Icones das conquistas (desenhados no app, dentro da esfera 3D).
const achievementIconLabels = {
  "live": "📡 Live",
  "calendar": "📅 Dias",
  "clock": "⏱ Horas",
  "diamond": "💎 Diamantes",
  "crown": "👑 Coroa",
  "plaque": "🏅 Placa",
  "portal": "🌀 Portal",
  "steps": "📶 Degraus",
  "crystal": "💠 Cristal",
  "crystals": "💠 Cristais",
  "laurel": "🏵 Louros",
  "hourglass": "⏳ Ampulheta",
  "flame": "🔥 Chama",
  "star": "⭐ Estrela",
};

/// Estilos de brasao (desenhados no app; arte propria substitui).
const crestLabels = {
  "prata": "Prata (simples)",
  "cristal": "Cristal (mais brilho)",
  "premium": "Premium (ouro, coroa e louros)",
  "merito": "Mérito (raro: raios, faixa e estrela)",
};

/// Importancia visual dos Marcos do Mes (1..8).
const milestoneImportanceLabels = {
  1: "1 · bonito e comemorativo",
  2: "2 · mais elaborado",
  3: "3 · mais elaborado",
  4: "4 · ESPECIAL (muito chamativo)",
  5: "5 · raro",
  6: "6 · muito especial",
  7: "7 · lendário",
  8: "8 · extremamente especial",
};

/// Inventario no painel (= JORNADA no app): conquistas automaticas, trilha,
/// marcos do mes, artes, brasoes e configuracoes (migrations 0091/0095).
/// O desbloqueio e feito pelo banco; aqui a equipe configura e corrige.
class ConquistasService {
  final SupabaseClient _client = Supabase.instance.client;

  static String? _cachedAgencyId;
  static String? _cachedForUser;

  Future<String> currentAgencyId() async {
    final userId = _client.auth.currentUser!.id;
    if (_cachedAgencyId != null && _cachedForUser == userId) return _cachedAgencyId!;
    final manager = await _client.from("managers").select("agency_id").eq("id", userId).single();
    _cachedForUser = userId;
    return _cachedAgencyId = manager["agency_id"] as String;
  }

  // ---------------------------------------------------------------- conquistas
  Future<List<Map<String, dynamic>>> fetchAchievements() async {
    final agencyId = await currentAgencyId();
    final rows = await _client.from("achievements").select().eq("agency_id", agencyId).order("family").order("sort_order");
    return List<Map<String, dynamic>>.from(rows as List);
  }

  /// achievement_id -> quantos streamers desbloquearam (sem os revogados).
  Future<Map<String, int>> fetchUnlockCounts() async {
    final agencyId = await currentAgencyId();
    final rows = await _client.from("streamer_achievements").select("achievement_id, revoked_at").eq("agency_id", agencyId);
    final counts = <String, int>{};
    for (final r in (rows as List)) {
      if (r["revoked_at"] != null) continue;
      final id = r["achievement_id"] as String;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    return counts;
  }

  Future<List<Map<String, dynamic>>> fetchUnlocks(String achievementId) async {
    final rows = await _client
        .from("streamer_achievements")
        .select("id, streamer_id, unlocked_at, value_at_unlock, period_key, source, revoked_at, revoke_reason, manual_reason, "
            "profiles(display_name, tiktok_username, avatar_url)")
        .eq("achievement_id", achievementId)
        .order("unlocked_at", ascending: false);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  /// Historico de correcoes manuais (calculado x manual, quem, quando, motivo).
  Future<List<Map<String, dynamic>>> fetchAdjustments(String achievementId) async {
    final rows = await _client
        .from("achievement_adjustments")
        .select("action, reason, calculated_value, calculated_unlocked, manual_value, created_at, created_by, profiles(display_name)")
        .eq("achievement_id", achievementId)
        .order("created_at", ascending: false);
    final list = List<Map<String, dynamic>>.from(rows as List);
    // quem alterou (created_by = managers.id, sem FK declarada)
    final ids = {for (final r in list) r["created_by"]}.whereType<String>().toList();
    if (ids.isNotEmpty) {
      final managers = await _client.from("managers").select("id, login_email").inFilter("id", ids);
      final emails = {for (final m in managers as List) m["id"] as String: m["login_email"] as String?};
      for (final r in list) {
        r["by_email"] = emails[r["created_by"]];
      }
    }
    return list;
  }

  Future<List<Map<String, dynamic>>> fetchStreamers() async {
    final agencyId = await currentAgencyId();
    final rows = await _client
        .from("profiles")
        .select("id, display_name, tiktok_username, is_active")
        .eq("agency_id", agencyId)
        .order("display_name");
    return List<Map<String, dynamic>>.from(rows as List);
  }

  /// Correcao manual: "unlock" ou "revoke". Nunca apaga o calculo original.
  Future<void> adjust({
    required String streamerId,
    required String achievementId,
    required String action,
    required String reason,
    double? manualValue,
  }) =>
      _client.rpc("admin_adjust_achievement", params: {
        "p_streamer_id": streamerId,
        "p_achievement_id": achievementId,
        "p_action": action,
        "p_reason": reason,
        "p_manual_value": manualValue,
      });

  Future<Map<String, dynamic>> update(String id, Map<String, dynamic> data) async {
    data["updated_at"] = DateTime.now().toUtc().toIso8601String();
    return await _client.from("achievements").update(data).eq("id", id).select().single();
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> data) async {
    final agencyId = await currentAgencyId();
    return await _client.from("achievements").insert({...data, "agency_id": agencyId}).select().single();
  }

  Future<String> uploadArt(PlatformFile file) => uploadEventFile(bucket: "streamer_inventory", prefix: "conquista", file: file);

  /// Recalcula todos os streamers da agencia (normalmente nao precisa: o
  /// banco recalcula sozinho a cada importacao).
  Future<int> recalculateAll() async {
    final result = await _client.rpc("evaluate_agency_achievements");
    return (result as num?)?.toInt() ?? 0;
  }

  // -------------------------------------------------------------- marcos do mes
  Future<List<Map<String, dynamic>>> fetchMilestones() async {
    final agencyId = await currentAgencyId();
    final rows = await _client.from("monthly_milestones").select().eq("agency_id", agencyId).order("value");
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<void> saveMilestone({String? id, required double value, String? title, required int importance, bool isActive = true}) async {
    final agencyId = await currentAgencyId();
    final data = {
      "agency_id": agencyId,
      "value": value,
      "title": (title ?? "").trim().isEmpty ? null : title!.trim(),
      "importance": importance,
      "is_active": isActive,
      "updated_at": DateTime.now().toUtc().toIso8601String(),
    };
    if (id == null) {
      await _client.from("monthly_milestones").insert(data);
    } else {
      await _client.from("monthly_milestones").update(data).eq("id", id);
    }
  }

  Future<void> deleteMilestone(String id) => _client.from("monthly_milestones").delete().eq("id", id);

  /// Quantos streamers bateram cada marco no mes [period].
  Future<Map<String, int>> fetchMilestoneCounts(String period) async {
    final agencyId = await currentAgencyId();
    final rows = await _client.from("streamer_monthly_milestones").select("milestone_id").eq("agency_id", agencyId).eq("period_key", period);
    final counts = <String, int>{};
    for (final r in (rows as List)) {
      final id = r["milestone_id"] as String;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    return counts;
  }

  // ---------------------------------------------------------- artes dos marcos
  /// milestone_id -> linha da arte no mes [period].
  Future<Map<String, Map<String, dynamic>>> fetchArts(String period) async {
    final agencyId = await currentAgencyId();
    final rows = await _client.from("monthly_milestone_arts").select().eq("agency_id", agencyId).eq("period_key", period);
    return {for (final r in (rows as List)) r["milestone_id"] as String: Map<String, dynamic>.from(r)};
  }

  Future<String> uploadMilestoneArt(PlatformFile file) => uploadEventFile(bucket: "streamer_inventory", prefix: "marco_mes", file: file);

  /// period "classica" = arte padrao do marco (vale todo mes); "AAAA-MM" =
  /// comemorativa daquele mes. slots = areas detectadas (foto e placa).
  Future<void> saveArt({
    required String period,
    required String milestoneId,
    required String imageUrl,
    Map<String, dynamic>? slots,
    String? label,
  }) async {
    final agencyId = await currentAgencyId();
    await _client.from("monthly_milestone_arts").upsert({
      "agency_id": agencyId,
      "period_key": period,
      "milestone_id": milestoneId,
      "image_url": imageUrl,
      "kind": period == "classica" ? "classica" : "comemorativa",
      "label": (label ?? "").trim().isEmpty ? null : label!.trim(),
      "slots": slots,
      "updated_at": DateTime.now().toUtc().toIso8601String(),
    }, onConflict: "agency_id,period_key,milestone_id");
  }

  Future<void> updateArtSlots(String artId, Map<String, dynamic>? slots) =>
      _client.from("monthly_milestone_arts").update({"slots": slots, "updated_at": DateTime.now().toUtc().toIso8601String()}).eq("id", artId);

  Future<void> updateArtLabel(String period, String label) async {
    final agencyId = await currentAgencyId();
    await _client.from("monthly_milestone_arts").update({"label": label.trim().isEmpty ? null : label.trim()}).eq("agency_id", agencyId).eq("period_key", period);
  }

  /// Meses que ja tem arte comemorativa.
  Future<List<String>> fetchSpecialPeriods() async {
    final agencyId = await currentAgencyId();
    final rows = await _client.from("monthly_milestone_arts").select("period_key").eq("agency_id", agencyId).eq("kind", "comemorativa");
    return {for (final r in rows as List) r["period_key"] as String}.toList()..sort();
  }

  /// Conquistas: excluir e reordenar.
  Future<void> deleteAchievement(String id) => _client.from("achievements").delete().eq("id", id);

  Future<void> reorderAchievements(List<String> idsInOrder) async {
    for (var i = 0; i < idsInOrder.length; i++) {
      await _client.from("achievements").update({"sort_order": i + 1}).eq("id", idsInOrder[i]);
    }
  }

  Future<void> deleteArt(String artId) => _client.from("monthly_milestone_arts").delete().eq("id", artId);

  // ------------------------------------------------------------------ brasoes
  Future<List<Map<String, dynamic>>> fetchStages() async {
    final agencyId = await currentAgencyId();
    final rows = await _client.from("journey_stages").select().eq("agency_id", agencyId).order("sort_order");
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<void> updateStage(String id, Map<String, dynamic> data) async {
    data["updated_at"] = DateTime.now().toUtc().toIso8601String();
    await _client.from("journey_stages").update(data).eq("id", id);
  }

  Future<String> uploadCrest(PlatformFile file) => uploadEventFile(bucket: "streamer_inventory", prefix: "brasao", file: file);

  // ------------------------------------------------------------ configuracoes
  Future<Map<String, dynamic>> fetchJourneyConfig() async {
    final agencyId = await currentAgencyId();
    final row = await _client.from("app_settings").select("value").eq("agency_id", agencyId).eq("key", "journey_config").maybeSingle();
    final v = row?["value"];
    return v is Map ? Map<String, dynamic>.from(v) : {"lookback_months": 6, "horizon_value": 80000};
  }

  Future<void> saveJourneyConfig(Map<String, dynamic> config) async {
    final agencyId = await currentAgencyId();
    await _client.from("app_settings").upsert(
      {"agency_id": agencyId, "key": "journey_config", "value": config, "updated_at": DateTime.now().toIso8601String()},
      onConflict: "agency_id,key",
    );
  }
}
