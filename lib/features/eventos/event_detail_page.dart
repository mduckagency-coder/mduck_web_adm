import "package:file_picker/file_picker.dart";
import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "../calendario/calendar_colors.dart";
import "../calendario/widgets/manager_picker_dialog.dart";
import "event_cronograma_tab.dart";
import "event_tarefas_tab.dart";
import "event_participantes_tab.dart";
import "event_premiacoes_tab.dart";
import "event_financeiro_tab.dart";
import "event_arquivos_tab.dart";
import "event_anotacoes_tab.dart";
import "event_historico_tab.dart";
import "event_history_service.dart";
import "event_upload_helpers.dart";
import "eventos_page.dart" show eventStatusColor;

class EventDetailPage extends StatefulWidget {
  final String eventId;
  const EventDetailPage({super.key, required this.eventId});

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final client = Supabase.instance.client;
    final event = await client.from("agency_events").select("*, event_types(name, color)").eq("id", widget.eventId).single();

    final responsibleId = event["responsible_manager_id"] as String?;
    if (responsibleId != null) {
      final manager = await client.from("managers").select("login_email").eq("id", responsibleId).maybeSingle();
      event["managers"] = manager != null ? {"login_email": manager["login_email"]} : null;
    } else {
      event["managers"] = null;
    }

    final participants = await client.from("event_participants").select("id").eq("event_id", widget.eventId);
    return {"event": event, "participantCount": (participants as List).length};
  }

  void _reload() => setState(() { _future = _load(); });

  Future<void> _changeStatus(String newStatus, String oldStatus) async {
    if (newStatus == oldStatus) return;
    final client = Supabase.instance.client;
    try {
      await client.from("agency_events").update({"status": newStatus, "updated_at": DateTime.now().toIso8601String()}).eq("id", widget.eventId);
      await logEventHistory(eventId: widget.eventId, action: "mudanca_status", detail: eventStatusLabel(oldStatus) + " → " + eventStatusLabel(newStatus));
      _reload();
    } catch (e) {
      if (mounted) showEventosActionError(context, e);
    }
  }

  void _openEdit(Map<String, dynamic> event) {
    showDialog(context: context, builder: (context) => _EventEditDialog(event: event)).then((changed) {
      if (changed == true) _reload();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text("Evento"),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).pop()),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text("Erro ao carregar: " + snapshot.error.toString(), style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center),
              ),
            );
          }
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final event = snapshot.data!["event"] as Map<String, dynamic>;
          final participantCount = snapshot.data!["participantCount"] as int;
          final typeData = event["event_types"];
          final managerData = event["managers"];
          final status = event["status"] as String;
          final start = DateTime.parse(event["start_date"] as String);
          final end = DateTime.parse(event["end_date"] as String);
          final now = DateTime.now();
          final totalDays = end.difference(start).inHours;
          final elapsed = now.difference(start).inHours;
          final progress = totalDays <= 0 ? (now.isBefore(start) ? 0.0 : 1.0) : (elapsed / totalDays).clamp(0.0, 1.0);
          final daysRemaining = end.difference(DateTime(now.year, now.month, now.day)).inDays;
          final bannerUrl = event["banner_url"] as String?;

          return DefaultTabController(
            length: 9,
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  color: const Color(0xFF1A1A1A),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: SizedBox(
                                    width: 56,
                                    height: 56,
                                    child: bannerUrl != null && bannerUrl.isNotEmpty
                                        ? Image.network(bannerUrl, fit: BoxFit.cover, errorBuilder: (context, error, stack) => Container(color: const Color(0xFF232323), child: const Icon(Icons.event, color: Colors.white24, size: 22)))
                                        : Container(color: const Color(0xFF232323), child: const Icon(Icons.event, color: Colors.white24, size: 22)),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(children: [
                                        Expanded(child: Text(event["title"] as String, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold))),
                                        IconButton(icon: const Icon(Icons.edit, color: Colors.white54, size: 20), onPressed: () => _openEdit(event)),
                                        DropdownButton<String>(
                                          value: status,
                                          dropdownColor: const Color(0xFF232323),
                                          underline: const SizedBox.shrink(),
                                          style: TextStyle(color: eventStatusColor(status), fontWeight: FontWeight.bold, fontSize: 13),
                                          items: eventStatusOptions.map((s) => DropdownMenuItem(value: s, child: Text(eventStatusLabel(s)))).toList(),
                                          onChanged: (v) => v != null ? _changeStatus(v, status) : null,
                                        ),
                                      ]),
                                      if ((event["description"] as String?)?.isNotEmpty == true)
                                        Padding(padding: const EdgeInsets.only(top: 4), child: Text(event["description"] as String, style: const TextStyle(color: Colors.white70, fontSize: 13))),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(spacing: 20, runSpacing: 8, children: [
                              if (typeData is Map) _metaChip(Icons.category_outlined, typeData["name"] as String),
                              _metaChip(Icons.person_outline, managerData is Map ? (managerData["login_email"] as String? ?? "Sem responsavel") : "Sem responsavel"),
                              _metaChip(Icons.date_range, start.toLocal().toString().substring(0, 10) + " a " + end.toLocal().toString().substring(0, 10)),
                              _metaChip(Icons.people_outline, participantCount.toString() + " participantes"),
                              _metaChip(Icons.hourglass_bottom, daysRemaining > 0 ? daysRemaining.toString() + " dias restantes" : "Periodo encerrado"),
                            ]),
                            const SizedBox(height: 10),
                            Row(children: [
                              const Text("Progresso: ", style: TextStyle(color: Colors.white54, fontSize: 12)),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(value: progress, minHeight: 6, backgroundColor: Colors.white12, valueColor: const AlwaysStoppedAnimation(Color(0xFF7A0BD4))),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text((progress * 100).toStringAsFixed(0) + "%", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            ]),
                          ],
                        ),
                      ),
                      const TabBar(
                        isScrollable: true,
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.white54,
                        indicatorColor: Color(0xFF7A0BD4),
                        tabs: [
                          Tab(text: "Visao Geral"),
                          Tab(text: "Cronograma"),
                          Tab(text: "Tarefas"),
                          Tab(text: "Participantes"),
                          Tab(text: "Premiacoes"),
                          Tab(text: "Financeiro"),
                          Tab(text: "Arquivos"),
                          Tab(text: "Anotacoes"),
                          Tab(text: "Historico"),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(children: [
                    _VisaoGeralTab(eventId: widget.eventId, event: event, participantCount: participantCount),
                    EventCronogramaTab(eventId: widget.eventId),
                    EventTarefasTab(eventId: widget.eventId),
                    EventParticipantesTab(eventId: widget.eventId),
                    EventPremiacoesTab(eventId: widget.eventId),
                    EventFinanceiroTab(eventId: widget.eventId),
                    EventArquivosTab(eventId: widget.eventId),
                    EventAnotacoesTab(eventId: widget.eventId),
                    EventHistoricoTab(eventId: widget.eventId),
                  ]),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _metaChip(IconData icon, String text) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: Colors.white54),
      const SizedBox(width: 4),
      Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12)),
    ]);
  }
}

/// Alem do resumo, mostra os colaboradores (gestores) que estao
/// participando da organizacao do evento e o que cada um precisa fazer --
/// puxado das tarefas atribuidas a eles na aba Tarefas. Colaboradores
/// ficaram so aqui (a aba Participantes agora e so de streamers) porque a
/// lista completa dos dois tipos misturados tomava espaco e confundia.
class _VisaoGeralTab extends StatefulWidget {
  final String eventId;
  final Map<String, dynamic> event;
  final int participantCount;
  const _VisaoGeralTab({required this.eventId, required this.event, required this.participantCount});

  @override
  State<_VisaoGeralTab> createState() => _VisaoGeralTabState();
}

class _VisaoGeralTabState extends State<_VisaoGeralTab> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final client = Supabase.instance.client;
    final participants = await client
        .from("event_participants")
        .select("id, role_label, manager:managers(id, login_email, photo_url)")
        .eq("event_id", widget.eventId)
        .eq("participant_type", "gestor")
        .order("created_at");
    final collaborators = (participants as List).cast<Map<String, dynamic>>();

    final tasks = await client.from("event_tasks").select("id, title, status, responsible_manager_id").eq("event_id", widget.eventId);
    final tasksByManager = <String, List<Map<String, dynamic>>>{};
    for (final t in (tasks as List)) {
      final managerId = t["responsible_manager_id"] as String?;
      if (managerId != null) tasksByManager.putIfAbsent(managerId, () => []).add(t as Map<String, dynamic>);
    }

    return {"collaborators": collaborators, "tasksByManager": tasksByManager};
  }

  void _reload() => setState(() { _future = _load(); });

  Future<void> _addCollaborators() async {
    final selected = await showDialog<List<Map<String, dynamic>>>(context: context, builder: (context) => const ManagerPickerDialog());
    if (selected == null || selected.isEmpty) return;
    final client = Supabase.instance.client;
    try {
      for (final m in selected) {
        await client.from("event_participants").insert({
          "event_id": widget.eventId,
          "participant_type": "gestor",
          "manager_id": m["id"],
        });
        await logEventHistory(eventId: widget.eventId, action: "participante_adicionado", detail: managerDisplayName(m));
      }
      _reload();
    } catch (e) {
      if (mounted) showEventosActionError(context, e);
    }
  }

  Future<void> _removeCollaborator(Map<String, dynamic> participant) async {
    final client = Supabase.instance.client;
    try {
      await client.from("event_participants").delete().eq("id", participant["id"]);
      final manager = participant["manager"];
      await logEventHistory(eventId: widget.eventId, action: "participante_removido", detail: manager is Map ? managerDisplayName(manager as Map<String, dynamic>) : "-");
      _reload();
    } catch (e) {
      if (mounted) showEventosActionError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            SizedBox(width: 160, child: Text(label, style: const TextStyle(color: Colors.white54))),
            Expanded(child: Text(value, style: const TextStyle(color: Colors.white))),
          ]),
        );

    final createdAt = widget.event["created_at"] != null ? DateTime.parse(widget.event["created_at"] as String).toLocal().toString().substring(0, 16) : "-";

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Resumo do evento", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          row("Nome", widget.event["title"] as String),
          row("Descricao", (widget.event["description"] as String?)?.isNotEmpty == true ? widget.event["description"] as String : "-"),
          row("Status", eventStatusLabel(widget.event["status"] as String)),
          row("Participantes", widget.participantCount.toString()),
          row("Criado em", createdAt),
          const SizedBox(height: 24),
          Row(children: [
            const Text("Colaboradores", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const Spacer(),
            OutlinedButton.icon(onPressed: _addCollaborators, icon: const Icon(Icons.person_add, size: 16), label: const Text("Adicionar")),
          ]),
          const SizedBox(height: 4),
          const Text("Quem esta na organizacao deste evento e o que precisa fazer (tarefas atribuidas na aba Tarefas).", style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic)),
          const SizedBox(height: 12),
          FutureBuilder<Map<String, dynamic>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.hasError) return buildEventosLoadError(snapshot.error!);
              if (!snapshot.hasData) return const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 24), child: CircularProgressIndicator()));
              final collaborators = snapshot.data!["collaborators"] as List<Map<String, dynamic>>;
              final tasksByManager = snapshot.data!["tasksByManager"] as Map<String, List<Map<String, dynamic>>>;
              if (collaborators.isEmpty) return const Text("Nenhum colaborador adicionado ainda.", style: TextStyle(color: Colors.white54));
              return Column(
                children: collaborators.map((p) {
                  final manager = p["manager"];
                  final managerId = manager is Map ? manager["id"] as String? : null;
                  final name = manager is Map ? managerDisplayName(manager as Map<String, dynamic>) : "-";
                  final photoUrl = manager is Map ? manager["photo_url"] as String? : null;
                  final tasks = managerId != null ? (tasksByManager[managerId] ?? const []) : const <Map<String, dynamic>>[];
                  return Card(
                    color: Colors.white.withOpacity(0.05),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.white24,
                              backgroundImage: photoUrl != null && photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                              child: photoUrl == null || photoUrl.isEmpty ? const Icon(Icons.person, color: Colors.white70, size: 16) : null,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  if ((p["role_label"] as String?)?.isNotEmpty == true) Text(p["role_label"] as String, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                ],
                              ),
                            ),
                            IconButton(icon: const Icon(Icons.close, color: Colors.white38, size: 18), onPressed: () => _removeCollaborator(p)),
                          ]),
                          const SizedBox(height: 8),
                          if (tasks.isEmpty)
                            const Text("Nenhuma tarefa atribuida.", style: TextStyle(color: Colors.white38, fontSize: 12))
                          else
                            ...tasks.map((t) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(children: [
                                    Icon(Icons.circle, size: 6, color: eventTaskStatusColor(t["status"] as String)),
                                    const SizedBox(width: 6),
                                    Expanded(child: Text(t["title"] as String, style: const TextStyle(color: Colors.white70, fontSize: 12))),
                                    Text(eventTaskStatusLabel(t["status"] as String), style: TextStyle(color: eventTaskStatusColor(t["status"] as String), fontSize: 11, fontWeight: FontWeight.bold)),
                                  ]),
                                )),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _EventEditDialog extends StatefulWidget {
  final Map<String, dynamic> event;
  const _EventEditDialog({required this.event});

  @override
  State<_EventEditDialog> createState() => _EventEditDialogState();
}

class _EventEditDialogState extends State<_EventEditDialog> {
  late final _titleController = TextEditingController(text: widget.event["title"] as String);
  late final _descriptionController = TextEditingController(text: widget.event["description"] as String? ?? "");
  late DateTime _startDate = DateTime.parse(widget.event["start_date"] as String);
  late DateTime _endDate = DateTime.parse(widget.event["end_date"] as String);
  List<Map<String, dynamic>> _managers = [];
  List<Map<String, dynamic>> _types = [];
  String? _responsibleId;
  String? _typeId;
  PlatformFile? _bannerFile;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _responsibleId = widget.event["responsible_manager_id"] as String?;
    _typeId = widget.event["type_id"] as String?;
    _load();
  }

  Future<void> _load() async {
    final client = Supabase.instance.client;
    final managers = await client.from("managers").select("id, login_email").order("login_email");
    final types = await client.from("event_types").select().eq("is_active", true).order("order_index");
    setState(() {
      _managers = (managers as List).cast<Map<String, dynamic>>();
      _types = (types as List).cast<Map<String, dynamic>>();
    });
  }

  Future<void> _pickBanner() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result != null && result.files.isNotEmpty && result.files.first.bytes != null) {
      setState(() => _bannerFile = result.files.first);
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(context: context, initialDate: isStart ? _startDate : _endDate, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (picked != null) setState(() => isStart ? _startDate = picked : _endDate = picked);
  }

  String _dateOnly(DateTime date) => date.year.toString().padLeft(4, "0") + "-" + date.month.toString().padLeft(2, "0") + "-" + date.day.toString().padLeft(2, "0");

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final client = Supabase.instance.client;
      final eventId = widget.event["id"] as String;
      String? bannerUrl = widget.event["banner_url"] as String?;
      if (_bannerFile != null) {
        bannerUrl = await uploadEventFile(bucket: "event_banners", prefix: eventId, file: _bannerFile!);
      }

      await client.from("agency_events").update({
        "title": _titleController.text.trim(),
        "description": _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        "type_id": _typeId,
        "responsible_manager_id": _responsibleId,
        "start_date": _dateOnly(_startDate),
        "end_date": _dateOnly(_endDate),
        "banner_url": bannerUrl,
        "updated_at": DateTime.now().toIso8601String(),
      }).eq("id", eventId);

      await logEventHistory(eventId: eventId, action: "edicao", detail: "Dados do evento atualizados");

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao salvar: " + e.toString())));
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
              const Text("Editar Evento", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _pickBanner,
                        icon: const Icon(Icons.image_outlined, size: 16),
                        label: Text(_bannerFile != null ? "Novo banner: " + _bannerFile!.name : "Trocar banner"),
                      ),
                      const SizedBox(height: 12),
                      TextField(controller: _titleController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Nome do evento", labelStyle: TextStyle(color: Colors.white54))),
                      const SizedBox(height: 8),
                      TextField(controller: _descriptionController, maxLines: 3, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Descricao", labelStyle: TextStyle(color: Colors.white54))),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String?>(
                        value: _typeId,
                        dropdownColor: const Color(0xFF232323),
                        decoration: const InputDecoration(labelText: "Tipo de evento", labelStyle: TextStyle(color: Colors.white54)),
                        style: const TextStyle(color: Colors.white),
                        items: _types.map((t) => DropdownMenuItem<String?>(value: t["id"] as String, child: Text(t["name"] as String))).toList(),
                        onChanged: (v) => setState(() => _typeId = v),
                      ),
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
                        Expanded(child: OutlinedButton.icon(onPressed: () => _pickDate(true), icon: const Icon(Icons.calendar_today, size: 14), label: Text(_dateOnly(_startDate)))),
                        const SizedBox(width: 8),
                        Expanded(child: OutlinedButton.icon(onPressed: () => _pickDate(false), icon: const Icon(Icons.calendar_today, size: 14), label: Text(_dateOnly(_endDate)))),
                      ]),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
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
    );
  }
}
