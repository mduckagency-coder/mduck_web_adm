import "dart:typed_data";

import "package:supabase_flutter/supabase_flutter.dart";

import "../../core/upload_optimizer.dart";

/// Configurações do Aplicativo (app_settings 'app_config'): textos, FAQ,
/// suporte, versao e data da ultima atualizacao mostrados no app.
/// E Reportes do Aplicativo (tabela app_reports, separada de bug_reports).
class AppConfigService {
  final _client = Supabase.instance.client;
  String? _agencyId;

  Future<String> _agency() async {
    if (_agencyId != null) return _agencyId!;
    final uid = _client.auth.currentUser!.id;
    final m = await _client.from("managers").select("agency_id").eq("id", uid).single();
    return _agencyId = m["agency_id"] as String;
  }

  /// Padroes do banco + o que ja foi salvo pela agencia.
  Future<Map<String, dynamic>> fetchConfig() async {
    Map<String, dynamic> defaults = {};
    try {
      final d = await _client.rpc("app_config_defaults");
      if (d is Map) defaults = Map<String, dynamic>.from(d);
    } catch (_) {}
    final row = await _client.from("app_settings").select("value").eq("agency_id", await _agency()).eq("key", "app_config").maybeSingle();
    final saved = row?["value"];
    return {...defaults, if (saved is Map) ...Map<String, dynamic>.from(saved)};
  }

  /// Grava so os campos informados, preservando o resto.
  Future<void> saveConfig(Map<String, dynamic> changes) async {
    final agencyId = await _agency();
    final row = await _client.from("app_settings").select("value").eq("agency_id", agencyId).eq("key", "app_config").maybeSingle();
    final current = row?["value"] is Map ? Map<String, dynamic>.from(row!["value"] as Map) : <String, dynamic>{};
    await _client.from("app_settings").upsert(
      {"agency_id": agencyId, "key": "app_config", "value": {...current, ...changes}},
      onConflict: "agency_id,key",
    );
  }

  /// Imagem do texto rico (Sobre a MDuck): bucket publico app_content.
  Future<String?> uploadContentImage(Uint8List bytes, String fileName) async {
    try {
      final ext = fileName.contains(".") ? fileName.split(".").last.toLowerCase() : "jpg";
      final o = optimizeUpload(bytes, ext);
      final path = "${await _agency()}/sobre/${DateTime.now().millisecondsSinceEpoch}.${o.ext}";
      await _client.storage.from("app_content").uploadBinary(path, o.bytes,
          fileOptions: FileOptions(contentType: contentTypeFor(o.ext), cacheControl: longCache));
      return _client.storage.from("app_content").getPublicUrl(path);
    } catch (_) {
      return null;
    }
  }

  // ------------------------------------------------------------------ reportes
  Future<List<Map<String, dynamic>>> fetchReports() async {
    final rows = await _client.from("app_reports").select().eq("agency_id", await _agency()).order("created_at", ascending: false).limit(1000);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  /// [reply] aparece pro streamer em "Meus envios"; [adminNote] e interna.
  Future<void> updateReport(String id, {String? status, String? adminNote, String? reply, bool replyChanged = false}) async {
    await _client.from("app_reports").update({
      "status": ?status,
      "admin_note": ?adminNote,
      if (replyChanged) "reply": (reply ?? "").trim().isEmpty ? null : reply!.trim(),
      if (replyChanged) "replied_at": (reply ?? "").trim().isEmpty ? null : DateTime.now().toUtc().toIso8601String(),
      "handled_by": _client.auth.currentUser?.id,
      "updated_at": DateTime.now().toUtc().toIso8601String(),
    }).eq("id", id);
  }

  Future<String?> screenshotUrl(String path) async {
    try {
      return await _client.storage.from("app_reports").createSignedUrl(path, 60 * 60);
    } catch (_) {
      return null;
    }
  }
}

const appReportTypes = {
  "bug": "Bug ou erro",
  "dados": "Dados incorretos ou desatualizados",
  "imagem_conquista": "Problema com imagem ou conquista",
  "conta": "Problema na conta",
  "sugestao": "Sugestão",
  "outro": "Outro",
};

const appReportStatuses = {
  "novo": "Novo",
  "em_analise": "Em análise",
  "resolvido": "Resolvido",
  "ignorado": "Ignorado",
  "duplicado": "Duplicado",
};
