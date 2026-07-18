import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";

class TeamFeedbacksPage extends StatefulWidget {
  const TeamFeedbacksPage({super.key});

  @override
  State<TeamFeedbacksPage> createState() => _TeamFeedbacksPageState();
}

class _TeamFeedbacksPageState extends State<TeamFeedbacksPage> {
  List<Map<String, dynamic>> _recruiters = [];
  String? _selectedRecruiterId;
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _loadRecruiters();
    _future = Future.value([]);
  }

  Future<void> _loadRecruiters() async {
    final client = Supabase.instance.client;
    final leads = await client.from("leads").select("recruiter_id");
    final ids = (leads as List).map((l) => l["recruiter_id"] as String).toSet();
    if (ids.isEmpty) return;
    final rows = await client.from("managers").select("id, login_email").inFilter("id", ids.toList());
    setState(() => _recruiters = (rows as List).cast<Map<String, dynamic>>());
  }

  Future<List<Map<String, dynamic>>> _loadFeedbacks(String recruiterId) async {
    final client = Supabase.instance.client;
    final rows = await client.from("recruiter_feedbacks").select("*, managers!recruiter_feedbacks_given_by_fkey(login_email)").eq("recruiter_id", recruiterId).order("created_at", ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> _finalize(String id) async {
    final client = Supabase.instance.client;
    await client.from("recruiter_feedbacks").update({"status": "concluido"}).eq("id", id);
    if (_selectedRecruiterId != null) setState(() => _future = _loadFeedbacks(_selectedRecruiterId!));
  }

  void _openAdd() {
    if (_selectedRecruiterId == null) return;
    showDialog(context: context, builder: (context) => _FeedbackFormDialog(recruiterId: _selectedRecruiterId!)).then((saved) {
      if (saved == true) setState(() => _future = _loadFeedbacks(_selectedRecruiterId!));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text("Feedbacks", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(width: 12),
            DropdownButton<String>(
              value: _selectedRecruiterId,
              hint: const Text("Escolha o recrutador", style: TextStyle(color: Colors.white54)),
              dropdownColor: const Color(0xFF1A1A1A),
              style: const TextStyle(color: Colors.white),
              items: _recruiters.map((r) => DropdownMenuItem(value: r["id"] as String, child: Text(r["login_email"] as String))).toList(),
              onChanged: (v) => setState(() {
                _selectedRecruiterId = v;
                if (v != null) _future = _loadFeedbacks(v);
              }),
            ),
            const Spacer(),
            if (_selectedRecruiterId != null)
              ElevatedButton.icon(
                onPressed: _openAdd,
                icon: const Icon(Icons.add),
                label: const Text("Novo Feedback"),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
              ),
          ]),
          const SizedBox(height: 20),
          Expanded(
            child: _selectedRecruiterId == null
                ? const Center(child: Text("Escolha um recrutador para ver os feedbacks.", style: TextStyle(color: Colors.white54)))
                : FutureBuilder<List<Map<String, dynamic>>>(
                    future: _future,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      final list = snapshot.data!;
                      if (list.isEmpty) return const Center(child: Text("Nenhum feedback registrado ainda.", style: TextStyle(color: Colors.white54)));
                      return ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (context, index) {
                          final f = list[index];
                          final givenBy = f["managers"];
                          final date = DateTime.parse(f["created_at"] as String).toLocal().toString().substring(0, 16);
                          final isPendingWithReply = f["status"] == "pendente" && (f["reply"] as String?)?.isNotEmpty == true;
                          return Card(
                            color: Colors.white.withOpacity(0.05),
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(date + " - por " + (givenBy is Map ? givenBy["login_email"] as String? ?? "-" : "-"), style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                  const SizedBox(height: 8),
                                  if ((f["positives"] as String?)?.isNotEmpty == true) Text("Pontos positivos: " + f["positives"], style: const TextStyle(color: Colors.greenAccent, fontSize: 13)),
                                  if ((f["improvements"] as String?)?.isNotEmpty == true) Text("Pontos de melhoria: " + f["improvements"], style: const TextStyle(color: Colors.amber, fontSize: 13)),
                                  if ((f["action_plan"] as String?)?.isNotEmpty == true) Text("Plano de acao: " + f["action_plan"], style: const TextStyle(color: Colors.white, fontSize: 13)),
                                  if ((f["notes"] as String?)?.isNotEmpty == true) Text("Observacoes: " + f["notes"], style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                  if ((f["reply"] as String?)?.isNotEmpty == true) ...[
                                    const SizedBox(height: 8),
                                    Text("Resposta do recrutador: " + (f["reply"] as String), style: const TextStyle(color: Colors.tealAccent, fontSize: 13)),
                                  ],
                                  if (f["confirmed_at"] != null)
                                    Text("Confirmado pelo recrutador em " + DateTime.parse(f["confirmed_at"] as String).toLocal().toString().substring(0, 16), style: const TextStyle(color: Colors.greenAccent, fontSize: 11)),
                                  if (isPendingWithReply) ...[
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: ElevatedButton(
                                        onPressed: () => _finalize(f["id"] as String),
                                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
                                        child: const Text("Finalizar ticket"),
                                      ),
                                    ),
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

class _FeedbackFormDialog extends StatefulWidget {
  final String recruiterId;
  const _FeedbackFormDialog({required this.recruiterId});

  @override
  State<_FeedbackFormDialog> createState() => _FeedbackFormDialogState();
}

class _FeedbackFormDialogState extends State<_FeedbackFormDialog> {
  final _titleController = TextEditingController();
  final _objectivesController = TextEditingController();
  final _positivesController = TextEditingController();
  final _improvementsController = TextEditingController();
  final _actionPlanController = TextEditingController();
  final _notesController = TextEditingController();
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    final client = Supabase.instance.client;
    await client.from("recruiter_feedbacks").insert({
      "recruiter_id": widget.recruiterId,
      "given_by": client.auth.currentUser!.id,
      "title": _titleController.text.trim(),
      "objectives": _objectivesController.text.trim(),
      "positives": _positivesController.text.trim(),
      "improvements": _improvementsController.text.trim(),
      "action_plan": _actionPlanController.text.trim(),
      "notes": _notesController.text.trim(),
    });
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Novo Feedback", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(controller: _titleController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Titulo", labelStyle: TextStyle(color: Colors.white54))),
                const SizedBox(height: 8),
                TextField(controller: _objectivesController, maxLines: 2, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Objetivos definidos", labelStyle: TextStyle(color: Colors.white54))),
                const SizedBox(height: 8),
                TextField(controller: _positivesController, maxLines: 2, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Pontos positivos", labelStyle: TextStyle(color: Colors.white54))),
                const SizedBox(height: 8),
                TextField(controller: _improvementsController, maxLines: 2, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Pontos de melhoria", labelStyle: TextStyle(color: Colors.white54))),
                const SizedBox(height: 8),
                TextField(controller: _actionPlanController, maxLines: 2, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Plano de acao", labelStyle: TextStyle(color: Colors.white54))),
                const SizedBox(height: 8),
                TextField(controller: _notesController, maxLines: 2, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Observacoes", labelStyle: TextStyle(color: Colors.white54))),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancelar")),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
                    child: Text(_saving ? "Salvando..." : "Salvar"),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
