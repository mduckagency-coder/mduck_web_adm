import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";

class RecruiterMyRecruitsPage extends StatefulWidget {
  const RecruiterMyRecruitsPage({super.key});

  @override
  State<RecruiterMyRecruitsPage> createState() => _RecruiterMyRecruitsPageState();
}

class _RecruiterMyRecruitsPageState extends State<RecruiterMyRecruitsPage> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;
    final rows = await client
        .from("profiles")
        .select("id, display_name, tiktok_creator_id, joined_at, is_active, last_live_at, avatar_url, assigned_manager_id, streamer_categories(name), managers!profiles_assigned_manager_id_fkey(login_email)")
        .eq("recruited_by_manager_id", userId)
        .order("joined_at", ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
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
              const Text("Meus Agenciados", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(width: 12),
              IconButton(icon: const Icon(Icons.refresh, color: Colors.white70), onPressed: () => setState(() => _future = _load())),
            ],
          ),
          const SizedBox(height: 4),
          const Text("Todos os streamers que voce ja trouxe para a agencia, mesmo que tenham mudado de gestor.", style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final list = snapshot.data!;
                if (list.isEmpty) {
                  return const Center(child: Text("Voce ainda nao agenciou nenhum streamer.", style: TextStyle(color: Colors.white54)));
                }
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final s = list[index];
                    final catData = s["streamer_categories"];
                    final managerData = s["managers"];
                    final active = s["is_active"] as bool? ?? true;
                    final lastLive = s["last_live_at"] as String?;
                    return Card(
                      color: Colors.white.withOpacity(0.05),
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white24,
                          backgroundImage: s["avatar_url"] != null ? NetworkImage(s["avatar_url"] as String) : null,
                          child: s["avatar_url"] == null ? const Icon(Icons.person, color: Colors.white54, size: 18) : null,
                        ),
                        title: Text(s["display_name"] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (s["tiktok_creator_id"] ?? "-") + "  -  " + (catData is Map ? catData["name"] as String? ?? "-" : "-"),
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                            Text(
                              "Agenciado em " + DateTime.parse(s["joined_at"] as String).toLocal().toString().substring(0, 10) +
                                  "  -  Gestor atual: " + (managerData is Map ? managerData["login_email"] as String? ?? "Nao atribuido" : "Nao atribuido"),
                              style: const TextStyle(color: Colors.white38, fontSize: 11),
                            ),
                            if (lastLive != null)
                              Text("Ultima atividade: " + DateTime.parse(lastLive).toLocal().toString().substring(0, 16), style: const TextStyle(color: Colors.white38, fontSize: 11)),
                          ],
                        ),
                        trailing: !active ? const Text("INATIVO", style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)) : null,
                      ),
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
