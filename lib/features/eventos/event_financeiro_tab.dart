import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "event_history_service.dart";

String _awardStatusLabelLocal(String status) {
  switch (status) {
    case "agendado":
      return "Agendado";
    case "pago":
      return "Pago";
    default:
      return "Pendente";
  }
}

/// Aceita tanto "5000" / "5000.50" quanto o formato BR "5.000,50" (ponto de
/// milhar + virgula decimal). Se tiver virgula, ela e o separador decimal --
/// remove os pontos (milhar) antes de converter; sem virgula, o ponto (se
/// houver) e tratado como decimal direto.
double? _parseCurrency(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  if (trimmed.contains(",")) {
    return double.tryParse(trimmed.replaceAll(".", "").replaceAll(",", "."));
  }
  return double.tryParse(trimmed);
}

double _awardTotal(Map<String, dynamic> award) {
  final items = (award["items"] as List?) ?? const [];
  var total = 0.0;
  for (final it in items) {
    final value = it is Map ? it["value"] as num? : null;
    if (value != null) total += value.toDouble();
  }
  return total;
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

  /// Financeiro do evento agora e so orcamento vs. gasto em premiacoes --
  /// o gasto e calculado direto dos valores preenchidos na aba Premiacoes
  /// (soma de items[].value de todo event_awards do evento), sem lancamento
  /// manual duplicado. O antigo controle de despesas/compras/patrocinios
  /// foi removido desta aba.
  Future<Map<String, dynamic>> _load() async {
    final client = Supabase.instance.client;
    final budget = await client.from("event_budget").select().eq("event_id", widget.eventId).maybeSingle();
    final awards = await client.from("event_awards").select("name, items, status").eq("event_id", widget.eventId).order("created_at");
    return {"budget": budget, "awards": (awards as List).cast<Map<String, dynamic>>()};
  }

  void _reload() => setState(() { _future = _load(); });

  Future<void> _editBudget(double current) async {
    final controller = TextEditingController(text: current == 0 ? "" : current.toStringAsFixed(2).replaceAll(".", ","));
    String? error;
    final value = await showDialog<double>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: const Color(0xFF1A1A1A),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Orcamento do evento", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(labelText: "Valor R\$", labelStyle: const TextStyle(color: Colors.white54), errorText: error, helperText: "Ex: 5000 ou 5.000,00", helperStyle: const TextStyle(color: Colors.white38)),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () {
                      final parsed = _parseCurrency(controller.text);
                      if (parsed == null) {
                        setDialogState(() => error = "Valor invalido.");
                        return;
                      }
                      Navigator.of(context).pop(parsed);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
                    child: const Text("Salvar"),
                  ),
                ),
              ],
            ),
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

  Widget _summaryCard(String label, String value, Color color) {
    return Container(
      width: 130,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: color)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
          const SizedBox(height: 3),
          Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
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
          final awards = snapshot.data!["awards"] as List<Map<String, dynamic>>;
          final budgetAmount = (budget?["budget_amount"] as num?)?.toDouble() ?? 0;

          final awardsSpent = awards.fold<double>(0, (sum, a) => sum + _awardTotal(a));
          final saldo = budgetAmount - awardsSpent;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Text("Financeiro", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                OutlinedButton.icon(onPressed: () => _editBudget(budgetAmount), icon: const Icon(Icons.edit, size: 14), label: const Text("Definir orcamento")),
              ]),
              const SizedBox(height: 4),
              const Text(
                "O gasto em premiacoes e calculado automaticamente a partir dos valores preenchidos na aba Premiacoes.",
                style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 16),
              Wrap(spacing: 12, runSpacing: 12, children: [
                _summaryCard("Orcamento", "R\$ " + budgetAmount.toStringAsFixed(2), const Color(0xFF7A0BD4)),
                _summaryCard("Gasto em Premiacoes", "R\$ " + awardsSpent.toStringAsFixed(2), Colors.amber),
                _summaryCard("Saldo disponivel", "R\$ " + saldo.toStringAsFixed(2), saldo >= 0 ? Colors.greenAccent : Colors.redAccent),
              ]),
              const SizedBox(height: 16),
              const Text("Premiacoes que compoem o gasto", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              Expanded(
                child: awards.isEmpty
                    ? const Center(child: Text("Nenhuma premiacao cadastrada ainda. Cadastre em Premiacoes para ver o gasto aqui.", style: TextStyle(color: Colors.white54), textAlign: TextAlign.center))
                    : ListView.builder(
                        itemCount: awards.length,
                        itemBuilder: (context, index) {
                          final award = awards[index];
                          final total = _awardTotal(award);
                          return Card(
                            color: Colors.white.withOpacity(0.05),
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(award["name"] as String, style: const TextStyle(color: Colors.white)),
                              subtitle: Text(_awardStatusLabelLocal(award["status"] as String), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                              trailing: Text("R\$ " + total.toStringAsFixed(2), style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
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
