import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";

class TeamMissionsPage extends StatefulWidget {
  const TeamMissionsPage({super.key});

  @override
  State<TeamMissionsPage> createState() => _TeamMissionsPageState();
}

class _TeamMissionsPageState extends State<TeamMissionsPage> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final client = Supabase.instance.client;
    final missions = await client.from("recruiter_missions").select().order("created_at", ascending: false);
    final missionsList = (missions as List).cast<Map<String, dynamic>>();

    for (final m in missionsList) {
      final recruiters = await client.from("recruiter_mission_assignees").select("recruiter_id, managers(login_email)").eq("mission_id", m["id"]);
      m["recruiters"] = (recruiters as List).cast<Map<String, dynamic>>();
      final categoryTargets = await client.from("recruiter_mission_category_targets").select().eq("mission_id", m["id"]);
      m["categoryTargets"] = (categoryTargets as List).cast<Map<String, dynamic>>();
    }
    return missionsList;
  }

  void _openForm({Map<String, dynamic>? existing}) {
    showDialog(context: context, builder: (context) => _MissionFormDialog(existing: existing)).then((saved) {
      if (saved == true) setState(() => _future = _load());
    });
  }

  Future<void> _delete(String id) async {
    final client = Supabase.instance.client;
    await client.from("recruiter_missions").delete().eq("id", id);
    setState(() => _future = _load());
  }

  Future<void> _toggleActive(String id, bool current) async {
    final client = Supabase.instance.client;
    await client.from("recruiter_missions").update({"is_active": !current}).eq("id", id);
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text("Missoes", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(width: 12),
            IconButton(icon: const Icon(Icons.refresh, color: Colors.white70), onPressed: () => setState(() => _future = _load())),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add),
              label: const Text("Nova Missao"),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
            ),
          ]),
          const SizedBox(height: 4),
          const Text("Missoes aparecem automaticamente no Dashboard, Metricas e Perfil de cada recrutador atribuido.", style: TextStyle(color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic)),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final list = snapshot.data!;
                if (list.isEmpty) return const Center(child: Text("Nenhuma missao cadastrada ainda.", style: TextStyle(color: Colors.white54)));
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final m = list[index];
                    final active = m["is_active"] as bool? ?? true;
                    final scope = m["scope"] as String;
                    final recruiters = (m["recruiters"] as List).cast<Map<String, dynamic>>();
                    final categoryTargets = (m["categoryTargets"] as List).cast<Map<String, dynamic>>();
                    final scopeLabel = scope == "geral" ? "GERAL (toda equipe)" : scope == "grupo" ? "GRUPO" : "INDIVIDUAL";
                    final scopeColor = scope == "geral" ? Colors.amber : scope == "grupo" ? Colors.tealAccent : const Color(0xFF7A0BD4);

                    return Card(
                      color: Colors.white.withOpacity(0.05),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: scopeColor.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                                child: Text(scopeLabel, style: TextStyle(color: scopeColor, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text(m["name"] as String, style: TextStyle(color: active ? Colors.white : Colors.white38, fontWeight: FontWeight.bold, fontSize: 15))),
                              Switch(value: active, onChanged: (_) => _toggleActive(m["id"] as String, active), activeColor: const Color(0xFF7A0BD4)),
                              IconButton(icon: const Icon(Icons.edit, color: Colors.white54, size: 18), onPressed: () => _openForm(existing: m)),
                              IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18), onPressed: () => _delete(m["id"] as String)),
                            ]),
                            if (scope != "geral" && recruiters.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text("Recrutadores: " + recruiters.map((r) => (r["managers"] as Map)["login_email"] as String? ?? "-").join(", "), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                            ],
                            const SizedBox(height: 10),
                            Wrap(spacing: 16, runSpacing: 6, children: [
                              if ((m["leads_dia"] as num?) != null) _goalChip("Leads/dia", m["leads_dia"]),
                              if ((m["leads_semana"] as num?) != null) _goalChip("Leads/semana", m["leads_semana"]),
                              if ((m["leads_mes"] as num?) != null) _goalChip("Leads/mes", m["leads_mes"]),
                              if ((m["agenciamentos_dia"] as num?) != null) _goalChip("Agenciados/dia", m["agenciamentos_dia"]),
                              if ((m["agenciamentos_semana"] as num?) != null) _goalChip("Agenciados/semana", m["agenciamentos_semana"]),
                              if ((m["agenciamentos_mes"] as num?) != null) _goalChip("Agenciados/mes", m["agenciamentos_mes"]),
                            ]),
                            if (categoryTargets.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              const Text("Metas por categoria:", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Wrap(spacing: 12, children: categoryTargets.map((c) => Text(c["category_name"] + ": " + (c["target_leads"] as num).toStringAsFixed(0) + " leads", style: const TextStyle(color: Colors.tealAccent, fontSize: 12))).toList()),
                            ],
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
      ),
    );
  }

  Widget _goalChip(String label, num? value) {
    if (value == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
      child: Text(label + ": " + value.toStringAsFixed(0), style: const TextStyle(color: Colors.white, fontSize: 12)),
    );
  }
}

class _MissionFormDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const _MissionFormDialog({this.existing});

  @override
  State<_MissionFormDialog> createState() => _MissionFormDialogState();
}

class _MissionFormDialogState extends State<_MissionFormDialog> {
  final _nameController = TextEditingController();
  String _scope = "individual";
  List<Map<String, dynamic>> _recruiters = [];
  final Set<String> _selectedRecruiterIds = {};
  final _leadsDiaController = TextEditingController();
  final _leadsSemanaController = TextEditingController();
  final _leadsMesController = TextEditingController();
  final _agDiaController = TextEditingController();
  final _agSemanaController = TextEditingController();
  final _agMesController = TextEditingController();
  List<Map<String, dynamic>> _categories = [];
  final List<Map<String, dynamic>> _categoryRows = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadRecruiters();
    _loadCategories();
    final e = widget.existing;
    if (e != null) {
      _nameController.text = e["name"] ?? "";
      _scope = e["scope"] ?? "individual";
      _leadsDiaController.text = (e["leads_dia"] as num?)?.toString() ?? "";
      _leadsSemanaController.text = (e["leads_semana"] as num?)?.toString() ?? "";
      _leadsMesController.text = (e["leads_mes"] as num?)?.toString() ?? "";
      _agDiaController.text = (e["agenciamentos_dia"] as num?)?.toString() ?? "";
      _agSemanaController.text = (e["agenciamentos_semana"] as num?)?.toString() ?? "";
      _agMesController.text = (e["agenciamentos_mes"] as num?)?.toString() ?? "";
      final recruiters = (e["recruiters"] as List?)?.cast<Map<String, dynamic>>() ?? [];
      for (final r in recruiters) {
        _selectedRecruiterIds.add(r["recruiter_id"] as String);
      }
      final categoryTargets = (e["categoryTargets"] as List?)?.cast<Map<String, dynamic>>() ?? [];
      for (final c in categoryTargets) {
        _categoryRows.add({"category": c["category_name"], "controller": TextEditingController(text: (c["target_leads"] as num).toString())});
      }
    }
  }

  Future<void> _loadRecruiters() async {
    final client = Supabase.instance.client;
    final leads = await client.from("leads").select("recruiter_id");
    final ids = (leads as List).map((l) => l["recruiter_id"] as String).toSet();
    if (ids.isEmpty) return;
    final rows = await client.from("managers").select("id, login_email").inFilter("id", ids.toList());
    setState(() => _recruiters = (rows as List).cast<Map<String, dynamic>>());
  }

  Future<void> _loadCategories() async {
    final client = Supabase.instance.client;
    final rows = await client.from("lead_categories").select().eq("is_active", true).order("order_index");
    setState(() => _categories = (rows as List).cast<Map<String, dynamic>>());
  }

  void _addCategoryRow() {
    if (_categories.isEmpty) return;
    setState(() => _categoryRows.add({"category": _categories.first["name"], "controller": TextEditingController()}));
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) return;
    if (_scope != "geral" && _selectedRecruiterIds.isEmpty) return;
    setState(() => _saving = true);
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;
    final manager = await client.from("managers").select("agency_id").eq("id", userId).single();

    double? parse(TextEditingController c) => c.text.trim().isEmpty ? null : double.tryParse(c.text.trim());

    final data = {
      "agency_id": manager["agency_id"],
      "name": _nameController.text.trim(),
      "scope": _scope,
      "leads_dia": parse(_leadsDiaController),
      "leads_semana": parse(_leadsSemanaController),
      "leads_mes": parse(_leadsMesController),
      "agenciamentos_dia": parse(_agDiaController),
      "agenciamentos_semana": parse(_agSemanaController),
      "agenciamentos_mes": parse(_agMesController),
      "created_by": userId,
    };

    String missionId;
    if (widget.existing != null) {
      missionId = widget.existing!["id"];
      await client.from("recruiter_missions").update(data).eq("id", missionId);
      await client.from("recruiter_mission_assignees").delete().eq("mission_id", missionId);
      await client.from("recruiter_mission_category_targets").delete().eq("mission_id", missionId);
    } else {
      final inserted = await client.from("recruiter_missions").insert(data).select().single();
      missionId = inserted["id"];
    }

    if (_scope != "geral") {
      for (final rid in _selectedRecruiterIds) {
        await client.from("recruiter_mission_assignees").insert({"mission_id": missionId, "recruiter_id": rid});
      }
    }

    for (final row in _categoryRows) {
      final controller = row["controller"] as TextEditingController;
      final value = double.tryParse(controller.text.trim());
      if (value != null && value > 0) {
        await client.from("recruiter_mission_category_targets").insert({"mission_id": missionId, "category_name": row["category"], "target_leads": value});
      }
    }

    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 780),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.existing != null ? "Editar Missao" : "Nova Missao", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(controller: _nameController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Nome da missao", labelStyle: TextStyle(color: Colors.white54))),
                const SizedBox(height: 12),
                const Text("Aplicar para:", style: TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 6),
                Wrap(spacing: 8, children: [
                  ChoiceChip(label: const Text("Individual"), selected: _scope == "individual", selectedColor: const Color(0xFF7A0BD4), labelStyle: TextStyle(color: _scope == "individual" ? Colors.white : Colors.white70), onSelected: (_) => setState(() => _scope = "individual")),
                  ChoiceChip(label: const Text("Grupo (varios)"), selected: _scope == "grupo", selectedColor: Colors.tealAccent, labelStyle: TextStyle(color: _scope == "grupo" ? Colors.black : Colors.white70), onSelected: (_) => setState(() => _scope = "grupo")),
                  ChoiceChip(label: const Text("Geral (toda equipe)"), selected: _scope == "geral", selectedColor: Colors.amber, labelStyle: TextStyle(color: _scope == "geral" ? Colors.black : Colors.white70), onSelected: (_) => setState(() => _scope = "geral")),
                ]),
                if (_scope != "geral") ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    const Text("Recrutadores:", style: TextStyle(color: Colors.white54, fontSize: 12)),
                    const Spacer(),
                    TextButton(onPressed: () => setState(() => _selectedRecruiterIds.addAll(_recruiters.map((r) => r["id"] as String))), child: const Text("Selecionar todos")),
                    TextButton(onPressed: () => setState(_selectedRecruiterIds.clear), child: const Text("Limpar")),
                  ]),
                  ..._recruiters.map((r) {
                    final id = r["id"] as String;
                    return CheckboxListTile(
                      value: _selectedRecruiterIds.contains(id),
                      onChanged: (v) => setState(() {
                        if (v == true) { _selectedRecruiterIds.add(id); } else { _selectedRecruiterIds.remove(id); }
                      }),
                      title: Text(r["login_email"] as String, style: const TextStyle(color: Colors.white, fontSize: 13)),
                      activeColor: const Color(0xFF7A0BD4),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    );
                  }),
                ],
                const SizedBox(height: 16),
                const Text("Meta de Leads", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                Row(children: [
                  Expanded(child: TextField(controller: _leadsDiaController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Por dia", labelStyle: TextStyle(color: Colors.white54)))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: _leadsSemanaController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Por semana", labelStyle: TextStyle(color: Colors.white54)))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: _leadsMesController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Por mes", labelStyle: TextStyle(color: Colors.white54)))),
                ]),
                const SizedBox(height: 12),
                const Text("Meta de Agenciamentos", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                Row(children: [
                  Expanded(child: TextField(controller: _agDiaController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Por dia", labelStyle: TextStyle(color: Colors.white54)))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: _agSemanaController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Por semana", labelStyle: TextStyle(color: Colors.white54)))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: _agMesController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Por mes", labelStyle: TextStyle(color: Colors.white54)))),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  const Text("Metas por Categoria", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  const Spacer(),
                  TextButton.icon(onPressed: _addCategoryRow, icon: const Icon(Icons.add, size: 16), label: const Text("Adicionar categoria")),
                ]),
                ..._categoryRows.map((row) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Expanded(
                        child: DropdownButton<String>(
                          value: row["category"] as String,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF1A1A1A),
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          items: _categories.map((c) => DropdownMenuItem(value: c["name"] as String, child: Text(c["name"] as String))).toList(),
                          onChanged: (v) => setState(() => row["category"] = v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 90,
                        child: TextField(
                          controller: row["controller"] as TextEditingController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: const InputDecoration(labelText: "Leads", labelStyle: TextStyle(color: Colors.white54, fontSize: 11)),
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.close, color: Colors.redAccent, size: 16), onPressed: () => setState(() => _categoryRows.remove(row))),
                    ]),
                  );
                }),
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

