import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";

const _colorOptions = [
  ("green", "Verde", Colors.greenAccent),
  ("amber", "Amarelo", Colors.amber),
  ("orange", "Laranja", Colors.orangeAccent),
  ("red", "Vermelho", Colors.redAccent),
];

class TeamSlaPage extends StatefulWidget {
  const TeamSlaPage({super.key});

  @override
  State<TeamSlaPage> createState() => _TeamSlaPageState();
}

class _TeamSlaPageState extends State<TeamSlaPage> {
  List<Map<String, dynamic>> _list = [];
  bool _loading = true;
  bool _hasChanges = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final client = Supabase.instance.client;
    final rows = await client.from("lead_status_sla").select().order("order_index");
    setState(() {
      _list = (rows as List).cast<Map<String, dynamic>>();
      _loading = false;
    });
  }

  Future<void> _persistOrder() async {
    final client = Supabase.instance.client;
    for (var i = 0; i < _list.length; i++) {
      await client.from("lead_status_sla").update({"order_index": i}).eq("id", _list[i]["id"]);
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _list.removeAt(oldIndex);
      _list.insert(newIndex, item);
      _hasChanges = true;
    });
  }

  Future<void> _saveOrder() async {
    setState(() => _saving = true);
    await _persistOrder();
    setState(() {
      _hasChanges = false;
      _saving = false;
    });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ordem salva.")));
  }

  void _openForm({Map<String, dynamic>? existing}) {
    showDialog(context: context, builder: (context) => _SlaFormDialog(existing: existing)).then((saved) {
      if (saved == true) _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text("Prazos (SLA)", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(width: 12),
            IconButton(icon: const Icon(Icons.refresh, color: Colors.white70), onPressed: _load),
            const Spacer(),
            if (_hasChanges)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _saveOrder,
                  icon: const Icon(Icons.save, size: 16),
                  label: Text(_saving ? "Salvando..." : "Salvar ordem"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black),
                ),
              ),
            ElevatedButton.icon(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add),
              label: const Text("Adicionar Prazo"),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
            ),
          ]),
          const SizedBox(height: 4),
          const Text(
            "Prazos com o Nome exatamente igual a um status de lead geram alertas automaticos. Arraste para reordenar.",
            style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _list.isEmpty
                ? const Center(child: Text("Nenhum prazo cadastrado ainda.", style: TextStyle(color: Colors.white54)))
                : ReorderableListView.builder(
                    itemCount: _list.length,
                    onReorder: _onReorder,
                    itemBuilder: (context, index) {
                      final s = _list[index];
                      final colorInfo = _colorOptions.firstWhere((c) => c.$1 == s["alert_color"], orElse: () => _colorOptions[1]);
                      final active = s["is_active"] as bool? ?? true;
                      return Card(
                        key: ValueKey(s["id"]),
                        color: Colors.white.withOpacity(0.05),
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          onTap: () => _openForm(existing: s),
                          leading: const Icon(Icons.drag_handle, color: Colors.white38),
                          title: Row(children: [
                            Icon(Icons.timer, color: colorInfo.$3, size: 18),
                            const SizedBox(width: 8),
                            Text((s["name"] as String?) ?? s["status"] as String, style: TextStyle(color: active ? Colors.white : Colors.white38, fontWeight: FontWeight.bold)),
                          ]),
                          subtitle: Text(
                            ((s["description"] as String?)?.isNotEmpty == true ? (s["description"] as String) + " - " : "") +
                                (s["max_hours"] as num).toString() + " " + (s["time_unit"] as String? ?? "horas") +
                                (!active ? "  (INATIVO)" : ""),
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SlaFormDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const _SlaFormDialog({this.existing});

  @override
  State<_SlaFormDialog> createState() => _SlaFormDialogState();
}

class _SlaFormDialogState extends State<_SlaFormDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _timeController = TextEditingController();
  String _unit = "horas";
  String _color = "amber";
  bool _isActive = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameController.text = (e["name"] as String?) ?? (e["status"] as String? ?? "");
      _descriptionController.text = e["description"] ?? "";
      _timeController.text = (e["max_hours"] as num).toString();
      _unit = e["time_unit"] ?? "horas";
      _color = e["alert_color"] ?? "amber";
      _isActive = e["is_active"] ?? true;
    }
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty || _timeController.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;
    final manager = await client.from("managers").select("agency_id").eq("id", userId).single();
    final maxOrder = widget.existing != null ? widget.existing!["order_index"] : 999;

    final data = {
      "agency_id": manager["agency_id"],
      "name": _nameController.text.trim(),
      "status": _nameController.text.trim(),
      "description": _descriptionController.text.trim(),
      "max_hours": double.tryParse(_timeController.text) ?? 0,
      "time_unit": _unit,
      "alert_color": _color,
      "order_index": maxOrder,
      "is_active": _isActive,
      "updated_at": DateTime.now().toIso8601String(),
    };

    if (widget.existing != null) {
      await client.from("lead_status_sla").update(data).eq("id", widget.existing!["id"]);
    } else {
      await client.from("lead_status_sla").insert(data);
    }

    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final client = Supabase.instance.client;
    await client.from("lead_status_sla").delete().eq("id", widget.existing!["id"]);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.existing != null ? "Editar prazo" : "Novo prazo", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text("A ordem agora e definida arrastando na lista.", style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic)),
                const SizedBox(height: 16),
                TextField(controller: _nameController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Nome da etapa", labelStyle: TextStyle(color: Colors.white54))),
                const SizedBox(height: 8),
                TextField(controller: _descriptionController, maxLines: 2, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Descricao", labelStyle: TextStyle(color: Colors.white54))),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: TextField(controller: _timeController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Tempo recomendado", labelStyle: TextStyle(color: Colors.white54)))),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _unit,
                    dropdownColor: const Color(0xFF1A1A1A),
                    style: const TextStyle(color: Colors.white),
                    items: const [DropdownMenuItem(value: "minutos", child: Text("minutos")), DropdownMenuItem(value: "horas", child: Text("horas")), DropdownMenuItem(value: "dias", child: Text("dias"))],
                    onChanged: (v) => setState(() => _unit = v!),
                  ),
                ]),
                const SizedBox(height: 8),
                const Text("Cor do alerta", style: TextStyle(color: Colors.white54, fontSize: 12)),
                Wrap(spacing: 8, children: _colorOptions.map((c) {
                  final selected = _color == c.$1;
                  return ChoiceChip(
                    label: Text(c.$2, style: TextStyle(color: selected ? Colors.white : c.$3, fontSize: 12)),
                    selected: selected,
                    selectedColor: c.$3,
                    onSelected: (_) => setState(() => _color = c.$1),
                  );
                }).toList()),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                  title: const Text("Ativo", style: TextStyle(color: Colors.white)),
                  activeColor: const Color(0xFF7A0BD4),
                  contentPadding: EdgeInsets.zero,
                ),
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

