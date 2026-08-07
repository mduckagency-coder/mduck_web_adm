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

  Future<void> saveValue(String key, String? value) async {
    final agencyId = await currentAgencyId();
    final existing = await _client.from("app_settings").select("id").eq("agency_id", agencyId).eq("key", key).maybeSingle();
    if (existing != null) {
      await _client.from("app_settings").update({"value": value, "updated_at": DateTime.now().toIso8601String()}).eq("id", existing["id"] as String);
    } else {
      await _client.from("app_settings").insert({"agency_id": agencyId, "key": key, "value": value});
    }
  }

  Future<String> uploadMedia(PlatformFile file) => uploadEventFile(bucket: "app_settings_media", prefix: "setting", file: file);
}
