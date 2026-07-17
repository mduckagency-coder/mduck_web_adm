import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";

class _StreamerRow {
  final String displayName;
  final String? tiktokId;
  final String? categoryName;
  final int diamonds;
  final int daysLive;
  final double hoursLive;

  _StreamerRow({
    required this.displayName,
    required this.tiktokId,
    required this.categoryName,
    required this.diamonds,
    required this.daysLive,
    required this.hoursLive,
  });
}

class CategoriasPage extends StatefulWidget {
  const CategoriasPage({super.key});

  @override
  State<CategoriasPage> createState() => _CategoriasPageState();
}

class _CategoriasPageState extends State<CategoriasPage> {
  String? _categoryFilter;
  String _sortKey = "diamonds";
  bool _ascending = false;
  late Future<List<_StreamerRow>> _future;
  List<Map<String, dynamic>> _categories = [];

  @override
  void initState() {
    super.initState();
    _future = _load();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final client = Supabase.instance.client;
    final rows = await client.from("streamer_categories").select("id, name").order("name");
    setState(() => _categories = (rows as List).cast<Map<String, dynamic>>());
  }

  Future<List<_StreamerRow>> _load() async {
    final client = Supabase.instance.client;
    final rows = await client
        .from("profiles")
        .select("display_name, tiktok_creator_id, streamer_categories(name), streamer_stats(diamonds, days_live, hours_live)")
        .eq("is_active", true);

    return (rows as List).map((r) {
      final statsData = r["streamer_stats"];
      Map<String, dynamic>? stats;
      if (statsData is List && statsData.isNotEmpty) {
        stats = statsData.first as Map<String, dynamic>;
      } else if (statsData is Map) {
        stats = statsData as Map<String, dynamic>;
      }
      final catData = r["streamer_categories"];
      return _StreamerRow(
        displayName: r["display_name"] as String,
        tiktokId: r["tiktok_creator_id"] as String?,
        categoryName: catData is Map ? catData["name"] as String? : null,
        diamonds: stats?["diamonds"] as int? ?? 0,
        daysLive: stats?["days_live"] as int? ?? 0,
        hoursLive: (stats?["hours_live"] as num?)?.toDouble() ?? 0,
      );
    }).toList();
  }

  List<_StreamerRow> _filterAndSort(List<_StreamerRow> all) {
    var list = _categoryFilter == null ? all : all.where((s) => s.categoryName == _categoryFilter).toList();
    list.sort((a, b) {
      int result;
      switch (_sortKey) {
        case "nick":
          result = a.displayName.compareTo(b.displayName);
          break;
        case "dias":
          result = a.daysLive.compareTo(b.daysLive);
          break;
        case "horas":
          result = a.hoursLive.compareTo(b.hoursLive);
          break;
        default:
          result = a.diamonds.compareTo(b.diamonds);
      }
      return _ascending ? result : -result;
    });
    return list;
  }

  Widget _sortHeader(String label, String key, {int flex = 1}) {
    final active = _sortKey == key;
    return Expanded(
      flex: flex,
      child: InkWell(
        onTap: () => setState(() {
          if (_sortKey == key) {
            _ascending = !_ascending;
          } else {
            _sortKey = key;
            _ascending = false;
          }
        }),
        child: Row(
          children: [
            Text(label, style: TextStyle(color: active ? Colors.white : Colors.white54, fontWeight: active ? FontWeight.bold : FontWeight.normal)),
            const SizedBox(width: 2),
            Icon(active ? (_ascending ? Icons.arrow_upward : Icons.arrow_downward) : Icons.unfold_more, size: 14, color: active ? Colors.white : Colors.white24),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_StreamerRow>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final filtered = _filterAndSort(snapshot.data!);

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text("Categorias", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(width: 12),
                  IconButton(icon: const Icon(Icons.refresh, color: Colors.white70), onPressed: () => setState(() => _future = _load())),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text("Todos"),
                    selected: _categoryFilter == null,
                    selectedColor: const Color(0xFF7A0BD4),
                    labelStyle: TextStyle(color: _categoryFilter == null ? Colors.white : Colors.white70),
                    onSelected: (_) => setState(() => _categoryFilter = null),
                  ),
                  ..._categories.map((c) {
                    final selected = _categoryFilter == c["name"];
                    return ChoiceChip(
                      label: Text(c["name"] as String),
                      selected: selected,
                      selectedColor: const Color(0xFF7A0BD4),
                      labelStyle: TextStyle(color: selected ? Colors.white : Colors.white70),
                      onSelected: (_) => setState(() => _categoryFilter = c["name"] as String),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 12),
              Text(filtered.length.toString() + " streamers", style: const TextStyle(color: Colors.white54)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white24))),
                child: Row(
                  children: [
                    const SizedBox(width: 44),
                    _sortHeader("Nick", "nick", flex: 3),
                    const Expanded(flex: 2, child: Text("Categoria", style: TextStyle(color: Colors.white54))),
                    _sortHeader("Diamantes", "diamonds", flex: 2),
                    _sortHeader("Dias", "dias", flex: 1),
                    _sortHeader("Horas", "horas", flex: 1),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final s = filtered[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              const CircleAvatar(radius: 18, backgroundColor: Colors.white24, child: Icon(Icons.person, color: Colors.white54, size: 18)),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(s.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    if (s.tiktokId != null) Text(s.tiktokId!, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                  ],
                                ),
                              ),
                              Expanded(flex: 2, child: Text(s.categoryName ?? "-", style: const TextStyle(color: Colors.white70, fontSize: 12))),
                              Expanded(flex: 2, child: Text(s.diamonds.toString(), style: const TextStyle(color: Color(0xFF7A0BD4), fontWeight: FontWeight.bold))),
                              Expanded(flex: 1, child: Text(s.daysLive.toString(), style: const TextStyle(color: Colors.white70))),
                              Expanded(flex: 1, child: Text(s.hoursLive.toStringAsFixed(0), style: const TextStyle(color: Colors.white70))),
                            ],
                          ),
                        ),
                        const Divider(color: Colors.white12, height: 1),
                      ],
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
