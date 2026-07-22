import "package:file_picker/file_picker.dart";
import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "event_detail_page.dart";
import "event_history_service.dart";
import "event_upload_helpers.dart";

Color hexToColor(String hex) {
  final cleaned = hex.replaceFirst("#", "");
  return Color(int.parse("FF" + cleaned, radix: 16));
}

Color eventStatusColor(String status) {
  switch (status) {
    case "em_andamento":
      return Colors.greenAccent;
    case "finalizado":
      return Colors.blueAccent;
    case "cancelado":
      return Colors.redAccent;
    default:
      return Colors.amber;
  }
}

class EventosPage extends StatefulWidget {
  const EventosPage({super.key});

  @override
  State<EventosPage> createState() => _EventosPageState();
}

class _EventosPageState extends State<EventosPage> {
  bool _loading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _types = [];
  String _search = "";
  String? _typeFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final client = Supabase.instance.client;

      final typesRows = await client.from("event_types").select().eq("is_active", true).order("order_index");
      final types = (typesRows as List).cast<Map<String, dynamic>>();

      final rows = await client.from("agency_events").select("*, event_types(name, color)").order("start_date", ascending: false);
      final events = (rows as List).cast<Map<String, dynamic>>();

      if (events.isNotEmpty) {
        final ids = events.map((e) => e["id"] as String).toList();
        final participantRows = await client.from("event_participants").select("event_id").inFilter("event_id", ids);
        final counts = <String, int>{};
        for (final p in (participantRows as List)) {
          final id = p["event_id"] as String;
          counts[id] = (counts[id] ?? 0) + 1;
        }

        final managerIds = events.map((e) => e["responsible_manager_id"] as String?).whereType<String>().toSet().toList();
        Map<String, String> managerEmails = {};
        if (managerIds.isNotEmpty) {
          final managerRows = await client.from("managers").select("id, login_email").inFilter("id", managerIds);
          managerEmails = {for (final m in (managerRows as List)) m["id"] as String: m["login_email"] as String};
        }

        for (final e in events) {
          e["participantCount"] = counts[e["id"]] ?? 0;
          final email = managerEmails[e["responsible_manager_id"]];
          e["managers"] = email != null ? {"login_email": email} : null;
        }
      }

      setState(() {
        _types = types;
        _events = events;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    return _events.where((e) {
      if (_search.isNotEmpty && !(e["title"] as String).toLowerCase().contains(_search.toLowerCase())) return false;
      if (_typeFilter != null && e["type_id"] != _typeFilter) return false;
      return true;
    }).toList();
  }

  void _openNew() {
    showDialog(context: context, builder: (context) => _EventFormDialog(types: _types)).then((saved) {
      if (saved == true) _load();
    });
  }

  void _openDetail(Map<String, dynamic> event) {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => EventDetailPage(eventId: event["id"] as String))).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text("Erro ao carregar: " + _errorMessage!, style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center),
        ),
      );
    }

    final filtered = _filtered;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text("Eventos", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(width: 12),
            IconButton(icon: const Icon(Icons.refresh, color: Colors.white70), onPressed: _load),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _openNew,
              icon: const Icon(Icons.add),
              label: const Text("Novo Evento"),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
            ),
          ]),
          const SizedBox(height: 4),
          const Text("Organize competicoes, campanhas, treinamentos e outros eventos da agencia em um so lugar.", style: TextStyle(color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 240,
                child: TextField(
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search, color: Colors.white54), hintText: "Buscar evento", hintStyle: TextStyle(color: Colors.white38), isDense: true),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              DropdownButton<String?>(
                value: _typeFilter,
                hint: const Text("Todos os tipos", style: TextStyle(color: Colors.white54)),
                dropdownColor: const Color(0xFF1A1A1A),
                style: const TextStyle(color: Colors.white),
                items: [const DropdownMenuItem<String?>(value: null, child: Text("Todos os tipos")), ..._types.map((t) => DropdownMenuItem<String?>(value: t["id"] as String, child: Text(t["name"] as String)))],
                onChanged: (v) => setState(() => _typeFilter = v),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(filtered.length.toString() + " eventos", style: const TextStyle(color: Colors.white54)),
          const SizedBox(height: 8),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text("Nenhum evento encontrado.", style: TextStyle(color: Colors.white54)))
                : SingleChildScrollView(
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: filtered.map((e) => _EventCard(event: e, onTap: () => _openDetail(e))).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  final VoidCallback onTap;
  const _EventCard({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusColor = eventStatusColor(event["status"] as String);
    final typeData = event["type_id"] != null ? event["event_types"] : null;
    final managerData = event["managers"];
    final bannerUrl = event["banner_url"] as String?;
    final start = DateTime.parse(event["start_date"] as String);
    final end = DateTime.parse(event["end_date"] as String);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 300,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 110,
              width: double.infinity,
              color: const Color(0xFF232323),
              child: bannerUrl != null && bannerUrl.isNotEmpty
                  ? Image.network(bannerUrl, fit: BoxFit.cover, errorBuilder: (context, error, stack) => const Icon(Icons.event, color: Colors.white24, size: 36))
                  : const Center(child: Icon(Icons.event, color: Colors.white24, size: 36)),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: Text(event["title"] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15), overflow: TextOverflow.ellipsis)),
                  ]),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: statusColor)),
                      child: Text(eventStatusLabel(event["status"] as String), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    if (typeData is Map)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: hexToColor(typeData["color"] as String).withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                        child: Text(typeData["name"] as String, style: TextStyle(color: hexToColor(typeData["color"] as String), fontSize: 10)),
                      ),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    start.toLocal().toString().substring(0, 10) + " a " + end.toLocal().toString().substring(0, 10),
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                  if (managerData is Map) Text("Responsavel: " + (managerData["login_email"] as String? ?? "-"), style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.people_outline, size: 14, color: Colors.white38),
                    const SizedBox(width: 4),
                    Text((event["participantCount"] ?? 0).toString() + " participantes", style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventFormDialog extends StatefulWidget {
  final List<Map<String, dynamic>> types;
  const _EventFormDialog({required this.types});

  @override
  State<_EventFormDialog> createState() => _EventFormDialogState();
}

class _EventFormDialogState extends State<_EventFormDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _typeId;
  String? _responsibleId;
  DateTime? _startDate;
  DateTime? _endDate;
  List<Map<String, dynamic>> _managers = [];
  PlatformFile? _bannerFile;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadManagers();
  }

  Future<void> _loadManagers() async {
    final client = Supabase.instance.client;
    final rows = await client.from("managers").select("id, login_email").order("login_email");
    setState(() {
      _managers = (rows as List).cast<Map<String, dynamic>>();
      _responsibleId = client.auth.currentUser!.id;
    });
  }

  Future<void> _pickBanner() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result != null && result.files.isNotEmpty && result.files.first.bytes != null) {
      setState(() => _bannerFile = result.files.first);
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _startDate : _endDate) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  bool get _canSave => _titleController.text.trim().isNotEmpty && _startDate != null && _endDate != null;

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser!.id;
      final manager = await client.from("managers").select("agency_id").eq("id", userId).single();

      final inserted = await client.from("agency_events").insert({
        "agency_id": manager["agency_id"],
        "type_id": _typeId,
        "title": _titleController.text.trim(),
        "description": _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        "status": "planejado",
        "start_date": _dateOnly(_startDate!),
        "end_date": _dateOnly(_endDate!),
        "responsible_manager_id": _responsibleId,
        "created_by": userId,
      }).select("id").single();

      final eventId = inserted["id"] as String;

      if (_bannerFile != null) {
        final url = await uploadEventFile(bucket: "event_banners", prefix: eventId, file: _bannerFile!);
        await client.from("agency_events").update({"banner_url": url}).eq("id", eventId);
      }

      await logEventHistory(eventId: eventId, action: "criacao", detail: "Evento criado");

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao criar evento: " + e.toString())));
    }
  }

  String _dateOnly(DateTime date) {
    final y = date.year.toString().padLeft(4, "0");
    final m = date.month.toString().padLeft(2, "0");
    final d = date.day.toString().padLeft(2, "0");
    return y + "-" + m + "-" + d;
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
              const Text("Novo Evento", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _pickBanner,
                        icon: const Icon(Icons.image_outlined, size: 16),
                        label: Text(_bannerFile != null ? "Banner selecionado: " + _bannerFile!.name : "Selecionar banner (opcional)"),
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
                        items: widget.types.map((t) => DropdownMenuItem<String?>(value: t["id"] as String, child: Text(t["name"] as String))).toList(),
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
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickDate(true),
                            icon: const Icon(Icons.calendar_today, size: 14),
                            label: Text(_startDate != null ? _dateOnly(_startDate!) : "Data inicial"),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickDate(false),
                            icon: const Icon(Icons.calendar_today, size: 14),
                            label: Text(_endDate != null ? _dateOnly(_endDate!) : "Data final"),
                          ),
                        ),
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
                  onPressed: (_canSave && !_saving) ? _save : null,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
                  child: Text(_saving ? "Salvando..." : "Criar evento"),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
