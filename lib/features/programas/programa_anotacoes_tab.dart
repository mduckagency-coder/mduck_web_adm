import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "programa_history_helpers.dart";

/// Bloco de notas livre do programa -- sem ciclo/mes, so uma lista
/// cronologica continua de anotacoes do gestor (no lugar do antigo slot de
/// Campanhas Mensais nesta tela; o sistema de campanhas em si continua
/// existindo no banco/codigo, so nao fica mais acessivel por aqui).
class ProgramaAnotacoesTab extends StatefulWidget {
  final Map<String, dynamic> program;
  const ProgramaAnotacoesTab({super.key, required this.program});

  @override
  State<ProgramaAnotacoesTab> createState() => _ProgramaAnotacoesTabState();
}

class _ProgramaAnotacoesTabState extends State<ProgramaAnotacoesTab> {
  late Future<List<Map<String, dynamic>>> _future;
  final _controller = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final client = Supabase.instance.client;
    final rows = await client
        .from("program_notes")
        .select("id, body, created_at, author:managers(login_email)")
        .eq("program_id", widget.program["id"])
        .order("created_at", ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _add() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _saving = true);
    try {
      final client = Supabase.instance.client;
      await client.from("program_notes").insert({
        "program_id": widget.program["id"],
        "agency_id": widget.program["agency_id"],
        "author_id": client.auth.currentUser?.id,
        "body": text,
      });
      _controller.clear();
      _reload();
    } catch (e) {
      if (mounted) showProgramasActionError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(String id) async {
    final ok = await confirmAction(context, title: "Excluir anotacao", message: "Excluir esta anotacao? Essa acao nao pode ser desfeita.", confirmLabel: "Excluir", confirmColor: Colors.redAccent);
    if (!ok) return;
    try {
      await Supabase.instance.client.from("program_notes").delete().eq("id", id);
      _reload();
    } catch (e) {
      if (mounted) showProgramasActionError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Anotacoes", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text("Bloco de notas livre do programa -- registre acordos, pendencias ou observacoes gerais.", style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic)),
          const SizedBox(height: 16),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(hintText: "Escrever uma anotacao...", hintStyle: TextStyle(color: Colors.white38)),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _saving ? null : _add,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
              child: Text(_saving ? "Salvando..." : "Adicionar"),
            ),
          ]),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.hasError) return buildProgramasLoadError(snapshot.error!);
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final list = snapshot.data!;
                if (list.isEmpty) return const Center(child: Text("Nenhuma anotacao ainda.", style: TextStyle(color: Colors.white54)));
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final note = list[index];
                    final author = note["author"];
                    final email = author is Map ? author["login_email"] as String? : null;
                    final date = note["created_at"] != null ? DateTime.parse(note["created_at"] as String).toLocal().toString().substring(0, 16) : "-";
                    return Card(
                      color: Colors.white.withOpacity(0.05),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(note["body"] as String, style: const TextStyle(color: Colors.white, fontSize: 13)),
                                const SizedBox(height: 6),
                                Text(date + (email != null ? "  -  " + email : ""), style: const TextStyle(color: Colors.white38, fontSize: 11)),
                              ],
                            ),
                          ),
                          IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Colors.white38), onPressed: () => _delete(note["id"] as String)),
                        ]),
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
