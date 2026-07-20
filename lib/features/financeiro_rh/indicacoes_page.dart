import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";

class IndicacoesPage extends StatefulWidget {
  const IndicacoesPage({super.key});

  @override
  State<IndicacoesPage> createState() => _IndicacoesPageState();
}

class _IndicacoesPageState extends State<IndicacoesPage> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final client = Supabase.instance.client;
    final rows = await client
        .from("leads")
        .select("name, origin_detail, status, created_at, converted_at, managers(login_email)")
        .eq("origin", "Indicacao")
        .order("created_at", ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.record_voice_over, color: Color(0xFF7A0BD4)),
            const SizedBox(width: 10),
            const Text("Indicacoes", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(width: 12),
            IconButton(icon: const Icon(Icons.refresh, color: Colors.white70), onPressed: () => setState(() => _future = _load())),
          ]),
          const SizedBox(height: 4),
          const Text("Streamers que entraram na agencia atraves de indicacao, e quem foi o recrutador responsavel.", style: TextStyle(color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic)),
          const SizedBox(height: 20),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final all = snapshot.data!;
                final agenciados = all.where((l) => l["status"] == "agenciado").toList();
                final emAndamento = all.where((l) => l["status"] != "agenciado").toList();

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(spacing: 12, children: [
                        _summaryCard("Total de Indicacoes", all.length.toString(), Icons.people, const Color(0xFF7A0BD4)),
                        _summaryCard("Agenciados", agenciados.length.toString(), Icons.verified, Colors.greenAccent),
                        _summaryCard("Em andamento", emAndamento.length.toString(), Icons.hourglass_bottom, Colors.orangeAccent),
                      ]),
                      const SizedBox(height: 24),
                      const Text("Agenciados por Indicacao", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 12),
                      if (agenciados.isEmpty)
                        const Text("Nenhum streamer agenciado por indicacao ainda.", style: TextStyle(color: Colors.white54, fontSize: 13))
                      else
                        Container(
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(14)),
                          child: Column(
                            children: agenciados.map((l) {
                              final recruiter = l["managers"];
                              final recruiterEmail = recruiter is Map ? recruiter["login_email"] as String? ?? "-" : "-";
                              final date = l["converted_at"] != null ? DateTime.parse(l["converted_at"] as String).toLocal().toString().substring(0, 10) : "-";
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white12))),
                                child: Row(children: [
                                  Expanded(flex: 2, child: Text(l["name"] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
                                  Expanded(flex: 2, child: Text("Indicado por: " + ((l["origin_detail"] as String?)?.isNotEmpty == true ? l["origin_detail"] as String : "-"), style: const TextStyle(color: Colors.white70, fontSize: 12))),
                                  Expanded(flex: 2, child: Text("Agenciado por: " + recruiterEmail, style: const TextStyle(color: Colors.white70, fontSize: 12))),
                                  Text(date, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                                ]),
                              );
                            }).toList(),
                          ),
                        ),
                      const SizedBox(height: 24),
                      const Text("Em Andamento", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 12),
                      if (emAndamento.isEmpty)
                        const Text("Nenhuma indicacao em andamento.", style: TextStyle(color: Colors.white54, fontSize: 13))
                      else
                        Container(
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(14)),
                          child: Column(
                            children: emAndamento.map((l) {
                              final recruiter = l["managers"];
                              final recruiterEmail = recruiter is Map ? recruiter["login_email"] as String? ?? "-" : "-";
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white12))),
                                child: Row(children: [
                                  Expanded(flex: 2, child: Text(l["name"] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
                                  Expanded(flex: 2, child: Text("Indicado por: " + ((l["origin_detail"] as String?)?.isNotEmpty == true ? l["origin_detail"] as String : "-"), style: const TextStyle(color: Colors.white70, fontSize: 12))),
                                  Expanded(flex: 2, child: Text("Recrutador: " + recruiterEmail, style: const TextStyle(color: Colors.white70, fontSize: 12))),
                                  Text(l["status"] as String, style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                                ]),
                              );
                            }).toList(),
                          ),
                        ),
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

  Widget _summaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.4))),
      child: Row(children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
            Text(title, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      ]),
    );
  }
}
