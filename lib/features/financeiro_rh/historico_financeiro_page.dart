import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";

class HistoricoFinanceiroPage extends StatefulWidget {
  final DateTime selectedMonth;
  const HistoricoFinanceiroPage({super.key, required this.selectedMonth});

  @override
  State<HistoricoFinanceiroPage> createState() => _HistoricoFinanceiroPageState();
}

class _HistoricoFinanceiroPageState extends State<HistoricoFinanceiroPage> {
  late Future<List<Map<String, dynamic>>> _future;
  String? _typeFilter;
  bool _filterByMonth = true;

  static const _typeLabels = {
    "salario": "Salario",
    "comissao": "Comissao",
    "ajuda_custo": "Ajuda de Custo",
    "bonificacao": "Bonificacao",
    "premiacao": "Premiacao",
    "despesa": "Despesa",
    "receita": "Receita",
  };

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final client = Supabase.instance.client;
    final rows = await client.from("financial_entries").select("*, managers!financial_entries_manager_id_fkey(login_email)").order("created_at", ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  void _openHistory(Map<String, dynamic> entry) {
    showDialog(context: context, builder: (context) => _EntryHistoryDialog(entry: entry));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Historico Financeiro", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 4),
        const Text("Todos os pagamentos, bonificacoes, comissoes e ajudas de custo. Clique para ver quem alterou e quando.", style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic)),
        const SizedBox(height: 12),
        Row(children: [
          FilterChip(label: const Text("So este mes"), selected: _filterByMonth, selectedColor: Colors.amber, labelStyle: TextStyle(color: _filterByMonth ? Colors.black : Colors.white70), onSelected: (v) => setState(() => _filterByMonth = v)),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 6, children: [
          ChoiceChip(label: const Text("Todos"), selected: _typeFilter == null, selectedColor: Colors.white24, onSelected: (_) => setState(() => _typeFilter = null)),
          ..._typeLabels.entries.map((e) => ChoiceChip(
                label: Text(e.value, style: const TextStyle(fontSize: 11)),
                selected: _typeFilter == e.key,
                selectedColor: Colors.amber,
                labelStyle: TextStyle(color: _typeFilter == e.key ? Colors.black : Colors.white70),
                onSelected: (_) => setState(() => _typeFilter = e.key),
              )),
        ]),
        const SizedBox(height: 12),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              var list = _typeFilter == null ? snapshot.data! : snapshot.data!.where((e) => e["entry_type"] == _typeFilter).toList();
              if (_filterByMonth) {
                list = list.where((e) {
                  final dateStr = (e["due_date"] ?? e["payment_date"] ?? e["created_at"]) as String?;
                  if (dateStr == null) return false;
                  final d = DateTime.parse(dateStr);
                  return d.year == widget.selectedMonth.year && d.month == widget.selectedMonth.month;
                }).toList();
              }
              if (list.isEmpty) return const Center(child: Text("Nenhum lancamento ainda.", style: TextStyle(color: Colors.white54)));
              return ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final e = list[index];
                  final managerData = e["managers"];
                  final statusColor = e["status"] == "pago" ? Colors.greenAccent : e["status"] == "cancelado" ? Colors.white38 : Colors.amber;
                  return Card(
                    color: Colors.white.withOpacity(0.05),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      onTap: () => _openHistory(e),
                      title: Text((e["description"] as String? ?? e["category"] as String? ?? _typeLabels[e["entry_type"]] ?? "-"), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        (_typeLabels[e["entry_type"]] ?? e["entry_type"] as String) +
                            (managerData is Map ? "  -  " + (managerData["login_email"] as String? ?? "") : "") +
                            "  -  " +
                            (e["due_date"] as String? ?? e["created_at"].toString().substring(0, 10)),
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text("R\$ " + (e["amount"] as num).toStringAsFixed(2), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          Text((e["status"] as String).toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
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

class _EntryHistoryDialog extends StatefulWidget {
  final Map<String, dynamic> entry;
  const _EntryHistoryDialog({required this.entry});

  @override
  State<_EntryHistoryDialog> createState() => _EntryHistoryDialogState();
}

class _EntryHistoryDialogState extends State<_EntryHistoryDialog> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final client = Supabase.instance.client;
    final rows = await client.from("financial_entry_history").select("*, managers(login_email)").eq("entry_id", widget.entry["id"]).order("created_at", ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.entry["description"] as String? ?? "-", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text("Historico de alteracoes", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    if (snapshot.data!.isEmpty) return const Text("Sem historico.", style: TextStyle(color: Colors.white38));
                    return ListView.builder(
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) {
                        final h = snapshot.data![index];
                        final performer = h["managers"];
                        final date = DateTime.parse(h["created_at"] as String).toLocal().toString().substring(0, 16);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            date + " - " + (h["action"] as String) + (h["detail"] != null ? ": " + h["detail"] : "") + " (" + (performer is Map ? performer["login_email"] as String? ?? "-" : "-") + ")",
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Fechar"))),
            ],
          ),
        ),
      ),
    );
  }
}

