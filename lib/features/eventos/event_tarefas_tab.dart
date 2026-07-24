import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "event_history_service.dart";

class EventTarefasTab extends StatefulWidget {
  final String eventId;
  const EventTarefasTab({super.key, required this.eventId});

  @override
  State<EventTarefasTab> createState() => _EventTarefasTabState();
}

class _EventTarefasTabState extends State<EventTarefasTab> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final client = Supabase.instance.client;
    final tasks = await client
        .from("event_tasks")
        .select()
        .eq("event_id", widget.eventId)
        .order("created_at");
    final taskList = (tasks as List).cast<Map<String, dynamic>>();

    if (taskList.isNotEmpty) {
      final taskIds = taskList.map((t) => t["id"] as String).toList();
      final items = await client.from("event_task_checklist_items").select().inFilter("task_id", taskIds).order("order_index");
      final itemsByTask = <String, List<Map<String, dynamic>>>{};
      for (final it in (items as List)) {
        itemsByTask.putIfAbsent(it["task_id"] as String, () => []).add(it as Map<String, dynamic>);
      }
      for (final t in taskList) {
        t["checklist"] = itemsByTask[t["id"]] ?? [];
      }

      final managerIds = taskList.map((t) => t["responsible_manager_id"] as String?).whereType<String>().toSet().toList();
      if (managerIds.isNotEmpty) {
        final managers = await client.from("managers").select("id, login_email").inFilter("id", managerIds);
        final emailMap = {for (final m in (managers as List)) m["id"] as String: m["login_email"] as String};
        for (final t in taskList) {
          final email = emailMap[t["responsible_manager_id"]];
          t["managers"] = email != null ? {"login_email": email} : null;
        }
      }
    }
    return taskList;
  }

  void _reload() => setState(() { _future = _load(); });

  void _openForm({Map<String, dynamic>? existing}) {
    showDialog(context: context, builder: (context) => _TaskFormDialog(eventId: widget.eventId, existing: existing)).then((saved) {
      if (saved == true) _reload();
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
            const Text("Tarefas", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add, size: 16),
              label: const Text("Nova tarefa"),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
            ),
          ]),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.hasError) return buildEventosLoadError(snapshot.error!);
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final list = snapshot.data!;
                if (list.isEmpty) return const Center(child: Text("Nenhuma tarefa cadastrada ainda.", style: TextStyle(color: Colors.white54)));
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final task = list[index];
                    final color = eventTaskStatusColor(task["status"] as String);
                    final managerData = task["managers"];
                    final checklist = (task["checklist"] as List).cast<Map<String, dynamic>>();
                    final done = checklist.where((c) => c["done"] == true).length;
                    return Card(
                      color: Colors.white.withOpacity(0.05),
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ExpansionTile(
                        title: Text(task["title"] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          "Responsavel: " +
                              (managerData is Map ? managerData["login_email"] as String? ?? "-" : "-") +
                              (task["due_date"] != null ? "  -  Prazo: " + (task["due_date"] as String) : "") +
                              (checklist.isNotEmpty ? "  -  " + done.toString() + "/" + checklist.length.toString() + " itens" : ""),
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(border: Border.all(color: color), borderRadius: BorderRadius.circular(8)),
                          child: Text(eventTaskStatusLabel(task["status"] as String), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if ((task["notes"] as String?)?.isNotEmpty == true) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(task["notes"] as String, style: const TextStyle(color: Colors.white70, fontSize: 12))),
                                ...checklist.map((c) => CheckboxListTile(
                                      value: c["done"] == true,
                                      onChanged: (_) => _toggleChecklistItem(c),
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      controlAffinity: ListTileControlAffinity.leading,
                                      activeColor: Colors.greenAccent,
                                      title: Text(c["label"] as String, style: const TextStyle(color: Colors.white, fontSize: 13)),
                                    )),
                                Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => _openForm(existing: task), child: const Text("Editar tarefa"))),
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

  Future<void> _toggleChecklistItem(Map<String, dynamic> item) async {
    final client = Supabase.instance.client;
    final newValue = item["done"] != true;
    try {
      await client.from("event_task_checklist_items").update({
        "done": newValue,
        "done_at": newValue ? DateTime.now().toIso8601String() : null,
      }).eq("id", item["id"]);
      await logEventHistory(eventId: widget.eventId, action: "tarefa_checklist", detail: item["label"] as String);
      _reload();
    } catch (e) {
      if (mounted) showEventosActionError(context, e);
    }
  }
}

class _TaskFormDialog extends StatefulWidget {
  final String eventId;
  final Map<String, dynamic>? existing;
  const _TaskFormDialog({required this.eventId, this.existing});

  @override
  State<_TaskFormDialog> createState() => _TaskFormDialogState();
}

class _TaskFormDialogState extends State<_TaskFormDialog> {
  late final _titleController = TextEditingController(text: widget.existing?["title"] as String? ?? "");
  late final _notesController = TextEditingController(text: widget.existing?["notes"] as String? ?? "");
  final _newItemController = TextEditingController();
  DateTime? _dueDate;
  String _status = "pendente";
  String? _responsibleId;
  List<Map<String, dynamic>> _managers = [];
  List<Map<String, dynamic>> _checklist = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _status = e["status"] as String;
      _responsibleId = e["responsible_manager_id"] as String?;
      if (e["due_date"] != null) _dueDate = DateTime.parse(e["due_date"] as String);
      _checklist = List<Map<String, dynamic>>.from((e["checklist"] as List?) ?? []);
    }
    _loadManagers();
  }

  Future<void> _loadManagers() async {
    final client = Supabase.instance.client;
    final rows = await client.from("managers").select("id, login_email").order("login_email");
    setState(() => _managers = (rows as List).cast<Map<String, dynamic>>());
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(context: context, initialDate: _dueDate ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (picked != null) setState(() => _dueDate = picked);
  }

  void _addChecklistItem() {
    final label = _newItemController.text.trim();
    if (label.isEmpty) return;
    setState(() {
      _checklist.add({"label": label, "done": false, "_new": true});
      _newItemController.clear();
    });
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser!.id;
      final dueDateSql = _dueDate != null ? _dueDate!.year.toString().padLeft(4, "0") + "-" + _dueDate!.month.toString().padLeft(2, "0") + "-" + _dueDate!.day.toString().padLeft(2, "0") : null;

      final data = {
        "event_id": widget.eventId,
        "title": _titleController.text.trim(),
        "responsible_manager_id": _responsibleId,
        "due_date": dueDateSql,
        "status": _status,
        "notes": _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        "completed_at": _status == "concluido" ? DateTime.now().toIso8601String() : null,
      };

      String taskId;
      if (widget.existing != null) {
        taskId = widget.existing!["id"] as String;
        await client.from("event_tasks").update(data).eq("id", taskId);
        await logEventHistory(eventId: widget.eventId, action: "tarefa_atualizada", detail: _titleController.text.trim());
      } else {
        final inserted = await client.from("event_tasks").insert({...data, "created_by": userId}).select("id").single();
        taskId = inserted["id"] as String;
        await logEventHistory(eventId: widget.eventId, action: "tarefa_criada", detail: _titleController.text.trim());
      }

      final newItems = _checklist.where((c) => c["_new"] == true).toList();
      if (newItems.isNotEmpty) {
        final rows = newItems.asMap().entries.map((entry) => {
              "task_id": taskId,
              "label": entry.value["label"],
              "order_index": entry.key,
            }).toList();
        await client.from("event_task_checklist_items").insert(rows);
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) showEventosActionError(context, e);
    }
  }

  Future<void> _delete() async {
    final client = Supabase.instance.client;
    try {
      await client.from("event_tasks").delete().eq("id", widget.existing!["id"]);
      await logEventHistory(eventId: widget.eventId, action: "tarefa_removida", detail: _titleController.text.trim());
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showEventosActionError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.existing != null ? "Editar tarefa" : "Nova tarefa", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(controller: _titleController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Titulo", labelStyle: TextStyle(color: Colors.white54))),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String?>(
                        value: _responsibleId,
                        dropdownColor: const Color(0xFF232323),
                        decoration: const InputDecoration(labelText: "Responsavel", labelStyle: TextStyle(color: Colors.white54)),
                        style: const TextStyle(color: Colors.white),
                        items: _managers.map((m) => DropdownMenuItem<String?>(value: m["id"] as String, child: Text(m["login_email"] as String))).toList(),
                        onChanged: (v) => setState(() => _responsibleId = v),
                      ),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(child: OutlinedButton.icon(onPressed: _pickDueDate, icon: const Icon(Icons.calendar_today, size: 14), label: Text(_dueDate != null ? _dueDate!.toString().substring(0, 10) : "Prazo"))),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _status,
                            dropdownColor: const Color(0xFF232323),
                            decoration: const InputDecoration(labelText: "Status", labelStyle: TextStyle(color: Colors.white54)),
                            style: const TextStyle(color: Colors.white),
                            items: eventTaskStatusOptions.map((s) => DropdownMenuItem(value: s, child: Text(eventTaskStatusLabel(s)))).toList(),
                            onChanged: (v) => setState(() => _status = v!),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      TextField(controller: _notesController, maxLines: 2, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Observacoes", labelStyle: TextStyle(color: Colors.white54))),
                      const SizedBox(height: 12),
                      const Text("Checklist", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      ..._checklist.map((c) => Row(children: [
                            Expanded(child: Text(c["label"] as String, style: const TextStyle(color: Colors.white70, fontSize: 13))),
                            IconButton(icon: const Icon(Icons.close, size: 14, color: Colors.white38), onPressed: () => setState(() => _checklist.remove(c))),
                          ])),
                      Row(children: [
                        Expanded(
                          child: TextField(
                            controller: _newItemController,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: const InputDecoration(hintText: "Novo item do checklist", hintStyle: TextStyle(color: Colors.white38), isDense: true),
                            onSubmitted: (_) => _addChecklistItem(),
                          ),
                        ),
                        IconButton(icon: const Icon(Icons.add, color: Color(0xFF7A0BD4)), onPressed: _addChecklistItem),
                      ]),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                if (widget.existing != null) TextButton(onPressed: _delete, child: const Text("Excluir", style: TextStyle(color: Colors.redAccent))),
                const Spacer(),
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
    );
  }
}
