import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";

class BugReportButton extends StatelessWidget {
  const BugReportButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: "Reportar um problema",
      icon: const Icon(Icons.bug_report_outlined, color: Colors.white70),
      onPressed: () {
        showDialog(context: context, builder: (context) => const _BugReportDialog());
      },
    );
  }
}

class _BugReportDialog extends StatefulWidget {
  const _BugReportDialog();

  @override
  State<_BugReportDialog> createState() => _BugReportDialogState();
}

class _BugReportDialogState extends State<_BugReportDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _areaController = TextEditingController();
  String _severity = "media";
  bool _saving = false;
  String? _errorMessage;
  bool _sent = false;

  Future<void> _submit() async {
    if (_titleController.text.trim().isEmpty || _descriptionController.text.trim().isEmpty) {
      setState(() => _errorMessage = "Preencha titulo e descricao.");
      return;
    }
    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser!.id;

      await client.from("bug_reports").insert({
        "reported_by": userId,
        "area": _areaController.text.trim(),
        "title": _titleController.text.trim(),
        "description": _descriptionController.text.trim(),
        "severity": _severity,
      });

      final admins = await client.from("managers").select("id").or("role.eq.admin,role.eq.coordenador");
      for (final a in (admins as List)) {
        try {
          await client.from("manager_notifications").insert({
            "manager_id": a["id"],
            "subject": "Novo reporte de bug",
            "message": _titleController.text.trim(),
            "priority": _severity,
          });
        } catch (_) {}
      }

      setState(() {
        _saving = false;
        _sent = true;
      });
    } catch (e) {
      setState(() {
        _saving = false;
        _errorMessage = "Erro ao enviar: " + e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _sent
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Icon(Icons.check_circle, color: Colors.greenAccent),
                      SizedBox(width: 8),
                      Text("Reporte enviado!", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 8),
                    const Text("A equipe responsavel foi notificada.", style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 16),
                    Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Fechar"))),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Reportar um Problema", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text("Descreva o que aconteceu, isso vai direto para o Dono/Admin.", style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic)),
                    const SizedBox(height: 16),
                    TextField(controller: _titleController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Titulo do problema", labelStyle: TextStyle(color: Colors.white54))),
                    const SizedBox(height: 8),
                    TextField(controller: _areaController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Onde aconteceu (pagina/tela)", labelStyle: TextStyle(color: Colors.white54))),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _descriptionController,
                      maxLines: 4,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: "O que aconteceu?", labelStyle: TextStyle(color: Colors.white54), border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 8),
                    DropdownButton<String>(
                      value: _severity,
                      dropdownColor: const Color(0xFF1A1A1A),
                      style: const TextStyle(color: Colors.white),
                      items: const [
                        DropdownMenuItem(value: "baixa", child: Text("Baixa")),
                        DropdownMenuItem(value: "media", child: Text("Media")),
                        DropdownMenuItem(value: "alta", child: Text("Alta")),
                        DropdownMenuItem(value: "urgente", child: Text("Urgente")),
                      ],
                      onChanged: (v) => setState(() => _severity = v!),
                    ),
                    if (_errorMessage != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 12))),
                    const SizedBox(height: 16),
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancelar")),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _saving ? null : _submit,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                        child: Text(_saving ? "Enviando..." : "Enviar reporte"),
                      ),
                    ]),
                  ],
                ),
        ),
      ),
    );
  }
}
