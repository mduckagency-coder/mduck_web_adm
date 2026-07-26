import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "programa_history_helpers.dart";

const _actionLabels = {
  "entrada_programa": "Entrou no programa",
  "mudanca_etapa": "Mudanca de etapa",
  "avaliacao_final": "Avaliacao final",
  "premiacao_registrada": "Premiacao registrada",
  "premiacao_entregue": "Premiacao entregue",
  "promovido_campanha": "Promovido (campanha mensal)",
  "observacao": "Observacao",
};

class ProgramaHistoricoTab extends StatefulWidget {
  final Map<String, dynamic> program;
  const ProgramaHistoricoTab({super.key, required this.program});

  @override
  State<ProgramaHistoricoTab> createState() => _ProgramaHistoricoTabState();
}

class _ProgramaHistoricoTabState extends State<ProgramaHistoricoTab> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final client = Supabase.instance.client;
    final rows = await client
        .from("streamer_phase_history")
        .select("action, detail, created_at, streamer:profiles(display_name), manager:managers(login_email)")
        .eq("phase_key", widget.program["program_key"])
        .order("created_at", ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text("Historico", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(width: 12),
            IconButton(icon: const Icon(Icons.refresh, color: Colors.white70), onPressed: _reload),
          ]),
          const SizedBox(height: 4),
          const Text("Quem entrou, concluiu, foi reprovado, promovido ou desligado neste programa.", style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic)),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.hasError) return buildProgramasLoadError(snapshot.error!);
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final list = snapshot.data!;
                if (list.isEmpty) return const Center(child: Text("Nenhum registro ainda.", style: TextStyle(color: Colors.white54)));
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final h = list[index];
                    final streamer = h["streamer"];
                    final manager = h["manager"];
                    final streamerName = streamer is Map ? (streamer["display_name"] as String? ?? "-") : "-";
                    final managerEmail = manager is Map ? manager["login_email"] as String? : null;
                    final date = h["created_at"] != null ? DateTime.parse(h["created_at"] as String).toLocal().toString().substring(0, 16) : "-";
                    final label = _actionLabels[h["action"]] ?? (h["action"] as String? ?? "-");
                    final detail = h["detail"] as String?;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.circle, size: 8, color: Color(0xFF7A0BD4)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(date, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                Text(streamerName + "  -  " + label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                if (detail != null && detail.isNotEmpty) Text(detail, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                if (managerEmail != null) Text("Responsavel: " + managerEmail, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                              ],
                            ),
                          ),
                        ],
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
