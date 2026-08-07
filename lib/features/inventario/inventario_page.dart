import "package:flutter/material.dart";
import "inventario_service.dart";
import "models/inventory_entry.dart";
import "widgets/inventory_app_settings_dialog.dart";
import "widgets/inventory_entry_form_dialog.dart";

class InventarioPage extends StatefulWidget {
  const InventarioPage({super.key});

  @override
  State<InventarioPage> createState() => _InventarioPageState();
}

class _InventarioPageState extends State<InventarioPage> {
  final _service = InventarioService();
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _streamers = [];
  Map<String, dynamic>? _selectedStreamer;
  List<InventoryEntry> _entries = [];
  InventoryCategory? _categoryFilter;

  bool _loadingStreamers = true;
  bool _loadingEntries = false;

  @override
  void initState() {
    super.initState();
    _loadStreamers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStreamers() async {
    setState(() => _loadingStreamers = true);
    final rows = await _service.fetchStreamers(search: _searchController.text);
    if (!mounted) return;
    setState(() {
      _streamers = rows;
      _loadingStreamers = false;
      if (_selectedStreamer != null && !rows.any((s) => s["id"] == _selectedStreamer!["id"])) {
        _selectedStreamer = null;
        _entries = [];
      }
    });
  }

  Future<void> _selectStreamer(Map<String, dynamic> streamer) async {
    setState(() {
      _selectedStreamer = streamer;
      _categoryFilter = null;
    });
    await _loadEntries();
  }

  Future<void> _loadEntries() async {
    if (_selectedStreamer == null) return;
    setState(() => _loadingEntries = true);
    final rows = await _service.fetchEntries(streamerId: _selectedStreamer!["id"] as String, category: _categoryFilter);
    if (mounted) {
      setState(() {
        _entries = rows;
        _loadingEntries = false;
      });
    }
  }

  Future<void> _openAddEntry() async {
    if (_selectedStreamer == null) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => InventoryEntryFormDialog(
        streamerId: _selectedStreamer!["id"] as String,
        streamerName: _selectedStreamer!["display_name"] as String? ?? "Streamer",
        initialCategory: _categoryFilter ?? InventoryCategory.conquista,
      ),
    );
    if (saved == true) _loadEntries();
  }

  Future<void> _deleteEntry(InventoryEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text("Excluir registro", style: TextStyle(color: Colors.white)),
        content: Text("Excluir \"" + entry.title + "\" do inventário?", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancelar")),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text("Excluir", style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirmed == true) {
      await _service.deleteEntry(entry.id);
      _loadEntries();
    }
  }

  Widget _streamerTile(Map<String, dynamic> streamer) {
    final selected = _selectedStreamer != null && _selectedStreamer!["id"] == streamer["id"];
    final avatarUrl = streamer["avatar_url"] as String?;
    final tiktokUsername = streamer["tiktok_username"] as String?;
    return Container(
      color: selected ? const Color(0xFF7A0BD4).withOpacity(0.15) : null,
      child: ListTile(
        dense: true,
        selected: selected,
        onTap: () => _selectStreamer(streamer),
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: Colors.white24,
          backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
          child: avatarUrl == null || avatarUrl.isEmpty ? const Icon(Icons.person, color: Colors.white70, size: 16) : null,
        ),
        title: Text(streamer["display_name"] as String? ?? "", style: TextStyle(color: selected ? const Color(0xFF7A0BD4) : Colors.white, fontSize: 13, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
        subtitle: Text(tiktokUsername != null ? "@" + tiktokUsername : "", style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ),
    );
  }

  Widget _entryCard(InventoryEntry entry) {
    final color = inventoryCategoryColor(entry.category);
    final dateLabel = entry.occurredAt.day.toString().padLeft(2, "0") + "/" + entry.occurredAt.month.toString().padLeft(2, "0") + "/" + entry.occurredAt.year.toString();
    return Card(
      color: const Color(0xFF1A1A1A),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (entry.imageUrl != null && entry.imageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(entry.imageUrl!, width: 56, height: 56, fit: BoxFit.cover),
              )
            else
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                child: Icon(inventoryCategoryIcon(entry.category), color: color, size: 24),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                      child: Text(inventoryCategoryLabel(entry.category), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    Text(inventoryCategoryVerb(entry.category), style: const TextStyle(color: Colors.white54, fontSize: 11, fontStyle: FontStyle.italic)),
                    const Spacer(),
                    if (entry.points != null)
                      Text("+" + entry.points.toString() + " XP", style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 4),
                  Text(entry.title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                  if (entry.description != null && entry.description!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(entry.description!, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                  const SizedBox(height: 4),
                  Text(dateLabel, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),
            IconButton(
              onPressed: () => _deleteEntry(entry),
              icon: const Icon(Icons.delete_outline, color: Colors.white38, size: 18),
              tooltip: "Excluir",
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailPane() {
    if (_selectedStreamer == null) {
      return const Center(child: Text("Selecione um streamer para ver o inventário.", style: TextStyle(color: Colors.white54)));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: Text(_selectedStreamer!["display_name"] as String? ?? "", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton.icon(
            onPressed: _openAddEntry,
            icon: const Icon(Icons.add),
            label: const Text("Adicionar"),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
          ),
        ]),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text("Todos"),
              selected: _categoryFilter == null,
              onSelected: (_) {
                setState(() => _categoryFilter = null);
                _loadEntries();
              },
              selectedColor: const Color(0xFF7A0BD4),
              backgroundColor: const Color(0xFF1A1A1A),
              labelStyle: TextStyle(color: _categoryFilter == null ? Colors.white : Colors.white70),
            ),
            ...InventoryCategory.values.map((c) {
              final selected = _categoryFilter == c;
              return ChoiceChip(
                avatar: Icon(inventoryCategoryIcon(c), size: 14, color: selected ? Colors.white : inventoryCategoryColor(c)),
                label: Text(inventoryCategoryLabel(c)),
                selected: selected,
                onSelected: (_) {
                  setState(() => _categoryFilter = c);
                  _loadEntries();
                },
                selectedColor: inventoryCategoryColor(c),
                backgroundColor: const Color(0xFF1A1A1A),
                labelStyle: TextStyle(color: selected ? Colors.white : Colors.white70),
              );
            }),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _loadingEntries
              ? const Center(child: CircularProgressIndicator())
              : _entries.isEmpty
                  ? const Center(child: Text("Nenhum registro por aqui ainda.", style: TextStyle(color: Colors.white54)))
                  : ListView(children: _entries.map(_entryCard).toList()),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text("Inventário", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: () => showDialog(context: context, builder: (_) => const InventoryAppSettingsDialog()),
              icon: const Icon(Icons.settings, size: 16, color: Colors.white70),
              label: const Text("Configuração tela app", style: TextStyle(color: Colors.white70)),
            ),
          ]),
          const SizedBox(height: 4),
          const Text(
            "Treinamentos, acompanhamentos, premiações e conquistas de cada streamer — o que aparece pra ele no aplicativo.",
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 280,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(prefixIcon: Icon(Icons.search, color: Colors.white54), hintText: "Buscar por nick ou ID", hintStyle: TextStyle(color: Colors.white38), isDense: true),
                        onChanged: (_) => _loadStreamers(),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _loadingStreamers
                            ? const Center(child: CircularProgressIndicator())
                            : _streamers.isEmpty
                                ? const Center(child: Text("Nenhum streamer encontrado.", style: TextStyle(color: Colors.white54)))
                                : ListView(children: _streamers.map(_streamerTile).toList()),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                const VerticalDivider(color: Colors.white24, width: 1),
                const SizedBox(width: 20),
                Expanded(child: _detailPane()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
