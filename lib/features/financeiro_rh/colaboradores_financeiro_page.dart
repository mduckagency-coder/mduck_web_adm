import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";

class ColaboradoresFinanceiroPage extends StatefulWidget {
  const ColaboradoresFinanceiroPage({super.key});

  @override
  State<ColaboradoresFinanceiroPage> createState() => _ColaboradoresFinanceiroPageState();
}

class _ColaboradoresFinanceiroPageState extends State<ColaboradoresFinanceiroPage> {
  late Future<List<Map<String, dynamic>>> _future;
  String _search = "";

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final client = Supabase.instance.client;
    final rows = await client
        .from("managers")
        .select("id, login_email, full_name, position_title, contract_type, employment_status, photo_url, managers!managers_coordinator_id_fkey(login_email), collaborator_financial_profile(base_salary, participates_in_bonus)")
        .order("login_email");
    return (rows as List).cast<Map<String, dynamic>>();
  }

  void _openDetail(Map<String, dynamic> collaborator) {
    showDialog(context: context, builder: (context) => _CollaboratorFinanceDialog(collaborator: collaborator)).then((_) {
      setState(() => _future = _load());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Text("Colaboradores", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(width: 12),
          SizedBox(
            width: 220,
            child: TextField(
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search, color: Colors.white54), hintText: "Buscar", hintStyle: TextStyle(color: Colors.white38), isDense: true),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final list = snapshot.data!.where((c) {
                if (_search.isEmpty) return true;
                final name = ((c["full_name"] as String?) ?? (c["login_email"] as String? ?? "")).toLowerCase();
                return name.contains(_search.toLowerCase());
              }).toList();
              if (list.isEmpty) return const Center(child: Text("Nenhum colaborador encontrado.", style: TextStyle(color: Colors.white54)));
              return ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final c = list[index];
                  final status = (c["employment_status"] as String?) ?? "ativo";
                  final statusColor = status == "ativo" ? Colors.greenAccent : status == "ferias" ? Colors.blueAccent : status == "afastado" ? Colors.orangeAccent : Colors.redAccent;
                  final gestorData = c["managers"];
                  final financeData = c["collaborator_financial_profile"];
                  Map<String, dynamic>? finance;
                  if (financeData is List && financeData.isNotEmpty) finance = financeData.first as Map<String, dynamic>;
                  if (financeData is Map) finance = financeData as Map<String, dynamic>;

                  return Card(
                    color: Colors.white.withOpacity(0.05),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      onTap: () => _openDetail(c),
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.white24,
                        backgroundImage: c["photo_url"] != null ? NetworkImage(c["photo_url"] as String) : null,
                        child: c["photo_url"] == null ? const Icon(Icons.person, color: Colors.white54) : null,
                      ),
                      title: Text((c["full_name"] as String?)?.isNotEmpty == true ? c["full_name"] as String : c["login_email"] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        (c["position_title"] as String? ?? "-") +
                            "  -  " +
                            (c["contract_type"] as String? ?? "-") +
                            "  -  Gestor: " +
                            (gestorData is Map ? gestorData["login_email"] as String? ?? "-" : "-"),
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(border: Border.all(color: statusColor), borderRadius: BorderRadius.circular(6)),
                            child: Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                          if (finance != null && finance["base_salary"] != null)
                            Padding(padding: const EdgeInsets.only(top: 4), child: Text("R\$ " + (finance["base_salary"] as num).toStringAsFixed(2), style: const TextStyle(color: Colors.greenAccent, fontSize: 12))),
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

class _CollaboratorFinanceDialog extends StatefulWidget {
  final Map<String, dynamic> collaborator;
  const _CollaboratorFinanceDialog({required this.collaborator});

  @override
  State<_CollaboratorFinanceDialog> createState() => _CollaboratorFinanceDialogState();
}

class _CollaboratorFinanceDialogState extends State<_CollaboratorFinanceDialog> {
  final _salaryController = TextEditingController();
  final _commissionController = TextEditingController();
  final _costAssistanceController = TextEditingController();
  final _bankAccountController = TextEditingController();
  final _notesController = TextEditingController();
  String _paymentMethod = "pix";
  int _paymentDay = 5;
  bool _participatesInBonus = false;
  bool _saving = false;
  late Future<List<Map<String, dynamic>>> _bonusTiersFuture;

  @override
  void initState() {
    super.initState();
    _bonusTiersFuture = _loadBonusTiers();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final client = Supabase.instance.client;
    final row = await client.from("collaborator_financial_profile").select().eq("manager_id", widget.collaborator["id"]).maybeSingle();
    if (row != null) {
      setState(() {
        _salaryController.text = (row["base_salary"] as num?)?.toString() ?? "";
        _commissionController.text = (row["commission_rate"] as num?)?.toString() ?? "";
        _costAssistanceController.text = (row["cost_assistance"] as num?)?.toString() ?? "";
        _bankAccountController.text = row["bank_account"] ?? "";
        _notesController.text = row["notes"] ?? "";
        _paymentMethod = row["payment_method"] ?? "pix";
        _paymentDay = row["payment_day"] ?? 5;
        _participatesInBonus = row["participates_in_bonus"] ?? false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _loadBonusTiers() async {
    final client = Supabase.instance.client;
    final rows = await client.from("collaborator_bonus_tiers").select().eq("manager_id", widget.collaborator["id"]).order("order_index");
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;
    await client.from("collaborator_financial_profile").upsert({
      "manager_id": widget.collaborator["id"],
      "base_salary": double.tryParse(_salaryController.text),
      "commission_rate": double.tryParse(_commissionController.text),
      "cost_assistance": double.tryParse(_costAssistanceController.text),
      "bank_account": _bankAccountController.text.trim(),
      "notes": _notesController.text.trim(),
      "payment_method": _paymentMethod,
      "payment_day": _paymentDay,
      "participates_in_bonus": _participatesInBonus,
      "updated_at": DateTime.now().toIso8601String(),
      "updated_by": userId,
    }, onConflict: "manager_id");
    if (mounted) Navigator.of(context).pop();
  }

  void _openAddTier() {
    showDialog(context: context, builder: (context) => _BonusTierFormDialog(managerId: widget.collaborator["id"] as String)).then((saved) {
      if (saved == true) setState(() => _bonusTiersFuture = _loadBonusTiers());
    });
  }

  Future<void> _deleteTier(String id) async {
    final client = Supabase.instance.client;
    await client.from("collaborator_bonus_tiers").delete().eq("id", id);
    setState(() => _bonusTiersFuture = _loadBonusTiers());
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.collaborator;
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 800),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text((c["full_name"] as String?)?.isNotEmpty == true ? c["full_name"] as String : c["login_email"] as String, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                Text((c["position_title"] as String?) ?? "-", style: const TextStyle(color: Colors.white54, fontSize: 13)),
                const SizedBox(height: 16),
                const Text("Dados Financeiros", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: TextField(controller: _salaryController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Salario", labelStyle: TextStyle(color: Colors.white54)))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: _commissionController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Comissao %", labelStyle: TextStyle(color: Colors.white54)))),
                ]),
                const SizedBox(height: 8),
                TextField(controller: _costAssistanceController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Ajuda de custo", labelStyle: TextStyle(color: Colors.white54))),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: DropdownButton<String>(
                      value: _paymentMethod,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF1A1A1A),
                      style: const TextStyle(color: Colors.white),
                      items: const [DropdownMenuItem(value: "pix", child: Text("PIX")), DropdownMenuItem(value: "ted", child: Text("TED"))],
                      onChanged: (v) => setState(() => _paymentMethod = v!),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: TextEditingController(text: _paymentDay.toString()),
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: "Dia de pagamento", labelStyle: TextStyle(color: Colors.white54)),
                      onChanged: (v) => _paymentDay = int.tryParse(v) ?? _paymentDay,
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                TextField(controller: _bankAccountController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Conta bancaria / chave PIX", labelStyle: TextStyle(color: Colors.white54))),
                const SizedBox(height: 8),
                TextField(controller: _notesController, maxLines: 2, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Observacoes", labelStyle: TextStyle(color: Colors.white54))),
                const SizedBox(height: 16),
                const Text("Metas", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                SwitchListTile(
                  value: _participatesInBonus,
                  onChanged: (v) => setState(() => _participatesInBonus = v),
                  title: const Text("Participa de bonificacao por metas", style: TextStyle(color: Colors.white, fontSize: 13)),
                  activeColor: Colors.amber,
                  contentPadding: EdgeInsets.zero,
                ),
                if (_participatesInBonus) ...[
                  Row(children: [
                    const Text("Regras de Bonificacao", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    TextButton.icon(onPressed: _openAddTier, icon: const Icon(Icons.add, size: 16), label: const Text("Adicionar faixa")),
                  ]),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _bonusTiersFuture,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox.shrink();
                      final tiers = snapshot.data!;
                      if (tiers.isEmpty) return const Text("Nenhuma faixa cadastrada.", style: TextStyle(color: Colors.white38, fontSize: 12));
                      return Column(
                        children: tiers.map((t) {
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text((t["goal_type"] as String) + (t["goal_category"] != null ? " (" + t["goal_category"] + ")" : "") + ": " + (t["threshold_value"] as num).toStringAsFixed(0), style: const TextStyle(color: Colors.white, fontSize: 13)),
                            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                              Text("+ R\$ " + (t["bonus_amount"] as num).toStringAsFixed(2), style: const TextStyle(color: Colors.greenAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                              IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 16), onPressed: () => _deleteTier(t["id"] as String)),
                            ]),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancelar")),
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

class _BonusTierFormDialog extends StatefulWidget {
  final String managerId;
  const _BonusTierFormDialog({required this.managerId});

  @override
  State<_BonusTierFormDialog> createState() => _BonusTierFormDialogState();
}

class _BonusTierFormDialogState extends State<_BonusTierFormDialog> {
  String _goalType = "recrutamentos";
  final _categoryController = TextEditingController();
  final _thresholdController = TextEditingController();
  final _amountController = TextEditingController();
  bool _saving = false;

  Future<void> _save() async {
    if (_thresholdController.text.trim().isEmpty || _amountController.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;
    await client.from("collaborator_bonus_tiers").insert({
      "manager_id": widget.managerId,
      "goal_type": _goalType,
      "goal_category": _goalType == "personalizada" ? _categoryController.text.trim() : null,
      "threshold_value": double.tryParse(_thresholdController.text) ?? 0,
      "bonus_amount": double.tryParse(_amountController.text) ?? 0,
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
              const Text("Nova faixa de bonificacao", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              DropdownButton<String>(
                value: _goalType,
                dropdownColor: const Color(0xFF1A1A1A),
                style: const TextStyle(color: Colors.white),
                items: const [
                  DropdownMenuItem(value: "recrutamentos", child: Text("Recrutamentos")),
                  DropdownMenuItem(value: "leads", child: Text("Leads")),
                  DropdownMenuItem(value: "personalizada", child: Text("Personalizada (categoria)")),
                ],
                onChanged: (v) => setState(() => _goalType = v!),
              ),
              if (_goalType == "personalizada")
                TextField(controller: _categoryController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Categoria especifica", labelStyle: TextStyle(color: Colors.white54))),
              const SizedBox(height: 8),
              TextField(controller: _thresholdController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Quantidade necessaria", labelStyle: TextStyle(color: Colors.white54))),
              const SizedBox(height: 8),
              TextField(controller: _amountController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Valor da bonificacao R\$", labelStyle: TextStyle(color: Colors.white54))),
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
