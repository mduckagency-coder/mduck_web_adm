import "package:flutter/material.dart";
import "package:file_picker/file_picker.dart";
import "package:supabase_flutter/supabase_flutter.dart";

const _expenseCategories = ["Aluguel", "Internet", "Energia", "Contabilidade", "Ferramentas", "Marketing", "Publicidade", "Equipamentos", "Viagens", "Impostos", "Outras despesas"];

class ContasPagarPage extends StatefulWidget {
  final DateTime selectedMonth;
  const ContasPagarPage({super.key, required this.selectedMonth});

  @override
  State<ContasPagarPage> createState() => _ContasPagarPageState();
}

class _ContasPagarPageState extends State<ContasPagarPage> {
  late Future<List<Map<String, dynamic>>> _future;
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    _future = _loadWithRecurrence();
  }

  @override
  void didUpdateWidget(ContasPagarPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedMonth != widget.selectedMonth) setState(() {});
  }

  Future<List<Map<String, dynamic>>> _loadWithRecurrence() async {
    await _generateRecurringEntries();
    return _load();
  }

  Future<void> _generateRecurringEntries() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;
    final now = DateTime.now();
    final recurring = await client.from("financial_entries").select().eq("entry_type", "despesa").eq("is_recurring", true);

    for (final e in (recurring as List)) {
      final recurrenceDay = e["recurrence_day"] as int?;
      if (recurrenceDay == null) continue;
      final nextDue = DateTime(now.year, now.month, recurrenceDay);
      final exists = await client
          .from("financial_entries")
          .select("id")
          .eq("entry_type", "despesa")
          .eq("supplier", e["supplier"] ?? "")
          .eq("category", e["category"] ?? "")
          .eq("due_date", nextDue.toIso8601String().substring(0, 10))
          .maybeSingle();
      if (exists == null && !now.isBefore(nextDue.subtract(const Duration(days: 5)))) {
        final manager = await client.from("managers").select("agency_id").eq("id", userId).single();
        await client.from("financial_entries").insert({
          "agency_id": manager["agency_id"],
          "entry_type": "despesa",
          "category": e["category"],
          "supplier": e["supplier"],
          "description": e["description"],
          "amount": e["amount"],
          "due_date": nextDue.toIso8601String().substring(0, 10),
          "status": "pendente",
          "is_recurring": true,
          "recurrence_day": recurrenceDay,
          "created_by": userId,
        });
      }
    }
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final client = Supabase.instance.client;
    final rows = await client.from("financial_entries").select().eq("entry_type", "despesa").order("due_date");
    return (rows as List).cast<Map<String, dynamic>>();
  }

  void _openForm({Map<String, dynamic>? existing}) {
    showDialog(context: context, builder: (context) => _ExpenseFormDialog(existing: existing)).then((saved) {
      if (saved == true) setState(() => _future = _load());
    });
  }

  Future<void> _markPaid(String id) async {
    final client = Supabase.instance.client;
    await client.from("financial_entries").update({"status": "pago", "payment_date": DateTime.now().toIso8601String().substring(0, 10)}).eq("id", id);
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text("Contas a Pagar - " + widget.selectedMonth.month.toString().padLeft(2, "0") + "/" + widget.selectedMonth.year.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () => _openForm(),
            icon: const Icon(Icons.add, size: 16),
            label: const Text("Nova Despesa"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
          ),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 6, children: [
          ChoiceChip(label: const Text("Todas"), selected: _statusFilter == null, selectedColor: Colors.white24, onSelected: (_) => setState(() => _statusFilter = null)),
          ChoiceChip(label: const Text("Pendente"), selected: _statusFilter == "pendente", selectedColor: Colors.amber, onSelected: (_) => setState(() => _statusFilter = "pendente")),
          ChoiceChip(label: const Text("Pago"), selected: _statusFilter == "pago", selectedColor: Colors.greenAccent, onSelected: (_) => setState(() => _statusFilter = "pago")),
          ChoiceChip(label: const Text("Atrasado"), selected: _statusFilter == "atrasado", selectedColor: Colors.redAccent, onSelected: (_) => setState(() => _statusFilter = "atrasado")),
        ]),
        const SizedBox(height: 12),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final now = DateTime.now();
              final list = snapshot.data!.where((e) {
                if (e["due_date"] == null) return false;
                final due = DateTime.parse(e["due_date"]);
                if (due.year != widget.selectedMonth.year || due.month != widget.selectedMonth.month) return false;
                if (_statusFilter == null) return true;
                if (_statusFilter == "atrasado") {
                  return e["status"] == "pendente" && DateTime.parse(e["due_date"]).isBefore(DateTime(now.year, now.month, now.day));
                }
                return e["status"] == _statusFilter;
              }).toList();
              if (list.isEmpty) return const Center(child: Text("Nenhuma despesa cadastrada ainda.", style: TextStyle(color: Colors.white54)));
              return ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final e = list[index];
                  final isLate = e["status"] == "pendente" && e["due_date"] != null && DateTime.parse(e["due_date"]).isBefore(DateTime(now.year, now.month, now.day));
                  final statusColor = e["status"] == "pago" ? Colors.greenAccent : isLate ? Colors.redAccent : Colors.amber;
                  return Card(
                    color: Colors.white.withOpacity(0.05),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      onTap: () => _openForm(existing: e),
                      title: Row(children: [
                        Expanded(child: Text((e["description"] as String? ?? e["category"] as String? ?? "-"), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        if (e["is_recurring"] == true) const Icon(Icons.repeat, color: Colors.white38, size: 14),
                      ]),
                      subtitle: Text(
                        (e["category"] as String? ?? "-") + "  -  " + (e["supplier"] as String? ?? "-") + "  -  Vence: " + (e["due_date"] as String? ?? "-"),
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text("R\$ " + (e["amount"] as num).toStringAsFixed(2), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(border: Border.all(color: statusColor), borderRadius: BorderRadius.circular(4)),
                            child: Text(isLate ? "ATRASADO" : (e["status"] as String).toUpperCase(), style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold)),
                          ),
                          if (e["status"] != "pago")
                            TextButton(onPressed: () => _markPaid(e["id"] as String), child: const Text("Marcar pago", style: TextStyle(fontSize: 11))),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ExpenseFormDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const _ExpenseFormDialog({this.existing});

  @override
  State<_ExpenseFormDialog> createState() => _ExpenseFormDialogState();
}

class _ExpenseFormDialogState extends State<_ExpenseFormDialog> {
  String _category = _expenseCategories.first;
  final _supplierController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _dueDate = DateTime.now();
  String _status = "pendente";
  bool _isRecurring = false;
  int _recurrenceDay = 5;
  String? _receiptUrl;
  bool _uploading = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _category = e["category"] ?? _category;
      _supplierController.text = e["supplier"] ?? "";
      _descriptionController.text = e["description"] ?? "";
      _amountController.text = (e["amount"] as num).toString();
      _notesController.text = e["notes"] ?? "";
      _dueDate = e["due_date"] != null ? DateTime.parse(e["due_date"]) : DateTime.now();
      _status = e["status"] ?? "pendente";
      _isRecurring = e["is_recurring"] ?? false;
      _recurrenceDay = e["recurrence_day"] ?? 5;
      _receiptUrl = e["receipt_url"];
    }
  }

  Future<void> _uploadReceipt() async {
    setState(() => _uploading = true);
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty || result.files.first.bytes == null) {
      setState(() => _uploading = false);
      return;
    }
    final file = result.files.first;
    final client = Supabase.instance.client;
    final path = DateTime.now().millisecondsSinceEpoch.toString() + "_" + file.name;
    try {
      await client.storage.from("material_attachments").uploadBinary(path, file.bytes!);
      final url = client.storage.from("material_attachments").getPublicUrl(path);
      setState(() {
        _receiptUrl = url;
        _uploading = false;
      });
    } catch (e) {
      setState(() => _uploading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao enviar: " + e.toString())));
    }
  }

  Future<void> _save() async {
    if (_amountController.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;
    final manager = await client.from("managers").select("agency_id").eq("id", userId).single();

    final data = {
      "agency_id": manager["agency_id"],
      "entry_type": "despesa",
      "category": _category,
      "supplier": _supplierController.text.trim(),
      "description": _descriptionController.text.trim(),
      "amount": double.tryParse(_amountController.text) ?? 0,
      "due_date": _dueDate.toIso8601String().substring(0, 10),
      "status": _status,
      "payment_date": _status == "pago" ? DateTime.now().toIso8601String().substring(0, 10) : null,
      "is_recurring": _isRecurring,
      "recurrence_day": _isRecurring ? _recurrenceDay : null,
      "receipt_url": _receiptUrl,
      "notes": _notesController.text.trim(),
      "created_by": userId,
    };

    if (widget.existing != null) {
      await client.from("financial_entries").update(data).eq("id", widget.existing!["id"]);
    } else {
      await client.from("financial_entries").insert(data);
    }

    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 700),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.existing != null ? "Editar despesa" : "Nova despesa", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                DropdownButton<String>(
                  value: _category,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF1A1A1A),
                  style: const TextStyle(color: Colors.white),
                  items: _expenseCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setState(() => _category = v!),
                ),
                const SizedBox(height: 8),
                TextField(controller: _supplierController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Fornecedor", labelStyle: TextStyle(color: Colors.white54))),
                const SizedBox(height: 8),
                TextField(controller: _descriptionController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Descricao", labelStyle: TextStyle(color: Colors.white54))),
                const SizedBox(height: 8),
                TextField(controller: _amountController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Valor R\$", labelStyle: TextStyle(color: Colors.white54))),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final picked = await showDatePicker(context: context, initialDate: _dueDate, firstDate: DateTime(2020), lastDate: DateTime(2100));
                        if (picked != null) setState(() => _dueDate = picked);
                      },
                      child: Text("Vencimento: " + _dueDate.toIso8601String().substring(0, 10)),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                DropdownButton<String>(
                  value: _status,
                  dropdownColor: const Color(0xFF1A1A1A),
                  style: const TextStyle(color: Colors.white),
                  items: const [
                    DropdownMenuItem(value: "pendente", child: Text("Pendente")),
                    DropdownMenuItem(value: "pago", child: Text("Pago")),
                    DropdownMenuItem(value: "cancelado", child: Text("Cancelado")),
                  ],
                  onChanged: (v) => setState(() => _status = v!),
                ),
                SwitchListTile(
                  value: _isRecurring,
                  onChanged: (v) => setState(() => _isRecurring = v),
                  title: const Text("Despesa recorrente (gera lancamento todo mes)", style: TextStyle(color: Colors.white, fontSize: 13)),
                  activeColor: Colors.amber,
                  contentPadding: EdgeInsets.zero,
                ),
                if (_isRecurring)
                  TextField(
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: "Todo dia (1-28)", labelStyle: TextStyle(color: Colors.white54)),
                    controller: TextEditingController(text: _recurrenceDay.toString()),
                    onChanged: (v) => _recurrenceDay = int.tryParse(v) ?? _recurrenceDay,
                  ),
                const SizedBox(height: 8),
                TextField(controller: _notesController, maxLines: 2, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Observacoes", labelStyle: TextStyle(color: Colors.white54))),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _uploading ? null : _uploadReceipt,
                  icon: const Icon(Icons.attach_file, size: 16),
                  label: Text(_uploading ? "Enviando..." : (_receiptUrl != null ? "Comprovante anexado" : "Anexar comprovante")),
                ),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancelar")),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                    child: Text(_saving ? "Salvando..." : "Salvar"),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

