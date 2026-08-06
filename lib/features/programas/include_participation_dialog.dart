import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "program_participation_service.dart";

class MonthGoalRow {
  final daysController = TextEditingController();
  final hoursController = TextEditingController();
  final diamondsController = TextEditingController();
  final battlesController = TextEditingController();
}

const _initialStatusOptions = [
  (null, "Em andamento (padrao)"),
  ("concluido", "Ja concluiu a meta"),
  ("entregue", "Ja recebeu a premiacao"),
];

/// Dialogo compartilhado entre a aba Participantes (inclusao em massa, a
/// partir da tabela de candidatos filtrada por faixa) e a aba Fluxo (botao
/// "+", adicionar 1 streamer direto no quadro). Define a missao (metas por
/// mes, "+" adiciona mes), observacao, premio, quando a missao comeca (este
/// mes ou um mes futuro -- pra quando o gestor ja quer programar alguem pro
/// mes que vem e nao quer esquecer) e, opcionalmente, se o card ja deve
/// nascer numa situacao adiantada (streamer que ja alcancou o resultado
/// antes mesmo de existir o card, ver createParticipation).
class IncludeParticipationDialog extends StatefulWidget {
  final String programId;
  final List<String> streamerIds;
  const IncludeParticipationDialog({super.key, required this.programId, required this.streamerIds});

  @override
  State<IncludeParticipationDialog> createState() => _IncludeParticipationDialogState();
}

class _IncludeParticipationDialogState extends State<IncludeParticipationDialog> {
  final List<MonthGoalRow> _months = [MonthGoalRow()];
  final _prizeController = TextEditingController();
  final _notesController = TextEditingController();
  final _awardValueController = TextEditingController();
  int _startMonthOffset = 0;
  String? _initialStage;
  bool _saving = false;
  String? _error;

  String _startMonthLabel() {
    if (_startMonthOffset == 0) return "Este mes";
    if (_startMonthOffset == 1) return "Mes que vem";
    return "Daqui a " + _startMonthOffset.toString() + " meses";
  }

  Future<void> _save() async {
    if (_initialStage == "entregue" && double.tryParse(_awardValueController.text.trim().replaceAll(",", ".")) == null) {
      setState(() => _error = "Informe o valor da premiacao pra registrar como ja entregue.");
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final months = _months
          .map(
            (m) => GoalTargetInput(
              targetDays: int.tryParse(m.daysController.text.trim()),
              targetHours: double.tryParse(m.hoursController.text.trim().replaceAll(",", ".")),
              targetDiamonds: num.tryParse(m.diamondsController.text.trim()),
              targetBattles: int.tryParse(m.battlesController.text.trim()),
            ),
          )
          .toList();
      final userId = Supabase.instance.client.auth.currentUser!.id;
      await createParticipationsBulk(
        programId: widget.programId,
        streamerIds: widget.streamerIds,
        prizeDescription: _prizeController.text.trim().isEmpty ? null : _prizeController.text.trim(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        months: months,
        createdBy: userId,
        startMonthOffset: _startMonthOffset,
        initialStage: _initialStage,
        initialAwardValue: _initialStage == "entregue"
            ? double.tryParse(_awardValueController.text.trim().replaceAll(",", "."))
            : null,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = "Erro: " + e.toString();
      });
    }
  }

  Widget _monthField(TextEditingController controller, String label) {
    return Expanded(
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54, fontSize: 11),
          isDense: true,
        ),
      ),
    );
  }

  Widget _monthRow(int index) {
    final m = _months[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                "Mes " + (index + 1).toString(),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (_months.length > 1)
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 18),
                  onPressed: () => setState(() => _months.removeAt(index)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _monthField(m.daysController, "Dias"),
              const SizedBox(width: 6),
              _monthField(m.hoursController, "Horas"),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _monthField(m.diamondsController, "Diamantes"),
              const SizedBox(width: 6),
              _monthField(m.battlesController, "Batalhas"),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.streamerIds.length;
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 700),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Incluir participacao (" + count.toString() + (count == 1 ? " streamer)" : " streamers)"),
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                "A mesma missao e aplicada a todos os selecionados.",
                style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Comeca em",
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _startMonthLabel(),
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_left, size: 18, color: Colors.white54),
                            onPressed: _startMonthOffset <= 0
                                ? null
                                : () => setState(() => _startMonthOffset--),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right, size: 18, color: Colors.white54),
                            onPressed: () => setState(() => _startMonthOffset++),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Metas por mes",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      ...List.generate(_months.length, _monthRow),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => setState(() => _months.add(MonthGoalRow())),
                          icon: const Icon(Icons.add, size: 16, color: Color(0xFF7A0BD4)),
                          label: const Text(
                            "Adicionar mes",
                            style: TextStyle(color: Color(0xFF7A0BD4)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _prizeController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: "Concorre a / presente",
                          labelStyle: TextStyle(color: Colors.white54),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _notesController,
                        maxLines: 3,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: "Observacao",
                          labelStyle: TextStyle(color: Colors.white54),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "Situacao inicial do card",
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      DropdownButton<String?>(
                        value: _initialStage,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF232323),
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        items: _initialStatusOptions
                            .map((o) => DropdownMenuItem(value: o.$1, child: Text(o.$2)))
                            .toList(),
                        onChanged: (v) => setState(() => _initialStage = v),
                      ),
                      if (_initialStage == "entregue") ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: _awardValueController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: "Valor da premiacao (R\$)",
                            labelStyle: TextStyle(color: Colors.white54),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            "Vai gerar uma saida em Financeiro RH > Entradas e Saidas.",
                            style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic),
                          ),
                        ),
                      ],
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text("Cancelar"),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7A0BD4),
                      foregroundColor: Colors.white,
                    ),
                    child: Text(_saving ? "Salvando..." : "Salvar"),
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
