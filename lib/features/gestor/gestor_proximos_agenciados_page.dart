import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "../recruiter/recruiter_onboarding_central_page.dart" show onboardingSteps;

(String, Color) _deriveStatus(Map<String, dynamic> checklist, bool linked) {
  if (checklist["entrou_agencia"] == true) {
    return linked ? ("Em onboarding", Colors.greenAccent) : ("Aguardando entrada", Colors.orangeAccent);
  }
  if (checklist["convite_aceito"] == true) return ("Convite aceito", Colors.amber);
  return ("Convite enviado", Colors.white54);
}

class GestorProximosAgenciadosPage extends StatefulWidget {
  const GestorProximosAgenciadosPage({super.key});

  @override
  State<GestorProximosAgenciadosPage> createState() => _GestorProximosAgenciadosPageState();
}

class _GestorProximosAgenciadosPageState extends State<GestorProximosAgenciadosPage> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;

    final gestorRows = await client.from("lead_onboarding_gestores").select("lead_id").eq("manager_id", userId);
    final leadIds = (gestorRows as List).map((g) => g["lead_id"] as String).toList();
    if (leadIds.isEmpty) return [];

    final leads = await client
        .from("leads")
        .select("id, name, tiktok_username, phone, category_interest, recruiter_id, converted_streamer_id")
        .inFilter("id", leadIds);
    final leadsList = (leads as List).cast<Map<String, dynamic>>();

    final recruiterIds = leadsList.map((l) => l["recruiter_id"] as String).toSet().toList();
    final recruiters = recruiterIds.isEmpty ? [] : await client.from("managers").select("id, login_email").inFilter("id", recruiterIds);
    final recruiterMap = {for (final r in recruiters) r["id"] as String: r["login_email"] as String};

    final result = <Map<String, dynamic>>[];
    for (final l in leadsList) {
      var checklist = await client.from("lead_onboarding_checklist").select().eq("lead_id", l["id"]).maybeSingle();
      checklist ??= {};
      if (checklist["concluido"] == true) continue;

      String? avatarUrl;
      if (l["converted_streamer_id"] != null) {
        final profile = await client.from("profiles").select("avatar_url").eq("id", l["converted_streamer_id"]).maybeSingle();
        avatarUrl = profile?["avatar_url"] as String?;
      }

      result.add({
        "leadId": l["id"],
        "name": l["name"],
        "tiktok_username": l["tiktok_username"],
        "category_interest": l["category_interest"],
        "recruiterEmail": recruiterMap[l["recruiter_id"]] ?? "-",
        "avatarUrl": avatarUrl,
        "status": _deriveStatus(checklist, l["converted_streamer_id"] != null),
        "lastUpdate": checklist["updated_at"] as String?,
      });
    }
    return result;
  }

  void _openDetail(Map<String, dynamic> item) {
    showDialog(context: context, builder: (context) => _ProximoAgenciadoDetailDialog(leadId: item["leadId"] as String, leadName: item["name"] as String));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text("Proximos Agenciados", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(width: 12),
            IconButton(icon: const Icon(Icons.refresh, color: Colors.white70), onPressed: () => setState(() => _future = _load())),
          ]),
          const SizedBox(height: 4),
          const Text("Streamers que ja tem voce como gestor, mas ainda estao concluindo a entrada na agencia.", style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic)),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final list = snapshot.data!;
                if (list.isEmpty) return const Center(child: Text("Nenhum streamer a caminho no momento.", style: TextStyle(color: Colors.white54)));
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final item = list[index];
                    final status = item["status"] as (String, Color);
                    final tiktok = item["tiktok_username"] as String?;
                    final category = item["category_interest"] as String?;
                    final lastUpdate = item["lastUpdate"] as String?;
                    return Card(
                      color: status.$2.withOpacity(0.1),
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: status.$2.withOpacity(0.6))),
                      child: ListTile(
                        onTap: () => _openDetail(item),
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white24,
                          backgroundImage: item["avatarUrl"] != null ? NetworkImage(item["avatarUrl"] as String) : null,
                          child: item["avatarUrl"] == null ? const Icon(Icons.person, color: Colors.white54, size: 18) : null,
                        ),
                        title: Text(item["name"] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (tiktok != null && tiktok.isNotEmpty ? "@" + tiktok + "  -  " : "") +
                                  (category != null && category.isNotEmpty ? category + "  -  " : "") +
                                  "Recrutador: " + (item["recruiterEmail"] as String),
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                            if (lastUpdate != null)
                              Text(
                                "Ultima atualizacao pelo recrutador: " + DateTime.parse(lastUpdate).toLocal().toString().substring(0, 16),
                                style: const TextStyle(color: Colors.white38, fontSize: 11),
                              ),
                          ],
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(border: Border.all(color: status.$2), borderRadius: BorderRadius.circular(8)),
                          child: Text(status.$1, style: TextStyle(color: status.$2, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProximoAgenciadoDetailDialog extends StatefulWidget {
  final String leadId;
  final String leadName;
  const _ProximoAgenciadoDetailDialog({required this.leadId, required this.leadName});

  @override
  State<_ProximoAgenciadoDetailDialog> createState() => _ProximoAgenciadoDetailDialogState();
}

class _ProximoAgenciadoDetailDialogState extends State<_ProximoAgenciadoDetailDialog> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final client = Supabase.instance.client;

    final lead = await client
        .from("leads")
        .select("name, tiktok_username, phone, category_interest, origin, created_at, recruiter_id, converted_streamer_id")
        .eq("id", widget.leadId)
        .single();

    final recruiter = await client.from("managers").select("login_email").eq("id", lead["recruiter_id"]).maybeSingle();

    var checklist = await client.from("lead_onboarding_checklist").select().eq("lead_id", widget.leadId).maybeSingle();
    checklist ??= {};

    final handoff = await client.from("lead_recruitment_handoff").select().eq("lead_id", widget.leadId).maybeSingle();

    final history = await client
        .from("lead_history")
        .select()
        .eq("lead_id", widget.leadId)
        .order("created_at", ascending: false);

    return {
      "lead": lead,
      "recruiterEmail": recruiter?["login_email"] as String?,
      "checklist": checklist,
      "handoff": handoff,
      "history": (history as List).cast<Map<String, dynamic>>(),
    };
  }

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(width: 150, child: Text(label, style: const TextStyle(color: Colors.white54))),
            Expanded(child: Text(value, style: const TextStyle(color: Colors.white))),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: FutureBuilder<Map<String, dynamic>>(
            future: _future,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox(height: 300, child: Center(child: CircularProgressIndicator()));
              final data = snapshot.data!;
              final lead = data["lead"] as Map<String, dynamic>;
              final checklist = data["checklist"] as Map<String, dynamic>;
              final handoff = data["handoff"] as Map<String, dynamic>?;
              final history = data["history"] as List<Map<String, dynamic>>;
              final recruiterEmail = data["recruiterEmail"] as String?;
              final lastUpdate = checklist["updated_at"] as String?;

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lead["name"] as String, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    if ((lead["tiktok_username"] as String?)?.isNotEmpty == true) _infoRow("@TikTok", lead["tiktok_username"] as String),
                    if ((lead["phone"] as String?)?.isNotEmpty == true) _infoRow("WhatsApp", lead["phone"] as String),
                    if ((lead["category_interest"] as String?)?.isNotEmpty == true) _infoRow("Categoria", lead["category_interest"] as String),
                    _infoRow("Recrutador responsavel", recruiterEmail ?? "-"),
                    _infoRow("Lead criado em", DateTime.parse(lead["created_at"] as String).toLocal().toString().substring(0, 16)),
                    _infoRow("Ultima atualizacao pelo recrutador", lastUpdate != null ? DateTime.parse(lastUpdate).toLocal().toString().substring(0, 16) : "-"),
                    if (handoff != null) ...[
                      const SizedBox(height: 16),
                      const Text("Informacoes do streamer (transferencia)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      if ((handoff["niche"] as String?)?.isNotEmpty == true) _infoRow("Nicho", handoff["niche"] as String),
                      if ((handoff["available_days"] as String?)?.isNotEmpty == true) _infoRow("Dias disponiveis", handoff["available_days"] as String),
                      if ((handoff["available_hours"] as String?)?.isNotEmpty == true) _infoRow("Horarios disponiveis", handoff["available_hours"] as String),
                      if ((handoff["previous_experience"] as String?)?.isNotEmpty == true) _infoRow("Experiencia anterior", handoff["previous_experience"] as String),
                      if ((handoff["objectives"] as String?)?.isNotEmpty == true) _infoRow("Objetivos", handoff["objectives"] as String),
                      if ((handoff["attention_points"] as String?)?.isNotEmpty == true) _infoRow("Pontos de atencao", handoff["attention_points"] as String),
                      if ((handoff["recruitment_summary"] as String?)?.isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        const Text("Resumo do recrutamento", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                        Text(handoff["recruitment_summary"] as String, style: const TextStyle(color: Colors.white, fontSize: 13)),
                      ],
                      if ((handoff["notes"] as String?)?.isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        const Text("Observacoes para o gestor", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                        Text(handoff["notes"] as String, style: const TextStyle(color: Colors.white, fontSize: 13)),
                      ],
                    ],
                    const SizedBox(height: 16),
                    const Text("Andamento do recrutador", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...onboardingSteps.where((s) => s.$1 != "gestor").map((s) {
                      final done = checklist[s.$1] == true;
                      final at = checklist[s.$1 + "_at"];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(children: [
                          Icon(done ? Icons.check_circle : Icons.radio_button_unchecked, color: done ? Colors.greenAccent : Colors.white24, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text(s.$2, style: TextStyle(color: done ? Colors.white : Colors.white54, fontSize: 13))),
                          if (done && at != null) Text(DateTime.parse(at as String).toLocal().toString().substring(0, 16), style: const TextStyle(color: Colors.white38, fontSize: 11)),
                        ]),
                      );
                    }),
                    const SizedBox(height: 16),
                    const Text("Historico", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    if (history.isEmpty)
                      const Text("Sem registros ainda.", style: TextStyle(color: Colors.white38, fontSize: 12))
                    else
                      ...history.map((h) {
                        final date = DateTime.parse(h["created_at"] as String).toLocal().toString().substring(0, 16);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Text("- (" + date + ") " + (h["detail"] as String? ?? (h["action"] as String)), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        );
                      }),
                    const SizedBox(height: 16),
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
