import "package:file_picker/file_picker.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "../eventos/event_upload_helpers.dart";

/// Slots fixos da ilha: Top 1 (destaque), Top 2..Top 10 (fixos) e uma AREA
/// unica pra quem bateu 80k+ mas nao esta no top 10 (pode ter varios
/// avatares dentro, por isso tem area_width/area_height/min_scale em vez
/// de um ponto so).
const islandSlotDefaults = <Map<String, Object>>[
  {"slot_key": "top_1", "label": "Top 1", "pos_x": 50.0, "pos_y": 20.0, "scale": 1.4, "z_index": 10},
  {"slot_key": "top_2", "label": "Top 2", "pos_x": 35.0, "pos_y": 30.0, "scale": 1.1, "z_index": 9},
  {"slot_key": "top_3", "label": "Top 3", "pos_x": 65.0, "pos_y": 30.0, "scale": 1.1, "z_index": 9},
  {"slot_key": "top_4", "label": "Top 4", "pos_x": 22.0, "pos_y": 42.0, "scale": 1.0, "z_index": 8},
  {"slot_key": "top_5", "label": "Top 5", "pos_x": 78.0, "pos_y": 42.0, "scale": 1.0, "z_index": 8},
  {"slot_key": "top_6", "label": "Top 6", "pos_x": 30.0, "pos_y": 55.0, "scale": 0.9, "z_index": 7},
  {"slot_key": "top_7", "label": "Top 7", "pos_x": 70.0, "pos_y": 55.0, "scale": 0.9, "z_index": 7},
  {"slot_key": "top_8", "label": "Top 8", "pos_x": 15.0, "pos_y": 65.0, "scale": 0.85, "z_index": 6},
  {"slot_key": "top_9", "label": "Top 9", "pos_x": 85.0, "pos_y": 65.0, "scale": 0.85, "z_index": 6},
  {"slot_key": "top_10", "label": "Top 10", "pos_x": 50.0, "pos_y": 70.0, "scale": 0.85, "z_index": 6},
  {
    "slot_key": "top_11_plus",
    "label": "Area 11+",
    "pos_x": 30.0,
    "pos_y": 76.0,
    "scale": 0.8,
    "z_index": 5,
    "area_width": 40.0,
    "area_height": 18.0,
    "min_scale": 0.55,
  },
  {"slot_key": "top_1_last_month", "label": "Top 1 do mes passado", "pos_x": 78.0, "pos_y": 6.0, "scale": 0.7, "z_index": 11},
];

/// Slots que mostram foto+nome do streamer (calculado automaticamente),
/// em vez do avatar "pato" escolhido por ele.
bool islandSlotIsPhotoSlot(String slotKey) => slotKey == "top_1_last_month";

/// slot_key dos slots de ponto fixo (Top 1..Top 10) vs. o slot de area
/// (top_11_plus, que pode ter varios avatares dentro).
bool islandSlotIsArea(String slotKey) => slotKey == "top_11_plus";

/// Retorna o slot_key correspondente a posicao no ranking (1-indexado).
String slotKeyForRank(int rank) => rank <= 10 ? "top_" + rank.toString() : "top_11_plus";

/// Raridades de skin disponiveis pros avatares.
const islandAvatarRarities = [
  ("comum", "Comum"),
  ("classico", "Clássico"),
  ("raro", "Raro"),
  ("epico", "Épico"),
  ("lendario", "Lendário"),
];

const _videoExtensions = [".mp4", ".mov", ".webm", ".m4v"];

bool islandMediaLooksLikeVideo(String url) {
  final lower = url.toLowerCase().split("?").first;
  return _videoExtensions.any((ext) => lower.endsWith(ext));
}

/// Gestao da Ilha Top: banco de videos/imagens de fundo, banco de avatares
/// (patos) e posicoes (x/y) de cada slot da ilha. Tudo por agencia.
class IlhaTopService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<String> currentAgencyId() async {
    final userId = _client.auth.currentUser!.id;
    final manager = await _client.from("managers").select("agency_id").eq("id", userId).single();
    return manager["agency_id"] as String;
  }

  Future<String> uploadMedia(PlatformFile file) => uploadEventFile(bucket: "island_media", prefix: "island", file: file);

  // ---------------------------------------------------------------- fundos
  Future<List<Map<String, dynamic>>> fetchBackgrounds() async {
    final agencyId = await currentAgencyId();
    final rows = await _client.from("island_backgrounds").select().eq("agency_id", agencyId).order("sort_order");
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<void> saveBackground({
    String? id,
    required String label,
    required String mediaUrl,
    required String mediaType,
    String? previewImageUrl,
    required String startTime,
    required String endTime,
    required String mode,
    required bool isActive,
    required bool muted,
    required double volume,
    required bool loopVideo,
    required double cropScale,
    required double cropOffsetX,
    required double cropOffsetY,
  }) async {
    final agencyId = await currentAgencyId();
    final data = {
      "agency_id": agencyId,
      "label": label,
      "media_url": mediaUrl,
      "media_type": mediaType,
      "preview_image_url": previewImageUrl,
      "start_time": startTime,
      "end_time": endTime,
      "mode": mode,
      "is_active": isActive,
      "muted": muted,
      "volume": volume,
      "loop_video": loopVideo,
      "crop_scale": cropScale,
      "crop_offset_x": cropOffsetX,
      "crop_offset_y": cropOffsetY,
      "updated_at": DateTime.now().toIso8601String(),
    };
    if (id != null) {
      await _client.from("island_backgrounds").update(data).eq("id", id);
    } else {
      await _client.from("island_backgrounds").insert(data);
    }
  }

  Future<void> deleteBackground(String id) => _client.from("island_backgrounds").delete().eq("id", id);

  // ------------------------------------------------------------- avatares
  Future<List<Map<String, dynamic>>> fetchAvatars() async {
    final agencyId = await currentAgencyId();
    final rows = await _client.from("island_avatars").select().eq("agency_id", agencyId).order("sort_order");
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<void> saveAvatar({
    String? id,
    required String label,
    required String mediaUrl,
    String? previewImageUrl,
    required bool isActive,
    required int minDiamonds,
    required List<String> categoryIds,
    String? gender,
    required String rarity,
    required bool muted,
    required double volume,
    required bool loopVideo,
    required double cropScale,
    required double cropOffsetX,
    required double cropOffsetY,
  }) async {
    final agencyId = await currentAgencyId();
    final data = {
      "agency_id": agencyId,
      "label": label,
      "media_url": mediaUrl,
      "preview_image_url": previewImageUrl,
      "is_active": isActive,
      "min_diamonds": minDiamonds,
      "category_ids": categoryIds.isEmpty ? null : categoryIds,
      "gender": gender,
      "rarity": rarity,
      "muted": muted,
      "volume": volume,
      "loop_video": loopVideo,
      "crop_scale": cropScale,
      "crop_offset_x": cropOffsetX,
      "crop_offset_y": cropOffsetY,
    };
    if (id != null) {
      await _client.from("island_avatars").update(data).eq("id", id);
    } else {
      await _client.from("island_avatars").insert(data);
    }
  }

  Future<void> deleteAvatar(String id) => _client.from("island_avatars").delete().eq("id", id);

  /// Ranking dos streamers pra Ilha Top, ordenado por diamantes do mes.
  /// Com testMode=false so entra quem bateu o minimo (80k) -- e o que vale
  /// de verdade. Com testMode=true usa o `threshold` customizado (config de
  /// teste) e aceita `pinnedIds` (ate 3, na ordem top1/top2/top3) pra forcar
  /// quem ocupa essas posicoes manualmente, independente dos diamantes --
  /// so pra pre-visualizacao (ninguem e desbloqueado de verdade nesse modo).
  Future<List<Map<String, dynamic>>> fetchRanking({
    required bool testMode,
    int threshold = 80000,
    List<String?> pinnedIds = const [],
  }) async {
    final profiles = await _client
        .from("profiles")
        .select("id, display_name, tiktok_creator_id, avatar_url, streamer_stats(diamonds)")
        .eq("is_active", true);

    final islands = await _client
        .from("streamer_islands")
        .select("streamer_id, unlocked_at, avatar_id, island_avatars(label, media_url, preview_image_url)");
    final islandMap = {for (final i in (islands as List)) i["streamer_id"] as String: i};

    final itemsCount = await _client.from("streamer_island_items").select("streamer_id");
    final countMap = <String, int>{};
    for (final it in (itemsCount as List)) {
      final sid = it["streamer_id"] as String;
      countMap[sid] = (countMap[sid] ?? 0) + 1;
    }

    final all = <Map<String, dynamic>>[];
    for (final p in (profiles as List)) {
      final statsData = p["streamer_stats"];
      int diamonds = 0;
      if (statsData is List && statsData.isNotEmpty) {
        diamonds = statsData.first["diamonds"] as int? ?? 0;
      } else if (statsData is Map) {
        diamonds = statsData["diamonds"] as int? ?? 0;
      }
      final island = islandMap[p["id"]];
      final avatar = island != null ? island["island_avatars"] : null;
      all.add({
        "id": p["id"],
        "display_name": p["display_name"],
        "tiktok_creator_id": p["tiktok_creator_id"],
        "profile_avatar_url": p["avatar_url"],
        "diamonds": diamonds,
        "unlocked_at": island != null ? island["unlocked_at"] : null,
        "decorations": countMap[p["id"]] ?? 0,
        "avatar_label": avatar is Map ? avatar["label"] as String? : null,
        "avatar_media_url": avatar is Map ? avatar["media_url"] as String? : null,
        "avatar_preview_url": avatar is Map ? avatar["preview_image_url"] as String? : null,
      });
    }
    all.sort((a, b) => (b["diamonds"] as int).compareTo(a["diamonds"] as int));

    if (!testMode) {
      return all.where((s) => (s["diamonds"] as int) >= threshold).toList();
    }

    final byId = {for (final s in all) s["id"] as String: s};
    final pinnedByRank = <int, String>{};
    for (var i = 0; i < pinnedIds.length && i < 3; i++) {
      final pid = pinnedIds[i];
      if (pid != null && byId.containsKey(pid)) pinnedByRank[i + 1] = pid;
    }
    final pinnedIdSet = pinnedByRank.values.toSet();
    final pool = all.where((s) => (s["diamonds"] as int) >= threshold && !pinnedIdSet.contains(s["id"])).toList();

    final total = pool.length + pinnedByRank.length;
    final result = <Map<String, dynamic>>[];
    var poolIndex = 0;
    for (var rank = 1; rank <= total; rank++) {
      final pinnedId = pinnedByRank[rank];
      if (pinnedId != null) {
        result.add(byId[pinnedId]!);
      } else if (poolIndex < pool.length) {
        result.add(pool[poolIndex]);
        poolIndex++;
      }
    }
    return result;
  }

  /// Todos os streamers ativos (id + nome), pra seletor de "forcar top 1/2/3"
  /// no modo teste -- sem filtro de diamantes, qualquer um pode ser fixado.
  Future<List<Map<String, dynamic>>> fetchAllActiveStreamersBasic() async {
    final rows = await _client.from("profiles").select("id, display_name").eq("is_active", true).order("display_name");
    return List<Map<String, dynamic>>.from(rows as List);
  }

  /// Modo teste da Ilha Top: configuracao de agencia (chave "island_test_mode"
  /// na tabela app_settings, ja lida pelo app do streamer via RLS). Quando
  /// true, o app deve ignorar o minimo de 80k e montar a ilha com o ranking
  /// completo, igual a pre-visualizacao daqui do admin.
  Future<bool> fetchTestMode() async {
    final agencyId = await currentAgencyId();
    final row = await _client.from("app_settings").select("value").eq("agency_id", agencyId).eq("key", "island_test_mode").maybeSingle();
    return row?["value"] == true;
  }

  Future<void> saveTestMode(bool value) => _saveAppSetting("island_test_mode", value);

  /// Configuracao do modo teste: diamantes minimos customizados, quem fica
  /// fixo em top1/top2/top3, e quais raridades de avatar ficam bloqueadas/
  /// desbloqueadas nesse cenario. Chave "island_test_config" em app_settings.
  Future<Map<String, dynamic>> fetchTestConfig() async {
    final agencyId = await currentAgencyId();
    final row = await _client.from("app_settings").select("value").eq("agency_id", agencyId).eq("key", "island_test_config").maybeSingle();
    final value = row?["value"];
    final saved = value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
    final savedLocks = saved["rarity_locks"];
    return {
      "diamond_threshold": (saved["diamond_threshold"] as num?)?.toInt() ?? 0,
      "pinned_top1": saved["pinned_top1"] as String?,
      "pinned_top2": saved["pinned_top2"] as String?,
      "pinned_top3": saved["pinned_top3"] as String?,
      "rarity_locks": {
        for (final r in islandAvatarRarities) r.$1: (savedLocks is Map ? savedLocks[r.$1] as bool? : null) ?? false,
      },
    };
  }

  Future<void> saveTestConfig(Map<String, dynamic> config) => _saveAppSetting("island_test_config", config);

  /// Upsert atomico (precisa da constraint unique(agency_id,key) da
  /// migration 0070) -- evita a corrida do padrao antigo "select -> insert
  /// ou update", que quebrava com PGRST116 (multiplas linhas) se duas telas
  /// salvassem a mesma chave quase ao mesmo tempo.
  Future<void> _saveAppSetting(String key, dynamic value) async {
    final agencyId = await currentAgencyId();
    await _client.from("app_settings").upsert(
      {"agency_id": agencyId, "key": key, "value": value, "updated_at": DateTime.now().toIso8601String()},
      onConflict: "agency_id,key",
    );
  }

  /// Categorias da agencia, pra restringir quem pode escolher cada avatar.
  Future<List<Map<String, dynamic>>> fetchCategories() async {
    final rows = await _client.from("streamer_categories").select("id, name").order("name");
    return List<Map<String, dynamic>>.from(rows as List);
  }

  /// Streamer com mais diamantes no ultimo mes fechado (via monthly_stats,
  /// alimentado pela importacao mensal do TikTok), pro slot "Top 1 do mes
  /// passado". Retorna null se nenhum mes foi importado ainda.
  Future<Map<String, dynamic>?> fetchLastMonthTop1() async {
    final profiles = await _client.from("profiles").select("id, display_name, avatar_url").eq("is_active", true);
    final profileMap = {for (final p in (profiles as List)) p["id"] as String: p};
    if (profileMap.isEmpty) return null;

    final monthlyRows = await _client.from("monthly_stats").select("streamer_id, period_key, diamonds").order("period_key", ascending: false);
    if ((monthlyRows as List).isEmpty) return null;

    final latestPeriodKey = monthlyRows.first["period_key"] as String;
    Map<String, dynamic>? best;
    for (final row in monthlyRows) {
      if (row["period_key"] != latestPeriodKey) continue;
      final sid = row["streamer_id"] as String;
      if (!profileMap.containsKey(sid)) continue;
      if (best == null || ((row["diamonds"] as int?) ?? 0) > ((best["diamonds"] as int?) ?? 0)) {
        best = row;
      }
    }
    if (best == null) return null;
    final profile = profileMap[best["streamer_id"]]!;
    return {
      "period_key": latestPeriodKey,
      "streamer_id": best["streamer_id"],
      "diamonds": best["diamonds"],
      "display_name": profile["display_name"],
      "avatar_url": profile["avatar_url"],
    };
  }

  // -------------------------------------------------------------- slots
  /// Busca os slots da agencia; semeia os defaults que ainda nao existirem
  /// (tanto na primeira vez quanto quando novos slots-padrao sao criados
  /// depois, ex: "top_1_last_month").
  Future<List<Map<String, dynamic>>> fetchSlots() async {
    final agencyId = await currentAgencyId();
    final rows = await _client.from("island_slots").select().eq("agency_id", agencyId).order("z_index", ascending: false);
    final list = List<Map<String, dynamic>>.from(rows as List);
    final existingKeys = list.map((s) => s["slot_key"] as String).toSet();
    final missing = islandSlotDefaults.where((d) => !existingKeys.contains(d["slot_key"])).toList();
    if (missing.isEmpty) return list;

    await _client.from("island_slots").insert([
      for (final s in missing) {...s, "agency_id": agencyId},
    ]);
    final seeded = await _client.from("island_slots").select().eq("agency_id", agencyId).order("z_index", ascending: false);
    return List<Map<String, dynamic>>.from(seeded as List);
  }

  Future<void> saveSlots(List<Map<String, dynamic>> slots) async {
    final agencyId = await currentAgencyId();
    await _client.from("island_slots").upsert(
          [
            for (final s in slots)
              {
                "id": s["id"],
                "agency_id": agencyId,
                "slot_key": s["slot_key"],
                "label": s["label"],
                "pos_x": s["pos_x"],
                "pos_y": s["pos_y"],
                "scale": s["scale"],
                "z_index": s["z_index"],
                "area_width": s["area_width"],
                "area_height": s["area_height"],
                "min_scale": s["min_scale"],
                "is_enabled": s["is_enabled"] ?? true,
              },
          ],
          onConflict: "agency_id,slot_key",
        );
  }
}
