import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "package:url_launcher/url_launcher.dart";

class WhatsAppTarget {
  final String id;
  final String displayName;
  final String? phone;

  WhatsAppTarget({required this.id, required this.displayName, required this.phone});
}

const _waTemplates = {
  "Parabens pela evolucao": "Parabens pela sua evolucao este mes! Continue assim.",
  "Convite para evento": "Temos um evento chegando na agencia, participe!",
  "Aviso de meta": "Voce esta perto de bater sua meta do mes, vamos com tudo!",
  "Personalizada": "",
};

class WhatsAppDialog extends StatefulWidget {
  final List<WhatsAppTarget> targets;
  final String targetLabel;

  /// Preenche a mensagem ja pronta (ex: metricas do mes) em vez de comecar
  /// vazia -- quem chama decide o template, "Personalizada" continua
  /// disponivel pra editar a mensagem antes de enviar.
  final String? initialMessage;

  const WhatsAppDialog({
    super.key,
    required this.targets,
    required this.targetLabel,
    this.initialMessage,
  });

  @override
  State<WhatsAppDialog> createState() => _WhatsAppDialogState();
}

class _WhatsAppDialogState extends State<WhatsAppDialog> {
  final _messageController = TextEditingController();
  String _selectedTemplate = "Personalizada";
  bool _sending = false;
  List<WhatsAppTarget>? _withPhone;
  List<WhatsAppTarget>? _withoutPhone;

  @override
  void initState() {
    super.initState();
    if (widget.initialMessage != null) {
      _messageController.text = widget.initialMessage!;
    }
  }

  void _applyTemplate(String key) {
    setState(() {
      _selectedTemplate = key;
      _messageController.text = _waTemplates[key] ?? "";
    });
  }

  Future<void> _confirm() async {
    if (_messageController.text.trim().isEmpty) return;
    setState(() => _sending = true);
    final client = Supabase.instance.client;
    final managerId = client.auth.currentUser!.id;
    final withPhone = <WhatsAppTarget>[];
    final withoutPhone = <WhatsAppTarget>[];

    for (final t in widget.targets) {
      final hasPhone = t.phone != null && t.phone!.trim().isNotEmpty;
      if (hasPhone) {
        withPhone.add(t);
      } else {
        withoutPhone.add(t);
      }
      await client.from("whatsapp_dispatch_logs").insert({
        "streamer_id": t.id,
        "sent_by": managerId,
        "message": _messageController.text.trim(),
        "had_phone": hasPhone,
      });
    }

    setState(() {
      _sending = false;
      _withPhone = withPhone;
      _withoutPhone = withoutPhone;
    });
  }

  Future<void> _openWhatsApp(WhatsAppTarget t) async {
    final phone = t.phone!.replaceAll(RegExp(r"[^0-9]"), "");
    final url = Uri.parse("https://wa.me/" + phone + "?text=" + Uri.encodeComponent(_messageController.text.trim()));
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final done = _withPhone != null;
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Enviar WhatsApp", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text("Destino: " + widget.targetLabel, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 12),
              if (!done) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _waTemplates.keys.map((key) {
                    final selected = _selectedTemplate == key;
                    return ChoiceChip(
                      label: Text(key, style: TextStyle(fontSize: 12, color: selected ? Colors.white : Colors.white70)),
                      selected: selected,
                      selectedColor: const Color(0xFF25D366),
                      onSelected: (_) => _applyTemplate(key),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _messageController,
                  maxLines: 4,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: "Mensagem", labelStyle: TextStyle(color: Colors.white54), border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancelar")),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _sending ? null : _confirm,
                      icon: const Icon(Icons.chat, size: 16),
                      label: Text(_sending ? "Registrando..." : "Continuar (" + widget.targets.length.toString() + ")"),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white),
                    ),
                  ],
                ),
              ] else ...[
                Text(_withPhone!.length.toString() + " com telefone cadastrado / " + _withoutPhone!.length.toString() + " sem telefone",
                    style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 12),
                if (_withPhone!.isEmpty)
                  const Text(
                    "Nenhum streamer selecionado tem telefone cadastrado ainda. O envio ficou registrado no historico e podera ser feito assim que o telefone for preenchido no perfil.",
                    style: TextStyle(color: Colors.white54),
                  )
                else
                  Expanded(
                    child: ListView(
                      children: _withPhone!.map((t) {
                        return ListTile(
                          dense: true,
                          title: Text(t.displayName, style: const TextStyle(color: Colors.white)),
                          trailing: ElevatedButton(
                            onPressed: () => _openWhatsApp(t),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white),
                            child: const Text("Abrir WhatsApp"),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Fechar")),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
