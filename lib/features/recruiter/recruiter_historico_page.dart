import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";

class RecruiterHistoricoPage extends StatefulWidget {
  const RecruiterHistoricoPage({super.key});

  @override
  State<RecruiterHistoricoPage> createState() => _RecruiterHistoricoPageState();
}

class _RecruiterHistoricoPageState extends State<RecruiterHistoricoPage> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;
    final events = <Map<String, dynamic>>[];

    final leads = await client.from("leads").select("id, name, created_at").eq("recruiter_id", userId);
    final leadIds = (leads as List).map((l) => l["id"] as String).toList();
    final leadNames = {for (final l in leads) l["id"] as String: l["name"] as String};

    for (final l in leads) {
      events.add({"date": l["created_at"], "text": "Lead cadastrado: " + (l["name"] as String)});
    }

    if (leadIds.isNotEmpty) {
      final leadHist = await client.from("lead_history").select().inFilter("lead_id", leadIds).order("created_at", ascending: false);
      for (final h in (leadHist as List)) {
        events.add({"date": h["created_at"], "text": "[" + (h["action"] as String) + "] " + ((h["detail"] as String?) ?? "")});
      }
    }

    final transfers = await client.from("streamer_transfers").select("transferred_at, profiles(display_name), managers!streamer_transfers_manager_id_fkey(login_email)").eq("recruiter_id", userId);
    for (final t in (transfers as List)) {
      final p = t["profiles"];
      final m = t["managers"];
      events.add({
        "date": t["transferred_at"],
        "text": "Streamer transferido: " + (p is Map ? p["display_name"] as String? ?? "-" : "-") + " -> " + (m is Map ? m["login_email"] as String? ?? "-" : "-"),
      });
    }

    events.sort((a, b) => (b["date"] as String).compareTo(a["date"] as String));
    return events;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text("Historico", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(width: 12),
            IconButton(icon: const Icon(Icons.refresh, color: Colors.white70), onPressed: () => setState(() => _future = _load())),
          ]),
          const SizedBox(height: 4),
          const Text(
            "Registro automatico de leads, mudancas de status e transferencias. (Edicoes de modelos e uso do funil ainda nao entram aqui.)",
            style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final list = snapshot.data!;
                if (list.isEmpty) return const Center(child: Text("Nenhuma atividade registrada ainda.", style: TextStyle(color: Colors.white54)));
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final e = list[index];
                    final date = DateTime.parse(e["date"] as String).toLocal().toString().substring(0, 16);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Icon(Icons.circle, size: 6, color: Color(0xFF7A0BD4)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(date + " - " + (e["text"] as String), style: const TextStyle(color: Colors.white70, fontSize: 13))),
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
