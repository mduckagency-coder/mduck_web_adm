import "package:flutter/material.dart";
import "package:file_picker/file_picker.dart";
import "package:url_launcher/url_launcher.dart";
import "package:supabase_flutter/supabase_flutter.dart";

class UnifiedProfilePage extends StatefulWidget {
  final String initialTab;
  final String? managerId;
  const UnifiedProfilePage({super.key, this.initialTab = "Informacoes", this.managerId});

  @override
  State<UnifiedProfilePage> createState() => _UnifiedProfilePageState();
}

class _UnifiedProfilePageState extends State<UnifiedProfilePage> {
  late Future<Map<String, dynamic>> _future;
  late String _tab;
  bool _isAdmin = false;
  bool _isDono = false;
  bool _isCoordOrAdmin = false;
  bool _uploadingPhoto = false;
  bool _isSelf = true;

  List<String> get _visibleTabs {
    final tabs = ["Informacoes"];
    if (_isSelf || _isCoordOrAdmin) { tabs.add("Desempenho"); tabs.add("Historico"); }
    if (_isSelf || _isDono) tabs.add("Financeiro"); if (_isSelf) tabs.add("Conta");
    return tabs;
  }

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final client = Supabase.instance.client;
    final currentUserId = client.auth.currentUser!.id;
    final targetId = widget.managerId ?? currentUserId;
    _isSelf = targetId == currentUserId;

    final viewer = await client.from("managers").select("role, financial_role").eq("id", currentUserId).single();
    _isAdmin = viewer["role"] == "admin";
    _isDono = viewer["financial_role"] == "dono";
    _isCoordOrAdmin = viewer["role"] == "coordenador" || viewer["role"] == "admin";

    final me = await client.from("managers").select().eq("id", targetId).single();
    if (me["coordinator_id"] != null) {
      final coordinator = await client.from("managers").select("login_email").eq("id", me["coordinator_id"]).maybeSingle();
      me["coordinator_email"] = coordinator?["login_email"];
    }
    return me;
  }

  Future<void> _uploadPhoto() async {
    setState(() => _uploadingPhoto = true);
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result == null || result.files.isEmpty || result.files.first.bytes == null) {
      setState(() => _uploadingPhoto = false);
      return;
    }
    final file = result.files.first;
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;
    final dotIndex = file.name.lastIndexOf(".");
    final rawExt = dotIndex != -1 ? file.name.substring(dotIndex + 1) : "";
    final ext = RegExp(r"^[a-zA-Z0-9]{1,5}$").hasMatch(rawExt) ? rawExt.toLowerCase() : "jpg";
    final path = userId + "_" + DateTime.now().millisecondsSinceEpoch.toString() + "." + ext;
    try {
      await client.storage.from("avatars").uploadBinary(path, file.bytes!);
      final url = client.storage.from("avatars").getPublicUrl(path);
      await client.from("managers").update({"photo_url": url}).eq("id", userId);
      setState(() {
        _uploadingPhoto = false;
        _future = _load();
      });
    } catch (e) {
      setState(() => _uploadingPhoto = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao enviar foto: " + e.toString())));
    }
  }

  String _tempoDeEmpresa(DateTime hireDate) {
    final days = DateTime.now().difference(hireDate).inDays;
    final years = days ~/ 365;
    final months = (days % 365) ~/ 30;
    if (years > 0) return years.toString() + " ano(s) e " + months.toString() + " mes(es)";
    return months.toString() + " mes(es)";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text("Perfil"),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text("Erro ao carregar perfil: " + snapshot.error.toString(), style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center),
              ),
            );
          }
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final me = snapshot.data!;
          final coordinatorEmail = me["coordinator_email"] as String?;
          final status = (me["employment_status"] as String?) ?? "ativo";
          final statusColor = status == "ativo" ? Colors.greenAccent : status == "ferias" ? Colors.blueAccent : status == "afastado" ? Colors.orangeAccent : Colors.redAccent;
          final screenWidth = MediaQuery.of(context).size.width;
          final isNarrow = screenWidth < 700;

          return SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [const Color(0xFF7A0BD4).withOpacity(0.25), const Color(0xFF121212)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                  ),
                  child: Flex(
                    direction: isNarrow ? Axis.vertical : Axis.horizontal,
                    crossAxisAlignment: isNarrow ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          CircleAvatar(
                            radius: 48,
                            backgroundColor: Colors.white24,
                            backgroundImage: me["photo_url"] != null ? NetworkImage(me["photo_url"] as String) : null,
                            child: me["photo_url"] == null ? const Icon(Icons.person, color: Colors.white, size: 48) : null,
                          ),
                          if (_isSelf) Positioned(
                            bottom: -4,
                            right: -4,
                            child: InkWell(
                              onTap: (!_isSelf || _uploadingPhoto) ? null : _uploadPhoto,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF7A0BD4)),
                                child: _uploadingPhoto
                                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(width: isNarrow ? 0 : 24, height: isNarrow ? 16 : 0),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: isNarrow ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                          children: [
                            Text((me["full_name"] as String?)?.isNotEmpty == true ? me["full_name"] as String : me["login_email"] as String,
                                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold), textAlign: isNarrow ? TextAlign.center : TextAlign.start),
                            if ((me["username"] as String?)?.isNotEmpty == true)
                              Text("@" + me["username"], style: const TextStyle(color: Colors.white54, fontSize: 13)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 10,
                              runSpacing: 6,
                              alignment: isNarrow ? WrapAlignment.center : WrapAlignment.start,
                              children: [
                                _headerChip(Icons.badge, (me["position_title"] as String?) ?? "Cargo nao definido"),
                                if ((me["department"] as String?)?.isNotEmpty == true) _headerChip(Icons.apartment, me["department"]),
                                _headerChip(Icons.person_outline, coordinatorEmail != null ? "Gestor: " + coordinatorEmail : "Sem gestor definido"),
                                if (me["hire_date"] != null) _headerChip(Icons.timer, _tempoDeEmpresa(DateTime.parse(me["hire_date"]))),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(border: Border.all(color: statusColor), borderRadius: BorderRadius.circular(8)),
                              child: Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                      if (_isAdmin)
                        Padding(
                          padding: EdgeInsets.only(top: isNarrow ? 16 : 0),
                          child: ElevatedButton.icon(
                            onPressed: () {
                              showDialog(context: context, builder: (context) => _EditProfileDialog(manager: me)).then((saved) {
                                if (saved == true) setState(() => _future = _load());
                              });
                            },
                            icon: const Icon(Icons.edit, size: 16),
                            label: const Text("Editar"),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  width: double.infinity,
                  color: const Color(0xFF1A1A1A),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _visibleTabs.map((t) {
                        final selected = _tab == t;
                        return InkWell(
                          onTap: () => setState(() => _tab = t),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: selected ? const Color(0xFF7A0BD4) : Colors.transparent, width: 3))),
                            child: Text(t, style: TextStyle(color: selected ? const Color(0xFF7A0BD4) : Colors.white70, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: _buildTabContent(me),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _headerChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white54, size: 14),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ]),
    );
  }

  Widget _buildTabContent(Map<String, dynamic> me) {
    switch (_tab) {
      case "Informacoes":
        return _InformacoesTab(manager: me);
      case "Desempenho":
        return _DesempenhoTab(managerId: me["id"] as String);
      case "Historico":
        return _HistoricoTab(managerId: me["id"] as String);
      case "Financeiro":
        return _FinanceiroTab(managerId: me["id"] as String, isSelf: _isSelf);
      case "Conta":
        return _ContaTab(manager: me);
      default:
        return const SizedBox.shrink();
    }
  }
}

class _InformacoesTab extends StatelessWidget {
  final Map<String, dynamic> manager;
  const _InformacoesTab({required this.manager});

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          SizedBox(width: 180, child: Text(label, style: const TextStyle(color: Colors.white54))),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.white))),
        ]),
      );

  Widget _clickableRow(String label, String? value, VoidCallback onTap) {
    if (value == null || value.isEmpty) return _row(label, "-");
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        SizedBox(width: 180, child: Text(label, style: const TextStyle(color: Colors.white54))),
        Expanded(
          child: InkWell(
            onTap: onTap,
            child: Row(children: [
              Text(value, style: const TextStyle(color: Color(0xFF7A0BD4), decoration: TextDecoration.underline)),
              const SizedBox(width: 6),
              const Icon(Icons.open_in_new, size: 14, color: Color(0xFF7A0BD4)),
            ]),
          ),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row("Nome de usuario", (manager["username"] as String?) ?? "-"),
          _clickableRow("Login TikTok", manager["tiktok_login"] as String?, () {
            final handle = (manager["tiktok_login"] as String).replaceFirst("@", "");
            launchUrl(Uri.parse("https://www.tiktok.com/@" + handle), mode: LaunchMode.externalApplication);
          }),
          _clickableRow("WhatsApp", manager["whatsapp"] as String?, () {
            final digits = (manager["whatsapp"] as String).replaceAll(RegExp(r"[^0-9]"), "");
            launchUrl(Uri.parse("https://wa.me/" + digits), mode: LaunchMode.externalApplication);
          }),
          _row("E-mail", manager["login_email"] as String),
          _row("CPF/CNPJ", (manager["cpf_cnpj"] as String?) ?? "-"),
          _row("Tipo de contratacao", (manager["contract_type"] as String?) ?? "-"),
          _row("Departamento", (manager["department"] as String?) ?? "-"),
          _row("Data de admissao", manager["hire_date"] != null ? manager["hire_date"].toString() : "Nao informado"),
        ],
      ),
    );
  }
}

class _DesempenhoTab extends StatefulWidget {
  final String managerId;
  const _DesempenhoTab({required this.managerId});

  @override
  State<_DesempenhoTab> createState() => _DesempenhoTabState();
}

class _DesempenhoTabState extends State<_DesempenhoTab> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final client = Supabase.instance.client;
    final now = DateTime.now();
    final targets = await client.from("recruiter_targets").select().or("recruiter_id.eq." + widget.managerId + ",recruiter_id.is.null");
    final targetsList = (targets as List).cast<Map<String, dynamic>>();
    final leads = await client.from("leads").select("status, created_at, converted_at").eq("recruiter_id", widget.managerId);
    final leadsList = (leads as List).cast<Map<String, dynamic>>();

    final active = <Map<String, dynamic>>[];
    for (final t in targetsList) {
      final start = DateTime.parse(t["starts_at"]);
      final end = DateTime.parse(t["ends_at"]);
      if (now.isBefore(start) || now.isAfter(end)) continue;
      double progress = 0;
      switch (t["metric"]) {
        case "leads":
          progress = leadsList.where((l) => !DateTime.parse(l["created_at"]).isBefore(start) && !DateTime.parse(l["created_at"]).isAfter(end)).length.toDouble();
          break;
        case "agenciamentos":
          progress = leadsList.where((l) {
            if (l["status"] != "agenciado" || l["converted_at"] == null) return false;
            final d = DateTime.parse(l["converted_at"]);
            return !d.isBefore(start) && !d.isAfter(end);
          }).length.toDouble();
          break;
      }
      t["progress"] = progress;
      active.add(t);
    }
    return active;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final list = snapshot.data!;
        if (list.isEmpty) return const Text("Nenhuma meta ativa no momento.", style: TextStyle(color: Colors.white54));
        return Column(
          children: list.map((t) {
            final progress = t["progress"] as double;
            final target = (t["target_value"] as num).toDouble();
            final fraction = target == 0 ? 0.0 : (progress / target).clamp(0.0, 1.0);
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text((t["metric"] as String) + " (" + (t["period_type"] as String) + ")", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(progress.toStringAsFixed(0) + " / " + target.toStringAsFixed(0), style: const TextStyle(color: Color(0xFF7A0BD4))),
                  const SizedBox(height: 6),
                  ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: fraction, minHeight: 6, backgroundColor: Colors.white12, valueColor: const AlwaysStoppedAnimation(Color(0xFF7A0BD4)))),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _HistoricoTab extends StatefulWidget {
  final String managerId;
  const _HistoricoTab({required this.managerId});

  @override
  State<_HistoricoTab> createState() => _HistoricoTabState();
}

class _HistoricoTabState extends State<_HistoricoTab> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final client = Supabase.instance.client;
    final events = <Map<String, dynamic>>[];
    final leads = await client.from("leads").select("id, name, created_at").eq("recruiter_id", widget.managerId);
    for (final l in (leads as List)) {
      events.add({"date": l["created_at"], "text": "Lead cadastrado: " + (l["name"] as String)});
    }
    events.sort((a, b) => (b["date"] as String).compareTo(a["date"] as String));
    return events;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final list = snapshot.data!;
        if (list.isEmpty) return const Text("Nenhuma atividade registrada ainda.", style: TextStyle(color: Colors.white54));
        return Column(
          children: list.take(50).map((e) {
            final date = DateTime.parse(e["date"] as String).toLocal().toString().substring(0, 16);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.circle, size: 6, color: Color(0xFF7A0BD4)),
                const SizedBox(width: 8),
                Expanded(child: Text(date + " - " + (e["text"] as String), style: const TextStyle(color: Colors.white70, fontSize: 13))),
              ]),
            );
          }).toList(),
        );
      },
    );
  }
}

class _FinanceiroTab extends StatefulWidget {
  final String managerId;
  final bool isSelf;
  const _FinanceiroTab({required this.managerId, required this.isSelf});

  @override
  State<_FinanceiroTab> createState() => _FinanceiroTabState();
}

class _FinanceiroTabState extends State<_FinanceiroTab> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final client = Supabase.instance.client;
    final profile = await client.from("collaborator_financial_profile").select().eq("manager_id", widget.managerId).maybeSingle();
    final tiers = await client.from("collaborator_bonus_tiers").select().eq("manager_id", widget.managerId).order("order_index");
    final pendingInvoices = await client
        .from("financial_entries")
        .select()
        .eq("manager_id", widget.managerId)
        .not("notified_at", "is", null)
        .isFilter("invoice_confirmed_at", null)
        .order("payment_date", ascending: false);
    return {
      "profile": profile,
      "tiers": (tiers as List).cast<Map<String, dynamic>>(),
      "pendingInvoices": (pendingInvoices as List).cast<Map<String, dynamic>>(),
    };
  }

  Future<void> _confirmInvoiceSent(String entryId) async {
    final client = Supabase.instance.client;
    await client.from("financial_entries").update({"invoice_confirmed_at": DateTime.now().toIso8601String()}).eq("id", entryId);
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final profile = snapshot.data!["profile"] as Map<String, dynamic>?;
        final tiers = snapshot.data!["tiers"] as List<Map<String, dynamic>>;
        final pendingInvoices = snapshot.data!["pendingInvoices"] as List<Map<String, dynamic>>;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.isSelf && pendingInvoices.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.amber.withOpacity(0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.amber.withOpacity(0.4))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Confirmar envio de nota fiscal", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14)),
                    const Text("Envie a nota fiscal para mduckagency@gmail.com e confirme abaixo.", style: TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(height: 12),
                    ...pendingInvoices.map((e) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text((e["description"] as String?) ?? "Pagamento", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                  Text("R\$ " + (e["amount"] as num).toStringAsFixed(2) + (e["payment_date"] != null ? "  -  " + e["payment_date"] : ""), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () => _confirmInvoiceSent(e["id"] as String),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                              child: const Text("Confirmar envio", style: TextStyle(fontSize: 12)),
                            ),
                          ]),
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (profile == null)
              const Text("Nenhum dado financeiro cadastrado ainda. Fale com o Financeiro/Dono.", style: TextStyle(color: Colors.white54))
            else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(14)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (profile["base_salary"] != null) Text("Salario: R\$ " + (profile["base_salary"] as num).toStringAsFixed(2), style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                    if (profile["commission_rate"] != null) Text("Comissao: " + (profile["commission_rate"] as num).toString() + "%", style: const TextStyle(color: Colors.white70)),
                    if (profile["cost_assistance"] != null) Text("Ajuda de custo: R\$ " + (profile["cost_assistance"] as num).toStringAsFixed(2), style: const TextStyle(color: Colors.white70)),
                    Text("Pagamento: " + (profile["payment_method"] as String? ?? "-") + " - todo dia " + (profile["payment_day"]?.toString() ?? "-"), style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text("Regras de Bonificacao", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              if (tiers.isEmpty)
                const Text("Nenhuma faixa cadastrada.", style: TextStyle(color: Colors.white38, fontSize: 12))
              else
                ...tiers.map((t) => Text(
                      (t["goal_type"] as String) + ": " + (t["threshold_value"] as num).toStringAsFixed(0) + " -> + R\$ " + (t["bonus_amount"] as num).toStringAsFixed(2),
                      style: const TextStyle(color: Colors.amber, fontSize: 13),
                    )),
            ],
          ],
        );
      },
    );
  }
}

class _ContaTab extends StatelessWidget {
  final Map<String, dynamic> manager;
  const _ContaTab({required this.manager});

  Future<void> _changePassword(BuildContext context) async {
    final newPasswordController = TextEditingController();
    final confirmController = TextEditingController();
    String? errorMessage;
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text("Alterar senha", style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: newPasswordController, obscureText: true, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Nova senha", labelStyle: TextStyle(color: Colors.white54))),
              const SizedBox(height: 8),
              TextField(controller: confirmController, obscureText: true, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Confirmar senha", labelStyle: TextStyle(color: Colors.white54))),
              if (errorMessage != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 12))),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancelar")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
              onPressed: () async {
                if (newPasswordController.text.trim().length < 6) {
                  setState(() => errorMessage = "A senha deve ter pelo menos 6 caracteres.");
                  return;
                }
                if (newPasswordController.text.trim() != confirmController.text.trim()) {
                  setState(() => errorMessage = "As senhas nao coincidem.");
                  return;
                }
                try {
                  await Supabase.instance.client.auth.updateUser(UserAttributes(password: newPasswordController.text.trim()));
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Senha alterada com sucesso.")));
                  }
                } catch (e) {
                  setState(() => errorMessage = "Erro ao alterar senha: " + e.toString());
                }
              },
              child: const Text("Salvar"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("E-mail: " + (manager["login_email"] as String), style: const TextStyle(color: Colors.white)),
          Text("Cargo/permissao: " + ((manager["role"] as String?) ?? "recrutador"), style: const TextStyle(color: Colors.white70)),
          if ((manager["financial_role"] as String?) != null) Text("Acesso financeiro: " + manager["financial_role"], style: const TextStyle(color: Colors.amber)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _changePassword(context),
            icon: const Icon(Icons.lock_outline, size: 16),
            label: const Text("Alterar senha"),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _EditProfileDialog extends StatefulWidget {
  final Map<String, dynamic> manager;
  const _EditProfileDialog({required this.manager});

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late TextEditingController _fullName, _username, _tiktokLogin, _whatsapp, _cpfCnpj, _contractType, _positionTitle, _department;
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
    _department = TextEditingController(text: m["department"] ?? "");
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
      "department": _department.text.trim(),
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
                const Text("Editar perfil", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
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
                TextField(controller: _department, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Departamento", labelStyle: TextStyle(color: Colors.white54))),
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










