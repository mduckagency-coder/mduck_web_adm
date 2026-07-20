import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "money_utils.dart";

class IndicacoesPage extends StatefulWidget {
  const IndicacoesPage({super.key});

  @override
  State<IndicacoesPage> createState() => _IndicacoesPageState();
}

class _IndicacoesPageState extends State<IndicacoesPage> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final client = Supabase.instance.client;
    final rows = await client
        .from("leads")
        .select("id, name, origin_detail, pix_key, status, created_at, converted_at, managers(login_email), financial_entries(id)")
        .eq("origin", "Indicacao")
        .order("created_at", ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  bool _bonusLaunched(Map<String, dynamic> lead) {
    final entries = lead["financial_entries"];
    return entries is List && entries.isNotEmpty;
  }

  void _launchBonus(Map<String, dynamic> lead) {
    showDialog(
      context: context,
      builder: (context) => _ReferralBonusDialog(leadId: lead["id"] as String, leadName: lead["name"] as String, leadPix: lead["pix_key"] as String?),
    ).then((saved) {
      if (saved == true) setState(() => _future = _load());
    });
  }

  void _addReferral() {
    showDialog(context: context, builder: (context) => const _AddReferralDialog()).then((saved) {
      if (saved == true) setState(() => _future = _load());
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
            const Icon(Icons.record_voice_over, color: Color(0xFF7A0BD4)),
            const SizedBox(width: 10),
            const Text("Indicacoes", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(width: 12),
            IconButton(icon: const Icon(Icons.refresh, color: Colors.white70), onPressed: () => setState(() => _future = _load())),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _addReferral,
              icon: const Icon(Icons.add, size: 16),
              label: const Text("Nova Indicacao"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
            ),
          ]),
          const SizedBox(height: 4),
          const Text("Streamers que entraram na agencia atraves de indicacao, e quem foi o recrutador responsavel.", style: TextStyle(color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic)),
          const SizedBox(height: 20),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text("Erro ao carregar: " + snapshot.error.toString(), style: const TextStyle(color: Colors.redAccent)));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final all = snapshot.data!;
                final agenciados = all.where((l) => l["status"] == "agenciado").toList();
                final emAndamento = all.where((l) => l["status"] != "agenciado").toList();

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(spacing: 12, children: [
                        _summaryCard("Total de Indicacoes", all.length.toString(), Icons.people, const Color(0xFF7A0BD4)),
                        _summaryCard("Agenciados", agenciados.length.toString(), Icons.verified, Colors.greenAccent),
                        _summaryCard("Em andamento", emAndamento.length.toString(), Icons.hourglass_bottom, Colors.orangeAccent),
                      ]),
                      const SizedBox(height: 24),
                      const Text("Agenciados por Indicacao", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 12),
                      if (agenciados.isEmpty)
                        const Text("Nenhum streamer agenciado por indicacao ainda.", style: TextStyle(color: Colors.white54, fontSize: 13))
                      else
                        Container(
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(14)),
                          child: Column(
                            children: agenciados.map((l) {
                              final recruiter = l["managers"];
                              final recruiterEmail = recruiter is Map ? recruiter["login_email"] as String? ?? "-" : "-";
                              final date = l["converted_at"] != null ? DateTime.parse(l["converted_at"] as String).toLocal().toString().substring(0, 10) : "-";
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white12))),
                                child: Row(children: [
                                  Expanded(flex: 2, child: Text(l["name"] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
                                  Expanded(flex: 2, child: Text("Indicado por: " + ((l["origin_detail"] as String?)?.isNotEmpty == true ? l["origin_detail"] as String : "-"), style: const TextStyle(color: Colors.white70, fontSize: 12))),
                                  Expanded(flex: 2, child: Text("Agenciado por: " + recruiterEmail, style: const TextStyle(color: Colors.white70, fontSize: 12))),
                                  Text(date, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                                  const SizedBox(width: 12),
                                  _bonusLaunched(l)
                                      ? const Text("BONUS LANCADO", style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold))
                                      : TextButton(onPressed: () => _launchBonus(l), child: const Text("Lancar bonus", style: TextStyle(fontSize: 11))),
                                ]),
                              );
                            }).toList(),
                          ),
                        ),
                      const SizedBox(height: 24),
                      const Text("Em Andamento", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 12),
                      if (emAndamento.isEmpty)
                        const Text("Nenhuma indicacao em andamento.", style: TextStyle(color: Colors.white54, fontSize: 13))
                      else
                        Container(
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(14)),
                          child: Column(
                            children: emAndamento.map((l) {
                              final recruiter = l["managers"];
                              final recruiterEmail = recruiter is Map ? recruiter["login_email"] as String? ?? "-" : "-";
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white12))),
                                child: Row(children: [
                                  Expanded(flex: 2, child: Text(l["name"] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
                                  Expanded(flex: 2, child: Text("Indicado por: " + ((l["origin_detail"] as String?)?.isNotEmpty == true ? l["origin_detail"] as String : "-"), style: const TextStyle(color: Colors.white70, fontSize: 12))),
                                  Expanded(flex: 2, child: Text("Recrutador: " + recruiterEmail, style: const TextStyle(color: Colors.white70, fontSize: 12))),
                                  Text(l["status"] as String, style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                                ]),
                              );
                            }).toList(),
                          ),
                        ),
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

  Widget _summaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.4))),
      child: Row(children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
            Text(title, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      ]),
    );
  }
}

class _ReferralBonusDialog extends StatefulWidget {
  final String leadId;
  final String leadName;
  final String? leadPix;
  const _ReferralBonusDialog({required this.leadId, required this.leadName, this.leadPix});

  @override
  State<_ReferralBonusDialog> createState() => _ReferralBonusDialogState();
}

class _ReferralBonusDialogState extends State<_ReferralBonusDialog> {
  final _amountController = TextEditingController();
  late final _pixController = TextEditingController(text: widget.leadPix ?? "");
  bool _saving = false;

  Future<void> _save() async {
    if (_amountController.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;
    final manager = await client.from("managers").select("agency_id").eq("id", userId).single();
    final pix = _pixController.text.trim();
    if (pix != (widget.leadPix ?? "")) {
      await client.from("leads").update({"pix_key": pix}).eq("id", widget.leadId);
    }
    await client.from("financial_entries").insert({
      "agency_id": manager["agency_id"],
      "entry_type": "indicacao",
      "category": "Indicacao",
      "description": "Bonus de indicacao - " + widget.leadName,
      "notes": pix.isEmpty ? null : "Chave PIX: " + pix,
      "related_lead_id": widget.leadId,
      "amount": parseAmount(_amountController.text),
      "due_date": DateTime.now().toIso8601String().substring(0, 10),
      "status": "pendente",
      "created_by": userId,
    });
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Lancar bonus de indicacao", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              Text(widget.leadName, style: const TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 16),
              TextField(controller: _amountController, autofocus: true, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Valor do bonus R\$", labelStyle: TextStyle(color: Colors.white54))),
              const SizedBox(height: 8),
              TextField(controller: _pixController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Chave PIX de quem indicou", labelStyle: TextStyle(color: Colors.white54))),
              const SizedBox(height: 16),
              Text("Sera criado como Conta a Pagar pendente, aparecendo em Pagamentos.", style: const TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic)),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancelar")),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                  child: Text(_saving ? "Salvando..." : "Lancar"),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

/// Registers a referral directly into the same `leads` table the recruiter
/// pipeline already uses (origin = "Indicacao"), so there's a single source
/// of truth instead of a separate "referrals" cadastro.
class _AddReferralDialog extends StatefulWidget {
  const _AddReferralDialog();

  @override
  State<_AddReferralDialog> createState() => _AddReferralDialogState();
}

class _AddReferralDialogState extends State<_AddReferralDialog> {
  final _nameController = TextEditingController();
  final _indicatedByController = TextEditingController();
  final _phoneController = TextEditingController();
  final _pixController = TextEditingController();
  bool _saving = false;

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;
    final manager = await client.from("managers").select("agency_id").eq("id", userId).single();
    final agencyId = manager["agency_id"];

    var initialStage = await client.from("lead_kanban_stages").select("stage_key").eq("agency_id", agencyId).eq("is_initial", true).eq("is_active", true).maybeSingle();
    initialStage ??= await client.from("lead_kanban_stages").select("stage_key").eq("agency_id", agencyId).eq("is_active", true).order("order_index").limit(1).maybeSingle();

    await client.from("leads").insert({
      "agency_id": agencyId,
      "recruiter_id": userId,
      "name": _nameController.text.trim(),
      "tiktok_username": "",
      "phone": _phoneController.text.trim(),
      "origin": "Indicacao",
      "origin_detail": _indicatedByController.text.trim(),
      "pix_key": _pixController.text.trim(),
      "status": initialStage != null ? initialStage["stage_key"] : "novo",
    });

    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Nova indicacao", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(controller: _nameController, autofocus: true, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Nome do indicado", labelStyle: TextStyle(color: Colors.white54))),
              const SizedBox(height: 8),
              TextField(controller: _indicatedByController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Indicado por", labelStyle: TextStyle(color: Colors.white54))),
              const SizedBox(height: 8),
              TextField(controller: _phoneController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Telefone (opcional)", labelStyle: TextStyle(color: Colors.white54))),
              const SizedBox(height: 8),
              TextField(controller: _pixController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Chave PIX de quem indicou (opcional)", labelStyle: TextStyle(color: Colors.white54))),
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
    );
  }
}
