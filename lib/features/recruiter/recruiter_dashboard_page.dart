import "package:flutter/material.dart";
import "package:fl_chart/fl_chart.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "lead_category_icons.dart";

class RecruiterDashboardPage extends StatefulWidget {
  final VoidCallback? onNavigateToFeedbacks;
  final VoidCallback? onNavigateToStreamers;
  const RecruiterDashboardPage({super.key, this.onNavigateToFeedbacks, this.onNavigateToStreamers});

  @override
  State<RecruiterDashboardPage> createState() => _RecruiterDashboardPageState();
}

class _RecruiterDashboardPageState extends State<RecruiterDashboardPage> {
  late Future<Map<String, dynamic>> _future;
  String _periodo = "dia";

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Bom dia";
    if (hour < 18) return "Boa tarde";
    return "Boa noite";
  }

  String _motivationalMessage(Map<String, dynamic> d) {
    final options = <String>[];
    final metaMensal = d["metaMensal"] as double;
    final agenciamentosMes = d["agenciamentosMes"] as int;
    if (metaMensal > 0 && agenciamentosMes < metaMensal) {
      options.add("Faltam apenas " + (metaMensal - agenciamentosMes).toStringAsFixed(0) + " agenciamentos para sua meta do mes.");
    }
    final posicao = d["minhaPosicao"] as int?;
    if (posicao != null && posicao <= 3) {
      options.add("Voce esta em " + posicao.toString() + "º lugar no ranking. Continue assim!");
    } else if (posicao != null) {
      options.add("Voce esta em " + posicao.toString() + "º lugar no ranking. Bora subir?");
    }
    final onboardingsPendentes = d["onboardingsPendentes"] as int;
    if (onboardingsPendentes > 0) {
      options.add("Hoje voce possui " + onboardingsPendentes.toString() + " onboarding(s) pendente(s).");
    }
    final taxaConversao = d["taxaConversao"] as double;
    final mediaEquipe = d["conversaoMediaEquipe"] as double;
    if (taxaConversao > mediaEquipe && mediaEquipe > 0) {
      options.add("Sua conversao esta acima da media da equipe!");
    }
    if (options.isEmpty) return "Vamos comecar mais um dia produtivo!";
    return options[DateTime.now().day % options.length];
  }

  Future<Map<String, dynamic>> _load() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final me = await client.from("managers").select("full_name, login_email").eq("id", userId).single();
    final greetingName = (me["full_name"] as String?)?.isNotEmpty == true ? (me["full_name"] as String).split(" ").first : (me["login_email"] as String).split("@").first;

    final leads = await client.from("leads").select().eq("recruiter_id", userId);
    final leadsList = (leads as List).cast<Map<String, dynamic>>();

    final leadsHoje = leadsList.where((l) => DateTime.parse(l["created_at"]).isAfter(today)).length;
    final leadsOntem = leadsList.where((l) {
      final d = DateTime.parse(l["created_at"]);
      return d.isAfter(yesterday) && d.isBefore(today);
    }).length;

    final totalLeads = leadsList.length;
    final leadsAgenciadosKanban = leadsList.where((l) => l["status"] == "agenciado").length;
    final taxaConversao = totalLeads == 0 ? 0.0 : (leadsAgenciadosKanban / totalLeads) * 100;

    // Dados oficiais da planilha: streamers com este agente logado como recrutador
    final officialJoins = await client.from("profiles").select("id, display_name, joined_at").eq("recruited_by_manager_id", userId);
    final officialJoinsList = (officialJoins as List).cast<Map<String, dynamic>>();

    final agenciamentosMes = officialJoinsList.where((p) {
      final d = DateTime.parse(p["joined_at"]);
      return d.year == now.year && d.month == now.month;
    }).length;

    final targetsRows = await client.from("recruiter_targets").select().or("recruiter_id.eq." + userId + ",recruiter_id.is.null");
    final targetsList = (targetsRows as List).cast<Map<String, dynamic>>();
    double metaMensal = 0, metaDiaria = 0, metaSemanal = 0;
    for (final t in targetsList) {
      final start = DateTime.parse(t["starts_at"]);
      final end = DateTime.parse(t["ends_at"]);
      if (now.isBefore(start) || now.isAfter(end)) continue;
      if (t["metric"] == "agenciamentos" && t["period_type"] == "mensal") metaMensal = (t["target_value"] as num).toDouble();
      if (t["metric"] == "leads" && t["period_type"] == "diario") metaDiaria = (t["target_value"] as num).toDouble();
      if (t["metric"] == "leads" && t["period_type"] == "semanal") metaSemanal = (t["target_value"] as num).toDouble();
    }
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final leadsSemana = leadsList.where((l) => DateTime.parse(l["created_at"]).isAfter(DateTime(weekStart.year, weekStart.month, weekStart.day))).length;

    final bonusTiers = await client.from("collaborator_bonus_tiers").select().eq("manager_id", userId).order("threshold_value");
    final bonusList = (bonusTiers as List).cast<Map<String, dynamic>>();
    Map<String, dynamic>? proximaBonificacao;
    for (final b in bonusList) {
      if (agenciamentosMes < (b["threshold_value"] as num)) {
        proximaBonificacao = b;
        break;
      }
    }

    final onboardingLeadIds = leadsList.where((l) => l["status"] == "agenciado").map((l) => l["id"] as String).toList();
    var onboardingsPendentes = 0;
    var onboardingsConcluidos = 0;
    if (onboardingLeadIds.isNotEmpty) {
      final checklists = await client.from("lead_onboarding_checklist").select("concluido").inFilter("lead_id", onboardingLeadIds);
      for (final c in (checklists as List)) {
        if (c["concluido"] == true) {
          onboardingsConcluidos++;
        } else {
          onboardingsPendentes++;
        }
      }
    }

    final allProfilesFull = await client.from("profiles").select("id, joined_at, recruited_by_manager_id, tiktok_agent_email, agent_relationship_date");
    final allProfilesFullList = (allProfilesFull as List).cast<Map<String, dynamic>>();
    final allProfilesList = allProfilesFullList.where((p) => p["recruited_by_manager_id"] != null).toList();
    final recruiterIds = allProfilesList.map((p) => p["recruited_by_manager_id"] as String).toSet();

    final allManagersRows = await client.from("managers").select("id, login_email, photo_url");
    final allManagersList = (allManagersRows as List).cast<Map<String, dynamic>>();
    final managerMap = {for (final m in allManagersList) m["id"] as String: m};
    final managerByEmail = {for (final m in allManagersList) (m["login_email"] as String).toLowerCase(): m};

    // Ranking agrupado pelo e-mail do agente da planilha (funciona mesmo sem conta cadastrada)
    String? relDate(Map<String, dynamic> p) => (p["agent_relationship_date"] as String?) ?? (p["joined_at"] as String?);
    final agentGroups = <String, List<Map<String, dynamic>>>{};
    for (final p in allProfilesFullList) {
      String? key = (p["tiktok_agent_email"] as String?)?.trim();
      if ((key == null || key.isEmpty) && p["recruited_by_manager_id"] != null) {
        key = managerMap[p["recruited_by_manager_id"]]?["login_email"] as String?;
      }
      if (key == null || key.isEmpty) continue;
      key = key.toLowerCase();
      agentGroups.putIfAbsent(key, () => []).add(p);
    }
    final myEmailLower = (me["login_email"] as String).toLowerCase();
    final ranking = <Map<String, dynamic>>[];
    agentGroups.forEach((email, profiles) {
      final recrutamentosMes = profiles.where((p) {
        final ds = relDate(p);
        if (ds == null) return false;
        final d = DateTime.parse(ds);
        return d.year == now.year && d.month == now.month;
      }).length;
      final mInfo = managerByEmail[email];
      ranking.add({"email": email, "photo_url": mInfo?["photo_url"], "recrutamentos": recrutamentosMes, "isMe": email == myEmailLower});
    });
    ranking.sort((a, b) => (b["recrutamentos"] as int).compareTo(a["recrutamentos"] as int));
    final minhaPosicao = ranking.indexWhere((r) => r["isMe"] == true) + 1;

    final monthStartStr = DateTime(now.year, now.month, 1).toIso8601String();
    final nextMonthStartStr = DateTime(now.year, now.month + 1, 1).toIso8601String();
    final allJoinedThisMonth = await client
        .from("profiles")
        .select("id")
        .gte("joined_at", monthStartStr)
        .lt("joined_at", nextMonthStartStr);
    final agenciadosGeralMes = (allJoinedThisMonth as List).length;

    final allLeadsForConversion = await client.from("leads").select("recruiter_id, status");
    final allLeadsForConversionList = (allLeadsForConversion as List).cast<Map<String, dynamic>>();
    final leadRecruiterIds = allLeadsForConversionList.map((l) => l["recruiter_id"] as String).toSet();
    final conversoes = <double>[];
    for (final rid in leadRecruiterIds) {
      final own = allLeadsForConversionList.where((l) => l["recruiter_id"] == rid).toList();
      final ag = own.where((l) => l["status"] == "agenciado").length;
      if (own.isNotEmpty) conversoes.add((ag / own.length) * 100);
    }
    final conversaoMediaEquipe = conversoes.isEmpty ? 0.0 : conversoes.reduce((a, b) => a + b) / conversoes.length;

    final metaTargetsRows = await client.from("recruiter_targets").select();
    final metaTargetsList = (metaTargetsRows as List).cast<Map<String, dynamic>>();
    final metasBatidas = <Map<String, dynamic>>[];
    final threeDaysAgo = now.subtract(const Duration(days: 3));
    for (final t in metaTargetsList) {
      final start = DateTime.parse(t["starts_at"]);
      final end = DateTime.parse(t["ends_at"]);
      if (now.isBefore(start) || now.isAfter(end)) continue;
      final targetValue = (t["target_value"] as num).toDouble();
      if (targetValue <= 0) continue;
      final metric = t["metric"] as String;
      if (metric != "agenciamentos" && metric != "leads") continue;
      final targetRecruiterIds = t["recruiter_id"] != null ? [t["recruiter_id"] as String] : recruiterIds.toList();
      for (final rid in targetRecruiterIds) {
        List<Map<String, dynamic>> own;
        String dateField;
        if (metric == "agenciamentos") {
          own = allProfilesList.where((p) {
            if (p["recruited_by_manager_id"] != rid) return false;
            final d = DateTime.parse(p["joined_at"]);
            return !d.isBefore(start) && !d.isAfter(end);
          }).toList();
          dateField = "joined_at";
        } else {
          own = allLeadsForConversionList.where((l) => l["recruiter_id"] == rid).toList();
          dateField = "created_at";
        }
        if (own.length >= targetValue && own.isNotEmpty) {
          own.sort((a, b) {
            final av = a[dateField];
            final bv = b[dateField];
            if (av == null || bv == null) return 0;
            return (bv as String).compareTo(av as String);
          });
          final whenStr = own.first[dateField] as String?;
          if (whenStr == null || DateTime.parse(whenStr).isBefore(threeDaysAgo)) continue;
          final mInfo = managerMap[rid];
          metasBatidas.add({
            "email": mInfo?["login_email"] ?? "-",
            "target": targetValue.toStringAsFixed(0),
            "metric": metric,
            "period": t["period_type"],
            "when": whenStr,
          });
        }
      }
    }
    metasBatidas.sort((a, b) => (b["when"] as String).compareTo(a["when"] as String));

    final recentProfiles = await client
        .from("profiles")
        .select("display_name, avatar_url, joined_at, agent_relationship_date, recruited_by_manager_id, tiktok_agent_email")
        .order("joined_at", ascending: false)
        .limit(5);
    final duckersRecentes = (recentProfiles as List).cast<Map<String, dynamic>>();
    for (final dItem in duckersRecentes) {
      final rid = dItem["recruited_by_manager_id"];
      final fromManager = rid != null ? (managerMap[rid]?["login_email"] as String?) : null;
      final fromSheet = (dItem["tiktok_agent_email"] as String?)?.trim();
      dItem["recruiterEmail"] = fromManager ?? (fromSheet != null && fromSheet.isNotEmpty ? fromSheet : "-");
    }

    final unreadFeedbacks = await client.from("recruiter_feedbacks").select().eq("recruiter_id", userId).isFilter("read_at", null).order("created_at", ascending: false);

    return {
      "greetingName": greetingName,
      "leadsHoje": leadsHoje,
      "leadsOntem": leadsOntem,
      "totalLeads": totalLeads,
      "agenciados": agenciamentosMes,
      "taxaConversao": taxaConversao,
      "conversaoMediaEquipe": conversaoMediaEquipe,
      "agenciamentosMes": agenciamentosMes,
      "agenciadosGeralMes": agenciadosGeralMes,
      "metaMensal": metaMensal,
      "metaDiaria": metaDiaria,
      "metaSemanal": metaSemanal,
      "leadsSemana": leadsSemana,
      "proximaBonificacao": proximaBonificacao,
      "onboardingsPendentes": onboardingsPendentes,
      "onboardingsConcluidos": onboardingsConcluidos,
      "ranking": ranking,
      "minhaPosicao": minhaPosicao,
      "metasBatidas": metasBatidas.take(5).toList(),
      "duckersRecentes": duckersRecentes,
      "officialJoins": officialJoinsList,
      "unreadFeedbacks": (unreadFeedbacks as List).cast<Map<String, dynamic>>(),
    };
  }

  Future<void> _confirmFeedback(String feedbackId) async {
    final client = Supabase.instance.client;
    await client.from("recruiter_feedbacks").update({"read_at": DateTime.now().toIso8601String()}).eq("id", feedbackId);
    widget.onNavigateToFeedbacks?.call();
  }

  Map<String, int> _groupedCounts(List<Map<String, dynamic>> officialJoins) {
    final counts = <String, int>{};
    final now = DateTime.now();
    if (_periodo == "dia") {
      for (var i = 6; i >= 0; i--) {
        final day = now.subtract(Duration(days: i));
        counts[day.day.toString().padLeft(2, "0") + "/" + day.month.toString().padLeft(2, "0")] = 0;
      }
      for (final p in officialJoins) {
        final d = DateTime.parse(p["joined_at"]);
        if (now.difference(d).inDays > 6) continue;
        final key = d.day.toString().padLeft(2, "0") + "/" + d.month.toString().padLeft(2, "0");
        if (counts.containsKey(key)) counts[key] = counts[key]! + 1;
      }
    } else if (_periodo == "semana") {
      for (var i = 5; i >= 0; i--) {
        final weekStart = now.subtract(Duration(days: now.weekday - 1 + i * 7));
        counts["Sem " + weekStart.day.toString() + "/" + weekStart.month.toString()] = 0;
      }
      for (final p in officialJoins) {
        final d = DateTime.parse(p["joined_at"]);
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
      for (final p in officialJoins) {
        final d = DateTime.parse(p["joined_at"]);
        final key = d.month.toString().padLeft(2, "0") + "/" + d.year.toString();
        if (counts.containsKey(key)) counts[key] = counts[key]! + 1;
      }
    }
    return counts;
  }

  Widget _statCard(IconData icon, String label, String value, Color color, String? delta) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 165,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [color.withOpacity(0.16), Colors.white.withOpacity(0.03)]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, color: color, size: 16), const SizedBox(width: 6), Expanded(child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)))]),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
          if (delta != null) ...[
            const SizedBox(height: 2),
            Text(delta, style: const TextStyle(color: Colors.white38, fontSize: 10)),
          ],
        ],
      ),
    );
  }

  Widget _progressRow(String label, int progress, double target, Color color) {
    final fraction = target == 0 ? 0.0 : (progress / target).clamp(0.0, 1.0);
    final falta = (target - progress).clamp(0, target).toStringAsFixed(0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold))),
            Text(progress.toString() + " / " + target.toStringAsFixed(0), style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(borderRadius: BorderRadius.circular(6), child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: fraction),
            duration: const Duration(milliseconds: 600),
            builder: (context, value, _) => LinearProgressIndicator(value: value, minHeight: 8, backgroundColor: Colors.white12, valueColor: AlwaysStoppedAnimation(color)),
          )),
          if (target > 0 && progress < target) Padding(padding: const EdgeInsets.only(top: 4), child: Text("Faltam " + falta, style: const TextStyle(color: Colors.white38, fontSize: 11))),
          if (target > 0 && progress >= target) const Padding(padding: EdgeInsets.only(top: 4), child: Text("Meta concluida!", style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _sideCard({required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
      child: child,
    );
  }

  Widget _rankingContent(List<Map<String, dynamic>> ranking, int minhaPosicao) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: const [Icon(Icons.emoji_events, color: Colors.amber, size: 18), SizedBox(width: 6), Text("Ranking da Equipe", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))]),
        const SizedBox(height: 2),
        const Text("Agenciamentos do mes (planilha oficial)", style: TextStyle(color: Colors.white38, fontSize: 10)),
        const SizedBox(height: 12),
        if (ranking.isEmpty)
          const Text("Sem dados ainda.", style: TextStyle(color: Colors.white54, fontSize: 12))
        else ...[
          ...ranking.take(5).toList().asMap().entries.map((entry) {
            final i = entry.key;
            final r = entry.value;
            final isMe = r["isMe"] == true;
            final medal = i == 0 ? "\ud83e\udd47" : i == 1 ? "\ud83e\udd48" : i == 2 ? "\ud83e\udd49" : null;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: isMe ? const Color(0xFF7A0BD4).withOpacity(0.2) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: isMe ? Border.all(color: const Color(0xFF7A0BD4)) : null,
              ),
              child: Row(children: [
                medal != null
                    ? Text(medal, style: const TextStyle(fontSize: 16))
                    : SizedBox(width: 20, child: Text((i + 1).toString(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white38, fontSize: 12))),
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.white24,
                  backgroundImage: r["photo_url"] != null ? NetworkImage(r["photo_url"] as String) : null,
                  child: r["photo_url"] == null ? const Icon(Icons.person, color: Colors.white54, size: 12) : null,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(r["email"] as String, style: TextStyle(color: isMe ? Colors.white : Colors.white70, fontSize: 11, fontWeight: isMe ? FontWeight.bold : FontWeight.normal), overflow: TextOverflow.ellipsis)),
                Text(r["recrutamentos"].toString(), style: const TextStyle(color: Color(0xFF7A0BD4), fontWeight: FontWeight.bold, fontSize: 12)),
              ]),
            );
          }),
          if (minhaPosicao > 5)
            Padding(padding: const EdgeInsets.only(top: 4), child: Text("Voce esta em " + minhaPosicao.toString() + "º lugar.", style: const TextStyle(color: Color(0xFF7A0BD4), fontSize: 12, fontWeight: FontWeight.bold))),
        ],
      ],
    );
  }

  Widget _metasBatidasContent(List<Map<String, dynamic>> metasBatidas) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: const [Icon(Icons.military_tech, color: Colors.amber, size: 18), SizedBox(width: 6), Text("Ultimas Metas Batidas", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))]),
        const SizedBox(height: 2),
        const Text("Ultimos 3 dias", style: TextStyle(color: Colors.white38, fontSize: 10)),
        const SizedBox(height: 12),
        if (metasBatidas.isEmpty)
          const Text("Nenhuma meta batida no periodo.", style: TextStyle(color: Colors.white54, fontSize: 12))
        else
          ...metasBatidas.map((mb) {
            final date = DateTime.parse(mb["when"] as String).toLocal().toString().substring(0, 16);
            final metricLabel = mb["metric"] == "agenciamentos" ? "agenciamentos" : "leads";
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(mb["email"] as String, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  Text("Bateu meta de " + mb["target"].toString() + " " + metricLabel + " (" + mb["period"].toString() + ") em " + date, style: const TextStyle(color: Colors.amber, fontSize: 10)),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _duckersAndChartContent(List<Map<String, dynamic>> duckersRecentes, Map<String, int> grouped) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: const [Icon(Icons.duo, color: Colors.tealAccent, size: 18), SizedBox(width: 6), Text("Duckers Recentes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))]),
        const SizedBox(height: 2),
        const Text("Ultimos 5 a ingressar na agencia", style: TextStyle(color: Colors.white38, fontSize: 10)),
        const SizedBox(height: 12),
        if (duckersRecentes.isEmpty)
          const Text("Nenhum agenciamento recente.", style: TextStyle(color: Colors.white54, fontSize: 12))
        else
          ...duckersRecentes.map((dk) {
            final date = DateTime.parse(dk["joined_at"] as String).toLocal().toString().substring(0, 16);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.white24,
                  backgroundImage: dk["avatar_url"] != null ? NetworkImage(dk["avatar_url"] as String) : null,
                  child: dk["avatar_url"] == null ? const Icon(Icons.person, color: Colors.white54, size: 12) : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(dk["display_name"] as String, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      Text("por " + (dk["recruiterEmail"] as String) + "  -  " + date, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                    ],
                  ),
                ),
              ]),
            );
          }),
      ],
    );
  }

  Widget _agenciamentosChartCard(Map<String, int> grouped) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text("Agenciamentos", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
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
            height: 140,
            child: BarChart(
              BarChartData(
                barTouchData: BarTouchData(enabled: true),
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
      child: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text("Erro ao carregar dashboard: " + snapshot.error.toString(), style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center),
              ),
            );
          }
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final d = snapshot.data!;
          final grouped = _groupedCounts((d["officialJoins"] as List).cast<Map<String, dynamic>>());
          final ranking = (d["ranking"] as List).cast<Map<String, dynamic>>();
          final unreadFeedbacks = (d["unreadFeedbacks"] as List).cast<Map<String, dynamic>>();
          final proximaBonificacao = d["proximaBonificacao"] as Map<String, dynamic>?;
          final minhaPosicao = d["minhaPosicao"] as int;
          final metasBatidas = (d["metasBatidas"] as List).cast<Map<String, dynamic>>();
          final duckersRecentes = (d["duckersRecentes"] as List).cast<Map<String, dynamic>>();

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_greeting() + ", " + (d["greetingName"] as String) + "! \ud83d\udc4b", style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(_motivationalMessage(d), style: const TextStyle(color: Color(0xFF7A0BD4), fontSize: 14, fontStyle: FontStyle.italic)),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.refresh, color: Colors.white70), onPressed: () => setState(() => _future = _load())),
                ]),
                const SizedBox(height: 20),
                if (unreadFeedbacks.isNotEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: const Color(0xFFFFF176), borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 6, offset: const Offset(2, 4))]),
                    child: Row(children: [
                      const Icon(Icons.sticky_note_2, color: Colors.black87),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              unreadFeedbacks.length == 1 ? "Voce recebeu um novo feedback: " + ((unreadFeedbacks.first["title"] as String?) ?? "Feedback") : "Voce recebeu " + unreadFeedbacks.length.toString() + " novos feedbacks",
                              style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const Text("Clique para ler e confirmar.", style: TextStyle(color: Colors.black54, fontSize: 12)),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => _confirmFeedback(unreadFeedbacks.first["id"] as String),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.black87, foregroundColor: Colors.white),
                        child: const Text("Ver feedback"),
                      ),
                    ]),
                  ),
                Wrap(spacing: 12, runSpacing: 12, children: [
                  _statCard(Icons.people, "Leads", d["totalLeads"].toString(), Colors.blueAccent, "+" + d["leadsHoje"].toString() + " hoje (ontem: " + d["leadsOntem"].toString() + ")"),
                  _statCard(Icons.verified, "Agenciados Geral (este mes)", d["agenciadosGeralMes"].toString(), Colors.greenAccent, "Toda a equipe - fonte: planilha oficial"),
                  _statCard(Icons.percent, "Conversao", (d["taxaConversao"] as double).toStringAsFixed(0) + "%",
                      const Color(0xFF7A0BD4), (d["taxaConversao"] as double) >= (d["conversaoMediaEquipe"] as double) ? "Acima da media da equipe" : "Media da equipe: " + (d["conversaoMediaEquipe"] as double).toStringAsFixed(0) + "%"),
                  _statCard(Icons.rocket_launch, "Onboardings", d["onboardingsPendentes"].toString() + " pendentes", Colors.orangeAccent, d["onboardingsConcluidos"].toString() + " concluidos"),
                ]),
                const SizedBox(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Meu Progresso", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            _progressRow("Meta do mes (agenciamentos - planilha oficial)", d["agenciamentosMes"] as int, d["metaMensal"] as double, const Color(0xFF7A0BD4)),
                            _progressRow("Meta diaria (leads)", d["leadsHoje"] as int, d["metaDiaria"] as double, Colors.tealAccent),
                            _progressRow("Meta semanal (leads)", d["leadsSemana"] as int, d["metaSemanal"] as double, Colors.blueAccent),
                            if (proximaBonificacao != null) ...[
                              const Divider(color: Colors.white12, height: 24),
                              Row(children: [
                                const Icon(Icons.card_giftcard, color: Colors.amber, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "Proxima bonificacao: R\$ " + (proximaBonificacao["bonus_amount"] as num).toStringAsFixed(2) + " ao atingir " + (proximaBonificacao["threshold_value"] as num).toStringAsFixed(0) + " " + (proximaBonificacao["goal_type"] as String),
                                    style: const TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ]),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          _sideCard(child: _rankingContent(ranking, minhaPosicao)),
                          _sideCard(child: _metasBatidasContent(metasBatidas)),
                          _sideCard(child: _duckersAndChartContent(duckersRecentes, grouped)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}








