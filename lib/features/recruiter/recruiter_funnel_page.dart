import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";

class RecruiterFunnelPage extends StatefulWidget {
  const RecruiterFunnelPage({super.key});

  @override
  State<RecruiterFunnelPage> createState() => _RecruiterFunnelPageState();
}

class _RecruiterFunnelPageState extends State<RecruiterFunnelPage> {
  late Future<List<Map<String, dynamic>>> _future;
  bool _canManage = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _checkRole();
  }

  Future<void> _checkRole() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;
    final manager = await client.from("managers").select("role").eq("id", userId).single();
    setState(() => _canManage = manager["role"] == "coordenador" || manager["role"] == "admin");
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final client = Supabase.instance.client;
    final rows = await client.from("message_funnel_steps").select().order("step_order");
    return (rows as List).cast<Map<String, dynamic>>();
  }

  void _openForm({Map<String, dynamic>? existing}) {
    showDialog(context: context, builder: (context) => _FunnelStepFormDialog(existing: existing)).then((saved) {
      if (saved == true) setState(() => _future = _load());
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
            const Text("Funil de Mensagens", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(width: 12),
            IconButton(icon: const Icon(Icons.refresh, color: Colors.white70), onPressed: () => setState(() => _future = _load())),
            const Spacer(),
            if (_canManage)
              ElevatedButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add),
                label: const Text("Nova Etapa"),
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
                if (list.isEmpty) return const Center(child: Text("Nenhuma etapa cadastrada ainda.", style: TextStyle(color: Colors.white54)));
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final step = list[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Card(
                          color: Colors.white.withOpacity(0.05),
                          margin: const EdgeInsets.only(bottom: 4),
                          child: ExpansionTile(
                            title: Text("Etapa " + (index + 1).toString() + " - " + (step["name"] as String), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            subtitle: Text((step["objective"] as String?) ?? "", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                            iconColor: Colors.white70,
                            collapsedIconColor: Colors.white70,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if ((step["suggested_message"] as String?)?.isNotEmpty == true) ...[
                                      const Text("Mensagem sugerida:", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                                      SelectableText(step["suggested_message"], style: const TextStyle(color: Colors.white)),
                                      const SizedBox(height: 8),
                                    ],
                                    if ((step["next_action"] as String?)?.isNotEmpty == true) Text("Proxima acao: " + step["next_action"], style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                    if ((step["recommended_response_time"] as String?)?.isNotEmpty == true)
                                      Text("Tempo recomendado: " + step["recommended_response_time"], style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                    const SizedBox(height: 12),
                                    const Text("Se o streamer...", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                    _situationRow("Nao respondeu", step["message_nao_respondeu"] as String?),
                                    _situationRow("Recusou", step["message_recusou"] as String?),
                                    _situationRow("Pediu mais informacoes", step["message_pediu_info"] as String?),
                                    _situationRow("Solicitou outro horario", step["message_outro_horario"] as String?),
                                    _situationRow("Ja possui agencia", step["message_ja_possui_agencia"] as String?),
                                    if ((step["notes"] as String?)?.isNotEmpty == true) ...[
                                      const SizedBox(height: 8),
                                      Text("Obs: " + step["notes"], style: const TextStyle(color: Colors.white38, fontSize: 12)),
                                    ],
                                    if (_canManage) ...[
                                      const SizedBox(height: 12),
                                      TextButton(onPressed: () => _openForm(existing: step), child: const Text("Editar etapa")),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (index < list.length - 1) const Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Icon(Icons.arrow_downward, color: Colors.white24, size: 18)),
                      ],
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

  Widget _situationRow(String label, String? message) {
    if (message == null || message.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: RichText(text: TextSpan(children: [
        TextSpan(text: label + ": ", style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold)),
        TextSpan(text: message, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ])),
    );
  }
}

class _FunnelStepFormDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const _FunnelStepFormDialog({this.existing});

  @override
  State<_FunnelStepFormDialog> createState() => _FunnelStepFormDialogState();
}

class _FunnelStepFormDialogState extends State<_FunnelStepFormDialog> {
  final _nameController = TextEditingController();
  final _objectiveController = TextEditingController();
  final _suggestedController = TextEditingController();
  final _nextActionController = TextEditingController();
  final _responseTimeController = TextEditingController();
  final _notesController = TextEditingController();
  final _naoRespondeuController = TextEditingController();
  final _recusouController = TextEditingController();
  final _pediuInfoController = TextEditingController();
  final _outroHorarioController = TextEditingController();
  final _jaPossuiController = TextEditingController();
  final _orderController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameController.text = e["name"] ?? "";
      _objectiveController.text = e["objective"] ?? "";
      _suggestedController.text = e["suggested_message"] ?? "";
      _nextActionController.text = e["next_action"] ?? "";
      _responseTimeController.text = e["recommended_response_time"] ?? "";
      _notesController.text = e["notes"] ?? "";
      _naoRespondeuController.text = e["message_nao_respondeu"] ?? "";
      _recusouController.text = e["message_recusou"] ?? "";
      _pediuInfoController.text = e["message_pediu_info"] ?? "";
      _outroHorarioController.text = e["message_outro_horario"] ?? "";
      _jaPossuiController.text = e["message_ja_possui_agencia"] ?? "";
      _orderController.text = (e["step_order"] ?? 0).toString();
    }
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;
    final manager = await client.from("managers").select("agency_id").eq("id", userId).single();

    final data = {
      "agency_id": manager["agency_id"],
      "step_order": int.tryParse(_orderController.text) ?? 0,
      "name": _nameController.text.trim(),
      "objective": _objectiveController.text.trim(),
      "suggested_message": _suggestedController.text.trim(),
      "next_action": _nextActionController.text.trim(),
      "recommended_response_time": _responseTimeController.text.trim(),
      "notes": _notesController.text.trim(),
      "message_nao_respondeu": _naoRespondeuController.text.trim(),
      "message_recusou": _recusouController.text.trim(),
      "message_pediu_info": _pediuInfoController.text.trim(),
      "message_outro_horario": _outroHorarioController.text.trim(),
      "message_ja_possui_agencia": _jaPossuiController.text.trim(),
    };

    if (widget.existing != null) {
      await client.from("message_funnel_steps").update(data).eq("id", widget.existing!["id"]);
    } else {
      await client.from("message_funnel_steps").insert(data);
    }

    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final client = Supabase.instance.client;
    await client.from("message_funnel_steps").delete().eq("id", widget.existing!["id"]);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 700),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.existing != null ? "Editar etapa" : "Nova etapa", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(controller: _orderController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Ordem (0, 1, 2...)", labelStyle: TextStyle(color: Colors.white54))),
                const SizedBox(height: 8),
                TextField(controller: _nameController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Nome da etapa", labelStyle: TextStyle(color: Colors.white54))),
                const SizedBox(height: 8),
                TextField(controller: _objectiveController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Objetivo", labelStyle: TextStyle(color: Colors.white54))),
                const SizedBox(height: 8),
                TextField(controller: _suggestedController, maxLines: 3, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Mensagem sugerida", labelStyle: TextStyle(color: Colors.white54))),
                const SizedBox(height: 8),
                TextField(controller: _nextActionController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Proxima acao", labelStyle: TextStyle(color: Colors.white54))),
                const SizedBox(height: 8),
                TextField(controller: _responseTimeController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Tempo recomendado para retorno", labelStyle: TextStyle(color: Colors.white54))),
                const SizedBox(height: 16),
                const Text("Mensagens por situacao", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(controller: _naoRespondeuController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Nao respondeu", labelStyle: TextStyle(color: Colors.white54))),
                const SizedBox(height: 8),
                TextField(controller: _recusouController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Recusou", labelStyle: TextStyle(color: Colors.white54))),
                const SizedBox(height: 8),
                TextField(controller: _pediuInfoController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Pediu mais informacoes", labelStyle: TextStyle(color: Colors.white54))),
                const SizedBox(height: 8),
                TextField(controller: _outroHorarioController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Solicitou outro horario", labelStyle: TextStyle(color: Colors.white54))),
                const SizedBox(height: 8),
                TextField(controller: _jaPossuiController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Ja possui agencia", labelStyle: TextStyle(color: Colors.white54))),
                const SizedBox(height: 8),
                TextField(controller: _notesController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Observacoes", labelStyle: TextStyle(color: Colors.white54))),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  if (widget.existing != null) TextButton(onPressed: _delete, child: const Text("Excluir", style: TextStyle(color: Colors.redAccent))),
                  const SizedBox(width: 8),
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
