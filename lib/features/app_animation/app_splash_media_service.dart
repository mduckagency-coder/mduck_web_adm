import "package:file_picker/file_picker.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "../eventos/event_upload_helpers.dart";

const _videoExtensions = [".mp4", ".mov", ".webm", ".m4v"];

bool splashMediaLooksLikeVideo(String url) {
  final lower = url.toLowerCase().split("?").first;
  return _videoExtensions.any((ext) => lower.endsWith(ext));
}

/// Extensoes aceitas no upload -- curada pra so deixar passar formato que o
/// Flutter decodifica sem plugin extra (mesmo criterio da Ilha Top).
const splashMediaAllowedExtensions = ["mp4", "mov", "webm", "m4v", "gif", "webp", "png", "jpg", "jpeg"];

/// "loading" (Carregamento, toca assim que o app abre) ou "intro"
/// (Introducao, toca logo em seguida).
class AppSplashMediaService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<String> currentAgencyId() async {
    final userId = _client.auth.currentUser!.id;
    final manager = await _client.from("managers").select("agency_id").eq("id", userId).single();
    return manager["agency_id"] as String;
  }

  Future<String> uploadMedia(PlatformFile file) => uploadEventFile(bucket: "island_media", prefix: "splash", file: file);

  Future<List<Map<String, dynamic>>> fetchMedia(String kind) async {
    final agencyId = await currentAgencyId();
    final rows = await _client.from("app_splash_media").select().eq("agency_id", agencyId).eq("kind", kind).order("sort_order");
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<void> saveMedia({
    String? id,
    required String kind,
    required String label,
    required String mediaUrl,
    required String mediaType,
    required String startTime,
    required String endTime,
    required String mode,
    required bool isActive,
    required bool muted,
    required double volume,
    required bool loopVideo,
  }) async {
    final agencyId = await currentAgencyId();
    final data = {
      "agency_id": agencyId,
      "kind": kind,
      "label": label,
      "media_url": mediaUrl,
      "media_type": mediaType,
      "start_time": startTime,
      "end_time": endTime,
      "mode": mode,
      "is_active": isActive,
      "muted": muted,
      "volume": volume,
      "loop_video": loopVideo,
      "updated_at": DateTime.now().toIso8601String(),
    };
    if (id != null) {
      await _client.from("app_splash_media").update(data).eq("id", id);
    } else {
      await _client.from("app_splash_media").insert(data);
    }
  }

  Future<void> deleteMedia(String id) => _client.from("app_splash_media").delete().eq("id", id);
}
