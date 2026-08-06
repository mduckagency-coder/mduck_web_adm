import "package:flutter/material.dart";
import "streamer_stage_service.dart";

const _revisarEmOptions = [3, 5, 7, 10, 15, 30];

/// "Registrar Ação" -- dialog rápido aberto direto do card (mesmo espírito
/// do botão "Enviar Material" do Onboard 15 Dias): o gestor escolhe o tipo
/// de ação, escreve o que precisa ser feito, e o streamer já vai pra coluna
/// daquele tipo no Kanban de Gestão de Streamers.
class StreamerActionDialog extends StatefulWidget {
  final String streamerId;
  final String agencyId;
  final String? assignedManagerId;
  final List<Map<String, dynamic>> agencyManagers;
  final VoidCallback? onSaved;

  const StreamerActionDialog({
    super.key,
    required this.streamerId,
    required this.agencyId,
    this.assignedManagerId,
    required this.agencyManagers,
    this.onSaved,
  });

  @override
  State<StreamerActionDialog> createState() => _StreamerActionDialogState();
}

class _StreamerActionDialogState extends State<StreamerActionDialog> {
  final _noteController = TextEditingController();
  String _stageKey = streamerStages.first.key;
  int _revisarEmDias = 5;
  String? _performedById;
  bool _saving = false;
  String? _errorMessage;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    String? performedByLabel;
    if (_performedById != null) {
      final match = widget.agencyManagers.firstWhere(
        (m) => m["id"] == _performedById,
        orElse: () => const {},
      );
      performedByLabel = match["login_email"] as String?;
    }
    try {
      await registerStreamerAction(
        streamerId: widget.streamerId,
        agencyId: widget.agencyId,
        stageKey: _stageKey,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        dueInDays: _revisarEmDias,
        performedByManagerId: _performedById,
        performedByLabel: performedByLabel,
      );
      // onSaved recarrega a tela por tras -- so fecha o dialog depois de
      // disparar, sem esperar (evita a tela ficar presa no dialog aberto
      // caso o reload demore).
      widget.onSaved?.call();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _errorMessage = "Erro ao salvar: " + e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
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
              const Text(
                "Registrar Ação",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Tipo de ação",
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                value: _stageKey,
                dropdownColor: const Color(0xFF1A1A1A),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(isDense: true),
                items: streamerStages
                    .map(
                      (s) => DropdownMenuItem(
                        value: s.key,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(s.icon, size: 15, color: Colors.white70),
                            const SizedBox(width: 8),
                            Text(s.label),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) =>
                    setState(() => _stageKey = v ?? streamerStages.first.key),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "O que precisa ser feito",
                  labelStyle: TextStyle(color: Colors.white54),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text(
                    "Revisar em",
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: _revisarEmDias,
                    dropdownColor: const Color(0xFF1A1A1A),
                    underline: const SizedBox.shrink(),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    items: _revisarEmOptions
                        .map(
                          (d) => DropdownMenuItem(
                            value: d,
                            child: Text(d.toString() + " dias"),
                          ),
                        )
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _revisarEmDias = v ?? 5),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text(
                    "Realizado por",
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String?>(
                    value: _performedById,
                    dropdownColor: const Color(0xFF1A1A1A),
                    underline: const SizedBox.shrink(),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    hint: const Text(
                      "Eu mesmo",
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    items: widget.agencyManagers
                        .map(
                          (m) => DropdownMenuItem<String?>(
                            value: m["id"] as String,
                            child: Text(m["login_email"] as String? ?? "-"),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _performedById = v),
                  ),
                ],
              ),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
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
