import "package:supabase_flutter/supabase_flutter.dart";

import "academy_models.dart";

/// Acesso a Academia pelas funcoes do servidor (que ja aplicam publicacao,
/// bloqueios e liberacoes). No painel, [viewAsProfile] / [viewAsAudience]
/// fazem o "Visualizar Academia como".
class AcademyRepository {
  final String? viewAsProfile;
  final String? viewAsAudience;
  const AcademyRepository({this.viewAsProfile, this.viewAsAudience});

  SupabaseClient get _db => Supabase.instance.client;

  Map<String, dynamic> get _viewAs => {"p_profile": viewAsProfile, "p_audience": viewAsAudience};

  Future<AcademyCatalog> fetchCatalog() async {
    final res = await _db.rpc("academy_catalog", params: _viewAs);
    return AcademyCatalog.fromJson(res as Map);
  }

  Future<AcademyLesson?> fetchLesson(String id) async {
    final res = await _db.rpc("academy_lesson", params: {"p_lesson": id, ..._viewAs});
    return res is Map ? AcademyLesson.fromJson(res) : null;
  }

  /// event: open | progress | complete. Gestor visualizando nao grava nada.
  Future<void> track(String lessonId, String event, {double? progress, Map<String, dynamic>? quiz}) async {
    if (viewAsProfile != null || viewAsAudience != null) return;
    try {
      await _db.rpc("academy_track", params: {"p_lesson": lessonId, "p_event": event, "p_progress": progress, "p_quiz": quiz});
    } catch (_) {
      // progresso e "melhor esforco": nao atrapalha a aula
    }
  }

  Future<void> requestAccess(String lessonId) async {
    await _db.rpc("academy_request_access", params: {"p_lesson": lessonId});
  }
}
