import "package:file_picker/file_picker.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "../eventos/event_upload_helpers.dart";
import "models/max_lesson.dart";

/// Camada unica de acesso as aulas do botao MAX do aplicativo.
class MaxLessonsService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<String> currentAgencyId() async {
    final userId = _client.auth.currentUser!.id;
    final manager = await _client.from("managers").select("agency_id").eq("id", userId).single();
    return manager["agency_id"] as String;
  }

  Future<List<MaxLesson>> fetchLessons() async {
    final agencyId = await currentAgencyId();
    final rows = await _client.from("max_lessons").select().eq("agency_id", agencyId).order("created_at", ascending: false);
    return (rows as List).map((r) => MaxLesson.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<String> uploadCoverImage(PlatformFile file) => uploadEventFile(bucket: "max_lessons", prefix: "cover", file: file);

  Future<String> uploadVideoFile(PlatformFile file) => uploadEventFile(bucket: "max_lessons", prefix: "video", file: file);

  Future<void> saveLesson({
    String? id,
    required String title,
    String? description,
    required MaxLessonCategory category,
    required MaxLessonLevel level,
    required String coverImageUrl,
    required MaxLessonVideoSource videoSource,
    required String videoUrl,
    bool isActive = true,
  }) async {
    if (id != null) {
      await _client.from("max_lessons").update({
        "title": title,
        "description": description,
        "category": maxLessonCategoryToDb(category),
        "level": maxLessonLevelToDb(level),
        "cover_image_url": coverImageUrl,
        "video_source": maxLessonVideoSourceToDb(videoSource),
        "video_url": videoUrl,
        "is_active": isActive,
        "updated_at": DateTime.now().toIso8601String(),
      }).eq("id", id);
      return;
    }
    final agencyId = await currentAgencyId();
    final userId = _client.auth.currentUser!.id;
    await _client.from("max_lessons").insert({
      "agency_id": agencyId,
      "title": title,
      "description": description,
      "category": maxLessonCategoryToDb(category),
      "level": maxLessonLevelToDb(level),
      "cover_image_url": coverImageUrl,
      "video_source": maxLessonVideoSourceToDb(videoSource),
      "video_url": videoUrl,
      "is_active": isActive,
      "created_by": userId,
    });
  }

  Future<void> setActive(String id, bool isActive) async {
    await _client.from("max_lessons").update({"is_active": isActive}).eq("id", id);
  }

  Future<void> deleteLesson(String id) async {
    await _client.from("max_lessons").delete().eq("id", id);
  }
}
