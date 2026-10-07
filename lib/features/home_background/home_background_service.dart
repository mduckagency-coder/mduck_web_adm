import "package:file_picker/file_picker.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "../eventos/event_upload_helpers.dart";

/// Extensoes aceitas pros videos de fundo da Home -- so o que o Flutter do
/// app toca sem plugin extra (mesmo criterio da Ilha Top / Carregamento).
const homeBackgroundAllowedExtensions = ["mp4", "mov", "webm", "m4v"];

/// Extensoes aceitas pro audio padrao da Home.
const homeAudioAllowedExtensions = ["mp3", "m4a", "aac", "wav", "ogg"];

/// Chave em app_settings onde fica o audio padrao: {"url": ..., "volume": 0..1}.
const homeDefaultAudioKey = "home_default_audio";

/// Faixas de horario prontas pra agilizar o cadastro (o admin ainda pode
/// escolher qualquer horario manualmente).
const homePeriodPresets = [
  (emoji: "🌙", label: "Madrugada", start: "00:00", end: "05:59"),
  (emoji: "🌅", label: "Manhã", start: "06:00", end: "11:59"),
  (emoji: "☀️", label: "Tarde", start: "12:00", end: "17:59"),
  (emoji: "🌆", label: "Noite", start: "18:00", end: "23:59"),
];

/// Faixas sugeridas pros videos de inatividade (ilha sem o pato): so dia e
/// noite.
const homeInactivityPresets = [
  (emoji: "☀️", label: "Dia", start: "06:00", end: "17:59"),
  (emoji: "🌙", label: "Noite", start: "18:00", end: "05:59"),
];

/// Categoria do video: programacao normal ou estado de inatividade (streamer
/// ha mais de 7 dias sem live -- decidido em home_pick_background, 0085).
const homeCategoryNormal = "normal";
const homeCategoryInactivity = "inactivity";

/// Chave em app_settings do liga/desliga da Inatividade (true/false).
const homeInactivityEnabledKey = "home_inactivity_enabled";

/// Texto sugerido pro aviso dos videos de inatividade.
const homeInactivityDefaultText = "Max está longe da ilha, esperando você voltar.\nFaça uma live para trazê-lo de volta.";

/// Videos de fundo da Home do app (tabela home_backgrounds) + audio padrao.
/// O app escolhe o video pela funcao home_pick_background (migration 0084).
class HomeBackgroundService {
  final SupabaseClient _client = Supabase.instance.client;

  // Agencia do gestor logado: muda so se trocar de conta, entao busca uma
  // vez e reaproveita (cada tela fazia essa consulta a mais toda hora).
  static String? _cachedAgencyId;
  static String? _cachedForUser;

  Future<String> currentAgencyId() async {
    final userId = _client.auth.currentUser!.id;
    if (_cachedAgencyId != null && _cachedForUser == userId) return _cachedAgencyId!;
    final manager = await _client.from("managers").select("agency_id").eq("id", userId).single();
    _cachedForUser = userId;
    return _cachedAgencyId = manager["agency_id"] as String;
  }

  Future<String> uploadVideo(PlatformFile file) => uploadEventFile(bucket: "island_media", prefix: "home_bg", file: file);

  Future<String> uploadAudio(PlatformFile file) => uploadEventFile(bucket: "island_media", prefix: "home_audio", file: file);

  Future<List<Map<String, dynamic>>> fetchAll() async {
    final agencyId = await currentAgencyId();
    final rows = await _client
        .from("home_backgrounds")
        .select()
        .eq("agency_id", agencyId)
        .order("start_time")
        .order("sort_order")
        .order("created_at");
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Map<String, dynamic> _row({
    required String agencyId,
    required String label,
    required String mediaUrl,
    required String startTime,
    required String endTime,
    required String mode,
    required String audioMode,
    required double volume,
    required bool isActive,
    required String category,
    String? overlayText,
  }) =>
      {
        "agency_id": agencyId,
        "category": category,
        "overlay_text": overlayText == null || overlayText.trim().isEmpty ? null : overlayText.trim(),
        "label": label,
        "media_url": mediaUrl,
        "media_type": "video",
        "start_time": startTime,
        "end_time": endTime,
        "mode": mode,
        "audio_mode": audioMode,
        "volume": volume,
        "is_active": isActive,
        "updated_at": DateTime.now().toIso8601String(),
      };

  /// Cria um ou varios videos de uma vez com a mesma configuracao (cada um
  /// com seu nome), ou edita um existente quando [id] vem preenchido.
  /// Devolve as linhas como ficaram no banco, pra tela atualizar na hora.
  Future<List<Map<String, dynamic>>> save({
    String? id,
    required List<({String label, String mediaUrl})> videos,
    required String startTime,
    required String endTime,
    required String mode,
    required String audioMode,
    required double volume,
    required bool isActive,
    String category = homeCategoryNormal,
    String? overlayText,
  }) async {
    final agencyId = await currentAgencyId();
    final rows = [
      for (final v in videos)
        _row(
          agencyId: agencyId,
          label: v.label,
          mediaUrl: v.mediaUrl,
          startTime: startTime,
          endTime: endTime,
          mode: mode,
          audioMode: audioMode,
          volume: volume,
          isActive: isActive,
          category: category,
          overlayText: category == homeCategoryInactivity ? overlayText : null,
        ),
    ];
    final List saved;
    if (id != null) {
      saved = await _client.from("home_backgrounds").update(rows.single).eq("id", id).select();
    } else if (rows.isNotEmpty) {
      saved = await _client.from("home_backgrounds").insert(rows).select();
    } else {
      saved = const [];
    }
    return List<Map<String, dynamic>>.from(saved);
  }

  Future<void> setActive(String id, bool active) =>
      _client.from("home_backgrounds").update({"is_active": active, "updated_at": DateTime.now().toIso8601String()}).eq("id", id);

  Future<void> delete(String id) => _client.from("home_backgrounds").delete().eq("id", id);

  /// Liga/desliga da Inatividade (app_settings.home_inactivity_enabled).
  /// Sem configuracao salva = ligada.
  Future<bool> fetchInactivityEnabled() async {
    final agencyId = await currentAgencyId();
    final row = await _client
        .from("app_settings")
        .select("value")
        .eq("agency_id", agencyId)
        .eq("key", homeInactivityEnabledKey)
        .maybeSingle();
    final value = row?["value"];
    return !(value == false || value == "false");
  }

  Future<void> saveInactivityEnabled(bool enabled) async {
    final agencyId = await currentAgencyId();
    await _client.from("app_settings").upsert(
      {
        "agency_id": agencyId,
        "key": homeInactivityEnabledKey,
        "value": enabled,
        "updated_at": DateTime.now().toIso8601String(),
      },
      onConflict: "agency_id,key",
    );
  }

  Future<({String? url, double volume})> fetchDefaultAudio() async {
    final agencyId = await currentAgencyId();
    final row = await _client
        .from("app_settings")
        .select("value")
        .eq("agency_id", agencyId)
        .eq("key", homeDefaultAudioKey)
        .maybeSingle();
    final value = row?["value"];
    if (value is Map) {
      final url = value["url"] as String?;
      return (url: url == null || url.isEmpty ? null : url, volume: (value["volume"] as num?)?.toDouble() ?? 1.0);
    }
    return (url: null, volume: 1.0);
  }

  Future<void> saveDefaultAudio({String? url, required double volume}) async {
    final agencyId = await currentAgencyId();
    await _client.from("app_settings").upsert(
      {
        "agency_id": agencyId,
        "key": homeDefaultAudioKey,
        "value": {"url": url ?? "", "volume": volume},
        "updated_at": DateTime.now().toIso8601String(),
      },
      onConflict: "agency_id,key",
    );
  }
}
