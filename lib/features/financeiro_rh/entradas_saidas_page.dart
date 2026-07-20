import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "money_utils.dart";

const _entryIcons = {
  "receita": Icons.attach_money,
  "despesa": Icons.shopping_cart_outlined,
  "salario": Icons.badge_outlined,
  "comissao": Icons.percent,
  "ajuda_custo": Icons.directions_car_filled_outlined,
  "bonificacao": Icons.card_giftcard,
  "premiacao": Icons.emoji_events_outlined,
  "indicacao": Icons.record_voice_over_outlined,
};

const _entryLabels = {
  "receita": "Receita",
  "despesa": "Despesa",
  "salario": "Salario",
  "comissao": "Comissao",
  "ajuda_custo": "Ajuda de Custo",
  "bonificacao": "Bonificacao",
  "premiacao": "Premiacao",
  "indicacao": "Indicacao",
};

const _expenseCategories = ["Equipe / Colaborador", "Aluguel", "Internet", "Energia", "Contabilidade", "Ferramentas", "Marketing", "Publicidade", "Equipamentos", "Viagens", "Impostos", "Outras despesas"];
const _customCategorySentinel = "__custom__";

bool _isEntrada(Map<String, dynamic> e) => e["entry_type"] == "receita";

class EntradasSaidasPage extends StatefulWidget {
  final DateTime selectedMonth;
  const EntradasSaidasPage({super.key, required this.selectedMonth});

  @override
  State<EntradasSaidasPage> createState() => _EntradasSaidasPageState();
}

class _EntradasSaidasPageState extends State<EntradasSaidasPage> {
  late Future<List<Map<String, dynamic>>> _future;
  String _filter = "todas";
  bool _filterByMonth = true;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(EntradasSaidasPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedMonth != widget.selectedMonth) setState(() {});
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final client = Supabase.instance.client;
    final rows = await client.from("financial_entries").select("*, managers!financial_entries_manager_id_fkey(login_email), external_collaborators(full_name)").order("due_date", ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  void _openForm({Map<String, dynamic>? existing}) {
    showDialog(context: context, builder: (context) => _EntryFormDialog(existing: existing)).then((saved) {
      if (saved == true) setState(() => _future = _load());
    });
  }

  Future<void> _markReceived(String id) async {
    final client = Supabase.instance.client;
    await client.from("financial_entries").update({"status": "pago", "payment_date": DateTime.now().toIso8601String().substring(0, 10)}).eq("id", id);
    setState(() => _future = _load());
  }

  String _personLabel(Map<String, dynamic> e) {
    final managerData = e["managers"];
    final externalData = e["external_collaborators"];
    if (managerData is Map) return managerData["login_email"] as String? ?? "";
    if (externalData is Map) return externalData["full_name"] as String? ?? "";
    return "";
  }

  Widget _column({required String title, required Color color, required List<Map<String, dynamic>> items, required bool isEntrada}) {
    final total = items.fold(0.0, (s, e) => s + (e["amount"] as num).toDouble());
    return Expanded(
      child: Container(
        decoration: BoxDecoration(color: color.withOpacity(0.06), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withOpacity(0.4))),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(isEntrada ? Icons.arrow_upward : Icons.arrow_downward, color: color, size: 16),
              const SizedBox(width: 6),
              Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
              const Spacer(),
              Text("R\$ " + total.toStringAsFixed(2), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
            ]),
            const Divider(color: Colors.white12),
            if (items.isEmpty)
              Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Text("Nenhum lancamento.", style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)))
            else
              ...items.map((e) {
                final isLate = e["status"] == "pendente" && e["due_date"] != null && DateTime.parse(e["due_date"]).isBefore(DateTime.now());
                final statusColor = e["status"] == "pago" ? Colors.greenAccent : e["status"] == "cancelado" ? Colors.white38 : isLate ? Colors.redAccent : Colors.amber;
                final personLabel = _personLabel(e);
                return InkWell(
                  onTap: () => _openForm(existing: e),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      Icon(_entryIcons[e["entry_type"]] ?? Icons.receipt_long, color: color, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text((e["description"] as String? ?? e["category"] as String? ?? _entryLabels[e["entry_type"]] ?? "-"), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text(
                              (_entryLabels[e["entry_type"]] ?? "-") + (personLabel.isNotEmpty ? "  -  " + personLabel : "") + "  -  " + (e["due_date"] as String? ?? "-"),
                              style: const TextStyle(color: Colors.white54, fontSize: 10),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text("R\$ " + (e["amount"] as num).toStringAsFixed(2), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          Text((isLate ? "ATRASADO" : (e["status"] as String).toUpperCase()), style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      if (isEntrada && e["status"] != "pago" && e["status"] != "cancelado")
                        IconButton(icon: const Icon(Icons.check_circle_outline, size: 16), color: Colors.greenAccent, tooltip: "Marcar recebido", onPressed: () => _markReceived(e["id"] as String)),
                    ]),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Text("Entradas e Saidas", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () => _openForm(),
            icon: const Icon(Icons.add, size: 16),
            label: const Text("Novo Lancamento"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
          ),
        ]),
        const SizedBox(height: 4),
        const Text("Visao lado a lado de tudo que entra e sai, como uma planilha. Clique num item para editar ou excluir.", style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic)),
        const SizedBox(height: 12),
        Row(children: [
          FilterChip(label: const Text("So este mes"), selected: _filterByMonth, selectedColor: Colors.amber, labelStyle: TextStyle(color: _filterByMonth ? Colors.black : Colors.white70), onSelected: (v) => setState(() => _filterByMonth = v)),
          const SizedBox(width: 8),
          ChoiceChip(label: const Text("Ambas"), selected: _filter == "todas", selectedColor: Colors.white24, onSelected: (_) => setState(() => _filter = "todas")),
          const SizedBox(width: 6),
          ChoiceChip(label: const Text("So Entradas"), selected: _filter == "entradas", selectedColor: Colors.greenAccent, labelStyle: TextStyle(color: _filter == "entradas" ? Colors.black : Colors.white70), onSelected: (_) => setState(() => _filter = "entradas")),
          const SizedBox(width: 6),
          ChoiceChip(label: const Text("So Saidas"), selected: _filter == "saidas", selectedColor: Colors.redAccent, labelStyle: TextStyle(color: _filter == "saidas" ? Colors.black : Colors.white70), onSelected: (_) => setState(() => _filter = "saidas")),
        ]),
        const SizedBox(height: 12),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text("Erro ao carregar: " + snapshot.error.toString(), style: const TextStyle(color: Colors.redAccent)));
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final filtered = snapshot.data!.where((e) {
                if (!_filterByMonth) return true;
                final dateStr = (e["due_date"] ?? e["payment_date"] ?? e["created_at"]) as String?;
                if (dateStr == null) return false;
                final d = DateTime.parse(dateStr);
                return d.year == widget.selectedMonth.year && d.month == widget.selectedMonth.month;
              }).toList();
              final entradas = filtered.where(_isEntrada).toList();
              final saidas = filtered.where((e) => !_isEntrada(e)).toList();

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_filter != "saidas") _column(title: "Entradas", color: Colors.greenAccent, items: entradas, isEntrada: true),
                  if (_filter == "todas") const SizedBox(width: 12),
                  if (_filter != "entradas") _column(title: "Saidas", color: Colors.redAccent, items: saidas, isEntrada: false),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Single form that creates or edits either an "entrada" (receita) or a
/// "saida" (despesa) financial_entries row, chosen via the toggle at the top.
class _EntryFormDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const _EntryFormDialog({this.existing});

  @override
  State<_EntryFormDialog> createState() => _EntryFormDialogState();
}

class _EntryFormDialogState extends State<_EntryFormDialog> {
  final _sourceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _customCategoryController = TextEditingController();
  String _direction = "entrada";
  String _category = _expenseCategories.first;
  DateTime _dueDate = DateTime.now();
  String _status = "pendente";
  bool _isRecurring = false;
  int _recurrenceDay = 5;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _direction = e["entry_type"] == "receita" ? "entrada" : "saida";
      _sourceController.text = (e["supplier"] as String?) ?? "";
      _descriptionController.text = (e["description"] as String?) ?? "";
      _amountController.text = (e["amount"] as num).toString();
      _notesController.text = (e["notes"] as String?) ?? "";
      _dueDate = e["due_date"] != null ? DateTime.parse(e["due_date"]) : DateTime.now();
      _status = (e["status"] as String?) ?? "pendente";
      final existingCategory = e["category"] as String?;
      if (existingCategory != null && !_expenseCategories.contains(existingCategory)) {
        _category = _customCategorySentinel;
        _customCategoryController.text = existingCategory;
      } else {
        _category = existingCategory ?? _category;
      }
      _isRecurring = e["is_recurring"] as bool? ?? false;
      _recurrenceDay = (e["recurrence_day"] as int?) ?? 5;
    }
  }

  Future<void> _save() async {
    if (_amountController.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;
    final manager = await client.from("managers").select("agency_id").eq("id", userId).single();
    final isEntrada = _direction == "entrada";

    final data = {
      "agency_id": manager["agency_id"],
      "entry_type": isEntrada ? "receita" : "despesa",
      "category": isEntrada ? null : (_category == _customCategorySentinel ? _customCategoryController.text.trim() : _category),
      "supplier": _sourceController.text.trim(),
      "description": _descriptionController.text.trim(),
      "amount": parseAmount(_amountController.text),
      "due_date": _dueDate.toIso8601String().substring(0, 10),
      "payment_date": _status == "pago" ? DateTime.now().toIso8601String().substring(0, 10) : null,
      "status": _status,
      "is_recurring": isEntrada ? false : _isRecurring,
      "recurrence_day": (!isEntrada && _isRecurring) ? _recurrenceDay : null,
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

  Future<void> _delete() async {
    setState(() => _saving = true);
    final client = Supabase.instance.client;
    await client.from("financial_entries").delete().eq("id", widget.existing!["id"]);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final isEntrada = _direction == "entrada";
    final isEditing = widget.existing != null;
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 700),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isEditing ? "Editar lancamento" : "Novo lancamento", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text("Entrada"),
                      selected: isEntrada,
                      selectedColor: Colors.greenAccent,
                      labelStyle: TextStyle(color: isEntrada ? Colors.black : Colors.white70, fontWeight: FontWeight.bold),
                      onSelected: (_) => setState(() => _direction = "entrada"),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text("Saida"),
                      selected: !isEntrada,
                      selectedColor: Colors.redAccent,
                      labelStyle: TextStyle(color: !isEntrada ? Colors.black : Colors.white70, fontWeight: FontWeight.bold),
                      onSelected: (_) => setState(() => _direction = "saida"),
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                if (!isEntrada) ...[
                  DropdownButton<String>(
                    value: _category,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF1A1A1A),
                    style: const TextStyle(color: Colors.white),
                    items: [
                      ..._expenseCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                      const DropdownMenuItem(value: _customCategorySentinel, child: Text("+ Nova categoria")),
                    ],
                    onChanged: (v) => setState(() => _category = v!),
                  ),
                  if (_category == _customCategorySentinel) ...[
                    const SizedBox(height: 8),
                    TextField(controller: _customCategoryController, autofocus: true, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Nome da categoria", labelStyle: TextStyle(color: Colors.white54))),
                  ],
                  const SizedBox(height: 8),
                ],
                TextField(controller: _sourceController, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: isEntrada ? "Origem / Cliente" : "Fornecedor", labelStyle: const TextStyle(color: Colors.white54))),
                const SizedBox(height: 8),
                TextField(controller: _descriptionController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Descricao", labelStyle: TextStyle(color: Colors.white54))),
                const SizedBox(height: 8),
                TextField(controller: _amountController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Valor R\$", labelStyle: TextStyle(color: Colors.white54))),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () async {
                    final picked = await showDatePicker(context: context, initialDate: _dueDate, firstDate: DateTime(2020), lastDate: DateTime(2100));
                    if (picked != null) setState(() => _dueDate = picked);
                  },
                  child: Text((isEntrada ? "Previsao: " : "Vencimento: ") + _dueDate.toIso8601String().substring(0, 10)),
                ),
                const SizedBox(height: 8),
                DropdownButton<String>(
                  value: _status,
                  dropdownColor: const Color(0xFF1A1A1A),
                  style: const TextStyle(color: Colors.white),
                  items: [
                    const DropdownMenuItem(value: "pendente", child: Text("Pendente")),
                    DropdownMenuItem(value: "pago", child: Text(isEntrada ? "Recebido" : "Pago")),
                    const DropdownMenuItem(value: "cancelado", child: Text("Cancelado")),
                  ],
                  onChanged: (v) => setState(() => _status = v!),
                ),
                if (!isEntrada) ...[
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
                ],
                const SizedBox(height: 8),
                TextField(controller: _notesController, maxLines: 2, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Observacoes", labelStyle: TextStyle(color: Colors.white54))),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: isEditing ? MainAxisAlignment.spaceBetween : MainAxisAlignment.end, children: [
                  if (isEditing)
                    TextButton(onPressed: _saving ? null : _delete, child: const Text("Excluir", style: TextStyle(color: Colors.redAccent))),
                  Row(children: [
                    TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancelar")),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                      child: Text(_saving ? "Salvando..." : "Salvar"),
                    ),
                  ]),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
