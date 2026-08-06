import "package:supabase_flutter/supabase_flutter.dart";

/// Co-gestores por streamer (streamer_managers, N:N) -- mesma ideia do
/// Onboard 15 Dias (streamer_phase_progress_managers), so que chaveada
/// direto por streamer_id em vez de um card de onboarding, pra continuar
/// valendo depois que o streamer se forma. Nao mexe em
/// profiles.assigned_manager_id (continua sendo o gestor responsavel unico
/// usado no resto do CRM).
class StreamerManager {
  final String id;
  final String? loginEmail;
  final String? photoUrl;
  const StreamerManager({required this.id, this.loginEmail, this.photoUrl});
}

/// Um streamer por vez -- todos os co-gestores de um streamer, pro dialog
/// de selecao (StreamerManagerPickerDialog).
Future<Set<String>> fetchStreamerManagerIds(String streamerId) async {
  final rows = await Supabase.instance.client
      .from("streamer_managers")
      .select("manager_id")
      .eq("streamer_id", streamerId);
  return (rows as List)
      .cast<Map<String, dynamic>>()
      .map((r) => r["manager_id"] as String)
      .toSet();
}

/// Varios streamers de uma vez -- pro card de cada streamer no board de
/// Gestao de Streamers mostrar os mini-avatares sem 1 consulta por card.
Future<Map<String, List<StreamerManager>>> fetchStreamerManagersByIds(
  List<String> streamerIds,
) async {
  if (streamerIds.isEmpty) return {};
  final rows = await Supabase.instance.client
      .from("streamer_managers")
      .select(
        "streamer_id, managers!streamer_managers_manager_id_fkey(id, login_email, photo_url)",
      )
      .inFilter("streamer_id", streamerIds);
  final result = <String, List<StreamerManager>>{};
  for (final r in (rows as List).cast<Map<String, dynamic>>()) {
    final streamerId = r["streamer_id"] as String;
    final m = r["managers"];
    if (m is! Map) continue;
    result
        .putIfAbsent(streamerId, () => [])
        .add(
          StreamerManager(
            id: m["id"] as String,
            loginEmail: m["login_email"] as String?,
            photoUrl: m["photo_url"] as String?,
          ),
        );
  }
  return result;
}

Future<void> addStreamerManager({
  required String streamerId,
  required String managerId,
  required String addedBy,
}) async {
  await Supabase.instance.client.from("streamer_managers").upsert({
    "streamer_id": streamerId,
    "manager_id": managerId,
    "added_by": addedBy,
  }, onConflict: "streamer_id,manager_id");
}

Future<void> removeStreamerManager({
  required String streamerId,
  required String managerId,
}) async {
  await Supabase.instance.client
      .from("streamer_managers")
      .delete()
      .eq("streamer_id", streamerId)
      .eq("manager_id", managerId);
}
