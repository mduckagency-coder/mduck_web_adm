import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";

const _categoryLabels = {
  "mes": "Mes",
  "semanal": "Semanal",
  "tiktok_streamers": "TikTok Streamers",
  "tiktok_agencia": "TikTok Agencia",
};

const _rewardTypeLabels = {
  "produto": "Produto",
  "placa": "Placa",
  "presente": "Presente",
  "outros": "Outros",
};

String _periodKey(DateTime d) => d.year.toString() + "-" + d.month.toString().padLeft(2, "0");

class FinanceiroPage extends StatefulWidget {
  const FinanceiroPage({super.key});

  @override
  State<FinanceiroPage> createState() => _FinanceiroPageState();
}

class _FinanceiroPageState extends State<FinanceiroPage> {
  late Future<_FinanceData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_FinanceData> _load() async {
    final client = Supabase.instance.client;
    final managerId = client.auth.currentUser!.id;
    final manager = await client.from("managers").select("agency_id").eq("id", managerId).single();
    final agencyId = manager["agency_id"] as String;

    final rewards = await client
        .from("campaign_rewards")
        .select("value, reward_type, streamer_id, profiles(display_name), agency_campaigns(category, start_date)");
    final missions = await client.from("missions").select("reward_value, starts_at, created_at");
    final budgets = await client.from("agency_budgets").select().eq("agency_id", agencyId);

    return _FinanceData(
      agencyId: agencyId,
      rewards: (rewards as List).cast<Map<String, dynamic>>(),
      missions: (missions as List).cast<Map<String, dynamic>>(),
      budgets: {for (final b in (budgets as List)) b["period_key"] as String: (b["budget"] as num).toDouble()},
    );
  }

  Future<void> _setBudget(String periodKey, double value) async {
    final client = Supabase.instance.client;
    final data = await _future;
    await client.from("agency_budgets").upsert({
      "agency_id": data.agencyId,
      "period_key": periodKey,
      "budget": value,
      "updated_at": DateTime.now().toIso8601String(),
    }, onConflict: "agency_id,period_key");
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text("Financeiro", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(width: 12),
              IconButton(icon: const Icon(Icons.refresh, color: Colors.white70), onPressed: () => setState(() => _future = _load())),
            ],
          ),
          const SizedBox(height: 16),
          const Text("Campanhas", style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<_FinanceData>(
              future: _future,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final data = snapshot.data!;

                final now = DateTime.now();
                final currentKey = _periodKey(now);
                final lastKey = _periodKey(DateTime(now.year, now.month - 1));
                final nextKey = _periodKey(DateTime(now.year, now.month + 1));

                final byMonth = <String, double>{};
                double totalCampanhasGeral = 0;
                double totalStreamers = 0;
                final byCategory = <String, double>{};
                final byType = <String, double>{};
                final byStreamer = <String, double>{};

                for (final r in data.rewards) {
                  final value = (r["value"] as num?)?.toDouble() ?? 0;
                  final campaign = r["agency_campaigns"];
                  String? monthKey;
                  if (campaign is Map && campaign["start_date"] != null) {
                    final start = DateTime.parse(campaign["start_date"]);
                    monthKey = _periodKey(start);
                    final cat = campaign["category"] as String?;
                    if (cat != null) byCategory[cat] = (byCategory[cat] ?? 0) + value;
                  }
                  if (monthKey != null) byMonth[monthKey] = (byMonth[monthKey] ?? 0) + value;

                  final type = r["reward_type"] as String?;
                  if (type != null) byType[type] = (byType[type] ?? 0) + value;

                  if (r["streamer_id"] != null) {
                    totalStreamers += value;
                    final profile = r["profiles"];
                    if (profile is Map) {
                      final name = profile["display_name"] as String?;
                      if (name != null) byStreamer[name] = (byStreamer[name] ?? 0) + value;
                    }
                  } else {
                    totalCampanhasGeral += value;
                  }
                }

                double totalMissoes = 0;
                for (final m in data.missions) {
                  final value = (m["reward_value"] as num?)?.toDouble() ?? 0;
                  if (value == 0) continue;
                  totalMissoes += value;
                  final dateStr = m["starts_at"] ?? m["created_at"];
                  if (dateStr != null) {
                    final monthKey = _periodKey(DateTime.parse(dateStr));
                    byMonth[monthKey] = (byMonth[monthKey] ?? 0) + value;
                  }
                }

                final gastoAtual = byMonth[currentKey] ?? 0;
                final gastoPassado = byMonth[lastKey] ?? 0;
                final orcamentoAtual = data.budgets[currentKey] ?? 0;
                final orcamentoProximo = data.budgets[nextKey] ?? 0;
                final saldoAtual = orcamentoAtual - gastoAtual;
                final disponivelProximo = orcamentoProximo + (saldoAtual > 0 ? saldoAtual : 0);

                final totalGeral = totalCampanhasGeral + totalStreamers + totalMissoes;
                final sortedStreamers = byStreamer.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          _MonthCard(label: "Mes passado", gasto: gastoPassado, color: Colors.white54),
                          _MonthCard(
                            label: "Mes atual",
                            gasto: gastoAtual,
                            color: const Color(0xFF7A0BD4),
                            orcamento: orcamentoAtual,
                            saldo: saldoAtual,
                            onEditBudget: (v) => _setBudget(currentKey, v),
                          ),
                          _MonthCard(
                            label: "Mes que vem",
                            gasto: null,
                            color: Colors.amber,
                            orcamento: orcamentoProximo,
                            disponivel: disponivelProximo,
                            onEditBudget: (v) => _setBudget(nextKey, v),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      const Text("Gasto por origem", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      _BarRow(label: "Campanhas (geral)", value: totalCampanhasGeral, total: totalGeral, color: Colors.blueAccent),
                      _BarRow(label: "Streamers (premiacoes individuais)", value: totalStreamers, total: totalGeral, color: Colors.greenAccent),
                      _BarRow(label: "Missoes APP", value: totalMissoes, total: totalGeral, color: Colors.orangeAccent),
                      const SizedBox(height: 24),
                      Text("Total geral: R\$ " + totalGeral.toStringAsFixed(2), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 24),
                      const Text("Por categoria de campanha", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      ..._categoryLabels.entries.map((e) => _BarRow(label: e.value, value: byCategory[e.key] ?? 0, total: totalCampanhasGeral + totalStreamers, color: Colors.blueAccent)),
                      const SizedBox(height: 24),
                      const Text("Por tipo de premiacao", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      ..._rewardTypeLabels.entries.map((e) => _BarRow(label: e.value, value: byType[e.key] ?? 0, total: totalCampanhasGeral + totalStreamers, color: Colors.amber)),
                      const SizedBox(height: 24),
                      const Text("Streamers que mais receberam", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      if (sortedStreamers.isEmpty)
                        const Text("Nenhuma premiacao vinculada a um streamer especifico ainda.", style: TextStyle(color: Colors.white54))
                      else
                        ...sortedStreamers.take(10).map((e) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Expanded(child: Text(e.key, style: const TextStyle(color: Colors.white))),
                                  Text("R\$ " + e.value.toStringAsFixed(2), style: const TextStyle(color: Color(0xFF7A0BD4), fontWeight: FontWeight.bold)),
                                ],
                              ),
                            )),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FinanceData {
  final String agencyId;
  final List<Map<String, dynamic>> rewards;
  final List<Map<String, dynamic>> missions;
  final Map<String, double> budgets;

  _FinanceData({required this.agencyId, required this.rewards, required this.missions, required this.budgets});
}

class _MonthCard extends StatelessWidget {
  final String label;
  final double? gasto;
  final double? orcamento;
  final double? saldo;
  final double? disponivel;
  final Color color;
  final void Function(double)? onEditBudget;

  const _MonthCard({required this.label, this.gasto, this.orcamento, this.saldo, this.disponivel, required this.color, this.onEditBudget});

  void _editBudget(BuildContext context) {
    final controller = TextEditingController(text: (orcamento ?? 0).toStringAsFixed(2));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text("Definir orcamento", style: TextStyle(color: Colors.white)),
        content: TextField(controller: controller, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () {
              onEditBudget?.call(double.tryParse(controller.text) ?? 0);
              Navigator.of(context).pop();
            },
            child: const Text("Salvar"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          if (gasto != null) Text("Gasto: R\$ " + gasto!.toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
          if (orcamento != null) Text("Orcamento: R\$ " + orcamento!.toStringAsFixed(2), style: const TextStyle(color: Colors.white70)),
          if (saldo != null)
            Text(
              (saldo! >= 0 ? "Sobrou: R\$ " : "Faltou: R\$ ") + saldo!.abs().toStringAsFixed(2),
              style: TextStyle(color: saldo! >= 0 ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold),
            ),
          if (disponivel != null) Text("Disponivel p/ investir: R\$ " + disponivel!.toStringAsFixed(2), style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (onEditBudget != null)
            TextButton(onPressed: () => _editBudget(context), child: const Text("Definir orcamento")),
        ],
      ),
    );
  }
}

class _BarRow extends StatelessWidget {
  final String label;
  final double value;
  final double total;
  final Color color;

  const _BarRow({required this.label, required this.value, required this.total, required this.color});

  @override
  Widget build(BuildContext context) {
    final fraction = total == 0 ? 0.0 : (value / total).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: const TextStyle(color: Colors.white70))),
              Text("R\$ " + value.toStringAsFixed(2), style: const TextStyle(color: Colors.white)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: fraction, minHeight: 6, backgroundColor: Colors.white12, valueColor: AlwaysStoppedAnimation(color)),
          ),
        ],
      ),
    );
  }
}
