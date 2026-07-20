import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";

class RecruiterFeedbacksPage extends StatefulWidget {
  const RecruiterFeedbacksPage({super.key});

  @override
  State<RecruiterFeedbacksPage> createState() => _RecruiterFeedbacksPageState();
}

class _RecruiterFeedbacksPageState extends State<RecruiterFeedbacksPage> {
  late Future<List<Map<String, dynamic>>> _future;
  final Map<String, TextEditingController> _replyControllers = {};

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;
    final rows = await client
        .from("recruiter_feedbacks")
        .select("*, managers!recruiter_feedbacks_given_by_fkey(login_email)")
        .eq("recruiter_id", userId)
        .order("created_at", ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> _markDone(Map<String, dynamic> feedback) async {
    final id = feedback["id"] as String;
    try {
      final client = Supabase.instance.client;
      final result = await client.from("recruiter_feedbacks").update({"status": "concluido", "read_at": DateTime.now().toIso8601String()}).eq("id", id).select();
      if (result.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Nao foi possivel atualizar.")));
        return;
      }
      if (feedback["source"] == "bug_report" && feedback["bug_report_id"] != null) {
        final admins = await client.from("managers").select("id").or("role.eq.admin,role.eq.coordenador");
        for (final a in (admins as List)) {
          try {
            await client.from("manager_notifications").insert({
              "manager_id": a["id"],
              "subject": "Recrutador confirmou resposta do bug",
              "message": (feedback["title"] as String?) ?? "Bug",
            });
          } catch (_) {}
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Confirmado! O Dono foi avisado para fechar o chamado definitivamente.")));
        }
      }
      _future = _load();
      setState(() {});
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: " + e.toString())));
    }
  }

  Future<void> _sendReply(String id) async {
    final controller = _replyControllers[id];
    if (controller == null || controller.text.trim().isEmpty) return;
    try {
      final client = Supabase.instance.client;
      final result = await client.from("recruiter_feedbacks").update({
        "reply": controller.text.trim(),
        "replied_at": DateTime.now().toIso8601String(),
        "read_at": DateTime.now().toIso8601String(),
      }).eq("id", id).select();
      if (result.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Nao foi possivel enviar (0 linhas afetadas - possivel bloqueio de permissao).")));
        return;
      }
      _future = _load();
      setState(() {});
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: " + e.toString())));
    }
  }

  TextEditingController _controllerFor(String id) {
    return _replyControllers.putIfAbsent(id, () => TextEditingController());
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text("Meus Feedbacks", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(width: 12),
            IconButton(icon: const Icon(Icons.refresh, color: Colors.white70), onPressed: () => setState(() => _future = _load())),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () {
                showDialog(context: context, builder: (context) => const _NovoChamadoDialog()).then((saved) {
                  if (saved == true) _future = _load();
      setState(() {});
                });
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text("Abrir Chamado"),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
            ),
          ]),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final list = snapshot.data!;
                if (list.isEmpty) return const Center(child: Text("Nenhum feedback recebido ainda.", style: TextStyle(color: Colors.white54)));
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final f = list[index];
                    final givenBy = f["managers"];
                    final date = DateTime.parse(f["created_at"] as String).toLocal().toString().substring(0, 16);
                    final isDone = f["status"] == "concluido";
                    final hasReply = (f["reply"] as String?)?.isNotEmpty == true;
                    return Card(
                      color: Colors.white.withOpacity(0.05),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Expanded(child: Text((f["title"] as String?) ?? "Feedback", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15))),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: (isDone ? Colors.greenAccent : Colors.amber).withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                                child: Text(isDone ? "Concluido" : "Pendente", style: TextStyle(color: isDone ? Colors.greenAccent : Colors.amber, fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ]),
                            Text(date + " - " + (givenBy is Map ? givenBy["login_email"] as String? ?? "-" : "-"), style: const TextStyle(color: Colors.white38, fontSize: 11)),
                            const SizedBox(height: 8),
                            if ((f["positives"] as String?)?.isNotEmpty == true) Text("Pontos positivos: " + f["positives"], style: const TextStyle(color: Colors.greenAccent, fontSize: 13)),
                            if ((f["improvements"] as String?)?.isNotEmpty == true) Text("Pontos de melhoria: " + f["improvements"], style: const TextStyle(color: Colors.amber, fontSize: 13)),
                            if ((f["objectives"] as String?)?.isNotEmpty == true) Text("Objetivos: " + f["objectives"], style: const TextStyle(color: Colors.white, fontSize: 13)),
                            if ((f["action_plan"] as String?)?.isNotEmpty == true) Text("Plano de acao: " + f["action_plan"], style: const TextStyle(color: Colors.white70, fontSize: 13)),
                            if (hasReply) ...[
                              const SizedBox(height: 8),
                              Text("Sua resposta: " + (f["reply"] as String), style: const TextStyle(color: Colors.tealAccent, fontSize: 13)),
                            ],
                            if (!isDone) ...[
                              if (!hasReply) ...[
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _controllerFor(f["id"] as String),
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                  decoration: const InputDecoration(
                                    labelText: "Responder ao gestor (caso nao va marcar como concluido)",
                                    labelStyle: TextStyle(color: Colors.white54, fontSize: 12),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Row(children: [
                                ElevatedButton(
                                  onPressed: () => _markDone(f),
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
                                  child: const Text("Marcar como concluido"),
                                ),
                                if (!hasReply) ...[
                                  const SizedBox(width: 8),
                                  OutlinedButton(
                                    onPressed: () => _sendReply(f["id"] as String),
                                    child: const Text("Enviar resposta"),
                                  ),
                                ],
                              ]),
                            ],
                          ],
                        ),
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




class _NovoChamadoDialog extends StatefulWidget {
  const _NovoChamadoDialog();

  @override
  State<_NovoChamadoDialog> createState() => _NovoChamadoDialogState();
}

class _NovoChamadoDialogState extends State<_NovoChamadoDialog> {
  List<Map<String, dynamic>> _recipients = [];
  String? _selectedId;
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadRecipients();
  }

  Future<void> _loadRecipients() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;
    final rows = await client.from("managers").select("id, login_email, role, financial_role").neq("id", userId);
    final list = (rows as List).cast<Map<String, dynamic>>().where((m) {
      final role = m["role"] as String?;
      final financialRole = m["financial_role"] as String?;
      return role == "gestor" || role == "coordenador" || role == "admin" || financialRole == "dono";
    }).toList();
    setState(() => _recipients = list);
  }

  String? _errorMessage;

  Future<void> _submit() async {
    if (_selectedId == null || _titleController.text.trim().isEmpty || _messageController.text.trim().isEmpty) {
      setState(() => _errorMessage = "Preencha destinatario, assunto e mensagem.");
      return;
    }
    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser!.id;
      await client.from("recruiter_feedbacks").insert({
        "recruiter_id": userId,
        "given_by": userId,
        "addressed_to": _selectedId,
        "title": _titleController.text.trim(),
        "notes": _messageController.text.trim(),
        "raised_by_recruiter": true,
        "status": "pendente",
      });
      try {
        await client.from("manager_notifications").insert({
          "manager_id": _selectedId,
          "message": "Novo chamado de um recrutador: " + _titleController.text.trim(),
        });
      } catch (_) {
        // nao bloqueia o envio do chamado se so a notificacao falhar
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
              const Text("Abrir Chamado", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text("Envie uma pergunta, orientacao ou informacao para um gestor, dono ou admin.", style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic)),
              const SizedBox(height: 16),
              const Text("Para quem?", style: TextStyle(color: Colors.white54, fontSize: 12)),
              DropdownButton<String>(
                value: _selectedId,
                isExpanded: true,
                hint: const Text("Selecione um destinatario", style: TextStyle(color: Colors.white54)),
                dropdownColor: const Color(0xFF1A1A1A),
                style: const TextStyle(color: Colors.white),
                items: _recipients.map((m) {
                  final role = (m["financial_role"] == "dono") ? "Dono" : (m["role"] as String? ?? "-");
                  return DropdownMenuItem(value: m["id"] as String, child: Text((m["login_email"] as String) + " (" + role + ")"));
                }).toList(),
                onChanged: (v) => setState(() => _selectedId = v),
              ),
              const SizedBox(height: 12),
              TextField(controller: _titleController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Assunto", labelStyle: TextStyle(color: Colors.white54))),
              const SizedBox(height: 12),
              TextField(
                controller: _messageController,
                maxLines: 4,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: "Mensagem", labelStyle: TextStyle(color: Colors.white54), border: OutlineInputBorder()),
              ),
              if (_errorMessage != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 12))),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancelar")),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
                  child: Text(_saving ? "Enviando..." : "Enviar chamado"),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}



