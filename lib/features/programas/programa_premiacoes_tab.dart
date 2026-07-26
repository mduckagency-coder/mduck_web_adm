import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "../calendario/widgets/streamer_picker_dialog.dart";
import "programa_history_helpers.dart";

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

class ProgramaPremiacoesTab extends StatefulWidget {
  final Map<String, dynamic> program;
  const ProgramaPremiacoesTab({super.key, required this.program});

  @override
  State<ProgramaPremiacoesTab> createState() => _ProgramaPremiacoesTabState();
}

class _ProgramaPremiacoesTabState extends State<ProgramaPremiacoesTab> {
  late Future<List<Map<String, dynamic>>> _future;
  String _filter = "pendentes";

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final client = Supabase.instance.client;
    final rows = await client
        .from("program_awards")
        .select("*, streamer:profiles(display_name, avatar_url, tiktok_username, tiktok_creator_id)")
        .eq("program_id", widget.program["id"])
        .order("created_at", ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _markDelivered(Map<String, dynamic> award) async {
    final ok = await confirmAction(context, title: "Marcar premiacao como entregue", message: "Confirmar entrega de \"" + (award["title"] as String) + "\"?");
    if (!ok) return;
    final client = Supabase.instance.client;
    try {
      await client.from("program_awards").update({"status": "entregue", "delivered_at": DateTime.now().toIso8601String()}).eq("id", award["id"]);
      final streamer = award["streamer"];
      await logProgramaHistory(
        streamerId: award["streamer_id"] as String,
        phaseKey: widget.program["program_key"] as String,
        action: "premiacao_entregue",
        detail: (award["title"] as String) + (streamer is Map ? "  -  " + (streamer["display_name"] as String? ?? "") : ""),
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Premiacao entregue.")));
      _reload();
    } catch (e) {
      if (mounted) showProgramasActionError(context, e);
    }
  }

  void _openForm({Map<String, dynamic>? existing}) {
    showDialog(context: context, builder: (context) => _AwardFormDialog(program: widget.program, existing: existing)).then((saved) {
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
            const Text("Premiacoes", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add, size: 16),
              label: const Text("Nova premiacao"),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            ChoiceChip(label: const Text("Pendentes"), selected: _filter == "pendentes", selectedColor: Colors.orangeAccent, onSelected: (_) => setState(() => _filter = "pendentes")),
            const SizedBox(width: 6),
            ChoiceChip(label: const Text("Entregues"), selected: _filter == "entregues", selectedColor: Colors.greenAccent, onSelected: (_) => setState(() => _filter = "entregues")),
            const SizedBox(width: 6),
            ChoiceChip(label: const Text("Todos"), selected: _filter == "todos", selectedColor: Colors.white24, onSelected: (_) => setState(() => _filter = "todos")),
          ]),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.hasError) return buildProgramasLoadError(snapshot.error!);
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final list = snapshot.data!.where((a) {
                  if (_filter == "pendentes") return a["status"] == "pendente";
                  if (_filter == "entregues") return a["status"] == "entregue";
                  return true;
                }).toList();
                if (list.isEmpty) return const Center(child: Text("Nenhuma premiacao aqui.", style: TextStyle(color: Colors.white54)));
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final award = list[index];
                    final streamer = award["streamer"];
                    final name = streamer is Map ? (streamer["display_name"] as String? ?? "-") : "-";
                    final nick = streamer is Map ? streamer["tiktok_username"] as String? : null;
                    final avatarUrl = streamer is Map ? streamer["avatar_url"] as String? : null;
                    final pending = award["status"] == "pendente";
                    final items = _parseItems(award["items"]);
                    final scheduledDate = award["scheduled_delivery_date"] as String?;
                    return Card(
                      color: Colors.white.withOpacity(0.05),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        onTap: () => _openForm(existing: award),
                        leading: CircleAvatar(radius: 18, backgroundColor: Colors.white24, backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null, child: avatarUrl == null ? const Icon(Icons.person, color: Colors.white54, size: 18) : null),
                        title: Text(name + (nick != null && nick.isNotEmpty ? " (@" + nick + ")" : ""), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(items.isNotEmpty ? _itemsSummary(items) : (award["title"] as String? ?? "-"), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            if (scheduledDate != null) Text("Entrega prevista: " + scheduledDate, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                          ],
                        ),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(border: Border.all(color: pending ? Colors.orangeAccent : Colors.greenAccent), borderRadius: BorderRadius.circular(8)),
                            child: Text(pending ? "Pendente" : "Entregue", style: TextStyle(color: pending ? Colors.orangeAccent : Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                          if (pending)
                            IconButton(icon: const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 20), tooltip: "Marcar como entregue", onPressed: () => _markDelivered(award)),
                        ]),
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
  final Map<String, dynamic> program;
  final Map<String, dynamic>? existing;
  const _AwardFormDialog({required this.program, this.existing});

  @override
  State<_AwardFormDialog> createState() => _AwardFormDialogState();
}

class _AwardFormDialogState extends State<_AwardFormDialog> {
  late final _reasonController = TextEditingController(text: widget.existing?["reason"] as String? ?? "");
  late List<_ItemRow> _items = _initialItems();
  late DateTime? _scheduledDeliveryDate =
      widget.existing?["scheduled_delivery_date"] != null ? DateTime.parse(widget.existing!["scheduled_delivery_date"] as String) : null;
  Map<String, dynamic>? _selectedStreamer;
  bool _saving = false;
  String? _error;

  List<_ItemRow> _initialItems() {
    final raw = widget.existing?["items"];
    if (raw is List && raw.isNotEmpty) {
      return raw
          .cast<Map<String, dynamic>>()
          .map((it) => _ItemRow(name: (it["name"] as String?) ?? "", quantity: (it["quantity"] as num?)?.toInt() ?? 1, value: it["value"] as num?))
          .toList();
    }
    final title = widget.existing?["title"] as String?;
    return [_ItemRow(name: title ?? "")];
  }

  @override
  void initState() {
    super.initState();
    final streamer = widget.existing?["streamer"];
    if (widget.existing != null && streamer is Map) {
      _selectedStreamer = {"id": widget.existing!["streamer_id"], ...streamer};
    }
  }

  Future<void> _pickStreamer() async {
    final selected = await showDialog<List<Map<String, dynamic>>>(context: context, builder: (context) => const StreamerPickerDialog());
    if (selected == null || selected.isEmpty) return;
    setState(() => _selectedStreamer = selected.first);
  }

  Future<void> _pickDeliveryDate() async {
    final picked = await showDatePicker(context: context, initialDate: _scheduledDeliveryDate ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (picked != null) setState(() => _scheduledDeliveryDate = picked);
  }

  Future<void> _save() async {
    final itemsData = _items
        .where((it) => it.nameController.text.trim().isNotEmpty)
        .map((it) => {
              "name": it.nameController.text.trim(),
              "quantity": int.tryParse(it.quantityController.text.trim()) ?? 1,
              "value": double.tryParse(it.valueController.text.trim().replaceAll(",", ".")),
            })
        .toList();

    if (itemsData.isEmpty) {
      setState(() => _error = "Adicione pelo menos um item de premiacao.");
      return;
    }
    if (_selectedStreamer == null) {
      setState(() => _error = "Selecione o streamer vinculado.");
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser!.id;
      final streamerId = _selectedStreamer!["id"] as String;
      final data = {
        "program_id": widget.program["id"],
        "streamer_id": streamerId,
        "title": _itemsSummary(itemsData),
        "items": itemsData,
        "scheduled_delivery_date": _scheduledDeliveryDate != null ? _scheduledDeliveryDate!.toIso8601String().substring(0, 10) : null,
        "reason": _reasonController.text.trim().isEmpty ? null : _reasonController.text.trim(),
      };
      if (widget.existing != null) {
        await client.from("program_awards").update(data).eq("id", widget.existing!["id"]);
      } else {
        await client.from("program_awards").insert({...data, "created_by": userId, "status": "pendente"});
      }
      await logProgramaHistory(streamerId: streamerId, phaseKey: widget.program["program_key"] as String, action: "premiacao_registrada", detail: data["title"] as String);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = "Erro: " + e.toString();
      });
    }
  }

  Future<void> _delete() async {
    try {
      await Supabase.instance.client.from("program_awards").delete().eq("id", widget.existing!["id"]);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showProgramasActionError(context, e);
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
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 650),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.existing != null ? "Editar premiacao" : "Nova premiacao", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(_selectedStreamer!["display_name"] as String? ?? "-", style: const TextStyle(color: Colors.white, fontSize: 13), overflow: TextOverflow.ellipsis),
                                        Text(
                                          "@" + ((_selectedStreamer!["tiktok_username"] as String?) ?? "-") + "  -  ID: " + ((_selectedStreamer!["tiktok_creator_id"] as String?) ?? "-"),
                                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ])
                              : const Text("Nenhum streamer selecionado", style: TextStyle(color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic)),
                        ),
                        TextButton(onPressed: _pickStreamer, child: Text(_selectedStreamer != null ? "Trocar" : "Selecionar")),
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
                      Row(children: [
                        Expanded(
                          child: Text(
                            _scheduledDeliveryDate != null ? "Entrega prevista: " + _scheduledDeliveryDate!.toIso8601String().substring(0, 10) : "Entrega prevista: nao definida",
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ),
                        TextButton(onPressed: _pickDeliveryDate, child: const Text("Escolher data")),
                        if (_scheduledDeliveryDate != null) IconButton(icon: const Icon(Icons.clear, size: 16, color: Colors.white38), onPressed: () => setState(() => _scheduledDeliveryDate = null)),
                      ]),
                      const SizedBox(height: 8),
                      TextField(controller: _reasonController, maxLines: 2, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Motivo", labelStyle: TextStyle(color: Colors.white54))),
                      if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12))),
                    ],
                  ),
                ),
              ),
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
