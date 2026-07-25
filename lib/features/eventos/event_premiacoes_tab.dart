import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "../calendario/widgets/streamer_picker_dialog.dart";
import "event_history_service.dart";

Color _awardStatusColor(String status) {
  switch (status) {
    case "agendado":
      return Colors.amber;
    case "pago":
      return Colors.greenAccent;
    default:
      return Colors.white54;
  }
}

String _awardStatusLabel(String status) {
  switch (status) {
    case "agendado":
      return "Agendado";
    case "pago":
      return "Pago";
    default:
      return "Pendente";
  }
}

const _awardStatusOptions = ["pendente", "agendado", "pago"];

List<Map<String, dynamic>> _parseItems(dynamic raw) {
  if (raw is List) return raw.cast<Map<String, dynamic>>();
  return const [];
}

String _itemsSummary(List<Map<String, dynamic>> items) {
  if (items.isEmpty) return "-";
  return items.map((it) {
    final qty = it["quantity"] ?? 1;
    final name = (it["name"] as String?) ?? "-";
    return qty.toString() + "x " + name;
  }).join(", ");
}

class EventPremiacoesTab extends StatefulWidget {
  final String eventId;
  const EventPremiacoesTab({super.key, required this.eventId});

  @override
  State<EventPremiacoesTab> createState() => _EventPremiacoesTabState();
}

class _EventPremiacoesTabState extends State<EventPremiacoesTab> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final client = Supabase.instance.client;
    final rows = await client
        .from("event_awards")
        .select("*, streamer:profiles(id, display_name, tiktok_username, tiktok_creator_id, avatar_url), manager:managers(login_email)")
        .eq("event_id", widget.eventId)
        .order("created_at");
    return (rows as List).cast<Map<String, dynamic>>();
  }

  void _reload() => setState(() { _future = _load(); });

  void _openForm({Map<String, dynamic>? existing}) {
    showDialog(context: context, builder: (context) => _AwardFormDialog(eventId: widget.eventId, existing: existing)).then((saved) {
      if (saved == true) _reload();
    });
  }

  Future<void> _toggleDelivered(Map<String, dynamic> award) async {
    final client = Supabase.instance.client;
    final payingNow = award["status"] != "pago";
    try {
      await client.from("event_awards").update({
        "status": payingNow ? "pago" : "pendente",
        "paid_at": payingNow ? DateTime.now().toIso8601String() : null,
      }).eq("id", award["id"]);
      await logEventHistory(eventId: widget.eventId, action: payingNow ? "premiacao_paga" : "premiacao_pendente", detail: award["name"] as String);
      _reload();
    } catch (e) {
      if (mounted) showEventosActionError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text("Premiacoes", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add, size: 16),
              label: const Text("Nova premiacao"),
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
                if (list.isEmpty) return const Center(child: Text("Nenhuma premiacao cadastrada ainda.", style: TextStyle(color: Colors.white54)));
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final award = list[index];
                    final color = _awardStatusColor(award["status"] as String);
                    final items = _parseItems(award["items"]);
                    final streamer = award["streamer"];
                    final hasStreamer = streamer is Map;
                    final manager = award["manager"];
                    final managerEmail = manager is Map ? manager["login_email"] as String? : null;
                    final createdAt = award["created_at"] != null ? DateTime.parse(award["created_at"]).toLocal().toString().substring(0, 16) : "-";
                    final paidAt = award["paid_at"] != null ? DateTime.parse(award["paid_at"]).toLocal().toString().substring(0, 10) : null;

                    return Card(
                      color: Colors.white.withOpacity(0.05),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () => _openForm(existing: award),
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: Colors.white24,
                                    backgroundImage: hasStreamer && streamer["avatar_url"] != null ? NetworkImage(streamer["avatar_url"] as String) : null,
                                    child: !hasStreamer || streamer["avatar_url"] == null ? const Icon(Icons.person, color: Colors.white54, size: 18) : null,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(award["name"] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                        const SizedBox(height: 2),
                                        Text(
                                          hasStreamer
                                              ? (streamer["display_name"] as String? ?? "-") + "  -  @" + ((streamer["tiktok_username"] as String?) ?? "-") + "  -  ID: " + ((streamer["tiktok_creator_id"] as String?) ?? "-")
                                              : "Sem streamer vinculado (manual)",
                                          style: TextStyle(color: hasStreamer ? Colors.white70 : Colors.white38, fontSize: 12, fontStyle: hasStreamer ? FontStyle.normal : FontStyle.italic),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(border: Border.all(color: color), borderRadius: BorderRadius.circular(8)),
                                    child: Text(_awardStatusLabel(award["status"] as String), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                  IconButton(
                                    icon: Icon(award["status"] == "pago" ? Icons.check_circle : Icons.check_circle_outline, color: award["status"] == "pago" ? Colors.greenAccent : Colors.white38, size: 20),
                                    tooltip: "Marcar como pago",
                                    onPressed: () => _toggleDelivered(award),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(_itemsSummary(items), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                              if (paidAt != null) ...[
                                const SizedBox(height: 2),
                                Text("Pago em " + paidAt, style: const TextStyle(color: Colors.greenAccent, fontSize: 11)),
                              ],
                              const SizedBox(height: 6),
                              Text(
                                "Cadastrado por " + (managerEmail ?? "-") + "  -  " + createdAt,
                                style: const TextStyle(color: Colors.white24, fontSize: 10),
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

class _ItemRow {
  final TextEditingController nameController;
  final TextEditingController quantityController;
  final TextEditingController valueController;
  _ItemRow({String name = "", int quantity = 1, num? value})
      : nameController = TextEditingController(text: name),
        quantityController = TextEditingController(text: quantity.toString()),
        valueController = TextEditingController(text: value?.toString() ?? "");
}

class _AwardFormDialog extends StatefulWidget {
  final String eventId;
  final Map<String, dynamic>? existing;
  const _AwardFormDialog({required this.eventId, this.existing});

  @override
  State<_AwardFormDialog> createState() => _AwardFormDialogState();
}

class _AwardFormDialogState extends State<_AwardFormDialog> {
  late final _nameController = TextEditingController(text: widget.existing?["name"] as String? ?? "");
  late final _notesController = TextEditingController(text: widget.existing?["notes"] as String? ?? "");
  late String _status = widget.existing?["status"] as String? ?? "pendente";
  late DateTime? _expectedDeliveryDate =
      widget.existing?["expected_delivery_date"] != null ? DateTime.parse(widget.existing!["expected_delivery_date"] as String) : null;
  late List<_ItemRow> _items = _initialItems();
  Map<String, dynamic>? _selectedStreamer;
  bool _saving = false;

  List<_ItemRow> _initialItems() {
    final raw = widget.existing?["items"];
    if (raw is List && raw.isNotEmpty) {
      return raw
          .cast<Map<String, dynamic>>()
          .map((it) => _ItemRow(name: (it["name"] as String?) ?? "", quantity: (it["quantity"] as num?)?.toInt() ?? 1, value: it["value"] as num?))
          .toList();
    }
    return [_ItemRow()];
  }

  @override
  void initState() {
    super.initState();
    final existingStreamer = widget.existing?["streamer"];
    if (existingStreamer is Map) _selectedStreamer = Map<String, dynamic>.from(existingStreamer);
  }

  Future<void> _pickStreamer() async {
    final selected = await showDialog<List<Map<String, dynamic>>>(context: context, builder: (context) => const StreamerPickerDialog());
    if (selected == null || selected.isEmpty) return;
    setState(() => _selectedStreamer = selected.first);
  }

  Future<void> _pickExpectedDate() async {
    final picked = await showDatePicker(context: context, initialDate: _expectedDeliveryDate ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (picked != null) setState(() => _expectedDeliveryDate = picked);
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser!.id;

      final itemsData = _items
          .where((it) => it.nameController.text.trim().isNotEmpty)
          .map((it) => {
                "name": it.nameController.text.trim(),
                "quantity": int.tryParse(it.quantityController.text.trim()) ?? 1,
                "value": double.tryParse(it.valueController.text.trim().replaceAll(",", ".")),
              })
          .toList();

      final wasPago = widget.existing?["status"] == "pago";
      final data = {
        "event_id": widget.eventId,
        "name": _nameController.text.trim(),
        "streamer_id": _selectedStreamer?["id"],
        "items": itemsData,
        "status": _status,
        "paid_at": _status == "pago" ? (wasPago ? widget.existing!["paid_at"] : DateTime.now().toIso8601String()) : null,
        "expected_delivery_date": _expectedDeliveryDate != null ? _expectedDeliveryDate!.toIso8601String().substring(0, 10) : null,
        "notes": _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      };

      final streamerName = _selectedStreamer?["display_name"] as String?;
      final logDetail = _nameController.text.trim() + (streamerName != null ? "  -  " + streamerName : "");

      if (widget.existing != null) {
        await client.from("event_awards").update(data).eq("id", widget.existing!["id"]);
        await logEventHistory(eventId: widget.eventId, action: "premiacao_atualizada", detail: logDetail);
      } else {
        await client.from("event_awards").insert({...data, "created_by": userId});
        await logEventHistory(eventId: widget.eventId, action: "premiacao_adicionada", detail: logDetail);
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
      await client.from("event_awards").delete().eq("id", widget.existing!["id"]);
      await logEventHistory(eventId: widget.eventId, action: "premiacao_removida", detail: _nameController.text.trim());
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showEventosActionError(context, e);
    }
  }

  Widget _itemRowWidget(int index) {
    final item = _items[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: TextField(controller: item.nameController, style: const TextStyle(color: Colors.white, fontSize: 13), decoration: const InputDecoration(labelText: "Premiacao", labelStyle: TextStyle(color: Colors.white54, fontSize: 11), isDense: true))),
          const SizedBox(width: 6),
          Expanded(flex: 2, child: TextField(controller: item.quantityController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white, fontSize: 13), decoration: const InputDecoration(labelText: "Qtd", labelStyle: TextStyle(color: Colors.white54, fontSize: 11), isDense: true))),
          const SizedBox(width: 6),
          Expanded(flex: 2, child: TextField(controller: item.valueController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white, fontSize: 13), decoration: const InputDecoration(labelText: "Valor R\$", labelStyle: TextStyle(color: Colors.white54, fontSize: 11), isDense: true))),
          if (_items.length > 1)
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 18),
              onPressed: () => setState(() => _items.removeAt(index)),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final createdAt = widget.existing?["created_at"] != null ? DateTime.parse(widget.existing!["created_at"]).toLocal().toString().substring(0, 16) : null;
    final managerData = widget.existing?["manager"];
    final managerEmail = managerData is Map ? managerData["login_email"] as String? : null;

    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 700),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.existing != null ? "Editar premiacao" : "Nova premiacao", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              if (createdAt != null) ...[
                const SizedBox(height: 2),
                Text("Gestor responsavel: " + (managerEmail ?? "-") + "  -  Cadastrado em " + createdAt, style: const TextStyle(color: Colors.white24, fontSize: 10)),
              ],
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(controller: _nameController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Titulo da premiacao", labelStyle: TextStyle(color: Colors.white54))),
                      const SizedBox(height: 10),
                      const Text("Streamer vinculado", style: TextStyle(color: Colors.white54, fontSize: 12)),
                      const SizedBox(height: 4),
                      Row(children: [
                        Expanded(
                          child: _selectedStreamer != null
                              ? Row(children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: Colors.white24,
                                    backgroundImage: _selectedStreamer!["avatar_url"] != null ? NetworkImage(_selectedStreamer!["avatar_url"] as String) : null,
                                    child: _selectedStreamer!["avatar_url"] == null ? const Icon(Icons.person, size: 14, color: Colors.white54) : null,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(_selectedStreamer!["display_name"] as String? ?? "-", style: const TextStyle(color: Colors.white, fontSize: 13), overflow: TextOverflow.ellipsis)),
                                ])
                              : const Text("Sem streamer vinculado (manual)", style: TextStyle(color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic)),
                        ),
                        TextButton(onPressed: _pickStreamer, child: Text(_selectedStreamer != null ? "Trocar" : "Vincular")),
                        if (_selectedStreamer != null) IconButton(icon: const Icon(Icons.clear, size: 16, color: Colors.white38), onPressed: () => setState(() => _selectedStreamer = null)),
                      ]),
                      const SizedBox(height: 14),
                      const Text("Itens premiados", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      ...List.generate(_items.length, _itemRowWidget),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => setState(() => _items.add(_ItemRow())),
                          icon: const Icon(Icons.add, size: 16, color: Color(0xFF7A0BD4)),
                          label: const Text("Adicionar item", style: TextStyle(color: Color(0xFF7A0BD4))),
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _status,
                        dropdownColor: const Color(0xFF232323),
                        decoration: const InputDecoration(labelText: "Status", labelStyle: TextStyle(color: Colors.white54)),
                        style: const TextStyle(color: Colors.white),
                        items: _awardStatusOptions.map((s) => DropdownMenuItem(value: s, child: Text(_awardStatusLabel(s)))).toList(),
                        onChanged: (v) => setState(() => _status = v!),
                      ),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                          child: Text(
                            _expectedDeliveryDate != null ? "Previsao de entrega: " + _expectedDeliveryDate!.toIso8601String().substring(0, 10) : "Previsao de entrega: nao definida",
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ),
                        TextButton(onPressed: _pickExpectedDate, child: const Text("Escolher data")),
                        if (_expectedDeliveryDate != null) IconButton(icon: const Icon(Icons.clear, size: 16, color: Colors.white38), onPressed: () => setState(() => _expectedDeliveryDate = null)),
                      ]),
                      const SizedBox(height: 8),
                      TextField(controller: _notesController, maxLines: 2, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Observacoes", labelStyle: TextStyle(color: Colors.white54))),
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
