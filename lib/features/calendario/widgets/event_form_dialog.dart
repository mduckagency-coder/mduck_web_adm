import "package:flutter/material.dart";
import "../calendar_colors.dart";
import "../calendar_notifications.dart";
import "../models/calendar_event.dart";
import "../models/event_category.dart";
import "../models/event_participant.dart";
import "../services/calendar_service.dart";
import "category_manager_dialog.dart";
import "manager_picker_dialog.dart";
import "participant_avatar.dart";
import "streamer_picker_dialog.dart";

/// Retorna true quando o evento foi salvo (criado/editado) ou excluido,
/// para a tela chamadora recarregar a lista.
class EventFormDialog extends StatefulWidget {
  final CalendarEvent? existing;
  final DateTime? initialDate;

  /// Escopo pre-selecionado para um evento novo (ex: "streamer" quando aberto
  /// a partir da Agenda dos Streamers). Ignorado ao editar um evento existente.
  final String initialScope;

  /// Quando true, ao criar um evento novo dispara notificacao para
  /// dono/coordenadores (usado nas areas de Gestor e Recrutador).
  final bool notifyOnCreate;

  const EventFormDialog({super.key, this.existing, this.initialDate, this.initialScope = "agencia", this.notifyOnCreate = false});

  @override
  State<EventFormDialog> createState() => _EventFormDialogState();
}

class _EventFormDialogState extends State<EventFormDialog> {
  final _service = CalendarService();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _meetingLinkController = TextEditingController();
  final _notesController = TextEditingController();

  List<EventCategory> _categories = [];
  String? _categoryId;
  DateTime _eventDate = DateTime.now();
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _allDay = false;
  String _priority = "normal";
  String _status = "agendado";
  String _scope = "agencia";
  String _visibility = "equipe";
  List<EventParticipant> _participants = [];

  bool _loadingCategories = true;
  bool _saving = false;

  List<EventCategory> get _categoriesForScope => _categories.where((c) => c.matchesScope(_scope)).toList();

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _titleController.text = e.title;
      _descriptionController.text = e.description ?? "";
      _locationController.text = e.location ?? "";
      _meetingLinkController.text = e.meetingLink ?? "";
      _notesController.text = e.notes ?? "";
      _categoryId = e.categoryId;
      _eventDate = e.eventDate;
      _startTime = e.startTime;
      _endTime = e.endTime;
      _allDay = e.allDay;
      _priority = e.priority;
      _status = e.status;
      _scope = e.scope;
      _visibility = e.visibility;
      _participants = List.of(e.participants);
    } else {
      _scope = widget.initialScope;
      if (widget.initialDate != null) _eventDate = widget.initialDate!;
    }
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _loadingCategories = true);
    await _service.seedDefaultCategories();
    final categories = await _service.fetchCategories(onlyActive: true);
    if (mounted) {
      setState(() {
        _categories = categories;
        final available = _categoriesForScope;
        if (_categoryId == null || !available.any((c) => c.id == _categoryId)) {
          _categoryId = available.isNotEmpty ? available.first.id : null;
        }
        _loadingCategories = false;
      });
    }
  }

  Future<void> _manageCategories() async {
    await showDialog(context: context, builder: (_) => const CategoryManagerDialog());
    _loadCategories();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _eventDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _eventDate = picked);
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(context: context, initialTime: (isStart ? _startTime : _endTime) ?? TimeOfDay.now());
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<String?> _promptRoleLabel(String defaultText) async {
    final controller = TextEditingController(text: defaultText);
    return showDialog<String>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF1A1A1A),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Funcao neste evento", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(controller: controller, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Ex: Streamer, Gestor Responsavel", labelStyle: TextStyle(color: Colors.white54))),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancelar")),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(controller.text.trim()),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
                  child: const Text("Confirmar"),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addStreamer() async {
    final selected = await showDialog<List<Map<String, dynamic>>>(context: context, builder: (_) => const StreamerPickerDialog());
    if (selected == null || selected.isEmpty) return;
    final roleLabel = await _promptRoleLabel("Streamer");
    if (roleLabel == null) return;
    setState(() {
      for (final s in selected) {
        if (_participants.any((p) => p.isStreamer && p.streamerId == s["id"])) continue;
        _participants.add(EventParticipant(
          participantType: "streamer",
          streamerId: s["id"] as String,
          streamerName: s["display_name"] as String?,
          streamerTiktokUsername: s["tiktok_username"] as String?,
          streamerTiktokId: s["tiktok_creator_id"] as String?,
          streamerAvatarUrl: s["avatar_url"] as String?,
          roleLabel: roleLabel,
        ));
      }
    });
  }

  Future<void> _addManager() async {
    final selected = await showDialog<List<Map<String, dynamic>>>(context: context, builder: (_) => const ManagerPickerDialog());
    if (selected == null || selected.isEmpty) return;
    final roleLabel = await _promptRoleLabel("Gestor Responsavel");
    if (roleLabel == null) return;
    setState(() {
      for (final m in selected) {
        if (_participants.any((p) => p.isGestor && p.managerId == m["id"])) continue;
        _participants.add(EventParticipant(
          participantType: "gestor",
          managerId: m["id"] as String,
          managerName: managerDisplayName(m),
          managerPhotoUrl: m["photo_url"] as String?,
          roleLabel: roleLabel,
        ));
      }
    });
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty || _categoryId == null) return;
    setState(() => _saving = true);
    final startTimeSql = _allDay ? null : timeOfDayToSql(_startTime);
    final endTimeSql = _allDay ? null : timeOfDayToSql(_endTime);
    if (widget.existing != null) {
      await _service.updateEvent(
        id: widget.existing!.id,
        categoryId: _categoryId!,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        eventDate: _eventDate,
        startTime: startTimeSql,
        endTime: endTimeSql,
        allDay: _allDay,
        location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
        meetingLink: _meetingLinkController.text.trim().isEmpty ? null : _meetingLinkController.text.trim(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        priority: _priority,
        status: _status,
        scope: _scope,
        visibility: _visibility,
        participants: _participants,
      );
    } else {
      await _service.createEvent(
        categoryId: _categoryId!,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        eventDate: _eventDate,
        startTime: startTimeSql,
        endTime: endTimeSql,
        allDay: _allDay,
        location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
        meetingLink: _meetingLinkController.text.trim().isEmpty ? null : _meetingLinkController.text.trim(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        priority: _priority,
        status: _status,
        scope: _scope,
        visibility: _visibility,
        participants: _participants,
      );
      if (widget.notifyOnCreate) {
        final createdByLabel = await _service.currentManagerLabel();
        await notifyNewEventToAdmins(eventTitle: _titleController.text.trim(), createdByLabel: createdByLabel);
      }
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    await _service.deleteEvent(widget.existing!.id);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = _eventDate.day.toString().padLeft(2, "0") + "/" + _eventDate.month.toString().padLeft(2, "0") + "/" + _eventDate.year.toString();
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.existing != null ? "Editar evento" : "Novo evento", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Este evento é sobre:", style: TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 6),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: "agencia", label: Text("Agência"), icon: Icon(Icons.apartment, size: 16)),
                          ButtonSegment(value: "streamer", label: Text("Streamer"), icon: Icon(Icons.person, size: 16)),
                        ],
                        selected: {_scope},
                        onSelectionChanged: (s) => setState(() {
                          _scope = s.first;
                          if (!_categoriesForScope.any((c) => c.id == _categoryId)) {
                            _categoryId = _categoriesForScope.isNotEmpty ? _categoriesForScope.first.id : null;
                          }
                        }),
                      ),
                      const SizedBox(height: 16),
                      TextField(controller: _titleController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Titulo", labelStyle: TextStyle(color: Colors.white54))),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: _loadingCategories
                                ? const LinearProgressIndicator()
                                : DropdownButtonFormField<String>(
                                    value: _categoryId,
                                    dropdownColor: const Color(0xFF232323),
                                    decoration: const InputDecoration(labelText: "Categoria", labelStyle: TextStyle(color: Colors.white54)),
                                    style: const TextStyle(color: Colors.white),
                                    items: [
                                      ..._categoriesForScope.map((c) => DropdownMenuItem(
                                            value: c.id,
                                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                                              CircleAvatar(radius: 6, backgroundColor: hexToColor(c.color)),
                                              const SizedBox(width: 8),
                                              Text(c.name),
                                            ]),
                                          )),
                                      const DropdownMenuItem(
                                        value: "__new__",
                                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                                          Icon(Icons.add, size: 16, color: Color(0xFF7A0BD4)),
                                          SizedBox(width: 8),
                                          Text("Novo tipo..."),
                                        ]),
                                      ),
                                    ],
                                    onChanged: (v) async {
                                      if (v == "__new__") {
                                        final saved = await showDialog<bool>(context: context, builder: (_) => const CategoryFormDialog());
                                        if (saved == true) await _loadCategories();
                                        return;
                                      }
                                      setState(() => _categoryId = v);
                                    },
                                  ),
                          ),
                          IconButton(onPressed: _manageCategories, icon: const Icon(Icons.settings, color: Colors.white54, size: 20), tooltip: "Gerenciar categorias"),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(controller: _descriptionController, maxLines: 2, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Descricao", labelStyle: TextStyle(color: Colors.white54))),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickDate,
                            icon: const Icon(Icons.calendar_today, size: 16, color: Colors.white70),
                            label: Text(dateLabel, style: const TextStyle(color: Colors.white70)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          const Text("Dia inteiro", style: TextStyle(color: Colors.white70, fontSize: 12)),
                          Switch(value: _allDay, onChanged: (v) => setState(() => _allDay = v), activeThumbColor: const Color(0xFF7A0BD4)),
                        ]),
                      ]),
                      if (!_allDay) ...[
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _pickTime(true),
                              icon: const Icon(Icons.access_time, size: 16, color: Colors.white70),
                              label: Text(_startTime != null ? _startTime!.format(context) : "Horario inicial", style: const TextStyle(color: Colors.white70)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _pickTime(false),
                              icon: const Icon(Icons.access_time, size: 16, color: Colors.white70),
                              label: Text(_endTime != null ? _endTime!.format(context) : "Horario final", style: const TextStyle(color: Colors.white70)),
                            ),
                          ),
                        ]),
                      ],
                      const SizedBox(height: 12),
                      TextField(controller: _locationController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Local (opcional)", labelStyle: TextStyle(color: Colors.white54))),
                      const SizedBox(height: 12),
                      TextField(controller: _meetingLinkController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Link da reuniao (opcional)", labelStyle: TextStyle(color: Colors.white54))),
                      const SizedBox(height: 12),
                      TextField(controller: _notesController, maxLines: 2, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Observacoes", labelStyle: TextStyle(color: Colors.white54))),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _priority,
                            dropdownColor: const Color(0xFF232323),
                            decoration: const InputDecoration(labelText: "Prioridade", labelStyle: TextStyle(color: Colors.white54)),
                            style: const TextStyle(color: Colors.white),
                            items: priorityOptions.map((p) => DropdownMenuItem(value: p, child: Text(priorityLabel(p)))).toList(),
                            onChanged: (v) => setState(() => _priority = v!),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _status,
                            dropdownColor: const Color(0xFF232323),
                            decoration: const InputDecoration(labelText: "Status", labelStyle: TextStyle(color: Colors.white54)),
                            style: const TextStyle(color: Colors.white),
                            items: statusOptions.map((s) => DropdownMenuItem(value: s, child: Text(statusLabel(s)))).toList(),
                            onChanged: (v) => setState(() => _status = v!),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      const Text("Visível para", style: TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 6),
                      SegmentedButton<String>(
                        segments: visibilityOptions.map((v) => ButtonSegment(value: v, label: Text(visibilityLabel(v)))).toList(),
                        selected: {_visibility},
                        onSelectionChanged: (s) => setState(() => _visibility = s.first),
                      ),
                      const SizedBox(height: 16),
                      const Text("Participantes", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _participants.map((p) {
                          final label = p.isStreamer ? (p.streamerName ?? "Streamer") : (p.managerName ?? "Gestor");
                          return Chip(
                            backgroundColor: const Color(0xFF232323),
                            avatar: ParticipantAvatar(participant: p, radius: 12),
                            label: Text((p.roleLabel != null && p.roleLabel!.isNotEmpty ? p.roleLabel! + ": " : "") + label, style: const TextStyle(color: Colors.white, fontSize: 12)),
                            onDeleted: () => setState(() => _participants.remove(p)),
                            deleteIconColor: Colors.white54,
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                      Row(children: [
                        OutlinedButton.icon(onPressed: _addStreamer, icon: const Icon(Icons.person_add, size: 16, color: Colors.white70), label: const Text("Streamer", style: TextStyle(color: Colors.white70))),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(onPressed: _addManager, icon: const Icon(Icons.badge, size: 16, color: Colors.white70), label: const Text("Gestor", style: TextStyle(color: Colors.white70))),
                      ]),
                    ],
                  ),
                ),
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
    );
  }
}
