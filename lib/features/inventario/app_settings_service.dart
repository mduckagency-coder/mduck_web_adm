import "package:file_picker/file_picker.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "../eventos/event_upload_helpers.dart";

/// Configuracoes de tela do app (chave-valor por agencia), ex: video/imagem
/// do mascote no banner do Inventario. Mesma tabela "app_settings" que ja e
/// lida por mduck_lives para default_days_target/default_hours_target.
class AppSettingsService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<String> currentAgencyId() async {
    final userId = _client.auth.currentUser!.id;
    final manager = await _client.from("managers").select("agency_id").eq("id", userId).single();
    return manager["agency_id"] as String;
  }

  Future<String?> fetchValue(String key) async {
    final agencyId = await currentAgencyId();
    final row = await _client.from("app_settings").select("id, value").eq("agency_id", agencyId).eq("key", key).maybeSingle();
    if (row == null) return null;
    return row["value"] as String?;
  }

  Future<void> saveValue(String key, String? value) => _saveRaw(key, value);

  Future<Map<String, dynamic>?> fetchJson(String key) async {
    final agencyId = await currentAgencyId();
    final row = await _client.from("app_settings").select("id, value").eq("agency_id", agencyId).eq("key", key).maybeSingle();
    if (row == null) return null;
    final value = row["value"];
    return value is Map<String, dynamic> ? value : null;
  }

  Future<void> saveJson(String key, Map<String, dynamic> value) => _saveRaw(key, value);

  /// Upsert atomico (precisa da constraint unique(agency_id,key) da
  /// migration 0070) -- evita a corrida do padrao antigo "select -> insert
  /// ou update", que quebrava com PGRST116 (multiplas linhas) se duas telas
  /// salvassem a mesma chave quase ao mesmo tempo.
  Future<void> _saveRaw(String key, dynamic value) async {
    final agencyId = await currentAgencyId();
    await _client.from("app_settings").upsert(
      {"agency_id": agencyId, "key": key, "value": value, "updated_at": DateTime.now().toIso8601String()},
      onConflict: "agency_id,key",
    );
  }

  Future<String> uploadMedia(PlatformFile file) => uploadEventFile(bucket: "app_settings_media", prefix: "setting", file: file);
}
