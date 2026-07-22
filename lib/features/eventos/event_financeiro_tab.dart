import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "event_history_service.dart";

const _entryTypeOptions = ["despesa", "patrocinio", "compra"];
const _entryStatusOptions = ["pendente", "pago", "recebido"];

String _entryTypeLabel(String type) {
  switch (type) {
    case "patrocinio":
      return "Patrocinio";
    case "compra":
      return "Compra";
    default:
      return "Despesa";
  }
}

Color _entryTypeColor(String type) {
  switch (type) {
    case "patrocinio":
      return Colors.greenAccent;
    case "compra":
      return Colors.amber;
    default:
      return Colors.redAccent;
  }
}

class EventFinanceiroTab extends StatefulWidget {
  final String eventId;
  const EventFinanceiroTab({super.key, required this.eventId});

  @override
  State<EventFinanceiroTab> createState() => _EventFinanceiroTabState();
}

class _EventFinanceiroTabState extends State<EventFinanceiroTab> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final client = Supabase.instance.client;
    final budget = await client.from("event_budget").select().eq("event_id", widget.eventId).maybeSingle();
    final entries = await client.from("event_financial_entries").select().eq("event_id", widget.eventId).order("entry_date", ascending: false);
    return {"budget": budget, "entries": (entries as List).cast<Map<String, dynamic>>()};
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _editBudget(double current) async {
    final controller = TextEditingController(text: current == 0 ? "" : current.toStringAsFixed(2));
    final value = await showDialog<double>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1A1A1A),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Orcamento do evento", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(controller: controller, keyboardType: TextInputType.number, autofocus: true, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Valor R\$", labelStyle: TextStyle(color: Colors.white54))),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(double.tryParse(controller.text.trim().replaceAll(",", ".")) ?? 0),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
                  child: const Text("Salvar"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (value == null) return;
    final client = Supabase.instance.client;
    try {
      await client.from("event_budget").upsert({
        "event_id": widget.eventId,
        "budget_amount": value,
        "updated_at": DateTime.now().toIso8601String(),
      }, onConflict: "event_id");
      await logEventHistory(eventId: widget.eventId, action: "orcamento_definido", detail: "R\$ " + value.toStringAsFixed(2));
      _reload();
    } catch (e) {
      if (mounted) showEventosActionError(context, e);
    }
  }

  void _openEntryForm({Map<String, dynamic>? existing}) {
    showDialog(context: context, builder: (context) => _EntryFormDialog(eventId: widget.eventId, existing: existing)).then((saved) {
      if (saved == true) _reload();
    });
  }

  Widget _summaryCard(String label, String value, Color color) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) return buildEventosLoadError(snapshot.error!);
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final budget = snapshot.data!["budget"] as Map<String, dynamic>?;
          final entries = snapshot.data!["entries"] as List<Map<String, dynamic>>;
          final budgetAmount = (budget?["budget_amount"] as num?)?.toDouble() ?? 0;

          double despesas = 0, compras = 0, patrocinios = 0;
          for (final e in entries) {
            final amount = (e["amount"] as num).toDouble();
            if (e["entry_type"] == "despesa") despesas += amount;
            if (e["entry_type"] == "compra") compras += amount;
            if (e["entry_type"] == "patrocinio") patrocinios += amount;
          }
          final saldo = budgetAmount - despesas - compras + patrocinios;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Text("Financeiro", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                OutlinedButton.icon(onPressed: () => _editBudget(budgetAmount), icon: const Icon(Icons.edit, size: 14), label: const Text("Definir orcamento")),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _openEntryForm(),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text("Novo lancamento"),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
                ),
              ]),
              const SizedBox(height: 16),
              Wrap(spacing: 12, runSpacing: 12, children: [
                _summaryCard("Orcamento", "R\$ " + budgetAmount.toStringAsFixed(2), const Color(0xFF7A0BD4)),
                _summaryCard("Despesas", "R\$ " + despesas.toStringAsFixed(2), Colors.redAccent),
                _summaryCard("Compras", "R\$ " + compras.toStringAsFixed(2), Colors.amber),
                _summaryCard("Patrocinios", "R\$ " + patrocinios.toStringAsFixed(2), Colors.greenAccent),
                _summaryCard("Saldo", "R\$ " + saldo.toStringAsFixed(2), saldo >= 0 ? Colors.greenAccent : Colors.redAccent),
              ]),
              const SizedBox(height: 16),
              Expanded(
                child: entries.isEmpty
                    ? const Center(child: Text("Nenhum lancamento registrado ainda.", style: TextStyle(color: Colors.white54)))
                    : ListView.builder(
                        itemCount: entries.length,
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          final color = _entryTypeColor(entry["entry_type"] as String);
                          return Card(
                            color: Colors.white.withOpacity(0.05),
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              onTap: () => _openEntryForm(existing: entry),
                              leading: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(border: Border.all(color: color), borderRadius: BorderRadius.circular(8)),
                                child: Text(_entryTypeLabel(entry["entry_type"] as String), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                              title: Text(entry["description"] as String, style: const TextStyle(color: Colors.white)),
                              subtitle: Text((entry["entry_date"] as String) + "  -  " + (entry["status"] as String), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                              trailing: Text("R\$ " + (entry["amount"] as num).toStringAsFixed(2), style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EntryFormDialog extends StatefulWidget {
  final String eventId;
  final Map<String, dynamic>? existing;
  const _EntryFormDialog({required this.eventId, this.existing});

  @override
  State<_EntryFormDialog> createState() => _EntryFormDialogState();
}

class _EntryFormDialogState extends State<_EntryFormDialog> {
  late final _descriptionController = TextEditingController(text: widget.existing?["description"] as String? ?? "");
  late final _amountController = TextEditingController(text: widget.existing?["amount"]?.toString() ?? "");
  late String _entryType = widget.existing?["entry_type"] as String? ?? "despesa";
  late String _status = widget.existing?["status"] as String? ?? "pendente";
  late DateTime _entryDate = widget.existing != null ? DateTime.parse(widget.existing!["entry_date"] as String) : DateTime.now();
  bool _saving = false;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: _entryDate, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (picked != null) setState(() => _entryDate = picked);
  }

  Future<void> _save() async {
    if (_descriptionController.text.trim().isEmpty || double.tryParse(_amountController.text.trim().replaceAll(",", ".")) == null) return;
    setState(() => _saving = true);
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser!.id;
      final dateSql = _entryDate.year.toString().padLeft(4, "0") + "-" + _entryDate.month.toString().padLeft(2, "0") + "-" + _entryDate.day.toString().padLeft(2, "0");

      final data = {
        "event_id": widget.eventId,
        "entry_type": _entryType,
        "description": _descriptionController.text.trim(),
        "amount": double.parse(_amountController.text.trim().replaceAll(",", ".")),
        "status": _status,
        "entry_date": dateSql,
      };

      if (widget.existing != null) {
        await client.from("event_financial_entries").update(data).eq("id", widget.existing!["id"]);
        await logEventHistory(eventId: widget.eventId, action: "financeiro_atualizado", detail: _descriptionController.text.trim());
      } else {
        await client.from("event_financial_entries").insert({...data, "created_by": userId});
        await logEventHistory(eventId: widget.eventId, action: "financeiro_lancamento", detail: _entryTypeLabel(_entryType) + ": " + _descriptionController.text.trim());
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
      await client.from("event_financial_entries").delete().eq("id", widget.existing!["id"]);
      await logEventHistory(eventId: widget.eventId, action: "financeiro_removido", detail: _descriptionController.text.trim());
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
              Text(widget.existing != null ? "Editar lancamento" : "Novo lancamento", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _entryType,
                dropdownColor: const Color(0xFF232323),
                decoration: const InputDecoration(labelText: "Tipo", labelStyle: TextStyle(color: Colors.white54)),
                style: const TextStyle(color: Colors.white),
                items: _entryTypeOptions.map((t) => DropdownMenuItem(value: t, child: Text(_entryTypeLabel(t)))).toList(),
                onChanged: (v) => setState(() => _entryType = v!),
              ),
              const SizedBox(height: 8),
              TextField(controller: _descriptionController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Descricao", labelStyle: TextStyle(color: Colors.white54))),
              const SizedBox(height: 8),
              TextField(controller: _amountController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Valor R\$", labelStyle: TextStyle(color: Colors.white54))),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _status,
                    dropdownColor: const Color(0xFF232323),
                    decoration: const InputDecoration(labelText: "Status", labelStyle: TextStyle(color: Colors.white54)),
                    style: const TextStyle(color: Colors.white),
                    items: _entryStatusOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) => setState(() => _status = v!),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton.icon(onPressed: _pickDate, icon: const Icon(Icons.calendar_today, size: 14), label: Text(_entryDate.toString().substring(0, 10)))),
              ]),
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
