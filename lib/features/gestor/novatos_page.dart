import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "gestor_streamer_service.dart";
import "streamer_list_view.dart";

/// "Novatos (Ate 90 Dias)" -- lista propria (nao reaproveita o programa
/// "Novatos 90 Dias" de Programas de Desenvolvimento, que e criterio-
/// automatico/nao-Kanban; essa e uma tela nova, dados proprios, decisao
/// confirmada com o usuario). So um filtro por dias na agencia + potencial
/// sobre a mesma StreamerListView reusada depois pela tela Streamers.
class NovatosPage extends StatefulWidget {
  const NovatosPage({super.key});

  @override
  State<NovatosPage> createState() => _NovatosPageState();
}

class _NovatosPageState extends State<NovatosPage> {
  late Future<List<GestorStreamerRow>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<GestorStreamerRow>> _load() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;
    final me = await client
        .from("managers")
        .select("agency_id")
        .eq("id", userId)
        .single();
    final agencyId = me["agency_id"] as String;
    final all = await fetchGestorStreamerRows(agencyId: agencyId);
    return all.where((r) => r.daysInAgency <= 90).toList();
  }

  void _reload() => setState(() => _future = _load());

  static final _quickFilters = [
    StreamerQuickFilter(label: "Todos", predicate: (r) => true),
    StreamerQuickFilter(
      label: "Até 30 dias",
      predicate: (r) => r.daysInAgency <= 30,
    ),
    StreamerQuickFilter(
      label: "Até 60 dias",
      predicate: (r) => r.daysInAgency <= 60,
    ),
    StreamerQuickFilter(
      label: "Até 90 dias",
      predicate: (r) => r.daysInAgency <= 90,
    ),
    StreamerQuickFilter(
      label: "Alto Potencial",
      predicate: (r) => r.potentialLevel == "alto",
    ),
    StreamerQuickFilter(
      label: "Potencial Médio",
      predicate: (r) => r.potentialLevel == "medio",
    ),
    StreamerQuickFilter(
      label: "Baixo Potencial",
      predicate: (r) => r.potentialLevel == "baixo",
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                "Novatos (Até 90 Dias)",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white70),
                onPressed: _reload,
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            "Streamers com até 90 dias de agência, com informações de potencial, acompanhamento e próxima ação.",
            style: TextStyle(
              color: Colors.white38,
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<GestorStreamerRow>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      "Erro ao carregar: " + snapshot.error.toString(),
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return StreamerListView(
                  rows: snapshot.data!,
                  quickFilters: _quickFilters,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
