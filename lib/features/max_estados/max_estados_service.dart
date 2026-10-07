import "package:file_picker/file_picker.dart";
import "../../core/upload_optimizer.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "models/max_state.dart";
import "models/max_state_media.dart";
import "models/max_state_message.dart";

/// Dias que definem cada estado do Max (Regular = o que nao cair nos outros).
class MaxStateRules {
  final int constanteMinLivesThisMonth;
  final int constanteMinStreakDays;
  final int inativoMinDaysWithoutLive;
  final int caveiraMinDaysWithoutLive;

  const MaxStateRules({
    required this.constanteMinLivesThisMonth,
    required this.constanteMinStreakDays,
    required this.inativoMinDaysWithoutLive,
    required this.caveiraMinDaysWithoutLive,
  });
}

/// Camada unica de acesso aos estados do Max: cada estado tem no maximo uma
/// midia principal (imagem OU video) e varias mensagens.
class MaxEstadosService {
  static const bucket = "max_states";

  final SupabaseClient _client = Supabase.instance.client;

  Future<String> currentAgencyId() async {
    final userId = _client.auth.currentUser!.id;
    final manager = await _client.from("managers").select("agency_id").eq("id", userId).single();
    return manager["agency_id"] as String;
  }

  String publicUrlFor(String storagePath) => _client.storage.from(bucket).getPublicUrl(storagePath);

  // ---------------- configuracao (engrenagem) ----------------

  /// Liga/desliga da tela do Max ao abrir o app (app_settings.max_intro_enabled).
  Future<bool> fetchEnabled() async {
    final agencyId = await currentAgencyId();
    final row = await _client
        .from("app_settings")
        .select("value")
        .eq("agency_id", agencyId)
        .eq("key", "max_intro_enabled")
        .maybeSingle();
    final value = row?["value"];
    return !(value == false || value == "false");
  }

  Future<void> saveEnabled(bool enabled) async {
    final agencyId = await currentAgencyId();
    await _client.from("app_settings").upsert(
      {"agency_id": agencyId, "key": "max_intro_enabled", "value": enabled, "updated_at": DateTime.now().toIso8601String()},
      onConflict: "agency_id,key",
    );
  }

  /// Dias de cada estado (max_state_rules). Valores padrao quando a agencia
  /// ainda nao configurou: Constante 3 dias de live no mes (e live ontem/hoje)
  /// ou 3 seguidos; Inativo a partir de 3 dias sem live; Caveira a partir de 10.
  Future<MaxStateRules> fetchRules() async {
    final agencyId = await currentAgencyId();
    final rows = await _client.from("max_state_rules").select().eq("agency_id", agencyId);
    Map<String, dynamic>? row(String key) =>
        (rows as List).cast<Map<String, dynamic>>().where((r) => r["state_key"] == key).firstOrNull;
    final constante = row("constante");
    final extra = constante?["extra_config"];
    return MaxStateRules(
      constanteMinLivesThisMonth: (constante?["min_lives_this_month"] as num?)?.toInt() ?? 3,
      constanteMinStreakDays: extra is Map ? (extra["constante_min_streak_days"] as num?)?.toInt() ?? 3 : 3,
      inativoMinDaysWithoutLive: (row("inativo")?["min_days_without_live"] as num?)?.toInt() ?? 3,
      caveiraMinDaysWithoutLive: (row("caveira")?["min_days_without_live"] as num?)?.toInt() ?? 10,
    );
  }

  Future<void> saveRules(MaxStateRules rules) async {
    final agencyId = await currentAgencyId();
    final userId = _client.auth.currentUser!.id;
    final now = DateTime.now().toIso8601String();
    await _client.from("max_state_rules").upsert([
      {
        "agency_id": agencyId,
        "state_key": "constante",
        "min_lives_this_month": rules.constanteMinLivesThisMonth,
        "extra_config": {"constante_min_streak_days": rules.constanteMinStreakDays},
        "updated_by": userId,
        "updated_at": now,
      },
      {
        "agency_id": agencyId,
        "state_key": "inativo",
        "min_days_without_live": rules.inativoMinDaysWithoutLive,
        "updated_by": userId,
        "updated_at": now,
      },
      {
        "agency_id": agencyId,
        "state_key": "caveira",
        "min_days_without_live": rules.caveiraMinDaysWithoutLive,
        "updated_by": userId,
        "updated_at": now,
      },
    ], onConflict: "agency_id,state_key");
  }

  Future<Map<MaxStateKey, MaxStateSummary>> fetchSummary() async {
    final agencyId = await currentAgencyId();
    final mediaRows = await _client.from("max_state_media").select().eq("agency_id", agencyId);
    final messageRows = await _client.from("max_state_messages").select("state_key").eq("agency_id", agencyId);

    final media = (mediaRows as List).map((r) => MaxStateMedia.fromMap(r as Map<String, dynamic>)).toList();
    final messageCounts = <MaxStateKey, int>{};
    for (final r in messageRows as List) {
      final key = maxStateKeyFromDb((r as Map<String, dynamic>)["state_key"] as String);
      messageCounts[key] = (messageCounts[key] ?? 0) + 1;
    }

    final result = <MaxStateKey, MaxStateSummary>{};
    for (final key in MaxStateKey.values) {
      MaxStateMedia? stateMedia;
      for (final m in media) {
        if (m.stateKey == key) {
          stateMedia = m;
          break;
        }
      }
      result[key] = MaxStateSummary(
        stateKey: key,
        media: stateMedia,
        messageCount: messageCounts[key] ?? 0,
      );
    }
    return result;
  }

  /// Cada estado tem no maximo uma midia. Retorna null se ainda nao houver
  /// conteudo cadastrado.
  Future<MaxStateMedia?> fetchMedia(MaxStateKey stateKey) async {
    final agencyId = await currentAgencyId();
    final rows = await _client
        .from("max_state_media")
        .select()
        .eq("agency_id", agencyId)
        .eq("state_key", maxStateKeyToDb(stateKey))
        .order("created_at")
        .limit(1);
    final list = rows as List;
    if (list.isEmpty) return null;
    return MaxStateMedia.fromMap(list.first as Map<String, dynamic>);
  }

  Future<String> uploadMedia({required MaxMediaType mediaType, required PlatformFile file}) async {
    final dotIndex = file.name.lastIndexOf(".");
    final rawExt = dotIndex != -1 ? file.name.substring(dotIndex + 1) : "";
    final ext = RegExp(r"^[a-zA-Z0-9]{1,6}$").hasMatch(rawExt) ? rawExt.toLowerCase() : "bin";
    final prefix = maxMediaTypeToDb(mediaType);
    // video/imagem do Max e baixado por todo streamer: limita e comprime
    final optimized = optimizeUpload(file.bytes!, ext);
    final path = "${prefix}_${DateTime.now().millisecondsSinceEpoch}.${optimized.ext}";
    await _client.storage.from(bucket).uploadBinary(
          path,
          optimized.bytes,
          fileOptions: FileOptions(contentType: contentTypeFor(optimized.ext), cacheControl: longCache),
        );
    return path;
  }

  /// Substitui a midia principal do estado (apaga a anterior, se existir, e
  /// grava a nova). Cada estado sempre tem no maximo um registro.
  Future<void> replaceMedia({
    required MaxStateKey stateKey,
    required MaxMediaType mediaType,
    required String storagePath,
  }) async {
    final existing = await fetchMedia(stateKey);
    final agencyId = await currentAgencyId();
    final userId = _client.auth.currentUser!.id;
    if (existing != null) {
      await _client.from("max_state_media").update({
        "media_type": maxMediaTypeToDb(mediaType),
        "name": maxStateKeyLabel(stateKey),
        "storage_path": storagePath,
        "is_active": true,
        "updated_at": DateTime.now().toIso8601String(),
      }).eq("id", existing.id);
      if (existing.storagePath != storagePath) {
        await _client.storage.from(bucket).remove([existing.storagePath]);
      }
      return;
    }
    await _client.from("max_state_media").insert({
      "agency_id": agencyId,
      "state_key": maxStateKeyToDb(stateKey),
      "media_type": maxMediaTypeToDb(mediaType),
      "name": maxStateKeyLabel(stateKey),
      "storage_path": storagePath,
      "is_active": true,
      "created_by": userId,
    });
  }

  Future<void> removeMedia(MaxStateMedia media) async {
    await _client.from("max_state_media").delete().eq("id", media.id);
    await _client.storage.from(bucket).remove([media.storagePath]);
  }

  Future<List<MaxStateMessage>> fetchMessages(MaxStateKey stateKey) async {
    final agencyId = await currentAgencyId();
    final rows = await _client
        .from("max_state_messages")
        .select()
        .eq("agency_id", agencyId)
        .eq("state_key", maxStateKeyToDb(stateKey))
        .order("created_at");
    return (rows as List).map((r) => MaxStateMessage.fromMap(r as Map<String, dynamic>)).toList();
  }

  /// Mensagens criadas pelo painel (sem selecao de categoria na UI) sempre
  /// usam a categoria "geral" -- as demais categorias (inicio/meio/final do
  /// mes, retorno etc.) ficam preparadas no banco para uso futuro do app.
  Future<void> saveMessage({
    String? id,
    required MaxStateKey stateKey,
    required String message,
    bool isActive = true,
  }) async {
    if (id != null) {
      await _client.from("max_state_messages").update({
        "message": message,
        "is_active": isActive,
        "updated_at": DateTime.now().toIso8601String(),
      }).eq("id", id);
      return;
    }
    final agencyId = await currentAgencyId();
    final userId = _client.auth.currentUser!.id;
    await _client.from("max_state_messages").insert({
      "agency_id": agencyId,
      "state_key": maxStateKeyToDb(stateKey),
      "category": maxMessageCategoryToDb(MaxMessageCategory.geral),
      "message": message,
      "is_active": isActive,
      "created_by": userId,
    });
  }

  Future<void> setMessageActive(String id, bool isActive) async {
    await _client.from("max_state_messages").update({"is_active": isActive}).eq("id", id);
  }

  Future<void> deleteMessage(String id) async {
    await _client.from("max_state_messages").delete().eq("id", id);
  }
}
