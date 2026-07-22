import "package:file_picker/file_picker.dart";
import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "event_cronograma_tab.dart";
import "event_tarefas_tab.dart";
import "event_participantes_tab.dart";
import "event_premiacoes_tab.dart";
import "event_financeiro_tab.dart";
import "event_arquivos_tab.dart";
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

  void _reload() => setState(() => _future = _load());

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
            length: 8,
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  color: const Color(0xFF1A1A1A),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (bannerUrl != null && bannerUrl.isNotEmpty)
                        SizedBox(
                          height: 160,
                          width: double.infinity,
                          child: Image.network(bannerUrl, fit: BoxFit.cover, errorBuilder: (context, error, stack) => Container(color: const Color(0xFF232323))),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
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
                          Tab(text: "Historico"),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(children: [
                    _VisaoGeralTab(event: event, participantCount: participantCount),
                    EventCronogramaTab(eventId: widget.eventId),
                    EventTarefasTab(eventId: widget.eventId),
                    EventParticipantesTab(eventId: widget.eventId),
                    EventPremiacoesTab(eventId: widget.eventId),
                    EventFinanceiroTab(eventId: widget.eventId),
                    EventArquivosTab(eventId: widget.eventId),
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

class _VisaoGeralTab extends StatelessWidget {
  final Map<String, dynamic> event;
  final int participantCount;
  const _VisaoGeralTab({required this.event, required this.participantCount});

  @override
  Widget build(BuildContext context) {
    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            SizedBox(width: 160, child: Text(label, style: const TextStyle(color: Colors.white54))),
            Expanded(child: Text(value, style: const TextStyle(color: Colors.white))),
          ]),
        );

    final createdAt = event["created_at"] != null ? DateTime.parse(event["created_at"] as String).toLocal().toString().substring(0, 16) : "-";

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Resumo do evento", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          row("Nome", event["title"] as String),
          row("Descricao", (event["description"] as String?)?.isNotEmpty == true ? event["description"] as String : "-"),
          row("Status", eventStatusLabel(event["status"] as String)),
          row("Participantes", participantCount.toString()),
          row("Criado em", createdAt),
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
