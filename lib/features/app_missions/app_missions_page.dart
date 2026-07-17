import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";

const _categories = [
  ("mes", "Mes"),
  ("semanal", "Semanal"),
  ("tiktok_streamers", "TikTok Streamers"),
  ("tiktok_agencia", "TikTok Agencia"),
];

const _rewardTypes = ["Produto", "Presente em live", "Kit Mduck", "Placa de Merito", "Outros"];

class AppMissionsPage extends StatefulWidget {
  const AppMissionsPage({super.key});

  @override
  State<AppMissionsPage> createState() => _AppMissionsPageState();
}

class _AppMissionsPageState extends State<AppMissionsPage> {
  String _tab = "cadastrar";

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
                label: const Text("Cadastrar Missoes"),
                selected: _tab == "cadastrar",
                selectedColor: const Color(0xFF7A0BD4),
                labelStyle: TextStyle(color: _tab == "cadastrar" ? Colors.white : Colors.white70),
                onSelected: (_) => setState(() => _tab = "cadastrar"),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text("Status Missoes"),
                selected: _tab == "status",
                selectedColor: const Color(0xFF7A0BD4),
                labelStyle: TextStyle(color: _tab == "status" ? Colors.white : Colors.white70),
                onSelected: (_) => setState(() => _tab = "status"),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(child: _tab == "cadastrar" ? const _CadastrarMissaoTab() : const _StatusMissoesTab()),
        ],
      ),
    );
  }
}

class _CadastrarMissaoTab extends StatefulWidget {
  const _CadastrarMissaoTab();

  @override
  State<_CadastrarMissaoTab> createState() => _CadastrarMissaoTabState();
}

class _CadastrarMissaoTabState extends State<_CadastrarMissaoTab> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _daysController = TextEditingController();
  final _hoursController = TextEditingController();
  final _diamondsController = TextEditingController();
  final _rewardDetailController = TextEditingController();
  final _rewardValueController = TextEditingController();

  String _category = "mes";
  String _targetType = "all";
  String? _targetId;
  String _rewardType = "Produto";
  bool _saving = false;
  String? _message;

  List<Map<String, dynamic>> _streamers = [];
  List<Map<String, dynamic>> _groups = [];
  List<Map<String, dynamic>> _categoriesList = [];

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    final client = Supabase.instance.client;
    final streamers = await client.from("profiles").select("id, display_name").eq("is_active", true).order("display_name");
    final groups = await client.from("groups").select("id, name").order("name");
    final categories = await client.from("streamer_categories").select("id, name").order("name");
    setState(() {
      _streamers = (streamers as List).cast<Map<String, dynamic>>();
      _groups = (groups as List).cast<Map<String, dynamic>>();
      _categoriesList = (categories as List).cast<Map<String, dynamic>>();
    });
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

      final mission = await client
          .from("missions")
          .insert({
            "agency_id": manager["agency_id"],
            "type": "event",
            "title": _titleController.text.trim(),
            "description": _descriptionController.text.trim(),
            "criteria": {},
            "category": _category,
            "target_type": _targetType,
            "target_id": _targetType == "all" ? null : _targetId,
            "requirement_days": int.tryParse(_daysController.text),
            "requirement_hours": double.tryParse(_hoursController.text),
            "requirement_diamonds": int.tryParse(_diamondsController.text),
            "reward_type": _rewardType,
            "reward_detail": _rewardDetailController.text.trim(),
            "reward_value": double.tryParse(_rewardValueController.text) ?? 0,
          })
          .select()
          .single();

      final missionId = mission["id"];

      List<String> targetStreamerIds = [];
      if (_targetType == "all") {
        final rows = await client.from("profiles").select("id").eq("is_active", true);
        targetStreamerIds = (rows as List).map((r) => r["id"] as String).toList();
      } else if (_targetType == "individual" && _targetId != null) {
        targetStreamerIds = [_targetId!];
      } else if (_targetType == "group" && _targetId != null) {
        final rows = await client.from("group_members").select("streamer_id").eq("group_id", _targetId!);
        targetStreamerIds = (rows as List).map((r) => r["streamer_id"] as String).toList();
      } else if (_targetType == "category" && _targetId != null) {
        final rows = await client.from("profiles").select("id").eq("category_id", _targetId!).eq("is_active", true);
        targetStreamerIds = (rows as List).map((r) => r["id"] as String).toList();
      }

      for (final streamerId in targetStreamerIds) {
        await client.from("streamer_missions").insert({
          "streamer_id": streamerId,
          "mission_id": missionId,
          "progress": {},
        });
      }

      setState(() {
        _message = "Missao criada e atribuida a " + targetStreamerIds.length.toString() + " streamer(s).";
        _titleController.clear();
        _descriptionController.clear();
        _daysController.clear();
        _hoursController.clear();
        _diamondsController.clear();
        _rewardDetailController.clear();
        _rewardValueController.clear();
      });
    } catch (e) {
      setState(() => _message = "Erro: " + e.toString());
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            TextField(controller: _descriptionController, maxLines: 3, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Descricao", labelStyle: TextStyle(color: Colors.white54))),
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
              ],
              onChanged: (v) => setState(() {
                _targetType = v!;
                _targetId = null;
              }),
            ),
            if (_targetType == "individual")
              DropdownButton<String>(
                value: _targetId,
                hint: const Text("Escolha o streamer", style: TextStyle(color: Colors.white54)),
                dropdownColor: const Color(0xFF1A1A1A),
                style: const TextStyle(color: Colors.white),
                items: _streamers.map((s) => DropdownMenuItem(value: s["id"] as String, child: Text(s["display_name"] as String))).toList(),
                onChanged: (v) => setState(() => _targetId = v),
              ),
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
            TextField(controller: _rewardDetailController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Detalhe da premiacao (editavel)", labelStyle: TextStyle(color: Colors.white54))),
            const SizedBox(height: 8),
            TextField(controller: _rewardValueController, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Valor estimado (R\$)", labelStyle: TextStyle(color: Colors.white54))),
            const SizedBox(height: 20),
            if (_message != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_message!, style: const TextStyle(color: Colors.greenAccent))),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
              child: Text(_saving ? "Salvando..." : "Criar Missao"),
            ),
          ],
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
    final missions = await client.from("missions").select("id, title, mission_status").eq("category", _category);
    final result = <Map<String, dynamic>>[];
    for (final m in (missions as List)) {
      final assignments = await client
          .from("streamer_missions")
          .select("completed_at, profiles(display_name)")
          .eq("mission_id", m["id"]);
      for (final a in (assignments as List)) {
        String status;
        if (m["mission_status"] == "cancelada") {
          status = "cancelada";
        } else if (a["completed_at"] != null) {
          status = "concluida";
        } else {
          status = "ativa";
        }
        final profileData = a["profiles"];
        final name = profileData is Map ? profileData["display_name"] as String? : "-";
        result.add({"mission": m["title"], "streamer": name ?? "-", "status": status});
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
                      : row["status"] == "cancelada"
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

