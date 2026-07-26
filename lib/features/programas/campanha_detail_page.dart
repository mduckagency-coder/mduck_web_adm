import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "campaign_cycle_service.dart";
import "program_eligibility_service.dart";
import "programa_history_helpers.dart";

Color _statusColor(ParticipantStatus s) {
  switch (s) {
    case ParticipantStatus.concluido:
      return Colors.greenAccent;
    case ParticipantStatus.proximo:
      return Colors.amber;
    case ParticipantStatus.atrasado:
      return Colors.orangeAccent;
    case ParticipantStatus.desistiu:
      return Colors.white38;
    case ParticipantStatus.inativo:
      return Colors.redAccent;
  }
}

class CampanhaDetailPage extends StatefulWidget {
  final Map<String, dynamic> program;
  final String cycleId;
  const CampanhaDetailPage({super.key, required this.program, required this.cycleId});

  @override
  State<CampanhaDetailPage> createState() => _CampanhaDetailPageState();
}

class _CampanhaDetailPageState extends State<CampanhaDetailPage> {
  bool _loading = true;
  bool _busy = false;
  String? _errorMessage;
  Map<String, dynamic>? _cycle;
  List<Map<String, dynamic>> _checklist = [];
  List<Map<String, dynamic>> _participants = [];
  ProgramCriteria _criteria = const ProgramCriteria();
  int _pendingAwardsCount = 0;
  DateTime? _lastLoadedAt;

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
      final cycle = await client.from("campaign_cycles").select().eq("id", widget.cycleId).single();
      final checklist = await client.from("campaign_cycle_checklist").select().eq("cycle_id", widget.cycleId).order("order_index");
      final participants = await fetchCycleParticipants(cycleId: widget.cycleId);
      final pendingAwards = await client.from("program_awards").select("id").eq("cycle_id", widget.cycleId).eq("status", "pendente");

      final base = ProgramCriteria.fromMap(widget.program["criteria"] as Map<String, dynamic>?);
      final mission = ProgramCriteria.fromMap(cycle["mission_criteria"] as Map<String, dynamic>?);

      setState(() {
        _cycle = cycle;
        _checklist = (checklist as List).cast<Map<String, dynamic>>();
        _participants = participants;
        _criteria = mergeCriteria(base, mission);
        _pendingAwardsCount = (pendingAwards as List).length;
        _lastLoadedAt = DateTime.now();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _copy(String text, String message) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggleChecklist(Map<String, dynamic> item) async {
    final client = Supabase.instance.client;
    final done = !(item["done"] as bool? ?? false);
    try {
      await client.from("campaign_cycle_checklist").update({"done": done, "done_at": done ? DateTime.now().toIso8601String() : null}).eq("id", item["id"]);
      _load();
    } catch (e) {
      if (mounted) showProgramasActionError(context, e);
    }
  }

  Future<void> _syncNow() async {
    setState(() => _busy = true);
    try {
      final added = await syncCycleParticipants(program: widget.program, cycleId: widget.cycleId);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(added == 0 ? "Nenhum novo streamer elegivel." : added.toString() + " novo(s) participante(s) adicionado(s).")));
      await _load();
    } catch (e) {
      if (mounted) showProgramasActionError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openMissionEditor() {
    showDialog(context: context, builder: (context) => _MissionEditDialog(cycle: _cycle!)).then((saved) {
      if (saved == true) _load();
    });
  }

  Future<void> _confirmConclude() async {
    final evaluations = {for (final p in _participants) p["streamer_id"] as String: evaluateParticipant(p, _criteria)};
    final concludedIds = evaluations.entries.where((e) => e.value.status == ParticipantStatus.concluido).map((e) => e.key).toSet();

    final selected = await showDialog<Set<String>>(
      context: context,
      builder: (context) => _ConcludeDialog(participants: _participants, initiallySelected: concludedIds),
    );
    if (selected == null) return;

    setState(() => _busy = true);
    try {
      final report = await concludeCycle(program: widget.program, cycleId: widget.cycleId, promoteStreamerIds: selected);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ciclo finalizado. " + report["promotions_count"].toString() + " promocao(oes).")));
      }
      await _load();
    } catch (e) {
      if (mounted) showProgramasActionError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(_cycle != null ? (_cycle!["name"] as String?) ?? _cycle!["period_label"] as String : "Campanha"),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).pop()),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? buildProgramasLoadError(_errorMessage!)
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final cycle = _cycle!;
    final isOpen = cycle["status"] == "em_andamento";
    final evaluations = {for (final p in _participants) p["streamer_id"] as String: evaluateParticipant(p, _criteria)};
    final oportunidades = _participants.where((p) => evaluations[p["streamer_id"]]?.status == ParticipantStatus.proximo).toList();
    final risco = _participants.where((p) => const {ParticipantStatus.inativo, ParticipantStatus.desistiu, ParticipantStatus.atrasado}.contains(evaluations[p["streamer_id"]]?.status)).toList();
    final report = cycle["report"] as Map<String, dynamic>?;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(border: Border.all(color: isOpen ? Colors.amber : Colors.greenAccent), borderRadius: BorderRadius.circular(8)),
              child: Text(isOpen ? "Em andamento" : "Finalizado", style: TextStyle(color: isOpen ? Colors.amber : Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
            const Spacer(),
            if (isOpen) ...[
              OutlinedButton.icon(onPressed: _busy ? null : _syncNow, icon: const Icon(Icons.sync, size: 14), label: const Text("Verificar elegiveis")),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _busy ? null : _confirmConclude,
                icon: const Icon(Icons.flag, size: 16),
                label: const Text("Finalizar ciclo"),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
              ),
            ],
          ]),
          const SizedBox(height: 4),
          Row(children: [
            if (cycle["name"] != null) Text(cycle["period_label"] as String, style: const TextStyle(color: Colors.white38, fontSize: 11)),
            if (cycle["name"] != null) const SizedBox(width: 10),
            if (_lastLoadedAt != null) Text(relativeTimeLabel(_lastLoadedAt!), style: const TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic)),
          ]),
          if ((cycle["notes"] as String?)?.isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Text(cycle["notes"] as String, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
          const SizedBox(height: 16),

          const Text("Indicadores do ciclo", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          Wrap(spacing: 12, runSpacing: 12, children: [
            _reportCard("Participantes", _participants.length, const Color(0xFF7A0BD4)),
            _reportCard("Elegiveis", evaluations.values.where((e) => e.status == ParticipantStatus.concluido).length, Colors.greenAccent),
            _reportCard("Em andamento", evaluations.values.where((e) => e.status != ParticipantStatus.concluido).length, Colors.blueAccent),
            _reportCard("Premiacoes pendentes", _pendingAwardsCount, Colors.pinkAccent),
            _reportCard(
              "Taxa de conclusao",
              _participants.isEmpty ? "0%" : ((evaluations.values.where((e) => e.status == ParticipantStatus.concluido).length / _participants.length) * 100).toStringAsFixed(0) + "%",
              Colors.amber,
            ),
          ]),
          const SizedBox(height: 20),

          if (report != null) ...[
            const Text("Relatorio final", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            Wrap(spacing: 12, runSpacing: 12, children: [
              _reportCard("Participantes", report["participant_count"], const Color(0xFF7A0BD4)),
              _reportCard("Concluiram", report["concluded_count"], Colors.greenAccent),
              _reportCard("Nao concluiram", report["not_concluded_count"], Colors.redAccent),
              _reportCard("Premiacoes", report["awards_count"], Colors.pinkAccent),
              _reportCard("Promocoes", report["promotions_count"], Colors.amber),
            ]),
            const SizedBox(height: 20),
          ],

          Row(children: [
            Expanded(child: Text("Missao: " + ((cycle["mission_title"] as String?) ?? "-"), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15))),
            if (isOpen) IconButton(icon: const Icon(Icons.edit, size: 18, color: Colors.white54), onPressed: _openMissionEditor),
          ]),
          if ((cycle["mission_description"] as String?)?.isNotEmpty == true) Text(cycle["mission_description"] as String, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(spacing: 12, runSpacing: 4, children: [
            if (_criteria.minDays != null) Text("Dias: " + _criteria.minDays.toString(), style: const TextStyle(color: Colors.white54, fontSize: 12)),
            if (_criteria.minHours != null) Text("Horas: " + _criteria.minHours.toString(), style: const TextStyle(color: Colors.white54, fontSize: 12)),
            if (_criteria.minDiamonds != null) Text("Diamantes: " + _criteria.minDiamonds.toString(), style: const TextStyle(color: Colors.white54, fontSize: 12)),
            if (_criteria.minHeartMe != null) Text("Heart Me: " + _criteria.minHeartMe.toString(), style: const TextStyle(color: Colors.white54, fontSize: 12)),
            if (_criteria.minBattles != null) Text("Batalhas: " + _criteria.minBattles.toString(), style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ]),
          const SizedBox(height: 20),

          if ((cycle["default_message"] as String?)?.isNotEmpty == true) ...[
            const Text("Mensagem padrao", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(cycle["default_message"] as String, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(onPressed: () => _copy(cycle["default_message"] as String, "Mensagem copiada."), icon: const Icon(Icons.copy, size: 14), label: const Text("Copiar mensagem")),
                ),
              ]),
            ),
            const SizedBox(height: 20),
          ],

          const Text("Checklist da campanha", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 6),
          ..._checklist.map((item) => CheckboxListTile(
                value: item["done"] as bool? ?? false,
                onChanged: (_) => _toggleChecklist(item),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
                activeColor: const Color(0xFF7A0BD4),
                title: Text(item["label"] as String, style: TextStyle(color: Colors.white, decoration: (item["done"] as bool? ?? false) ? TextDecoration.lineThrough : null, fontSize: 13)),
              )),
          const SizedBox(height: 20),

          if (oportunidades.isNotEmpty) ...[
            const Text("Oportunidades", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 14)),
            const Text("Perto de bater a meta -- vale uma cutucada.", style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic)),
            const SizedBox(height: 6),
            ...oportunidades.map((p) {
              final streamer = p["streamer"];
              final name = streamer is Map ? streamer["display_name"] as String? ?? "-" : "-";
              final gap = evaluations[p["streamer_id"]]?.gaps.firstOrNull ?? "-";
              return Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [
                const Icon(Icons.trending_up, size: 14, color: Colors.greenAccent),
                const SizedBox(width: 6),
                Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(width: 8),
                Text(gap, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ]));
            }),
            const SizedBox(height: 20),
          ],

          if (risco.isNotEmpty) ...[
            const Text("Em risco", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14)),
            const Text("Precisam de atencao antes de perder a meta do mes.", style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic)),
            const SizedBox(height: 6),
            ...risco.map((p) {
              final streamer = p["streamer"];
              final name = streamer is Map ? streamer["display_name"] as String? ?? "-" : "-";
              final evaluation = evaluations[p["streamer_id"]]!;
              final reason = evaluation.gaps.firstOrNull ?? participantStatusLabel(evaluation.status);
              return Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [
                const Icon(Icons.warning_amber, size: 14, color: Colors.redAccent),
                const SizedBox(width: 6),
                Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(width: 8),
                Text(reason, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ]));
            }),
            const SizedBox(height: 20),
          ],

          Row(children: [
            const Text("Participantes da Campanha", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            const Spacer(),
            TextButton.icon(
              onPressed: _participants.isEmpty
                  ? null
                  : () {
                      final names = _participants.map((p) {
                        final s = p["streamer"];
                        return s is Map ? (s["display_name"] as String? ?? "-") : "-";
                      }).join("\n");
                      _copy(names, "Lista copiada (" + _participants.length.toString() + " nomes).");
                    },
              icon: const Icon(Icons.copy, size: 14),
              label: const Text("Copiar Lista"),
            ),
          ]),
          const SizedBox(height: 6),
          if (_participants.isEmpty)
            const Text("Nenhum participante encontrado ainda.", style: TextStyle(color: Colors.white54))
          else
            ..._participants.map((p) {
              final streamer = p["streamer"];
              final name = streamer is Map ? streamer["display_name"] as String? ?? "-" : "-";
              final avatarUrl = streamer is Map ? streamer["avatar_url"] as String? : null;
              final catData = streamer is Map ? streamer["streamer_categories"] : null;
              final categoryName = catData is Map ? catData["name"] as String? : null;
              final statsData = streamer is Map ? streamer["streamer_stats"] : null;
              Map<String, dynamic>? stats;
              if (statsData is List && statsData.isNotEmpty) stats = statsData.first as Map<String, dynamic>;
              else if (statsData is Map) stats = statsData as Map<String, dynamic>;
              final evaluation = evaluations[p["streamer_id"]]!;
              final color = _statusColor(evaluation.status);

              return Card(
                color: Colors.white.withOpacity(0.05),
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  leading: CircleAvatar(radius: 16, backgroundColor: Colors.white24, backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null, child: avatarUrl == null ? const Icon(Icons.person, size: 16, color: Colors.white54) : null),
                  title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text(
                    (categoryName ?? "Sem categoria") +
                        "  -  Dias: " + ((stats?["days_live"])?.toString() ?? "-") +
                        "  -  Horas: " + ((stats?["hours_live"])?.toString() ?? "-") +
                        "  -  Diamantes: " + ((stats?["diamonds"])?.toString() ?? "-"),
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(border: Border.all(color: color), borderRadius: BorderRadius.circular(8)),
                    child: Text(participantStatusLabel(evaluation.status), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _reportCard(String label, dynamic value, Color color) {
    return Container(
      width: 120,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: color)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
        const SizedBox(height: 3),
        Text((value ?? 0).toString(), style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class _MissionEditDialog extends StatefulWidget {
  final Map<String, dynamic> cycle;
  const _MissionEditDialog({required this.cycle});

  @override
  State<_MissionEditDialog> createState() => _MissionEditDialogState();
}

class _MissionEditDialogState extends State<_MissionEditDialog> {
  late final _nameController = TextEditingController(text: widget.cycle["name"] as String? ?? "");
  late final _notesController = TextEditingController(text: widget.cycle["notes"] as String? ?? "");
  late final _titleController = TextEditingController(text: widget.cycle["mission_title"] as String? ?? "");
  late final _descriptionController = TextEditingController(text: widget.cycle["mission_description"] as String? ?? "");
  late final _messageController = TextEditingController(text: widget.cycle["default_message"] as String? ?? "");
  late final _minDaysController = TextEditingController(text: (widget.cycle["mission_criteria"]?["min_days"])?.toString() ?? "");
  late final _minHoursController = TextEditingController(text: (widget.cycle["mission_criteria"]?["min_hours"])?.toString() ?? "");
  late final _minDiamondsController = TextEditingController(text: (widget.cycle["mission_criteria"]?["min_diamonds"])?.toString() ?? "");
  late final _minHeartMeController = TextEditingController(text: (widget.cycle["mission_criteria"]?["min_heart_me"])?.toString() ?? "");
  late final _minBattlesController = TextEditingController(text: (widget.cycle["mission_criteria"]?["min_battles"])?.toString() ?? "");
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final client = Supabase.instance.client;
      final existingCriteria = widget.cycle["mission_criteria"] as Map<String, dynamic>? ?? {};
      final criteria = {
        ...existingCriteria,
        "min_days": int.tryParse(_minDaysController.text.trim()),
        "min_hours": double.tryParse(_minHoursController.text.trim().replaceAll(",", ".")),
        "min_diamonds": num.tryParse(_minDiamondsController.text.trim()),
        "min_heart_me": num.tryParse(_minHeartMeController.text.trim().replaceAll(",", ".")),
        "min_battles": int.tryParse(_minBattlesController.text.trim()),
      };
      await client.from("campaign_cycles").update({
        "name": _nameController.text.trim().isEmpty ? null : _nameController.text.trim(),
        "notes": _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        "mission_title": _titleController.text.trim(),
        "mission_description": _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        "default_message": _messageController.text.trim().isEmpty ? null : _messageController.text.trim(),
        "mission_criteria": criteria,
      }).eq("id", widget.cycle["id"]);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) showProgramasActionError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Editar ciclo", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(controller: _nameController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Nome do ciclo (opcional)", labelStyle: TextStyle(color: Colors.white54))),
                const SizedBox(height: 8),
                TextField(controller: _notesController, maxLines: 2, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Observacoes", labelStyle: TextStyle(color: Colors.white54))),
                const SizedBox(height: 16),
                const Text("Missao do mes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                TextField(controller: _titleController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Titulo", labelStyle: TextStyle(color: Colors.white54))),
                const SizedBox(height: 8),
                TextField(controller: _descriptionController, maxLines: 2, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Descricao", labelStyle: TextStyle(color: Colors.white54))),
                const SizedBox(height: 12),
                const Text("Objetivos (vazio = usa o criterio base do programa)", style: TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 4),
                Row(children: [
                  Expanded(child: TextField(controller: _minDaysController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Dias", labelStyle: TextStyle(color: Colors.white54)))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: _minHoursController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Horas", labelStyle: TextStyle(color: Colors.white54)))),
                ]),
                Row(children: [
                  Expanded(child: TextField(controller: _minDiamondsController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Diamantes", labelStyle: TextStyle(color: Colors.white54)))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: _minHeartMeController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Heart Me", labelStyle: TextStyle(color: Colors.white54)))),
                ]),
                TextField(controller: _minBattlesController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Batalhas minimas", labelStyle: TextStyle(color: Colors.white54))),
                const SizedBox(height: 8),
                TextField(controller: _messageController, maxLines: 3, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Mensagem padrao", labelStyle: TextStyle(color: Colors.white54))),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancelar")),
                  const SizedBox(width: 8),
                  ElevatedButton(onPressed: _saving ? null : _save, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white), child: Text(_saving ? "Salvando..." : "Salvar")),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConcludeDialog extends StatefulWidget {
  final List<Map<String, dynamic>> participants;
  final Set<String> initiallySelected;
  const _ConcludeDialog({required this.participants, required this.initiallySelected});

  @override
  State<_ConcludeDialog> createState() => _ConcludeDialogState();
}

class _ConcludeDialogState extends State<_ConcludeDialog> {
  late Set<String> _selected = Set.of(widget.initiallySelected);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Finalizar ciclo", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const Text("Marcados serao promovidos automaticamente para o proximo programa. Desmarque quem nao deve ser promovido.", style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic)),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: widget.participants.length,
                  itemBuilder: (context, index) {
                    final p = widget.participants[index];
                    final streamerId = p["streamer_id"] as String;
                    final streamer = p["streamer"];
                    final name = streamer is Map ? streamer["display_name"] as String? ?? "-" : "-";
                    return CheckboxListTile(
                      value: _selected.contains(streamerId),
                      onChanged: (v) => setState(() => v == true ? _selected.add(streamerId) : _selected.remove(streamerId)),
                      dense: true,
                      activeColor: const Color(0xFF7A0BD4),
                      title: Text(name, style: const TextStyle(color: Colors.white, fontSize: 13)),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => Navigator.of(context).pop(null), child: const Text("Cancelar")),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(_selected),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
                  child: const Text("Confirmar e finalizar"),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
