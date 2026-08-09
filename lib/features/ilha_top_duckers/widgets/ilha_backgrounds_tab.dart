import "package:flutter/material.dart";
import "../ilha_top_service.dart";
import "ilha_background_form_dialog.dart";

/// Banco de videos/imagens de fundo da Ilha Top: pelo menos 4, ilimitado
/// pra adicionar. Cada um tem uma janela de horario e modo fixo/aleatorio.
class IlhaBackgroundsTab extends StatefulWidget {
  const IlhaBackgroundsTab({super.key});

  @override
  State<IlhaBackgroundsTab> createState() => _IlhaBackgroundsTabState();
}

class _IlhaBackgroundsTabState extends State<IlhaBackgroundsTab> {
  final _service = IlhaTopService();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.fetchBackgrounds();
  }

  void _reload() => setState(() => _future = _service.fetchBackgrounds());

  Future<void> _openForm([Map<String, dynamic>? existing]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => IlhaBackgroundFormDialog(existing: existing),
    );
    if (saved == true) _reload();
  }

  Future<void> _delete(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text("Excluir vídeo de fundo?", style: TextStyle(color: Colors.white)),
        content: const Text("Essa ação não pode ser desfeita.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancelar")),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text("Excluir", style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirmed == true) {
      await _service.deleteBackground(id);
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final list = snapshot.data!;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(list.length.toString() + " vídeo(s)/imagem(ns) de fundo cadastrados", style: const TextStyle(color: Colors.white54)),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => _openForm(),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text("Adicionar vídeo de fundo"),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
                ),
              ]),
              const SizedBox(height: 8),
              if (list.length < 4)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    "Recomendado cadastrar pelo menos 4 fundos cobrindo diferentes horários do dia.",
                    style: const TextStyle(color: Colors.amberAccent, fontSize: 12),
                  ),
                ),
              Expanded(
                child: list.isEmpty
                    ? const Center(child: Text("Nenhum fundo cadastrado ainda.", style: TextStyle(color: Colors.white54)))
                    : ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (context, index) {
                          final b = list[index];
                          final active = b["is_active"] as bool? ?? true;
                          return Card(
                            color: Colors.white.withOpacity(0.05),
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: Icon(b["media_type"] == "video" ? Icons.movie : Icons.image, color: Colors.white54),
                              title: Text(b["label"] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                (b["start_time"] as String).substring(0, 5) +
                                    " – " +
                                    (b["end_time"] as String).substring(0, 5) +
                                    "  ·  " +
                                    (b["mode"] == "fixed" ? "Fixo" : "Aleatório") +
                                    (active ? "" : "  ·  inativo"),
                                style: TextStyle(color: active ? Colors.white54 : Colors.redAccent.withOpacity(0.7), fontSize: 12),
                              ),
                              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                IconButton(icon: const Icon(Icons.edit, color: Colors.white54, size: 18), onPressed: () => _openForm(b)),
                                IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent, size: 18), onPressed: () => _delete(b["id"] as String)),
                              ]),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
