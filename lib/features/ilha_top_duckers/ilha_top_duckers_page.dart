import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";

class IlhaTopDuckersPage extends StatefulWidget {
  const IlhaTopDuckersPage({super.key});

  @override
  State<IlhaTopDuckersPage> createState() => _IlhaTopDuckersPageState();
}

class _IlhaTopDuckersPageState extends State<IlhaTopDuckersPage> {
  late Future<List<Map<String, dynamic>>> _future;
  static const _threshold = 80000;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final client = Supabase.instance.client;
    final profiles = await client
        .from("profiles")
        .select("id, display_name, tiktok_creator_id, streamer_stats(diamonds)")
        .eq("is_active", true);

    final islands = await client.from("streamer_islands").select("streamer_id, unlocked_at");
    final islandMap = {for (final i in (islands as List)) i["streamer_id"] as String: i["unlocked_at"]};

    final itemsCount = await client.from("streamer_island_items").select("streamer_id");
    final countMap = <String, int>{};
    for (final it in (itemsCount as List)) {
      final sid = it["streamer_id"] as String;
      countMap[sid] = (countMap[sid] ?? 0) + 1;
    }

    final qualifying = <Map<String, dynamic>>[];
    for (final p in (profiles as List)) {
      final statsData = p["streamer_stats"];
      int diamonds = 0;
      if (statsData is List && statsData.isNotEmpty) {
        diamonds = statsData.first["diamonds"] as int? ?? 0;
      } else if (statsData is Map) {
        diamonds = statsData["diamonds"] as int? ?? 0;
      }
      if (diamonds < _threshold) continue;
      qualifying.add({
        "id": p["id"],
        "display_name": p["display_name"],
        "tiktok_creator_id": p["tiktok_creator_id"],
        "diamonds": diamonds,
        "unlocked_at": islandMap[p["id"]],
        "decorations": countMap[p["id"]] ?? 0,
      });
    }
    qualifying.sort((a, b) => (b["diamonds"] as int).compareTo(a["diamonds"] as int));
    return qualifying;
  }

  Future<void> _unlock(String streamerId) async {
    final client = Supabase.instance.client;
    await client.from("streamer_islands").upsert({"streamer_id": streamerId, "unlocked_at": DateTime.now().toIso8601String()});
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final list = snapshot.data!;

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text("Ilha Top Duckers", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(width: 12),
                  IconButton(icon: const Icon(Icons.refresh, color: Colors.white70), onPressed: () => setState(() => _future = _load())),
                ],
              ),
              const SizedBox(height: 4),
              Text("Streamers com " + _threshold.toString() + "+ diamantes no mes (elegiveis a ilha).", style: const TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 16),
              Text(list.length.toString() + " elegiveis", style: const TextStyle(color: Colors.white54)),
              const SizedBox(height: 8),
              Expanded(
                child: list.isEmpty
                    ? const Center(child: Text("Nenhum streamer atingiu 80k diamantes ainda.", style: TextStyle(color: Colors.white54)))
                    : ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (context, index) {
                          final s = list[index];
                          final unlocked = s["unlocked_at"] != null;
                          return Card(
                            color: Colors.white.withOpacity(0.05),
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: const CircleAvatar(radius: 18, backgroundColor: Colors.white24, child: Icon(Icons.terrain, color: Colors.white54, size: 18)),
                              title: Text(s["display_name"] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                (s["tiktok_creator_id"] ?? "-") + "  -  " + s["diamonds"].toString() + " diamantes  -  " + s["decorations"].toString() + " decoracoes na ilha",
                                style: const TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                              trailing: unlocked
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(border: Border.all(color: Colors.greenAccent), borderRadius: BorderRadius.circular(8)),
                                      child: Text("Desbloqueada em " + DateTime.parse(s["unlocked_at"]).toLocal().toString().substring(0, 10),
                                          style: const TextStyle(color: Colors.greenAccent, fontSize: 11)),
                                    )
                                  : ElevatedButton(
                                      onPressed: () => _unlock(s["id"] as String),
                                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
                                      child: const Text("Desbloquear ilha"),
                                    ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
