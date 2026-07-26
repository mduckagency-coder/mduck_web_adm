import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "programa_history_helpers.dart";
import "program_visual.dart";
import "programa_visao_geral_tab.dart";
import "programa_fluxo_tab.dart";
import "programa_participantes_tab.dart";
import "programa_premiacoes_tab.dart";
import "programa_anotacoes_tab.dart";
import "programa_configuracoes_tab.dart";
import "programa_historico_tab.dart";

class ProgramaDetailPage extends StatefulWidget {
  final String programId;
  const ProgramaDetailPage({super.key, required this.programId});

  @override
  State<ProgramaDetailPage> createState() => _ProgramaDetailPageState();
}

class _ProgramaDetailPageState extends State<ProgramaDetailPage> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final client = Supabase.instance.client;
    final program = await client.from("development_programs").select("*, program_managers:development_program_managers(manager:managers(login_email))").eq("id", widget.programId).single();
    final phaseKey = program["program_key"] as String;

    final progress = await client.from("streamer_phase_progress").select("id, completed_at, outcome, stage_key").eq("phase_key", phaseKey);
    final progressList = (progress as List).cast<Map<String, dynamic>>();

    final stages = await client.from("streamer_phase_stages").select("id, stage_key, is_evaluation_stage").eq("agency_id", program["agency_id"]).eq("phase_key", phaseKey);
    final stageList = (stages as List).cast<Map<String, dynamic>>();
    final evalStageKeys = stageList.where((s) => s["is_evaluation_stage"] == true).map((s) => s["stage_key"] as String).toSet();

    // Metas do programa: concluiram (aprovados/graduados), pendentes (na
    // etapa de avaliacao final aguardando decisao do gestor) e em andamento
    // (todo o resto que ainda esta ativo no fluxo).
    var completedCount = 0;
    var pendingCount = 0;
    var inProgressCount = 0;
    for (final r in progressList) {
      if (r["completed_at"] != null) {
        final outcome = r["outcome"] as String?;
        if (outcome == "aprovado" || outcome == "graduado") completedCount++;
      } else if (evalStageKeys.contains(r["stage_key"]) && r["outcome"] == null) {
        pendingCount++;
      } else {
        inProgressCount++;
      }
    }

    return {
      "program": program,
      "activeCount": pendingCount + inProgressCount,
      "inProgressCount": inProgressCount,
      "pendingCount": pendingCount,
      "completedCount": completedCount,
      "totalCount": progressList.length,
      "hasStages": stageList.isNotEmpty,
    };
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _changeStatus(String newStatus) async {
    final client = Supabase.instance.client;
    try {
      await client.from("development_programs").update({"status": newStatus, "updated_at": DateTime.now().toIso8601String()}).eq("id", widget.programId);
      _reload();
    } catch (e) {
      if (mounted) showProgramasActionError(context, e);
    }
  }

  Future<void> _editTitle(Map<String, dynamic> program) async {
    final controller = TextEditingController(text: program["name"] as String);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text("Editar titulo", style: TextStyle(color: Colors.white)),
        content: TextField(controller: controller, autofocus: true, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Nome", labelStyle: TextStyle(color: Colors.white54))),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
            child: const Text("Salvar"),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || newName == program["name"]) return;
    try {
      await Supabase.instance.client.from("development_programs").update({"name": newName, "updated_at": DateTime.now().toIso8601String()}).eq("id", widget.programId);
      _reload();
    } catch (e) {
      if (mounted) showProgramasActionError(context, e);
    }
  }

  String _responsiblesLabel(Map<String, dynamic> program) {
    final rows = (program["program_managers"] as List?) ?? const [];
    final emails = rows.map((r) {
      final manager = (r as Map)["manager"];
      return manager is Map ? manager["login_email"] as String? : null;
    }).whereType<String>().toList();
    return emails.isEmpty ? "Sem responsavel" : emails.join(", ");
  }

  Widget _buildIdentityImage(Map<String, dynamic> program) {
    final imageUrl = program["image_url"] as String?;
    final color = hexToColor(program["color"] as String? ?? "#7A0BD4");
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => Container(color: const Color(0xFF232323), child: Icon(programIcon(program["icon_key"] as String?), color: color, size: 20)),
          ),
        ),
      );
    }
    return CircleAvatar(radius: 22, backgroundColor: color.withOpacity(0.2), child: Icon(programIcon(program["icon_key"] as String?), size: 20, color: color));
  }

  Widget _metaChip(IconData icon, String text) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: Colors.white54),
      const SizedBox(width: 4),
      Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        toolbarHeight: 40,
        leading: IconButton(icon: const Icon(Icons.arrow_back, size: 20), onPressed: () => Navigator.of(context).pop()),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) return buildProgramasLoadError(snapshot.error!);
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final data = snapshot.data!;
          final program = data["program"] as Map<String, dynamic>;
          final programStatusValue = program["status"] as String? ?? "ativo";
          final hasStages = data["hasStages"] as bool;
          final activeCount = data["activeCount"] as int;
          final inProgressCount = data["inProgressCount"] as int;
          final pendingCount = data["pendingCount"] as int;
          final completedCount = data["completedCount"] as int;
          final goalTotal = activeCount + completedCount;
          final progressFraction = goalTotal == 0 ? 0.0 : (completedCount / goalTotal).clamp(0.0, 1.0);
          final status = programStatus(hasStages: hasStages, status: programStatusValue);
          final startDate = program["start_date"] != null ? DateTime.parse(program["start_date"] as String) : null;
          final endDate = program["end_date"] != null ? DateTime.parse(program["end_date"] as String) : null;

          return DefaultTabController(
            length: 7,
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  color: const Color(0xFF1A1A1A),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              _buildIdentityImage(program),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      Flexible(child: Text(program["name"] as String, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                                      IconButton(
                                        icon: const Icon(Icons.edit, size: 14, color: Colors.white54),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () => _editTitle(program),
                                      ),
                                      const Spacer(),
                                      if (hasStages)
                                        DropdownButton<String>(
                                          value: programStatusValue,
                                          dropdownColor: const Color(0xFF232323),
                                          underline: const SizedBox.shrink(),
                                          style: TextStyle(color: status.$2, fontWeight: FontWeight.bold, fontSize: 12),
                                          items: const [
                                            DropdownMenuItem(value: "ativo", child: Text("Ativo")),
                                            DropdownMenuItem(value: "pausado", child: Text("Pausado")),
                                            DropdownMenuItem(value: "encerrado", child: Text("Encerrado")),
                                          ],
                                          onChanged: (v) => v != null ? _changeStatus(v) : null,
                                        )
                                      else
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(color: status.$2.withOpacity(0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: status.$2)),
                                          child: Text(status.$1, style: TextStyle(color: status.$2, fontSize: 10, fontWeight: FontWeight.bold)),
                                        ),
                                    ]),
                                    if ((program["description"] as String?)?.isNotEmpty == true)
                                      Text(program["description"] as String, style: const TextStyle(color: Colors.white70, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                            ]),
                            const SizedBox(height: 6),
                            Wrap(spacing: 14, runSpacing: 4, children: [
                              _metaChip(Icons.people_outline, _responsiblesLabel(program)),
                              _metaChip(Icons.groups_outlined, activeCount.toString() + " participantes"),
                              _metaChip(Icons.emoji_events_outlined, completedCount.toString() + " concluidos"),
                              if (startDate != null) _metaChip(Icons.event, "Desde " + startDate.toLocal().toString().substring(0, 10)),
                              if (endDate != null) _metaChip(Icons.event_busy, "Ate " + endDate.toLocal().toString().substring(0, 10)),
                            ]),
                            const SizedBox(height: 6),
                            Row(children: [
                              SizedBox(
                                width: 100,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(value: progressFraction, minHeight: 4, backgroundColor: Colors.white12, valueColor: const AlwaysStoppedAnimation(Color(0xFF7A0BD4))),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text((progressFraction * 100).toStringAsFixed(0) + "%", style: const TextStyle(color: Colors.white70, fontSize: 11)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  completedCount.toString() + " concluiram  •  " + inProgressCount.toString() + " em andamento  •  " + pendingCount.toString() + " pendentes",
                                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ]),
                          ],
                        ),
                      ),
                      const TabBar(
                        isScrollable: true,
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.white54,
                        indicatorColor: Color(0xFF7A0BD4),
                        tabs: [
                          Tab(text: "Visao Geral"),
                          Tab(text: "Fluxo"),
                          Tab(text: "Participantes"),
                          Tab(text: "Premiacoes"),
                          Tab(text: "Anotacoes"),
                          Tab(text: "Configuracoes"),
                          Tab(text: "Historico"),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(children: [
                    ProgramaVisaoGeralTab(program: program, onChanged: _reload),
                    ProgramaFluxoTab(program: program),
                    ProgramaParticipantesTab(program: program),
                    ProgramaPremiacoesTab(program: program),
                    ProgramaAnotacoesTab(program: program),
                    ProgramaConfiguracoesTab(program: program, onChanged: _reload),
                    ProgramaHistoricoTab(program: program),
                  ]),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
