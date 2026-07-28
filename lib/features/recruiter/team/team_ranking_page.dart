import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";

class TeamRankingPage extends StatefulWidget {
  const TeamRankingPage({super.key});

  @override
  State<TeamRankingPage> createState() => _TeamRankingPageState();
}

class _TeamRankingPageState extends State<TeamRankingPage> {
  String _metric = "recrutamentos";
  late Future<List<Map<String, dynamic>>> _future;

  static const _metrics = [
    ("recrutamentos", "Recrutamentos"),
    ("conversao", "Conversao"),
    ("leads", "Leads trabalhados"),
    ("meta", "Cumprimento de metas"),
  ];

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final client = Supabase.instance.client;
    final now = DateTime.now();

    final allManagersRows = await client.from("managers").select("id, login_email");
    final allManagersList = (allManagersRows as List).cast<Map<String, dynamic>>();
    final managerEmailById = {for (final m in allManagersList) m["id"] as String: m["login_email"] as String};
    final managerIdByEmail = {for (final m in allManagersList) (m["login_email"] as String).toLowerCase(): m["id"] as String};

    // Recrutamentos vem dos dados oficiais da planilha (profiles), agrupados por e-mail do
    // agente. Isso funciona mesmo para e-mails sem conta cadastrada no sistema, e ignora o
    // status "agenciado" do kanban de leads, que e apenas o funil interno do recrutador.
    final profiles = await client.from("profiles").select("recruited_by_manager_id, tiktok_agent_email, joined_at, agent_relationship_date");
    final profilesList = (profiles as List).cast<Map<String, dynamic>>();

    String? relDate(Map<String, dynamic> p) => (p["agent_relationship_date"] as String?) ?? (p["joined_at"] as String?);

    final agentGroups = <String, List<Map<String, dynamic>>>{};
    for (final p in profilesList) {
      String? key = (p["tiktok_agent_email"] as String?)?.trim();
      if ((key == null || key.isEmpty) && p["recruited_by_manager_id"] != null) {
        key = managerEmailById[p["recruited_by_manager_id"]];
      }
      if (key == null || key.isEmpty) continue;
      key = key.toLowerCase();
      agentGroups.putIfAbsent(key, () => []).add(p);
    }
    if (agentGroups.isEmpty) return [];

    final leads = await client.from("leads").select("recruiter_id, status");
    final leadsList = (leads as List).cast<Map<String, dynamic>>();

    final targets = await client.from("recruiter_targets").select("recruiter_id, target_value, starts_at, ends_at").eq("metric", "agenciamentos").eq("period_type", "mensal");
    final targetsList = (targets as List).cast<Map<String, dynamic>>();

    final result = <Map<String, dynamic>>[];
    agentGroups.forEach((email, own) {
      final recrutamentos = own.where((p) {
        final ds = relDate(p);
        if (ds == null) return false;
        final d = DateTime.parse(ds);
        return d.year == now.year && d.month == now.month;
      }).length;

      final rid = managerIdByEmail[email];
      final ownLeads = rid == null ? <Map<String, dynamic>>[] : leadsList.where((l) => l["recruiter_id"] == rid).toList();
      final conversao = ownLeads.isEmpty ? 0.0 : (ownLeads.where((l) => l["status"] == "agenciado").length / ownLeads.length) * 100;

      double metaVal = 0;
      if (rid != null) {
        for (final t in targetsList) {
          if (t["recruiter_id"] != rid) continue;
          final start = DateTime.parse(t["starts_at"]);
          final end = DateTime.parse(t["ends_at"]);
          if (!now.isBefore(start) && !now.isAfter(end)) metaVal = (t["target_value"] as num).toDouble();
        }
      }
      final cumprimento = metaVal == 0 ? 0.0 : (recrutamentos / metaVal) * 100;

      result.add({
        "email": email,
        "recrutamentos": recrutamentos,
        "conversao": conversao,
        "leads": ownLeads.length,
        "meta": cumprimento,
      });
    });
    return result;
  }

  num _valueFor(Map<String, dynamic> r) {
    switch (_metric) {
      case "conversao":
        return r["conversao"];
      case "leads":
        return r["leads"];
      case "meta":
        return r["meta"];
      default:
        return r["recrutamentos"];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text("Ranking da Equipe", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(width: 12),
            IconButton(icon: const Icon(Icons.refresh, color: Colors.white70), onPressed: () => setState(() => _future = _load())),
          ]),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: _metrics.map((m) {
              final selected = _metric == m.$1;
              return ChoiceChip(
                label: Text(m.$2),
                selected: selected,
                selectedColor: const Color(0xFF7A0BD4),
                labelStyle: TextStyle(color: selected ? Colors.white : Colors.white70),
                onSelected: (_) => setState(() => _metric = m.$1),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final list = [...snapshot.data!]..sort((a, b) => _valueFor(b).compareTo(_valueFor(a)));
                if (list.isEmpty) return const Center(child: Text("Sem dados ainda.", style: TextStyle(color: Colors.white54)));
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final r = list[index];
                    final medalColor = index == 0 ? Colors.amber : index == 1 ? Colors.grey.shade300 : index == 2 ? const Color(0xFFCD7F32) : Colors.white12;
                    final value = _valueFor(r);
                    final valueText = _metric == "conversao" || _metric == "meta" ? value.toStringAsFixed(0) + "%" : value.toString();
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(10)),
                      child: Row(children: [
                        Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: medalColor.withOpacity(index < 3 ? 1 : 0.2)),
                          child: Text("#" + (index + 1).toString(), style: TextStyle(color: index < 3 ? Colors.black : Colors.white54, fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(r["email"] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        Text(valueText, style: const TextStyle(color: Color(0xFF7A0BD4), fontWeight: FontWeight.bold, fontSize: 16)),
                      ]),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
