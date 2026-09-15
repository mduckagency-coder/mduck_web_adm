import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "money_utils.dart";

/// Cria um lead de indicacao (origin = "Indicacao"), reaproveitado tanto pelo
/// cadastro unico quanto pelo cadastro em lote -- pra nao duplicar a logica
/// de achar a etapa inicial do kanban e registrar o historico de criacao.
Future<void> _createReferralLead(
  SupabaseClient client, {
  required String userId,
  required String agencyId,
  required String name,
  required String indicatedBy,
  String phone = "",
  String pix = "",
  double? amount,
}) async {
  var initialStage = await client.from("lead_kanban_stages").select("stage_key").eq("agency_id", agencyId).eq("is_initial", true).eq("is_active", true).maybeSingle();
  initialStage ??= await client.from("lead_kanban_stages").select("stage_key").eq("agency_id", agencyId).eq("is_active", true).order("order_index").limit(1).maybeSingle();

  final inserted = await client.from("leads").insert({
    "agency_id": agencyId,
    "recruiter_id": userId,
    "created_by": userId,
    "name": name,
    "tiktok_username": "",
    "phone": phone,
    "origin": "Indicacao",
    "origin_detail": indicatedBy,
    "pix_key": pix,
    "status": initialStage != null ? initialStage["stage_key"] : "novo",
  }).select("id").single();

  await client.from("lead_history").insert({
    "lead_id": inserted["id"],
    "action": "criacao",
    "detail": "Lead cadastrado",
    "performed_by": userId,
  });

  if (amount != null) {
    await client.from("financial_entries").insert({
      "agency_id": agencyId,
      "entry_type": "indicacao",
      "category": "Indicacao",
      "description": "Bonus de indicacao - " + name,
      "notes": pix.isEmpty ? null : "Chave PIX: " + pix,
      "related_lead_id": inserted["id"],
      "amount": amount,
      "due_date": DateTime.now().toIso8601String().substring(0, 10),
      "status": "pendente",
      "created_by": userId,
    });
  }
}

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
        .select(
          "id, name, origin_detail, pix_key, referrer_streamer_id, status, created_at, converted_at, referral_validated_at, "
          "managers!leads_recruiter_id_fkey(login_email), financial_entries(id, status), "
          "referrer:profiles!leads_referrer_streamer_id_fkey(id, display_name, tiktok_creator_id, pix_key)",
        )
        .eq("origin", "Indicacao")
        .order("created_at", ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  /// Status do bonus de indicacao: null = ainda nao lancado, senao o status
  /// do financial_entries mais recente ("pendente", "pago" ou "cancelado").
  String? _paymentStatus(Map<String, dynamic> lead) {
    final entries = lead["financial_entries"];
    if (entries is! List || entries.isEmpty) return null;
    final first = entries.first;
    return first is Map ? first["status"] as String? : null;
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withOpacity(0.5))),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  bool _isValidado(Map<String, dynamic> lead) => lead["referral_validated_at"] != null;

  Future<void> _validate(Map<String, dynamic> lead) async {
    final client = Supabase.instance.client;
    await client.from("leads").update({"referral_validated_at": DateTime.now().toIso8601String()}).eq("id", lead["id"]);
    setState(() => _future = _load());
  }

  Widget _validadoIndicator(Map<String, dynamic> lead, {bool allowValidate = true}) {
    if (_isValidado(lead)) return _badge("VALIDADO", Colors.greenAccent);
    if (!allowValidate) return _badge("NAO VALIDADO", Colors.white54);
    return TextButton(
      onPressed: () => _validate(lead),
      style: TextButton.styleFrom(foregroundColor: Colors.amber, padding: const EdgeInsets.symmetric(horizontal: 8)),
      child: const Text("Validar", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _paymentBadge(Map<String, dynamic> lead, {bool showLaunchAction = true}) {
    final status = _paymentStatus(lead);
    switch (status) {
      case "pago":
        return _badge("PAGO", Colors.greenAccent);
      case "pendente":
        return _badge("PENDENTE", Colors.amber);
      case "cancelado":
        return _badge("CANCELADO", Colors.white38);
      default:
        return showLaunchAction
            ? TextButton(onPressed: () => _launchBonus(lead), child: const Text("Lancar bonus", style: TextStyle(fontSize: 11)))
            : const Text("-", style: TextStyle(color: Colors.white24, fontSize: 12));
    }
  }

  void _launchBonus(Map<String, dynamic> lead) {
    final referrer = lead["referrer"];
    showDialog(
      context: context,
      builder: (context) => _ReferralBonusDialog(
        leadId: lead["id"] as String,
        leadName: lead["name"] as String,
        leadPix: lead["pix_key"] as String?,
        initialReferrerId: referrer is Map ? referrer["id"] as String? : null,
        initialReferrerName: referrer is Map ? referrer["display_name"] as String? : null,
      ),
    ).then((saved) {
      if (saved == true) setState(() => _future = _load());
    });
  }

  String _referrerLabel(Map<String, dynamic> lead) {
    final referrer = lead["referrer"];
    if (referrer is Map && referrer["display_name"] != null) {
      return referrer["display_name"] as String;
    }
    final detail = lead["origin_detail"] as String?;
    return detail?.isNotEmpty == true ? detail! : "-";
  }

  void _addReferral() {
    showDialog(context: context, builder: (context) => const _AddReferralDialog()).then((saved) {
      if (saved == true) setState(() => _future = _load());
    });
  }

  void _addReferralBulk() {
    showDialog(context: context, builder: (context) => const _BulkAddReferralDialog()).then((saved) {
      if (saved == true) setState(() => _future = _load());
    });
  }

  void _editReferral(Map<String, dynamic> lead) {
    showDialog(context: context, builder: (context) => _IndicacaoDetailDialog(lead: lead)).then((saved) {
      if (saved == true) setState(() => _future = _load());
    });
  }

  /// Uma indicacao por linha, em coluna (nao Row com Expanded fixos) pra nao
  /// estourar a largura em tela estreita/celular -- os selos e o botao de
  /// editar ficam num Wrap, que quebra linha em vez de cortar conteudo.
  Widget _indicacaoTile(
    Map<String, dynamic> l, {
    required String roleLabel,
    required String roleValue,
    String? dateText,
    required bool allowValidate,
    required bool showLaunchAction,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white12))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(l["name"] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
            if (dateText != null) ...[
              Text(dateText, style: const TextStyle(color: Colors.white38, fontSize: 12)),
              const SizedBox(width: 4),
            ],
            IconButton(
              icon: const Icon(Icons.edit, size: 16, color: Colors.white54),
              tooltip: "Editar / excluir / observacoes",
              onPressed: () => _editReferral(l),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ]),
          const SizedBox(height: 2),
          Text("Indicado por: " + _referrerLabel(l), style: const TextStyle(color: Colors.white70, fontSize: 12)),
          Text(roleLabel + ": " + roleValue, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _validadoIndicator(l, allowValidate: allowValidate),
              _paymentBadge(l, showLaunchAction: showLaunchAction),
            ],
          ),
        ],
      ),
    );
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
            OutlinedButton.icon(
              onPressed: _addReferralBulk,
              icon: const Icon(Icons.playlist_add, size: 16),
              label: const Text("Adicionar em lote"),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white70, side: const BorderSide(color: Colors.white24)),
            ),
            const SizedBox(width: 8),
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
                              return _indicacaoTile(l, roleLabel: "Agenciado por", roleValue: recruiterEmail, dateText: date, allowValidate: true, showLaunchAction: true);
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
                              return _indicacaoTile(l, roleLabel: "Recrutador", roleValue: recruiterEmail, allowValidate: false, showLaunchAction: false);
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
  final String? initialReferrerId;
  final String? initialReferrerName;
  const _ReferralBonusDialog({
    required this.leadId,
    required this.leadName,
    this.leadPix,
    this.initialReferrerId,
    this.initialReferrerName,
  });

  @override
  State<_ReferralBonusDialog> createState() => _ReferralBonusDialogState();
}

class _ReferralBonusDialogState extends State<_ReferralBonusDialog> {
  final _amountController = TextEditingController();
  late final _pixController = TextEditingController(text: widget.leadPix ?? "");
  String? _selectedStreamerId;
  String? _selectedStreamerName;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedStreamerId = widget.initialReferrerId;
    _selectedStreamerName = widget.initialReferrerName;
  }

  Future<void> _pickStreamer() async {
    final picked = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _StreamerPickerDialog(),
    );
    if (picked == null) return;
    setState(() {
      _selectedStreamerId = picked["id"] as String;
      _selectedStreamerName = picked["display_name"] as String;
      final pix = picked["pix_key"] as String?;
      if (pix != null && pix.isNotEmpty) _pixController.text = pix;
    });
  }

  Future<void> _save() async {
    if (_amountController.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;
    final manager = await client.from("managers").select("agency_id").eq("id", userId).single();
    final pix = _pixController.text.trim();
    await client.from("leads").update({
      "pix_key": pix,
      "referrer_streamer_id": _selectedStreamerId,
    }).eq("id", widget.leadId);
    await client.from("financial_entries").insert({
      "agency_id": manager["agency_id"],
      "entry_type": "indicacao",
      "category": "Indicacao",
      "description": "Bonus de indicacao - " + widget.leadName + (_selectedStreamerName != null ? " (indicado por " + _selectedStreamerName! + ")" : ""),
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
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Confirmar indicacao e lancar bonus", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              Text(widget.leadName, style: const TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 16),
              const Text("Streamer que sera pago (quem indicou)", style: TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      _selectedStreamerName ?? "Nenhum streamer do CRM selecionado",
                      style: TextStyle(color: _selectedStreamerName != null ? Colors.white : Colors.white38, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(onPressed: _pickStreamer, child: const Text("Buscar no CRM", style: TextStyle(fontSize: 12))),
              ]),
              const SizedBox(height: 12),
              TextField(controller: _amountController, autofocus: true, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Valor do bonus R\$", labelStyle: TextStyle(color: Colors.white54))),
              const SizedBox(height: 8),
              TextField(controller: _pixController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Chave PIX de quem indicou", labelStyle: TextStyle(color: Colors.white54))),
              const SizedBox(height: 4),
              const Text("Selecionar um streamer do CRM preenche a chave PIX automaticamente (ainda editavel).", style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic)),
              const SizedBox(height: 16),
              Text("Sera criado como Conta a Pagar pendente, aparecendo em Pagamentos.", style: const TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic)),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancelar")),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                  child: Text(_saving ? "Salvando..." : "Confirmar"),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

/// Busca rapida nos streamers da agencia (CRM/profiles) pra vincular quem fez
/// a indicacao e puxar a chave PIX ja cadastrada no CRM, em vez de digitar na
/// mao toda vez que o coordenador confirma o pagamento.
class _StreamerPickerDialog extends StatefulWidget {
  const _StreamerPickerDialog();

  @override
  State<_StreamerPickerDialog> createState() => _StreamerPickerDialogState();
}

class _StreamerPickerDialogState extends State<_StreamerPickerDialog> {
  late Future<List<Map<String, dynamic>>> _future;
  String _search = "";

  @override
  void initState() {
    super.initState();
    _future = Supabase.instance.client
        .from("profiles")
        .select("id, display_name, tiktok_creator_id, pix_key")
        .order("display_name")
        .then((rows) => (rows as List).cast<Map<String, dynamic>>());
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 480),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Selecionar streamer do CRM", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search, color: Colors.white54), hintText: "Buscar por nick ou ID", hintStyle: TextStyle(color: Colors.white38), isDense: true),
                onChanged: (v) => setState(() => _search = v),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return Text("Erro ao carregar: " + snapshot.error.toString(), style: const TextStyle(color: Colors.redAccent));
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final all = snapshot.data!;
                    final filtered = _search.isEmpty
                        ? all
                        : all.where((s) {
                            final name = (s["display_name"] as String? ?? "").toLowerCase();
                            final id = (s["tiktok_creator_id"] as String?) ?? "";
                            return name.contains(_search.toLowerCase()) || id.contains(_search);
                          }).toList();
                    if (filtered.isEmpty) return const Text("Nenhum streamer encontrado.", style: TextStyle(color: Colors.white54));
                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final s = filtered[index];
                        final hasPix = (s["pix_key"] as String?)?.isNotEmpty == true;
                        return ListTile(
                          dense: true,
                          title: Text(s["display_name"] as String? ?? "-", style: const TextStyle(color: Colors.white)),
                          subtitle: Text((s["tiktok_creator_id"] as String?) ?? "-", style: const TextStyle(color: Colors.white38, fontSize: 12)),
                          trailing: hasPix ? const Text("PIX ok", style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)) : null,
                          onTap: () => Navigator.of(context).pop(s),
                        );
                      },
                    );
                  },
                ),
              ),
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

    await _createReferralLead(
      client,
      userId: userId,
      agencyId: manager["agency_id"] as String,
      name: _nameController.text.trim(),
      indicatedBy: _indicatedByController.text.trim(),
      phone: _phoneController.text.trim(),
      pix: _pixController.text.trim(),
    );

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

/// Detalhe de uma indicacao: editar dados, ver/adicionar observacoes
/// (reaproveita o mesmo padrao de lead_history "observacao" ja usado no
/// modulo de Recrutamento) e excluir. Exclusao fica bloqueada quando ja tem
/// bonus lancado, pra nao deixar um financial_entries orfao -- nesse caso o
/// pagamento e cancelado direto em Pagamentos.
class _IndicacaoDetailDialog extends StatefulWidget {
  final Map<String, dynamic> lead;
  const _IndicacaoDetailDialog({required this.lead});

  @override
  State<_IndicacaoDetailDialog> createState() => _IndicacaoDetailDialogState();
}

class _IndicacaoDetailDialogState extends State<_IndicacaoDetailDialog> {
  late final _nameController = TextEditingController(text: widget.lead["name"] as String? ?? "");
  late final _indicatedByController = TextEditingController(text: widget.lead["origin_detail"] as String? ?? "");
  late final _pixController = TextEditingController(text: widget.lead["pix_key"] as String? ?? "");
  final _obsController = TextEditingController();
  late Future<List<Map<String, dynamic>>> _historyFuture;
  bool _savingEdit = false;
  bool _savingObs = false;
  bool _deleting = false;

  bool get _bonusLaunched {
    final entries = widget.lead["financial_entries"];
    return entries is List && entries.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    _historyFuture = _loadHistory();
  }

  Future<List<Map<String, dynamic>>> _loadHistory() async {
    final client = Supabase.instance.client;
    final rows = await client.from("lead_history").select().eq("lead_id", widget.lead["id"]).eq("action", "observacao").order("created_at", ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> _saveEdit() async {
    setState(() => _savingEdit = true);
    final client = Supabase.instance.client;
    await client.from("leads").update({
      "name": _nameController.text.trim(),
      "origin_detail": _indicatedByController.text.trim(),
      "pix_key": _pixController.text.trim(),
    }).eq("id", widget.lead["id"]);
    if (mounted) setState(() => _savingEdit = false);
  }

  Future<void> _saveObservation() async {
    if (_obsController.text.trim().isEmpty) return;
    setState(() => _savingObs = true);
    final client = Supabase.instance.client;
    await client.from("lead_history").insert({
      "lead_id": widget.lead["id"],
      "action": "observacao",
      "detail": _obsController.text.trim(),
      "performed_by": client.auth.currentUser!.id,
    });
    _obsController.clear();
    setState(() {
      _savingObs = false;
      _historyFuture = _loadHistory();
    });
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text("Excluir indicacao?", style: TextStyle(color: Colors.white)),
        content: const Text("Isso remove a indicacao e seu historico permanentemente. Nao pode ser desfeito.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text("Excluir"),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _deleting = true);
    final client = Supabase.instance.client;
    await client.from("lead_history").delete().eq("lead_id", widget.lead["id"]);
    await client.from("leads").delete().eq("id", widget.lead["id"]);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Editar indicacao", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(controller: _nameController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Nome do indicado", labelStyle: TextStyle(color: Colors.white54))),
              const SizedBox(height: 8),
              TextField(controller: _indicatedByController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Indicado por", labelStyle: TextStyle(color: Colors.white54))),
              const SizedBox(height: 8),
              TextField(controller: _pixController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Chave PIX de quem indicou", labelStyle: TextStyle(color: Colors.white54))),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: _savingEdit ? null : _saveEdit,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
                  child: Text(_savingEdit ? "Salvando..." : "Salvar alteracoes"),
                ),
              ),
              const Divider(color: Colors.white12, height: 28),
              const Text("Observacoes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              Flexible(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _historyFuture,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox(height: 40, child: Center(child: CircularProgressIndicator()));
                    final notes = snapshot.data!;
                    if (notes.isEmpty) return const Text("Nenhuma observacao ainda.", style: TextStyle(color: Colors.white38, fontSize: 12));
                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: notes.length,
                      itemBuilder: (context, index) {
                        final n = notes[index];
                        final date = DateTime.parse(n["created_at"] as String).toLocal().toString().substring(0, 16);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text("- (" + date + ") " + (n["detail"] as String? ?? ""), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _obsController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(labelText: "Adicionar observacao", labelStyle: TextStyle(color: Colors.white54, fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _savingObs ? null : _saveObservation,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
                  child: Text(_savingObs ? "..." : "Add"),
                ),
              ]),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                _bonusLaunched
                    ? const Text("Bonus ja lancado -- cancele em Pagamentos antes de excluir.", style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic))
                    : TextButton.icon(
                        onPressed: _deleting ? null : _confirmDelete,
                        icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                        label: Text(_deleting ? "Excluindo..." : "Excluir indicacao", style: const TextStyle(color: Colors.redAccent)),
                      ),
                TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text("Fechar")),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cadastro em lote de indicacoes -- pra quando o coordenador ja tem uma
/// lista pronta (planilha) e cadastrar uma por uma seria lento demais. Cada
/// linha vira um lead de indicacao; se o valor do bonus vier preenchido, o
/// pagamento pendente ja sai lancado direto (sem precisar abrir "Lancar
/// bonus" depois pra cada um).
class _BulkAddReferralDialog extends StatefulWidget {
  const _BulkAddReferralDialog();

  @override
  State<_BulkAddReferralDialog> createState() => _BulkAddReferralDialogState();
}

class _BulkReferralRow {
  final nameController = TextEditingController();
  final indicatedByController = TextEditingController();
  final pixController = TextEditingController();
  final amountController = TextEditingController();
}

class _BulkAddReferralDialogState extends State<_BulkAddReferralDialog> {
  final List<_BulkReferralRow> _rows = [_BulkReferralRow(), _BulkReferralRow(), _BulkReferralRow()];
  bool _saving = false;
  String? _error;

  void _addRow() => setState(() => _rows.add(_BulkReferralRow()));

  void _removeRow(int index) => setState(() => _rows.removeAt(index));

  Future<void> _save() async {
    final valid = _rows.where((r) => r.nameController.text.trim().isNotEmpty).toList();
    if (valid.isEmpty) {
      setState(() => _error = "Preencha ao menos o nome do indicado em uma linha.");
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser!.id;
      final manager = await client.from("managers").select("agency_id").eq("id", userId).single();
      final agencyId = manager["agency_id"] as String;

      for (final row in valid) {
        final amountText = row.amountController.text.trim();
        await _createReferralLead(
          client,
          userId: userId,
          agencyId: agencyId,
          name: row.nameController.text.trim(),
          indicatedBy: row.indicatedByController.text.trim(),
          pix: row.pixController.text.trim(),
          amount: amountText.isEmpty ? null : parseAmount(amountText),
        );
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = "Erro ao salvar: " + e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Adicionar indicacoes em lote", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text("Preencha uma linha por indicacao. Chave PIX e Valor sao opcionais -- se o valor vier preenchido, o bonus ja sai lancado como pendente.", style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic)),
              const SizedBox(height: 12),
              Row(children: const [
                Expanded(flex: 3, child: Text("Indicado", style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold))),
                SizedBox(width: 8),
                Expanded(flex: 3, child: Text("Quem indicou", style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold))),
                SizedBox(width: 8),
                Expanded(flex: 3, child: Text("Chave PIX", style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold))),
                SizedBox(width: 8),
                Expanded(flex: 2, child: Text("Valor R\$", style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold))),
                SizedBox(width: 32),
              ]),
              const SizedBox(height: 4),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _rows.length,
                  itemBuilder: (context, index) {
                    final row = _rows[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(children: [
                        Expanded(flex: 3, child: TextField(controller: row.nameController, style: const TextStyle(color: Colors.white, fontSize: 13), decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()))),
                        const SizedBox(width: 8),
                        Expanded(flex: 3, child: TextField(controller: row.indicatedByController, style: const TextStyle(color: Colors.white, fontSize: 13), decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()))),
                        const SizedBox(width: 8),
                        Expanded(flex: 3, child: TextField(controller: row.pixController, style: const TextStyle(color: Colors.white, fontSize: 13), decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()))),
                        const SizedBox(width: 8),
                        Expanded(flex: 2, child: TextField(controller: row.amountController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white, fontSize: 13), decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()))),
                        SizedBox(
                          width: 32,
                          child: _rows.length > 1
                              ? IconButton(padding: EdgeInsets.zero, icon: const Icon(Icons.close, size: 16, color: Colors.white38), onPressed: () => _removeRow(index))
                              : null,
                        ),
                      ]),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(onPressed: _addRow, icon: const Icon(Icons.add, size: 16), label: const Text("Adicionar linha")),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
              ],
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancelar")),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                  child: Text(_saving ? "Salvando..." : "Salvar todas"),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
