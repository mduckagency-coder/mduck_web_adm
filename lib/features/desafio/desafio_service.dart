import "package:supabase_flutter/supabase_flutter.dart";

/// Categorias sugeridas pras dicas (opcional no cadastro).
const desafioTipCategories = [
  "Interação",
  "Início de live",
  "Retenção",
  "Conteúdo",
  "Chat",
  "Presentes",
  "Comunidade",
  "Engajamento",
  "Estratégia",
];

/// Resumo da Visao geral.
class DesafioOverview {
  final int activeGames;
  final int totalGames;
  final int activeTips;
  final int totalTips;
  final int plays;
  final int players;
  final DateTime? lastUpdate;

  const DesafioOverview({
    required this.activeGames,
    required this.totalGames,
    required this.activeTips,
    required this.totalTips,
    required this.plays,
    required this.players,
    this.lastUpdate,
  });
}

/// Desafio (dado da Home do app): jogos (challenge_games), dicas
/// (challenge_tips) e partidas (challenge_plays) -- migration 0088.
class DesafioService {
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

  String get _now => DateTime.now().toUtc().toIso8601String();

  // ---------------- jogos ----------------

  Future<List<Map<String, dynamic>>> fetchGames() async {
    final agencyId = await currentAgencyId();
    final rows = await _client.from("challenge_games").select().eq("agency_id", agencyId).order("sort_order");
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<Map<String, dynamic>> updateGame(String id, {String? name, String? description, bool? isActive}) async {
    final data = <String, dynamic>{"updated_at": _now};
    if (name != null) data["name"] = name.trim();
    if (description != null) data["description"] = description.trim().isEmpty ? null : description.trim();
    if (isActive != null) data["is_active"] = isActive;
    return await _client.from("challenge_games").update(data).eq("id", id).select().single();
  }

  // ---------------- dicas ----------------

  Future<List<Map<String, dynamic>>> fetchTips() async {
    final agencyId = await currentAgencyId();
    final rows = await _client.from("challenge_tips").select().eq("agency_id", agencyId).order("created_at", ascending: false);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<Map<String, dynamic>> saveTip({String? id, required String text, String? category, required bool isActive}) async {
    final agencyId = await currentAgencyId();
    final data = {
      "agency_id": agencyId,
      "text": text.trim(),
      "category": category == null || category.trim().isEmpty ? null : category.trim(),
      "is_active": isActive,
      "updated_at": _now,
    };
    if (id != null) {
      return await _client.from("challenge_tips").update(data).eq("id", id).select().single();
    }
    return await _client.from("challenge_tips").insert(data).select().single();
  }

  Future<void> setTipActive(String id, bool active) =>
      _client.from("challenge_tips").update({"is_active": active, "updated_at": _now}).eq("id", id);

  Future<void> deleteTip(String id) => _client.from("challenge_tips").delete().eq("id", id);

  // ---------------- visao geral ----------------

  Future<DesafioOverview> fetchOverview() async {
    final agencyId = await currentAgencyId();
    final gamesFuture = fetchGames();
    final tipsFuture = fetchTips();
    final plays = await _client.from("challenge_plays").select("streamer_id").eq("agency_id", agencyId);
    final games = await gamesFuture;
    final tips = await tipsFuture;

    DateTime? last;
    for (final row in [...games, ...tips]) {
      final d = DateTime.tryParse(row["updated_at"] as String? ?? "");
      if (d != null && (last == null || d.isAfter(last))) last = d;
    }
    return DesafioOverview(
      activeGames: games.where((g) => g["is_active"] == true).length,
      totalGames: games.length,
      activeTips: tips.where((t) => t["is_active"] == true).length,
      totalTips: tips.length,
      plays: plays.length,
      players: plays.map((p) => p["streamer_id"]).toSet().length,
      lastUpdate: last?.toLocal(),
    );
  }
}
