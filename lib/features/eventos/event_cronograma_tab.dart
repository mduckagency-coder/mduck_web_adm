import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "event_history_service.dart";

Color _scheduleStatusColor(String status) {
  switch (status) {
    case "em_andamento":
      return Colors.blueAccent;
    case "concluido":
      return Colors.greenAccent;
    case "cancelado":
      return Colors.redAccent;
    default:
      return Colors.amber;
  }
}

String _scheduleStatusLabel(String status) {
  switch (status) {
    case "em_andamento":
      return "Em andamento";
    case "concluido":
      return "Concluido";
    case "cancelado":
      return "Cancelado";
    default:
      return "Pendente";
  }
}

const _scheduleStatusOptions = ["pendente", "em_andamento", "concluido", "cancelado"];

class EventCronogramaTab extends StatefulWidget {
  final String eventId;
  const EventCronogramaTab({super.key, required this.eventId});

  @override
  State<EventCronogramaTab> createState() => _EventCronogramaTabState();
}

class _EventCronogramaTabState extends State<EventCronogramaTab> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final client = Supabase.instance.client;
    final rows = await client
        .from("event_schedule")
        .select()
        .eq("event_id", widget.eventId)
        .order("activity_date")
        .order("activity_time");
    final list = (rows as List).cast<Map<String, dynamic>>();

    final managerIds = list.map((r) => r["responsible_manager_id"] as String?).whereType<String>().toSet().toList();
    if (managerIds.isNotEmpty) {
      final managers = await client.from("managers").select("id, login_email").inFilter("id", managerIds);
      final emailMap = {for (final m in (managers as List)) m["id"] as String: m["login_email"] as String};
      for (final r in list) {
        final email = emailMap[r["responsible_manager_id"]];
        r["managers"] = email != null ? {"login_email": email} : null;
      }
    }
    return list;
  }

  void _reload() => setState(() { _future = _load(); });

  void _openForm({Map<String, dynamic>? existing}) {
    showDialog(context: context, builder: (context) => _ScheduleFormDialog(eventId: widget.eventId, existing: existing)).then((saved) {
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
            const Text("Cronograma", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add, size: 16),
              label: const Text("Nova atividade"),
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
                if (list.isEmpty) return const Center(child: Text("Nenhuma atividade no cronograma ainda.", style: TextStyle(color: Colors.white54)));
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final item = list[index];
                    final color = _scheduleStatusColor(item["status"] as String);
                    final managerData = item["managers"];
                    final date = DateTime.parse(item["activity_date"] as String);
                    final time = item["activity_time"] as String?;
                    final notes = item["notes"] as String?;
                    return Card(
                      color: Colors.white.withOpacity(0.05),
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        onTap: () => _openForm(existing: item),
                        leading: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(date.day.toString().padLeft(2, "0") + "/" + date.month.toString().padLeft(2, "0"), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            if (time != null) Text(time.substring(0, 5), style: const TextStyle(color: Colors.white54, fontSize: 11)),
                          ],
                        ),
                        title: Text(item["description"] as String, style: const TextStyle(color: Colors.white)),
                        subtitle: Text(
                          "Responsavel: " + (managerData is Map ? managerData["login_email"] as String? ?? "-" : "-") + (notes != null && notes.isNotEmpty ? "  -  " + notes : ""),
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(border: Border.all(color: color), borderRadius: BorderRadius.circular(8)),
                          child: Text(_scheduleStatusLabel(item["status"] as String), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
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

class _ScheduleFormDialog extends StatefulWidget {
  final String eventId;
  final Map<String, dynamic>? existing;
  const _ScheduleFormDialog({required this.eventId, this.existing});

  @override
  State<_ScheduleFormDialog> createState() => _ScheduleFormDialogState();
}

class _ScheduleFormDialogState extends State<_ScheduleFormDialog> {
  late final _descriptionController = TextEditingController(text: widget.existing?["description"] as String? ?? "");
  late final _notesController = TextEditingController(text: widget.existing?["notes"] as String? ?? "");
  DateTime _date = DateTime.now();
  TimeOfDay? _time;
  String _status = "pendente";
  String? _responsibleId;
  List<Map<String, dynamic>> _managers = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _date = DateTime.parse(e["activity_date"] as String);
      final timeStr = e["activity_time"] as String?;
      if (timeStr != null) {
        final parts = timeStr.split(":");
        _time = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
      _status = e["status"] as String;
      _responsibleId = e["responsible_manager_id"] as String?;
    }
    _loadManagers();
  }

  Future<void> _loadManagers() async {
    final client = Supabase.instance.client;
    final rows = await client.from("managers").select("id, login_email").order("login_email");
    setState(() => _managers = (rows as List).cast<Map<String, dynamic>>());
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time ?? TimeOfDay.now());
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    if (_descriptionController.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser!.id;
      final timeSql = _time != null ? _time!.hour.toString().padLeft(2, "0") + ":" + _time!.minute.toString().padLeft(2, "0") + ":00" : null;
      final dateSql = _date.year.toString().padLeft(4, "0") + "-" + _date.month.toString().padLeft(2, "0") + "-" + _date.day.toString().padLeft(2, "0");

      final data = {
        "event_id": widget.eventId,
        "activity_date": dateSql,
        "activity_time": timeSql,
        "description": _descriptionController.text.trim(),
        "responsible_manager_id": _responsibleId,
        "status": _status,
        "notes": _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      };

      if (widget.existing != null) {
        await client.from("event_schedule").update(data).eq("id", widget.existing!["id"]);
        await logEventHistory(eventId: widget.eventId, action: "cronograma_atualizado", detail: _descriptionController.text.trim());
      } else {
        await client.from("event_schedule").insert({...data, "created_by": userId});
        await logEventHistory(eventId: widget.eventId, action: "cronograma_adicionado", detail: _descriptionController.text.trim());
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
      await client.from("event_schedule").delete().eq("id", widget.existing!["id"]);
      await logEventHistory(eventId: widget.eventId, action: "cronograma_removido", detail: _descriptionController.text.trim());
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
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.existing != null ? "Editar atividade" : "Nova atividade", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(controller: _descriptionController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Descricao", labelStyle: TextStyle(color: Colors.white54))),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: OutlinedButton.icon(onPressed: _pickDate, icon: const Icon(Icons.calendar_today, size: 14), label: Text(_date.toString().substring(0, 10)))),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton.icon(onPressed: _pickTime, icon: const Icon(Icons.access_time, size: 14), label: Text(_time != null ? _time!.format(context) : "Horario"))),
              ]),
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
              DropdownButtonFormField<String>(
                value: _status,
                dropdownColor: const Color(0xFF232323),
                decoration: const InputDecoration(labelText: "Status", labelStyle: TextStyle(color: Colors.white54)),
                style: const TextStyle(color: Colors.white),
                items: _scheduleStatusOptions.map((s) => DropdownMenuItem(value: s, child: Text(_scheduleStatusLabel(s)))).toList(),
                onChanged: (v) => setState(() => _status = v!),
              ),
              const SizedBox(height: 8),
              TextField(controller: _notesController, maxLines: 2, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Observacoes", labelStyle: TextStyle(color: Colors.white54))),
              const SizedBox(height: 16),
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
