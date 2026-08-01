import "package:flutter/material.dart";
import "package:fl_chart/fl_chart.dart";
import "package:supabase_flutter/supabase_flutter.dart";

class GestorDashboardPage extends StatefulWidget {
  const GestorDashboardPage({super.key});

  @override
  State<GestorDashboardPage> createState() => _GestorDashboardPageState();
}

class _GestorDashboardPageState extends State<GestorDashboardPage> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;
    final now = DateTime.now();

    final rows = await client
        .from("profiles")
        .select("id, joined_at, is_active, streamer_stats(diamonds)")
        .eq("assigned_manager_id", userId);
    final streamers = (rows as List).cast<Map<String, dynamic>>();

    final total = streamers.length;
    final ativos = streamers.where((s) => s["is_active"] == true).length;

    var diamantesTotal = 0;
    for (final s in streamers) {
      final statsData = s["streamer_stats"];
      if (statsData is List && statsData.isNotEmpty)
        diamantesTotal += statsData.first["diamonds"] as int? ?? 0;
      if (statsData is Map)
        diamantesTotal += statsData["diamonds"] as int? ?? 0;
    }

    var emOnboarding = 0;
    if (streamers.isNotEmpty) {
      final ids = streamers.map((s) => s["id"] as String).toList();
      final leads = await client
          .from("leads")
          .select("id, converted_streamer_id")
          .inFilter("converted_streamer_id", ids);
      final leadIds = (leads as List).map((l) => l["id"] as String).toList();
      if (leadIds.isNotEmpty) {
        final checklists = await client
            .from("lead_onboarding_checklist")
            .select("lead_id, concluido")
            .inFilter("lead_id", leadIds);
        emOnboarding = (checklists as List)
            .where((c) => c["concluido"] != true)
            .length;
      }
    }

    final novosPerMonth = <String, int>{};
    for (var i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i);
      novosPerMonth[month.month.toString().padLeft(2, "0") +
              "/" +
              month.year.toString().substring(2)] =
          0;
    }
    for (final s in streamers) {
      final joined = DateTime.parse(s["joined_at"] as String);
      final key =
          joined.month.toString().padLeft(2, "0") +
          "/" +
          joined.year.toString().substring(2);
      if (novosPerMonth.containsKey(key))
        novosPerMonth[key] = novosPerMonth[key]! + 1;
    }

    return {
      "total": total,
      "ativos": ativos,
      "emOnboarding": emOnboarding,
      "diamantesTotal": diamantesTotal,
      "novosPerMonth": novosPerMonth,
    };
  }

  Widget _metricCard(IconData icon, String label, String value, Color color) {
    return Container(
      width: 190,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.18), Colors.white.withOpacity(0.03)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _barChart(String title, Map<String, int> data) {
    return Container(
      width: 400,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final keys = data.keys.toList();
                        final i = value.toInt();
                        if (i < 0 || i >= keys.length)
                          return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            keys[i],
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 9,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: data.values.toList().asMap().entries.map((e) {
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: e.value.toDouble(),
                        color: const Color(0xFF7A0BD4),
                        width: 18,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                "Dashboard",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white70),
                onPressed: () => setState(() => _future = _load()),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _future,
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                final d = snapshot.data!;
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 14,
                        runSpacing: 14,
                        children: [
                          _metricCard(
                            Icons.groups,
                            "Meus Streamers",
                            d["total"].toString(),
                            Colors.blueAccent,
                          ),
                          _metricCard(
                            Icons.check_circle,
                            "Ativos",
                            d["ativos"].toString(),
                            Colors.greenAccent,
                          ),
                          _metricCard(
                            Icons.hourglass_bottom,
                            "Em Onboarding",
                            d["emOnboarding"].toString(),
                            Colors.amber,
                          ),
                          _metricCard(
                            Icons.diamond,
                            "Diamantes (total)",
                            d["diamantesTotal"].toString(),
                            const Color(0xFF7A0BD4),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _barChart(
                        "Novos streamers por mes (6 meses)",
                        d["novosPerMonth"] as Map<String, int>,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
