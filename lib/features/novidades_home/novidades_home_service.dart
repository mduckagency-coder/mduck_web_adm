import "package:file_picker/file_picker.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "../eventos/event_upload_helpers.dart";

/// Publico de uma novidade (mesmo formato das Missoes APP).
const newsTargetAll = "all";
const newsTargetGroup = "group";
const newsTargetIndividual = "individual";

const newsImageExtensions = ["png", "jpg", "jpeg", "webp", "gif"];

/// Uma opcao de publico (grupo ou streamer) pros seletores do formulario.
class NewsAudienceOption {
  final String id;
  final String name;
  const NewsAudienceOption(this.id, this.name);
}

/// Novidades Home (tabela agency_news, migration 0087): cadastro e historico
/// completo pro painel. O app le pelas funcoes app_news_for_me /
/// app_mark_news_read.
class NovidadesHomeService {
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

  Future<String> uploadImage(PlatformFile file) => uploadEventFile(bucket: "island_media", prefix: "news", file: file);

  /// Historico completo (nunca apaga), mais recente primeiro.
  Future<List<Map<String, dynamic>>> fetchAll() async {
    final agencyId = await currentAgencyId();
    final rows = await _client
        .from("agency_news")
        .select()
        .eq("agency_id", agencyId)
        .order("published_at", ascending: false);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  /// Quantos streamers ja leram cada novidade (id -> total).
  Future<Map<String, int>> fetchReadCounts() async {
    final rows = await _client.from("agency_news_reads").select("news_id");
    final counts = <String, int>{};
    for (final r in (rows as List)) {
      final id = r["news_id"] as String;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    return counts;
  }

  Future<List<NewsAudienceOption>> fetchGroups() async {
    final rows = await _client.from("groups").select("id, name").order("name");
    return [for (final r in (rows as List)) NewsAudienceOption(r["id"] as String, r["name"] as String? ?? "Grupo")];
  }

  Future<List<NewsAudienceOption>> fetchStreamers() async {
    final agencyId = await currentAgencyId();
    final rows = await _client
        .from("profiles")
        .select("id, display_name")
        .eq("agency_id", agencyId)
        .eq("is_active", true)
        .order("display_name");
    return [for (final r in (rows as List)) NewsAudienceOption(r["id"] as String, r["display_name"] as String? ?? "Streamer")];
  }

  /// Cria ou edita (quando [id] vem preenchido). Devolve a linha salva.
  Future<Map<String, dynamic>> save({
    String? id,
    required String title,
    required String body,
    String? imageUrl,
    String? linkUrl,
    String? linkLabel,
    required DateTime publishedAt,
    DateTime? expiresAt,
    required bool isActive,
    required String targetType,
    String? targetId,
  }) async {
    final agencyId = await currentAgencyId();
    String? clean(String? v) => v == null || v.trim().isEmpty ? null : v.trim();
    final data = {
      "agency_id": agencyId,
      "title": title.trim(),
      "body": body.trim(),
      "image_url": clean(imageUrl),
      "link_url": clean(linkUrl),
      "link_label": clean(linkLabel),
      "published_at": publishedAt.toUtc().toIso8601String(),
      "expires_at": expiresAt?.toUtc().toIso8601String(),
      "is_active": isActive,
      "target_type": targetType,
      "target_id": targetType == newsTargetAll ? null : targetId,
      "updated_at": DateTime.now().toUtc().toIso8601String(),
    };
    if (id != null) {
      return await _client.from("agency_news").update(data).eq("id", id).select().single();
    }
    data["created_by"] = _client.auth.currentUser!.id;
    return await _client.from("agency_news").insert(data).select().single();
  }

  Future<void> setActive(String id, bool active) => _client
      .from("agency_news")
      .update({"is_active": active, "updated_at": DateTime.now().toUtc().toIso8601String()}).eq("id", id);
}
