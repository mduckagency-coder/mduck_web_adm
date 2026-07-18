import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";

class RecruiterTemplatesPage extends StatefulWidget {
  const RecruiterTemplatesPage({super.key});

  @override
  State<RecruiterTemplatesPage> createState() => _RecruiterTemplatesPageState();
}

class _RecruiterTemplatesPageState extends State<RecruiterTemplatesPage> {
  String _tab = "equipe";
  late Future<List<Map<String, dynamic>>> _future;
  bool _canManageShared = false;

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
    setState(() => _canManageShared = manager["role"] == "coordenador" || manager["role"] == "admin");
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;
    if (_tab == "equipe") {
      final rows = await client.from("message_templates").select().isFilter("owner_id", null).order("category").order("name");
      return (rows as List).cast<Map<String, dynamic>>();
    } else {
      final rows = await client.from("message_templates").select().eq("owner_id", userId).order("name");
      return (rows as List).cast<Map<String, dynamic>>();
    }
  }

  void _switchTab(String tab) {
    setState(() {
      _tab = tab;
      _future = _load();
    });
  }

  void _openForm({Map<String, dynamic>? existing, bool asPersonal = false}) {
    showDialog(context: context, builder: (context) => _TemplateFormDialog(existing: existing, forcePersonal: asPersonal)).then((saved) {
      if (saved == true) setState(() => _future = _load());
    });
  }

  Future<void> _duplicate(Map<String, dynamic> template) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;
    final manager = await client.from("managers").select("agency_id").eq("id", userId).single();
    await client.from("message_templates").insert({
      "agency_id": manager["agency_id"],
      "owner_id": userId,
      "name": template["name"].toString() + " (copia)",
      "category": template["category"],
      "objective": template["objective"],
      "message_text": template["message_text"],
      "notes": template["notes"],
    });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Copiado para sua biblioteca pessoal.")));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text("Modelos de Mensagens", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(width: 12),
            IconButton(icon: const Icon(Icons.refresh, color: Colors.white70), onPressed: () => setState(() => _future = _load())),
            const Spacer(),
            if (_tab == "equipe" && _canManageShared)
              ElevatedButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add),
                label: const Text("Novo modelo da equipe"),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
              ),
            if (_tab == "pessoal")
              ElevatedButton.icon(
                onPressed: () => _openForm(asPersonal: true),
                icon: const Icon(Icons.add),
                label: const Text("Novo modelo pessoal"),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB026FF), foregroundColor: Colors.white),
              ),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            ChoiceChip(label: const Text("Biblioteca da Equipe"), selected: _tab == "equipe", selectedColor: const Color(0xFF7A0BD4), labelStyle: TextStyle(color: _tab == "equipe" ? Colors.white : Colors.white70), onSelected: (_) => _switchTab("equipe")),
            const SizedBox(width: 8),
            ChoiceChip(label: const Text("Minha Biblioteca"), selected: _tab == "pessoal", selectedColor: const Color(0xFFB026FF), labelStyle: TextStyle(color: _tab == "pessoal" ? Colors.white : Colors.white70), onSelected: (_) => _switchTab("pessoal")),
          ]),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final list = snapshot.data!;
                if (list.isEmpty) return const Center(child: Text("Nenhum modelo cadastrado ainda.", style: TextStyle(color: Colors.white54)));
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final t = list[index];
                    return Card(
                      color: Colors.white.withOpacity(0.05),
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ExpansionTile(
                        title: Text(t["name"] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text((t["category"] as String?) ?? "", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        iconColor: Colors.white70,
                        collapsedIconColor: Colors.white70,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if ((t["objective"] as String?)?.isNotEmpty == true) Text("Objetivo: " + t["objective"], style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                if ((t["description"] as String?)?.isNotEmpty == true) Text(t["description"], style: const TextStyle(color: Colors.white54, fontSize: 12, fontStyle: FontStyle.italic)),
                                const SizedBox(height: 8),
                                SelectableText(t["message_text"] as String, style: const TextStyle(color: Colors.white)),
                                if ((t["notes"] as String?)?.isNotEmpty == true) ...[
                                  const SizedBox(height: 8),
                                  Text("Obs: " + t["notes"], style: const TextStyle(color: Colors.white38, fontSize: 12)),
                                ],
                                const SizedBox(height: 12),
                                Row(children: [
                                  if (_tab == "equipe")
                                    OutlinedButton.icon(onPressed: () => _duplicate(t), icon: const Icon(Icons.copy, size: 14), label: const Text("Duplicar pra mim")),
                                  if (_tab == "equipe" && _canManageShared) ...[
                                    const SizedBox(width: 8),
                                    TextButton(onPressed: () => _openForm(existing: t), child: const Text("Editar")),
                                  ],
                                  if (_tab == "pessoal") TextButton(onPressed: () => _openForm(existing: t, asPersonal: true), child: const Text("Editar")),
                                ]),
                              ],
                            ),
                          ),
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

class _TemplateFormDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final bool forcePersonal;
  const _TemplateFormDialog({this.existing, required this.forcePersonal});

  @override
  State<_TemplateFormDialog> createState() => _TemplateFormDialogState();
}

class _TemplateFormDialogState extends State<_TemplateFormDialog> {
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _objectiveController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _messageController = TextEditingController();
  final _notesController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameController.text = e["name"] ?? "";
      _categoryController.text = e["category"] ?? "";
      _objectiveController.text = e["objective"] ?? "";
      _descriptionController.text = e["description"] ?? "";
      _messageController.text = e["message_text"] ?? "";
      _notesController.text = e["notes"] ?? "";
    }
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty || _messageController.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;
    final manager = await client.from("managers").select("agency_id").eq("id", userId).single();

    final data = {
      "agency_id": manager["agency_id"],
      "owner_id": widget.forcePersonal ? userId : null,
      "name": _nameController.text.trim(),
      "category": _categoryController.text.trim(),
      "objective": _objectiveController.text.trim(),
      "description": _descriptionController.text.trim(),
      "message_text": _messageController.text.trim(),
      "notes": _notesController.text.trim(),
      "updated_at": DateTime.now().toIso8601String(),
    };

    if (widget.existing != null) {
      await client.from("message_templates").update(data).eq("id", widget.existing!["id"]);
    } else {
      await client.from("message_templates").insert(data);
    }

    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final client = Supabase.instance.client;
    await client.from("message_templates").delete().eq("id", widget.existing!["id"]);
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
                Text(widget.existing != null ? "Editar modelo" : "Novo modelo", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(controller: _nameController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Nome", labelStyle: TextStyle(color: Colors.white54))),
                const SizedBox(height: 8),
                TextField(controller: _categoryController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Categoria", labelStyle: TextStyle(color: Colors.white54))),
                const SizedBox(height: 8),
                TextField(controller: _objectiveController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Objetivo", labelStyle: TextStyle(color: Colors.white54))),
                const SizedBox(height: 8),
                TextField(controller: _descriptionController, maxLines: 2, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Descricao", labelStyle: TextStyle(color: Colors.white54))),
                const SizedBox(height: 8),
                TextField(controller: _messageController, maxLines: 4, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Texto da mensagem", labelStyle: TextStyle(color: Colors.white54))),
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

