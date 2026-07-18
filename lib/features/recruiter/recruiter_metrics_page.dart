import "package:flutter/material.dart";
import "package:fl_chart/fl_chart.dart";
import "package:supabase_flutter/supabase_flutter.dart";

class RecruiterMetricsPage extends StatefulWidget {
  const RecruiterMetricsPage({super.key});

  @override
  State<RecruiterMetricsPage> createState() => _RecruiterMetricsPageState();
}

class _RecruiterMetricsPageState extends State<RecruiterMetricsPage> {
  late Future<Map<String, dynamic>> _future;
  late Future<List<Map<String, dynamic>>> _missionsFuture;
  String _periodo = "dia";

  @override
  void initState() {
    super.initState();
    _future = _load();
    _missionsFuture = _loadMissions();
  }

  Future<List<Map<String, dynamic>>> _loadMissions() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;
    final now = DateTime.now();

    final myMissionIds = await client.from("recruiter_mission_assignees").select("mission_id").eq("recruiter_id", userId);
    final idsSet = (myMissionIds as List).map((m) => m["mission_id"] as String).toSet();

    final allActive = await client.from("recruiter_missions").select().eq("is_active", true);
    final missionsList = (allActive as List).cast<Map<String, dynamic>>().where((m) => m["scope"] == "geral" || idsSet.contains(m["id"])).toList();

    final leads = await client.from("leads").select("status, created_at, converted_at, category_interest").eq("recruiter_id", userId);
    final leadsList = (leads as List).cast<Map<String, dynamic>>();

    final categoryTargetsAll = await client.from("recruiter_mission_category_targets").select();
    final categoryTargetsList = (categoryTargetsAll as List).cast<Map<String, dynamic>>();

    int countLeadsSince(DateTime since) => leadsList.where((l) => DateTime.parse(l["created_at"]).isAfter(since)).length;
    int countAgenciadosSince(DateTime since) => leadsList.where((l) {
          if (l["status"] != "agenciado" || l["converted_at"] == null) return false;
          return DateTime.parse(l["converted_at"]).isAfter(since);
        }).length;

    final today = DateTime(now.year, now.month, now.day);
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);

    for (final m in missionsList) {
      m["progressLeadsDia"] = countLeadsSince(today);
      m["progressLeadsSemana"] = countLeadsSince(DateTime(weekStart.year, weekStart.month, weekStart.day));
      m["progressLeadsMes"] = countLeadsSince(monthStart);
      m["progressAgDia"] = countAgenciadosSince(today);
      m["progressAgSemana"] = countAgenciadosSince(DateTime(weekStart.year, weekStart.month, weekStart.day));
      m["progressAgMes"] = countAgenciadosSince(monthStart);

      final myTargets = categoryTargetsList.where((c) => c["mission_id"] == m["id"]).toList();
      for (final ct in myTargets) {
        ct["progress"] = leadsList.where((l) => l["category_interest"] == ct["category_name"] && DateTime.parse(l["created_at"]).isAfter(monthStart)).length;
      }
      m["myCategoryTargets"] = myTargets;
    }

    return missionsList;
  }

  String? relevantDate(Map<String, dynamic> p) => (p["agent_relationship_date"] as String?) ?? (p["joined_at"] as String?);

  Future<Map<String, dynamic>> _load() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final me = await client.from("managers").select("login_email").eq("id", userId).single();
    final myEmail = me["login_email"] as String;

    final leads = await client.from("leads").select("id, status, created_at, updated_at").eq("recruiter_id", userId);
    final leadsList = (leads as List).cast<Map<String, dynamic>>();
    final totalLeads = leadsList.length;

    final leadsHoje = leadsList.where((l) => DateTime.parse(l["created_at"]).isAfter(today)).length;
    final leadsSemana = leadsList.where((l) => now.difference(DateTime.parse(l["created_at"])).inDays < 7).length;
    final leadsMes = leadsList.where((l) {
      final d = DateTime.parse(l["created_at"]);
      return d.year == now.year && d.month == now.month;
    }).length;

    final targets = await client.from("recruiter_targets").select().or("recruiter_id.eq." + userId + ",recruiter_id.is.null").eq("metric", "leads");
    double metaDiaria = 0, metaSemanal = 0, metaMensal = 0;
    for (final t in (targets as List)) {
      final start = DateTime.parse(t["starts_at"]);
      final end = DateTime.parse(t["ends_at"]);
      if (now.isBefore(start) || now.isAfter(end)) continue;
      if (t["period_type"] == "diario") metaDiaria = (t["target_value"] as num).toDouble();
      if (t["period_type"] == "semanal") metaSemanal = (t["target_value"] as num).toDouble();
      if (t["period_type"] == "mensal") metaMensal = (t["target_value"] as num).toDouble();
    }

    // Dados oficiais da planilha (agenciamentos confirmados)
    final officialRows = await client
        .from("profiles")
        .select("id, joined_at, agent_relationship_date")
        .or("tiktok_agent_email.ilike." + myEmail + ",recruited_by_manager_id.eq." + userId);
    final officialListRaw = (officialRows as List).cast<Map<String, dynamic>>();
    final officialList = officialListRaw.where((p) => relevantDate(p) != null).toList()
      ..sort((a, b) => relevantDate(a)!.compareTo(relevantDate(b)!));
    final totalAgenciamentos = officialList.length;
    final agenciamentosHoje = officialList.where((p) => DateTime.parse(relevantDate(p)!).isAfter(today)).length;
    final agenciamentosSemana = officialList.where((p) => now.difference(DateTime.parse(relevantDate(p)!)).inDays < 7).length;
    final agenciamentosMes = officialList.where((p) {
      final d = DateTime.parse(relevantDate(p)!);
      return d.year == now.year && d.month == now.month;
    }).length;

    final conversao = totalLeads == 0 ? 0.0 : (totalAgenciamentos / totalLeads) * 100;

    double tempoMedio = 0;
    if (officialList.length >= 2) {
      final datas = officialList.map((p) => DateTime.parse(relevantDate(p)!)).toList()..sort();
      final gaps = <double>[];
      for (var i = 1; i < datas.length; i++) {
        gaps.add(datas[i].difference(datas[i - 1]).inHours / 24.0);
      }
      tempoMedio = gaps.reduce((a, b) => a + b) / gaps.length;
    }

    final slaRows = await client.from("lead_status_sla").select();
    final slaMap = {for (final s in (slaRows as List)) s["status"] as String: (s["max_hours"] as num).toDouble()};

    final pendencias = <Map<String, dynamic>>[];
    for (final l in leadsList) {
      if (l["status"] == "agenciado" || l["status"] == "recusado") continue;
      final maxHours = slaMap[l["status"]];
      if (maxHours == null) continue;
      final hoursSince = now.difference(DateTime.parse(l["updated_at"])).inMinutes / 60.0;
      if (hoursSince > maxHours) pendencias.add({"leadId": l["id"], "status": l["status"], "hoursSince": hoursSince});
    }

    final feedbacksPendentes = await client.from("recruiter_feedbacks").select("id").eq("recruiter_id", userId).eq("status", "pendente");

    return {
      "leadsHoje": leadsHoje,
      "leadsSemana": leadsSemana,
      "leadsMes": leadsMes,
      "totalLeads": totalLeads,
      "metaDiaria": metaDiaria,
      "metaSemanal": metaSemanal,
      "metaMensal": metaMensal,
      "agenciamentosHoje": agenciamentosHoje,
      "agenciamentosSemana": agenciamentosSemana,
      "agenciamentosMes": agenciamentosMes,
      "totalAgenciamentos": totalAgenciamentos,
      "conversao": conversao,
      "tempoMedio": tempoMedio,
      "pendencias": pendencias,
      "feedbacksPendentes": (feedbacksPendentes as List).length,
      "officialList": officialList,
    };
  }

  Map<String, int> _groupedCounts(List<Map<String, dynamic>> officialList) {
    final counts = <String, int>{};
    final now = DateTime.now();
    if (_periodo == "dia") {
      for (var i = 6; i >= 0; i--) {
        final day = now.subtract(Duration(days: i));
        counts[day.day.toString().padLeft(2, "0") + "/" + day.month.toString().padLeft(2, "0")] = 0;
      }
      for (final p in officialList) {
        final d = DateTime.parse((p["agent_relationship_date"] as String?) ?? p["joined_at"]);
        if (now.difference(d).inDays > 6) continue;
        final key = d.day.toString().padLeft(2, "0") + "/" + d.month.toString().padLeft(2, "0");
        if (counts.containsKey(key)) counts[key] = counts[key]! + 1;
      }
    } else if (_periodo == "semana") {
      for (var i = 5; i >= 0; i--) {
        final weekStart = now.subtract(Duration(days: now.weekday - 1 + i * 7));
        counts["Sem " + weekStart.day.toString() + "/" + weekStart.month.toString()] = 0;
      }
      for (final p in officialList) {
        final d = DateTime.parse((p["agent_relationship_date"] as String?) ?? p["joined_at"]);
        final diffWeeks = ((now.difference(d).inDays) / 7).floor();
        if (diffWeeks > 5 || diffWeeks < 0) continue;
        final weekStart = now.subtract(Duration(days: now.weekday - 1 + diffWeeks * 7));
        final key = "Sem " + weekStart.day.toString() + "/" + weekStart.month.toString();
        if (counts.containsKey(key)) counts[key] = counts[key]! + 1;
      }
    } else {
      for (var i = 4; i >= 0; i--) {
        final month = DateTime(now.year, now.month - i);
        counts[month.month.toString().padLeft(2, "0") + "/" + month.year.toString()] = 0;
      }
      for (final p in officialList) {
        final d = DateTime.parse((p["agent_relationship_date"] as String?) ?? p["joined_at"]);
        final key = d.month.toString().padLeft(2, "0") + "/" + d.year.toString();
        if (counts.containsKey(key)) counts[key] = counts[key]! + 1;
      }
    }
    return counts;
  }

  (String, Color) _indicator(double atual, double meta) {
    if (meta == 0) return ("\u26aa", Colors.white38);
    final pct = (atual / meta) * 100;
    if (pct >= 100) return ("\ud83d\udfe2", Colors.greenAccent);
    if (pct >= 70) return ("\ud83d\udfe1", Colors.amber);
    return ("\ud83d\udd34", Colors.redAccent);
  }

  Widget _metricCard(IconData icon, String label, String value, Color color) {
    return Container(
      width: 175,
      height: 110,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [color.withOpacity(0.16), Colors.white.withOpacity(0.03)]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Expanded(child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis)),
          ]),
          const Spacer(),
          Text(value, style: TextStyle(color: color, fontSize: 21, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          const Text("Atualizado agora", style: TextStyle(color: Colors.white24, fontSize: 9)),
        ],
      ),
    );
  }

  Widget _metaBarCompact(String label, int atual, double meta) {
    final fraction = meta == 0 ? 0.0 : (atual / meta).clamp(0.0, 1.0);
    final pct = meta == 0 ? 0 : ((atual / meta) * 100).clamp(0, 100).round();
    final falta = (meta - atual).clamp(0, meta).toStringAsFixed(0);
    final indicator = _indicator(atual.toDouble(), meta);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(indicator.$1, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 6),
            Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold))),
            Text(atual.toString() + " / " + meta.toStringAsFixed(0), style: TextStyle(color: indicator.$2, fontSize: 13, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: fraction),
              duration: const Duration(milliseconds: 600),
              builder: (context, value, _) => LinearProgressIndicator(value: value, minHeight: 8, backgroundColor: Colors.white12, valueColor: AlwaysStoppedAnimation(indicator.$2)),
            ),
          ),
          const SizedBox(height: 6),
          Row(children: [
            Text(pct.toString() + "%", style: TextStyle(color: indicator.$2, fontSize: 11, fontWeight: FontWeight.bold)),
            const Spacer(),
            if (meta > 0 && atual < meta) Text("Faltam " + falta, style: const TextStyle(color: Colors.white38, fontSize: 11)),
            if (meta > 0 && atual >= meta) const Text("Meta concluida!", style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
          ]),
        ],
      ),
    );
  }

  String _motivationalMessage(Map<String, dynamic> d) {
    final leadsHoje = d["leadsHoje"] as int;
    final metaDiaria = d["metaDiaria"] as double;
    if (metaDiaria > 0 && leadsHoje >= metaDiaria) return "Parabens! Voce atingiu sua meta diaria.";
    if (metaDiaria > 0 && leadsHoje < metaDiaria) return "Faltam " + (metaDiaria - leadsHoje).toStringAsFixed(0) + " leads para concluir sua meta de hoje.";
    if ((d["pendencias"] as List).isNotEmpty) return "Voce possui atividades pendentes que precisam de atencao.";
    return "Continue assim, seu trabalho esta sendo acompanhado!";
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text("Minhas Metricas", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(width: 12),
            IconButton(icon: const Icon(Icons.refresh, color: Colors.white70), onPressed: () => setState(() => _future = _load())),
          ]),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _future,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final d = snapshot.data!;
                final pendencias = d["pendencias"] as List<Map<String, dynamic>>;
                final officialList = (d["officialList"] as List).cast<Map<String, dynamic>>();
                final grouped = _groupedCounts(officialList);

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: const Color(0xFF7A0BD4).withOpacity(0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF7A0BD4))),
                        child: Text(_motivationalMessage(d), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 20),
                      Wrap(spacing: 14, runSpacing: 14, children: [
                        _metricCard(Icons.person_add, "Leads Hoje", d["leadsHoje"].toString(), Colors.blueAccent),
                        _metricCard(Icons.calendar_view_week, "Leads Semana", d["leadsSemana"].toString(), Colors.blueAccent),
                        _metricCard(Icons.calendar_month, "Leads Mes", d["leadsMes"].toString(), Colors.blueAccent),
                        _metricCard(Icons.verified, "Agenciamentos Hoje", d["agenciamentosHoje"].toString(), Colors.greenAccent),
                        _metricCard(Icons.verified_user, "Agenciamentos Semana", d["agenciamentosSemana"].toString(), Colors.greenAccent),
                        _metricCard(Icons.emoji_events, "Agenciamentos Mes", d["agenciamentosMes"].toString(), Colors.greenAccent),
                        _metricCard(Icons.percent, "Conversao", (d["conversao"] as double).toStringAsFixed(0) + "%", const Color(0xFF7A0BD4)),
                        _metricCard(Icons.timelapse, "Tempo Medio entre Agenciamentos", (d["tempoMedio"] as double).toStringAsFixed(1) + " dias", Colors.orangeAccent),
                        _metricCard(Icons.warning_amber, "Pendencias", pendencias.length.toString(), pendencias.isEmpty ? Colors.greenAccent : Colors.redAccent),
                        _metricCard(Icons.feedback, "Feedbacks Pendentes", d["feedbacksPendentes"].toString(), (d["feedbacksPendentes"] as int) == 0 ? Colors.greenAccent : Colors.amber),
                      ]),
                      const SizedBox(height: 24),
                      const Text("Metas", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 10),
                      _metaBarCompact("Meta diaria (leads)", d["leadsHoje"] as int, d["metaDiaria"] as double),
                      _metaBarCompact("Meta semanal (leads)", d["leadsSemana"] as int, d["metaSemanal"] as double),
                      _metaBarCompact("Meta mensal (leads)", d["leadsMes"] as int, d["metaMensal"] as double),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              const Text("Evolucao de Agenciamentos", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                              const Spacer(),
                              ...["dia", "semana", "mes"].map((p) {
                                final selected = _periodo == p;
                                return Padding(
                                  padding: const EdgeInsets.only(left: 6),
                                  child: ChoiceChip(
                                    label: Text(p == "dia" ? "Por dia" : p == "semana" ? "Por semana" : "Por mes", style: const TextStyle(fontSize: 11)),
                                    selected: selected,
                                    selectedColor: const Color(0xFF7A0BD4),
                                    labelStyle: TextStyle(color: selected ? Colors.white : Colors.white70),
                                    onSelected: (_) => setState(() => _periodo = p),
                                  ),
                                );
                              }),
                            ]),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 180,
                              child: BarChart(
                                BarChartData(
                                  barTouchData: BarTouchData(
                                    enabled: true,
                                    touchTooltipData: BarTouchTooltipData(
                                      getTooltipColor: (group) => const Color(0xFF7A0BD4),
                                      getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(rod.toY.toInt().toString(), const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                  titlesData: FlTitlesData(
                                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        getTitlesWidget: (value, meta) {
                                          final keys = grouped.keys.toList();
                                          final i = value.toInt();
                                          if (i < 0 || i >= keys.length) return const SizedBox.shrink();
                                          return Padding(padding: const EdgeInsets.only(top: 6), child: Text(keys[i], style: const TextStyle(color: Colors.white54, fontSize: 9)));
                                        },
                                      ),
                                    ),
                                  ),
                                  gridData: const FlGridData(show: false),
                                  borderData: FlBorderData(show: false),
                                  barGroups: grouped.values.toList().asMap().entries.map((e) {
                                    return BarChartGroupData(x: e.key, barRods: [BarChartRodData(toY: e.value.toDouble(), color: const Color(0xFF7A0BD4), width: 14, borderRadius: BorderRadius.circular(4))]);
                                  }).toList(),
                                ),
                                swapAnimationDuration: const Duration(milliseconds: 400),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text("Missoes Ativas", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      FutureBuilder<List<Map<String, dynamic>>>(
                        future: _missionsFuture,
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                          final missions = snapshot.data!;
                          if (missions.isEmpty) return const Text("Nenhuma missao atribuida no momento.", style: TextStyle(color: Colors.white54, fontSize: 13));
                          return Column(
                            children: missions.map((m) {
                              final rows = <Widget>[];
                              void addRow(String label, num? target, int progress) {
                                if (target == null) return;
                                final fraction = target == 0 ? 0.0 : (progress / target).clamp(0.0, 1.0);
                                rows.add(Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 3),
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Row(children: [
                                      Expanded(child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12))),
                                      Text(progress.toString() + " / " + target.toStringAsFixed(0), style: const TextStyle(color: Color(0xFF7A0BD4), fontSize: 12, fontWeight: FontWeight.bold)),
                                    ]),
                                    ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: fraction, minHeight: 5, backgroundColor: Colors.white12, valueColor: const AlwaysStoppedAnimation(Color(0xFF7A0BD4)))),
                                  ]),
                                ));
                              }
                              addRow("Leads por dia", m["leads_dia"] as num?, m["progressLeadsDia"] as int);
                              addRow("Leads por semana", m["leads_semana"] as num?, m["progressLeadsSemana"] as int);
                              addRow("Leads por mes", m["leads_mes"] as num?, m["progressLeadsMes"] as int);
                              addRow("Agenciamentos por dia", m["agenciamentos_dia"] as num?, m["progressAgDia"] as int);
                              addRow("Agenciamentos por semana", m["agenciamentos_semana"] as num?, m["progressAgSemana"] as int);
                              addRow("Agenciamentos por mes", m["agenciamentos_mes"] as num?, m["progressAgMes"] as int);
                              final categoryTargets = (m["myCategoryTargets"] as List).cast<Map<String, dynamic>>();
                              for (final ct in categoryTargets) {
                                addRow("Categoria: " + (ct["category_name"] as String), ct["target_leads"] as num?, ct["progress"] as int);
                              }
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(m["name"] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                    const SizedBox(height: 6),
                                    ...rows,
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                      if (pendencias.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const Text("Alertas", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        ...pendencias.map((p) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                "\u26a0\ufe0f Um lead esta parado em \"" + (p["status"] as String) + "\" ha " + (p["hoursSince"] as double).toStringAsFixed(0) + "h",
                                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                              ),
                            )),
                      ],
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






