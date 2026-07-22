import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "event_history_service.dart";

Color _awardStatusColor(String status) {
  switch (status) {
    case "comprado":
      return Colors.amber;
    case "entregue":
      return Colors.greenAccent;
    default:
      return Colors.white54;
  }
}

String _awardStatusLabel(String status) {
  switch (status) {
    case "comprado":
      return "Comprado";
    case "entregue":
      return "Entregue";
    default:
      return "Pendente";
  }
}

const _awardStatusOptions = ["pendente", "comprado", "entregue"];

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
    final rows = await client.from("event_awards").select().eq("event_id", widget.eventId).order("created_at");
    return (rows as List).cast<Map<String, dynamic>>();
  }

  void _reload() => setState(() => _future = _load());

  void _openForm({Map<String, dynamic>? existing}) {
    showDialog(context: context, builder: (context) => _AwardFormDialog(eventId: widget.eventId, existing: existing)).then((saved) {
      if (saved == true) _reload();
    });
  }

  Future<void> _toggleDelivered(Map<String, dynamic> award) async {
    final client = Supabase.instance.client;
    final delivering = award["status"] != "entregue";
    try {
      await client.from("event_awards").update({
        "status": delivering ? "entregue" : "pendente",
        "delivered_at": delivering ? DateTime.now().toIso8601String() : null,
      }).eq("id", award["id"]);
      await logEventHistory(eventId: widget.eventId, action: delivering ? "premiacao_entregue" : "premiacao_pendente", detail: award["name"] as String);
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
                    final value = award["value"] as num?;
                    final supplier = award["supplier"] as String?;
                    return Card(
                      color: Colors.white.withOpacity(0.05),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        onTap: () => _openForm(existing: award),
                        title: Text(award["name"] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          "Qtd: " + award["quantity"].toString() + (value != null ? "  -  R\$ " + value.toStringAsFixed(2) : "") + (supplier != null && supplier.isNotEmpty ? "  -  " + supplier : ""),
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(border: Border.all(color: color), borderRadius: BorderRadius.circular(8)),
                            child: Text(_awardStatusLabel(award["status"] as String), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(award["status"] == "entregue" ? Icons.check_circle : Icons.check_circle_outline, color: award["status"] == "entregue" ? Colors.greenAccent : Colors.white38, size: 20),
                            tooltip: "Marcar como entregue",
                            onPressed: () => _toggleDelivered(award),
                          ),
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

class _AwardFormDialog extends StatefulWidget {
  final String eventId;
  final Map<String, dynamic>? existing;
  const _AwardFormDialog({required this.eventId, this.existing});

  @override
  State<_AwardFormDialog> createState() => _AwardFormDialogState();
}

class _AwardFormDialogState extends State<_AwardFormDialog> {
  late final _nameController = TextEditingController(text: widget.existing?["name"] as String? ?? "");
  late final _quantityController = TextEditingController(text: (widget.existing?["quantity"] ?? 1).toString());
  late final _valueController = TextEditingController(text: widget.existing?["value"]?.toString() ?? "");
  late final _supplierController = TextEditingController(text: widget.existing?["supplier"] as String? ?? "");
  late final _notesController = TextEditingController(text: widget.existing?["notes"] as String? ?? "");
  late String _status = widget.existing?["status"] as String? ?? "pendente";
  bool _saving = false;

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser!.id;

      final data = {
        "event_id": widget.eventId,
        "name": _nameController.text.trim(),
        "quantity": int.tryParse(_quantityController.text.trim()) ?? 1,
        "value": double.tryParse(_valueController.text.trim().replaceAll(",", ".")),
        "supplier": _supplierController.text.trim().isEmpty ? null : _supplierController.text.trim(),
        "status": _status,
        "delivered_at": _status == "entregue" ? DateTime.now().toIso8601String() : null,
        "notes": _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      };

      if (widget.existing != null) {
        await client.from("event_awards").update(data).eq("id", widget.existing!["id"]);
        await logEventHistory(eventId: widget.eventId, action: "premiacao_atualizada", detail: _nameController.text.trim());
      } else {
        await client.from("event_awards").insert({...data, "created_by": userId});
        await logEventHistory(eventId: widget.eventId, action: "premiacao_adicionada", detail: _nameController.text.trim());
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.existing != null ? "Editar premiacao" : "Nova premiacao", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(controller: _nameController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Nome", labelStyle: TextStyle(color: Colors.white54))),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextField(controller: _quantityController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Quantidade", labelStyle: TextStyle(color: Colors.white54)))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: _valueController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Valor R\$", labelStyle: TextStyle(color: Colors.white54)))),
              ]),
              const SizedBox(height: 8),
              TextField(controller: _supplierController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Fornecedor", labelStyle: TextStyle(color: Colors.white54))),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _status,
                dropdownColor: const Color(0xFF232323),
                decoration: const InputDecoration(labelText: "Status", labelStyle: TextStyle(color: Colors.white54)),
                style: const TextStyle(color: Colors.white),
                items: _awardStatusOptions.map((s) => DropdownMenuItem(value: s, child: Text(_awardStatusLabel(s)))).toList(),
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
