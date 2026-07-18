import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";

class RecruiterProfilePage extends StatefulWidget {
  const RecruiterProfilePage({super.key});

  @override
  State<RecruiterProfilePage> createState() => _RecruiterProfilePageState();
}

class _RecruiterProfilePageState extends State<RecruiterProfilePage> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;

    final me = await client.from("managers").select("*, managers!managers_coordinator_id_fkey(login_email)").eq("id", userId).single();
    final compensation = await client.from("recruiter_compensation").select().eq("manager_id", userId).order("created_at", ascending: false);
    final bonusRules = await client.from("recruiter_bonus_rules").select().eq("recruiter_id", userId).order("created_at", ascending: false);

    final now = DateTime.now();
    final targets = await client.from("recruiter_targets").select().or("recruiter_id.eq." + userId + ",recruiter_id.is.null");
    final targetsList = (targets as List).cast<Map<String, dynamic>>();
    final leads = await client.from("leads").select("status, created_at, converted_at").eq("recruiter_id", userId);
    final leadsList = (leads as List).cast<Map<String, dynamic>>();

    for (final t in targetsList) {
      final start = DateTime.parse(t["starts_at"]);
      final end = DateTime.parse(t["ends_at"]);
      double progress = 0;
      switch (t["metric"]) {
        case "leads":
          progress = leadsList.where((l) {
            final d = DateTime.parse(l["created_at"]);
            return !d.isBefore(start) && !d.isAfter(end);
          }).length.toDouble();
          break;
        case "agenciamentos":
          progress = leadsList.where((l) {
            if (l["status"] != "agenciado" || l["converted_at"] == null) return false;
            final d = DateTime.parse(l["converted_at"]);
            return !d.isBefore(start) && !d.isAfter(end);
          }).length.toDouble();
          break;
        case "contatos":
          progress = leadsList.where((l) {
            final d = DateTime.parse(l["created_at"]);
            return l["status"] != "novo" && !d.isBefore(start) && !d.isAfter(end);
          }).length.toDouble();
          break;
        case "conversao_minima":
          final periodLeads = leadsList.where((l) {
            final d = DateTime.parse(l["created_at"]);
            return !d.isBefore(start) && !d.isAfter(end);
          }).toList();
          final agenciados = periodLeads.where((l) => l["status"] == "agenciado").length;
          progress = periodLeads.isEmpty ? 0 : (agenciados / periodLeads.length) * 100;
          break;
      }
      t["progress"] = progress;
      t["isActive"] = !now.isBefore(start) && !now.isAfter(end);
    }

    return {
      "me": me,
      "compensation": (compensation as List).cast<Map<String, dynamic>>(),
      "bonusRules": (bonusRules as List).cast<Map<String, dynamic>>(),
      "targets": targetsList.where((t) => t["isActive"] == true).toList(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text("Meu Perfil", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(width: 12),
            IconButton(icon: const Icon(Icons.refresh, color: Colors.white70), onPressed: () => setState(() => _future = _load())),
          ]),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text("Erro: " + snapshot.error.toString(), style: const TextStyle(color: Colors.redAccent)));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final me = snapshot.data!["me"] as Map<String, dynamic>;
                final compensation = snapshot.data!["compensation"] as List<Map<String, dynamic>>;
                final bonusRules = snapshot.data!["bonusRules"] as List<Map<String, dynamic>>;
                final targets = snapshot.data!["targets"] as List<Map<String, dynamic>>;
                final coordinatorData = me["managers"];
                final isAdmin = me["role"] == "admin";
                final status = (me["employment_status"] as String?) ?? "ativo";
                final statusColor = status == "ativo" ? Colors.greenAccent : status == "ferias" ? Colors.blueAccent : status == "afastado" ? Colors.orangeAccent : Colors.redAccent;

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: Colors.white24,
                          backgroundImage: me["photo_url"] != null ? NetworkImage(me["photo_url"] as String) : null,
                          child: me["photo_url"] == null ? const Icon(Icons.person, color: Colors.white, size: 32) : null,
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text((me["full_name"] as String?)?.isNotEmpty == true ? me["full_name"] as String : me["login_email"] as String, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            Text((me["position_title"] as String?) ?? (me["role"] as String? ?? "-"), style: const TextStyle(color: Color(0xFF7A0BD4), fontSize: 13)),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(border: Border.all(color: statusColor), borderRadius: BorderRadius.circular(8)),
                          child: Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                        const Spacer(),
                        if (isAdmin)
                          ElevatedButton.icon(
                            onPressed: () {
                              showDialog(context: context, builder: (context) => _EditProfileDialog(manager: me)).then((saved) {
                                if (saved == true) setState(() => _future = _load());
                              });
                            },
                            icon: const Icon(Icons.edit, size: 16),
                            label: const Text("Editar (Admin Master)"),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
                          ),
                      ]),
                      const SizedBox(height: 20),
                      const Text("Informacoes Pessoais", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(14)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _infoRow("Nome de usuario", (me["username"] as String?) ?? "-"),
                            _infoRow("Login TikTok", (me["tiktok_login"] as String?) ?? "-"),
                            _infoRow("WhatsApp", (me["whatsapp"] as String?) ?? "-"),
                            _infoRow("E-mail", me["login_email"] as String),
                            _infoRow("CPF/CNPJ", (me["cpf_cnpj"] as String?) ?? "-"),
                            _infoRow("Tipo de contratacao", (me["contract_type"] as String?) ?? "-"),
                            _infoRow("Data de admissao", me["hire_date"] != null ? me["hire_date"].toString() : "Nao informado"),
                            if (me["hire_date"] != null) _infoRow("Tempo de empresa", _tempoDeEmpresa(DateTime.parse(me["hire_date"]))),
                            _infoRow("Coordenador responsavel", coordinatorData is Map ? coordinatorData["login_email"] as String? ?? "-" : "Nao definido"),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text("Metas Individuais", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      if (targets.isEmpty)
                        const Text("Nenhuma meta ativa no momento.", style: TextStyle(color: Colors.white54, fontSize: 13))
                      else
                        ...targets.map((t) {
                          final progress = t["progress"] as double;
                          final target = (t["target_value"] as num).toDouble();
                          final fraction = target == 0 ? 0.0 : (progress / target).clamp(0.0, 1.0);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text((t["metric"] as String) + " (" + (t["period_type"] as String) + "): " + progress.toStringAsFixed(0) + " / " + target.toStringAsFixed(0),
                                    style: const TextStyle(color: Colors.white, fontSize: 13)),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(value: fraction, minHeight: 6, backgroundColor: Colors.white12, valueColor: const AlwaysStoppedAnimation(Color(0xFF7A0BD4))),
                                ),
                              ],
                            ),
                          );
                        }),
                      const SizedBox(height: 24),
                      Row(children: [
                        const Text("Area Financeira", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        const Spacer(),
                        if (isAdmin)
                          TextButton.icon(
                            onPressed: () {
                              showDialog(context: context, builder: (context) => _CompensationFormDialog(recruiterId: me["id"] as String)).then((saved) {
                                if (saved == true) setState(() => _future = _load());
                              });
                            },
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text("Adicionar"),
                          ),
                      ]),
                      const Text("Visivel apenas para voce e para o Administrador Master.", style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic)),
                      const SizedBox(height: 8),
                      if (bonusRules.isNotEmpty) ...[
                        const Text("Regra de bonificacao ativa", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                        ...bonusRules.map((b) => Text(
                              "Salario base R\$ " + (b["base_salary"] ?? 0).toString() + " - Meta principal: " + b["main_goal_value"].toString() + " - Bonus de R\$ " + b["bonus_amount"].toString() + " ao atingir +" + b["bonus_goal_value"].toString(),
                              style: const TextStyle(color: Colors.tealAccent, fontSize: 12),
                            )),
                        const SizedBox(height: 8),
                      ],
                      if (compensation.isEmpty)
                        const Text("Nenhum registro financeiro ainda.", style: TextStyle(color: Colors.white54, fontSize: 13))
                      else
                        ...compensation.map((c) {
                          final date = c["payment_date"] ?? c["created_at"].toString().substring(0, 10);
                          return Card(
                            color: Colors.white.withOpacity(0.05),
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text((c["comp_type"] as String).toUpperCase() + " - R\$ " + (c["amount"] as num).toStringAsFixed(2), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                              subtitle: Text((c["description"] as String? ?? "") + "  -  " + date.toString(), style: const TextStyle(color: Colors.white54, fontSize: 11)),
                            ),
                          );
                        }),
                      if (isAdmin) ...[
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () {
                            showDialog(context: context, builder: (context) => _BonusRuleFormDialog(recruiterId: me["id"] as String)).then((saved) {
                              if (saved == true) setState(() => _future = _load());
                            });
                          },
                          icon: const Icon(Icons.rule, size: 16),
                          label: const Text("Configurar regra de bonificacao"),
                        ),
                      ],
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

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          SizedBox(width: 180, child: Text(label, style: const TextStyle(color: Colors.white54))),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.white))),
        ]),
      );

  String _tempoDeEmpresa(DateTime hireDate) {
    final days = DateTime.now().difference(hireDate).inDays;
    final years = days ~/ 365;
    final months = (days % 365) ~/ 30;
    if (years > 0) return years.toString() + " ano(s) e " + months.toString() + " mes(es)";
    return months.toString() + " mes(es)";
  }
}

class _EditProfileDialog extends StatefulWidget {
  final Map<String, dynamic> manager;
  const _EditProfileDialog({required this.manager});

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late TextEditingController _fullName, _username, _tiktokLogin, _whatsapp, _cpfCnpj, _contractType, _positionTitle;
  DateTime? _hireDate;
  String _status = "ativo";
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final m = widget.manager;
    _fullName = TextEditingController(text: m["full_name"] ?? "");
    _username = TextEditingController(text: m["username"] ?? "");
    _tiktokLogin = TextEditingController(text: m["tiktok_login"] ?? "");
    _whatsapp = TextEditingController(text: m["whatsapp"] ?? "");
    _cpfCnpj = TextEditingController(text: m["cpf_cnpj"] ?? "");
    _contractType = TextEditingController(text: m["contract_type"] ?? "");
    _positionTitle = TextEditingController(text: m["position_title"] ?? "");
    _status = m["employment_status"] ?? "ativo";
    if (m["hire_date"] != null) _hireDate = DateTime.parse(m["hire_date"]);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final client = Supabase.instance.client;
    await client.from("managers").update({
      "full_name": _fullName.text.trim(),
      "username": _username.text.trim(),
      "tiktok_login": _tiktokLogin.text.trim(),
      "whatsapp": _whatsapp.text.trim(),
      "cpf_cnpj": _cpfCnpj.text.trim(),
      "contract_type": _contractType.text.trim(),
      "position_title": _positionTitle.text.trim(),
      "employment_status": _status,
      "hire_date": _hireDate?.toIso8601String().substring(0, 10),
    }).eq("id", widget.manager["id"]);
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
                const Text("Editar perfil (Admin Master)", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(controller: _fullName, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Nome completo", labelStyle: TextStyle(color: Colors.white54))),
                const SizedBox(height: 8),
                TextField(controller: _username, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Nome de usuario", labelStyle: TextStyle(color: Colors.white54))),
                const SizedBox(height: 8),
                TextField(controller: _tiktokLogin, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Login TikTok", labelStyle: TextStyle(color: Colors.white54))),
                const SizedBox(height: 8),
                TextField(controller: _whatsapp, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "WhatsApp", labelStyle: TextStyle(color: Colors.white54))),
                const SizedBox(height: 8),
                TextField(controller: _cpfCnpj, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "CPF/CNPJ", labelStyle: TextStyle(color: Colors.white54))),
                const SizedBox(height: 8),
                TextField(controller: _contractType, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Tipo de contratacao (CLT, PJ...)", labelStyle: TextStyle(color: Colors.white54))),
                const SizedBox(height: 8),
                TextField(controller: _positionTitle, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Cargo", labelStyle: TextStyle(color: Colors.white54))),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: Text(_hireDate != null ? "Admissao: " + _hireDate!.toIso8601String().substring(0, 10) : "Sem data", style: const TextStyle(color: Colors.white70))),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(context: context, initialDate: _hireDate ?? DateTime.now(), firstDate: DateTime(2015), lastDate: DateTime(2100));
                      if (picked != null) setState(() => _hireDate = picked);
                    },
                    child: const Text("Escolher"),
                  ),
                ]),
                const SizedBox(height: 8),
                DropdownButton<String>(
                  value: _status,
                  dropdownColor: const Color(0xFF1A1A1A),
                  style: const TextStyle(color: Colors.white),
                  items: const [
                    DropdownMenuItem(value: "ativo", child: Text("Ativo")),
                    DropdownMenuItem(value: "ferias", child: Text("Ferias")),
                    DropdownMenuItem(value: "afastado", child: Text("Afastado")),
                    DropdownMenuItem(value: "desligado", child: Text("Desligado")),
                  ],
                  onChanged: (v) => setState(() => _status = v!),
                ),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
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
      ),
    );
  }
}

class _CompensationFormDialog extends StatefulWidget {
  final String recruiterId;
  const _CompensationFormDialog({required this.recruiterId});

  @override
  State<_CompensationFormDialog> createState() => _CompensationFormDialogState();
}

class _CompensationFormDialogState extends State<_CompensationFormDialog> {
  String _type = "bonificacao";
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _paymentDate;
  bool _saving = false;

  Future<void> _save() async {
    if (_amountController.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;
    await client.from("recruiter_compensation").insert({
      "manager_id": widget.recruiterId,
      "comp_type": _type,
      "amount": double.tryParse(_amountController.text) ?? 0,
      "description": _descriptionController.text.trim(),
      "payment_date": _paymentDate?.toIso8601String().substring(0, 10),
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
              const Text("Novo registro financeiro", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              DropdownButton<String>(
                value: _type,
                dropdownColor: const Color(0xFF1A1A1A),
                style: const TextStyle(color: Colors.white),
                items: const [
                  DropdownMenuItem(value: "salario", child: Text("Salario")),
                  DropdownMenuItem(value: "bonificacao", child: Text("Bonificacao")),
                  DropdownMenuItem(value: "premiacao", child: Text("Premiacao")),
                  DropdownMenuItem(value: "comissao", child: Text("Comissao")),
                  DropdownMenuItem(value: "meta_paga", child: Text("Meta paga")),
                ],
                onChanged: (v) => setState(() => _type = v!),
              ),
              const SizedBox(height: 8),
              TextField(controller: _amountController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Valor R\$", labelStyle: TextStyle(color: Colors.white54))),
              const SizedBox(height: 8),
              TextField(controller: _descriptionController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Descricao", labelStyle: TextStyle(color: Colors.white54))),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: Text(_paymentDate != null ? "Pagamento: " + _paymentDate!.toIso8601String().substring(0, 10) : "Sem data", style: const TextStyle(color: Colors.white70))),
                TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
                    if (picked != null) setState(() => _paymentDate = picked);
                  },
                  child: const Text("Escolher"),
                ),
              ]),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
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

class _BonusRuleFormDialog extends StatefulWidget {
  final String recruiterId;
  const _BonusRuleFormDialog({required this.recruiterId});

  @override
  State<_BonusRuleFormDialog> createState() => _BonusRuleFormDialogState();
}

class _BonusRuleFormDialogState extends State<_BonusRuleFormDialog> {
  final _baseSalaryController = TextEditingController();
  final _mainGoalController = TextEditingController();
  final _bonusGoalController = TextEditingController();
  final _bonusAmountController = TextEditingController();
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;
    await client.from("recruiter_bonus_rules").insert({
      "recruiter_id": widget.recruiterId,
      "base_salary": double.tryParse(_baseSalaryController.text) ?? 0,
      "main_goal_value": int.tryParse(_mainGoalController.text) ?? 0,
      "bonus_goal_value": int.tryParse(_bonusGoalController.text) ?? 0,
      "bonus_amount": double.tryParse(_bonusAmountController.text) ?? 0,
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
              const Text("Regra de bonificacao", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(controller: _baseSalaryController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Salario base R\$", labelStyle: TextStyle(color: Colors.white54))),
              const SizedBox(height: 8),
              TextField(controller: _mainGoalController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Meta principal (recrutamentos/mes)", labelStyle: TextStyle(color: Colors.white54))),
              const SizedBox(height: 8),
              TextField(controller: _bonusGoalController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Meta adicional (a mais que a principal)", labelStyle: TextStyle(color: Colors.white54))),
              const SizedBox(height: 8),
              TextField(controller: _bonusAmountController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Valor da bonificacao R\$", labelStyle: TextStyle(color: Colors.white54))),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
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

