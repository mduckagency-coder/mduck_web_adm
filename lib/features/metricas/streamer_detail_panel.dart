import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "level_maintenance_page.dart";

class StreamerDetailPanel extends StatefulWidget {
  final Map<String, dynamic> item;
  const StreamerDetailPanel({super.key, required this.item});

  @override
  State<StreamerDetailPanel> createState() => _StreamerDetailPanelState();
}

class _StreamerDetailPanelState extends State<StreamerDetailPanel> {
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _observations = [];
  bool _loading = true;
  bool _showMore = false;
  final _obsController = TextEditingController();
  bool _savingObs = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final client = Supabase.instance.client;
    final id = widget.item["id"] as String;

    final profile = await client
        .from("profiles")
        .select(
            "tiktok_creator_id, tiktok_group_name, phone, email, joined_at, is_active, last_live_at, tiktok_agent_email, assigned_manager_id, recruited_by_manager_id, managers!profiles_assigned_manager_id_fkey(login_email)")
        .eq("id", id)
        .maybeSingle();

    String? agentEmail = profile?["tiktok_agent_email"] as String?;
    if (agentEmail == null || agentEmail.isEmpty) {
      final rid = profile?["recruited_by_manager_id"];
      if (rid != null) {
        final m = await client.from("managers").select("login_email").eq("id", rid).maybeSingle();
        agentEmail = m?["login_email"] as String?;
      }
    }
    if (profile != null) profile["resolvedAgentEmail"] = agentEmail;

    final obs = await client.from("streamer_observations").select("note, created_at, managers(login_email)").eq("streamer_id", id).order("created_at", ascending: false);

    setState(() {
      _profile = profile;
      _observations = (obs as List).cast<Map<String, dynamic>>();
      _loading = false;
    });
  }

  Future<void> _addObservation() async {
    if (_obsController.text.trim().isEmpty) return;
    setState(() => _savingObs = true);
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;
    await client.from("streamer_observations").insert({
      "streamer_id": widget.item["id"],
      "note": _obsController.text.trim(),
      "created_by": userId,
    });
    _obsController.clear();
    final obs = await client.from("streamer_observations").select("note, created_at, managers(login_email)").eq("streamer_id", widget.item["id"]).order("created_at", ascending: false);
    setState(() {
      _observations = (obs as List).cast<Map<String, dynamic>>();
      _savingObs = false;
    });
  }

  (String, String, Color) _statusBadge() {
    final i = widget.item;
    final nextThreshold = i["nextThreshold"] as int?;
    if (i["canUpgradeDiamonds"] == true && nextThreshold != null) {
      return ("\ud83d\udfe2", "Proximo de subir para " + (nextThreshold ~/ 1000).toString() + "k", Colors.greenAccent);
    }
    if (i["maintained"] == true) return ("\ud83d\udfe2", "Mantendo o nivel", Colors.greenAccent);
    if (i["isRecovering"] == true) return ("\ud83d\udfe0", "Precisa recuperar o nivel", Colors.orangeAccent);
    if (i["meetsMaintDiamonds"] == true && i["meetsMaintActivity"] != true) return ("\ud83d\udfe1", "Em evolucao (falta atividade)", Colors.amber);
    final gap = i["effDiamondGap"] as double;
    final target = (i["usesUpgradeGap"] == true ? i["nextThreshold"] : i["requiredThreshold"]) as int? ?? 1;
    if (gap / target < 0.3) return ("\ud83d\udfe1", "Em evolucao", Colors.amber);
    return ("\ud83d\udd34", "Risco de perder manutencao", Colors.redAccent);
  }

  Widget _historicoCard() {
    final i = widget.item;
    final previousThreshold = i["requiredThreshold"] as int;
    final previousTier = i["previousLevel"] as int;
    final previousDiamonds = (i["previousDiamonds"] as num).toDouble();
    final historicoEmoji = i["historicoEmoji"] as String;
    final historicoLabel = i["historicoLabel"] as String;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("HISTORICO DO ULTIMO MES", style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          _kv("Diamantes do mes passado", previousDiamonds.toStringAsFixed(0)),
          _kv("Tier conquistado", "Tier " + previousTier.toString() + " (" + previousThreshold.toString() + ")"),
          const SizedBox(height: 6),
          Row(children: [
            Text(historicoEmoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Expanded(child: Text(historicoLabel, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
          ]),
          Builder(builder: (context) {
            final currentLevelNow = i["currentLevelNow"] as int;
            final showManutencao = previousTier >= 2 && currentLevelNow == previousTier;
            final subidaCount = (previousTier >= 2 && currentLevelNow > previousTier) ? (currentLevelNow - previousTier) : 0;
            if (!showManutencao && subidaCount == 0) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(spacing: 6, runSpacing: 6, children: [
                if (showManutencao)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                    child: const Text("Manutencao de Nivel", style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ...List.generate(subidaCount, (idx) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                      child: const Text("Subida de Nivel", style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold)),
                    )),
              ]),
            );
          }),
        ],
      ),
    );
  }

  Widget _metaCard() {
    final i = widget.item;
    final atMax = i["atMaxLevel"] == true;

    if (atMax) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.greenAccent.withOpacity(0.3))),
        child: const Text("Tier maximo (10) ja atingido!", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
      );
    }

    final target = (i["nextThreshold"] as int).toDouble();
    final current = (i["currentDiamonds"] as num).toDouble();
    final targetTier = i["nextLevel"] as int;
    final gap = (i["effDiamondGap"] as double);
    final fraction = (current / target).clamp(0.0, 1.0);
    final probability = i["probability"] as String;
    final probColor = probability == "Alta" ? Colors.greenAccent : probability == "Media" ? Colors.amber : Colors.orangeAccent;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFF7A0BD4).withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF7A0BD4).withOpacity(0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("META DO MES ATUAL", style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          _kv("Objetivo", "Tier " + targetTier.toString() + " (" + target.toStringAsFixed(0) + " diamantes)"),
          _kv("Atual", current.toStringAsFixed(0)),
          _kv("Faltam", gap.toStringAsFixed(0)),
          const SizedBox(height: 8),
          ClipRRect(borderRadius: BorderRadius.circular(5), child: LinearProgressIndicator(value: fraction, minHeight: 10, backgroundColor: Colors.white12, valueColor: AlwaysStoppedAnimation(fraction >= 1 ? Colors.greenAccent : const Color(0xFF7A0BD4)))),
          const SizedBox(height: 6),
          Row(children: [
            Text("Progresso: " + (fraction * 100).toStringAsFixed(0) + "%", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            const Spacer(),
            Text("Probabilidade: " + probability, style: TextStyle(color: probColor, fontSize: 12, fontWeight: FontWeight.bold)),
          ]),
        ],
      ),
    );
  }

  Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12))),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  void _openNotifyManager() {
    showDialog(
      context: context,
      builder: (context) => _NotifyManagerDialog(
        streamerId: widget.item["id"] as String,
        streamerName: widget.item["display_name"] as String,
        managerId: (_profile?["assigned_manager_id"] as String?) ?? (widget.item["recruited_by_manager_id"] as String?) ?? (_profile?["recruited_by_manager_id"] as String?),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.item;
    final status = _statusBadge();
    final screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      alignment: Alignment.centerRight,
      insetPadding: const EdgeInsets.all(0),
      backgroundColor: const Color(0xFF1A1A1A),
      child: SizedBox(
        width: 420,
        height: screenHeight,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: Text("Detalhes do Streamer", style: const TextStyle(color: Colors.white54, fontSize: 12))),
                      IconButton(icon: const Icon(Icons.close, color: Colors.white70), onPressed: () => Navigator.of(context).pop()),
                    ]),
                    Center(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: Colors.white24,
                            backgroundImage: i["avatar_url"] != null ? NetworkImage(i["avatar_url"] as String) : null,
                            child: i["avatar_url"] == null ? const Icon(Icons.person, color: Colors.white70, size: 40) : null,
                          ),
                          const SizedBox(height: 10),
                          Text(i["display_name"] as String, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          Text("ID: " + (_profile?["tiktok_creator_id"]?.toString() ?? "-"), style: const TextStyle(color: Colors.white38, fontSize: 11)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(border: Border.all(color: status.$3), borderRadius: BorderRadius.circular(8)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(status.$1 + " ", style: const TextStyle(fontSize: 13)),
                        Text(status.$2, style: TextStyle(color: status.$3, fontSize: 12, fontWeight: FontWeight.bold)),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    _infoRow("Grupo", (_profile?["tiktok_group_name"] as String?) ?? "-"),
                    _infoRow("Agente responsavel", (_profile?["resolvedAgentEmail"] as String?) ?? "-"),
                    _infoRow("Gestor responsavel", _profile?["managers"] is Map ? (_profile!["managers"]["login_email"] as String? ?? "-") : "-"),
                    const SizedBox(height: 16),
                    const Text("Resumo do Mes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 10),
                    _progressLine("Diamantes", (i["currentDiamonds"] as num).toDouble(), (i["requiredThreshold"] as int).toDouble(), Colors.tealAccent),
                    _progressLine("Dias validos", (i["currentDays"] as num).toDouble(), (i["requiredDays"] as int).toDouble(), Colors.blueAccent),
                    _progressLine("Horas", (i["currentHours"] as num).toDouble(), (i["requiredHours"] as int).toDouble(), Colors.purpleAccent),
                    const SizedBox(height: 8),
                    Text("Tier atual: " + i["previousLevel"].toString() + (i["nextLevel"] != null ? "   Proximo Tier: " + i["nextLevel"].toString() : ""), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 16),
                    const Text("Acoes Rapidas", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 10),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      OutlinedButton.icon(onPressed: () => setState(() => _showMore = !_showMore), icon: const Icon(Icons.person_outline, size: 14), label: const Text("Ver Perfil Completo", style: TextStyle(fontSize: 12))),
                      OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.history, size: 14), label: const Text("Abrir Historico", style: TextStyle(fontSize: 12))),
                      OutlinedButton.icon(onPressed: _openNotifyManager, icon: const Icon(Icons.notifications_active, size: 14), label: const Text("Notificar Gestor", style: TextStyle(fontSize: 12))),
                    ]),
                    if (_showMore) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(10)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _infoRow("Telefone", (_profile?["phone"] as String?) ?? "-"),
                            _infoRow("E-mail", (_profile?["email"] as String?) ?? "-"),
                            _infoRow("Entrou em", _profile?["joined_at"] != null ? DateTime.parse(_profile!["joined_at"]).toLocal().toString().substring(0, 10) : "-"),
                            _infoRow("Ultima live", _profile?["last_live_at"] != null ? DateTime.parse(_profile!["last_live_at"]).toLocal().toString().substring(0, 16) : "-"),
                            _infoRow("Status", _profile?["is_active"] == true ? "Ativo" : "Inativo"),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    const Divider(color: Colors.white12),
                    const Text("Observacoes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _obsController,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: const InputDecoration(hintText: "Adicionar observacao...", hintStyle: TextStyle(color: Colors.white24), isDense: true),
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.send, color: Color(0xFF7A0BD4), size: 18), onPressed: _savingObs ? null : _addObservation),
                    ]),
                    const SizedBox(height: 8),
                    if (_observations.isEmpty)
                      const Text("Nenhuma observacao ainda.", style: TextStyle(color: Colors.white38, fontSize: 12))
                    else
                      ..._observations.map((o) {
                        final date = DateTime.parse(o["created_at"] as String).toLocal();
                        final author = o["managers"] is Map ? (o["managers"]["login_email"] as String? ?? "-") : "-";
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(8)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(o["note"] as String, style: const TextStyle(color: Colors.white, fontSize: 13)),
                              const SizedBox(height: 4),
                              Text(
                                date.toString().substring(0, 16) + " - " + author,
                                style: const TextStyle(color: Colors.white38, fontSize: 10),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        SizedBox(width: 130, child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12))),
        Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 12))),
      ]),
    );
  }

  Widget _progressLine(String label, double value, double target, Color color) {
    final fraction = target == 0 ? 1.0 : (value / target).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12))),
            Text(value.toStringAsFixed(0) + " / " + target.toStringAsFixed(0), style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 4),
          ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: fraction, minHeight: 6, backgroundColor: Colors.white12, valueColor: AlwaysStoppedAnimation(color))),
        ],
      ),
    );
  }
}

class _NotifyManagerDialog extends StatefulWidget {
  final String streamerId;
  final String streamerName;
  final String? managerId;
  const _NotifyManagerDialog({required this.streamerId, required this.streamerName, required this.managerId});

  @override
  State<_NotifyManagerDialog> createState() => _NotifyManagerDialogState();
}

class _NotifyManagerDialogState extends State<_NotifyManagerDialog> {
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  String _priority = "media";
  bool _saving = false;
  String? _errorMessage;

  Future<void> _send() async {
    if (widget.managerId == null) {
      setState(() => _errorMessage = "Este streamer nao possui gestor responsavel definido ainda.");
      return;
    }
    if (_subjectController.text.trim().isEmpty || _messageController.text.trim().isEmpty) {
      setState(() => _errorMessage = "Preencha assunto e mensagem.");
      return;
    }
    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      final client = Supabase.instance.client;
      await client.from("manager_notifications").insert({
        "manager_id": widget.managerId,
        "subject": _subjectController.text.trim(),
        "message": _messageController.text.trim(),
        "priority": _priority,
        "streamer_id": widget.streamerId,
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _saving = false;
        _errorMessage = "Erro ao enviar: " + e.toString();
      });
    }
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
              Text("Notificar Gestor sobre " + widget.streamerName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(controller: _subjectController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Assunto", labelStyle: TextStyle(color: Colors.white54))),
              const SizedBox(height: 8),
              TextField(controller: _messageController, maxLines: 3, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Mensagem", labelStyle: TextStyle(color: Colors.white54), border: OutlineInputBorder())),
              const SizedBox(height: 8),
              DropdownButton<String>(
                value: _priority,
                dropdownColor: const Color(0xFF1A1A1A),
                style: const TextStyle(color: Colors.white),
                items: const [
                  DropdownMenuItem(value: "baixa", child: Text("Baixa")),
                  DropdownMenuItem(value: "media", child: Text("Media")),
                  DropdownMenuItem(value: "alta", child: Text("Alta")),
                  DropdownMenuItem(value: "urgente", child: Text("Urgente")),
                ],
                onChanged: (v) => setState(() => _priority = v!),
              ),
              if (_errorMessage != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 12))),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancelar")),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _saving ? null : _send,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
                  child: Text(_saving ? "Enviando..." : "Enviar ao Gestor"),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}





