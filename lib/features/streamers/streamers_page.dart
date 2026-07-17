import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";

class _StreamerRow {
  final String id;
  final String displayName;
  final String? tiktokId;
  final String? categoryName;
  final String? groupName;
  final bool isActive;
  final DateTime joinedAt;
  final int daysLive;
  final double hoursLive;
  final int diamonds;
  final DateTime? lastLiveAt;
  final double? trendPercent;

  _StreamerRow({
    required this.id,
    required this.displayName,
    required this.tiktokId,
    required this.categoryName,
    required this.groupName,
    required this.isActive,
    required this.joinedAt,
    required this.daysLive,
    required this.hoursLive,
    required this.diamonds,
    required this.lastLiveAt,
    required this.trendPercent,
  });
}

class StreamersPage extends StatefulWidget {
  const StreamersPage({super.key});

  @override
  State<StreamersPage> createState() => _StreamersPageState();
}

class _StreamersPageState extends State<StreamersPage> {
  late Future<List<_StreamerRow>> _future;
  String _search = "";
  String? _categoryFilter;
  String? _groupFilter;
  bool _onlyActive = true;
  String _trendFilter = "todos";
  String _sortKey = "diamonds";
  bool _ascending = false;

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _groups = [];

  @override
  void initState() {
    super.initState();
    _future = _load();
    _loadFilterOptions();
  }

  Future<void> _loadFilterOptions() async {
    final client = Supabase.instance.client;
    final categories = await client.from("streamer_categories").select("id, name").order("name");
    final groups = await client.from("groups").select("id, name").order("name");
    setState(() {
      _categories = (categories as List).cast<Map<String, dynamic>>();
      _groups = (groups as List).cast<Map<String, dynamic>>();
    });
  }

  Future<List<_StreamerRow>> _load() async {
    final client = Supabase.instance.client;
    final rows = await client.from("profiles").select(
        "id, display_name, tiktok_creator_id, is_active, joined_at, streamer_categories(name), groups!profiles_group_id_fkey(name), streamer_stats(days_live, hours_live, diamonds)");

    final monthlyRows = await client
        .from("monthly_stats")
        .select("streamer_id, period_key, diamonds")
        .order("period_key", ascending: false);
    final lastMonthMap = <String, int>{};
    for (final m in (monthlyRows as List)) {
      final sid = m["streamer_id"] as String;
      if (!lastMonthMap.containsKey(sid)) {
        lastMonthMap[sid] = m["diamonds"] as int? ?? 0;
      }
    }

    return (rows as List).map((r) {
      final statsData = r["streamer_stats"];
      Map<String, dynamic>? stats;
      if (statsData is List && statsData.isNotEmpty) {
        stats = statsData.first as Map<String, dynamic>;
      } else if (statsData is Map) {
        stats = statsData as Map<String, dynamic>;
      }
      final diamonds = stats?["diamonds"] as int? ?? 0;
      final id = r["id"] as String;
      final lastMonthDiamonds = lastMonthMap[id];

      double? trend;
      if (lastMonthDiamonds != null && lastMonthDiamonds > 0) {
        trend = ((diamonds - lastMonthDiamonds) / lastMonthDiamonds) * 100;
      }

      final catData = r["streamer_categories"];
      final groupData = r["groups"];

      return _StreamerRow(
        id: id,
        displayName: r["display_name"] as String,
        tiktokId: r["tiktok_creator_id"] as String?,
        categoryName: catData is Map ? catData["name"] as String? : null,
        groupName: groupData is Map ? groupData["name"] as String? : null,
        isActive: r["is_active"] as bool? ?? true,
        joinedAt: DateTime.parse(r["joined_at"] as String),
        daysLive: stats?["days_live"] as int? ?? 0,
        hoursLive: (stats?["hours_live"] as num?)?.toDouble() ?? 0,
        diamonds: diamonds,
        lastLiveAt: null,
        trendPercent: trend,
      );
    }).toList();
  }

  (String, Color) _trendLabel(double? trend) {
    if (trend == null) return ("Sem dado", Colors.white38);
    if (trend > 10) return ("Em alta", Colors.greenAccent);
    if (trend < -10) return ("Em queda", Colors.redAccent);
    return ("Estavel", Colors.amber);
  }

  List<_StreamerRow> _filterAndSort(List<_StreamerRow> all) {
    var list = all.where((s) {
      if (_onlyActive && !s.isActive) return false;
      if (_search.isNotEmpty && !s.displayName.toLowerCase().contains(_search.toLowerCase())) return false;
      if (_categoryFilter != null && s.categoryName != _categoryFilter) return false;
      if (_groupFilter != null && s.groupName != _groupFilter) return false;
      if (_trendFilter != "todos") {
        final label = _trendLabel(s.trendPercent).$1;
        if (_trendFilter == "alta" && label != "Em alta") return false;
        if (_trendFilter == "queda" && label != "Em queda") return false;
        if (_trendFilter == "estavel" && label != "Estavel") return false;
      }
      return true;
    }).toList();

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
        case "tendencia":
          result = (a.trendPercent ?? -999).compareTo(b.trendPercent ?? -999);
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
                  const Text("Streamers", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(width: 12),
                  IconButton(icon: const Icon(Icons.refresh, color: Colors.white70), onPressed: () => setState(() => _future = _load())),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 220,
                    child: TextField(
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.search, color: Colors.white54), hintText: "Buscar nick", hintStyle: TextStyle(color: Colors.white38), isDense: true),
                      onChanged: (v) => setState(() => _search = v),
                    ),
                  ),
                  DropdownButton<String?>(
                    value: _categoryFilter,
                    hint: const Text("Categoria", style: TextStyle(color: Colors.white54)),
                    dropdownColor: const Color(0xFF1A1A1A),
                    style: const TextStyle(color: Colors.white),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text("Todas categorias")),
                      ..._categories.map((c) => DropdownMenuItem<String?>(value: c["name"] as String, child: Text(c["name"] as String))),
                    ],
                    onChanged: (v) => setState(() => _categoryFilter = v),
                  ),
                  DropdownButton<String?>(
                    value: _groupFilter,
                    hint: const Text("Grupo", style: TextStyle(color: Colors.white54)),
                    dropdownColor: const Color(0xFF1A1A1A),
                    style: const TextStyle(color: Colors.white),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text("Todos os grupos")),
                      ..._groups.map((g) => DropdownMenuItem<String?>(value: g["name"] as String, child: Text(g["name"] as String))),
                    ],
                    onChanged: (v) => setState(() => _groupFilter = v),
                  ),
                  FilterChip(
                    label: const Text("Somente ativos"),
                    selected: _onlyActive,
                    onSelected: (v) => setState(() => _onlyActive = v),
                    selectedColor: const Color(0xFF7A0BD4),
                    labelStyle: TextStyle(color: _onlyActive ? Colors.white : Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ("todos", "Todos"),
                  ("alta", "Em alta"),
                  ("estavel", "Estavel"),
                  ("queda", "Em queda"),
                ].map((t) {
                  final selected = _trendFilter == t.$1;
                  return ChoiceChip(
                    label: Text(t.$2, style: const TextStyle(fontSize: 12)),
                    selected: selected,
                    selectedColor: const Color(0xFF7A0BD4),
                    labelStyle: TextStyle(color: selected ? Colors.white : Colors.white70),
                    onSelected: (_) => setState(() => _trendFilter = t.$1),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Text(filtered.length.toString() + " streamers", style: const TextStyle(color: Colors.white54)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white24))),
                child: Row(
                  children: [
                    const SizedBox(width: 44),
                    _sortHeader("Nick", "nick", flex: 3),
                    const Expanded(flex: 2, child: Text("Categoria / Grupo", style: TextStyle(color: Colors.white54))),
                    _sortHeader("Diamantes", "diamonds", flex: 2),
                    _sortHeader("Dias", "dias", flex: 1),
                    _sortHeader("Horas", "horas", flex: 1),
                    _sortHeader("Tendencia", "tendencia", flex: 2),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final s = filtered[index];
                    final trend = _trendLabel(s.trendPercent);
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
                              Expanded(
                                flex: 2,
                                child: Text(
                                  (s.categoryName ?? "-") + " / " + (s.groupName ?? "Sem grupo"),
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ),
                              Expanded(flex: 2, child: Text(s.diamonds.toString(), style: const TextStyle(color: Color(0xFF7A0BD4), fontWeight: FontWeight.bold))),
                              Expanded(flex: 1, child: Text(s.daysLive.toString(), style: const TextStyle(color: Colors.white70))),
                              Expanded(flex: 1, child: Text(s.hoursLive.toStringAsFixed(0), style: const TextStyle(color: Colors.white70))),
                              Expanded(
                                flex: 2,
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(border: Border.all(color: trend.$2), borderRadius: BorderRadius.circular(6)),
                                      child: Text(trend.$1, style: TextStyle(color: trend.$2, fontSize: 11)),
                                    ),
                                    if (s.trendPercent != null) ...[
                                      const SizedBox(width: 4),
                                      Text((s.trendPercent! > 0 ? "+" : "") + s.trendPercent!.toStringAsFixed(0) + "%", style: TextStyle(color: trend.$2, fontSize: 11)),
                                    ],
                                  ],
                                ),
                              ),
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
