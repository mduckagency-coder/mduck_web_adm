import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";

class CrmPage extends StatefulWidget {
  const CrmPage({super.key});

  @override
  State<CrmPage> createState() => _CrmPageState();
}

class _CrmPageState extends State<CrmPage> {
  String _search = "";
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final client = Supabase.instance.client;
    final rows = await client.from("profiles").select("id, display_name, tiktok_creator_id, joined_at, is_active, recruited_by").order("display_name");
    return (rows as List).cast<Map<String, dynamic>>();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final all = snapshot.data!;
        final filtered = _search.isEmpty
            ? all
            : all.where((s) {
                final name = (s["display_name"] as String).toLowerCase();
                final id = (s["tiktok_creator_id"] as String?) ?? "";
                return name.contains(_search.toLowerCase()) || id.contains(_search);
              }).toList();

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text("CRM - Curriculo dos Streamers", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(width: 12),
                  IconButton(icon: const Icon(Icons.refresh, color: Colors.white70), onPressed: () => setState(() => _future = _load())),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 320,
                child: TextField(
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search, color: Colors.white54), hintText: "Buscar por nick ou ID", hintStyle: TextStyle(color: Colors.white38), isDense: true),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              const SizedBox(height: 12),
              Text(filtered.length.toString() + " streamers", style: const TextStyle(color: Colors.white54)),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final s = filtered[index];
                    final active = s["is_active"] as bool? ?? true;
                    return Column(
                      children: [
                        ListTile(
                          leading: const CircleAvatar(radius: 18, backgroundColor: Colors.white24, child: Icon(Icons.person, color: Colors.white54, size: 18)),
                          title: Text(s["display_name"] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            (s["tiktok_creator_id"] as String? ?? "-") + (s["recruited_by"] != null ? "  -  Recrutado por: " + s["recruited_by"] : ""),
                            style: const TextStyle(color: Colors.white38, fontSize: 12),
                          ),
                          trailing: !active
                              ? const Text("INATIVO", style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold))
                              : const Icon(Icons.chevron_right, color: Colors.white38),
                          onTap: () => showDialog(context: context, builder: (context) => _CrmDetailDialog(streamerId: s["id"] as String)),
                        ),
                        const Divider(color: Colors.white12, height: 1),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CrmDetailDialog extends StatefulWidget {
  final String streamerId;
  const _CrmDetailDialog({required this.streamerId});

  @override
  State<_CrmDetailDialog> createState() => _CrmDetailDialogState();
}

class _CrmDetailDialogState extends State<_CrmDetailDialog> {
  late Future<Map<String, dynamic>> _future;
  final _recruitedByController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _noteController = TextEditingController();
  bool _savingRecruited = false;
  bool _savingContact = false;
  bool _savingNote = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final client = Supabase.instance.client;

    final profile = await client
        .from("profiles")
        .select(
            "display_name, tiktok_username, tiktok_creator_id, tiktok_group_name, joined_at, is_active, left_at, left_reason, recruited_by, phone, email, avatar_url, streamer_categories(name), groups!profiles_group_id_fkey(name)")
        .eq("id", widget.streamerId)
        .single();

    _recruitedByController.text = (profile["recruited_by"] as String?) ?? "";
    _phoneController.text = (profile["phone"] as String?) ?? "";
    _emailController.text = (profile["email"] as String?) ?? "";

    final campaignRewards = await client
        .from("campaign_rewards")
        .select("value, reward_type, description, created_at, agency_campaigns(title)")
        .eq("streamer_id", widget.streamerId);

    final completedMissions = await client
        .from("streamer_missions")
        .select("completed_at, missions(title, reward_type, reward_detail)")
        .eq("streamer_id", widget.streamerId)
        .not("completed_at", "is", null);

    final notes = await client
        .from("streamer_contact_logs")
        .select("message_sent, manager_label, created_at, context")
        .eq("streamer_id", widget.streamerId)
        .order("created_at", ascending: false);

    final timeline = <Map<String, dynamic>>[];

    for (final r in (campaignRewards as List)) {
      final campaign = r["agency_campaigns"];
      timeline.add({
        "date": r["created_at"],
        "type": "premio",
        "text": "Premio recebido: " + ((r["description"] as String?) ?? (r["reward_type"] as String)) + (campaign is Map ? " (" + (campaign["title"] as String) + ")" : ""),
      });
    }
    for (final m in (completedMissions as List)) {
      final mission = m["missions"];
      if (mission == null) continue;
      timeline.add({
        "date": m["completed_at"],
        "type": "missao",
        "text": "Missao concluida: " + (mission["title"] as String) + " - Premio: " + (mission["reward_type"]?.toString() ?? "-"),
      });
    }
    for (final n in (notes as List)) {
      timeline.add({
        "date": n["created_at"],
        "type": "nota",
        "text": "[" + (n["context"] as String) + "] " + (n["manager_label"] ?? "Gestor") + ": " + (n["message_sent"] as String? ?? ""),
      });
    }

    timeline.sort((a, b) => (b["date"] as String).compareTo(a["date"] as String));

    return {"profile": profile, "timeline": timeline};
  }

  Future<void> _saveRecruitedBy() async {
    setState(() => _savingRecruited = true);
    final client = Supabase.instance.client;
    await client.from("profiles").update({"recruited_by": _recruitedByController.text.trim()}).eq("id", widget.streamerId);
    setState(() => _savingRecruited = false);
  }

  Future<void> _saveContact() async {
    setState(() => _savingContact = true);
    final client = Supabase.instance.client;
    await client.from("profiles").update({
      "phone": _phoneController.text.trim(),
      "email": _emailController.text.trim(),
    }).eq("id", widget.streamerId);
    setState(() => _savingContact = false);
  }

  Future<void> _endParticipation(bool currentlyActive) async {
    if (currentlyActive) {
      final reasonController = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text("Encerrar participacao do streamer?", style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Ele sera marcado como inativo e removido de rankings e missoes atuais. O historico permanece salvo.", style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 12),
              TextField(controller: reasonController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Motivo (opcional)", labelStyle: TextStyle(color: Colors.white54))),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancelar")),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              child: const Text("Encerrar participacao"),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      final client = Supabase.instance.client;
      await client.from("profiles").update({
        "is_active": false,
        "left_at": DateTime.now().toIso8601String(),
        "left_reason": reasonController.text.trim(),
        "assigned_manager_id": null,
      }).eq("id", widget.streamerId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Participacao encerrada. Streamer marcado como inativo."), backgroundColor: Colors.redAccent));
      }
    } else {
      final client = Supabase.instance.client;
      await client.from("profiles").update({
        "is_active": true,
        "left_at": null,
        "left_reason": null,
      }).eq("id", widget.streamerId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Streamer reativado com sucesso."), backgroundColor: Colors.greenAccent));
      }
    }
    setState(() => _future = _load());
  }

  Future<void> _saveNote() async {
    if (_noteController.text.trim().isEmpty) return;
    setState(() => _savingNote = true);
    final client = Supabase.instance.client;
    await client.from("streamer_contact_logs").insert({
      "streamer_id": widget.streamerId,
      "manager_id": client.auth.currentUser!.id,
      "manager_label": client.auth.currentUser!.email ?? "Gestor",
      "message_sent": _noteController.text.trim(),
      "context": "crm",
    });
    _noteController.clear();
    setState(() {
      _savingNote = false;
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 800),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: FutureBuilder<Map<String, dynamic>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return SizedBox(height: 150, child: Center(child: Text("Erro: " + snapshot.error.toString(), style: const TextStyle(color: Colors.redAccent))));
              }
              if (!snapshot.hasData) return const SizedBox(height: 300, child: Center(child: CircularProgressIndicator()));

              final p = snapshot.data!["profile"] as Map<String, dynamic>;
              final timeline = snapshot.data!["timeline"] as List<Map<String, dynamic>>;
              final groupData = p["groups"];
              final catData = p["streamer_categories"];
              final active = p["is_active"] as bool? ?? true;

              Widget row(String label, String value) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        SizedBox(width: 140, child: Text(label, style: const TextStyle(color: Colors.white54))),
                        Expanded(child: Text(value, style: const TextStyle(color: Colors.white))),
                      ],
                    ),
                  );

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: Colors.white24,
                          backgroundImage: p["avatar_url"] != null ? NetworkImage(p["avatar_url"] as String) : null,
                          child: p["avatar_url"] == null ? const Icon(Icons.person, color: Colors.white, size: 22) : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(p["display_name"] as String, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
                        if (!active)
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                            child: const Text("INATIVO", style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        OutlinedButton.icon(
                          onPressed: () => _endParticipation(active),
                          icon: Icon(active ? Icons.person_remove : Icons.person_add_alt, size: 16, color: active ? Colors.redAccent : Colors.greenAccent),
                          label: Text(active ? "Encerrar participacao" : "Reativar", style: TextStyle(color: active ? Colors.redAccent : Colors.greenAccent, fontSize: 12)),
                          style: OutlinedButton.styleFrom(side: BorderSide(color: active ? Colors.redAccent : Colors.greenAccent)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    row("ID TikTok", (p["tiktok_creator_id"] as String?) ?? "-"),
                    row("Nick TikTok", (p["tiktok_username"] as String?) ?? "-"),
                    row("Entrada na agencia", DateTime.parse(p["joined_at"] as String).toLocal().toString().substring(0, 10)),
                    row("Categoria", catData is Map ? catData["name"] as String? ?? "-" : "-"),
                    row("Grupo (interno)", groupData is Map ? groupData["name"] as String? ?? "Sem grupo" : "Sem grupo"),
                    row("Grupo (TikTok)", (p["tiktok_group_name"] as String?)?.isNotEmpty == true ? p["tiktok_group_name"] as String : "-"),
                    if (!active) row("Encerrado em", p["left_at"] != null ? DateTime.parse(p["left_at"] as String).toLocal().toString().substring(0, 16) : "-"),
                    if (!active && (p["left_reason"] as String?)?.isNotEmpty == true) row("Motivo", p["left_reason"] as String),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _phoneController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(labelText: "Telefone / WhatsApp", labelStyle: TextStyle(color: Colors.white54)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _emailController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(labelText: "E-mail", labelStyle: TextStyle(color: Colors.white54)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _savingContact ? null : _saveContact,
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
                          child: Text(_savingContact ? "..." : "Salvar"),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _recruitedByController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(labelText: "Recrutado por", labelStyle: TextStyle(color: Colors.white54)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _savingRecruited ? null : _saveRecruitedBy,
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
                          child: Text(_savingRecruited ? "..." : "Salvar"),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text("Historico completo (premios, missoes e notas)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 220,
                      child: timeline.isEmpty
                          ? const Center(child: Text("Nenhum registro ainda.", style: TextStyle(color: Colors.white54)))
                          : ListView.builder(
                              itemCount: timeline.length,
                              itemBuilder: (context, index) {
                                final t = timeline[index];
                                final color = t["type"] == "premio" ? Colors.amber : t["type"] == "missao" ? Colors.greenAccent : Colors.white70;
                                final date = DateTime.parse(t["date"] as String).toLocal().toString().substring(0, 16);
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.circle, size: 8, color: color),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(date, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                            Text(t["text"] as String, style: TextStyle(color: color, fontSize: 13)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _noteController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(labelText: "Nota geral do CRM", labelStyle: TextStyle(color: Colors.white54)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _savingNote ? null : _saveNote,
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB026FF), foregroundColor: Colors.white),
                          child: Text(_savingNote ? "..." : "Salvar"),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Fechar"))),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}




