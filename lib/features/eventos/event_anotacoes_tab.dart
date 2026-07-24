import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "../calendario/widgets/streamer_picker_dialog.dart";
import "event_history_service.dart";

/// Mural de anotacoes gerais do evento -- qualquer gestor pode escrever uma
/// observacao (marcando um streamer especifico ou nao) pra registrar algo
/// relevante que os outros precisam ver, e editar/excluir quando resolvido.
/// Diferente da aba Historico (log automatico, so leitura): aqui o conteudo
/// e escrito e mantido manualmente pelos gestores.
class EventAnotacoesTab extends StatefulWidget {
  final String eventId;
  const EventAnotacoesTab({super.key, required this.eventId});

  @override
  State<EventAnotacoesTab> createState() => _EventAnotacoesTabState();
}

class _EventAnotacoesTabState extends State<EventAnotacoesTab> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final client = Supabase.instance.client;
    final rows = await client
        .from("event_notes")
        .select("*, streamer:profiles(id, display_name), author:managers(login_email)")
        .eq("event_id", widget.eventId)
        .order("created_at", ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  void _reload() => setState(() { _future = _load(); });

  String _shortContent(String content) => content.length > 60 ? content.substring(0, 60) + "..." : content;

  void _openForm({Map<String, dynamic>? existing}) {
    showDialog<bool>(context: context, builder: (context) => _NoteFormDialog(eventId: widget.eventId, existing: existing)).then((saved) {
      if (saved == true) _reload();
    });
  }

  Future<void> _delete(Map<String, dynamic> note) async {
    final client = Supabase.instance.client;
    try {
      await client.from("event_notes").delete().eq("id", note["id"]);
      await logEventHistory(eventId: widget.eventId, action: "anotacao_removida", detail: _shortContent(note["content"] as String));
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
            const Text("Anotacoes", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add, size: 16),
              label: const Text("Anotacao"),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
            ),
          ]),
          const SizedBox(height: 4),
          const Text(
            "Mural de observacoes e informacoes relevantes que todos os gestores podem ver. Marque um streamer se for sobre alguem especifico.",
            style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.hasError) return buildEventosLoadError(snapshot.error!);
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final list = snapshot.data!;
                if (list.isEmpty) return const Center(child: Text("Nenhuma anotacao ainda.", style: TextStyle(color: Colors.white54)));
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final n = list[index];
                    final streamer = n["streamer"];
                    final author = n["author"];
                    final createdAt = DateTime.parse(n["created_at"] as String).toLocal().toString().substring(0, 16);
                    final wasEdited = n["updated_at"] != null;
                    return Card(
                      color: Colors.white.withOpacity(0.05),
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (streamer is Map)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: const Color(0xFF7A0BD4).withOpacity(0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFF7A0BD4))),
                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    const Icon(Icons.person, size: 12, color: Color(0xFF7A0BD4)),
                                    const SizedBox(width: 4),
                                    Text(streamer["display_name"] as String? ?? "-", style: const TextStyle(color: Color(0xFF7A0BD4), fontSize: 11, fontWeight: FontWeight.bold)),
                                  ]),
                                ),
                              ),
                            Text(n["content"] as String, style: const TextStyle(color: Colors.white, fontSize: 14)),
                            const SizedBox(height: 8),
                            Row(children: [
                              Expanded(
                                child: Text(
                                  (author is Map ? author["login_email"] as String? ?? "-" : "-") + "  -  " + createdAt + (wasEdited ? " (editado)" : ""),
                                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, size: 16, color: Colors.white38),
                                onPressed: () => _openForm(existing: n),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                visualDensity: VisualDensity.compact,
                              ),
                              const SizedBox(width: 14),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                                onPressed: () => _delete(n),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                visualDensity: VisualDensity.compact,
                              ),
                            ]),
                          ],
                        ),
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

class _NoteFormDialog extends StatefulWidget {
  final String eventId;
  final Map<String, dynamic>? existing;
  const _NoteFormDialog({required this.eventId, this.existing});

  @override
  State<_NoteFormDialog> createState() => _NoteFormDialogState();
}

class _NoteFormDialogState extends State<_NoteFormDialog> {
  late final _contentController = TextEditingController(text: widget.existing?["content"] as String? ?? "");
  Map<String, dynamic>? _streamer;
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final existingStreamer = widget.existing?["streamer"];
    if (existingStreamer is Map) _streamer = Map<String, dynamic>.from(existingStreamer);
  }

  Future<void> _pickStreamer() async {
    final selected = await showDialog<List<Map<String, dynamic>>>(context: context, builder: (context) => const StreamerPickerDialog());
    if (selected != null && selected.isNotEmpty) setState(() => _streamer = selected.first);
  }

  Future<void> _save() async {
    if (_contentController.text.trim().isEmpty) return;
    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser!.id;
      final content = _contentController.text.trim();
      final shortContent = content.length > 60 ? content.substring(0, 60) + "..." : content;

      if (widget.existing != null) {
        await client.from("event_notes").update({
          "streamer_id": _streamer?["id"],
          "content": content,
          "updated_at": DateTime.now().toIso8601String(),
        }).eq("id", widget.existing!["id"]);
        await logEventHistory(eventId: widget.eventId, action: "anotacao_editada", detail: shortContent);
      } else {
        await client.from("event_notes").insert({
          "event_id": widget.eventId,
          "streamer_id": _streamer?["id"],
          "content": content,
          "created_by": userId,
        });
        await logEventHistory(eventId: widget.eventId, action: "anotacao_criada", detail: shortContent);
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _saving = false;
        _errorMessage = "Erro: " + e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 500),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.existing != null ? "Editar anotacao" : "Nova anotacao", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                controller: _contentController,
                maxLines: 5,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: "O que voce quer registrar?", labelStyle: TextStyle(color: Colors.white54)),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickStreamer,
                    icon: const Icon(Icons.person_search, size: 16),
                    label: Text(
                      _streamer != null ? "Streamer: " + (_streamer!["display_name"] as String? ?? "-") : "Marcar streamer (opcional)",
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (_streamer != null) IconButton(icon: const Icon(Icons.close, size: 16, color: Colors.white38), onPressed: () => setState(() => _streamer = null)),
              ]),
              if (_errorMessage != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 12))),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancelar")),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
                  child: Text(_saving ? "Salvando..." : "Salvar"),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
