import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "program_participation_service.dart";
import "program_phase_service.dart";
import "programa_detail_page.dart";
import "programa_history_helpers.dart";
import "program_visual.dart";

class ProgramasPage extends StatefulWidget {
  const ProgramasPage({super.key});

  @override
  State<ProgramasPage> createState() => _ProgramasPageState();
}

class _ProgramasPageState extends State<ProgramasPage> {
  bool _loading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _programs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final client = Supabase.instance.client;
      final agencyId = await currentAgencyId();
      await seedDevelopmentPrograms(agencyId: agencyId);

      final programs = await client.from("development_programs").select("*, program_managers:development_program_managers(manager:managers(login_email))").eq("agency_id", agencyId).order("order_index");
      final programList = (programs as List).cast<Map<String, dynamic>>();
      final phaseKeys = programList.map((p) => p["program_key"] as String).toList();
      final programIds = programList.map((p) => p["id"] as String).toList();

      final progressRows = phaseKeys.isEmpty ? [] : await client.from("streamer_phase_progress").select("phase_key, stage_key, outcome, completed_at").inFilter("phase_key", phaseKeys);
      final stageRows = phaseKeys.isEmpty
          ? []
          : await client.from("streamer_phase_stages").select("phase_key, stage_key, is_evaluation_stage").eq("agency_id", agencyId).inFilter("phase_key", phaseKeys);
      final awardRows = programIds.isEmpty ? [] : await client.from("program_awards").select("program_id, status").inFilter("program_id", programIds);
      final stageCountsByProgram = await fetchParticipationStageCountsByProgram(programIds: programIds);

      final progressByPhase = <String, List<Map<String, dynamic>>>{};
      for (final r in (progressRows as List)) {
        progressByPhase.putIfAbsent(r["phase_key"] as String, () => []).add(r as Map<String, dynamic>);
      }
      final evalStagesByPhase = <String, Set<String>>{};
      final hasStagesByPhase = <String, bool>{};
      for (final r in (stageRows as List)) {
        final phaseKey = r["phase_key"] as String;
        hasStagesByPhase[phaseKey] = true;
        if (r["is_evaluation_stage"] == true) evalStagesByPhase.putIfAbsent(phaseKey, () => {}).add(r["stage_key"] as String);
      }
      final pendingAwardsByProgram = <String, int>{};
      for (final r in (awardRows as List)) {
        if (r["status"] == "pendente") {
          final programId = r["program_id"] as String;
          pendingAwardsByProgram[programId] = (pendingAwardsByProgram[programId] ?? 0) + 1;
        }
      }

      for (final p in programList) {
        final phaseKey = p["program_key"] as String;
        final progress = progressByPhase[phaseKey] ?? const [];
        final active = progress.where((r) => r["completed_at"] == null).toList();
        final completed = progress.where((r) => r["completed_at"] != null).toList();
        final evalStages = evalStagesByPhase[phaseKey] ?? const {};
        final pendingEvaluations = active.where((r) => evalStages.contains(r["stage_key"]) && r["outcome"] == null).length;

        p["participantCount"] = active.length;
        p["progressFraction"] = progress.isEmpty ? 0.0 : completed.length / progress.length;
        p["pendingCount"] = pendingEvaluations;
        p["pendingAwards"] = pendingAwardsByProgram[p["id"]] ?? 0;
        p["hasStages"] = hasStagesByPhase[phaseKey] ?? false;

        final stageCounts = stageCountsByProgram[p["id"]] ?? const {};
        p["participationTotal"] = stageCounts["_total"] ?? 0;
        p["participationEmAndamento"] = stageCounts["em_andamento"] ?? 0;
        p["participationPendenteEntrega"] = stageCounts["pendente_entrega"] ?? 0;
      }

      setState(() {
        _programs = programList;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _loading = false;
      });
    }
  }

  void _openDetail(Map<String, dynamic> program) {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => ProgramaDetailPage(programId: program["id"] as String))).then((_) => _load());
  }

  void _openCreateDialog() {
    showDialog(context: context, builder: (context) => const _NewProgramDialog()).then((created) {
      if (created == true) _load();
    });
  }

  Future<void> _editProgram(Map<String, dynamic> program) async {
    final saved = await showEditProgramDialog(context, program);
    if (saved) _load();
  }

  /// Programas fixos (developmentProgramKeys) tambem podem ser excluidos --
  /// deleteDevelopmentProgram registra a exclusao em
  /// development_programs_dismissed pra seedDevelopmentPrograms parar de
  /// recriar esse program_key sozinho na proxima abertura da tela.
  Future<void> _deleteProgram(Map<String, dynamic> program) async {
    final isFixed = developmentProgramKeys.contains(program["program_key"] as String);
    final ok = await confirmAction(
      context,
      title: "Excluir programa",
      message: "Excluir \"" +
          (program["name"] as String) +
          "\"? Premiacoes, participacoes e anotacoes deste programa tambem sao apagadas." +
          (isFixed ? " E um programa padrao -- excluido, ele nao volta a aparecer sozinho." : "") +
          " Essa acao nao pode ser desfeita.",
      confirmLabel: "Excluir",
      confirmColor: Colors.redAccent,
    );
    if (!ok) return;
    try {
      final client = Supabase.instance.client;
      await deleteDevelopmentProgram(
        programId: program["id"] as String,
        programKey: program["program_key"] as String,
        agencyId: program["agency_id"] as String,
        deletedBy: client.auth.currentUser!.id,
      );
      _load();
    } catch (e) {
      if (mounted) showProgramasActionError(context, e);
    }
  }

  /// Segura e arrasta um card sobre outro pra reordenar -- tira o arrastado
  /// da posicao antiga e insere na posicao do alvo, depois renumera
  /// order_index de todo mundo em sequencia (1, 2, 3...) pra refletir a
  /// nova ordem exata, ja que um arraste pode pular varias posicoes de uma
  /// vez (trocar so 2 valores, como um botao subir/descer faria, nao e
  /// suficiente aqui).
  Future<void> _reorderPrograms(Map<String, dynamic> dragged, Map<String, dynamic> target) async {
    if (dragged["id"] == target["id"]) return;
    final newList = List<Map<String, dynamic>>.from(_programs);
    final fromIndex = newList.indexWhere((p) => p["id"] == dragged["id"]);
    final toIndex = newList.indexWhere((p) => p["id"] == target["id"]);
    if (fromIndex == -1 || toIndex == -1) return;
    final item = newList.removeAt(fromIndex);
    newList.insert(toIndex, item);
    setState(() => _programs = newList);
    try {
      final client = Supabase.instance.client;
      for (var i = 0; i < newList.length; i++) {
        await client.from("development_programs").update({"order_index": i + 1}).eq("id", newList[i]["id"]);
      }
    } catch (e) {
      if (mounted) showProgramasActionError(context, e);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null) return buildProgramasLoadError(_errorMessage!);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text("Programas de Desenvolvimento", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(width: 12),
            IconButton(icon: const Icon(Icons.refresh, color: Colors.white70), onPressed: _load),
            IconButton(tooltip: "Novo programa", icon: const Icon(Icons.add_circle_outline, color: Colors.white70), onPressed: _openCreateDialog),
          ]),
          const SizedBox(height: 4),
          const Text("A jornada completa do streamer na agencia, do Onboarding a Elite.", style: TextStyle(color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic)),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final p in _programs)
                    _ProgramCard(
                      program: p,
                      onTap: () => _openDetail(p),
                      onEdit: () => _editProgram(p),
                      onDelete: () => _deleteProgram(p),
                      onReorder: (dragged) => _reorderPrograms(dragged, p),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgramCard extends StatelessWidget {
  final Map<String, dynamic> program;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<Map<String, dynamic>> onReorder;
  const _ProgramCard({
    required this.program,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onReorder,
  });

  String _responsiblesLabel() {
    final rows = (program["program_managers"] as List?) ?? const [];
    final emails = rows.map((r) {
      final manager = (r as Map)["manager"];
      return manager is Map ? manager["login_email"] as String? : null;
    }).whereType<String>().toList();
    return emails.isEmpty ? "Nao definido" : emails.join(", ");
  }

  Widget _buildIcon(Color color) {
    final imageUrl = program["image_url"] as String?;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 26,
          height: 26,
          child: Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (context, error, stack) => Icon(programIcon(program["icon_key"] as String?), color: color, size: 22)),
        ),
      );
    }
    return Icon(programIcon(program["icon_key"] as String?), color: color, size: 22);
  }

  Widget _buildCardContent(BuildContext context) {
    final hasStages = program["hasStages"] as bool? ?? false;
    final status = programStatus(hasStages: hasStages, status: program["status"] as String? ?? "ativo");
    final color = hexToColor(program["color"] as String? ?? "#7A0BD4");
    final progressFraction = (program["progressFraction"] as double? ?? 0.0).clamp(0.0, 1.0);
    final participantCount = program["participantCount"] as int? ?? 0;
    final pendingCount = program["pendingCount"] as int? ?? 0;
    final pendingAwards = program["pendingAwards"] as int? ?? 0;
    final participationTotal = program["participationTotal"] as int? ?? 0;
    final participationEmAndamento = program["participationEmAndamento"] as int? ?? 0;
    final participationPendenteEntrega = program["participationPendenteEntrega"] as int? ?? 0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              _buildIcon(color),
              const SizedBox(width: 8),
              Expanded(child: Text(program["name"] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15), overflow: TextOverflow.ellipsis)),
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.more_vert, size: 18, color: Colors.white38),
                color: const Color(0xFF232323),
                onSelected: (v) {
                  if (v == "edit") onEdit();
                  if (v == "delete") onDelete();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: "edit", child: Text("Editar", style: TextStyle(color: Colors.white, fontSize: 13))),
                  PopupMenuItem(value: "delete", child: Text("Excluir", style: TextStyle(color: Colors.redAccent, fontSize: 13))),
                ],
              ),
            ]),
            const SizedBox(height: 6),
            if ((program["description"] as String?)?.isNotEmpty == true)
              Text(program["description"] as String, style: const TextStyle(color: Colors.white54, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: status.$2.withOpacity(0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: status.$2)),
              child: Text(status.$1, style: TextStyle(color: status.$2, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 10),
            Text("Responsaveis: " + _responsiblesLabel(), style: const TextStyle(color: Colors.white54, fontSize: 11)),
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.people_outline, size: 14, color: Colors.white38),
              const SizedBox(width: 4),
              Text(participantCount.toString() + " participantes", style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ]),
            if (participationTotal > 0) ...[
              const SizedBox(height: 4),
              Wrap(spacing: 6, runSpacing: 4, children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.groups, size: 12, color: Color(0xFF7A0BD4)),
                  const SizedBox(width: 3),
                  Text(participationTotal.toString() + " no Fluxo", style: const TextStyle(color: Color(0xFF7A0BD4), fontSize: 10, fontWeight: FontWeight.bold)),
                ]),
                if (participationEmAndamento > 0)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.hourglass_bottom, size: 12, color: Colors.blueAccent),
                    const SizedBox(width: 3),
                    Text(participationEmAndamento.toString() + " em andamento", style: const TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                  ]),
                if (participationPendenteEntrega > 0)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.payments, size: 12, color: Colors.amber),
                    const SizedBox(width: 3),
                    Text(participationPendenteEntrega.toString() + " pendente de pagamento", style: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
                  ]),
              ]),
            ],
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: progressFraction, minHeight: 6, backgroundColor: Colors.white12, valueColor: const AlwaysStoppedAnimation(Color(0xFF7A0BD4))),
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 4, children: [
              if (pendingCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                  child: Text(pendingCount.toString() + " pendencia(s)", style: const TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              if (pendingAwards > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.pinkAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                  child: Text(pendingAwards.toString() + " premiacao(oes) pendente(s)", style: const TextStyle(color: Colors.pinkAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
            ]),
          ],
        ),
      ),
    );
  }

  /// Clica e arrasta (Draggable -- mesmo padrao ja usado no quadro Fluxo,
  /// que funciona com mouse; LongPressDraggable e pensado pra toque e nao
  /// respondia bem a clique+arraste com mouse no desktop/web) sobre outro
  /// card pra reordenar. O card-alvo (DragTarget) e que recebe o solto e
  /// dispara onReorder. Um clique parado (sem mover o mouse) continua
  /// funcionando como toque normal, abrindo o programa.
  @override
  Widget build(BuildContext context) {
    return DragTarget<Map<String, dynamic>>(
      onWillAcceptWithDetails: (details) => details.data["id"] != program["id"],
      onAcceptWithDetails: (details) => onReorder(details.data),
      builder: (context, candidateData, rejectedData) {
        final highlighting = candidateData.isNotEmpty;
        final content = _buildCardContent(context);
        final card = highlighting
            ? Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF7A0BD4), width: 2),
                ),
                child: content,
              )
            : content;
        return Draggable<Map<String, dynamic>>(
          data: program,
          feedback: Material(
            color: Colors.transparent,
            child: SizedBox(width: 300, child: content),
          ),
          childWhenDragging: Opacity(opacity: 0.3, child: card),
          child: card,
        );
      },
    );
  }
}

/// Cria um programa alem dos 6 fixos -- nasce sem etapas (100%
/// configuravel em Configuracoes, igual os fixos ficam antes de terem um
/// fluxo definido) e ja aparece nos dropdowns de encadeamento dos outros
/// programas (essas queries listam qualquer programa da agencia).
class _NewProgramDialog extends StatefulWidget {
  const _NewProgramDialog();

  @override
  State<_NewProgramDialog> createState() => _NewProgramDialogState();
}

class _NewProgramDialogState extends State<_NewProgramDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _saving = false;
  String? _error;

  Future<void> _create() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final client = Supabase.instance.client;
      final agencyId = await currentAgencyId();
      final existing = await client.from("development_programs").select("order_index").eq("agency_id", agencyId).order("order_index", ascending: false).limit(1).maybeSingle();
      final nextOrder = ((existing?["order_index"] as int?) ?? 0) + 1;
      await client.from("development_programs").insert({
        "agency_id": agencyId,
        "program_key": "custom_" + DateTime.now().millisecondsSinceEpoch.toString(),
        "order_index": nextOrder,
        "name": _nameController.text.trim(),
        "description": _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = "Erro: " + e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Novo programa", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text("Nasce sem fluxo definido -- configure tudo depois na aba Configuracoes do programa.", style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic)),
              const SizedBox(height: 16),
              TextField(controller: _nameController, autofocus: true, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Nome", labelStyle: TextStyle(color: Colors.white54))),
              const SizedBox(height: 8),
              TextField(controller: _descriptionController, maxLines: 2, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Descricao (opcional)", labelStyle: TextStyle(color: Colors.white54))),
              if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12))),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancelar")),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _saving ? null : _create,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
                  child: Text(_saving ? "Criando..." : "Criar"),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
