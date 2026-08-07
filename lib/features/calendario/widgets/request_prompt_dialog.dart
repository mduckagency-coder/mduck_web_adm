import "package:flutter/material.dart";
import "../models/calendar_request.dart";
import "../services/calendar_service.dart";
import "streamer_picker_dialog.dart";

/// Dialogo para a agencia pedir que um streamer preencha uma solicitacao de
/// batalha oficial ou evento. Retorna true quando o pedido foi enviado.
class RequestPromptDialog extends StatefulWidget {
  const RequestPromptDialog({super.key});

  @override
  State<RequestPromptDialog> createState() => _RequestPromptDialogState();
}

class _RequestPromptDialogState extends State<RequestPromptDialog> {
  final _service = CalendarService();
  final _messageController = TextEditingController();

  Map<String, dynamic>? _streamer;
  CalendarRequestType _requestType = CalendarRequestType.batalhaOficial;
  DateTime? _suggestedStart;
  DateTime? _suggestedEnd;
  bool _sending = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pickStreamer() async {
    final selected = await showDialog<List<Map<String, dynamic>>>(context: context, builder: (_) => const StreamerPickerDialog());
    if (selected != null && selected.isNotEmpty) setState(() => _streamer = selected.first);
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _suggestedStart : _suggestedEnd) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _suggestedStart = picked;
      } else {
        _suggestedEnd = picked;
      }
    });
  }

  Future<void> _send() async {
    if (_streamer == null || _messageController.text.trim().isEmpty) return;
    setState(() => _sending = true);
    await _service.sendRequestPrompt(
      streamerId: _streamer!["id"] as String,
      requestType: _requestType,
      message: _messageController.text.trim(),
      suggestedDateStart: _suggestedStart,
      suggestedDateEnd: _suggestedEnd,
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  String _dateLabel(DateTime? date) {
    if (date == null) return "Selecionar";
    return date.day.toString().padLeft(2, "0") + "/" + date.month.toString().padLeft(2, "0") + "/" + date.year.toString();
  }

  @override
  Widget build(BuildContext context) {
    final canSend = _streamer != null && _messageController.text.trim().isNotEmpty;
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Pedir solicitação ao streamer", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text(
                "Envia um alerta no aplicativo pedindo para o streamer preencher uma solicitação de batalha oficial ou evento.",
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Streamer", style: TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 6),
                      OutlinedButton.icon(
                        onPressed: _pickStreamer,
                        icon: const Icon(Icons.person_search, size: 16, color: Colors.white70),
                        label: Text(_streamer != null ? (_streamer!["display_name"] as String? ?? "Streamer selecionado") : "Selecionar streamer", style: const TextStyle(color: Colors.white70)),
                      ),
                      const SizedBox(height: 16),
                      const Text("Tipo de solicitação", style: TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 6),
                      SegmentedButton<CalendarRequestType>(
                        segments: const [
                          ButtonSegment(value: CalendarRequestType.batalhaOficial, label: Text("Batalha Oficial"), icon: Icon(Icons.sports_kabaddi, size: 16)),
                          ButtonSegment(value: CalendarRequestType.evento, label: Text("Evento"), icon: Icon(Icons.event, size: 16)),
                        ],
                        selected: {_requestType},
                        onSelectionChanged: (s) => setState(() => _requestType = s.first),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _messageController,
                        maxLines: 3,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: "Mensagem",
                          labelStyle: TextStyle(color: Colors.white54),
                          hintText: "Ex: você está perto de alcançar sua meta, agende uma batalha oficial este mês. Prefira estes dias e horários...",
                          hintStyle: TextStyle(color: Colors.white38),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 16),
                      const Text("Período sugerido (opcional)", style: TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 6),
                      Row(children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickDate(isStart: true),
                            icon: const Icon(Icons.calendar_today, size: 16, color: Colors.white70),
                            label: Text(_dateLabel(_suggestedStart), style: const TextStyle(color: Colors.white70)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text("até", style: TextStyle(color: Colors.white54, fontSize: 12)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickDate(isStart: false),
                            icon: const Icon(Icons.calendar_today, size: 16, color: Colors.white70),
                            label: Text(_dateLabel(_suggestedEnd), style: const TextStyle(color: Colors.white70)),
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancelar")),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _sending || !canSend ? null : _send,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
                  child: Text(_sending ? "Enviando..." : "Enviar pedido"),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
