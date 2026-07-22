import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "../recruiter/recruiter_streamers_page.dart";

class GestorMyStreamersPage extends StatefulWidget {
  const GestorMyStreamersPage({super.key});

  @override
  State<GestorMyStreamersPage> createState() => _GestorMyStreamersPageState();
}

class _GestorMyStreamersPageState extends State<GestorMyStreamersPage> {
  late Future<List<Map<String, dynamic>>> _future;
  String _search = "";
  String? _categoryFilter;
  String? _statusFilter;

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
        .select(
            "id, display_name, tiktok_creator_id, joined_at, is_active, last_live_at, avatar_url, phone, assigned_manager_id, streamer_categories(name), managers!profiles_assigned_manager_id_fkey(login_email), streamer_stats(days_live, diamonds)")
        .eq("assigned_manager_id", userId)
        .order("joined_at", ascending: false);
    final list = (rows as List).cast<Map<String, dynamic>>();

    if (list.isNotEmpty) {
      final ids = list.map((s) => s["id"] as String).toList();
      final onboardingRows = await client.from("onboarding").select("streamer_id").inFilter("streamer_id", ids);
      final onboardingSet = (onboardingRows as List).map((o) => o["streamer_id"] as String).toSet();
      for (final s in list) {
        s["hasOnboarding"] = onboardingSet.contains(s["id"]);
      }
    }
    return list;
  }

  List<Map<String, dynamic>> _filter(List<Map<String, dynamic>> all) {
    return all.where((s) {
      if (_search.isNotEmpty) {
        final name = (s["display_name"] as String).toLowerCase();
        final tiktok = (s["tiktok_creator_id"] as String? ?? "").toLowerCase();
        if (!name.contains(_search.toLowerCase()) && !tiktok.contains(_search.toLowerCase())) return false;
      }
      final catData = s["streamer_categories"];
      final catName = catData is Map ? catData["name"] as String? : null;
      if (_categoryFilter != null && catName != _categoryFilter) return false;
      if (_statusFilter != null && computeStreamerStatus(s).$1 != _statusFilter) return false;
      return true;
    }).toList();
  }

  Widget _metricCard(String label, String value, Color color) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: color)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final all = snapshot.data!;
          final filtered = _filter(all);
          final categories = all.map((s) => s["streamer_categories"]).whereType<Map>().map((c) => c["name"] as String).toSet().toList()..sort();

          final ativos = all.where((s) => s["is_active"] == true).length;
          final onboarding = all.where((s) => s["hasOnboarding"] == true).length;
          final inativos = all.where((s) => s["is_active"] != true).length;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Text("Meus Streamers", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(width: 12),
                IconButton(icon: const Icon(Icons.refresh, color: Colors.white70), onPressed: () => setState(() => _future = _load())),
              ]),
              const SizedBox(height: 16),
              Wrap(spacing: 12, runSpacing: 12, children: [
                _metricCard("Total", all.length.toString(), const Color(0xFF7A0BD4)),
                _metricCard("Ativos", ativos.toString(), Colors.greenAccent),
                _metricCard("Em Onboarding", onboarding.toString(), Colors.blueAccent),
                _metricCard("Inativos", inativos.toString(), Colors.redAccent),
              ]),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 200,
                    child: TextField(
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.search, color: Colors.white54), hintText: "Buscar nome ou @TikTok", hintStyle: TextStyle(color: Colors.white38), isDense: true),
                      onChanged: (v) => setState(() => _search = v),
                    ),
                  ),
                  DropdownButton<String?>(
                    value: _categoryFilter,
                    hint: const Text("Categoria", style: TextStyle(color: Colors.white54)),
                    dropdownColor: const Color(0xFF1A1A1A),
                    style: const TextStyle(color: Colors.white),
                    items: [const DropdownMenuItem<String?>(value: null, child: Text("Todas categorias")), ...categories.map((c) => DropdownMenuItem<String?>(value: c, child: Text(c)))],
                    onChanged: (v) => setState(() => _categoryFilter = v),
                  ),
                  DropdownButton<String?>(
                    value: _statusFilter,
                    hint: const Text("Status", style: TextStyle(color: Colors.white54)),
                    dropdownColor: const Color(0xFF1A1A1A),
                    style: const TextStyle(color: Colors.white),
                    items: const [
                      DropdownMenuItem<String?>(value: null, child: Text("Todos status")),
                      DropdownMenuItem<String?>(value: "Onboarding", child: Text("Onboarding")),
                      DropdownMenuItem<String?>(value: "Ativo", child: Text("Ativo")),
                      DropdownMenuItem<String?>(value: "Pouca atividade", child: Text("Pouca atividade")),
                      DropdownMenuItem<String?>(value: "Sem lives recentes", child: Text("Sem lives recentes")),
                      DropdownMenuItem<String?>(value: "Inativo", child: Text("Inativo")),
                    ],
                    onChanged: (v) => setState(() => _statusFilter = v),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(filtered.length.toString() + " streamers", style: const TextStyle(color: Colors.white54)),
              const SizedBox(height: 8),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text("Nenhum streamer atribuido a voce ainda.", style: TextStyle(color: Colors.white54)))
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final s = filtered[index];
                          final status = computeStreamerStatus(s);
                          final catData = s["streamer_categories"];
                          final joined = DateTime.parse(s["joined_at"] as String);
                          final daysSince = DateTime.now().difference(joined).inDays;
                          return Card(
                            color: Colors.white.withOpacity(0.05),
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              onTap: () => showDialog(context: context, builder: (context) => StreamerFichaDialog(streamer: s)),
                              leading: CircleAvatar(
                                radius: 18,
                                backgroundColor: Colors.white24,
                                backgroundImage: s["avatar_url"] != null ? NetworkImage(s["avatar_url"] as String) : null,
                                child: s["avatar_url"] == null ? const Icon(Icons.person, color: Colors.white54, size: 18) : null,
                              ),
                              title: Text(s["display_name"] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                (s["tiktok_creator_id"] ?? "-") + "  -  " + (catData is Map ? catData["name"] as String? ?? "-" : "-") + "  -  Ha " + daysSince.toString() + " dias",
                                style: const TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(border: Border.all(color: status.$2), borderRadius: BorderRadius.circular(8)),
                                child: Text(status.$3 + " " + status.$1, style: TextStyle(color: status.$2, fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
