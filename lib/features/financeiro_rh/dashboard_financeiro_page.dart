import "package:flutter/material.dart";
import "package:fl_chart/fl_chart.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "payroll_generation.dart";

String _periodKey(DateTime d) => d.year.toString() + "-" + d.month.toString().padLeft(2, "0");

class VisaoGeralFinanceiroPage extends StatefulWidget {
  final DateTime selectedMonth;
  final void Function(String tab)? onNavigate;
  const VisaoGeralFinanceiroPage({super.key, required this.selectedMonth, this.onNavigate});

  @override
  State<VisaoGeralFinanceiroPage> createState() => _VisaoGeralFinanceiroPageState();
}

class _VisaoGeralFinanceiroPageState extends State<VisaoGeralFinanceiroPage> {
  late Future<Map<String, dynamic>> _future;
  bool _showDespesaDetail = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(VisaoGeralFinanceiroPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedMonth != widget.selectedMonth) {
      setState(() => _future = _load());
    }
  }

  Future<Map<String, dynamic>> _load() async {
    await generateMonthlyPayrollEntries();
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;
    final manager = await client.from("managers").select("agency_id").eq("id", userId).single();
    final agencyId = manager["agency_id"] as String;
    final now = widget.selectedMonth;
    final currentKey = _periodKey(now);

    final rows = await client.from("financial_entries").select();
    final entries = (rows as List).cast<Map<String, dynamic>>();

    bool isThisMonth(Map<String, dynamic> e, String dateField) {
      final d = e[dateField];
      if (d == null) return false;
      final date = DateTime.parse(d);
      return date.year == now.year && date.month == now.month;
    }

    double sumWhere(bool Function(Map<String, dynamic>) test) {
      return entries.where(test).fold(0.0, (sum, e) => sum + (e["amount"] as num).toDouble());
    }

    final entradasMes = sumWhere((e) => e["entry_type"] == "receita" && isThisMonth(e, "payment_date"));
    final folhaTypes = {"salario", "comissao", "ajuda_custo", "bonificacao", "premiacao", "indicacao"};
    final folhaMes = sumWhere((e) => folhaTypes.contains(e["entry_type"]) && isThisMonth(e, "due_date"));
    final despesasFixasMes = sumWhere((e) => e["entry_type"] == "despesa" && e["is_recurring"] == true && isThisMonth(e, "due_date"));
    final despesasVariaveisMes = sumWhere((e) => e["entry_type"] == "despesa" && e["is_recurring"] != true && isThisMonth(e, "due_date"));
    final despesasMes = despesasFixasMes + despesasVariaveisMes;
    final saidasMes = folhaMes + despesasMes;
    final lucroPrevisto = entradasMes - saidasMes;

    final totalReceitasPagas = sumWhere((e) => e["entry_type"] == "receita" && e["status"] == "pago");
    final totalSaidasPagas = sumWhere((e) => e["entry_type"] != "receita" && e["status"] == "pago");
    final saldoAtual = totalReceitasPagas - totalSaidasPagas;

    final pagamentosPendentes = entries.where((e) => e["entry_type"] != "receita" && e["status"] == "pendente").toList();
    final today = DateTime.now();
    final pagamentosVencidos = pagamentosPendentes.where((e) {
      if (e["due_date"] == null) return false;
      return DateTime.parse(e["due_date"]).isBefore(DateTime(today.year, today.month, today.day));
    }).toList();

    final monthly = <String, Map<String, double>>{};
    for (var i = 5; i >= 0; i--) {
      final m = DateTime(now.year, now.month - i);
      final key = m.month.toString().padLeft(2, "0") + "/" + m.year.toString();
      monthly[key] = {"entradas": 0, "saidas": 0};
    }
    for (final e in entries) {
      final dateField = e["entry_type"] == "receita" ? "payment_date" : "due_date";
      if (e[dateField] == null) continue;
      final d = DateTime.parse(e[dateField]);
      final key = d.month.toString().padLeft(2, "0") + "/" + d.year.toString();
      if (!monthly.containsKey(key)) continue;
      if (e["entry_type"] == "receita") {
        monthly[key]!["entradas"] = monthly[key]!["entradas"]! + (e["amount"] as num).toDouble();
      } else {
        monthly[key]!["saidas"] = monthly[key]!["saidas"]! + (e["amount"] as num).toDouble();
      }
    }

    // Modulo Financeiro (campanhas/missoes/orcamento)
    final rewards = await client.from("campaign_rewards").select("value, agency_campaigns(start_date)");
    final missions = await client.from("missions").select("reward_value, starts_at, created_at");
    final budgets = await client.from("agency_budgets").select().eq("agency_id", agencyId).eq("period_key", currentKey).maybeSingle();
    double gastoCampanhasMes = 0;
    for (final r in (rewards as List)) {
      final campaign = r["agency_campaigns"];
      if (campaign is Map && campaign["start_date"] != null) {
        if (_periodKey(DateTime.parse(campaign["start_date"])) == currentKey) {
          gastoCampanhasMes += (r["value"] as num?)?.toDouble() ?? 0;
        }
      }
    }
    for (final m in (missions as List)) {
      final dateStr = m["starts_at"] ?? m["created_at"];
      if (dateStr != null && _periodKey(DateTime.parse(dateStr)) == currentKey) {
        gastoCampanhasMes += (m["reward_value"] as num?)?.toDouble() ?? 0;
      }
    }
    final orcamentoCampanhasMes = (budgets?["budget"] as num?)?.toDouble() ?? 0;

    // Modulo comissoes de recrutamento
    final compensations = await client.from("recruiter_compensation").select("amount, payment_date, created_at");
    double comissoesRecrutamentoMes = 0;
    for (final c in (compensations as List)) {
      final dateStr = c["payment_date"] ?? c["created_at"];
      if (dateStr != null && _periodKey(DateTime.parse(dateStr)) == currentKey) {
        comissoesRecrutamentoMes += (c["amount"] as num?)?.toDouble() ?? 0;
      }
    }

    return {
      "saldoAtual": saldoAtual,
      "entradasMes": entradasMes,
      "saidasMes": saidasMes,
      "lucroPrevisto": lucroPrevisto,
      "despesasFixasMes": despesasFixasMes,
      "despesasVariaveisMes": despesasVariaveisMes,
      "despesasMes": despesasMes,
      "folhaMes": folhaMes,
      "pagamentosPendentes": pagamentosPendentes.length,
      "pagamentosPendentesValor": pagamentosPendentes.fold(0.0, (s, e) => s + (e["amount"] as num).toDouble()),
      "pagamentosVencidos": pagamentosVencidos.length,
      "pagamentosVencidosValor": pagamentosVencidos.fold(0.0, (s, e) => s + (e["amount"] as num).toDouble()),
      "monthly": monthly,
      "gastoCampanhasMes": gastoCampanhasMes,
      "orcamentoCampanhasMes": orcamentoCampanhasMes,
      "comissoesRecrutamentoMes": comissoesRecrutamentoMes,
    };
  }

  String _fmt(num v) => "R\$ " + v.toStringAsFixed(2);

  Widget _card(String label, String value, Color color, IconData icon) {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withOpacity(0.18), Colors.white.withOpacity(0.03)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, color: color, size: 18), const SizedBox(width: 6), Expanded(child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)))]),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _moduleCard(String title, String subtitle, Color color, IconData icon, String tab) {
    return InkWell(
      onTap: widget.onNavigate == null ? null : () => widget.onNavigate!(tab),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 250,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withOpacity(0.4))),
        child: Row(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          if (widget.onNavigate != null) const Icon(Icons.chevron_right, color: Colors.white38, size: 18),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("Erro ao carregar: " + snapshot.error.toString(), style: const TextStyle(color: Colors.redAccent)));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final d = snapshot.data!;
        final monthly = (d["monthly"] as Map<String, Map<String, double>>);

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(spacing: 12, runSpacing: 12, children: [
                _card("Saldo Atual", _fmt(d["saldoAtual"]), d["saldoAtual"] >= 0 ? Colors.greenAccent : Colors.redAccent, Icons.account_balance_wallet),
                _card("Entradas do Mes", _fmt(d["entradasMes"]), Colors.greenAccent, Icons.trending_up),
                _card("Saidas do Mes", _fmt(d["saidasMes"]), Colors.redAccent, Icons.trending_down),
                _card("Lucro Previsto", _fmt(d["lucroPrevisto"]), d["lucroPrevisto"] >= 0 ? Colors.tealAccent : Colors.orangeAccent, Icons.insights),
                _card("Pagamentos Pendentes", d["pagamentosPendentes"].toString() + " (" + _fmt(d["pagamentosPendentesValor"]) + ")", Colors.amber, Icons.hourglass_bottom),
                _card("Pagamentos Vencidos", d["pagamentosVencidos"].toString() + " (" + _fmt(d["pagamentosVencidosValor"]) + ")", Colors.redAccent, Icons.warning_amber),
              ]),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => setState(() => _showDespesaDetail = !_showDespesaDetail),
                icon: Icon(_showDespesaDetail ? Icons.expand_less : Icons.expand_more, size: 16),
                label: Text("Detalhe de despesas (" + _fmt(d["despesasMes"]) + ")"),
              ),
              if (_showDespesaDetail)
                Padding(
                  padding: const EdgeInsets.only(left: 12, bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Fixas: " + _fmt(d["despesasFixasMes"]), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      Text("Variaveis: " + _fmt(d["despesasVariaveisMes"]), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      Text("Folha (salario/comissao/ajuda de custo/bonificacao/premiacao/indicacao): " + _fmt(d["folhaMes"]), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              const Text("Por modulo", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 12),
              Wrap(spacing: 12, runSpacing: 12, children: [
                _moduleCard("RH / Folha", _fmt(d["folhaMes"]) + " este mes", const Color(0xFF7A0BD4), Icons.badge, "equipe"),
                _moduleCard(
                  "Financeiro (Campanhas)",
                  _fmt(d["gastoCampanhasMes"]) + " de " + _fmt(d["orcamentoCampanhasMes"]),
                  Colors.blueAccent,
                  Icons.campaign,
                  "equipe",
                ),
                _moduleCard("Comissoes de Recrutamento", _fmt(d["comissoesRecrutamentoMes"]) + " este mes", Colors.orangeAccent, Icons.groups, "equipe"),
              ]),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Evolucao Mensal (Entradas x Saidas)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 220,
                      child: BarChart(
                        BarChartData(
                          barTouchData: BarTouchData(enabled: false),
                          titlesData: FlTitlesData(
                            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  final keys = monthly.keys.toList();
                                  final i = value.toInt();
                                  if (i < 0 || i >= keys.length) return const SizedBox.shrink();
                                  return Padding(padding: const EdgeInsets.only(top: 6), child: Text(keys[i], style: const TextStyle(color: Colors.white54, fontSize: 10)));
                                },
                              ),
                            ),
                          ),
                          gridData: const FlGridData(show: false),
                          borderData: FlBorderData(show: false),
                          barGroups: monthly.entries.toList().asMap().entries.map((e) {
                            return BarChartGroupData(x: e.key, barRods: [
                              BarChartRodData(toY: e.value.value["entradas"]!, color: Colors.greenAccent, width: 10, borderRadius: BorderRadius.circular(3)),
                              BarChartRodData(toY: e.value.value["saidas"]!, color: Colors.redAccent, width: 10, borderRadius: BorderRadius.circular(3)),
                            ]);
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(children: const [
                      Icon(Icons.circle, color: Colors.greenAccent, size: 10),
                      SizedBox(width: 4),
                      Text("Entradas", style: TextStyle(color: Colors.white70, fontSize: 11)),
                      SizedBox(width: 16),
                      Icon(Icons.circle, color: Colors.redAccent, size: 10),
                      SizedBox(width: 4),
                      Text("Saidas", style: TextStyle(color: Colors.white70, fontSize: 11)),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
