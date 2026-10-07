import "package:file_picker/file_picker.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "../eventos/event_upload_helpers.dart";
import "models/inventory_entry.dart";

const _entrySelect = "*, created_by_manager:managers!created_by(id, full_name, login_email)";

/// Metricas reais do streamer (mesma fonte da Home do app: streamer_stats).
class StreamerQuickStats {
  final int diamonds;
  final double hours;
  final int daysLive;
  const StreamerQuickStats({required this.diamonds, required this.hours, required this.daysLive});
}

/// Inventario do streamer (streamer_inventory_entries, migrations 0059/0090).
/// O mesmo registro aparece aqui, na linha do tempo do CRM e no app.
class InventarioService {
  final SupabaseClient _client = Supabase.instance.client;

  static String? _cachedAgencyId;
  static String? _cachedForUser;

  Future<String> currentAgencyId() async {
    final userId = _client.auth.currentUser!.id;
    if (_cachedAgencyId != null && _cachedForUser == userId) return _cachedAgencyId!;
    final manager = await _client.from("managers").select("agency_id").eq("id", userId).single();
    _cachedForUser = userId;
    return _cachedAgencyId = manager["agency_id"] as String;
  }

  /// Busca streamers da agencia por nome, @username ou id do criador.
  Future<List<Map<String, dynamic>>> fetchStreamers({String? search}) async {
    final agencyId = await currentAgencyId();
    dynamic query = _client
        .from("profiles")
        .select("id, display_name, tiktok_username, tiktok_creator_id, avatar_url, is_active")
        .eq("agency_id", agencyId);
    final term = search?.trim().replaceAll("@", "") ?? "";
    if (term.isNotEmpty) {
      query = query.or("display_name.ilike.%$term%,tiktok_username.ilike.%$term%,tiktok_creator_id.ilike.%$term%");
    } else {
      query = query.eq("is_active", true);
    }
    final rows = await query.order("display_name").limit(60);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<StreamerQuickStats> fetchStats(String streamerId) async {
    final row = await _client
        .from("streamer_stats")
        .select("diamonds, hours_live, days_live")
        .eq("streamer_id", streamerId)
        .maybeSingle();
    return StreamerQuickStats(
      diamonds: (row?["diamonds"] as num?)?.toInt() ?? 0,
      hours: (row?["hours_live"] as num?)?.toDouble() ?? 0,
      daysLive: (row?["days_live"] as num?)?.toInt() ?? 0,
    );
  }

  Future<List<InventoryEntry>> fetchEntries(String streamerId) async {
    final rows = await _client
        .from("streamer_inventory_entries")
        .select(_entrySelect)
        .eq("streamer_id", streamerId)
        .order("occurred_at", ascending: false)
        .order("created_at", ascending: false);
    return (rows as List).map((r) => InventoryEntry.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<String> uploadImage(PlatformFile file) => uploadEventFile(bucket: "streamer_inventory", prefix: "inventario", file: file);

  /// Cria ou edita (quando [id] vem preenchido). Devolve o registro salvo.
  Future<InventoryEntry> save({
    String? id,
    required String streamerId,
    required String category,
    required String title,
    String? description,
    required DateTime occurredAt,
    double? amount,
    required bool showAmount,
    String? imageUrl,
    String? internalNote,
    required String status,
    required bool visibleToStreamer,
  }) async {
    final agencyId = await currentAgencyId();
    final userId = _client.auth.currentUser!.id;
    String? clean(String? v) => v == null || v.trim().isEmpty ? null : v.trim();
    final data = <String, dynamic>{
      "agency_id": agencyId,
      "streamer_id": streamerId,
      "category": category,
      "title": title.trim(),
      "description": clean(description),
      "occurred_at": _dateOnly(occurredAt),
      "amount": amount,
      "show_amount": showAmount,
      "image_url": clean(imageUrl),
      "internal_note": clean(internalNote),
      "status": status,
      "visible_to_streamer": visibleToStreamer,
      "updated_at": DateTime.now().toUtc().toIso8601String(),
      "updated_by": userId,
    };
    final Map<String, dynamic> row;
    if (id != null) {
      row = await _client.from("streamer_inventory_entries").update(data).eq("id", id).select(_entrySelect).single();
    } else {
      data["source"] = "manual";
      data["created_by"] = userId;
      row = await _client.from("streamer_inventory_entries").insert(data).select(_entrySelect).single();
    }
    return InventoryEntry.fromMap(row);
  }

  Future<void> deleteEntry(String id) => _client.from("streamer_inventory_entries").delete().eq("id", id);

  String _dateOnly(DateTime d) =>
      "${d.year.toString().padLeft(4, "0")}-${d.month.toString().padLeft(2, "0")}-${d.day.toString().padLeft(2, "0")}";
}
