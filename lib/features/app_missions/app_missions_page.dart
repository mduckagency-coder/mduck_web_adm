import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "reward_images_page.dart";

const _categories = [
  ("mes", "Mes"),
  ("semanal", "Semanal"),
  ("tiktok_streamers", "TikTok Streamers"),
  ("tiktok_agencia", "TikTok Agencia"),
];

const _rewardTypes = ["Produto", "Presente em live", "Kit Mduck", "Placa de Merito", "Outros"];

const _tiers = [
  ("10k", "Ate 10k", 0, 10000),
  ("20k", "10k a 20k", 10001, 20000),
  ("40k", "20k a 40k", 20001, 40000),
  ("79k", "40k a 79k", 40001, 79000),
  ("topducker", "Top Duckers (80k-149k)", 80000, 149999),
  ("elite", "Elite (250k+)", 250000, 999999999),
];

(String, Color) _computeMissionStatus(Map<String, dynamic> m) {
  if (m["mission_status"] == "cancelada") return ("Cancelada", Colors.redAccent);
  final now = DateTime.now();
  final start = m["starts_at"] != null ? DateTime.parse(m["starts_at"]) : null;
  final end = m["ends_at"] != null ? DateTime.parse(m["ends_at"]) : null;
  if (start == null) return ("A acontecer", Colors.blueAccent);
  if (now.isBefore(start)) return ("A acontecer", Colors.blueAccent);
  if (end != null && now.isAfter(end)) return ("Encerrada", Colors.greenAccent);
  return ("Em andamento", Colors.amber);
}

String _monthLabel(Map<String, dynamic> m) {
  if (m["starts_at"] == null) return "Sem data";
  final start = DateTime.parse(m["starts_at"]);
  final now = DateTime.now();
  final diff = (start.year - now.year) * 12 + (start.month - now.month);
  if (diff == 0) return "Este mes";
  if (diff == -1) return "Mes passado";
  if (diff == 1) return "Proximo mes";
  return start.month.toString().padLeft(2, "0") + "/" + start.year.toString();
}

class AppMissionsPage extends StatefulWidget {
  const AppMissionsPage({super.key});

  @override
  State<AppMissionsPage> createState() => _AppMissionsPageState();
}

class _AppMissionsPageState extends State<AppMissionsPage> {
  String _tab = "missoes";

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Missoes APP MDuck Lives", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 16),
          Row(
            children: [
              ChoiceChip(
                label: const Text("Missoes"),
                selected: _tab == "missoes",
                selectedColor: const Color(0xFF7A0BD4),
                labelStyle: TextStyle(color: _tab == "missoes" ? Colors.white : Colors.white70),
                onSelected: (_) => setState(() => _tab = "missoes"),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text("Status Missoes"),
                selected: _tab == "status",
                selectedColor: const Color(0xFF7A0BD4),
                labelStyle: TextStyle(color: _tab == "status" ? Colors.white : Colors.white70),
                onSelected: (_) => setState(() => _tab = "status"),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text("Imagens de Premiacao"),
                selected: _tab == "imagens",
                selectedColor: const Color(0xFF7A0BD4),
                labelStyle: TextStyle(color: _tab == "imagens" ? Colors.white : Colors.white70),
                onSelected: (_) => setState(() => _tab = "imagens"),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _tab == "missoes"
                ? const _MissoesListTab()
                : _tab == "status"
                    ? const _StatusMissoesTab()
                    : const RewardImagesPage(),
          ),
        ],
      ),
    );
  }
}

class _MissoesListTab extends StatefulWidget {
  const _MissoesListTab();

  @override
  State<_MissoesListTab> createState() => _MissoesListTabState();
}

class _MissoesListTabState extends State<_MissoesListTab> {
  String? _categoryFilter;
  String _monthFilter = "todos";
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final client = Supabase.instance.client;
    var query = client.from("missions").select();
    if (_categoryFilter != null) query = query.eq("category", _categoryFilter as Object);
    final rows = await query.order("created_at", ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  void _reload() => setState(() => _future = _load());

  void _openCreate() {
    showDialog(context: context, builder: (context) => const _MissionFormDialog()).then((saved) {
      if (saved == true) _reload();
    });
  }

  List<Map<String, dynamic>> _filterByMonth(List<Map<String, dynamic>> list) {
    if (_monthFilter == "todos") return list;
    return list.where((m) {
      final label = _monthLabel(m);
      if (_monthFilter == "este") return label == "Este mes";
      if (_monthFilter == "passado") return label == "Mes passado";
      if (_monthFilter == "proximo") return label == "Proximo mes";
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(icon: const Icon(Icons.refresh, color: Colors.white70), onPressed: _reload),
            const Spacer(),
            FloatingActionButton.small(
              onPressed: _openCreate,
              backgroundColor: const Color(0xFF7A0BD4),
              foregroundColor: Colors.white,
              tooltip: "Nova missao",
              child: const Icon(Icons.add),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text("Todas categorias"),
              selected: _categoryFilter == null,
              selectedColor: Colors.white24,
              onSelected: (_) => setState(() {
                _categoryFilter = null;
                _future = _load();
              }),
            ),
            ..._categories.map((c) {
              final selected = _categoryFilter == c.$1;
              return ChoiceChip(
                label: Text(c.$2),
                selected: selected,
                selectedColor: const Color(0xFF7A0BD4),
                labelStyle: TextStyle(color: selected ? Colors.white : Colors.white70),
                onSelected: (_) => setState(() {
                  _categoryFilter = c.$1;
                  _future = _load();
                }),
              );
            }),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ("todos", "Todos os meses"),
            ("passado", "Mes passado"),
            ("este", "Este mes"),
            ("proximo", "Proximo mes"),
          ].map((m) {
            final selected = _monthFilter == m.$1;
            return ChoiceChip(
              label: Text(m.$2, style: const TextStyle(fontSize: 12)),
              selected: selected,
              selectedColor: Colors.white24,
              onSelected: (_) => setState(() => _monthFilter = m.$1),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final missions = _filterByMonth(snapshot.data!);
              if (missions.isEmpty) {
                return const Center(child: Text("Nenhuma missao encontrada.", style: TextStyle(color: Colors.white54)));
              }
              return ListView.builder(
                itemCount: missions.length,
                itemBuilder: (context, index) {
                  final m = missions[index];
                  final status = _computeMissionStatus(m);
                  final categoryLabel = _categories.firstWhere((c) => c.$1 == m["category"], orElse: () => _categories[0]).$2;
                  return Card(
                    color: Colors.white.withOpacity(0.05),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text(m["title"] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      subtitle: Text(categoryLabel + " - " + _monthLabel(m), style: const TextStyle(color: Colors.white54)),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(border: Border.all(color: status.$2), borderRadius: BorderRadius.circular(8)),
                        child: Text(status.$1, style: TextStyle(color: status.$2, fontSize: 12)),
                      ),
                      onTap: () {
                        showDialog(context: context, builder: (context) => _MissionFormDialog(existing: m)).then((saved) {
                          if (saved == true) _reload();
                        });
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
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
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _daysController = TextEditingController();
  final _hoursController = TextEditingController();
  final _diamondsController = TextEditingController();
  final _rewardDetailController = TextEditingController();
  final _rewardValueController = TextEditingController();
  final _streamerSearchController = TextEditingController();
  final _streamerIdController = TextEditingController();

  String _category = "mes";
  String _targetType = "all";
  String? _targetId;
  String _tierPeriod = "atual";
  String _tierKey = "10k";
  String _rewardType = "Produto";
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isCancelled = false;
  bool _saving = false;
  String? _message;

  List<Map<String, dynamic>> _streamers = [];
  List<Map<String, dynamic>> _groups = [];
  List<Map<String, dynamic>> _categoriesList = [];
  List<Map<String, dynamic>> _rewardImages = [];
  String? _rewardImageId;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _loadOptions();
    final e = widget.existing;
    if (e != null) {
      _titleController.text = e["title"] ?? "";
      _descriptionController.text = e["description"] ?? "";
      _category = e["category"] ?? "mes";
      _targetType = e["target_type"] ?? "all";
      _targetId = e["target_id"];
      _daysController.text = (e["requirement_days"] ?? "").toString();
      _hoursController.text = (e["requirement_hours"] ?? "").toString();
      _diamondsController.text = (e["requirement_diamonds"] ?? "").toString();
      _rewardType = e["reward_type"] ?? "Produto";
      _rewardDetailController.text = e["reward_detail"] ?? "";
      _rewardValueController.text = (e["reward_value"] ?? 0).toString();
      _isCancelled = e["mission_status"] == "cancelada";
      if (e["starts_at"] != null) _startDate = DateTime.tryParse(e["starts_at"]);
      if (e["ends_at"] != null) _endDate = DateTime.tryParse(e["ends_at"]);
    }
  }

  Future<void> _loadOptions() async {
    final client = Supabase.instance.client;
    final streamers = await client.from("profiles").select("id, display_name, tiktok_creator_id").eq("is_active", true).order("display_name");
    final groups = await client.from("groups").select("id, name").order("name");
    final categories = await client.from("streamer_categories").select("id, name").order("name");
    final rewardImages = await client.from("reward_images").select().order("label");
    setState(() {
      _streamers = (streamers as List).cast<Map<String, dynamic>>();
      _groups = (groups as List).cast<Map<String, dynamic>>();
      _categoriesList = (categories as List).cast<Map<String, dynamic>>();
      _rewardImages = (rewardImages as List).cast<Map<String, dynamic>>();
      if (widget.existing != null && widget.existing!["reward_image_url"] != null) {
        final match = _rewardImages.where((r) => r["image_url"] == widget.existing!["reward_image_url"]);
        if (match.isNotEmpty) _rewardImageId = match.first["id"] as String;
      }
    });
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _startDate : _endDate) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<List<String>> _resolveTargets() async {
    final client = Supabase.instance.client;
    if (_targetType == "all") {
      final rows = await client.from("profiles").select("id").eq("is_active", true);
      return (rows as List).map((r) => r["id"] as String).toList();
    }
    if (_targetType == "individual") {
      if (_streamerIdController.text.trim().isNotEmpty) {
        final row = await client.from("profiles").select("id").eq("tiktok_creator_id", _streamerIdController.text.trim()).maybeSingle();
        return row != null ? [row["id"] as String] : [];
      }
      return _targetId != null ? [_targetId!] : [];
    }
    if (_targetType == "group" && _targetId != null) {
      final rows = await client.from("group_members").select("streamer_id").eq("group_id", _targetId!);
      return (rows as List).map((r) => r["streamer_id"] as String).toList();
    }
    if (_targetType == "category" && _targetId != null) {
      final rows = await client.from("profiles").select("id").eq("category_id", _targetId!).eq("is_active", true);
      return (rows as List).map((r) => r["id"] as String).toList();
    }
    if (_targetType == "tier") {
      final tier = _tiers.firstWhere((t) => t.$1 == _tierKey);
      if (_tierPeriod == "atual") {
        final rows = await client.from("profiles").select("id, streamer_stats(diamonds)").eq("is_active", true);
        return (rows as List).where((r) {
          final statsData = r["streamer_stats"];
          int diamonds = 0;
          if (statsData is List && statsData.isNotEmpty) diamonds = statsData.first["diamonds"] as int? ?? 0;
          else if (statsData is Map) diamonds = statsData["diamonds"] as int? ?? 0;
          return diamonds >= tier.$3 && diamonds <= tier.$4;
        }).map((r) => r["id"] as String).toList();
      } else {
        final monthlyRows = await client.from("monthly_stats").select("streamer_id, period_key, diamonds").order("period_key", ascending: false);
        final lastMap = <String, int>{};
        for (final row in (monthlyRows as List)) {
          final sid = row["streamer_id"] as String;
          if (!lastMap.containsKey(sid)) lastMap[sid] = row["diamonds"] as int? ?? 0;
        }
        return lastMap.entries.where((e) => e.value >= tier.$3 && e.value <= tier.$4).map((e) => e.key).toList();
      }
    }
    return [];
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) return;
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      final client = Supabase.instance.client;
      final managerId = client.auth.currentUser!.id;
      final manager = await client.from("managers").select("agency_id").eq("id", managerId).single();

      final data = {
        "agency_id": manager["agency_id"],
        "type": "event",
        "title": _titleController.text.trim(),
        "description": _descriptionController.text.trim(),
        "criteria": {},
        "category": _category,
        "target_type": _targetType,
        "target_id": (_targetType == "all" || _targetType == "tier") ? null : _targetId,
        "starts_at": _startDate?.toIso8601String(),
        "ends_at": _endDate?.toIso8601String(),
        "requirement_days": int.tryParse(_daysController.text),
        "requirement_hours": double.tryParse(_hoursController.text),
        "requirement_diamonds": int.tryParse(_diamondsController.text),
        "reward_type": _rewardType,
        "reward_detail": _rewardDetailController.text.trim(),
        "reward_value": double.tryParse(_rewardValueController.text) ?? 0,
        "reward_image_url": _rewardImageId != null ? _rewardImages.firstWhere((r) => r["id"] == _rewardImageId)["image_url"] : null,
        "mission_status": _isCancelled ? "cancelada" : "ativa",
      };

      String missionId;
      if (_isEditing) {
        missionId = widget.existing!["id"];
        await client.from("missions").update(data).eq("id", missionId);
      } else {
        final mission = await client.from("missions").insert(data).select().single();
        missionId = mission["id"];
      }

      final targetIds = await _resolveTargets();
      final existingAssignments = await client.from("streamer_missions").select("streamer_id").eq("mission_id", missionId);
      final existingIds = (existingAssignments as List).map((r) => r["streamer_id"] as String).toSet();

      for (final streamerId in targetIds) {
        if (existingIds.contains(streamerId)) continue;
        await client.from("streamer_missions").insert({"streamer_id": streamerId, "mission_id": missionId, "progress": {}});
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _message = "Erro: " + e.toString());
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 780),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_isEditing ? "Editar missao" : "Nova missao", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                const Text("Categoria", style: TextStyle(color: Colors.white54)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: _categories.map((c) {
                    final selected = _category == c.$1;
                    return ChoiceChip(
                      label: Text(c.$2),
                      selected: selected,
                      selectedColor: const Color(0xFF7A0BD4),
                      labelStyle: TextStyle(color: selected ? Colors.white : Colors.white70),
                      onSelected: (_) => setState(() => _category = c.$1),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                TextField(controller: _titleController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Titulo", labelStyle: TextStyle(color: Colors.white54))),
                const SizedBox(height: 8),
                TextField(controller: _descriptionController, maxLines: 2, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Descricao", labelStyle: TextStyle(color: Colors.white54))),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: OutlinedButton(onPressed: () => _pickDate(true), child: Text(_startDate != null ? "Inicio: " + _startDate!.toIso8601String().substring(0, 10) : "Escolher inicio"))),
                    const SizedBox(width: 8),
                    Expanded(child: OutlinedButton(onPressed: () => _pickDate(false), child: Text(_endDate != null ? "Fim: " + _endDate!.toIso8601String().substring(0, 10) : "Escolher fim"))),
                  ],
                ),
                const SizedBox(height: 16),
                const Text("Alvo", style: TextStyle(color: Colors.white54)),
                const SizedBox(height: 6),
                DropdownButton<String>(
                  value: _targetType,
                  dropdownColor: const Color(0xFF1A1A1A),
                  style: const TextStyle(color: Colors.white),
                  items: const [
                    DropdownMenuItem(value: "all", child: Text("Todos os streamers")),
                    DropdownMenuItem(value: "individual", child: Text("Streamer individual")),
                    DropdownMenuItem(value: "group", child: Text("Grupo")),
                    DropdownMenuItem(value: "category", child: Text("Categoria")),
                    DropdownMenuItem(value: "tier", child: Text("Faixa de diamantes")),
                  ],
                  onChanged: (v) => setState(() {
                    _targetType = v!;
                    _targetId = null;
                  }),
                ),
                if (_targetType == "individual") ...[
                  TextField(
                    controller: _streamerSearchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: "Buscar streamer por nick", labelStyle: TextStyle(color: Colors.white54)),
                    onChanged: (_) => setState(() {}),
                  ),
                  if (_streamerSearchController.text.trim().isNotEmpty)
                    Container(
                      constraints: const BoxConstraints(maxHeight: 180),
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
                      child: Builder(builder: (context) {
                        final query = _streamerSearchController.text.trim().toLowerCase();
                        final matches = _streamers.where((s) => (s["display_name"] as String).toLowerCase().contains(query)).take(20).toList();
                        if (matches.isEmpty) {
                          return const Padding(padding: EdgeInsets.all(12), child: Text("Nenhum streamer encontrado.", style: TextStyle(color: Colors.white54, fontSize: 12)));
                        }
                        return ListView(
                          shrinkWrap: true,
                          children: matches.map((s) {
                            final selected = _targetId == s["id"];
                            return ListTile(
                              dense: true,
                              selected: selected,
                              selectedTileColor: const Color(0xFF7A0BD4).withOpacity(0.3),
                              title: Text(s["display_name"] as String, style: const TextStyle(color: Colors.white, fontSize: 13)),
                              subtitle: s["tiktok_creator_id"] != null ? Text(s["tiktok_creator_id"] as String, style: const TextStyle(color: Colors.white38, fontSize: 11)) : null,
                              onTap: () => setState(() {
                                _targetId = s["id"] as String;
                                _streamerSearchController.text = s["display_name"] as String;
                              }),
                            );
                          }).toList(),
                        );
                      }),
                    ),
                  if (_targetId != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text("Selecionado: " + (_streamers.firstWhere((s) => s["id"] == _targetId, orElse: () => {"display_name": "?"})["display_name"] as String),
                          style: const TextStyle(color: Colors.greenAccent, fontSize: 12)),
                    ),
                  const SizedBox(height: 8),
                  const Text("ou digite o ID do TikTok diretamente:", style: TextStyle(color: Colors.white38, fontSize: 11)),
                  TextField(controller: _streamerIdController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "ID do TikTok", labelStyle: TextStyle(color: Colors.white54))),
                ],
                if (_targetType == "group")
                  DropdownButton<String>(
                    value: _targetId,
                    hint: const Text("Escolha o grupo", style: TextStyle(color: Colors.white54)),
                    dropdownColor: const Color(0xFF1A1A1A),
                    style: const TextStyle(color: Colors.white),
                    items: _groups.map((g) => DropdownMenuItem(value: g["id"] as String, child: Text(g["name"] as String))).toList(),
                    onChanged: (v) => setState(() => _targetId = v),
                  ),
                if (_targetType == "category")
                  DropdownButton<String>(
                    value: _targetId,
                    hint: const Text("Escolha a categoria", style: TextStyle(color: Colors.white54)),
                    dropdownColor: const Color(0xFF1A1A1A),
                    style: const TextStyle(color: Colors.white),
                    items: _categoriesList.map((c) => DropdownMenuItem(value: c["id"] as String, child: Text(c["name"] as String))).toList(),
                    onChanged: (v) => setState(() => _targetId = v),
                  ),
                if (_targetType == "tier") ...[
                  Row(
                    children: [
                      const Text("Periodo: ", style: TextStyle(color: Colors.white70)),
                      DropdownButton<String>(
                        value: _tierPeriod,
                        dropdownColor: const Color(0xFF1A1A1A),
                        style: const TextStyle(color: Colors.white),
                        items: const [
                          DropdownMenuItem(value: "atual", child: Text("Mes atual")),
                          DropdownMenuItem(value: "passado", child: Text("Mes passado (fechado)")),
                        ],
                        onChanged: (v) => setState(() => _tierPeriod = v!),
                      ),
                    ],
                  ),
                  DropdownButton<String>(
                    value: _tierKey,
                    dropdownColor: const Color(0xFF1A1A1A),
                    style: const TextStyle(color: Colors.white),
                    items: _tiers.map((t) => DropdownMenuItem(value: t.$1, child: Text(t.$2))).toList(),
                    onChanged: (v) => setState(() => _tierKey = v!),
                  ),
                ],
                const Text("Editar e salvar de novo atualiza o alvo (adiciona quem faltar, sem remover quem ja tem progresso).",
                    style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic)),
                const SizedBox(height: 16),
                const Text("Meta para concluir", style: TextStyle(color: Colors.white54)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(child: TextField(controller: _daysController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Dias", labelStyle: TextStyle(color: Colors.white54)))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: _hoursController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Horas", labelStyle: TextStyle(color: Colors.white54)))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: _diamondsController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Diamantes", labelStyle: TextStyle(color: Colors.white54)))),
                  ],
                ),
                const SizedBox(height: 16),
                const Text("Premiacao", style: TextStyle(color: Colors.white54)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: _rewardTypes.map((r) {
                    final selected = _rewardType == r;
                    return ChoiceChip(
                      label: Text(r),
                      selected: selected,
                      selectedColor: const Color(0xFF7A0BD4),
                      labelStyle: TextStyle(color: selected ? Colors.white : Colors.white70),
                      onSelected: (_) => setState(() => _rewardType = r),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                TextField(controller: _rewardDetailController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Detalhe da premiacao (o streamer ve isso)", labelStyle: TextStyle(color: Colors.white54))),
                const SizedBox(height: 8),
                TextField(controller: _rewardValueController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Valor estimado R\$ (so aparece no painel/financeiro)", labelStyle: TextStyle(color: Colors.white54))),
                const SizedBox(height: 8),
                DropdownButton<String?>(
                  value: _rewardImageId,
                  hint: const Text("Imagem da premiacao (opcional)", style: TextStyle(color: Colors.white54)),
                  dropdownColor: const Color(0xFF1A1A1A),
                  style: const TextStyle(color: Colors.white),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text("Sem imagem")),
                    ..._rewardImages.map((r) => DropdownMenuItem<String?>(value: r["id"] as String, child: Text(r["label"] as String))),
                  ],
                  onChanged: (v) => setState(() => _rewardImageId = v),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  value: _isCancelled,
                  onChanged: (v) => setState(() => _isCancelled = v ?? false),
                  title: const Text("Cancelar esta missao", style: TextStyle(color: Colors.white)),
                  activeColor: Colors.redAccent,
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 12),
                if (_message != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_message!, style: const TextStyle(color: Colors.redAccent))),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancelar")),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
                      child: Text(_saving ? "Salvando..." : "Salvar"),
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

class _StatusMissoesTab extends StatefulWidget {
  const _StatusMissoesTab();

  @override
  State<_StatusMissoesTab> createState() => _StatusMissoesTabState();
}

class _StatusMissoesTabState extends State<_StatusMissoesTab> {
  String _category = "mes";
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final client = Supabase.instance.client;
    final missions = await client.from("missions").select("id, title, mission_status, starts_at, ends_at").eq("category", _category);
    final result = <Map<String, dynamic>>[];
    for (final m in (missions as List)) {
      final assignments = await client.from("streamer_missions").select("completed_at, profiles(display_name)").eq("mission_id", m["id"]);
      final status = _computeMissionStatus(m);
      for (final a in (assignments as List)) {
        String streamerStatus;
        if (status.$1 == "Cancelada") {
          streamerStatus = "cancelada";
        } else if (a["completed_at"] != null) {
          streamerStatus = "concluida";
        } else if (status.$1 == "Encerrada") {
          streamerStatus = "expirada";
        } else {
          streamerStatus = "ativa";
        }
        final profileData = a["profiles"];
        final name = profileData is Map ? profileData["display_name"] as String? : "-";
        result.add({"mission": m["title"], "streamer": name ?? "-", "status": streamerStatus});
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: _categories.map((c) {
            final selected = _category == c.$1;
            return ChoiceChip(
              label: Text(c.$2),
              selected: selected,
              selectedColor: const Color(0xFF7A0BD4),
              labelStyle: TextStyle(color: selected ? Colors.white : Colors.white70),
              onSelected: (_) => setState(() {
                _category = c.$1;
                _future = _load();
              }),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              if (snapshot.data!.isEmpty) {
                return const Center(child: Text("Nenhuma missao/atribuicao nessa categoria ainda.", style: TextStyle(color: Colors.white54)));
              }
              return ListView.builder(
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  final row = snapshot.data![index];
                  final color = row["status"] == "concluida"
                      ? Colors.greenAccent
                      : row["status"] == "cancelada" || row["status"] == "expirada"
                          ? Colors.redAccent
                          : Colors.amber;
                  return ListTile(
                    dense: true,
                    title: Text(row["streamer"] as String, style: const TextStyle(color: Colors.white)),
                    subtitle: Text(row["mission"] as String, style: const TextStyle(color: Colors.white54)),
                    trailing: Text(row["status"] as String, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}


