import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";

class _StreamerRow {
  final String displayName;
  final String? categoryName;
  final int diamonds;
  final int daysLive;
  final int cumulativeDays;
  final double hoursLive;
  final int battles;

  _StreamerRow({
    required this.displayName,
    required this.categoryName,
    required this.diamonds,
    required this.daysLive,
    required this.cumulativeDays,
    required this.hoursLive,
    required this.battles,
  });
}

class RankingPage extends StatefulWidget {
  const RankingPage({super.key});

  @override
  State<RankingPage> createState() => _RankingPageState();
}

class _RankingPageState extends State<RankingPage> {
  String _metric = "diamonds";
  String? _categoryFilter;
  late Future<List<_StreamerRow>> _future;
  List<Map<String, dynamic>> _categories = [];

  static const _metrics = [
    ("diamonds", "Diamantes", Icons.diamond, Color(0xFF7A0BD4)),
    ("horas", "Horas", Icons.access_time, Colors.orangeAccent),
    ("dias", "Dias (acumulado)", Icons.calendar_today, Colors.greenAccent),
    ("batalhas", "Batalhas", Icons.sports_mma, Colors.redAccent),
  ];

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
        .select("id, display_name, streamer_categories(name), streamer_stats(diamonds, days_live, hours_live, battles)")
        .eq("is_active", true);

    final monthlyRows = await client.from("monthly_stats").select("streamer_id, days_live");
    final cumulativeMap = <String, int>{};
    for (final m in (monthlyRows as List)) {
      final sid = m["streamer_id"] as String;
      cumulativeMap[sid] = (cumulativeMap[sid] ?? 0) + ((m["days_live"] as int?) ?? 0);
    }

    return (rows as List).map((r) {
      final statsData = r["streamer_stats"];
      Map<String, dynamic>? stats;
      if (statsData is List && statsData.isNotEmpty) {
        stats = statsData.first as Map<String, dynamic>;
      } else if (statsData is Map) {
        stats = statsData as Map<String, dynamic>;
      }
      final catData = r["streamer_categories"];
      final daysLive = stats?["days_live"] as int? ?? 0;
      return _StreamerRow(
        displayName: r["display_name"] as String,
        categoryName: catData is Map ? catData["name"] as String? : null,
        diamonds: stats?["diamonds"] as int? ?? 0,
        daysLive: daysLive,
        cumulativeDays: (cumulativeMap[r["id"]] ?? 0) + daysLive,
        hoursLive: (stats?["hours_live"] as num?)?.toDouble() ?? 0,
        battles: stats?["battles"] as int? ?? 0,
      );
    }).toList();
  }

  num _valueFor(_StreamerRow s) {
    switch (_metric) {
      case "horas":
        return s.hoursLive;
      case "dias":
        return s.cumulativeDays;
      case "batalhas":
        return s.battles;
      default:
        return s.diamonds;
    }
  }

  List<_StreamerRow> _filterAndSort(List<_StreamerRow> all) {
    var list = _categoryFilter == null ? all : all.where((s) => s.categoryName == _categoryFilter).toList();
    list.sort((a, b) => _valueFor(b).compareTo(_valueFor(a)));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final metricInfo = _metrics.firstWhere((m) => m.$1 == _metric);

    return FutureBuilder<List<_StreamerRow>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final ranked = _filterAndSort(snapshot.data!);

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text("Ranking", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(width: 12),
                  IconButton(icon: const Icon(Icons.refresh, color: Colors.white70), onPressed: () => setState(() => _future = _load())),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: _metrics.map((m) {
                  final selected = _metric == m.$1;
                  return ChoiceChip(
                    avatar: Icon(m.$3, size: 16, color: selected ? Colors.white : m.$4),
                    label: Text(m.$2),
                    selected: selected,
                    selectedColor: m.$4,
                    labelStyle: TextStyle(color: selected ? Colors.white : Colors.white70),
                    onSelected: (_) => setState(() => _metric = m.$1),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text("Geral (todas categorias)"),
                    selected: _categoryFilter == null,
                    selectedColor: Colors.white24,
                    onSelected: (_) => setState(() => _categoryFilter = null),
                  ),
                  ..._categories.map((c) {
                    final selected = _categoryFilter == c["name"];
                    return ChoiceChip(
                      label: Text(c["name"] as String),
                      selected: selected,
                      selectedColor: Colors.white24,
                      onSelected: (_) => setState(() => _categoryFilter = c["name"] as String),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  itemCount: ranked.length,
                  itemBuilder: (context, index) {
                    final s = ranked[index];
                    final isTop3 = index < 3;
                    final medalColor = index == 0 ? Colors.amber : index == 1 ? Colors.grey.shade300 : index == 2 ? const Color(0xFFCD7F32) : Colors.white24;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isTop3 ? metricInfo.$4.withOpacity(0.12) : Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(10),
                        border: isTop3 ? Border.all(color: metricInfo.$4.withOpacity(0.6)) : null,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: medalColor.withOpacity(isTop3 ? 1 : 0.2)),
                            child: Text("#" + (index + 1).toString(), style: TextStyle(color: isTop3 ? Colors.black : Colors.white70, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                          const SizedBox(width: 12),
                          const CircleAvatar(radius: 16, backgroundColor: Colors.white24, child: Icon(Icons.person, color: Colors.white54, size: 16)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                if (s.categoryName != null) Text(s.categoryName!, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                              ],
                            ),
                          ),
                          Text(_valueFor(s).toString(), style: TextStyle(color: metricInfo.$4, fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
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

