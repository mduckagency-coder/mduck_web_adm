import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";

const _templates = {
  "Sentimos sua falta!": "Sentimos sua falta por aqui! Que tal fazer uma live hoje?",
  "Streak em risco": "Seu progresso deste mes esta em risco, volte a fazer lives para nao perder seu status!",
  "Chamado do gestor": "Precisamos falar com voce sobre sua atividade recente. Entre em contato com seu gestor.",
  "Personalizada": "",
};

class NotifyDialog extends StatefulWidget {
  final List<String> streamerIds;
  final String targetLabel;

  const NotifyDialog({super.key, required this.streamerIds, required this.targetLabel});

  @override
  State<NotifyDialog> createState() => _NotifyDialogState();
}

class _NotifyDialogState extends State<NotifyDialog> {
  final _messageController = TextEditingController();
  String _selectedTemplate = "Personalizada";
  bool _sending = false;
  String? _error;

  void _applyTemplate(String key) {
    setState(() {
      _selectedTemplate = key;
      _messageController.text = _templates[key] ?? "";
    });
  }

  Future<void> _send() async {
    if (_messageController.text.trim().isEmpty) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final client = Supabase.instance.client;
      String? agencyId;
      final managerId = client.auth.currentUser!.id;
      final manager = await client.from("managers").select("agency_id").eq("id", managerId).single();
      agencyId = manager["agency_id"] as String;

      final notification = await client
          .from("notifications")
          .insert({
            "agency_id": agencyId,
            "sent_by": managerId,
            "message": _messageController.text.trim(),
          })
          .select()
          .single();

      final notificationId = notification["id"];
      final recipients = widget.streamerIds
          .map((id) => {"notification_id": notificationId, "streamer_id": id})
          .toList();
      await client.from("notification_recipients").insert(recipients);

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Enviar notificacao", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text("Destino: " + widget.targetLabel, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _templates.keys.map((key) {
                  final selected = _selectedTemplate == key;
                  return ChoiceChip(
                    label: Text(key, style: TextStyle(fontSize: 12, color: selected ? Colors.white : Colors.white70)),
                    selected: selected,
                    selectedColor: const Color(0xFF7A0BD4),
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
              if (_error != null) Text("Erro: " + _error!, style: const TextStyle(color: Colors.redAccent)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancelar")),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send, size: 16),
                    label: Text(_sending ? "Enviando..." : "Enviar (" + widget.streamerIds.length.toString() + ")"),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
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
