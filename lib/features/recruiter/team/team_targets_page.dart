import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";

const _metrics = [
  ("leads", "Quantidade de Leads"),
  ("contatos", "Contatos realizados"),
  ("agenciamentos", "Streamers recrutados"),
  ("conversao_minima", "Taxa minima de conversao (%)"),
];

class TeamTargetsPage extends StatefulWidget {
  const TeamTargetsPage({super.key});

  @override
  State<TeamTargetsPage> createState() => _TeamTargetsPageState();
}

class _TeamTargetsPageState extends State<TeamTargetsPage> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final client = Supabase.instance.client;
    final targets = await client.from("recruiter_targets").select("*, managers!recruiter_targets_recruiter_id_fkey(login_email)").order("starts_at", ascending: false);
    final targetsList = (targets as List).cast<Map<String, dynamic>>();

    final leads = await client.from("leads").select("recruiter_id, status, created_at, converted_at");
    final leadsList = (leads as List).cast<Map<String, dynamic>>();

    for (final t in targetsList) {
      final rid = t["recruiter_id"];
      final start = DateTime.parse(t["starts_at"]);
      final end = DateTime.parse(t["ends_at"]);
      final own = rid == null ? leadsList : leadsList.where((l) => l["recruiter_id"] == rid).toList();

      double progress = 0;
      switch (t["metric"]) {
        case "leads":
          progress = own.where((l) {
            final d = DateTime.parse(l["created_at"]);
            return !d.isBefore(start) && !d.isAfter(end);
          }).length.toDouble();
          break;
        case "agenciamentos":
          progress = own.where((l) {
            if (l["status"] != "agenciado" || l["converted_at"] == null) return false;
            final d = DateTime.parse(l["converted_at"]);
            return !d.isBefore(start) && !d.isAfter(end);
          }).length.toDouble();
          break;
        case "contatos":
          progress = own.where((l) {
            final d = DateTime.parse(l["created_at"]);
            return l["status"] != "novo" && !d.isBefore(start) && !d.isAfter(end);
          }).length.toDouble();
          break;
        case "conversao_minima":
          final periodLeads = own.where((l) {
            final d = DateTime.parse(l["created_at"]);
            return !d.isBefore(start) && !d.isAfter(end);
          }).toList();
          final agenciados = periodLeads.where((l) => l["status"] == "agenciado").length;
          progress = periodLeads.isEmpty ? 0 : (agenciados / periodLeads.length) * 100;
          break;
      }
      t["progress"] = progress;
    }
    return targetsList;
  }

  void _openForm({Map<String, dynamic>? existing}) {
    showDialog(context: context, builder: (context) => _TargetFormDialog(existing: existing)).then((saved) {
      if (saved == true) setState(() => _future = _load());
    });
  }

  Future<void> _delete(String id) async {
    final client = Supabase.instance.client;
    await client.from("recruiter_targets").delete().eq("id", id);
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
            const Text("Metas", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(width: 12),
            IconButton(icon: const Icon(Icons.refresh, color: Colors.white70), onPressed: () => setState(() => _future = _load())),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add),
              label: const Text("Nova Meta"),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () {
                showDialog(context: context, builder: (context) => const _BulkTargetFormDialog()).then((saved) {
                  if (saved == true) setState(() => _future = _load());
                });
              },
              icon: const Icon(Icons.playlist_add_check, size: 18),
              label: const Text("Cadastro em Massa"),
            ),
          ]),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final list = snapshot.data!;
                if (list.isEmpty) return const Center(child: Text("Nenhuma meta cadastrada ainda.", style: TextStyle(color: Colors.white54)));
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final t = list[index];
                    final managerData = t["managers"];
                    final isGeneral = t["recruiter_id"] == null;
                    final metricLabel = _metrics.firstWhere((m) => m.$1 == t["metric"], orElse: () => ("", t["metric"])).$2;
                    final progress = t["progress"] as double;
                    final target = (t["target_value"] as num).toDouble();
                    final fraction = target == 0 ? 0.0 : (progress / target).clamp(0.0, 1.0);
                    return Card(
                      color: Colors.white.withOpacity(0.05),
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              if (isGeneral)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                                  child: const Text("GERAL", style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              Expanded(
                                child: Text(
                                  isGeneral ? "Toda a equipe" : (managerData is Map ? managerData["login_email"] as String? ?? "-" : "-"),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                              IconButton(icon: const Icon(Icons.edit, color: Colors.white54, size: 18), onPressed: () => _openForm(existing: t)),
                              IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18), onPressed: () => _delete(t["id"] as String)),
                            ]),
                            Text(metricLabel + " - " + (t["period_type"] as String) + " (" + t["starts_at"].toString() + " a " + t["ends_at"].toString() + ")", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                            const SizedBox(height: 8),
                            Text(progress.toStringAsFixed(0) + " / " + target.toStringAsFixed(0), style: const TextStyle(color: Color(0xFF7A0BD4), fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(value: fraction, minHeight: 6, backgroundColor: Colors.white12, valueColor: const AlwaysStoppedAnimation(Color(0xFF7A0BD4))),
                            ),
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
}

class _TargetFormDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const _TargetFormDialog({this.existing});

  @override
  State<_TargetFormDialog> createState() => _TargetFormDialogState();
}

class _TargetFormDialogState extends State<_TargetFormDialog> {
  List<Map<String, dynamic>> _recruiters = [];
  String _scope = "individual";
  String? _selectedRecruiterId;
  String _metric = "agenciamentos";
  String _periodType = "mensal";
  final _valueController = TextEditingController();
  DateTime _startsAt = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endsAt = DateTime(DateTime.now().year, DateTime.now().month + 1, 0);
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadRecruiters();
    final e = widget.existing;
    if (e != null) {
      _scope = e["recruiter_id"] == null ? "geral" : "individual";
      _selectedRecruiterId = e["recruiter_id"];
      _metric = e["metric"];
      _periodType = e["period_type"];
      _valueController.text = (e["target_value"] as num).toString();
      _startsAt = DateTime.parse(e["starts_at"]);
      _endsAt = DateTime.parse(e["ends_at"]);
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

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(context: context, initialDate: isStart ? _startsAt : _endsAt, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (picked != null) setState(() => isStart ? _startsAt = picked : _endsAt = picked);
  }

  Future<void> _save() async {
    if (_scope == "individual" && _selectedRecruiterId == null) return;
    if (_valueController.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final client = Supabase.instance.client;
    final createdBy = client.auth.currentUser!.id;
    final data = {
      "recruiter_id": _scope == "geral" ? null : _selectedRecruiterId,
      "metric": _metric,
      "target_value": double.tryParse(_valueController.text) ?? 0,
      "period_type": _periodType,
      "starts_at": _startsAt.toIso8601String().substring(0, 10),
      "ends_at": _endsAt.toIso8601String().substring(0, 10),
      "created_by": createdBy,
    };
    if (widget.existing != null) {
      await client.from("recruiter_targets").update(data).eq("id", widget.existing!["id"]);
    } else {
      await client.from("recruiter_targets").insert(data);
    }
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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.existing != null ? "Editar Meta" : "Nova Meta", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                const Text("Aplicar para:", style: TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 6),
                Row(children: [
                  ChoiceChip(
                    label: const Text("Individual"),
                    selected: _scope == "individual",
                    selectedColor: const Color(0xFF7A0BD4),
                    labelStyle: TextStyle(color: _scope == "individual" ? Colors.white : Colors.white70),
                    onSelected: (_) => setState(() => _scope = "individual"),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text("Geral (toda equipe)"),
                    selected: _scope == "geral",
                    selectedColor: Colors.amber,
                    labelStyle: TextStyle(color: _scope == "geral" ? Colors.black : Colors.white70),
                    onSelected: (_) => setState(() => _scope = "geral"),
                  ),
                ]),
                if (_scope == "individual") ...[
                  const SizedBox(height: 8),
                  DropdownButton<String>(
                    value: _selectedRecruiterId,
                    hint: const Text("Recrutador", style: TextStyle(color: Colors.white54)),
                    dropdownColor: const Color(0xFF1A1A1A),
                    style: const TextStyle(color: Colors.white),
                    items: _recruiters.map((r) => DropdownMenuItem(value: r["id"] as String, child: Text(r["login_email"] as String))).toList(),
                    onChanged: (v) => setState(() => _selectedRecruiterId = v),
                  ),
                ],
                const SizedBox(height: 8),
                DropdownButton<String>(
                  value: _metric,
                  dropdownColor: const Color(0xFF1A1A1A),
                  style: const TextStyle(color: Colors.white),
                  items: _metrics.map((m) => DropdownMenuItem(value: m.$1, child: Text(m.$2))).toList(),
                  onChanged: (v) => setState(() => _metric = v!),
                ),
                const SizedBox(height: 8),
                TextField(controller: _valueController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Valor da meta", labelStyle: TextStyle(color: Colors.white54))),
                const SizedBox(height: 8),
                DropdownButton<String>(
                  value: _periodType,
                  dropdownColor: const Color(0xFF1A1A1A),
                  style: const TextStyle(color: Colors.white),
                  items: const [
                    DropdownMenuItem(value: "diario", child: Text("Diario")),
                    DropdownMenuItem(value: "semanal", child: Text("Semanal")),
                    DropdownMenuItem(value: "mensal", child: Text("Mensal")),
                  ],
                  onChanged: (v) => setState(() => _periodType = v!),
                ),
                const SizedBox(height: 8),
                const Text("Periodo (escolha as datas exatas, pode ser qualquer intervalo)", style: TextStyle(color: Colors.white38, fontSize: 11)),
                Row(children: [
                  Expanded(child: OutlinedButton(onPressed: () => _pickDate(true), child: Text("Inicio: " + _startsAt.toIso8601String().substring(0, 10)))),
                  const SizedBox(width: 8),
                  Expanded(child: OutlinedButton(onPressed: () => _pickDate(false), child: Text("Fim: " + _endsAt.toIso8601String().substring(0, 10)))),
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
      ),
    );
  }
}


class _BulkTargetFormDialog extends StatefulWidget {
  const _BulkTargetFormDialog();

  @override
  State<_BulkTargetFormDialog> createState() => _BulkTargetFormDialogState();
}

class _BulkTargetFormDialogState extends State<_BulkTargetFormDialog> {
  List<Map<String, dynamic>> _recruiters = [];
  final Set<String> _selectedRecruiterIds = {};
  bool _saving = false;

  final Map<String, bool> _enabled = {
    "leads_diario": false,
    "leads_semanal": false,
    "leads_mensal": false,
    "agenciamentos_diario": false,
    "agenciamentos_semanal": false,
    "agenciamentos_mensal": false,
  };
  final Map<String, TextEditingController> _valueControllers = {
    "leads_diario": TextEditingController(),
    "leads_semanal": TextEditingController(),
    "leads_mensal": TextEditingController(),
    "agenciamentos_diario": TextEditingController(),
    "agenciamentos_semanal": TextEditingController(),
    "agenciamentos_mensal": TextEditingController(),
  };

  static const _presetLabels = {
    "leads_diario": "Leads por dia",
    "leads_semanal": "Leads por semana",
    "leads_mensal": "Leads por mes",
    "agenciamentos_diario": "Agenciamentos por dia",
    "agenciamentos_semanal": "Agenciamentos por semana",
    "agenciamentos_mensal": "Agenciamentos por mes",
  };

  @override
  void initState() {
    super.initState();
    _loadRecruiters();
  }

  Future<void> _loadRecruiters() async {
    final client = Supabase.instance.client;
    final leads = await client.from("leads").select("recruiter_id");
    final ids = (leads as List).map((l) => l["recruiter_id"] as String).toSet();
    if (ids.isEmpty) return;
    final rows = await client.from("managers").select("id, login_email").inFilter("id", ids.toList());
    setState(() => _recruiters = (rows as List).cast<Map<String, dynamic>>());
  }

  void _toggleAll(bool select) {
    setState(() {
      _selectedRecruiterIds.clear();
      if (select) _selectedRecruiterIds.addAll(_recruiters.map((r) => r["id"] as String));
    });
  }

  (DateTime, DateTime) _periodFor(String periodType) {
    final now = DateTime.now();
    if (periodType == "diario") {
      final today = DateTime(now.year, now.month, now.day);
      return (today, today);
    }
    if (periodType == "semanal") {
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final sunday = monday.add(const Duration(days: 6));
      return (DateTime(monday.year, monday.month, monday.day), DateTime(sunday.year, sunday.month, sunday.day));
    }
    return (DateTime(now.year, now.month, 1), DateTime(now.year, now.month + 1, 0));
  }

  Future<void> _save() async {
    if (_selectedRecruiterIds.isEmpty) return;
    final activePresets = _enabled.entries.where((e) => e.value).toList();
    if (activePresets.isEmpty) return;

    setState(() => _saving = true);
    final client = Supabase.instance.client;
    final createdBy = client.auth.currentUser!.id;

    for (final recruiterId in _selectedRecruiterIds) {
      for (final preset in activePresets) {
        final value = double.tryParse(_valueControllers[preset.key]!.text) ?? 0;
        if (value <= 0) continue;
        final isAgenciamento = preset.key.startsWith("agenciamentos");
        final periodType = preset.key.endsWith("diario") ? "diario" : preset.key.endsWith("semanal") ? "semanal" : "mensal";
        final period = _periodFor(periodType);

        await client.from("recruiter_targets").insert({
          "recruiter_id": recruiterId,
          "metric": isAgenciamento ? "agenciamentos" : "leads",
          "target_value": value,
          "period_type": periodType,
          "starts_at": period.$1.toIso8601String().substring(0, 10),
          "ends_at": period.$2.toIso8601String().substring(0, 10),
          "created_by": createdBy,
        });
      }
    }

    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Cadastro em Massa de Metas", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text("Marque os recrutadores e as metas que quer criar de uma vez. Os periodos (dia/semana/mes) usam a data de hoje automaticamente.",
                    style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic)),
                const SizedBox(height: 16),
                Row(children: [
                  const Text("Recrutadores:", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  const Spacer(),
                  TextButton(onPressed: () => _toggleAll(true), child: const Text("Selecionar todos")),
                  TextButton(onPressed: () => _toggleAll(false), child: const Text("Limpar")),
                ]),
                ..._recruiters.map((r) {
                  final id = r["id"] as String;
                  return CheckboxListTile(
                    value: _selectedRecruiterIds.contains(id),
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        _selectedRecruiterIds.add(id);
                      } else {
                        _selectedRecruiterIds.remove(id);
                      }
                    }),
                    title: Text(r["login_email"] as String, style: const TextStyle(color: Colors.white, fontSize: 13)),
                    activeColor: const Color(0xFF7A0BD4),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  );
                }),
                const SizedBox(height: 16),
                const Text("Metas a cadastrar:", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ..._presetLabels.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Checkbox(
                        value: _enabled[entry.key],
                        onChanged: (v) => setState(() => _enabled[entry.key] = v ?? false),
                        activeColor: const Color(0xFF7A0BD4),
                      ),
                      SizedBox(width: 160, child: Text(entry.value, style: const TextStyle(color: Colors.white, fontSize: 13))),
                      Expanded(
                        child: TextField(
                          controller: _valueControllers[entry.key],
                          enabled: _enabled[entry.key] == true,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: const InputDecoration(labelText: "Quantidade", labelStyle: TextStyle(color: Colors.white54, fontSize: 12)),
                        ),
                      ),
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
                    child: Text(_saving ? "Salvando..." : "Criar Metas"),
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

