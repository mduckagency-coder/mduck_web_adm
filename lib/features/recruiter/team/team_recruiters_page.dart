import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";

class TeamRecruitersPage extends StatefulWidget {
  const TeamRecruitersPage({super.key});

  @override
  State<TeamRecruitersPage> createState() => _TeamRecruitersPageState();
}

class _TeamRecruitersPageState extends State<TeamRecruitersPage> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final client = Supabase.instance.client;
    final now = DateTime.now();

    final leads = await client.from("leads").select("recruiter_id, status, created_at, updated_at");
    final leadsList = (leads as List).cast<Map<String, dynamic>>();
    final recruiterIds = leadsList.map((l) => l["recruiter_id"] as String).toSet();

    if (recruiterIds.isEmpty) return [];

    final managers = await client.from("managers").select("id, login_email").inFilter("id", recruiterIds.toList());
    final managerMap = {for (final m in (managers as List)) m["id"] as String: m["login_email"] as String};

    final profiles = await client.from("profiles").select("recruited_by_manager_id, joined_at").not("recruited_by_manager_id", "is", null);
    final profilesList = (profiles as List).cast<Map<String, dynamic>>();

    final targets = await client.from("recruiter_targets").select("recruiter_id, target_value, starts_at, ends_at").eq("metric", "agenciamentos").eq("period_type", "mensal");
    final targetsList = (targets as List).cast<Map<String, dynamic>>();

    final result = <Map<String, dynamic>>[];
    for (final rid in recruiterIds) {
      final own = leadsList.where((l) => l["recruiter_id"] == rid).toList();
      final ativos = own.where((l) => l["status"] != "agenciado" && l["status"] != "recusado").length;
      final negociando = own.where((l) => l["status"] == "negociando").length;
      final agenciados = own.where((l) => l["status"] == "agenciado").length;
      final conversao = own.isEmpty ? 0.0 : (agenciados / own.length) * 100;

      final recrutadosNoMes = profilesList.where((p) {
        if (p["recruited_by_manager_id"] != rid) return false;
        final d = DateTime.parse(p["joined_at"]);
        return d.year == now.year && d.month == now.month;
      }).length;

      DateTime? lastActivity;
      for (final l in own) {
        final d = DateTime.parse((l["updated_at"] ?? l["created_at"]) as String);
        if (lastActivity == null || d.isAfter(lastActivity)) lastActivity = d;
      }

      double metaAtual = 0;
      for (final t in targetsList) {
        if (t["recruiter_id"] != rid) continue;
        final start = DateTime.parse(t["starts_at"]);
        final end = DateTime.parse(t["ends_at"]);
        if (!now.isBefore(start) && !now.isAfter(end)) metaAtual = (t["target_value"] as num).toDouble();
      }
      final pctMeta = metaAtual == 0 ? 0.0 : (recrutadosNoMes / metaAtual) * 100;

      result.add({
        "id": rid,
        "email": managerMap[rid] ?? "-",
        "leadsAtivos": ativos,
        "leadsNegociando": negociando,
        "recrutadosNoMes": recrutadosNoMes,
        "conversao": conversao,
        "metaAtual": metaAtual,
        "pctMeta": pctMeta,
        "lastActivity": lastActivity,
      });
    }
    result.sort((a, b) => (b["recrutadosNoMes"] as int).compareTo(a["recrutadosNoMes"] as int));
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text("Recrutadores", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(width: 12),
            IconButton(icon: const Icon(Icons.refresh, color: Colors.white70), onPressed: () => setState(() => _future = _load())),
          ]),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final list = snapshot.data!;
                if (list.isEmpty) return const Center(child: Text("Nenhum recrutador com leads ainda.", style: TextStyle(color: Colors.white54)));
                return SingleChildScrollView(
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: list.map((r) {
                      return Container(
                        width: 280,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white12)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              const CircleAvatar(radius: 20, backgroundColor: Colors.white24, child: Icon(Icons.person, color: Colors.white70)),
                              const SizedBox(width: 10),
                              Expanded(child: Text(r["email"] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis)),
                            ]),
                            const SizedBox(height: 12),
                            Text("Meta: " + (r["recrutadosNoMes"]).toString() + " / " + (r["metaAtual"] as double).toStringAsFixed(0) + " (" + (r["pctMeta"] as double).toStringAsFixed(0) + "%)",
                                style: const TextStyle(color: Color(0xFF7A0BD4), fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: ((r["pctMeta"] as double) / 100).clamp(0.0, 1.0),
                                minHeight: 6,
                                backgroundColor: Colors.white12,
                                valueColor: const AlwaysStoppedAnimation(Color(0xFF7A0BD4)),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text("Leads ativos: " + r["leadsAtivos"].toString(), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            Text("Em negociacao: " + r["leadsNegociando"].toString(), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            Text("Conversao: " + (r["conversao"] as double).toStringAsFixed(0) + "%", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            Text(
                              "Ultima atividade: " + (r["lastActivity"] != null ? (r["lastActivity"] as DateTime).toLocal().toString().substring(0, 16) : "-"),
                              style: const TextStyle(color: Colors.white38, fontSize: 11),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
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
