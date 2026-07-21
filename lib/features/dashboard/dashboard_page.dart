import "package:flutter/material.dart";
import "package:fl_chart/fl_chart.dart";
import "package:supabase_flutter/supabase_flutter.dart";

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

String _periodKey(DateTime d) => d.year.toString() + "-" + d.month.toString().padLeft(2, "0");
const streamers80kThreshold = 80000;

class _DashboardPageState extends State<DashboardPage> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;
    final me = await client.from("managers").select("agency_id, financial_role").eq("id", userId).maybeSingle();
    final agencyId = me?["agency_id"] as String?;
    final isDono = me?["financial_role"] == "dono";
    final now = DateTime.now();
    final periodKey = _periodKey(now);
    Map<String, dynamic>? goals;
    if (agencyId != null) {
      try {
        goals = await client.from("agency_goals").select().eq("agency_id", agencyId).eq("period_key", periodKey).maybeSingle();
      } catch (_) {
        // Table not migrated yet on this environment -- fall back to no goals
        // set instead of breaking the whole dashboard for everyone.
        goals = null;
      }
    }

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

    final streamersComLive = streamers.where((s) => (s["days"] as int) > 0).length;
    final liveOpenPct = streamers.isEmpty ? 0.0 : (streamersComLive / streamers.length) * 100;
    final streamers80k = streamers.where((s) => (s["diamonds"] as int) >= streamers80kThreshold).length;

    return {
      "isDono": isDono,
      "agencyId": agencyId,
      "periodKey": periodKey,
      "diamondsGoal": (goals?["diamonds_goal"] as num?)?.toDouble(),
      "recruitmentGoal": goals?["recruitment_goal"] as int?,
      "liveOpenPctGoal": (goals?["live_open_pct_goal"] as num?)?.toDouble(),
      "streamers80kGoal": goals?["streamers_80k_goal"] as int?,
      "liveOpenPct": liveOpenPct,
      "streamers80k": streamers80k,
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

  void _openEditGoals(Map<String, dynamic> d) {
    showDialog(
      context: context,
      builder: (context) => _EditGoalsDialog(
        agencyId: d["agencyId"] as String,
        periodKey: d["periodKey"] as String,
        diamondsGoal: d["diamondsGoal"] as double?,
        recruitmentGoal: d["recruitmentGoal"] as int?,
        liveOpenPctGoal: d["liveOpenPctGoal"] as double?,
        streamers80kGoal: d["streamers80kGoal"] as int?,
      ),
    ).then((saved) {
      if (saved == true) setState(() => _future = _load());
    });
  }

  Widget _goalCard(String label, IconData icon, Color color, double atual, double? meta, String Function(double) fmt) {
    final hasGoal = meta != null && meta > 0;
    final fraction = hasGoal ? (atual / meta).clamp(0.0, 1.0) : 0.0;
    return Container(
      width: 240,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withOpacity(0.4))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, color: color, size: 18), const SizedBox(width: 6), Expanded(child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)))]),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Text(fmt(atual), style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
            Text(" / " + (hasGoal ? fmt(meta) : "sem meta"), style: const TextStyle(color: Colors.white38, fontSize: 13)),
          ]),
          const SizedBox(height: 8),
          ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: hasGoal ? fraction : 0, minHeight: 6, backgroundColor: Colors.white12, valueColor: AlwaysStoppedAnimation(color))),
        ],
      ),
    );
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
                if (snapshot.hasError) return Center(child: Text("Erro ao carregar: " + snapshot.error.toString(), style: const TextStyle(color: Colors.redAccent)));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final d = snapshot.data!;
                String pctText(double v) => (v >= 0 ? "+" : "") + v.toStringAsFixed(0) + "%";

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Text("Metas do Mes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        const Spacer(),
                        if (d["isDono"] == true)
                          TextButton.icon(onPressed: () => _openEditGoals(d), icon: const Icon(Icons.edit, size: 16), label: const Text("Editar metas")),
                      ]),
                      const SizedBox(height: 12),
                      Wrap(spacing: 16, runSpacing: 16, children: [
                        _goalCard("Diamantes", Icons.diamond, const Color(0xFF7A0BD4), (d["totalDiamondsAtual"] as int).toDouble(), d["diamondsGoal"] as double?, (v) => v.toStringAsFixed(0)),
                        _goalCard("Recrutamento", Icons.person_add, Colors.blueAccent, (d["novosAgenciados"] as int).toDouble(), (d["recruitmentGoal"] as int?)?.toDouble(), (v) => v.toStringAsFixed(0)),
                        _goalCard("Abertura de live", Icons.live_tv, Colors.orangeAccent, d["liveOpenPct"] as double, d["liveOpenPctGoal"] as double?, (v) => v.toStringAsFixed(0) + "%"),
                        _goalCard("Streamers acima de " + streamers80kThreshold.toString(), Icons.diamond_outlined, Colors.greenAccent, (d["streamers80k"] as int).toDouble(), (d["streamers80kGoal"] as int?)?.toDouble(), (v) => v.toStringAsFixed(0)),
                      ]),
                      const SizedBox(height: 28),
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

class _EditGoalsDialog extends StatefulWidget {
  final String agencyId;
  final String periodKey;
  final double? diamondsGoal;
  final int? recruitmentGoal;
  final double? liveOpenPctGoal;
  final int? streamers80kGoal;
  const _EditGoalsDialog({
    required this.agencyId,
    required this.periodKey,
    this.diamondsGoal,
    this.recruitmentGoal,
    this.liveOpenPctGoal,
    this.streamers80kGoal,
  });

  @override
  State<_EditGoalsDialog> createState() => _EditGoalsDialogState();
}

class _EditGoalsDialogState extends State<_EditGoalsDialog> {
  late final _diamondsController = TextEditingController(text: widget.diamondsGoal?.toStringAsFixed(0) ?? "");
  late final _recruitmentController = TextEditingController(text: widget.recruitmentGoal?.toString() ?? "");
  late final _liveOpenPctController = TextEditingController(text: widget.liveOpenPctGoal?.toStringAsFixed(0) ?? "");
  late final _streamers80kController = TextEditingController(text: widget.streamers80kGoal?.toString() ?? "");
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser!.id;
      await client.from("agency_goals").upsert({
        "agency_id": widget.agencyId,
        "period_key": widget.periodKey,
        "diamonds_goal": double.tryParse(_diamondsController.text.trim()),
        "recruitment_goal": int.tryParse(_recruitmentController.text.trim()),
        "live_open_pct_goal": double.tryParse(_liveOpenPctController.text.trim()),
        "streamers_80k_goal": int.tryParse(_streamers80kController.text.trim()),
        "updated_at": DateTime.now().toIso8601String(),
        "updated_by": userId,
      }, onConflict: "agency_id,period_key");
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Editar metas do mes", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(controller: _diamondsController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Meta de diamantes", labelStyle: TextStyle(color: Colors.white54))),
              const SizedBox(height: 8),
              TextField(controller: _recruitmentController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Meta de recrutamento (novos agenciados)", labelStyle: TextStyle(color: Colors.white54))),
              const SizedBox(height: 8),
              TextField(controller: _liveOpenPctController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Meta de abertura de live (%)", labelStyle: TextStyle(color: Colors.white54))),
              const SizedBox(height: 8),
              TextField(controller: _streamers80kController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "Meta de streamers acima de " + streamers80kThreshold.toString(), labelStyle: const TextStyle(color: Colors.white54))),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text("Erro ao salvar: " + _error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
              ],
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancelar")),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                  child: Text(_saving ? "Salvando..." : "Salvar"),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
