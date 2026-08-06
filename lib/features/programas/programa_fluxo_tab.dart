import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "../calendario/widgets/streamer_picker_dialog.dart";
import "include_participation_dialog.dart";
import "program_participation_service.dart";
import "programa_history_helpers.dart";

const _stageColors = {
  "proximos_a_entrar": Colors.white54,
  "em_andamento": Colors.blueAccent,
  "nao_conseguiu": Colors.redAccent,
  "concluido": Colors.greenAccent,
  "pendente_entrega": Colors.amber,
  "entregue": Colors.pinkAccent,
};

/// Quadro Kanban sobre program_participations (ver program_participation_
/// service.dart) -- nao usa mais streamer_phase_progress/criterios
/// automaticos, esse motor antigo continua no banco mas nao decide mais
/// entrada/saida de ninguem aqui. Proximos a entrar/Em andamento/Nao
/// conseguiu/Concluido sao colunas calculadas sozinhas a partir do outcome
/// dos meses da missao (definida na aba Participantes ou aqui mesmo, botao
/// "Adicionar card"), mas o gestor pode arrastar qualquer card pra qualquer
/// coluna na mao quando precisar corrigir.
class ProgramaFluxoTab extends StatefulWidget {
  final Map<String, dynamic> program;
  const ProgramaFluxoTab({super.key, required this.program});

  @override
  State<ProgramaFluxoTab> createState() => _ProgramaFluxoTabState();
}

class _ProgramaFluxoTabState extends State<ProgramaFluxoTab> {
  bool _loading = true;
  String? _errorMessage;
  List<ProgramParticipation> _participations = [];
  final _horizontalController = ScrollController();

  String get _programId => widget.program["id"] as String;

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
      final participations = await fetchParticipations(programId: _programId);
      setState(() {
        _participations = participations;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _moveCard(ProgramParticipation p, String? newStage) async {
    final currentStage = newStage == null ? null : participationStage(p);
    if (newStage != null && currentStage == newStage) return;
    num? awardValue;
    if (newStage == "entregue") {
      awardValue = await promptPrizeValue(context, streamerName: p.streamerName);
      if (awardValue == null) return;
    }
    try {
      await setParticipationStage(
        participation: p,
        newStage: newStage,
        performedBy: Supabase.instance.client.auth.currentUser!.id,
        awardValue: awardValue,
      );
      _load();
    } catch (e) {
      if (mounted) showProgramasActionError(context, e);
    }
  }

  Future<void> _removeParticipation(ProgramParticipation p) async {
    final ok = await confirmAction(
      context,
      title: "Remover do programa",
      message: "Remover " + (p.streamerName ?? "este streamer") + " deste programa?",
      confirmLabel: "Remover",
      confirmColor: Colors.redAccent,
    );
    if (!ok) return;
    try {
      await removeParticipation(
        participationId: p.id,
        removedBy: Supabase.instance.client.auth.currentUser!.id,
      );
      if (mounted) Navigator.of(context).pop();
      _load();
    } catch (e) {
      if (mounted) showProgramasActionError(context, e);
    }
  }

  Future<void> _addCard() async {
    final selected = await showDialog<List<Map<String, dynamic>>>(
      context: context,
      builder: (context) => const StreamerPickerDialog(),
    );
    if (selected == null || selected.isEmpty) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => IncludeParticipationDialog(
        programId: _programId,
        streamerIds: selected.map((s) => s["id"] as String).toList(),
      ),
    );
    if (saved == true) _load();
  }

  void _openCard(ProgramParticipation p) {
    showDialog(
      context: context,
      builder: (context) => _ParticipationCardDialog(
        participation: p,
        onMove: (newStage) => _moveCard(p, newStage),
        onRemove: () => _removeParticipation(p),
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
                "Fluxo",
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 12),
              IconButton(icon: const Icon(Icons.refresh, color: Colors.white70), onPressed: _load),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _addCard,
                icon: const Icon(Icons.add, size: 16),
                label: const Text("Adicionar card"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7A0BD4),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            "Proximos a entrar/Em andamento/Nao conseguiu/Concluido sao automaticos, conforme os meses da missao vao sendo confirmados na aba Participantes. Arraste o card pra qualquer coluna se precisar corrigir na mao.",
            style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? buildProgramasLoadError(_errorMessage!)
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
          children: participationStageOrder.map((stageKey) {
            final stageColor = _stageColors[stageKey] ?? const Color(0xFF7A0BD4);
            final columnCards = _participations
                .where((p) => participationStage(p) == stageKey)
                .toList();

            return Container(
              width: 230,
              height: 560,
              margin: const EdgeInsets.only(right: 12),
              child: DragTarget<ProgramParticipation>(
                onWillAcceptWithDetails: (details) => participationStage(details.data) != stageKey,
                onAcceptWithDetails: (details) => _moveCard(details.data, stageKey),
                builder: (context, candidateData, rejectedData) {
                  final highlighting = candidateData.isNotEmpty;
                  return Container(
                    decoration: BoxDecoration(
                      color: highlighting
                          ? stageColor.withOpacity(0.15)
                          : Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: highlighting ? stageColor : Colors.white12),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [stageColor.withOpacity(0.35), stageColor.withOpacity(0.12)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                            border: Border(bottom: BorderSide(color: stageColor, width: 2)),
                          ),
                          child: Column(
                            children: [
                              Text(
                                participationStageLabels[stageKey] ?? stageKey,
                                style: TextStyle(
                                  color: stageColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: stageColor.withOpacity(0.25),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  columnCards.length.toString(),
                                  style: TextStyle(
                                    color: stageColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: columnCards.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Text(
                                    "Ninguem aqui.",
                                    style: TextStyle(color: Colors.white38, fontSize: 11),
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.all(8),
                                  itemCount: columnCards.length,
                                  itemBuilder: (context, index) {
                                    final p = columnCards[index];
                                    final tile = InkWell(
                                      onTap: () => _openCard(p),
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1A1A1A),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: p.stageOverride != null
                                                ? stageColor.withOpacity(0.6)
                                                : Colors.white12,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 14,
                                              backgroundColor: Colors.white24,
                                              backgroundImage: p.streamerAvatarUrl != null
                                                  ? NetworkImage(p.streamerAvatarUrl!)
                                                  : null,
                                              child: p.streamerAvatarUrl == null
                                                  ? const Icon(Icons.person, size: 14, color: Colors.white54)
                                                  : null,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                p.streamerName ?? "-",
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (p.stageOverride != null)
                                              const Icon(Icons.push_pin, size: 12, color: Colors.white38),
                                          ],
                                        ),
                                      ),
                                    );
                                    return Draggable<ProgramParticipation>(
                                      data: p,
                                      feedback: Material(
                                        color: Colors.transparent,
                                        child: SizedBox(width: 210, child: tile),
                                      ),
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

class _ParticipationCardDialog extends StatelessWidget {
  final ProgramParticipation participation;
  final ValueChanged<String?> onMove;
  final VoidCallback onRemove;
  const _ParticipationCardDialog({
    required this.participation,
    required this.onMove,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final p = participation;
    final stage = participationStage(p);
    final stageIndex = participationStageOrder.indexOf(stage);

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
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.white24,
                    backgroundImage:
                        p.streamerAvatarUrl != null ? NetworkImage(p.streamerAvatarUrl!) : null,
                    child: p.streamerAvatarUrl == null
                        ? const Icon(Icons.person, color: Colors.white54)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.streamerName ?? "-",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (p.categoryName != null)
                          Text(
                            p.categoryName!,
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (_stageColors[stage] ?? Colors.white).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _stageColors[stage] ?? Colors.white),
                    ),
                    child: Text(
                      participationStageLabels[stage] ?? stage,
                      style: TextStyle(
                        color: _stageColors[stage] ?? Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (p.stageOverride != null)
                    TextButton.icon(
                      onPressed: () {
                        onMove(null);
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.sync, size: 14),
                      label: const Text("Voltar ao automatico", style: TextStyle(fontSize: 11)),
                    ),
                ],
              ),
              if (p.prizeDescription != null && p.prizeDescription!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.card_giftcard, size: 14, color: Colors.pinkAccent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        p.prizeDescription!,
                        style: const TextStyle(color: Colors.pinkAccent, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
              if (p.notes != null && p.notes!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  p.notes!,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              const Text(
                "Metas",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              ...p.goals.map((g) {
                final parts = <String>[];
                if (g.targetDays != null) parts.add(g.targetDays.toString() + " dias");
                if (g.targetHours != null) parts.add(g.targetHours!.toStringAsFixed(1) + "h");
                if (g.targetDiamonds != null)
                  parts.add(g.targetDiamonds!.toStringAsFixed(0) + " diamantes");
                if (g.targetBattles != null) parts.add(g.targetBattles.toString() + " batalhas");
                final outcomeColor = g.outcome == "cumpriu"
                    ? Colors.greenAccent
                    : g.outcome == "nao_cumprido"
                    ? Colors.redAccent
                    : Colors.white38;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Icon(Icons.circle, size: 8, color: outcomeColor),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "Mes " +
                              g.monthIndex.toString() +
                              " (" +
                              g.periodKey +
                              "): " +
                              (parts.isEmpty ? "sem meta" : parts.join(", ")),
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 14),
              const Text(
                "Mover card",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (stageIndex > 0)
                    TextButton.icon(
                      onPressed: () {
                        onMove(participationStageOrder[stageIndex - 1]);
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.chevron_left, size: 16),
                      label: Text(
                        "Voltar para " +
                            (participationStageLabels[participationStageOrder[stageIndex - 1]] ?? ""),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  if (stageIndex < participationStageOrder.length - 1)
                    ElevatedButton.icon(
                      onPressed: () {
                        onMove(participationStageOrder[stageIndex + 1]);
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.chevron_right, size: 16),
                      label: Text(
                        "Avancar para " +
                            (participationStageLabels[participationStageOrder[stageIndex + 1]] ?? ""),
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7A0BD4),
                        foregroundColor: Colors.white,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: onRemove,
                    child: const Text("Remover do programa", style: TextStyle(color: Colors.redAccent)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text("Fechar"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
