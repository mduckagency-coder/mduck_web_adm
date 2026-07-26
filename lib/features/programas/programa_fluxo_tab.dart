import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "program_phase_service.dart";
import "program_eligibility_service.dart";
import "programa_history_helpers.dart";

Color _hexToColor(String hex) {
  final cleaned = hex.replaceFirst("#", "");
  return Color(int.parse("FF" + cleaned, radix: 16));
}

class ProgramaFluxoTab extends StatefulWidget {
  final Map<String, dynamic> program;
  const ProgramaFluxoTab({super.key, required this.program});

  @override
  State<ProgramaFluxoTab> createState() => _ProgramaFluxoTabState();
}

class _ProgramaFluxoTabState extends State<ProgramaFluxoTab> {
  bool _loading = true;
  String? _errorMessage;
  bool _syncing = false;
  List<Map<String, dynamic>> _stages = [];
  List<Map<String, dynamic>> _cards = [];
  final _horizontalController = ScrollController();

  String get _phaseKey => widget.program["program_key"] as String;
  String get _agencyId => widget.program["agency_id"] as String;

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

      final stageRows = await client
          .from("streamer_phase_stages")
          .select()
          .eq("agency_id", _agencyId)
          .eq("phase_key", _phaseKey)
          .eq("is_active", true)
          .order("order_index", ascending: true);
      final stages = (stageRows as List).cast<Map<String, dynamic>>();

      final progressRows = await client
          .from("streamer_phase_progress")
          .select("id, streamer_id, stage_key, stage_changed_at, outcome, completed_at, streamer:profiles(id, display_name, avatar_url, tiktok_creator_id)")
          .eq("phase_key", _phaseKey)
          .filter("completed_at", "is", null)
          .order("id", ascending: true);

      final cards = (progressRows as List).cast<Map<String, dynamic>>();

      setState(() {
        _stages = stages;
        _cards = cards;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _syncNow() async {
    setState(() => _syncing = true);
    try {
      final client = Supabase.instance.client;
      final criteria = ProgramCriteria.fromMap(widget.program["criteria"] as Map<String, dynamic>?);
      final snapshots = await fetchActiveStreamerSnapshots(agencyId: _agencyId);
      final enrolled = await fetchEnrolledStreamerIds(phaseKey: _phaseKey);

      final previous = await client
          .from("development_programs")
          .select("program_key")
          .eq("agency_id", _agencyId)
          .or("next_program_key.eq." + _phaseKey + ",graduate_program_key.eq." + _phaseKey)
          .maybeSingle();
      final previousKey = previous?["program_key"] as String?;
      final completedPrev = previousKey != null ? await fetchCompletedStreamerIds(phaseKey: previousKey) : null;

      final created = await syncEligibleStreamers(
        phaseKey: _phaseKey,
        criteria: criteria,
        snapshots: snapshots,
        enrolledStreamerIds: enrolled,
        previousProgramCompletedStreamerIds: completedPrev,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(created == 0 ? "Nenhum novo streamer elegivel encontrado." : created.toString() + " streamer(s) entraram automaticamente.")));
      }
      await _load();
    } catch (e) {
      if (mounted) showProgramasActionError(context, e);
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _moveCard(Map<String, dynamic> card, String newStageKey) async {
    final oldStageKey = card["stage_key"] as String;
    if (oldStageKey == newStageKey) return;
    final index = _cards.indexWhere((c) => c["id"] == card["id"]);
    if (index == -1) return;
    setState(() => _cards[index]["stage_key"] = newStageKey);
    try {
      await moveProgramCard(progressId: card["id"] as String, newStageKey: newStageKey);
      final streamer = card["streamer"];
      await logProgramaHistory(
        streamerId: card["streamer_id"] as String,
        phaseKey: _phaseKey,
        action: "mudanca_etapa",
        detail: (streamer is Map ? streamer["display_name"] as String? : "-"),
      );
    } catch (e) {
      setState(() => _cards[index]["stage_key"] = oldStageKey);
      if (mounted) showProgramasActionError(context, e);
    }
  }

  void _openCard(Map<String, dynamic> card, Map<String, dynamic> stage) {
    showDialog(
      context: context,
      builder: (context) => _CardDetailDialog(
        card: card,
        stage: stage,
        program: widget.program,
      ),
    ).then((changed) {
      if (changed == true) _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text("Fluxo", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(width: 12),
            IconButton(icon: const Icon(Icons.refresh, color: Colors.white70), onPressed: _load),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _syncing ? null : _syncNow,
              icon: const Icon(Icons.sync, size: 16),
              label: Text(_syncing ? "Verificando..." : "Verificar elegibilidade agora"),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
            ),
          ]),
          const SizedBox(height: 4),
          const Text(
            "Entrada automatica: streamers que cumprem os criterios configurados entram sozinhos na primeira etapa. Sem criterio definido, ninguem entra automaticamente ainda.",
            style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? buildProgramasLoadError(_errorMessage!)
                    : _stages.isEmpty
                        ? const Center(child: Text("Nenhuma etapa configurada ainda. Configure o fluxo na aba Configuracoes.", style: TextStyle(color: Colors.white54), textAlign: TextAlign.center))
                        : _board(),
          ),
        ],
      ),
    );
  }

  Widget _board() {
    return Scrollbar(
      controller: _horizontalController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _horizontalController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _stages.map((stage) {
            final stageKey = stage["stage_key"] as String;
            final stageColor = _hexToColor(stage["color"] as String? ?? "#7A0BD4");
            final columnCards = _cards.where((c) => c["stage_key"] == stageKey).toList();

            return Container(
              width: 230,
              height: 560,
              margin: const EdgeInsets.only(right: 12),
              child: DragTarget<Map<String, dynamic>>(
                onWillAcceptWithDetails: (details) => details.data["stage_key"] != stageKey,
                onAcceptWithDetails: (details) => _moveCard(details.data, stageKey),
                builder: (context, candidateData, rejectedData) {
                  final highlighting = candidateData.isNotEmpty;
                  return Container(
                    decoration: BoxDecoration(
                      color: highlighting ? stageColor.withOpacity(0.15) : Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: highlighting ? stageColor : Colors.white12),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [stageColor.withOpacity(0.35), stageColor.withOpacity(0.12)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                            border: Border(bottom: BorderSide(color: stageColor, width: 2)),
                          ),
                          child: Column(children: [
                            Text(stage["name"] as String, style: TextStyle(color: stageColor, fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: stageColor.withOpacity(0.25), borderRadius: BorderRadius.circular(10)),
                              child: Text(columnCards.length.toString(), style: TextStyle(color: stageColor, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ]),
                        ),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.all(8),
                            itemCount: columnCards.length,
                            itemBuilder: (context, index) {
                              final card = columnCards[index];
                              final streamer = card["streamer"];
                              final name = streamer is Map ? (streamer["display_name"] as String? ?? "-") : "-";
                              final avatarUrl = streamer is Map ? streamer["avatar_url"] as String? : null;
                              final isEvaluation = stage["is_evaluation_stage"] == true;
                              final tile = InkWell(
                                onTap: () => _openCard(card, stage),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1A1A1A),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: isEvaluation ? Colors.orangeAccent : Colors.white12),
                                  ),
                                  child: Row(children: [
                                    CircleAvatar(radius: 14, backgroundColor: Colors.white24, backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null, child: avatarUrl == null ? const Icon(Icons.person, size: 14, color: Colors.white54) : null),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                                    if (isEvaluation) const Icon(Icons.rate_review, size: 14, color: Colors.orangeAccent),
                                  ]),
                                ),
                              );
                              return Draggable<Map<String, dynamic>>(
                                data: card,
                                feedback: Material(color: Colors.transparent, child: SizedBox(width: 210, child: tile)),
                                childWhenDragging: Opacity(opacity: 0.3, child: tile),
                                child: tile,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _CardDetailDialog extends StatefulWidget {
  final Map<String, dynamic> card;
  final Map<String, dynamic> stage;
  final Map<String, dynamic> program;
  const _CardDetailDialog({required this.card, required this.stage, required this.program});

  @override
  State<_CardDetailDialog> createState() => _CardDetailDialogState();
}

class _CardDetailDialogState extends State<_CardDetailDialog> {
  bool _saving = false;

  Future<void> _evaluate(String outcome) async {
    final streamer = widget.card["streamer"];
    final name = streamer is Map ? (streamer["display_name"] as String? ?? "este streamer") : "este streamer";
    final result = await showDialog<(String?, String?)>(
      context: context,
      builder: (context) => _EvaluationDialog(outcome: outcome, streamerName: name),
    );
    if (result == null) return;
    final reason = result.$1;
    final note = result.$2;
    setState(() => _saving = true);
    try {
      final client = Supabase.instance.client;
      await evaluateProgramCard(
        programId: widget.program["id"] as String,
        phaseKey: widget.program["program_key"] as String,
        progressId: widget.card["id"] as String,
        streamerId: widget.card["streamer_id"] as String,
        outcome: outcome,
        performedBy: client.auth.currentUser!.id,
        reason: reason,
        observacao: (note == null || note.isEmpty) ? null : note,
      );
      if (mounted) {
        const outcomeMessages = {
          "aprovado": "Streamer aprovado.",
          "graduado": "Streamer graduado.",
          "revisao": "Streamer colocado em revisao.",
          "desligado": "Streamer desligado.",
        };
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(outcomeMessages[outcome] ?? "Avaliacao registrada.")));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) showProgramasActionError(context, e);
    }
  }

  Future<void> _delete() async {
    final streamer = widget.card["streamer"];
    final name = streamer is Map ? (streamer["display_name"] as String? ?? "este streamer") : "este streamer";
    final ok = await confirmAction(
      context,
      title: "Remover do fluxo",
      message: "Remover " + name + " deste programa? O card sera apagado do fluxo.",
      confirmLabel: "Remover",
      confirmColor: Colors.redAccent,
    );
    if (!ok) return;
    setState(() => _saving = true);
    try {
      await deleteProgramCard(progressId: widget.card["id"] as String);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) showProgramasActionError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final streamer = widget.card["streamer"];
    final name = streamer is Map ? (streamer["display_name"] as String? ?? "-") : "-";
    final tiktokId = streamer is Map ? streamer["tiktok_creator_id"] as String? : null;
    final avatarUrl = streamer is Map ? streamer["avatar_url"] as String? : null;
    final isEvaluation = widget.stage["is_evaluation_stage"] == true;
    final stageChangedAt = widget.card["stage_changed_at"] != null ? DateTime.parse(widget.card["stage_changed_at"] as String) : null;

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
              Row(children: [
                CircleAvatar(radius: 20, backgroundColor: Colors.white24, backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null, child: avatarUrl == null ? const Icon(Icons.person, color: Colors.white54) : null),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      if (tiktokId != null) Text("ID: " + tiktokId, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Text("Etapa atual: " + (widget.stage["name"] as String), style: const TextStyle(color: Colors.white70, fontSize: 13)),
              if (stageChangedAt != null)
                Text("Desde " + stageChangedAt.toLocal().toString().substring(0, 10), style: const TextStyle(color: Colors.white38, fontSize: 12)),
              const SizedBox(height: 16),
              if (isEvaluation) ...[
                const Text("Avaliacao final", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  ElevatedButton.icon(onPressed: _saving ? null : () => _evaluate("aprovado"), icon: const Icon(Icons.check, size: 16), label: const Text("Aprovar"), style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black)),
                  ElevatedButton.icon(onPressed: _saving ? null : () => _evaluate("graduado"), icon: const Icon(Icons.star, size: 16), label: const Text("Graduar"), style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black)),
                  ElevatedButton.icon(onPressed: _saving ? null : () => _evaluate("revisao"), icon: const Icon(Icons.hourglass_bottom, size: 16), label: const Text("Revisao"), style: ElevatedButton.styleFrom(backgroundColor: Colors.white24, foregroundColor: Colors.white)),
                  ElevatedButton.icon(onPressed: _saving ? null : () => _evaluate("desligado"), icon: const Icon(Icons.close, size: 16), label: const Text("Encerrar parceria"), style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white)),
                ]),
                const SizedBox(height: 12),
              ],
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                TextButton(onPressed: _saving ? null : _delete, child: const Text("Remover do fluxo", style: TextStyle(color: Colors.redAccent))),
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Fechar")),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

const _outcomeQuestionLabels = {
  "aprovado": "Aprovar",
  "graduado": "Graduar",
  "revisao": "colocar em Revisao",
  "desligado": "Encerrar a parceria com",
};

const _reprovalReasonKeys = ["baixa_frequencia", "poucas_horas", "sem_treinamento", "desistencia", "outro"];
const _reprovalReasonLabels = {
  "baixa_frequencia": "Baixa frequencia",
  "poucas_horas": "Poucas horas",
  "sem_treinamento": "Nao realizou treinamento",
  "desistencia": "Desistencia",
  "outro": "Outro",
};

/// Dialog que serve tanto de confirmacao quanto de coleta de dados da
/// avaliacao final: motivo (so quando for reprovacao/desligamento, lista
/// fixa + "Outro" com texto livre) e observacoes (sempre, opcional). Retorna
/// null se cancelado, ou (motivo?, observacao?) se confirmado.
class _EvaluationDialog extends StatefulWidget {
  final String outcome;
  final String streamerName;
  const _EvaluationDialog({required this.outcome, required this.streamerName});

  @override
  State<_EvaluationDialog> createState() => _EvaluationDialogState();
}

class _EvaluationDialogState extends State<_EvaluationDialog> {
  final _noteController = TextEditingController();
  final _otherReasonController = TextEditingController();
  String _reason = _reprovalReasonKeys.first;

  @override
  Widget build(BuildContext context) {
    final isReproval = widget.outcome == "desligado";
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      title: Text(
        (_outcomeQuestionLabels[widget.outcome] ?? widget.outcome) + " " + widget.streamerName + "?",
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isReproval) ...[
              const Text("Motivo", style: TextStyle(color: Colors.white54, fontSize: 12)),
              DropdownButton<String>(
                value: _reason,
                isExpanded: true,
                dropdownColor: const Color(0xFF232323),
                style: const TextStyle(color: Colors.white),
                items: _reprovalReasonKeys.map((k) => DropdownMenuItem(value: k, child: Text(_reprovalReasonLabels[k]!))).toList(),
                onChanged: (v) => setState(() => _reason = v ?? _reason),
              ),
              if (_reason == "outro") ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _otherReasonController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: "Detalhe o motivo", labelStyle: TextStyle(color: Colors.white54)),
                ),
              ],
              const SizedBox(height: 12),
            ],
            const Text("Observacoes (opcional)", style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 4),
            TextField(
              controller: _noteController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(hintText: "Registrar algo sobre esta avaliacao", hintStyle: TextStyle(color: Colors.white38)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancelar")),
        ElevatedButton(
          onPressed: () {
            String? reasonValue;
            if (isReproval) {
              reasonValue = _reason == "outro" ? (_otherReasonController.text.trim().isEmpty ? "outro" : _otherReasonController.text.trim()) : _reason;
            }
            Navigator.of(context).pop((reasonValue, _noteController.text.trim()));
          },
          style: ElevatedButton.styleFrom(backgroundColor: widget.outcome == "desligado" ? Colors.redAccent : const Color(0xFF7A0BD4), foregroundColor: Colors.white),
          child: const Text("Confirmar"),
        ),
      ],
    );
  }
}
