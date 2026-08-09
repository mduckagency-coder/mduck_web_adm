import "package:flutter/material.dart";
import "../ilha_top_service.dart";
import "ilha_avatar_form_dialog.dart";

/// Banco de avatares "pato" que o streamer escolhe no app dele.
class IlhaAvatarsTab extends StatefulWidget {
  const IlhaAvatarsTab({super.key});

  @override
  State<IlhaAvatarsTab> createState() => _IlhaAvatarsTabState();
}

const _rarityColors = {
  "comum": Colors.white54,
  "classico": Colors.lightBlueAccent,
  "raro": Colors.tealAccent,
  "epico": Colors.purpleAccent,
  "lendario": Colors.amber,
};

class _IlhaAvatarsTabState extends State<IlhaAvatarsTab> {
  final _service = IlhaTopService();
  late Future<List<Map<String, dynamic>>> _future;
  Map<String, String> _categoryNames = {};

  @override
  void initState() {
    super.initState();
    _future = _service.fetchAvatars();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final categories = await _service.fetchCategories();
    if (mounted) setState(() => _categoryNames = {for (final c in categories) c["id"] as String: c["name"] as String});
  }

  void _reload() => setState(() => _future = _service.fetchAvatars());

  String _rarityLabel(String? key) => islandAvatarRarities.firstWhere((r) => r.$1 == key, orElse: () => ("comum", "Comum")).$2;

  Future<void> _openForm([Map<String, dynamic>? existing]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => IlhaAvatarFormDialog(existing: existing),
    );
    if (saved == true) _reload();
  }

  Future<void> _delete(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text("Excluir avatar?", style: TextStyle(color: Colors.white)),
        content: const Text("Streamers que já escolheram esse avatar perdem a escolha. Essa ação não pode ser desfeita.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancelar")),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text("Excluir", style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirmed == true) {
      await _service.deleteAvatar(id);
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
                Text(list.length.toString() + " avatar(es) cadastrados", style: const TextStyle(color: Colors.white54)),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => _openForm(),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text("Adicionar avatar"),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
                ),
              ]),
              const SizedBox(height: 8),
              Expanded(
                child: list.isEmpty
                    ? const Center(child: Text("Nenhum avatar cadastrado ainda.", style: TextStyle(color: Colors.white54)))
                    : GridView.builder(
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 240, mainAxisExtent: 168, crossAxisSpacing: 10, mainAxisSpacing: 10),
                        itemCount: list.length,
                        itemBuilder: (context, index) {
                          final a = list[index];
                          final active = a["is_active"] as bool? ?? true;
                          final rarity = a["rarity"] as String? ?? "comum";
                          final gender = a["gender"] as String?;
                          final minDiamonds = a["min_diamonds"] as int? ?? 0;
                          final catIds = (a["category_ids"] as List?)?.cast<String>() ?? const [];
                          final catLabel = catIds.isEmpty ? "Todas as categorias" : catIds.map((id) => _categoryNames[id] ?? "?").join(", ");
                          return Card(
                            color: Colors.white.withOpacity(0.05),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    const Icon(Icons.movie, color: Colors.white54, size: 18),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(a["label"] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                                    ),
                                  ]),
                                  const SizedBox(height: 6),
                                  Wrap(spacing: 4, runSpacing: 4, children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(border: Border.all(color: _rarityColors[rarity] ?? Colors.white54), borderRadius: BorderRadius.circular(4)),
                                      child: Text(_rarityLabel(rarity), style: TextStyle(color: _rarityColors[rarity] ?? Colors.white54, fontSize: 10)),
                                    ),
                                    if (gender != null)
                                      Icon(gender == "feminino" ? Icons.female : Icons.male, color: Colors.white54, size: 14),
                                    if (!active)
                                      const Text("inativo", style: TextStyle(color: Colors.redAccent, fontSize: 11)),
                                  ]),
                                  const SizedBox(height: 4),
                                  if (minDiamonds > 0)
                                    Text(minDiamonds.toString() + "+ diamantes", style: const TextStyle(color: Colors.white54, fontSize: 11)),
                                  Text(catLabel, style: const TextStyle(color: Colors.white38, fontSize: 11), overflow: TextOverflow.ellipsis, maxLines: 1),
                                  const Spacer(),
                                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                                    IconButton(icon: const Icon(Icons.edit, color: Colors.white54, size: 16), onPressed: () => _openForm(a), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                                    const SizedBox(width: 12),
                                    IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent, size: 16), onPressed: () => _delete(a["id"] as String), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                                  ]),
                                ],
                              ),
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
