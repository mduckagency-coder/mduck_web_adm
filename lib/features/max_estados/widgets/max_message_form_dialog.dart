import "package:flutter/material.dart";
import "../max_estados_service.dart";
import "../models/max_state.dart";
import "../models/max_state_message.dart";

/// Retorna true quando a mensagem foi salva, para a tela chamadora recarregar.
class MaxMessageFormDialog extends StatefulWidget {
  final MaxStateKey stateKey;
  final MaxStateMessage? existing;

  const MaxMessageFormDialog({super.key, required this.stateKey, this.existing});

  @override
  State<MaxMessageFormDialog> createState() => _MaxMessageFormDialogState();
}

class _MaxMessageFormDialogState extends State<MaxMessageFormDialog> {
  final _service = MaxEstadosService();
  final _messageController = TextEditingController();

  bool _isActive = true;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _messageController.text = e.message;
      _isActive = e.isActive;
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  bool get _canSave => _messageController.text.trim().isNotEmpty;

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    await _service.saveMessage(
      id: widget.existing?.id,
      stateKey: widget.stateKey,
      message: _messageController.text.trim(),
      isActive: _isActive,
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                (_isEditing ? "Editar mensagem" : "Nova mensagem") + " — " + maxStateKeyLabel(widget.stateKey),
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _messageController,
                maxLines: 3,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: "Mensagem", labelStyle: TextStyle(color: Colors.white54)),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              Row(children: [
                const Text("Ativa (visível no app)", style: TextStyle(color: Colors.white70, fontSize: 12)),
                const Spacer(),
                Switch(value: _isActive, onChanged: (v) => setState(() => _isActive = v), activeThumbColor: const Color(0xFF7A0BD4)),
              ]),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancelar")),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _saving || !_canSave ? null : _save,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
                  child: Text(_saving ? "Salvando..." : "Salvar"),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
