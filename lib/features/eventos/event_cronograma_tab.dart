import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "../calendario/models/calendar_event.dart";
import "../calendario/models/event_category.dart";
import "../calendario/models/event_participant.dart";
import "../calendario/services/calendar_service.dart";
import "../calendario/widgets/streamer_picker_dialog.dart";
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

/// Mapeia o status do cronograma (pendente/em_andamento/concluido/cancelado)
/// para o vocabulario do modulo Calendario (agendado/em_andamento/
/// finalizado/cancelado), usado no espelho calendar_events.
String _toCalendarStatus(String status) {
  switch (status) {
    case "em_andamento":
      return "em_andamento";
    case "concluido":
      return "finalizado";
    case "cancelado":
      return "cancelado";
    default:
      return "agendado";
  }
}

Color _hexToColor(String hex) {
  final cleaned = hex.replaceFirst("#", "");
  return Color(int.parse("FF" + cleaned, radix: 16));
}

String _fmtDateTime(DateTime dt) =>
    dt.day.toString().padLeft(2, "0") + "/" + dt.month.toString().padLeft(2, "0") + "/" + dt.year.toString() + "  " + dt.hour.toString().padLeft(2, "0") + ":" + dt.minute.toString().padLeft(2, "0");

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
        .select("*, category:event_categories(name, color), links:event_schedule_streamers(streamer:profiles(id, display_name, tiktok_username, tiktok_creator_id, avatar_url))")
        .eq("event_id", widget.eventId)
        .order("start_at");
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
          const SizedBox(height: 4),
          const Text(
            "Atividades vinculadas a um streamer aparecem tambem na Agenda dos Streamers (calendario individual). Marcando \"mostrar no calendario da agencia\", aparecem tambem na Agenda da Agencia.",
            style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic),
          ),
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
                    final startAt = DateTime.parse(item["start_at"] as String).toLocal();
                    final notes = item["notes"] as String?;
                    final categoryData = item["category"];
                    final links = (item["links"] as List?) ?? const [];
                    final streamers = links.map((l) => (l as Map)["streamer"]).whereType<Map>().toList();
                    final awards = ((item["awards"] as List?) ?? const []).cast<Map<String, dynamic>>();
                    final awardsLabel = awards.map((a) => a["label"] as String? ?? "").where((s) => s.isNotEmpty).join(", ");

                    return Card(
                      color: Colors.white.withOpacity(0.05),
                      margin: const EdgeInsets.only(bottom: 10),
                      child: InkWell(
                        onTap: () => _openForm(existing: item),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 52,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(startAt.day.toString().padLeft(2, "0") + "/" + startAt.month.toString().padLeft(2, "0"), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                    Text(startAt.hour.toString().padLeft(2, "0") + ":" + startAt.minute.toString().padLeft(2, "0"), style: const TextStyle(color: Colors.white54, fontSize: 11)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      Expanded(child: Text(item["description"] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
                                      if (categoryData is Map)
                                        Container(
                                          margin: const EdgeInsets.only(left: 6),
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(color: _hexToColor(categoryData["color"] as String? ?? "#7A0BD4").withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                                          child: Text(categoryData["name"] as String? ?? "-", style: TextStyle(color: _hexToColor(categoryData["color"] as String? ?? "#7A0BD4"), fontSize: 10, fontWeight: FontWeight.bold)),
                                        ),
                                    ]),
                                    if (streamers.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Wrap(spacing: 6, runSpacing: 4, children: streamers.map((s) {
                                        final avatarUrl = s["avatar_url"] as String?;
                                        return Row(mainAxisSize: MainAxisSize.min, children: [
                                          CircleAvatar(radius: 9, backgroundColor: Colors.white24, backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null, child: avatarUrl == null ? const Icon(Icons.person, size: 10, color: Colors.white54) : null),
                                          const SizedBox(width: 4),
                                          Text((s["display_name"] as String?) ?? "-", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                        ]);
                                      }).toList()),
                                    ],
                                    if (awardsLabel.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text("Premiacao: " + awardsLabel, style: const TextStyle(color: Colors.amber, fontSize: 12)),
                                    ],
                                    const SizedBox(height: 4),
                                    Text(
                                      "Responsavel: " + (managerData is Map ? managerData["login_email"] as String? ?? "-" : "-") + (notes != null && notes.isNotEmpty ? "  -  " + notes : ""),
                                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(border: Border.all(color: color), borderRadius: BorderRadius.circular(8)),
                                child: Text(_scheduleStatusLabel(item["status"] as String), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
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

class _AwardRefRow {
  String? awardId;
  final TextEditingController labelController;
  _AwardRefRow({this.awardId, String label = ""}) : labelController = TextEditingController(text: label);
}

class _ScheduleFormDialog extends StatefulWidget {
  final String eventId;
  final Map<String, dynamic>? existing;
  const _ScheduleFormDialog({required this.eventId, this.existing});

  @override
  State<_ScheduleFormDialog> createState() => _ScheduleFormDialogState();
}

class _ScheduleFormDialogState extends State<_ScheduleFormDialog> {
  final _calendarService = CalendarService();
  late final _descriptionController = TextEditingController(text: widget.existing?["description"] as String? ?? "");
  late final _notesController = TextEditingController(text: widget.existing?["notes"] as String? ?? "");
  late DateTime _startAt = widget.existing?["start_at"] != null ? DateTime.parse(widget.existing!["start_at"] as String).toLocal() : DateTime.now();
  late DateTime? _endAt = widget.existing?["end_at"] != null ? DateTime.parse(widget.existing!["end_at"] as String).toLocal() : null;
  late String _status = widget.existing?["status"] as String? ?? "pendente";
  late String? _responsibleId = widget.existing?["responsible_manager_id"] as String?;
  late String? _categoryId = widget.existing?["category_id"] as String?;
  late bool _showInAgencyCalendar = widget.existing?["show_in_agency_calendar"] as bool? ?? false;
  late List<Map<String, dynamic>> _selectedStreamers = _initialStreamers();
  late List<_AwardRefRow> _awardRows = _initialAwardRows();

  List<Map<String, dynamic>> _availableAwards = [];
  List<Map<String, dynamic>> _managers = [];
  List<EventCategory> _categories = [];
  bool _saving = false;
  String? _errorMessage;

  List<Map<String, dynamic>> _initialStreamers() {
    final links = widget.existing?["links"] as List?;
    if (links == null) return [];
    return links.map((l) => Map<String, dynamic>.from((l as Map)["streamer"] as Map)).toList();
  }

  List<_AwardRefRow> _initialAwardRows() {
    final raw = widget.existing?["awards"] as List?;
    if (raw != null && raw.isNotEmpty) {
      return raw.cast<Map<String, dynamic>>().map((a) => _AwardRefRow(awardId: a["award_id"] as String?, label: (a["label"] as String?) ?? "")).toList();
    }
    return [_AwardRefRow()];
  }

  @override
  void initState() {
    super.initState();
    _loadManagers();
    _loadCategories();
    _loadEventAwards();
  }

  Future<void> _loadManagers() async {
    final client = Supabase.instance.client;
    final rows = await client.from("managers").select("id, login_email").order("login_email");
    if (mounted) setState(() => _managers = (rows as List).cast<Map<String, dynamic>>());
  }

  Future<void> _loadCategories() async {
    await _calendarService.seedDefaultCategories();
    final categories = await _calendarService.fetchCategories(onlyActive: true);
    if (mounted) setState(() => _categories = categories);
  }

  Future<void> _loadEventAwards() async {
    final client = Supabase.instance.client;
    final rows = await client.from("event_awards").select("id, name").eq("event_id", widget.eventId).order("created_at");
    if (mounted) setState(() => _availableAwards = (rows as List).cast<Map<String, dynamic>>());
  }

  Future<void> _pickStreamers() async {
    final selected = await showDialog<List<Map<String, dynamic>>>(context: context, builder: (context) => const StreamerPickerDialog());
    if (selected == null) return;
    setState(() {
      for (final s in selected) {
        if (!_selectedStreamers.any((e) => e["id"] == s["id"])) _selectedStreamers.add(s);
      }
    });
  }

  Future<void> _pickStartAt() async {
    final date = await showDatePicker(context: context, initialDate: _startAt, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay(hour: _startAt.hour, minute: _startAt.minute));
    if (!mounted) return;
    setState(() => _startAt = DateTime(date.year, date.month, date.day, time?.hour ?? _startAt.hour, time?.minute ?? _startAt.minute));
  }

  Future<void> _pickEndAt() async {
    final base = _endAt ?? _startAt;
    final date = await showDatePicker(context: context, initialDate: base, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay(hour: base.hour, minute: base.minute));
    if (!mounted) return;
    setState(() => _endAt = DateTime(date.year, date.month, date.day, time?.hour ?? base.hour, time?.minute ?? base.minute));
  }

  /// Espelha a atividade como um evento real do modulo Calendario
  /// (calendar_events), pra reaproveitar Agenda da Agencia / Agenda dos
  /// Streamers em vez de duplicar um sistema paralelo. Sem streamer
  /// vinculado e sem o toggle "mostrar no calendario da agencia" marcado,
  /// nao ha nada relevante pra mostrar em nenhum calendario -- remove o
  /// espelho, se existir.
  Future<void> _syncCalendarMirror({required String scheduleId, required String? existingCalendarEventId}) async {
    final client = Supabase.instance.client;
    if (!_showInAgencyCalendar && _selectedStreamers.isEmpty) {
      if (existingCalendarEventId != null) {
        await _calendarService.deleteEvent(existingCalendarEventId);
        await client.from("event_schedule").update({"calendar_event_id": null}).eq("id", scheduleId);
      }
      return;
    }

    final eventDate = DateTime(_startAt.year, _startAt.month, _startAt.day);
    final startTimeSql = timeOfDayToSql(TimeOfDay(hour: _startAt.hour, minute: _startAt.minute));
    String? endTimeSql;
    if (_endAt != null && _endAt!.year == _startAt.year && _endAt!.month == _startAt.month && _endAt!.day == _startAt.day) {
      endTimeSql = timeOfDayToSql(TimeOfDay(hour: _endAt!.hour, minute: _endAt!.minute));
    }
    final scope = _showInAgencyCalendar ? "agencia" : "streamer";
    final participants = _selectedStreamers.map((s) => EventParticipant(participantType: "streamer", streamerId: s["id"] as String)).toList();
    final notes = _notesController.text.trim().isEmpty ? null : _notesController.text.trim();
    final title = _descriptionController.text.trim();
    final calendarStatus = _toCalendarStatus(_status);

    if (existingCalendarEventId != null) {
      await _calendarService.updateEvent(
        id: existingCalendarEventId,
        categoryId: _categoryId!,
        title: title,
        eventDate: eventDate,
        startTime: startTimeSql,
        endTime: endTimeSql,
        allDay: false,
        notes: notes,
        priority: "normal",
        status: calendarStatus,
        scope: scope,
        visibility: "equipe",
        participants: participants,
      );
    } else {
      final newId = await _calendarService.createEvent(
        categoryId: _categoryId!,
        title: title,
        eventDate: eventDate,
        startTime: startTimeSql,
        endTime: endTimeSql,
        allDay: false,
        notes: notes,
        priority: "normal",
        status: calendarStatus,
        scope: scope,
        visibility: "equipe",
        participants: participants,
      );
      await client.from("event_schedule").update({"calendar_event_id": newId}).eq("id", scheduleId);
    }
  }

  Future<void> _save() async {
    if (_descriptionController.text.trim().isEmpty || _categoryId == null) {
      setState(() => _errorMessage = "Preencha o titulo e o tipo de evento.");
      return;
    }
    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser!.id;

      final awardsData = _awardRows
          .where((r) => r.labelController.text.trim().isNotEmpty)
          .map((r) => {"award_id": r.awardId, "label": r.labelController.text.trim()})
          .toList();

      final data = {
        "event_id": widget.eventId,
        "start_at": _startAt.toUtc().toIso8601String(),
        "end_at": _endAt?.toUtc().toIso8601String(),
        "description": _descriptionController.text.trim(),
        "responsible_manager_id": _responsibleId,
        "status": _status,
        "notes": _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        "category_id": _categoryId,
        "awards": awardsData,
        "show_in_agency_calendar": _showInAgencyCalendar,
      };

      String scheduleId;
      final existingCalendarEventId = widget.existing?["calendar_event_id"] as String?;
      if (widget.existing != null) {
        scheduleId = widget.existing!["id"] as String;
        await client.from("event_schedule").update(data).eq("id", scheduleId);
        await logEventHistory(eventId: widget.eventId, action: "cronograma_atualizado", detail: _descriptionController.text.trim());
      } else {
        final inserted = await client.from("event_schedule").insert({...data, "created_by": userId}).select("id").single();
        scheduleId = inserted["id"] as String;
        await logEventHistory(eventId: widget.eventId, action: "cronograma_adicionado", detail: _descriptionController.text.trim());
      }

      await client.from("event_schedule_streamers").delete().eq("schedule_id", scheduleId);
      if (_selectedStreamers.isNotEmpty) {
        await client.from("event_schedule_streamers").insert(_selectedStreamers.map((s) => {"schedule_id": scheduleId, "streamer_id": s["id"]}).toList());
      }

      await _syncCalendarMirror(scheduleId: scheduleId, existingCalendarEventId: existingCalendarEventId);

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) showEventosActionError(context, e);
    }
  }

  Future<void> _delete() async {
    final client = Supabase.instance.client;
    try {
      final calendarEventId = widget.existing!["calendar_event_id"] as String?;
      if (calendarEventId != null) await _calendarService.deleteEvent(calendarEventId);
      await client.from("event_schedule").delete().eq("id", widget.existing!["id"]);
      await logEventHistory(eventId: widget.eventId, action: "cronograma_removido", detail: _descriptionController.text.trim());
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showEventosActionError(context, e);
    }
  }

  Widget _awardRowWidget(int index) {
    final row = _awardRows[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<String?>(
              value: row.awardId,
              isExpanded: true,
              dropdownColor: const Color(0xFF232323),
              decoration: const InputDecoration(labelText: "Cadastrada (opcional)", labelStyle: TextStyle(color: Colors.white54, fontSize: 11), isDense: true),
              style: const TextStyle(color: Colors.white, fontSize: 12),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text("Escrever manualmente")),
                ..._availableAwards.map((a) => DropdownMenuItem<String?>(value: a["id"] as String, child: Text(a["name"] as String, overflow: TextOverflow.ellipsis))),
              ],
              onChanged: (v) => setState(() {
                row.awardId = v;
                if (v != null) {
                  final award = _availableAwards.firstWhere((a) => a["id"] == v);
                  row.labelController.text = award["name"] as String;
                }
              }),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 2,
            child: TextField(controller: row.labelController, style: const TextStyle(color: Colors.white, fontSize: 13), decoration: const InputDecoration(labelText: "Premiacao", labelStyle: TextStyle(color: Colors.white54, fontSize: 11), isDense: true)),
          ),
          if (_awardRows.length > 1)
            IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 18), onPressed: () => setState(() => _awardRows.removeAt(index)), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.existing != null ? "Editar atividade" : "Nova atividade", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(controller: _descriptionController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Titulo", labelStyle: TextStyle(color: Colors.white54))),
                      const SizedBox(height: 10),
                      const Text("Streamer(s) vinculado(s)", style: TextStyle(color: Colors.white54, fontSize: 12)),
                      const SizedBox(height: 4),
                      if (_selectedStreamers.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _selectedStreamers.map((s) {
                              final avatarUrl = s["avatar_url"] as String?;
                              return Chip(
                                avatar: CircleAvatar(radius: 10, backgroundColor: Colors.white24, backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null, child: avatarUrl == null ? const Icon(Icons.person, size: 11, color: Colors.white54) : null),
                                label: Text((s["display_name"] as String?) ?? "-", style: const TextStyle(fontSize: 12, color: Colors.white)),
                                backgroundColor: Colors.white.withOpacity(0.08),
                                deleteIconColor: Colors.white54,
                                onDeleted: () => setState(() => _selectedStreamers.removeWhere((e) => e["id"] == s["id"])),
                              );
                            }).toList(),
                          ),
                        ),
                      OutlinedButton.icon(onPressed: _pickStreamers, icon: const Icon(Icons.person_add_alt, size: 14), label: const Text("Vincular streamer(s)")),
                      const SizedBox(height: 12),
                      const Text("Tipo de evento", style: TextStyle(color: Colors.white54, fontSize: 12)),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        value: _categoryId,
                        isExpanded: true,
                        hint: const Text("Selecione", style: TextStyle(color: Colors.white38)),
                        dropdownColor: const Color(0xFF232323),
                        decoration: const InputDecoration(isDense: true),
                        style: const TextStyle(color: Colors.white),
                        items: _categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                        onChanged: (v) => setState(() => _categoryId = v),
                      ),
                      const SizedBox(height: 12),
                      const Text("Premiacao(oes)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      ...List.generate(_awardRows.length, _awardRowWidget),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => setState(() => _awardRows.add(_AwardRefRow())),
                          icon: const Icon(Icons.add, size: 16, color: Color(0xFF7A0BD4)),
                          label: const Text("Adicionar premiacao", style: TextStyle(color: Color(0xFF7A0BD4))),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(child: OutlinedButton.icon(onPressed: _pickStartAt, icon: const Icon(Icons.play_circle_outline, size: 14), label: Text("Inicio: " + _fmtDateTime(_startAt), style: const TextStyle(fontSize: 12)))),
                      ]),
                      const SizedBox(height: 6),
                      Row(children: [
                        Expanded(child: OutlinedButton.icon(onPressed: _pickEndAt, icon: const Icon(Icons.stop_circle_outlined, size: 14), label: Text(_endAt != null ? "Fim: " + _fmtDateTime(_endAt!) : "Fim (opcional)", style: const TextStyle(fontSize: 12)))),
                        if (_endAt != null) IconButton(icon: const Icon(Icons.clear, size: 16, color: Colors.white38), onPressed: () => setState(() => _endAt = null)),
                      ]),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        value: _showInAgencyCalendar,
                        onChanged: (v) => setState(() => _showInAgencyCalendar = v),
                        activeColor: const Color(0xFF7A0BD4),
                        contentPadding: EdgeInsets.zero,
                        title: const Text("Mostrar no calendario geral da agencia", style: TextStyle(color: Colors.white, fontSize: 13)),
                        subtitle: const Text("Se vinculada a um streamer, a atividade ja aparece na Agenda dos Streamers mesmo sem marcar aqui.", style: TextStyle(color: Colors.white38, fontSize: 11)),
                      ),
                      const SizedBox(height: 4),
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
                      if (_errorMessage != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 12))),
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
