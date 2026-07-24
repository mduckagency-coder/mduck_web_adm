import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "event_history_service.dart";

const _actionLabels = {
  "criacao": "Evento criado",
  "edicao": "Dados do evento atualizados",
  "mudanca_status": "Mudanca de status",
  "cronograma_adicionado": "Atividade adicionada ao cronograma",
  "cronograma_atualizado": "Atividade do cronograma atualizada",
  "cronograma_removido": "Atividade do cronograma removida",
  "tarefa_criada": "Tarefa criada",
  "tarefa_atualizada": "Tarefa atualizada",
  "tarefa_removida": "Tarefa removida",
  "tarefa_checklist": "Item de checklist marcado",
  "participante_adicionado": "Participante adicionado",
  "participante_removido": "Participante removido",
  "premiacao_adicionada": "Premiacao adicionada",
  "premiacao_atualizada": "Premiacao atualizada",
  "premiacao_removida": "Premiacao removida",
  "premiacao_entregue": "Premiacao entregue",
  "premiacao_pendente": "Premiacao marcada como pendente",
  "orcamento_definido": "Orcamento definido",
  "financeiro_lancamento": "Lancamento financeiro adicionado",
  "financeiro_atualizado": "Lancamento financeiro atualizado",
  "financeiro_removido": "Lancamento financeiro removido",
  "arquivo_anexado": "Arquivo anexado",
  "arquivo_removido": "Arquivo removido",
};

class EventHistoricoTab extends StatefulWidget {
  final String eventId;
  const EventHistoricoTab({super.key, required this.eventId});

  @override
  State<EventHistoricoTab> createState() => _EventHistoricoTabState();
}

class _EventHistoricoTabState extends State<EventHistoricoTab> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final client = Supabase.instance.client;
    final rows = await client.from("event_history").select("*, managers(login_email)").eq("event_id", widget.eventId).order("created_at", ascending: false);
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
            const Text("Historico", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(width: 12),
            IconButton(icon: const Icon(Icons.refresh, color: Colors.white70), onPressed: () => setState(() { _future = _load(); })),
          ]),
          const SizedBox(height: 4),
          const Text("Registro automatico de tudo que acontece neste evento.", style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic)),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.hasError) return buildEventosLoadError(snapshot.error!);
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final list = snapshot.data!;
                if (list.isEmpty) return const Center(child: Text("Nenhum registro ainda.", style: TextStyle(color: Colors.white54)));
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final h = list[index];
                    final date = DateTime.parse(h["created_at"] as String).toLocal().toString().substring(0, 16);
                    final performerData = h["managers"];
                    final label = _actionLabels[h["action"]] ?? h["action"] as String;
                    final detail = h["detail"] as String?;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.circle, size: 8, color: Color(0xFF7A0BD4)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  date + (performerData is Map ? "  -  " + (performerData["login_email"] as String? ?? "-") : ""),
                                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                                ),
                                Text(label + (detail != null && detail.isNotEmpty ? ": " + detail : ""), style: const TextStyle(color: Colors.white, fontSize: 13)),
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
