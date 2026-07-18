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

  Future<void> _markDone(String id) async {
    final client = Supabase.instance.client;
    await client.from("recruiter_feedbacks").update({"status": "concluido", "read_at": DateTime.now().toIso8601String()}).eq("id", id);
    setState(() => _future = _load());
  }

  Future<void> _sendReply(String id) async {
    final controller = _replyControllers[id];
    if (controller == null || controller.text.trim().isEmpty) return;
    final client = Supabase.instance.client;
    await client.from("recruiter_feedbacks").update({
      "reply": controller.text.trim(),
      "replied_at": DateTime.now().toIso8601String(),
      "read_at": DateTime.now().toIso8601String(),
    }).eq("id", id);
    setState(() => _future = _load());
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
                              const SizedBox(height: 10),
                              TextField(
                                controller: _controllerFor(f["id"] as String),
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                decoration: const InputDecoration(
                                  labelText: "Responder ao gestor (caso nao va marcar como concluido)",
                                  labelStyle: TextStyle(color: Colors.white54, fontSize: 12),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(children: [
                                ElevatedButton(
                                  onPressed: () => _markDone(f["id"] as String),
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
                                  child: const Text("Marcar como concluido"),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  onPressed: () => _sendReply(f["id"] as String),
                                  child: const Text("Enviar resposta"),
                                ),
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
