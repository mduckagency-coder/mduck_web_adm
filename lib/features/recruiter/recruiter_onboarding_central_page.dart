import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "lead_handoff_dialog.dart";
import "../gestor/onboarding_phase_service.dart";

const onboardingSteps = [
  ("convite_enviado", "Convite enviado", Icons.send),
  ("convite_aceito", "Convite aceito", Icons.check_circle_outline),
  ("entrou_agencia", "Entrou para Agencia", Icons.login),
  ("gestor", "Selecionar Gestor", Icons.supervisor_account),
  ("grupo_individual_criado", "Grupo Individual", Icons.group),
  ("material_boas_vindas", "Materiais de Boas-vindas", Icons.card_giftcard),
  ("apresentacao_gestores", "Apresentacao dos Gestores", Icons.groups),
  ("concluido", "Onboarding Concluido", Icons.flag),
];

class RecruiterOnboardingCentralPage extends StatefulWidget {
  const RecruiterOnboardingCentralPage({super.key});

  @override
  State<RecruiterOnboardingCentralPage> createState() => _RecruiterOnboardingCentralPageState();
}

class _RecruiterOnboardingCentralPageState extends State<RecruiterOnboardingCentralPage> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  int _saidaOficialMes = 0;

  String _search = "";
  String? _gestorFilter;
  String? _categoriaFilter;
  String? _statusFilter;
  String _periodFilter = "todos";
  DateTime? _customStart;
  DateTime? _customEnd;
  String? _metricFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser!.id;

      final leads = await client
          .from("leads")
          .select("id, name, tiktok_username, category_interest, converted_at, converted_streamer_id, phone")
          .eq("recruiter_id", userId)
          .eq("status", "agenciado")
          .order("converted_at", ascending: false);
      final leadsList = (leads as List).cast<Map<String, dynamic>>();

      for (final l in leadsList) {
        var checklist = await client.from("lead_onboarding_checklist").select().eq("lead_id", l["id"]).maybeSingle();
        checklist ??= await client.from("lead_onboarding_checklist").insert({"lead_id": l["id"]}).select().single();
        l["checklist"] = checklist;

        final gestores = await client.from("lead_onboarding_gestores").select("manager_id, managers(login_email, photo_url)").eq("lead_id", l["id"]);
        l["gestores"] = (gestores as List).cast<Map<String, dynamic>>();

        if (l["converted_streamer_id"] != null) {
          final profile = await client
              .from("profiles")
              .select("display_name, avatar_url, tiktok_creator_id, is_active, last_live_at, joined_at, streamer_categories(name), streamer_stats(diamonds)")
              .eq("id", l["converted_streamer_id"])
              .maybeSingle();
          l["linkedProfile"] = profile;
        }
      }

      final now = DateTime.now();
      final saidaRows = await client
          .from("profiles")
          .select("id, joined_at, is_active")
          .eq("recruited_by_manager_id", userId)
          .eq("is_active", false);
      final saidaList = (saidaRows as List).cast<Map<String, dynamic>>();
      final saidaMes = saidaList.where((p) {
        final joined = DateTime.parse(p["joined_at"]);
        return joined.year == now.year && joined.month == now.month;
      }).length;

      setState(() {
        _items = leadsList;
        _saidaOficialMes = saidaMes;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  int _stepsDone(Map<String, dynamic> checklist, List<Map<String, dynamic>> gestores) {
    var count = 0;
    for (final s in onboardingSteps) {
      if (s.$1 == "gestor") {
        if (gestores.isNotEmpty) count++;
      } else if (checklist[s.$1] == true) {
        count++;
      }
    }
    return count;
  }

  bool _isDone(Map<String, dynamic> item) {
    final checklist = item["checklist"] as Map<String, dynamic>;
    return checklist["concluido"] == true;
  }

  DateTime? _agenciadoDate(Map<String, dynamic> item) {
    final d = item["converted_at"];
    return d != null ? DateTime.parse(d) : null;
  }

  Map<String, dynamic> get _metrics {
    final now = DateTime.now();
    final total = _items.length;
    final emOnboarding = _items.where((i) => !_isDone(i)).length;
    final linked = _items.where((i) => i["linkedProfile"] != null).toList();
    final ativos = linked.where((i) => (i["linkedProfile"] as Map)["is_active"] == true).length;
    final inativos = linked.where((i) => (i["linkedProfile"] as Map)["is_active"] != true).length;
    final saida = _saidaOficialMes;
    final taxaPermanencia = linked.isEmpty ? 0.0 : (ativos / linked.length) * 100;
    final recentes90 = linked.where((i) {
      final p = i["linkedProfile"] as Map;
      final joined = p["joined_at"] != null ? DateTime.parse(p["joined_at"]) : null;
      if (joined == null) return false;
      return now.difference(joined).inDays <= 90;
    }).toList();
    final graduados = recentes90.where((i) {
      final p = i["linkedProfile"] as Map;
      final statsData = p["streamer_stats"];
      int diamonds = 0;
      if (statsData is List && statsData.isNotEmpty) diamonds = statsData.first["diamonds"] as int? ?? 0;
      if (statsData is Map) diamonds = statsData["diamonds"] as int? ?? 0;
      return diamonds >= 80000;
    }).length;
    final taxaGraduacao = recentes90.isEmpty ? 0.0 : (graduados / recentes90.length) * 100;

    return {
      "total": total,
      "emOnboarding": emOnboarding,
      "ativos": ativos,
      "inativos": inativos,
      "saida": saida,
      "taxaPermanencia": taxaPermanencia,
      "taxaGraduacao": taxaGraduacao,
    };
  }

  List<Map<String, dynamic>> get _filteredItems {
    final now = DateTime.now();
    return _items.where((item) {
      final linked = item["linkedProfile"] as Map<String, dynamic>?;
      final name = ((linked?["display_name"] ?? item["name"]) as String).toLowerCase();
      final tiktok = ((linked?["tiktok_creator_id"] ?? item["tiktok_username"]) as String? ?? "").toLowerCase();
      if (_search.isNotEmpty && !name.contains(_search.toLowerCase()) && !tiktok.contains(_search.toLowerCase())) return false;

      if (_gestorFilter != null) {
        final gestores = (item["gestores"] as List).cast<Map<String, dynamic>>();
        final emails = gestores.map((g) => (g["managers"] as Map?)?["login_email"] as String?).whereType<String>().toSet();
        if (!emails.contains(_gestorFilter)) return false;
      }

      if (_categoriaFilter != null) {
        final catData = linked != null ? linked["streamer_categories"] : null;
        final cat = catData is Map ? catData["name"] as String? : item["category_interest"] as String?;
        if (cat != _categoriaFilter) return false;
      }

      if (_statusFilter == "Concluido" && !_isDone(item)) return false;
      if (_statusFilter == "Em andamento" && _isDone(item)) return false;

      final agenciado = _agenciadoDate(item);
      if (_periodFilter != "todos" && agenciado != null) {
        final day = DateTime(agenciado.year, agenciado.month, agenciado.day);
        final today = DateTime(now.year, now.month, now.day);
        switch (_periodFilter) {
          case "hoje":
            if (day != today) return false;
            break;
          case "ontem":
            if (day != today.subtract(const Duration(days: 1))) return false;
            break;
          case "semana":
            final weekStart = today.subtract(Duration(days: today.weekday - 1));
            if (day.isBefore(weekStart)) return false;
            break;
          case "7dias":
            if (day.isBefore(today.subtract(const Duration(days: 7)))) return false;
            break;
          case "mes":
            if (!(day.year == today.year && day.month == today.month)) return false;
            break;
          case "mespassado":
            final lastMonth = DateTime(today.year, today.month - 1);
            if (!(day.year == lastMonth.year && day.month == lastMonth.month)) return false;
            break;
          case "custom":
            if (_customStart != null && day.isBefore(_customStart!)) return false;
            if (_customEnd != null && day.isAfter(_customEnd!)) return false;
            break;
        }
      }

      if (_metricFilter != null) {
        switch (_metricFilter) {
          case "emOnboarding":
            if (_isDone(item)) return false;
            break;
          case "ativos":
            if (linked == null || linked["is_active"] != true) return false;
            break;
          case "inativos":
            if (linked == null || linked["is_active"] == true) return false;
            break;
        }
      }

      return true;
    }).toList();
  }

  void _clearFilters() {
    setState(() {
      _search = "";
      _gestorFilter = null;
      _categoriaFilter = null;
      _statusFilter = null;
      _periodFilter = "todos";
      _customStart = null;
      _customEnd = null;
      _metricFilter = null;
    });
  }

  Future<void> _toggleStep(Map<String, dynamic> item, String fieldKey) async {
    final checklist = item["checklist"] as Map<String, dynamic>;
    final wasDone = checklist[fieldKey] == true;
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;

    setState(() {
      checklist[fieldKey] = !wasDone;
      checklist[fieldKey + "_at"] = wasDone ? null : DateTime.now().toIso8601String();
      checklist[fieldKey + "_by"] = wasDone ? null : userId;
    });

    try {
      await client.from("lead_onboarding_checklist").update({
        fieldKey: !wasDone,
        fieldKey + "_at": wasDone ? null : DateTime.now().toIso8601String(),
        fieldKey + "_by": wasDone ? null : userId,
        "updated_at": DateTime.now().toIso8601String(),
      }).eq("lead_id", item["id"]);
      if (!wasDone) {
        final label = onboardingSteps.firstWhere((s) => s.$1 == fieldKey, orElse: () => (fieldKey, fieldKey, Icons.check)).$2;
        await client.from("lead_history").insert({
          "lead_id": item["id"],
          "action": "onboarding_" + fieldKey,
          "detail": label,
          "performed_by": userId,
        });

        if (fieldKey == "convite_enviado") {
          try {
            await createOnboardingLeadCardIfNeeded(leadId: item["id"] as String);
          } catch (_) {}
        } else if (fieldKey == "concluido") {
          final streamerId = item["converted_streamer_id"] as String?;
          if (streamerId != null) {
            try {
              await createOnboardingPhaseCardIfNeeded(streamerId: streamerId);
            } catch (_) {}
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Vincule o streamer oficial (\"Vincular Streamer\") para iniciar o Onboarding 0-15 Dias na Gestao.")),
            );
          }
        }
      }
    } catch (e) {
      setState(() {
        checklist[fieldKey] = wasDone;
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao salvar: " + e.toString())));
    }
  }

  void _openGestorSelector(Map<String, dynamic> item) {
    showDialog(context: context, builder: (context) => _GestorPickerDialog(leadId: item["id"] as String, leadName: (item["name"] as String))).then((_) => _load());
  }

  void _openVincularStreamer(Map<String, dynamic> item) {
    showDialog(context: context, builder: (context) => _VincularStreamerDialog(leadId: item["id"] as String)).then((_) => _load());
  }

  void _openHandoff(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => LeadHandoffDialog(leadId: item["id"] as String, leadName: item["name"] as String, initialCategory: item["category_interest"] as String?),
    ).then((confirmed) {
      if (confirmed == true) _load();
    });
  }

  Widget _compactMetric(String key, IconData icon, String label, String value, Color color, String tooltip) {
    final selected = _metricFilter == key;
    return Tooltip(
      message: tooltip,
      textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8), border: Border.all(color: color)),
      child: InkWell(
        onTap: () => setState(() => _metricFilter = selected ? null : key),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.22) : color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? color : color.withOpacity(0.35), width: selected ? 1.5 : 1),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.bold, height: 1)),
                Text(label, style: const TextStyle(color: Colors.white54, fontSize: 9)),
              ],
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (picked != null) {
      setState(() {
        _customStart = DateTime(picked.start.year, picked.start.month, picked.start.day);
        _customEnd = DateTime(picked.end.year, picked.end.month, picked.end.day);
        _periodFilter = "custom";
      });
    }
  }

  Widget _buildCard(Map<String, dynamic> item) {
    final linked = item["linkedProfile"] as Map<String, dynamic>?;
    final checklist = item["checklist"] as Map<String, dynamic>;
    final gestores = (item["gestores"] as List).cast<Map<String, dynamic>>();
    final displayName = (linked?["display_name"] ?? item["name"]) as String;
    final tiktok = (linked?["tiktok_creator_id"] ?? item["tiktok_username"]) as String?;
    final avatarUrl = linked?["avatar_url"] as String?;
    final done = _stepsDone(checklist, gestores);
    final fraction = done / onboardingSteps.length;
    final isDone = _isDone(item);
    final agenciado = _agenciadoDate(item);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDone ? Colors.greenAccent.withOpacity(0.4) : Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.white24,
              backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
              child: avatarUrl == null ? const Icon(Icons.person, color: Colors.white70) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(child: Text(displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15), overflow: TextOverflow.ellipsis)),
                    if (linked == null)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                          child: const Text("NAO VINCULADO", style: TextStyle(color: Colors.orangeAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                      ),
                  ]),
                  if (tiktok != null && tiktok.isNotEmpty) Text("@" + tiktok, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  Text(
                    "Recrutador: voce" + (gestores.isNotEmpty ? "  -  Gestor: " + gestores.map((g) => (g["managers"] as Map?)?["login_email"] as String? ?? "-").join(", ") : "  -  Gestor: nao definido") +
                        (agenciado != null ? "  -  Agenciado em " + agenciado.toLocal().toString().substring(0, 10) : ""),
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(border: Border.all(color: isDone ? Colors.greenAccent : Colors.blueAccent), borderRadius: BorderRadius.circular(6)),
                  child: Text(isDone ? "Concluido" : "Em andamento", style: TextStyle(color: isDone ? Colors.greenAccent : Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 4),
                Text(done.toString() + "/" + onboardingSteps.length.toString(), style: const TextStyle(color: Color(0xFF7A0BD4), fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
          ]),
          const SizedBox(height: 10),
          ClipRRect(borderRadius: BorderRadius.circular(5), child: LinearProgressIndicator(value: fraction, minHeight: 7, backgroundColor: Colors.white12, valueColor: AlwaysStoppedAnimation(isDone ? Colors.greenAccent : const Color(0xFF7A0BD4)))),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: onboardingSteps.asMap().entries.map((entry) {
                final index = entry.key;
                final step = entry.value;
                final isGestorStep = step.$1 == "gestor";
                final isConviteEnviadoStep = step.$1 == "convite_enviado";
                final stepDone = isGestorStep ? gestores.isNotEmpty : checklist[step.$1] == true;
                return Row(children: [
                  if (index > 0) const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Icon(Icons.arrow_forward, color: Colors.white24, size: 14)),
                  InkWell(
                    onTap: () => isGestorStep
                        ? _openGestorSelector(item)
                        : isConviteEnviadoStep
                            ? _openHandoff(item)
                            : _toggleStep(item, step.$1),
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: stepDone ? Colors.greenAccent.withOpacity(0.15) : Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: stepDone ? Colors.greenAccent : Colors.white24),
                      ),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(stepDone ? Icons.check_circle : step.$3, color: stepDone ? Colors.greenAccent : Colors.white38, size: 18),
                        const SizedBox(height: 4),
                        Text(step.$2, style: TextStyle(color: stepDone ? Colors.greenAccent : Colors.white54, fontSize: 9, fontWeight: stepDone ? FontWeight.bold : FontWeight.normal), textAlign: TextAlign.center),
                      ]),
                    ),
                  ),
                ]);
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            if (linked == null)
              OutlinedButton.icon(onPressed: () => _openVincularStreamer(item), icon: const Icon(Icons.link, size: 14), label: const Text("Vincular Streamer", style: TextStyle(fontSize: 12))),
            const Spacer(),
            TextButton.icon(
              onPressed: () => showDialog(context: context, builder: (context) => _FichaCompletaDialog(item: item)),
              icon: const Icon(Icons.open_in_new, size: 14),
              label: const Text("Ver perfil completo", style: TextStyle(fontSize: 12)),
            ),
          ]),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text("Erro ao carregar: " + _error!, style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center),
        ),
      );
    }

    final m = _metrics;
    final filtered = _filteredItems;
    final categorias = _items.map((i) {
      final linked = i["linkedProfile"] as Map<String, dynamic>?;
      final catData = linked != null ? linked["streamer_categories"] : null;
      return catData is Map ? catData["name"] as String? : i["category_interest"] as String?;
    }).whereType<String>().where((c) => c.isNotEmpty).toSet().toList()
      ..sort();
    final gestoresDisponiveis = <String>{};
    for (final i in _items) {
      final gestores = (i["gestores"] as List).cast<Map<String, dynamic>>();
      for (final g in gestores) {
        final email = (g["managers"] as Map?)?["login_email"] as String?;
        if (email != null) gestoresDisponiveis.add(email);
      }
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Text("Streamers Agenciados", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(width: 12),
              IconButton(icon: const Icon(Icons.refresh, color: Colors.white70), onPressed: _load),
            ]),
            const SizedBox(height: 4),
            const Text("Central de Onboarding - a lista abaixo e criada automaticamente quando um lead vira Agenciado no Kanban.", style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic)),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _compactMetric("total", Icons.people_alt, "Total Agenciados", m["total"].toString(), const Color(0xFF7A0BD4), "Total de streamers agenciados por voce."),
                const SizedBox(width: 8),
                _compactMetric("emOnboarding", Icons.hourglass_bottom, "Em Onboarding", m["emOnboarding"].toString(), Colors.blueAccent, "Ainda nao concluiram todas as etapas de onboarding."),
                const SizedBox(width: 8),
                _compactMetric("ativos", Icons.check_circle, "Ativos", m["ativos"].toString(), Colors.greenAccent, "Streamers com cadastro oficial vinculado e ativos."),
                const SizedBox(width: 8),
                _compactMetric("inativos", Icons.cancel, "Inativos", m["inativos"].toString(), Colors.redAccent, "Streamers com cadastro oficial vinculado e inativos."),
                const SizedBox(width: 8),
                _compactMetric("saida", Icons.logout, "Sairam da Agencia", m["saida"].toString(), Colors.orangeAccent, "Ficaram inativos ate 30 dias apos entrar."),
                const SizedBox(width: 8),
                _compactMetric("permanencia", Icons.trending_up, "Taxa de Permanencia", (m["taxaPermanencia"] as double).toStringAsFixed(0) + "%", Colors.tealAccent, "Percentual dos vinculados oficialmente que seguem ativos."),
                const SizedBox(width: 8),
                _compactMetric("graduacao", Icons.emoji_events, "Graduacao", (m["taxaGraduacao"] as double).toStringAsFixed(0) + "%", Colors.amber, "Entre os agenciados nos ultimos 90 dias, % que alcancou 80 mil diamantes."),
              ]),
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(12)),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 210,
                    child: TextField(
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.search, color: Colors.white54, size: 18), hintText: "Buscar nome ou @TikTok", hintStyle: TextStyle(color: Colors.white38), isDense: true),
                      onChanged: (v) => setState(() => _search = v),
                    ),
                  ),
                  DropdownButton<String?>(
                    value: _gestorFilter,
                    hint: const Text("Gestor responsavel", style: TextStyle(color: Colors.white54, fontSize: 12)),
                    dropdownColor: const Color(0xFF1A1A1A),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    items: [const DropdownMenuItem<String?>(value: null, child: Text("Todos os gestores")), ...gestoresDisponiveis.map((g) => DropdownMenuItem<String?>(value: g, child: Text(g)))],
                    onChanged: (v) => setState(() => _gestorFilter = v),
                  ),
                  DropdownButton<String?>(
                    value: _categoriaFilter,
                    hint: const Text("Categoria", style: TextStyle(color: Colors.white54, fontSize: 12)),
                    dropdownColor: const Color(0xFF1A1A1A),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    items: [const DropdownMenuItem<String?>(value: null, child: Text("Todas categorias")), ...categorias.map((c) => DropdownMenuItem<String?>(value: c, child: Text(c)))],
                    onChanged: (v) => setState(() => _categoriaFilter = v),
                  ),
                  DropdownButton<String?>(
                    value: _statusFilter,
                    hint: const Text("Status", style: TextStyle(color: Colors.white54, fontSize: 12)),
                    dropdownColor: const Color(0xFF1A1A1A),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    items: const [
                      DropdownMenuItem<String?>(value: null, child: Text("Todos status")),
                      DropdownMenuItem<String?>(value: "Em andamento", child: Text("Em andamento")),
                      DropdownMenuItem<String?>(value: "Concluido", child: Text("Concluido")),
                    ],
                    onChanged: (v) => setState(() => _statusFilter = v),
                  ),
                  Wrap(
                    spacing: 6,
                    children: [
                      ("todos", "Todos"),
                      ("hoje", "Hoje"),
                      ("ontem", "Ontem"),
                      ("semana", "Esta semana"),
                      ("7dias", "Ultimos 7 dias"),
                      ("mes", "Este mes"),
                      ("mespassado", "Mes passado"),
                    ].map((p) {
                      final selected = _periodFilter == p.$1;
                      return ChoiceChip(
                        label: Text(p.$2, style: const TextStyle(fontSize: 11)),
                        selected: selected,
                        selectedColor: const Color(0xFF7A0BD4),
                        labelStyle: TextStyle(color: selected ? Colors.white : Colors.white70),
                        onSelected: (_) => setState(() => _periodFilter = p.$1),
                      );
                    }).toList(),
                  ),
                  OutlinedButton.icon(
                    onPressed: _pickCustomRange,
                    icon: const Icon(Icons.date_range, size: 14),
                    label: Text(_periodFilter == "custom" && _customStart != null
                        ? _customStart!.toIso8601String().substring(0, 10) + " a " + _customEnd!.toIso8601String().substring(0, 10)
                        : "Periodo personalizado", style: const TextStyle(fontSize: 11)),
                  ),
                  TextButton.icon(onPressed: _clearFilters, icon: const Icon(Icons.filter_alt_off, size: 14), label: const Text("Limpar filtros", style: TextStyle(fontSize: 12))),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(filtered.length.toString() + " streamers", style: const TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 12),
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(children: [
                    const Icon(Icons.inbox_outlined, color: Colors.white24, size: 40),
                    const SizedBox(height: 8),
                    Text(_items.isEmpty ? "Nenhum streamer agenciado ainda. Mova um lead para Agenciado no Kanban." : "Nenhum resultado com esses filtros.", style: const TextStyle(color: Colors.white54)),
                  ]),
                ),
              )
            else
              ...filtered.map(_buildCard),
          ],
        ),
      ),
    );
  }
}

class _GestorPickerDialog extends StatefulWidget {
  final String leadId;
  final String leadName;
  const _GestorPickerDialog({required this.leadId, required this.leadName});

  @override
  State<_GestorPickerDialog> createState() => _GestorPickerDialogState();
}

class _GestorPickerDialogState extends State<_GestorPickerDialog> {
  List<Map<String, dynamic>> _gestores = [];
  final Set<String> _selected = {};
  String _search = "";
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final client = Supabase.instance.client;
    final rows = await client.from("managers").select("id, login_email, photo_url, department");
    final gestoresList = (rows as List).cast<Map<String, dynamic>>();
    for (final g in gestoresList) {
      final count = await client.from("profiles").select("id").eq("assigned_manager_id", g["id"]).eq("is_active", true);
      g["activeCount"] = (count as List).length;
    }
    final current = await client.from("lead_onboarding_gestores").select("manager_id").eq("lead_id", widget.leadId);
    setState(() {
      _gestores = gestoresList;
      _selected.addAll((current as List).map((c) => c["manager_id"] as String));
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final client = Supabase.instance.client;
    final existing = await client.from("lead_onboarding_gestores").select("manager_id").eq("lead_id", widget.leadId);
    final existingIds = (existing as List).map((e) => e["manager_id"] as String).toSet();

    final toAdd = _selected.difference(existingIds);
    final toRemove = existingIds.difference(_selected);

    for (final id in toAdd) {
      await client.from("lead_onboarding_gestores").insert({"lead_id": widget.leadId, "manager_id": id});
      await client.from("manager_notifications").insert({
        "manager_id": id,
        "message": "Voce foi selecionado como gestor de: " + widget.leadName,
      });
      await propagateManagerToProfile(leadId: widget.leadId, managerId: id);
    }
    for (final id in toRemove) {
      await client.from("lead_onboarding_gestores").delete().eq("lead_id", widget.leadId).eq("manager_id", id);
    }

    // Se o gestor foi definido aqui antes de qualquer "Convite enviado", o
    // card do Onboarding 0-15 ainda pode nao existir -- propagateManagerToProfile
    // so atualiza um card ja existente, nunca cria um novo.
    if (toAdd.isNotEmpty) {
      try {
        final leadRow = await client.from("leads").select("converted_streamer_id").eq("id", widget.leadId).maybeSingle();
        final streamerId = leadRow?["converted_streamer_id"] as String?;
        if (streamerId != null) {
          await createOnboardingPhaseCardIfNeeded(streamerId: streamerId);
        } else {
          await createOnboardingLeadCardIfNeeded(leadId: widget.leadId);
        }
      } catch (_) {}
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _gestores.where((g) => (g["login_email"] as String).toLowerCase().contains(_search.toLowerCase())).toList();
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Selecionar gestor(es) para " + widget.leadName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text("Pode selecionar mais de um colaborador.", style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic)),
              const SizedBox(height: 8),
              TextField(
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search, color: Colors.white54), hintText: "Pesquisar gestor", hintStyle: TextStyle(color: Colors.white38), isDense: true),
                onChanged: (v) => setState(() => _search = v),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text("Nenhum gestor encontrado.", style: TextStyle(color: Colors.white54)))
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final g = filtered[index];
                          final id = g["id"] as String;
                          return CheckboxListTile(
                            enabled: !_saving,
                            value: _selected.contains(id),
                            onChanged: (v) => setState(() {
                              if (v == true) { _selected.add(id); } else { _selected.remove(id); }
                            }),
                            controlAffinity: ListTileControlAffinity.leading,
                            activeColor: const Color(0xFF7A0BD4),
                            secondary: CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.white24,
                              backgroundImage: g["photo_url"] != null ? NetworkImage(g["photo_url"] as String) : null,
                              child: g["photo_url"] == null ? const Icon(Icons.person, color: Colors.white70, size: 18) : null,
                            ),
                            title: Text(g["login_email"] as String, style: const TextStyle(color: Colors.white, fontSize: 13)),
                            subtitle: Text(
                              g["activeCount"].toString() + " streamers ativos" + ((g["department"] as String?)?.isNotEmpty == true ? "  -  " + g["department"] : ""),
                              style: const TextStyle(color: Colors.white54, fontSize: 11),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancelar")),
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

class _VincularStreamerDialog extends StatefulWidget {
  final String leadId;
  const _VincularStreamerDialog({required this.leadId});

  @override
  State<_VincularStreamerDialog> createState() => _VincularStreamerDialogState();
}

class _VincularStreamerDialogState extends State<_VincularStreamerDialog> {
  String _search = "";
  List<Map<String, dynamic>> _results = [];
  bool _searching = false;
  String? _selectedId;
  bool _saving = false;

  Future<void> _doSearch(String query) async {
    setState(() {
      _search = query;
      _searching = true;
    });
    if (query.trim().length < 2) {
      setState(() {
        _results = [];
        _searching = false;
      });
      return;
    }
    final client = Supabase.instance.client;
    final rows = await client
        .from("profiles")
        .select("id, display_name, tiktok_creator_id, avatar_url")
        .or("display_name.ilike.%" + query + "%,tiktok_creator_id.ilike.%" + query + "%")
        .limit(20);
    setState(() {
      _results = (rows as List).cast<Map<String, dynamic>>();
      _searching = false;
    });
  }

  Future<void> _confirm() async {
    if (_selectedId == null) return;
    setState(() => _saving = true);
    final client = Supabase.instance.client;
    try {
      await client.from("leads").update({"converted_streamer_id": _selectedId}).eq("id", widget.leadId);

      final gestores = await client.from("lead_onboarding_gestores").select("manager_id").eq("lead_id", widget.leadId);
      final currentGestor = (gestores as List).isNotEmpty ? (gestores.first["manager_id"] as String) : null;
      if (currentGestor != null) {
        await propagateManagerToProfile(leadId: widget.leadId, managerId: currentGestor);
      }

      // Vincular o streamer oficial ja e suficiente pra promover o card no
      // Onboarding 0-15 do gestor -- nao faz sentido exigir tambem
      // "Onboarding Concluido" aqui, senao o card fica preso como
      // "pre-vinculo" mesmo depois do streamer ja estar oficialmente
      // vinculado.
      try {
        await createOnboardingPhaseCardIfNeeded(streamerId: _selectedId!);
      } catch (_) {}

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao vincular: " + e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Vincular Streamer Oficial", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text("Pesquise pelo nome ou @TikTok do cadastro oficial (ja importado da planilha).", style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic)),
              const SizedBox(height: 12),
              TextField(
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search, color: Colors.white54), hintText: "Nome ou @TikTok", hintStyle: TextStyle(color: Colors.white38), isDense: true),
                onChanged: _doSearch,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _searching
                    ? const Center(child: CircularProgressIndicator())
                    : _results.isEmpty
                        ? Center(child: Text(_search.trim().length < 2 ? "Digite ao menos 2 letras para buscar." : "Nenhum streamer oficial encontrado.", style: const TextStyle(color: Colors.white54, fontSize: 12), textAlign: TextAlign.center))
                        : ListView.builder(
                            itemCount: _results.length,
                            itemBuilder: (context, index) {
                              final r = _results[index];
                              final selected = _selectedId == r["id"];
                              return ListTile(
                                onTap: () => setState(() => _selectedId = r["id"] as String),
                                selected: selected,
                                selectedTileColor: const Color(0xFF7A0BD4).withOpacity(0.15),
                                leading: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Colors.white24,
                                  backgroundImage: r["avatar_url"] != null ? NetworkImage(r["avatar_url"] as String) : null,
                                  child: r["avatar_url"] == null ? const Icon(Icons.person, color: Colors.white70, size: 16) : null,
                                ),
                                title: Text(r["display_name"] as String, style: const TextStyle(color: Colors.white, fontSize: 13)),
                                subtitle: Text("@" + (r["tiktok_creator_id"] as String? ?? "-"), style: const TextStyle(color: Colors.white54, fontSize: 11)),
                                trailing: selected ? const Icon(Icons.check_circle, color: Color(0xFF7A0BD4)) : null,
                              );
                            },
                          ),
              ),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancelar")),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: (_selectedId == null || _saving) ? null : _confirm,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
                  child: Text(_saving ? "Vinculando..." : "Confirmar vinculo"),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _FichaCompletaDialog extends StatelessWidget {
  final Map<String, dynamic> item;
  const _FichaCompletaDialog({required this.item});

  @override
  Widget build(BuildContext context) {
    final linked = item["linkedProfile"] as Map<String, dynamic>?;
    final checklist = item["checklist"] as Map<String, dynamic>;
    final gestores = (item["gestores"] as List).cast<Map<String, dynamic>>();
    final displayName = (linked?["display_name"] ?? item["name"]) as String;
    final tiktok = (linked?["tiktok_creator_id"] ?? item["tiktok_username"]) as String?;

    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 700),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                if (tiktok != null) Text("@" + tiktok, style: const TextStyle(color: Colors.white54)),
                if (item["phone"] != null && (item["phone"] as String).isNotEmpty) Text("WhatsApp: " + item["phone"], style: const TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                Text(linked != null ? "Vinculado ao cadastro oficial" : "Ainda nao vinculado ao cadastro oficial", style: TextStyle(color: linked != null ? Colors.greenAccent : Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                const Text("Etapas do Onboarding", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                ...onboardingSteps.where((s) => s.$1 != "gestor").map((s) {
                  final done = checklist[s.$1] == true;
                  final at = checklist[s.$1 + "_at"];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Icon(done ? Icons.check_circle : Icons.radio_button_unchecked, color: done ? Colors.greenAccent : Colors.white24, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(s.$2, style: TextStyle(color: done ? Colors.white : Colors.white54, fontSize: 13))),
                      if (done && at != null) Text(DateTime.parse(at).toLocal().toString().substring(0, 16), style: const TextStyle(color: Colors.white38, fontSize: 11)),
                    ]),
                  );
                }),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Icon(gestores.isNotEmpty ? Icons.check_circle : Icons.radio_button_unchecked, color: gestores.isNotEmpty ? Colors.greenAccent : Colors.white24, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Gestor: " + (gestores.isEmpty ? "nao definido" : gestores.map((g) => (g["managers"] as Map?)?["login_email"] as String? ?? "-").join(", ")),
                        style: TextStyle(color: gestores.isNotEmpty ? Colors.white : Colors.white54, fontSize: 13),
                      ),
                    ),
                  ]),
                ),
                if (checklist["notes"] != null && (checklist["notes"] as String).isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text("Observacoes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 6),
                  Text(checklist["notes"], style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
                const SizedBox(height: 16),
                Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Fechar"))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


