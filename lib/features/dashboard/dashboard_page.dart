import "package:flutter/material.dart";
import "package:fl_chart/fl_chart.dart";
import "package:supabase_flutter/supabase_flutter.dart";

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final client = Supabase.instance.client;

    final profiles = await client
        .from("profiles")
        .select("id, display_name, joined_at, last_live_at, streamer_stats(days_live, hours_live, diamonds)")
        .eq("is_active", true);

    final monthlyRows = await client
        .from("monthly_stats")
        .select("streamer_id, period_key, diamonds, hours_live, days_live")
        .order("period_key", ascending: false);
    final lastMonthMap = <String, Map<String, dynamic>>{};
    final cumulativeDaysMap = <String, int>{};
    for (final m in (monthlyRows as List)) {
      final sid = m["streamer_id"] as String;
      if (!lastMonthMap.containsKey(sid)) lastMonthMap[sid] = m;
      cumulativeDaysMap[sid] = (cumulativeDaysMap[sid] ?? 0) + ((m["days_live"] as int?) ?? 0);
    }

    final now = DateTime.now();
    int totalDiamondsAtual = 0;
    double totalHorasAtual = 0;
    int totalDiamondsPassado = 0;
    double totalHorasPassado = 0;
    int novosAgenciados = 0;
    int inativos = 0;

    final streamers = <Map<String, dynamic>>[];

    for (final p in (profiles as List)) {
      final statsData = p["streamer_stats"];
      Map<String, dynamic>? stats;
      if (statsData is List && statsData.isNotEmpty) {
        stats = statsData.first as Map<String, dynamic>;
      } else if (statsData is Map) {
        stats = statsData as Map<String, dynamic>;
      }
      final diamonds = stats?["diamonds"] as int? ?? 0;
      final hours = (stats?["hours_live"] as num?)?.toDouble() ?? 0;
      final daysCurrentMonth = stats?["days_live"] as int? ?? 0;
      final cumulativeDays = (cumulativeDaysMap[p["id"]] ?? 0) + daysCurrentMonth;

      totalDiamondsAtual += diamonds;
      totalHorasAtual += hours;

      final past = lastMonthMap[p["id"]];
      totalDiamondsPassado += (past?["diamonds"] as int?) ?? 0;
      totalHorasPassado += (past?["hours_live"] as num?)?.toDouble()?.toInt() ?? 0;

      final joinedAt = DateTime.parse(p["joined_at"] as String);
      if (joinedAt.year == now.year && joinedAt.month == now.month) novosAgenciados++;

      final lastLiveText = p["last_live_at"] as String?;
      if (lastLiveText != null) {
        final daysSince = now.toUtc().difference(DateTime.parse(lastLiveText)).inDays;
        if (daysSince > 3) inativos++;
      }

      streamers.add({"display_name": p["display_name"], "days": daysCurrentMonth, "cumulativeDays": cumulativeDays, "hours": hours, "diamonds": diamonds});
    }

    final allByDiamonds = [...streamers]..sort((a, b) => (b["diamonds"] as int).compareTo(a["diamonds"] as int));
    final allByHoras = [...streamers]..sort((a, b) => (b["hours"] as double).compareTo(a["hours"] as double));
    final topDiasAcumulado = [...streamers]..sort((a, b) => (b["cumulativeDays"] as int).compareTo(a["cumulativeDays"] as int));

    double pctChange(num atual, num passado) {
      if (passado == 0) return 0;
      return ((atual - passado) / passado) * 100;
    }

    return {
      "totalDiamondsAtual": totalDiamondsAtual,
      "totalDiamondsPassado": totalDiamondsPassado,
      "diamondsChange": pctChange(totalDiamondsAtual, totalDiamondsPassado),
      "totalHorasAtual": totalHorasAtual,
      "totalHorasPassado": totalHorasPassado,
      "horasChange": pctChange(totalHorasAtual, totalHorasPassado),
      "novosAgenciados": novosAgenciados,
      "inativos": inativos,
      "allByDiamonds": allByDiamonds,
      "allByHoras": allByHoras,
      "topDiasAcumulado": topDiasAcumulado.take(10).toList(),
      "totalStreamers": streamers.length,
    };
  }

  Widget _metricCard(IconData icon, String label, String value, Color color, {String? change}) {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [color.withOpacity(0.18), Colors.white.withOpacity(0.03)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, color: color, size: 20), const SizedBox(width: 8), Expanded(child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)))]),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(color: color, fontSize: 26, fontWeight: FontWeight.bold)),
          if (change != null) ...[
            const SizedBox(height: 4),
            Row(children: [
              Icon(change.startsWith("-") ? Icons.trending_down : Icons.trending_up, size: 14, color: change.startsWith("-") ? Colors.redAccent : Colors.greenAccent),
              const SizedBox(width: 4),
              Text(change, style: TextStyle(color: change.startsWith("-") ? Colors.redAccent : Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _comparisonChart(String title, double passado, double atual, Color color) {
    final maxVal = (passado > atual ? passado : atual) * 1.2;
    return Container(
      width: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            child: BarChart(
              BarChartData(
                maxY: maxVal == 0 ? 10 : maxVal,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final label = value == 0 ? "Mes passado" : "Mes atual";
                        return Padding(padding: const EdgeInsets.only(top: 6), child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)));
                      },
                    ),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: [
                  BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: passado, color: Colors.white38, width: 40, borderRadius: BorderRadius.circular(6))]),
                  BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: atual, color: color, width: 40, borderRadius: BorderRadius.circular(6))]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rankSection(String title, IconData icon, Color color, List<dynamic> all, String Function(Map) valueBuilder, {bool fullScroll = true}) {
    final top10 = all.take(10).toList();
    return Container(
      width: 340,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15))),
            if (fullScroll) Text(all.length.toString() + " no total", style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ]),
          const SizedBox(height: 10),
          SizedBox(
            height: fullScroll ? 420 : (top10.length * 34.0).clamp(0, 340),
            child: ListView.builder(
              itemCount: fullScroll ? all.length : top10.length,
              itemBuilder: (context, i) {
                final s = (fullScroll ? all : top10)[i] as Map;
                final medalColor = i == 0 ? Colors.amber : i == 1 ? Colors.grey.shade300 : i == 2 ? const Color(0xFFCD7F32) : Colors.white12;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: medalColor.withOpacity(i < 3 ? 1 : 0.2)),
                        child: Text("#" + (i + 1).toString(), style: TextStyle(color: i < 3 ? Colors.black : Colors.white54, fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                      const SizedBox(width: 8),
                      const CircleAvatar(radius: 13, backgroundColor: Colors.white24, child: Icon(Icons.person, color: Colors.white54, size: 13)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(s["display_name"] as String, style: const TextStyle(color: Colors.white, fontSize: 13))),
                      Text(valueBuilder(s), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text("Dashboard", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(width: 12),
            IconButton(icon: const Icon(Icons.refresh, color: Colors.white70), onPressed: () => setState(() => _future = _load())),
          ]),
          const SizedBox(height: 4),
          const Text("Visao geral da agencia", style: TextStyle(color: Colors.white54)),
          const SizedBox(height: 20),
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _future,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final d = snapshot.data!;
                String pctText(double v) => (v >= 0 ? "+" : "") + v.toStringAsFixed(0) + "%";

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(spacing: 16, runSpacing: 16, children: [
                        _metricCard(Icons.diamond, "Diamantes (mes atual)", d["totalDiamondsAtual"].toString(), const Color(0xFF7A0BD4), change: pctText(d["diamondsChange"])),
                        _metricCard(Icons.access_time, "Horas de live (mes atual)", (d["totalHorasAtual"] as double).toStringAsFixed(0), Colors.orangeAccent, change: pctText(d["horasChange"])),
                        _metricCard(Icons.people, "Streamers ativos", d["totalStreamers"].toString(), Colors.greenAccent),
                        _metricCard(Icons.person_add, "Novos agenciados (mes)", d["novosAgenciados"].toString(), Colors.blueAccent),
                        _metricCard(Icons.warning_amber, "Inativos (3+ dias)", d["inativos"].toString(), Colors.redAccent),
                      ]),
                      const SizedBox(height: 28),
                      Wrap(spacing: 16, runSpacing: 16, children: [
                        _comparisonChart("Diamantes: mes passado vs atual", (d["totalDiamondsPassado"] as int).toDouble(), (d["totalDiamondsAtual"] as int).toDouble(), const Color(0xFF7A0BD4)),
                        _comparisonChart("Horas: mes passado vs atual", d["totalHorasPassado"] as double, d["totalHorasAtual"] as double, Colors.orangeAccent),
                      ]),
                      const SizedBox(height: 28),
                      const Text("Rankings (prioridade: Diamantes e Horas - com lista completa)", style: TextStyle(color: Colors.white54, fontSize: 12, fontStyle: FontStyle.italic)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 16, runSpacing: 16, children: [
                        _rankSection("Diamantes - Todos", Icons.diamond, const Color(0xFF7A0BD4), d["allByDiamonds"] as List, (m) => m["diamonds"].toString()),
                        _rankSection("Horas - Todos", Icons.access_time, Colors.orangeAccent, d["allByHoras"] as List, (m) => (m["hours"] as double).toStringAsFixed(0) + "h"),
                        _rankSection("Dias Ativos (acumulado, todos os meses)", Icons.calendar_today, Colors.greenAccent, d["topDiasAcumulado"] as List, (m) => m["cumulativeDays"].toString() + "d", fullScroll: false),
                      ]),
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
