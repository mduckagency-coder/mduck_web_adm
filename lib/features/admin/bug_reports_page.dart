import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";

class BugReportsPage extends StatefulWidget {
  const BugReportsPage({super.key});

  @override
  State<BugReportsPage> createState() => _BugReportsPageState();
}

class _BugReportsPageState extends State<BugReportsPage> {
  late Future<List<Map<String, dynamic>>> _future;
  String _statusFilter = "aberto";

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final client = Supabase.instance.client;
    final rows = await client.from("bug_reports").select("*, managers!bug_reports_reported_by_fkey(login_email)").order("created_at", ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> _markResolved(String id) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;
    await client.from("bug_reports").update({
      "status": "resolvido",
      "resolved_at": DateTime.now().toIso8601String(),
      "resolved_by": userId,
    }).eq("id", id);
    setState(() => _future = _load());
  }

  Future<void> _reopen(String id) async {
    final client = Supabase.instance.client;
    await client.from("bug_reports").update({"status": "aberto", "resolved_at": null, "resolved_by": null}).eq("id", id);
    setState(() => _future = _load());
  }

  void _openReplyDialog(Map<String, dynamic> report) {
    showDialog(context: context, builder: (context) => _ReplyDialog(report: report)).then((sent) {
      if (sent == true) setState(() => _future = _load());
    });
  }

  Color _severityColor(String severity) {
    switch (severity) {
      case "urgente":
        return Colors.redAccent;
      case "alta":
        return Colors.orangeAccent;
      case "media":
        return Colors.amber;
      default:
        return Colors.white54;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.bug_report, color: Colors.redAccent),
            const SizedBox(width: 10),
            const Text("Reportes de Bugs", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(width: 12),
            IconButton(icon: const Icon(Icons.refresh, color: Colors.white70), onPressed: () => setState(() => _future = _load())),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            ChoiceChip(
              label: const Text("Em Aberto"),
              selected: _statusFilter == "aberto",
              selectedColor: Colors.redAccent,
              labelStyle: TextStyle(color: _statusFilter == "aberto" ? Colors.white : Colors.white70, fontWeight: FontWeight.bold),
              onSelected: (_) => setState(() => _statusFilter = "aberto"),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text("Resolvidos"),
              selected: _statusFilter == "resolvido",
              selectedColor: Colors.greenAccent,
              labelStyle: TextStyle(color: _statusFilter == "resolvido" ? Colors.black : Colors.white70, fontWeight: FontWeight.bold),
              onSelected: (_) => setState(() => _statusFilter = "resolvido"),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text("Todos"),
              selected: _statusFilter == "todos",
              selectedColor: Colors.white24,
              onSelected: (_) => setState(() => _statusFilter = "todos"),
            ),
          ]),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final list = _statusFilter == "todos" ? snapshot.data! : snapshot.data!.where((b) => b["status"] == _statusFilter).toList();
                if (list.isEmpty) return const Center(child: Text("Nenhum reporte encontrado.", style: TextStyle(color: Colors.white54)));
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final b = list[index];
                    final severity = b["severity"] as String;
                    final resolved = b["status"] == "resolvido";
                    final reporter = b["managers"];
                    final reporterEmail = reporter is Map ? reporter["login_email"] as String? ?? "-" : "-";
                    final date = DateTime.parse(b["created_at"] as String).toLocal().toString().substring(0, 16);
                    final hasReply = (b["admin_reply"] as String?)?.isNotEmpty == true;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _severityColor(severity).withOpacity(0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: _severityColor(severity).withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                              child: Text(severity.toUpperCase(), style: TextStyle(color: _severityColor(severity), fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(b["title"] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(border: Border.all(color: resolved ? Colors.greenAccent : Colors.redAccent), borderRadius: BorderRadius.circular(6)),
                              child: Text(resolved ? "RESOLVIDO" : "EM ABERTO", style: TextStyle(color: resolved ? Colors.greenAccent : Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ]),
                          if ((b["area"] as String?)?.isNotEmpty == true) ...[
                            const SizedBox(height: 4),
                            Text("Area: " + b["area"], style: const TextStyle(color: Colors.white38, fontSize: 11)),
                          ],
                          const SizedBox(height: 6),
                          Text(b["description"] as String, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                          const SizedBox(height: 8),
                          Text("Por: " + reporterEmail + "  -  " + date, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                          if (hasReply) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: const Color(0xFF7A0BD4).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Sua resposta:", style: TextStyle(color: Color(0xFF7A0BD4), fontSize: 11, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text(b["admin_reply"] as String, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Row(children: [
                            OutlinedButton.icon(
                              onPressed: () => _openReplyDialog(b),
                              icon: const Icon(Icons.reply, size: 14),
                              label: Text(hasReply ? "Editar resposta" : "Responder", style: const TextStyle(fontSize: 12)),
                            ),
                            const SizedBox(width: 8),
                            if (!resolved)
                              ElevatedButton(
                                onPressed: () => _markResolved(b["id"] as String),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent.withOpacity(0.2), foregroundColor: Colors.greenAccent, elevation: 0),
                                child: const Text("Marcar como resolvido", style: TextStyle(fontSize: 12)),
                              )
                            else
                              OutlinedButton(
                                onPressed: () => _reopen(b["id"] as String),
                                child: const Text("Reabrir", style: TextStyle(fontSize: 12)),
                              ),
                          ]),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ReplyDialog extends StatefulWidget {
  final Map<String, dynamic> report;
  const _ReplyDialog({required this.report});

  @override
  State<_ReplyDialog> createState() => _ReplyDialogState();
}

class _ReplyDialogState extends State<_ReplyDialog> {
  late final TextEditingController _controller;
  bool _saving = false;
  String? _errorMessage;
  bool _alsoMarkResolved = true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.report["admin_reply"] as String? ?? "");
  }

  Future<void> _send() async {
    if (_controller.text.trim().isEmpty) {
      setState(() => _errorMessage = "Escreva uma resposta.");
      return;
    }
    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser!.id;
      final reportId = widget.report["id"] as String;
      final reporterId = widget.report["reported_by"] as String?;

      final updateData = <String, dynamic>{
        "admin_reply": _controller.text.trim(),
        "replied_at": DateTime.now().toIso8601String(),
        "replied_by": userId,
      };
      if (_alsoMarkResolved) {
        updateData["status"] = "resolvido";
        updateData["resolved_at"] = DateTime.now().toIso8601String();
        updateData["resolved_by"] = userId;
      }
      await client.from("bug_reports").update(updateData).eq("id", reportId);

      if (reporterId != null) {
        await client.from("recruiter_feedbacks").insert({
          "recruiter_id": reporterId,
          "given_by": userId,
          "title": "Resposta sobre bug: " + (widget.report["title"] as String),
          "notes": _controller.text.trim(),
          "status": "pendente",
          "source": "bug_report",
          "bug_report_id": reportId,
        });

        try {
          await client.from("manager_notifications").insert({
            "manager_id": reporterId,
            "subject": "Resposta sobre o bug reportado",
            "message": widget.report["title"],
          });
        } catch (_) {}
      }

      if (mounted) Navigator.of(context).pop(true);
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Responder: " + (widget.report["title"] as String), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text("A pessoa vai receber uma notificacao e essa resposta vai aparecer nos Feedbacks dela.", style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic)),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                maxLines: 4,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: "Sua resposta", labelStyle: TextStyle(color: Colors.white54), border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: _alsoMarkResolved,
                onChanged: (v) => setState(() => _alsoMarkResolved = v ?? true),
                title: const Text("Marcar como resolvido junto", style: TextStyle(color: Colors.white, fontSize: 13)),
                activeColor: const Color(0xFF7A0BD4),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
              if (_errorMessage != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 12))),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancelar")),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _saving ? null : _send,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
                  child: Text(_saving ? "Enviando..." : "Enviar resposta"),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
