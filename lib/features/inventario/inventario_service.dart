import "package:file_picker/file_picker.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "../eventos/event_upload_helpers.dart";
import "models/inventory_entry.dart";

const _entrySelect = "*, created_by_manager:managers!created_by(id, full_name, login_email)";

/// Camada unica de acesso ao inventario do streamer (treinamentos,
/// acompanhamentos, premiacoes e conquistas).
class InventarioService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<String> currentAgencyId() async {
    final userId = _client.auth.currentUser!.id;
    final manager = await _client.from("managers").select("agency_id").eq("id", userId).single();
    return manager["agency_id"] as String;
  }

  /// Busca streamers da agencia por nome, nick (tiktok_username) ou id do
  /// criador (tiktok_creator_id).
  Future<List<Map<String, dynamic>>> fetchStreamers({String? search}) async {
    final agencyId = await currentAgencyId();
    dynamic query = _client
        .from("profiles")
        .select("id, display_name, tiktok_username, tiktok_creator_id, avatar_url")
        .eq("agency_id", agencyId)
        .eq("is_active", true);
    if (search != null && search.trim().isNotEmpty) {
      final term = search.trim();
      query = query.or("display_name.ilike.%" + term + "%,tiktok_username.ilike.%" + term + "%,tiktok_creator_id.ilike.%" + term + "%");
    }
    final rows = await query.order("display_name").limit(200);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<List<InventoryEntry>> fetchEntries({required String streamerId, InventoryCategory? category}) async {
    dynamic query = _client.from("streamer_inventory_entries").select(_entrySelect).eq("streamer_id", streamerId);
    if (category != null) query = query.eq("category", inventoryCategoryToDb(category));
    final rows = await query.order("occurred_at", ascending: false).order("created_at", ascending: false);
    return (rows as List).map((r) => InventoryEntry.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<String> uploadImage(PlatformFile file) => uploadEventFile(bucket: "streamer_inventory", prefix: "inventario", file: file);

  Future<void> addEntry({
    required String streamerId,
    required InventoryCategory category,
    required String title,
    String? description,
    required DateTime occurredAt,
    int? points,
    String? imageUrl,
  }) async {
    final agencyId = await currentAgencyId();
    final userId = _client.auth.currentUser!.id;
    await _client.from("streamer_inventory_entries").insert({
      "agency_id": agencyId,
      "streamer_id": streamerId,
      "category": inventoryCategoryToDb(category),
      "title": title,
      "description": description,
      "occurred_at": _dateOnly(occurredAt),
      "points": points,
      "image_url": imageUrl,
      "source": "manual",
      "created_by": userId,
    });
  }

  Future<void> deleteEntry(String id) async {
    await _client.from("streamer_inventory_entries").delete().eq("id", id);
  }

  String _dateOnly(DateTime date) {
    final y = date.year.toString().padLeft(4, "0");
    final m = date.month.toString().padLeft(2, "0");
    final d = date.day.toString().padLeft(2, "0");
    return y + "-" + m + "-" + d;
  }
}
