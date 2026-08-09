import "package:flutter/material.dart";
import "app_splash_media_service.dart";
import "widgets/app_splash_media_form_dialog.dart";

/// Pagina de Carregamento (kind=loading, video que toca assim que o app
/// abre) ou Introducao (kind=intro, video que toca logo em seguida, antes
/// de entrar no app) -- mesmo esquema de janela de horario e ativo/inativo
/// dos fundos da Ilha Top, um banco por kind.
class AppSplashMediaPage extends StatefulWidget {
  const AppSplashMediaPage({super.key, required this.kind, required this.title, required this.helpText});

  final String kind;
  final String title;
  final String helpText;

  @override
  State<AppSplashMediaPage> createState() => _AppSplashMediaPageState();
}

class _AppSplashMediaPageState extends State<AppSplashMediaPage> {
  final _service = AppSplashMediaService();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.fetchMedia(widget.kind);
  }

  void _reload() => setState(() => _future = _service.fetchMedia(widget.kind));

  Future<void> _openForm([Map<String, dynamic>? existing]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AppSplashMediaFormDialog(kind: widget.kind, kindLabel: widget.title, existing: existing),
    );
    if (saved == true) _reload();
  }

  Future<void> _delete(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text("Excluir vídeo?", style: TextStyle(color: Colors.white)),
        content: const Text("Essa ação não pode ser desfeita.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancelar")),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text("Excluir", style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirmed == true) {
      await _service.deleteMedia(id);
      _reload();
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
            Text(widget.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(width: 12),
            IconButton(icon: const Icon(Icons.refresh, color: Colors.white70), onPressed: _reload),
          ]),
          const SizedBox(height: 4),
          Text(widget.helpText, style: const TextStyle(color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic)),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text("Erro ao carregar: " + snapshot.error.toString(), style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center),
                    ),
                  );
                }
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final list = snapshot.data!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(list.length.toString() + " vídeo(s)/imagem(ns) cadastrados", style: const TextStyle(color: Colors.white54)),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: () => _openForm(),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text("Adicionar"),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Expanded(
                      child: list.isEmpty
                          ? const Center(child: Text("Nenhum vídeo cadastrado ainda.", style: TextStyle(color: Colors.white54)))
                          : ListView.builder(
                              itemCount: list.length,
                              itemBuilder: (context, index) {
                                final m = list[index];
                                final active = m["is_active"] as bool? ?? true;
                                return Card(
                                  color: Colors.white.withOpacity(0.05),
                                  margin: const EdgeInsets.only(bottom: 10),
                                  child: ListTile(
                                    leading: Icon(m["media_type"] == "video" ? Icons.movie : Icons.image, color: Colors.white54),
                                    title: Text(m["label"] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    subtitle: Text(
                                      (m["start_time"] as String).substring(0, 5) +
                                          " – " +
                                          (m["end_time"] as String).substring(0, 5) +
                                          "  ·  " +
                                          (m["mode"] == "fixed" ? "Fixo" : "Aleatório") +
                                          (active ? "" : "  ·  inativo"),
                                      style: TextStyle(color: active ? Colors.white54 : Colors.redAccent.withOpacity(0.7), fontSize: 12),
                                    ),
                                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                      IconButton(icon: const Icon(Icons.edit, color: Colors.white54, size: 18), onPressed: () => _openForm(m)),
                                      IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent, size: 18), onPressed: () => _delete(m["id"] as String)),
                                    ]),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
