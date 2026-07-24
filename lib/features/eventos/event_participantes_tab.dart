import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "../calendario/widgets/streamer_picker_dialog.dart";
import "event_history_service.dart";

/// So streamers -- colaboradores (gestores) participando do evento agora
/// ficam na aba Visao Geral, junto com as tarefas atribuidas a cada um.
class EventParticipantesTab extends StatefulWidget {
  final String eventId;
  const EventParticipantesTab({super.key, required this.eventId});

  @override
  State<EventParticipantesTab> createState() => _EventParticipantesTabState();
}

class _EventParticipantesTabState extends State<EventParticipantesTab> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final client = Supabase.instance.client;
    final rows = await client
        .from("event_participants")
        .select("*, streamer:profiles(id, display_name, tiktok_username, avatar_url)")
        .eq("event_id", widget.eventId)
        .eq("participant_type", "streamer")
        .order("created_at");
    return (rows as List).cast<Map<String, dynamic>>();
  }

  void _reload() => setState(() { _future = _load(); });

  Future<String?> _promptRoleLabel() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1A1A1A),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Papel neste evento (opcional)", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(controller: controller, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Ex: Organizador, Competidor", labelStyle: TextStyle(color: Colors.white54))),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(controller.text.trim()),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
                  child: const Text("Confirmar"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addStreamers() async {
    final selected = await showDialog<List<Map<String, dynamic>>>(context: context, builder: (context) => const StreamerPickerDialog());
    if (selected == null || selected.isEmpty) return;
    final roleLabel = await _promptRoleLabel();
    if (roleLabel == null) return;
    final client = Supabase.instance.client;
    try {
      for (final s in selected) {
        await client.from("event_participants").insert({
          "event_id": widget.eventId,
          "participant_type": "streamer",
          "streamer_id": s["id"],
          "role_label": roleLabel.isEmpty ? null : roleLabel,
        });
        await logEventHistory(eventId: widget.eventId, action: "participante_adicionado", detail: (s["display_name"] as String?) ?? "Streamer");
      }
      _reload();
    } catch (e) {
      if (mounted) showEventosActionError(context, e);
    }
  }

  Future<void> _remove(Map<String, dynamic> participant) async {
    final client = Supabase.instance.client;
    try {
      await client.from("event_participants").delete().eq("id", participant["id"]);
      final streamer = participant["streamer"];
      final name = streamer is Map ? streamer["display_name"] as String? : null;
      await logEventHistory(eventId: widget.eventId, action: "participante_removido", detail: name ?? "-");
      _reload();
    } catch (e) {
      if (mounted) showEventosActionError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text("Participantes", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const Spacer(),
            OutlinedButton.icon(onPressed: _addStreamers, icon: const Icon(Icons.person_add, size: 16), label: const Text("Streamer")),
          ]),
          const SizedBox(height: 4),
          const Text("Colaboradores (gestores) envolvidos na organizacao ficam na aba Visao Geral.", style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic)),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.hasError) return buildEventosLoadError(snapshot.error!);
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final list = snapshot.data!;
                if (list.isEmpty) return const Center(child: Text("Nenhum streamer adicionado ainda.", style: TextStyle(color: Colors.white54)));
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final p = list[index];
                    final streamer = p["streamer"];
                    final name = streamer is Map ? streamer["display_name"] as String? ?? "-" : "-";
                    final photoUrl = streamer is Map ? streamer["avatar_url"] as String? : null;
                    final subtitle = streamer is Map ? "@" + ((streamer["tiktok_username"] as String?) ?? "-") : "";
                    return Card(
                      color: Colors.white.withOpacity(0.05),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white24,
                          backgroundImage: photoUrl != null && photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                          child: photoUrl == null || photoUrl.isEmpty ? const Icon(Icons.person, color: Colors.white70, size: 18) : null,
                        ),
                        title: Text(name, style: const TextStyle(color: Colors.white)),
                        subtitle: Text(((p["role_label"] as String?)?.isNotEmpty == true ? p["role_label"] as String : subtitle), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        trailing: IconButton(icon: const Icon(Icons.close, color: Colors.white38, size: 18), onPressed: () => _remove(p)),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
