import "package:flutter/material.dart";
import "package:fl_chart/fl_chart.dart";
import "package:supabase_flutter/supabase_flutter.dart";

class TeamDashboardPage extends StatefulWidget {
  const TeamDashboardPage({super.key});

  @override
  State<TeamDashboardPage> createState() => _TeamDashboardPageState();
}

class _TeamDashboardPageState extends State<TeamDashboardPage> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final client = Supabase.instance.client;
    final now = DateTime.now();

    final leads = await client.from("leads").select("recruiter_id, created_at, status, converted_at");
    final leadsList = (leads as List).cast<Map<String, dynamic>>();

    final recruiterIds = leadsList.map((l) => l["recruiter_id"] as String).toSet();
    final totalRecrutadores = recruiterIds.length;

    final leadsHoje = leadsList.where((l) {
      final d = DateTime.parse(l["created_at"]);
      return d.year == now.year && d.month == now.month && d.day == now.day;
    }).length;

    final leadsDoMes = leadsList.where((l) {
      final d = DateTime.parse(l["created_at"]);
      return d.year == now.year && d.month == now.month;
    }).length;

    // Recrutamentos contam pelos dados oficiais da planilha (profiles), nao pelo status
    // "agenciado" do kanban de leads, que e apenas o funil interno do recrutador.
    final officialProfiles = await client.from("profiles").select("joined_at, agent_relationship_date");
    final officialProfilesList = (officialProfiles as List).cast<Map<String, dynamic>>();
    String? relDate(Map<String, dynamic> p) => (p["agent_relationship_date"] as String?) ?? (p["joined_at"] as String?);
    final recrutamentosDoMes = officialProfilesList.where((p) {
      final ds = relDate(p);
      if (ds == null) return false;
      final d = DateTime.parse(ds);
      return d.year == now.year && d.month == now.month;
    }).length;

    final targets = await client.from("recruiter_targets").select("target_value, starts_at, ends_at").eq("metric", "agenciamentos").eq("period_type", "mensal");
    double metaGeral = 0;
    for (final t in (targets as List)) {
      final start = DateTime.parse(t["starts_at"]);
      final end = DateTime.parse(t["ends_at"]);
      if (!now.isBefore(start) && !now.isAfter(end)) metaGeral += (t["target_value"] as num).toDouble();
    }
    final metaConcluida = metaGeral == 0 ? 0.0 : (recrutamentosDoMes / metaGeral) * 100;

    double conversaoMedia = 0;
    if (recruiterIds.isNotEmpty) {
      final rates = <double>[];
      for (final rid in recruiterIds) {
        final own = leadsList.where((l) => l["recruiter_id"] == rid).toList();
        final agenciados = own.where((l) => l["status"] == "agenciado").length;
        if (own.isNotEmpty) rates.add((agenciados / own.length) * 100);
      }
      if (rates.isNotEmpty) conversaoMedia = rates.reduce((a, b) => a + b) / rates.length;
    }

    final leadsPerDay = <String, int>{};
    for (var i = 13; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      leadsPerDay[day.day.toString().padLeft(2, "0") + "/" + day.month.toString().padLeft(2, "0")] = 0;
    }
    for (final l in leadsList) {
      final d = DateTime.parse(l["created_at"]);
      if (now.difference(d).inDays > 13) continue;
      final key = d.day.toString().padLeft(2, "0") + "/" + d.month.toString().padLeft(2, "0");
      if (leadsPerDay.containsKey(key)) leadsPerDay[key] = leadsPerDay[key]! + 1;
    }

    final recrutamentosPerWeek = <String, int>{};
    for (var i = 7; i >= 0; i--) {
      final weekStart = now.subtract(Duration(days: now.weekday - 1 + i * 7));
      recrutamentosPerWeek["Sem " + weekStart.day.toString() + "/" + weekStart.month.toString()] = 0;
    }
    for (final p in officialProfilesList) {
      final ds = relDate(p);
      if (ds == null) continue;
      final d = DateTime.parse(ds);
      final diffWeeks = ((now.difference(d).inDays) / 7).floor();
      if (diffWeeks > 7 || diffWeeks < 0) continue;
      final weekStart = now.subtract(Duration(days: now.weekday - 1 + diffWeeks * 7));
      final key = "Sem " + weekStart.day.toString() + "/" + weekStart.month.toString();
      if (recrutamentosPerWeek.containsKey(key)) recrutamentosPerWeek[key] = recrutamentosPerWeek[key]! + 1;
    }

    return {
      "totalRecrutadores": totalRecrutadores,
      "leadsHoje": leadsHoje,
      "leadsDoMes": leadsDoMes,
      "recrutamentosDoMes": recrutamentosDoMes,
      "metaGeral": metaGeral,
      "metaConcluida": metaConcluida,
      "conversaoMedia": conversaoMedia,
      "leadsPerDay": leadsPerDay,
      "recrutamentosPerWeek": recrutamentosPerWeek,
    };
  }

  Widget _metricCard(IconData icon, String label, String value, Color color) {
    return Container(
      width: 190,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [color.withOpacity(0.18), Colors.white.withOpacity(0.03)]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, color: color, size: 18), const SizedBox(width: 6), Expanded(child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)))]),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _barChart(String title, Map<String, int> data) {
    return Container(
      width: 400,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final keys = data.keys.toList();
                        final i = value.toInt();
                        if (i < 0 || i >= keys.length) return const SizedBox.shrink();
                        return Padding(padding: const EdgeInsets.only(top: 6), child: Text(keys[i], style: const TextStyle(color: Colors.white54, fontSize: 9)));
                      },
                    ),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: data.values.toList().asMap().entries.map((e) {
                  return BarChartGroupData(x: e.key, barRods: [BarChartRodData(toY: e.value.toDouble(), color: const Color(0xFF7A0BD4), width: 14, borderRadius: BorderRadius.circular(4))]);
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
          Row(children: [
            const Text("Dashboard da Equipe", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(width: 12),
            IconButton(icon: const Icon(Icons.refresh, color: Colors.white70), onPressed: () => setState(() => _future = _load())),
          ]),
          const SizedBox(height: 20),
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _future,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final d = snapshot.data!;
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(spacing: 14, runSpacing: 14, children: [
                        _metricCard(Icons.groups, "Total de Recrutadores", d["totalRecrutadores"].toString(), Colors.blueAccent),
                        _metricCard(Icons.today, "Leads Criados Hoje", d["leadsHoje"].toString(), Colors.tealAccent),
                        _metricCard(Icons.calendar_month, "Leads do Mes", d["leadsDoMes"].toString(), Colors.amber),
                        _metricCard(Icons.verified, "Recrutamentos do Mes", d["recrutamentosDoMes"].toString(), Colors.greenAccent),
                        _metricCard(Icons.flag, "Meta Geral", (d["metaGeral"] as double).toStringAsFixed(0), Colors.orangeAccent),
                        _metricCard(Icons.check_circle, "Meta Concluida", (d["metaConcluida"] as double).toStringAsFixed(0) + "%", const Color(0xFF7A0BD4)),
                        _metricCard(Icons.percent, "Conversao Media da Equipe", (d["conversaoMedia"] as double).toStringAsFixed(0) + "%", Colors.pinkAccent),
                      ]),
                      const SizedBox(height: 24),
                      Wrap(spacing: 16, runSpacing: 16, children: [
                        _barChart("Leads por dia (14 dias)", d["leadsPerDay"] as Map<String, int>),
                        _barChart("Recrutamentos por semana (8 semanas)", d["recrutamentosPerWeek"] as Map<String, int>),
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
