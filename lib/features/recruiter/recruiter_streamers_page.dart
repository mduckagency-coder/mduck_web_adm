import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "recruiter_onboarding_section.dart";

(String, Color, String) computeStreamerStatus(Map<String, dynamic> s) {
  if (s["hasOnboarding"] == true) return ("Onboarding", Colors.blueAccent, "\ud83d\udfe2");
  if (s["is_active"] != true) return ("Inativo", Colors.redAccent, "\ud83d\udd34");
  final lastLive = s["last_live_at"] as String?;
  if (lastLive == null) return ("Sem lives recentes", Colors.orangeAccent, "\ud83d\udfe0");
  final days = DateTime.now().toUtc().difference(DateTime.parse(lastLive)).inDays;
  if (days <= 2) return ("Ativo", Colors.greenAccent, "\ud83d\udfe2");
  if (days <= 7) return ("Pouca atividade", Colors.amber, "\ud83d\udfe1");
  if (days <= 15) return ("Sem lives recentes", Colors.orangeAccent, "\ud83d\udfe0");
  return ("Inativo", Colors.redAccent, "\ud83d\udd34");
}

int extractDaysLive(Map<String, dynamic> s) {
  final statsData = s["streamer_stats"];
  if (statsData is List && statsData.isNotEmpty) return statsData.first["days_live"] as int? ?? 0;
  if (statsData is Map) return statsData["days_live"] as int? ?? 0;
  return 0;
}

int extractDiamonds(Map<String, dynamic> s) {
  final statsData = s["streamer_stats"];
  if (statsData is List && statsData.isNotEmpty) return statsData.first["diamonds"] as int? ?? 0;
  if (statsData is Map) return statsData["diamonds"] as int? ?? 0;
  return 0;
}

class RecruiterStreamersPage extends StatefulWidget {
  const RecruiterStreamersPage({super.key});

  @override
  State<RecruiterStreamersPage> createState() => _RecruiterStreamersPageState();
}

class _RecruiterStreamersPageState extends State<RecruiterStreamersPage> {
  late Future<Map<String, dynamic>> _future;
  String _search = "";
  String? _categoryFilter;
  String? _managerFilter;
  String? _statusFilter;
  String _periodFilter = "todos";
  bool _totalAllPeriod = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;
    final rows = await client
        .from("profiles")
        .select(
            "id, display_name, tiktok_creator_id, joined_at, is_active, last_live_at, avatar_url, phone, assigned_manager_id, streamer_categories(name), managers!profiles_assigned_manager_id_fkey(login_email), streamer_stats(days_live, diamonds)")
        .eq("recruited_by_manager_id", userId)
        .order("joined_at", ascending: false);
    final list = (rows as List).cast<Map<String, dynamic>>();

    if (list.isNotEmpty) {
      final ids = list.map((s) => s["id"] as String).toList();
      final onboardingRows = await client.from("onboarding").select("streamer_id").inFilter("streamer_id", ids);
      final onboardingSet = (onboardingRows as List).map((o) => o["streamer_id"] as String).toSet();
      for (final s in list) {
        s["hasOnboarding"] = onboardingSet.contains(s["id"]);
      }
    }

    return {"list": list};
  }

  List<Map<String, dynamic>> _filter(List<Map<String, dynamic>> all) {
    return all.where((s) {
      if (_search.isNotEmpty) {
        final name = (s["display_name"] as String).toLowerCase();
        final tiktok = (s["tiktok_creator_id"] as String? ?? "").toLowerCase();
        if (!name.contains(_search.toLowerCase()) && !tiktok.contains(_search.toLowerCase())) return false;
      }
      final catData = s["streamer_categories"];
      final catName = catData is Map ? catData["name"] as String? : null;
      if (_categoryFilter != null && catName != _categoryFilter) return false;
      final managerData = s["managers"];
      final managerEmail = managerData is Map ? managerData["login_email"] as String? : null;
      if (_managerFilter != null && managerEmail != _managerFilter) return false;
      if (_statusFilter != null && computeStreamerStatus(s).$1 != _statusFilter) return false;
      if (_periodFilter != "todos") {
        final now = DateTime.now();
        final joined = DateTime.parse(s["joined_at"]);
        if (_periodFilter == "este" && !(joined.year == now.year && joined.month == now.month)) return false;
        if (_periodFilter == "passado") {
          final lastMonth = DateTime(now.year, now.month - 1);
          if (!(joined.year == lastMonth.year && joined.month == lastMonth.month)) return false;
        }
      }
      return true;
    }).toList();
  }

  Widget _metricCard(String label, String value, Color color, String tooltip, {Widget? extra}) {
    return Tooltip(
      message: tooltip,
      textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8), border: Border.all(color: color)),
      child: Container(
        width: 185,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: color)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11))),
              const Icon(Icons.info_outline, color: Colors.white38, size: 13),
              if (extra != null) extra,
            ]),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final all = (snapshot.data!["list"] as List).cast<Map<String, dynamic>>();
        final filtered = _filter(all);
        final now = DateTime.now();

        final totalTodoPeriodo = all.length;
        final totalMes = all.where((s) {
          final j = DateTime.parse(s["joined_at"]);
          return j.year == now.year && j.month == now.month;
        }).length;
        final totalExibido = _totalAllPeriod ? totalTodoPeriodo : totalMes;

        final ativos90 = all.where((s) {
          final j = DateTime.parse(s["joined_at"]);
          final daysSinceJoin = now.difference(j).inDays;
          return daysSinceJoin <= 90 && extractDaysLive(s) >= 14;
        }).length;

        final onboarding15 = all.where((s) {
          final j = DateTime.parse(s["joined_at"]);
          return now.difference(j).inDays <= 15;
        }).length;

        final inativos7 = all.where((s) {
          final lastLive = s["last_live_at"] as String?;
          if (lastLive == null) return true;
          final days = now.toUtc().difference(DateTime.parse(lastLive)).inDays;
          return days > 7;
        }).length;

        final saida30 = all.where((s) {
          final j = DateTime.parse(s["joined_at"]);
          final daysSinceJoin = now.difference(j).inDays;
          return s["is_active"] != true && daysSinceJoin <= 30;
        }).length;

        final taxaPermanencia = totalTodoPeriodo == 0 ? 0.0 : (all.where((s) => s["is_active"] == true).length / totalTodoPeriodo) * 100;

        final ultimos90 = all.where((s) => now.difference(DateTime.parse(s["joined_at"])).inDays <= 90).toList();
        final graduados = ultimos90.where((s) => extractDiamonds(s) >= 80000).length;
        final taxaGraduacao = ultimos90.isEmpty ? 0.0 : (graduados / ultimos90.length) * 100;

        final categories = all.map((s) => s["streamer_categories"]).whereType<Map>().map((c) => c["name"] as String).toSet().toList()..sort();
        final managerEmails = all.map((s) => s["managers"]).whereType<Map>().map((m) => m["login_email"] as String).toSet().toList()..sort();

        return Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Text("Streamers Agenciados", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(width: 12),
                  IconButton(icon: const Icon(Icons.refresh, color: Colors.white70), onPressed: () => setState(() => _future = _load())),
                ]),
                const SizedBox(height: 16),
                Wrap(spacing: 12, runSpacing: 12, children: [
                  _metricCard(
                    "Total Agenciados (" + (_totalAllPeriod ? "todo periodo" : "este mes") + ")",
                    totalExibido.toString(),
                    const Color(0xFF7A0BD4),
                    "Quantidade de streamers que voce agenciou. Toque no icone de relogio para trocar entre este mes e todo o periodo.",
                    extra: IconButton(
                      icon: Icon(_totalAllPeriod ? Icons.calendar_month : Icons.calendar_today, size: 14, color: Colors.white54),
                      onPressed: () => setState(() => _totalAllPeriod = !_totalAllPeriod),
                      tooltip: "Trocar periodo",
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
                  _metricCard("Ativos", ativos90.toString(), Colors.greenAccent,
                      "Streamers agenciados nos ultimos 90 dias que tem no minimo 14 dias validos de live neste mes."),
                  _metricCard("Em Onboarding", onboarding15.toString(), Colors.blueAccent,
                      "Streamers que entraram na agencia ha 15 dias ou menos."),
                  _metricCard("Inativos", inativos7.toString(), Colors.redAccent,
                      "Streamers que nao fizeram nenhuma live nos ultimos 7 dias."),
                  _metricCard("Saida", saida30.toString(), Colors.orangeAccent,
                      "Streamers marcados como inativos que foram agenciados nos ultimos 30 dias (saida precoce)."),
                  _metricCard("Taxa de Permanencia", taxaPermanencia.toStringAsFixed(0) + "%", Colors.tealAccent,
                      "Percentual de todos os seus agenciados (em qualquer periodo) que continuam ativos hoje."),
                  _metricCard("Graduacao", taxaGraduacao.toStringAsFixed(0) + "%", Colors.amber,
                      "Entre os agenciados nos ultimos 90 dias, percentual que alcancou 80 mil diamantes ou mais em algum mes."),
                ]),
                const SizedBox(height: 20),
                const RecruiterOnboardingSection(),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 200,
                      child: TextField(
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(prefixIcon: Icon(Icons.search, color: Colors.white54), hintText: "Buscar nome ou @TikTok", hintStyle: TextStyle(color: Colors.white38), isDense: true),
                        onChanged: (v) => setState(() => _search = v),
                      ),
                    ),
                    DropdownButton<String?>(
                      value: _categoryFilter,
                      hint: const Text("Categoria", style: TextStyle(color: Colors.white54)),
                      dropdownColor: const Color(0xFF1A1A1A),
                      style: const TextStyle(color: Colors.white),
                      items: [const DropdownMenuItem<String?>(value: null, child: Text("Todas categorias")), ...categories.map((c) => DropdownMenuItem<String?>(value: c, child: Text(c)))],
                      onChanged: (v) => setState(() => _categoryFilter = v),
                    ),
                    DropdownButton<String?>(
                      value: _managerFilter,
                      hint: const Text("Gestor atual", style: TextStyle(color: Colors.white54)),
                      dropdownColor: const Color(0xFF1A1A1A),
                      style: const TextStyle(color: Colors.white),
                      items: [const DropdownMenuItem<String?>(value: null, child: Text("Todos os gestores")), ...managerEmails.map((m) => DropdownMenuItem<String?>(value: m, child: Text(m)))],
                      onChanged: (v) => setState(() => _managerFilter = v),
                    ),
                    DropdownButton<String?>(
                      value: _statusFilter,
                      hint: const Text("Status", style: TextStyle(color: Colors.white54)),
                      dropdownColor: const Color(0xFF1A1A1A),
                      style: const TextStyle(color: Colors.white),
                      items: const [
                        DropdownMenuItem<String?>(value: null, child: Text("Todos status")),
                        DropdownMenuItem<String?>(value: "Onboarding", child: Text("Onboarding")),
                        DropdownMenuItem<String?>(value: "Ativo", child: Text("Ativo")),
                        DropdownMenuItem<String?>(value: "Pouca atividade", child: Text("Pouca atividade")),
                        DropdownMenuItem<String?>(value: "Sem lives recentes", child: Text("Sem lives recentes")),
                        DropdownMenuItem<String?>(value: "Inativo", child: Text("Inativo")),
                      ],
                      onChanged: (v) => setState(() => _statusFilter = v),
                    ),
                    Wrap(
                      spacing: 6,
                      children: [
                        ("todos", "Todos periodos"),
                        ("este", "Este mes"),
                        ("passado", "Mes passado"),
                      ].map((p) {
                        final selected = _periodFilter == p.$1;
                        return ChoiceChip(
                          label: Text(p.$2, style: const TextStyle(fontSize: 12)),
                          selected: selected,
                          selectedColor: const Color(0xFF7A0BD4),
                          labelStyle: TextStyle(color: selected ? Colors.white : Colors.white70),
                          onSelected: (_) => setState(() => _periodFilter = p.$1),
                        );
                      }).toList(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(filtered.length.toString() + " streamers", style: const TextStyle(color: Colors.white54)),
                const SizedBox(height: 8),
                filtered.isEmpty
                    ? const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: Text("Nenhum streamer encontrado.", style: TextStyle(color: Colors.white54))))
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final s = filtered[index];
                          final status = computeStreamerStatus(s);
                          final catData = s["streamer_categories"];
                          final managerData = s["managers"];
                          final joined = DateTime.parse(s["joined_at"] as String);
                          final daysSince = DateTime.now().difference(joined).inDays;

                          return Card(
                            color: Colors.white.withOpacity(0.05),
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              onTap: () => showDialog(context: context, builder: (context) => StreamerFichaDialog(streamer: s)),
                              leading: CircleAvatar(
                                radius: 18,
                                backgroundColor: Colors.white24,
                                backgroundImage: s["avatar_url"] != null ? NetworkImage(s["avatar_url"] as String) : null,
                                child: s["avatar_url"] == null ? const Icon(Icons.person, color: Colors.white54, size: 18) : null,
                              ),
                              title: Text(s["display_name"] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                (s["tiktok_creator_id"] ?? "-") +
                                    "  -  " +
                                    (catData is Map ? catData["name"] as String? ?? "-" : "-") +
                                    "  -  Ha " +
                                    daysSince.toString() +
                                    " dias  -  Gestor: " +
                                    (managerData is Map ? managerData["login_email"] as String? ?? "Nao atribuido" : "Nao atribuido"),
                                style: const TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(border: Border.all(color: status.$2), borderRadius: BorderRadius.circular(8)),
                                    child: Text(status.$3 + " " + status.$1, style: TextStyle(color: status.$2, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                  if (s["assigned_manager_id"] == null) ...[
                                    const SizedBox(height: 4),
                                    ElevatedButton(
                                      onPressed: () {
                                        showDialog(context: context, builder: (context) => TransferDialog(streamerId: s["id"] as String, streamerName: s["display_name"] as String)).then((done) {
                                          if (done == true) setState(() => _future = _load());
                                        });
                                      },
                                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10)),
                                      child: const Text("Transferir", style: TextStyle(fontSize: 11)),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class StreamerFichaDialog extends StatefulWidget {
  final Map<String, dynamic> streamer;
  const StreamerFichaDialog({super.key, required this.streamer});

  @override
  State<StreamerFichaDialog> createState() => _StreamerFichaDialogState();
}

class _StreamerFichaDialogState extends State<StreamerFichaDialog> {
  late Future<Map<String, dynamic>> _future;
  final _obsController = TextEditingController();
  bool _savingObs = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final client = Supabase.instance.client;
    final streamerId = widget.streamer["id"] as String;

    final assignmentHistory = await client
        .from("manager_assignment_history")
        .select("manager_id, assigned_at, managers(login_email)")
        .eq("streamer_id", streamerId)
        .order("assigned_at");

    final materials = await client.from("streamer_materials_sent").select("material_name, sent, created_at, managers(login_email)").eq("streamer_id", streamerId);

    final group = await client.from("streamer_individual_groups").select().eq("streamer_id", streamerId).maybeSingle();

    final notes = await client.from("delivery_notes").select("note, created_at, managers(login_email)").eq("streamer_id", streamerId).order("created_at", ascending: false);

    final lead = await client.from("leads").select("id, created_at, status").eq("converted_streamer_id", streamerId).maybeSingle();
    List<Map<String, dynamic>> leadEvents = [];
    if (lead != null) {
      final leadHist = await client.from("lead_history").select().eq("lead_id", lead["id"]).order("created_at");
      leadEvents = (leadHist as List).cast<Map<String, dynamic>>();
    }

    final transfers = await client.from("streamer_transfers").select("transferred_at, managers!streamer_transfers_manager_id_fkey(login_email)").eq("streamer_id", streamerId);

    final timeline = <Map<String, dynamic>>[];
    for (final e in leadEvents) {
      timeline.add({"date": e["created_at"], "label": e["action"] + (e["detail"] != null ? ": " + e["detail"] : "")});
    }
    for (final t in (transfers as List)) {
      final m = t["managers"];
      timeline.add({"date": t["transferred_at"], "label": "Transferido para " + (m is Map ? m["login_email"] as String? ?? "gestor" : "gestor")});
    }
    for (final mat in (materials as List)) {
      if (mat["sent"] == true) timeline.add({"date": mat["created_at"], "label": "Material enviado: " + (mat["material_name"] as String)});
    }
    if (group != null && group["group_created"] == true) {
      timeline.add({"date": group["created_at"], "label": "Grupo individual criado: " + ((group["group_name"] as String?) ?? "")});
    }
    timeline.sort((a, b) => (a["date"] as String).compareTo(b["date"] as String));

    return {
      "assignmentHistory": (assignmentHistory as List).cast<Map<String, dynamic>>(),
      "materials": (materials).cast<Map<String, dynamic>>(),
      "group": group,
      "notes": (notes as List).cast<Map<String, dynamic>>(),
      "timeline": timeline,
    };
  }

  Future<void> _saveObservation() async {
    if (_obsController.text.trim().isEmpty) return;
    setState(() => _savingObs = true);
    final client = Supabase.instance.client;
    await client.from("delivery_notes").insert({
      "streamer_id": widget.streamer["id"],
      "note": _obsController.text.trim(),
      "created_by": client.auth.currentUser!.id,
    });
    _obsController.clear();
    setState(() {
      _savingObs = false;
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.streamer;
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 820),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: FutureBuilder<Map<String, dynamic>>(
            future: _future,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox(height: 300, child: Center(child: CircularProgressIndicator()));
              final assignmentHistory = snapshot.data!["assignmentHistory"] as List<Map<String, dynamic>>;
              final materials = snapshot.data!["materials"] as List<Map<String, dynamic>>;
              final group = snapshot.data!["group"] as Map<String, dynamic>?;
              final notes = snapshot.data!["notes"] as List<Map<String, dynamic>>;
              final timeline = snapshot.data!["timeline"] as List<Map<String, dynamic>>;
              final catData = s["streamer_categories"];
              final managerData = s["managers"];

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.white24,
                        backgroundImage: s["avatar_url"] != null ? NetworkImage(s["avatar_url"] as String) : null,
                        child: s["avatar_url"] == null ? const Icon(Icons.person, color: Colors.white, size: 20) : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(s["display_name"] as String, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
                    ]),
                    const SizedBox(height: 12),
                    Text("@" + (s["tiktok_creator_id"] ?? "-"), style: const TextStyle(color: Colors.white70)),
                    Text("Categoria: " + (catData is Map ? catData["name"] as String? ?? "-" : "-"), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    Text("WhatsApp: " + ((s["phone"] as String?)?.isNotEmpty == true ? s["phone"] as String : "-"), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    Text("Agenciado em: " + DateTime.parse(s["joined_at"] as String).toLocal().toString().substring(0, 10), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    Text("Gestor atual: " + (managerData is Map ? managerData["login_email"] as String? ?? "Nao atribuido" : "Nao atribuido"), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 16),
                    const Text("Historico de responsaveis", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    if (assignmentHistory.isEmpty)
                      const Text("Ainda nao transferido para nenhum gestor.", style: TextStyle(color: Colors.white38, fontSize: 12))
                    else
                      ...assignmentHistory.map((a) {
                        final m = a["managers"];
                        final date = DateTime.parse(a["assigned_at"] as String).toLocal().toString().substring(0, 16);
                        return Text("- " + date + ": vinculado a " + (m is Map ? m["login_email"] as String? ?? "-" : "-"), style: const TextStyle(color: Colors.white70, fontSize: 12));
                      }),
                    const SizedBox(height: 16),
                    const Text("Materiais enviados", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    if (materials.isEmpty)
                      const Text("Nenhum material registrado.", style: TextStyle(color: Colors.white38, fontSize: 12))
                    else
                      ...materials.map((m) {
                        final sentBy = m["managers"];
                        final date = DateTime.parse(m["created_at"] as String).toLocal().toString().substring(0, 10);
                        return Text(
                          (m["sent"] == true ? "\u2611 " : "\u2610 ") + (m["material_name"] as String) + " - " + date + (sentBy is Map ? " por " + (sentBy["login_email"] as String? ?? "") : ""),
                          style: TextStyle(color: m["sent"] == true ? Colors.greenAccent : Colors.white38, fontSize: 12),
                        );
                      }),
                    const SizedBox(height: 16),
                    const Text("Grupo individual", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    if (group == null || group["group_created"] != true)
                      const Text("Pendente - grupo ainda nao criado.", style: TextStyle(color: Colors.orangeAccent, fontSize: 12))
                    else
                      Text("Criado: " + ((group["group_name"] as String?) ?? "-") + (((group["group_link"] as String?)?.isNotEmpty == true) ? " (" + group["group_link"] + ")" : ""),
                          style: const TextStyle(color: Colors.greenAccent, fontSize: 12)),
                    const SizedBox(height: 16),
                    const Text("Observacoes do recrutador", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    if (notes.isEmpty)
                      const Text("Nenhuma observacao ainda.", style: TextStyle(color: Colors.white38, fontSize: 12))
                    else
                      ...notes.map((n) {
                        final date = DateTime.parse(n["created_at"] as String).toLocal().toString().substring(0, 16);
                        return Padding(padding: const EdgeInsets.only(bottom: 4), child: Text("- (" + date + ") " + (n["note"] as String), style: const TextStyle(color: Colors.white70, fontSize: 12)));
                      }),
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
                        child: Text(_savingObs ? "..." : "Salvar"),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    const Text("Linha do tempo", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    if (timeline.isEmpty)
                      const Text("Sem eventos registrados.", style: TextStyle(color: Colors.white38, fontSize: 12))
                    else
                      ...timeline.map((t) {
                        final date = DateTime.parse(t["date"] as String).toLocal().toString().substring(0, 16);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Icon(Icons.circle, size: 6, color: Color(0xFF7A0BD4)),
                            const SizedBox(width: 8),
                            Expanded(child: Text(date + " - " + (t["label"] as String), style: const TextStyle(color: Colors.white70, fontSize: 12))),
                          ]),
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

class TransferDialog extends StatefulWidget {
  final String streamerId;
  final String streamerName;
  const TransferDialog({super.key, required this.streamerId, required this.streamerName});

  @override
  State<TransferDialog> createState() => _TransferDialogState();
}

class _TransferDialogState extends State<TransferDialog> {
  List<Map<String, dynamic>> _managers = [];
  List<Map<String, dynamic>> _materials = [];
  final Map<String, bool> _materialsSent = {};
  final _customMaterialController = TextEditingController();
  String? _selectedManagerId;
  bool _chkGestor = false;
  bool _chkObservacoes = false;
  bool _chkInformacoes = false;
  bool _groupCreated = false;
  final _groupNameController = TextEditingController();
  final _groupLinkController = TextEditingController();
  final _deliveryNotesController = TextEditingController();
  bool _saving = false;
  late Future<List<Map<String, dynamic>>> _observationsFuture;

  @override
  void initState() {
    super.initState();
    _loadManagers();
    _loadMaterials();
    _observationsFuture = _loadObservations();
  }

  Future<void> _loadManagers() async {
    final client = Supabase.instance.client;
    final rows = await client.from("managers").select("id, login_email").eq("role", "gestor");
    setState(() => _managers = (rows as List).cast<Map<String, dynamic>>());
  }

  Future<void> _loadMaterials() async {
    final client = Supabase.instance.client;
    final rows = await client.from("onboarding_materials_catalog").select().eq("is_active", true).order("name");
    setState(() {
      _materials = (rows as List).cast<Map<String, dynamic>>();
      for (final m in _materials) {
        _materialsSent[m["name"] as String] = false;
      }
    });
  }

  Future<List<Map<String, dynamic>>> _loadObservations() async {
    final client = Supabase.instance.client;
    final lead = await client.from("leads").select("id").eq("converted_streamer_id", widget.streamerId).maybeSingle();
    if (lead == null) return [];
    final rows = await client.from("lead_history").select().eq("lead_id", lead["id"]).eq("action", "observacao").order("created_at", ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  void _addCustomMaterial() {
    final name = _customMaterialController.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _materials.add({"name": name, "is_custom": true});
      _materialsSent[name] = false;
      _customMaterialController.clear();
    });
  }

  bool get _canConfirm => _chkGestor && _chkObservacoes && _chkInformacoes && _selectedManagerId != null;

  Future<void> _confirm() async {
    if (!_canConfirm) return;
    setState(() => _saving = true);
    final client = Supabase.instance.client;
    final recruiterId = client.auth.currentUser!.id;

    await client.from("profiles").update({"assigned_manager_id": _selectedManagerId}).eq("id", widget.streamerId);

    await client.from("streamer_transfers").insert({
      "streamer_id": widget.streamerId,
      "recruiter_id": recruiterId,
      "manager_id": _selectedManagerId,
      "checklist_gestor_selecionado": _chkGestor,
      "checklist_observacoes": _chkObservacoes,
      "checklist_informacoes": _chkInformacoes,
    });

    await client.from("onboarding").insert({
      "streamer_id": widget.streamerId,
      "assigned_manager_id": _selectedManagerId,
      "current_phase": "fase_1_dia_0",
    });

    await client.from("manager_notifications").insert({
      "manager_id": _selectedManagerId,
      "message": "Voce recebeu um novo streamer para iniciar o onboarding: " + widget.streamerName,
      "streamer_id": widget.streamerId,
    });

    for (final entry in _materialsSent.entries) {
      final materialData = _materials.firstWhere((m) => m["name"] == entry.key, orElse: () => {"is_custom": false});
      await client.from("streamer_materials_sent").insert({
        "streamer_id": widget.streamerId,
        "material_name": entry.key,
        "sent": entry.value,
        "is_custom": materialData["is_custom"] ?? false,
        "sent_by": recruiterId,
      });
    }

    if (_groupCreated || _groupNameController.text.trim().isNotEmpty) {
      await client.from("streamer_individual_groups").insert({
        "streamer_id": widget.streamerId,
        "group_created": _groupCreated,
        "group_name": _groupNameController.text.trim(),
        "group_link": _groupLinkController.text.trim(),
        "participants": ["Streamer", "Recrutador", "Gestor"],
      });
    }

    if (_deliveryNotesController.text.trim().isNotEmpty) {
      await client.from("delivery_notes").insert({
        "streamer_id": widget.streamerId,
        "note": _deliveryNotesController.text.trim(),
        "created_by": recruiterId,
      });
    }

    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 780),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Transferir " + widget.streamerName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                const Text("Gestor responsavel", style: TextStyle(color: Colors.white54)),
                const SizedBox(height: 6),
                DropdownButton<String>(
                  value: _selectedManagerId,
                  hint: const Text("Escolha o gestor", style: TextStyle(color: Colors.white54)),
                  dropdownColor: const Color(0xFF1A1A1A),
                  style: const TextStyle(color: Colors.white),
                  items: _managers.map((m) => DropdownMenuItem(value: m["id"] as String, child: Text(m["login_email"] as String))).toList(),
                  onChanged: (v) => setState(() {
                    _selectedManagerId = v;
                    _chkGestor = v != null;
                  }),
                ),
                const SizedBox(height: 16),
                const Text("Materiais enviados", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ..._materials.map((m) {
                  final name = m["name"] as String;
                  return CheckboxListTile(
                    value: _materialsSent[name] ?? false,
                    onChanged: (v) => setState(() => _materialsSent[name] = v ?? false),
                    title: Text(name, style: const TextStyle(color: Colors.white, fontSize: 13)),
                    activeColor: const Color(0xFF7A0BD4),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  );
                }),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _customMaterialController,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: const InputDecoration(labelText: "Outro material", labelStyle: TextStyle(color: Colors.white54, fontSize: 12)),
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.add, color: Color(0xFF7A0BD4)), onPressed: _addCustomMaterial),
                  ],
                ),
                const SizedBox(height: 16),
                const Text("Grupo individual", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                CheckboxListTile(
                  value: _groupCreated,
                  onChanged: (v) => setState(() => _groupCreated = v ?? false),
                  title: const Text("Grupo criado", style: TextStyle(color: Colors.white, fontSize: 13)),
                  activeColor: const Color(0xFF7A0BD4),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
                TextField(controller: _groupNameController, style: const TextStyle(color: Colors.white, fontSize: 13), decoration: const InputDecoration(labelText: "Nome do grupo", labelStyle: TextStyle(color: Colors.white54, fontSize: 12))),
                const SizedBox(height: 6),
                TextField(controller: _groupLinkController, style: const TextStyle(color: Colors.white, fontSize: 13), decoration: const InputDecoration(labelText: "Link do grupo (opcional)", labelStyle: TextStyle(color: Colors.white54, fontSize: 12))),
                const SizedBox(height: 16),
                const Text("Observacoes da entrega", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: _deliveryNotesController,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(hintText: "Ex: ja fazia lives, disponivel a noite...", hintStyle: TextStyle(color: Colors.white24, fontSize: 12), border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                const Text("Observacoes ja registradas (do lead)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                SizedBox(
                  height: 80,
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _observationsFuture,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      if (snapshot.data!.isEmpty) return const Text("Nenhuma observacao registrada.", style: TextStyle(color: Colors.white38, fontSize: 12));
                      return ListView(
                        children: snapshot.data!.map((o) => Text("- " + (o["detail"] as String? ?? ""), style: const TextStyle(color: Colors.white70, fontSize: 12))).toList(),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                const Text("Checklist de entrega", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                CheckboxListTile(
                  value: _chkGestor,
                  onChanged: (v) => setState(() => _chkGestor = v ?? false),
                  title: const Text("Gestor selecionado", style: TextStyle(color: Colors.white, fontSize: 13)),
                  activeColor: const Color(0xFF7A0BD4),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
                CheckboxListTile(
                  value: _chkObservacoes,
                  onChanged: (v) => setState(() => _chkObservacoes = v ?? false),
                  title: const Text("Observacoes preenchidas", style: TextStyle(color: Colors.white, fontSize: 13)),
                  activeColor: const Color(0xFF7A0BD4),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
                CheckboxListTile(
                  value: _chkInformacoes,
                  onChanged: (v) => setState(() => _chkInformacoes = v ?? false),
                  title: const Text("Informacoes conferidas", style: TextStyle(color: Colors.white, fontSize: 13)),
                  activeColor: const Color(0xFF7A0BD4),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancelar")),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: (_canConfirm && !_saving) ? _confirm : null,
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
                      child: Text(_saving ? "Transferindo..." : "Concluir transferencia"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
