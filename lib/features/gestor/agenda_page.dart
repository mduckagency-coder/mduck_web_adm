import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "agenda_filters.dart";
import "streamer_side_panel.dart";
import "streamer_tasks_service.dart";

/// Agenda -- lista das tarefas (streamer_tasks) agrupadas por prazo, geradas
/// a partir do campo "Proxima acao" que ja e preenchido no painel lateral
/// (streamer_side_panel.dart) e mostrado tambem nas listas de Novatos/
/// Streamers -- um so caminho de escrita, tres jeitos de exibir a mesma
/// tarefa.
class AgendaPage extends StatefulWidget {
  const AgendaPage({super.key});

  @override
  State<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends State<AgendaPage> {
  late Future<List<AgendaTask>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<AgendaTask>> _load() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;
    final me = await client
        .from("managers")
        .select("agency_id")
        .eq("id", userId)
        .single();
    return fetchAgendaTasks(agencyId: me["agency_id"] as String);
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _complete(AgendaTask t) async {
    await completeTask(t.task.id);
    _reload();
  }

  static const _bucketOrder = [
    AgendaBucket.hoje,
    AgendaBucket.estaSemana,
    AgendaBucket.atrasados,
    AgendaBucket.concluidos,
  ];

  static const _bucketColors = {
    AgendaBucket.hoje: Color(0xFF7A0BD4),
    AgendaBucket.estaSemana: Colors.cyanAccent,
    AgendaBucket.atrasados: Colors.redAccent,
    AgendaBucket.concluidos: Colors.greenAccent,
  };

  Widget _taskRow(AgendaTask t, Color color) {
    final task = t.task;
    final done = task.completedAt != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          if (task.dueAt != null)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Text(
                task.dueAt!.toLocal().toString().substring(11, 16),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          InkWell(
            onTap: () =>
                openStreamerSidePanel(context, streamerId: task.streamerId),
            child: CircleAvatar(
              radius: 14,
              backgroundColor: Colors.white24,
              backgroundImage: t.streamerAvatarUrl != null
                  ? NetworkImage(t.streamerAvatarUrl!)
                  : null,
              child: t.streamerAvatarUrl == null
                  ? const Icon(Icons.person, color: Colors.white54, size: 14)
                  : null,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              onTap: () =>
                  openStreamerSidePanel(context, streamerId: task.streamerId),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.streamerName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    task.title,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          if (!done)
            IconButton(
              icon: const Icon(
                Icons.check_circle_outline,
                color: Colors.greenAccent,
              ),
              tooltip: "Concluir",
              onPressed: () => _complete(t),
            )
          else
            const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
        ],
      ),
    );
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
              const Text(
                "Agenda",
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
            "Tarefas geradas a partir da \"Próxima ação\" de cada streamer -- defina/edite pelo painel lateral.",
            style: TextStyle(
              color: Colors.white38,
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<AgendaTask>>(
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
                final grouped = groupAgendaTasks(snapshot.data!);
                final anyTask = grouped.values.any((l) => l.isNotEmpty);
                if (!anyTask) {
                  return const Center(
                    child: Text(
                      "Nenhuma tarefa cadastrada ainda.",
                      style: TextStyle(color: Colors.white54),
                    ),
                  );
                }
                return ListView(
                  children: _bucketOrder.expand((bucket) {
                    final tasks = grouped[bucket]!;
                    if (tasks.isEmpty) return const <Widget>[];
                    final color = _bucketColors[bucket]!;
                    return [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8, top: 12),
                        child: Row(
                          children: [
                            Icon(Icons.circle, size: 8, color: color),
                            const SizedBox(width: 6),
                            Text(
                              agendaBucketLabels[bucket]! +
                                  " (" +
                                  tasks.length.toString() +
                                  ")",
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...tasks.map((t) => _taskRow(t, color)),
                    ];
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
