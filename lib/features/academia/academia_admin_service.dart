import "dart:typed_data";

import "package:supabase_flutter/supabase_flutter.dart";

import "../../core/upload_optimizer.dart";

/// Painel > Academia MDuck: categorias, series, aulas (blocos), solicitacoes,
/// liberacoes manuais e metricas. RLS: gestores da agencia.
class AcademiaAdminService {
  final _db = Supabase.instance.client;
  String? _agency;

  Future<String> agencyId() async {
    if (_agency != null) return _agency!;
    final m = await _db.from("managers").select("agency_id").eq("id", _db.auth.currentUser!.id).single();
    return _agency = m["agency_id"] as String;
  }

  // ------------------------------------------------------------- categorias
  Future<List<Map<String, dynamic>>> fetchCategories() async {
    final rows = await _db.from("academy_categories").select().eq("agency_id", await agencyId()).order("sort_order");
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<void> saveCategory(Map<String, dynamic> c) async {
    final data = {...c}..remove("created_at");
    if (data["id"] == null) {
      data.remove("id");
      await _db.from("academy_categories").insert({...data, "agency_id": await agencyId()});
    } else {
      await _db.from("academy_categories").update(data).eq("id", data["id"]);
    }
  }

  Future<void> deleteCategory(String id) => _db.from("academy_categories").delete().eq("id", id);

  // ----------------------------------------------------------------- series
  Future<List<Map<String, dynamic>>> fetchSeries() async {
    final rows = await _db.from("academy_series").select().eq("agency_id", await agencyId()).order("sort_order");
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<void> saveSeries(Map<String, dynamic> s) async {
    final data = {...s}..remove("created_at");
    if (data["id"] == null) {
      data.remove("id");
      await _db.from("academy_series").insert({...data, "agency_id": await agencyId()});
    } else {
      await _db.from("academy_series").update(data).eq("id", data["id"]);
    }
  }

  Future<void> deleteSeries(String id) => _db.from("academy_series").delete().eq("id", id);

  /// Reordena qualquer tabela da Academia pela lista de ids.
  Future<void> reorder(String table, List<String> ids) async {
    for (var i = 0; i < ids.length; i++) {
      await _db.from(table).update({"sort_order": (i + 1) * 10}).eq("id", ids[i]);
    }
  }

  // ------------------------------------------------------------------ aulas
  Future<List<Map<String, dynamic>>> fetchLessons() async {
    final rows = await _db.from("academy_lessons").select().eq("agency_id", await agencyId()).order("sort_order").order("created_at");
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<Map<String, dynamic>> saveLesson(Map<String, dynamic> l) async {
    final data = {...l}
      ..remove("created_at")
      ..remove("agency_id")
      ..["updated_at"] = DateTime.now().toUtc().toIso8601String();
    if (data["id"] == null) {
      data.remove("id");
      data["created_by"] = _db.auth.currentUser?.id;
      return await _db.from("academy_lessons").insert({...data, "agency_id": await agencyId()}).select().single();
    }
    return await _db.from("academy_lessons").update(data).eq("id", data["id"]).select().single();
  }

  Future<void> updateLessons(List<String> ids, Map<String, dynamic> changes) =>
      _db.from("academy_lessons").update({...changes, "updated_at": DateTime.now().toUtc().toIso8601String()}).inFilter("id", ids);

  Future<void> deleteLesson(String id) => _db.from("academy_lessons").delete().eq("id", id);

  Future<Map<String, dynamic>> duplicateLesson(Map<String, dynamic> l) {
    final copy = {...l}
      ..remove("id")
      ..["slug"] = null
      ..["title"] = "${l["title"]} (cópia)"
      ..["status"] = "rascunho"
      ..["featured"] = false;
    return saveLesson(copy);
  }

  // ------------------------------------------------------------- streamers
  Future<List<Map<String, dynamic>>> fetchStreamers() async {
    final rows = await _db
        .from("profiles")
        .select("id, display_name, tiktok_username, is_active")
        .eq("agency_id", await agencyId())
        .order("display_name");
    return List<Map<String, dynamic>>.from(rows as List);
  }

  // ------------------------------------------------- liberacoes manuais
  Future<List<Map<String, dynamic>>> fetchGrants(String lessonId) async {
    final rows = await _db.from("academy_access_grants").select("profile_id, created_at").eq("lesson_id", lessonId);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<void> grant(String lessonId, String profileId) => _db
      .from("academy_access_grants")
      .upsert({"lesson_id": lessonId, "profile_id": profileId, "granted_by": _db.auth.currentUser?.id}, onConflict: "lesson_id,profile_id");

  Future<void> revoke(String lessonId, String profileId) =>
      _db.from("academy_access_grants").delete().eq("lesson_id", lessonId).eq("profile_id", profileId);

  // ---------------------------------------------------------- solicitacoes
  Future<List<Map<String, dynamic>>> fetchRequests() async {
    final rows = await _db
        .from("academy_access_requests")
        .select("*, lesson:academy_lessons(id, title, category_id), profile:profiles(id, display_name, tiktok_username)")
        .eq("agency_id", await agencyId())
        .order("created_at", ascending: false)
        .limit(500);
    final list = List<Map<String, dynamic>>.from(rows as List);
    final ids = {for (final r in list) if (r["handled_by"] != null) r["handled_by"] as String};
    if (ids.isNotEmpty) {
      final mgrs = await _db.from("managers").select("id, full_name, login_email").inFilter("id", ids.toList());
      final names = {for (final m in mgrs as List) m["id"]: (m["full_name"] ?? m["login_email"] ?? "") as String};
      for (final r in list) {
        r["handled_by_name"] = names[r["handled_by"]];
      }
    }
    return list;
  }

  Future<void> handleRequest(String id, String status, String? note) =>
      _db.rpc("academy_handle_request", params: {"p_request": id, "p_status": status, "p_note": note});

  // --------------------------------------------------------------- metricas
  Future<Map<String, dynamic>> metrics() async {
    final res = await _db.rpc("academy_metrics");
    return Map<String, dynamic>.from(res as Map);
  }

  // --------------------------------------------------------------- arquivos
  /// Imagem/video da Academia, otimizado antes de subir (ver
  /// core/upload_optimizer.dart). Lanca [UploadTooLarge] com a explicacao
  /// quando o video e grande demais para o app.
  Future<String?> upload(Uint8List bytes, String fileName) async {
    final ext = fileName.contains(".") ? fileName.split(".").last.toLowerCase() : "jpg";
    final o = optimizeUpload(bytes, ext);
    try {
      final path = "${await agencyId()}/${DateTime.now().millisecondsSinceEpoch}.${o.ext}";
      await _db.storage.from("academy").uploadBinary(path, o.bytes,
          fileOptions: FileOptions(contentType: contentTypeFor(o.ext), cacheControl: longCache));
      return _db.storage.from("academy").getPublicUrl(path);
    } catch (_) {
      return null;
    }
  }
}

const academyThemes = {
  "fundamentos": "🦆 Fundamentos (MDuck limpo)",
  "batalhas": "⚔️ Batalhas (energético)",
  "games": "🎮 Games (tecnológico)",
  "musica": "🎤 Música (artístico)",
  "engajamento": "💬 Engajamento (comunidade)",
  "todos": "⭐ Para todo streamer",
  "recursos": "🧰 Recursos",
  "seguranca": "🛡️ Segurança",
  "exclusivo": "💜 Exclusivo MDuck",
};

const academyAvailability = {
  "disponivel": "🟢 Disponível",
  "bloqueado": "🔒 Bloqueado",
  "solicitacao": "📨 Solicitação necessária",
  "em_breve": "👁️ Em breve",
};

const academyStatus = {
  "rascunho": "Rascunho",
  "revisao": "Em revisão",
  "publicado": "Publicado",
};

const academyInfoStatus = {
  "atual": "✅ Informação atual",
  "revisar": "🔎 Revisar",
  "desatualizado": "⚠️ Desatualizada",
};
