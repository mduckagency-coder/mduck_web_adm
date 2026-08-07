import "package:flutter/material.dart";
import "../calendar_colors.dart";
import "../models/calendar_event.dart";
import "../models/calendar_request.dart";
import "../models/event_category.dart";
import "../services/calendar_service.dart";

/// Retorna true quando a solicitacao foi alterada (aprovada, rejeitada,
/// avancou de etapa ou foi excluida), para a tela chamadora recarregar a
/// lista.
class RequestReviewDialog extends StatefulWidget {
  final CalendarRequest request;

  const RequestReviewDialog({super.key, required this.request});

  @override
  State<RequestReviewDialog> createState() => _RequestReviewDialogState();
}

enum _Mode { viewing, approving, rejecting, battleApprove, battleConfirmOpponent, battlePrepMessage, battleComplete }

class _RequestReviewDialogState extends State<RequestReviewDialog> {
  final _service = CalendarService();
  final _reasonController = TextEditingController();
  final _approvalMessageController = TextEditingController();
  final _opponentNameController = TextEditingController();
  final _prepMessageController = TextEditingController();
  final _scoreController = TextEditingController();

  _Mode _mode = _Mode.viewing;
  bool _saving = false;

  List<EventCategory> _categories = [];
  String? _categoryId;
  DateTime _eventDate = DateTime.now();
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _loadingCategories = true;

  List<CalendarRequestHistoryEntry> _history = [];
  bool _loadingHistory = true;

  bool get _isBattle => widget.request.requestType == CalendarRequestType.batalhaOficial;

  @override
  void initState() {
    super.initState();
    _eventDate = widget.request.proposedDate ?? DateTime.now();
    _startTime = widget.request.proposedStartTime;
    _endTime = widget.request.proposedEndTime;
    _loadHistory();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _approvalMessageController.dispose();
    _opponentNameController.dispose();
    _prepMessageController.dispose();
    _scoreController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final rows = await _service.fetchRequestHistory(widget.request.id);
    if (mounted) {
      setState(() {
        _history = rows;
        _loadingHistory = false;
      });
    }
  }

  Future<void> _loadCategoriesForApproval() async {
    setState(() => _loadingCategories = true);
    await _service.seedDefaultCategories();
    final categories = await _service.fetchCategories(onlyActive: true);
    if (!mounted) return;
    // Solicitacao aprovada vira um evento so pra aquele streamer -- "Evento
    // Individual" e a categoria que mais se encaixa, tanto pra batalha
    // quanto pra evento generico.
    final preferred = categories.where((c) => c.key == "evento_individual").toList();
    setState(() {
      _categories = categories;
      _categoryId = preferred.isNotEmpty ? preferred.first.id : (categories.isNotEmpty ? categories.first.id : null);
      _loadingCategories = false;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: _eventDate, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (picked != null) setState(() => _eventDate = picked);
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(context: context, initialTime: (isStart ? _startTime : _endTime) ?? TimeOfDay.now());
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _confirmApproveEvento() async {
    if (_categoryId == null) return;
    setState(() => _saving = true);
    await _service.approveRequest(
      request: widget.request,
      categoryId: _categoryId!,
      eventDate: _eventDate,
      startTime: timeOfDayToSql(_startTime),
      endTime: timeOfDayToSql(_endTime),
      approvalMessage: _approvalMessageController.text.trim().isEmpty ? null : _approvalMessageController.text.trim(),
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _confirmReject() async {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) return;
    setState(() => _saving = true);
    await _service.rejectRequest(request: widget.request, reason: reason);
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _confirmStartBattleSearch() async {
    setState(() => _saving = true);
    await _service.startBattleOpponentSearch(
      request: widget.request,
      approvalMessage: _approvalMessageController.text.trim().isEmpty ? null : _approvalMessageController.text.trim(),
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _confirmOpponent() async {
    if (_categoryId == null || _opponentNameController.text.trim().isEmpty) return;
    setState(() => _saving = true);
    await _service.confirmBattleOpponent(
      request: widget.request,
      opponentName: _opponentNameController.text.trim(),
      categoryId: _categoryId!,
      eventDate: _eventDate,
      startTime: timeOfDayToSql(_startTime),
      endTime: timeOfDayToSql(_endTime),
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _confirmPrepMessage() async {
    final message = _prepMessageController.text.trim();
    if (message.isEmpty) return;
    setState(() => _saving = true);
    await _service.sendBattlePrepMessage(request: widget.request, message: message);
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _confirmCompleteBattle() async {
    setState(() => _saving = true);
    await _service.completeBattle(request: widget.request, score: _scoreController.text.trim().isEmpty ? null : _scoreController.text.trim());
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text("Excluir solicitação", style: TextStyle(color: Colors.white)),
        content: const Text("Essa ação não pode ser desfeita.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancelar")),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text("Excluir", style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirmed != true) return;
    await _service.deleteRequest(widget.request.id);
    if (mounted) Navigator.of(context).pop(true);
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12))),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 13))),
        ],
      ),
    );
  }

  List<Widget> _requestDetails() {
    final r = widget.request;
    final dateLabel = r.proposedDate != null
        ? r.proposedDate!.day.toString().padLeft(2, "0") + "/" + r.proposedDate!.month.toString().padLeft(2, "0") + "/" + r.proposedDate!.year.toString()
        : "Não informado";
    final timeLabel = r.proposedStartTime != null
        ? r.proposedStartTime!.format(context) + (r.proposedEndTime != null ? " às " + r.proposedEndTime!.format(context) : "")
        : "Não informado";

    final rows = <Widget>[
      _detailRow("Streamer", r.streamerName ?? "-"),
      _detailRow("Tipo", calendarRequestTypeLabel(r.requestType)),
      _detailRow("Data pretendida", dateLabel),
      _detailRow("Horário", timeLabel),
    ];

    if (_isBattle) {
      rows.add(_detailRow("Rounds", r.battleRounds?.toString() ?? "-"));
      rows.add(_detailRow("Diamantes aprox.", r.battleDiamondsEstimate?.toString() ?? "-"));
      rows.add(_detailRow("Oponente pedido", r.battleOpponentType != null ? battleOpponentTypeLabel(r.battleOpponentType!) : "-"));
      if (r.battleOpponentName != null) rows.add(_detailRow("Oponente confirmado", r.battleOpponentName!));
      if (r.battleScore != null) rows.add(_detailRow("Pontuação", r.battleScore!));
    } else {
      rows.add(_detailRow("Descrição", (r.description ?? "").isEmpty ? "-" : r.description!));
    }
    rows.add(_detailRow("Banner de divulgação", r.needsBanner ? "Sim" : "Não"));

    if (r.status != CalendarRequestStatus.aguardandoAnalise) {
      if (r.reviewNotes != null && r.reviewNotes!.isNotEmpty) rows.add(_detailRow("Motivo da recusa", r.reviewNotes!));
      if (r.approvalMessage != null && r.approvalMessage!.isNotEmpty) rows.add(_detailRow("Mensagem da agência", r.approvalMessage!));
      if (r.reviewedByManagerName != null) rows.add(_detailRow("Revisado por", r.reviewedByManagerName!));
    }
    return rows;
  }

  Widget _historySection() {
    if (_loadingHistory) return const SizedBox.shrink();
    if (_history.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: Colors.white24, height: 24),
        const Text("Histórico", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ..._history.map((h) {
          final dateLabel = h.changedAt.day.toString().padLeft(2, "0") +
              "/" +
              h.changedAt.month.toString().padLeft(2, "0") +
              " " +
              h.changedAt.hour.toString().padLeft(2, "0") +
              ":" +
              h.changedAt.minute.toString().padLeft(2, "0");
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 8, height: 8, margin: const EdgeInsets.only(top: 4, right: 8), decoration: BoxDecoration(shape: BoxShape.circle, color: calendarRequestStatusColor(h.status))),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(calendarRequestStatusLabel(h.status) + (h.changedByManagerName != null ? " · " + h.changedByManagerName! : "") + " · " + dateLabel,
                          style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                      if (h.note != null && h.note!.isNotEmpty) Text(h.note!, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _categoryDateTimeForm() {
    final dateLabel = _eventDate.day.toString().padLeft(2, "0") + "/" + _eventDate.month.toString().padLeft(2, "0") + "/" + _eventDate.year.toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        _loadingCategories
            ? const LinearProgressIndicator()
            : DropdownButtonFormField<String>(
                initialValue: _categoryId,
                dropdownColor: const Color(0xFF232323),
                decoration: const InputDecoration(labelText: "Categoria", labelStyle: TextStyle(color: Colors.white54)),
                style: const TextStyle(color: Colors.white),
                items: _categories
                    .map((c) => DropdownMenuItem(
                          value: c.id,
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            CircleAvatar(radius: 6, backgroundColor: hexToColor(c.color)),
                            const SizedBox(width: 8),
                            Text(c.name),
                          ]),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _categoryId = v),
              ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today, size: 16, color: Colors.white70),
              label: Text(dateLabel, style: const TextStyle(color: Colors.white70)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _pickTime(true),
              icon: const Icon(Icons.access_time, size: 16, color: Colors.white70),
              label: Text(_startTime != null ? _startTime!.format(context) : "Início", style: const TextStyle(color: Colors.white70)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _pickTime(false),
              icon: const Icon(Icons.access_time, size: 16, color: Colors.white70),
              label: Text(_endTime != null ? _endTime!.format(context) : "Fim", style: const TextStyle(color: Colors.white70)),
            ),
          ),
        ]),
      ],
    );
  }

  Widget _modeForm() {
    switch (_mode) {
      case _Mode.viewing:
        return const SizedBox.shrink();
      case _Mode.rejecting:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(color: Colors.white24, height: 24),
            const Text("Motivo da recusa", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _reasonController,
              maxLines: 3,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(hintText: "Explique por que a solicitação foi recusada", hintStyle: TextStyle(color: Colors.white38)),
            ),
          ],
        );
      case _Mode.approving:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(color: Colors.white24, height: 24),
            const Text("Confirmar dados do evento", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            _categoryDateTimeForm(),
            const SizedBox(height: 12),
            TextField(
              controller: _approvalMessageController,
              maxLines: 2,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "Mensagem para o streamer (opcional)", labelStyle: TextStyle(color: Colors.white54)),
            ),
          ],
        );
      case _Mode.battleApprove:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(color: Colors.white24, height: 24),
            const Text("Aprovar e iniciar busca de oponente", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _approvalMessageController,
              maxLines: 2,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "Mensagem para o streamer (opcional)", labelStyle: TextStyle(color: Colors.white54)),
            ),
          ],
        );
      case _Mode.battleConfirmOpponent:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(color: Colors.white24, height: 24),
            const Text("Confirmar oponente e agendar", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _opponentNameController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "Nome do oponente", labelStyle: TextStyle(color: Colors.white54)),
              onChanged: (_) => setState(() {}),
            ),
            _categoryDateTimeForm(),
          ],
        );
      case _Mode.battlePrepMessage:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(color: Colors.white24, height: 24),
            const Text("Mensagem de preparo", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _prepMessageController,
              maxLines: 3,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(hintText: "Ex: prepare seu setup, a batalha é amanhã às 20h...", hintStyle: TextStyle(color: Colors.white38)),
              onChanged: (_) => setState(() {}),
            ),
          ],
        );
      case _Mode.battleComplete:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(color: Colors.white24, height: 24),
            const Text("Marcar como concluída", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _scoreController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "Pontuação/resultado (opcional)", labelStyle: TextStyle(color: Colors.white54)),
            ),
          ],
        );
    }
  }

  List<Widget> _actionButtons() {
    final status = widget.request.status;
    if (_mode == _Mode.rejecting) {
      return [
        ElevatedButton(
          onPressed: _saving ? null : _confirmReject,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
          child: Text(_saving ? "Enviando..." : "Confirmar recusa"),
        ),
      ];
    }
    if (_mode == _Mode.approving) {
      return [
        ElevatedButton(
          onPressed: _saving || _categoryId == null ? null : _confirmApproveEvento,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF27AE60), foregroundColor: Colors.white),
          child: Text(_saving ? "Aprovando..." : "Confirmar aprovação"),
        ),
      ];
    }
    if (_mode == _Mode.battleApprove) {
      return [
        ElevatedButton(
          onPressed: _saving ? null : _confirmStartBattleSearch,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF27AE60), foregroundColor: Colors.white),
          child: Text(_saving ? "Enviando..." : "Confirmar aprovação"),
        ),
      ];
    }
    if (_mode == _Mode.battleConfirmOpponent) {
      final canConfirm = _categoryId != null && _opponentNameController.text.trim().isNotEmpty;
      return [
        ElevatedButton(
          onPressed: _saving || !canConfirm ? null : _confirmOpponent,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A085), foregroundColor: Colors.white),
          child: Text(_saving ? "Salvando..." : "Confirmar e agendar"),
        ),
      ];
    }
    if (_mode == _Mode.battlePrepMessage) {
      return [
        ElevatedButton(
          onPressed: _saving || _prepMessageController.text.trim().isEmpty ? null : _confirmPrepMessage,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
          child: Text(_saving ? "Enviando..." : "Enviar mensagem"),
        ),
      ];
    }
    if (_mode == _Mode.battleComplete) {
      return [
        ElevatedButton(
          onPressed: _saving ? null : _confirmCompleteBattle,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
          child: Text(_saving ? "Salvando..." : "Marcar como concluída"),
        ),
      ];
    }

    // _Mode.viewing: botoes dependem do status e do tipo da solicitacao.
    final buttons = <Widget>[];
    if (status == CalendarRequestStatus.aguardandoAnalise) {
      buttons.add(OutlinedButton(
        onPressed: () => setState(() => _mode = _Mode.rejecting),
        style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: const BorderSide(color: Colors.redAccent)),
        child: const Text("Reprovar"),
      ));
      buttons.add(const SizedBox(width: 8));
      if (_isBattle) {
        buttons.add(ElevatedButton(
          onPressed: () => setState(() => _mode = _Mode.battleApprove),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF27AE60), foregroundColor: Colors.white),
          child: const Text("Aprovar e buscar oponente"),
        ));
      } else {
        buttons.add(ElevatedButton(
          onPressed: () {
            setState(() => _mode = _Mode.approving);
            _loadCategoriesForApproval();
          },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF27AE60), foregroundColor: Colors.white),
          child: const Text("Aprovar"),
        ));
      }
    } else if (_isBattle && status == CalendarRequestStatus.buscandoOponente) {
      buttons.add(OutlinedButton(
        onPressed: () => setState(() => _mode = _Mode.battlePrepMessage),
        child: const Text("Mensagem de preparo"),
      ));
      buttons.add(const SizedBox(width: 8));
      buttons.add(ElevatedButton(
        onPressed: () {
          setState(() => _mode = _Mode.battleConfirmOpponent);
          _loadCategoriesForApproval();
        },
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A085), foregroundColor: Colors.white),
        child: const Text("Confirmar oponente"),
      ));
    } else if (_isBattle && status == CalendarRequestStatus.oponenteConfirmado) {
      buttons.add(OutlinedButton(
        onPressed: () => setState(() => _mode = _Mode.battlePrepMessage),
        child: const Text("Mensagem de preparo"),
      ));
      buttons.add(const SizedBox(width: 8));
      buttons.add(ElevatedButton(
        onPressed: () => setState(() => _mode = _Mode.battleComplete),
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
        child: const Text("Marcar como concluída"),
      ));
    }
    return buttons;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(widget.request.displayTitle, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: calendarRequestStatusColor(widget.request.status).withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                  child: Text(calendarRequestStatusLabel(widget.request.status), style: TextStyle(color: calendarRequestStatusColor(widget.request.status), fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ]),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ..._requestDetails(),
                      _modeForm(),
                      _historySection(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(
                  onPressed: _saving ? null : _confirmDelete,
                  child: const Text("Excluir", style: TextStyle(color: Colors.redAccent)),
                ),
                const Spacer(),
                if (_mode != _Mode.viewing) TextButton(onPressed: _saving ? null : () => setState(() => _mode = _Mode.viewing), child: const Text("Voltar")),
                if (_mode == _Mode.viewing) TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Fechar")),
                const SizedBox(width: 8),
                ..._actionButtons(),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
