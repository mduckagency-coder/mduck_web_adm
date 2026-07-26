import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "onboarding_phase_service.dart";

Color _hexToColor(String hex) {
  final cleaned = hex.replaceFirst("#", "");
  return Color(int.parse("FF" + cleaned, radix: 16));
}

Color _tryColor(String hex) {
  try {
    return _hexToColor(hex);
  } catch (_) {
    return Colors.white24;
  }
}

/// Engrenagem de configuracao das colunas do Kanban de Onboarding 0-15
/// Dias (streamer_phase_stages): reordenar (drag), renomear, recolorir,
/// ativar/desativar, criar e excluir etapas. So acessivel a
/// coordenador/admin (checagem feita na pagina que abre este dialog).
class OnboardingStageConfigDialog extends StatefulWidget {
  final String agencyId;
  final String phaseKey;
  const OnboardingStageConfigDialog({super.key, required this.agencyId, this.phaseKey = onboardingPhaseKey});

  @override
  State<OnboardingStageConfigDialog> createState() => _OnboardingStageConfigDialogState();
}

class _OnboardingStageConfigDialogState extends State<OnboardingStageConfigDialog> {
  List<Map<String, dynamic>> _stages = [];
  bool _loading = true;
  bool _hasChanges = false;
  bool _saving = false;
  String? _lastMessage;
  bool _lastMessageIsError = false;
  bool _anyChangeMade = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final client = Supabase.instance.client;
    final rows = await client
        .from("streamer_phase_stages")
        .select()
        .eq("agency_id", widget.agencyId)
        .eq("phase_key", widget.phaseKey)
        .order("order_index", ascending: true);
    setState(() {
      _stages = (rows as List).cast<Map<String, dynamic>>();
      _loading = false;
      _hasChanges = false;
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _stages.removeAt(oldIndex);
      _stages.insert(newIndex, item);
      _hasChanges = true;
    });
  }

  Future<void> _saveOrder() async {
    setState(() {
      _saving = true;
      _lastMessage = null;
    });
    final client = Supabase.instance.client;
    try {
      for (var i = 0; i < _stages.length; i++) {
        final id = _stages[i]["id"];
        await client.from("streamer_phase_stages").update({"order_index": i}).eq("id", id);
      }
      _anyChangeMade = true;
      await _load();
      setState(() {
        _saving = false;
        _lastMessage = "Ordem salva com sucesso.";
        _lastMessageIsError = false;
      });
    } catch (e) {
      setState(() {
        _saving = false;
        _lastMessage = "Erro: " + e.toString();
        _lastMessageIsError = true;
      });
    }
  }

  Future<void> _openForm({Map<String, dynamic>? existing}) async {
    final saved = await showDialog<bool>(context: context, builder: (context) => _StageFormDialog(existing: existing, agencyId: widget.agencyId, phaseKey: widget.phaseKey));
    if (saved == true) {
      _anyChangeMade = true;
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 700),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Expanded(child: Text("Configurar colunas do Onboarding", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
                IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => Navigator.of(context).pop(_anyChangeMade)),
              ]),
              const Text("Arraste para reordenar. Toque numa etapa para editar titulo, cor ou ativa-la/desativa-la.", style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic)),
              const SizedBox(height: 12),
              Row(children: [
                if (_hasChanges)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _saveOrder,
                      icon: const Icon(Icons.save, size: 16),
                      label: Text(_saving ? "Salvando..." : "Salvar ordem"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black),
                    ),
                  ),
                ElevatedButton.icon(
                  onPressed: () => _openForm(),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text("Nova Etapa"),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
                ),
              ]),
              if (_lastMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_lastMessage!, style: TextStyle(color: _lastMessageIsError ? Colors.redAccent : Colors.greenAccent, fontSize: 12)),
                ),
              const SizedBox(height: 12),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ReorderableListView.builder(
                        itemCount: _stages.length,
                        onReorder: _onReorder,
                        itemBuilder: (context, index) {
                          final s = _stages[index];
                          final color = _hexToColor(s["color"] as String);
                          final active = s["is_active"] as bool? ?? true;
                          return Card(
                            key: ValueKey(s["id"]),
                            color: Colors.white.withOpacity(0.05),
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              onTap: () => _openForm(existing: s),
                              leading: const Icon(Icons.drag_handle, color: Colors.white38),
                              title: Row(children: [
                                CircleAvatar(radius: 8, backgroundColor: color),
                                const SizedBox(width: 8),
                                Text(s["name"] as String, style: TextStyle(color: active ? Colors.white : Colors.white38, fontWeight: FontWeight.bold)),
                              ]),
                              subtitle: !active ? const Text("INATIVA", style: TextStyle(color: Colors.white54, fontSize: 11)) : null,
                            ),
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

class _StageFormDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final String agencyId;
  final String phaseKey;
  const _StageFormDialog({this.existing, required this.agencyId, this.phaseKey = onboardingPhaseKey});

  @override
  State<_StageFormDialog> createState() => _StageFormDialogState();
}

class _StageFormDialogState extends State<_StageFormDialog> {
  final _nameController = TextEditingController();
  final _colorController = TextEditingController(text: "#7A0BD4");
  final _newItemController = TextEditingController();
  final _newMaterialCheckItemController = TextEditingController();
  bool _isActive = true;
  bool _saving = false;
  String? _errorMessage;

  List<Map<String, dynamic>> _items = [];
  bool _loadingItems = false;
  bool _savingItem = false;

  List<Map<String, dynamic>> _materialCheckItems = [];
  bool _loadingMaterialCheckItems = false;
  bool _savingMaterialCheckItem = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameController.text = e["name"] ?? "";
      _colorController.text = e["color"] ?? "#7A0BD4";
      _isActive = e["is_active"] ?? true;
      _loadItems();
      _loadMaterialCheckItems();
    }
  }

  Future<void> _loadItems() async {
    setState(() => _loadingItems = true);
    final client = Supabase.instance.client;
    final rows = await client
        .from("streamer_phase_checklist_items")
        .select()
        .eq("agency_id", widget.agencyId)
        .eq("phase_key", widget.phaseKey)
        .eq("stage_key", widget.existing!["stage_key"])
        .order("order_index", ascending: true);
    if (mounted) setState(() {
      _items = (rows as List).cast<Map<String, dynamic>>();
      _loadingItems = false;
    });
  }

  Future<void> _loadMaterialCheckItems() async {
    setState(() => _loadingMaterialCheckItems = true);
    final client = Supabase.instance.client;
    final rows = await client
        .from("onboarding_material_check_items")
        .select()
        .eq("agency_id", widget.agencyId)
        .eq("phase_key", widget.phaseKey)
        .eq("stage_key", widget.existing!["stage_key"])
        .order("order_index", ascending: true);
    if (mounted) setState(() {
      _materialCheckItems = (rows as List).cast<Map<String, dynamic>>();
      _loadingMaterialCheckItems = false;
    });
  }

  Future<void> _addMaterialCheckItem() async {
    final label = _newMaterialCheckItemController.text.trim();
    if (label.isEmpty) return;
    setState(() => _savingMaterialCheckItem = true);
    final client = Supabase.instance.client;
    var itemKey = label.toLowerCase().replaceAll(RegExp(r"[^a-z0-9]+"), "_");
    var suffix = 1;
    while (_materialCheckItems.any((it) => it["item_key"] == itemKey)) {
      itemKey = label.toLowerCase().replaceAll(RegExp(r"[^a-z0-9]+"), "_") + "_" + suffix.toString();
      suffix++;
    }
    final nextOrder = _materialCheckItems.isEmpty ? 1 : (_materialCheckItems.map((it) => it["order_index"] as int).reduce((a, b) => a > b ? a : b) + 1);
    await client.from("onboarding_material_check_items").insert({
      "agency_id": widget.agencyId,
      "phase_key": widget.phaseKey,
      "stage_key": widget.existing!["stage_key"],
      "item_key": itemKey,
      "label": label,
      "order_index": nextOrder,
    });
    _newMaterialCheckItemController.clear();
    await _loadMaterialCheckItems();
    if (mounted) setState(() => _savingMaterialCheckItem = false);
  }

  Future<void> _deleteMaterialCheckItem(String id) async {
    await Supabase.instance.client.from("onboarding_material_check_items").delete().eq("id", id);
    await _loadMaterialCheckItems();
  }

  Future<void> _addItem() async {
    final label = _newItemController.text.trim();
    if (label.isEmpty) return;
    setState(() => _savingItem = true);
    final client = Supabase.instance.client;
    var itemKey = label.toLowerCase().replaceAll(RegExp(r"[^a-z0-9]+"), "_");
    var suffix = 1;
    while (_items.any((it) => it["item_key"] == itemKey)) {
      itemKey = label.toLowerCase().replaceAll(RegExp(r"[^a-z0-9]+"), "_") + "_" + suffix.toString();
      suffix++;
    }
    final nextOrder = _items.isEmpty ? 1 : (_items.map((it) => it["order_index"] as int).reduce((a, b) => a > b ? a : b) + 1);
    await client.from("streamer_phase_checklist_items").insert({
      "agency_id": widget.agencyId,
      "phase_key": widget.phaseKey,
      "stage_key": widget.existing!["stage_key"],
      "item_key": itemKey,
      "label": label,
      "order_index": nextOrder,
    });
    _newItemController.clear();
    await _loadItems();
    if (mounted) setState(() => _savingItem = false);
  }

  Future<void> _deleteItem(String id) async {
    await Supabase.instance.client.from("streamer_phase_checklist_items").delete().eq("id", id);
    await _loadItems();
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      final client = Supabase.instance.client;
      final stageKey = widget.existing != null ? widget.existing!["stage_key"] : _nameController.text.trim().toLowerCase().replaceAll(RegExp(r"[^a-z0-9]+"), "_");
      final maxOrder = widget.existing != null
          ? widget.existing!["order_index"]
          : (await client.from("streamer_phase_stages").select("order_index").eq("agency_id", widget.agencyId).eq("phase_key", widget.phaseKey).order("order_index", ascending: false).limit(1).maybeSingle())?["order_index"] ?? -1;

      final data = {
        "agency_id": widget.agencyId,
        "phase_key": widget.phaseKey,
        "stage_key": stageKey,
        "name": _nameController.text.trim(),
        "color": _colorController.text.trim(),
        "order_index": widget.existing != null ? maxOrder : (maxOrder as int) + 1,
        "is_active": _isActive,
      };

      if (widget.existing != null) {
        await client.from("streamer_phase_stages").update(data).eq("id", widget.existing!["id"]);
      } else {
        await client.from("streamer_phase_stages").insert(data);
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _saving = false;
        _errorMessage = "Erro: " + e.toString();
      });
    }
  }

  Future<void> _delete() async {
    final client = Supabase.instance.client;
    final stageKey = widget.existing!["stage_key"] as String;
    final cardsHere = await client
        .from("streamer_phase_progress")
        .select("id")
        .eq("agency_id", widget.agencyId)
        .eq("phase_key", widget.phaseKey)
        .eq("stage_key", stageKey)
        .filter("completed_at", "is", null)
        .limit(1);
    if ((cardsHere as List).isNotEmpty) {
      setState(() => _errorMessage = "Nao e possivel excluir: existem cards ativos nesta etapa. Mova-os antes de excluir.");
      return;
    }
    await client.from("streamer_phase_stages").delete().eq("id", widget.existing!["id"]);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.existing != null ? "Editar etapa" : "Nova etapa", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text("A ordem e definida arrastando na lista. Aqui voce edita titulo, cor e se esta ativa.", style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic)),
              const SizedBox(height: 16),
              TextField(controller: _nameController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Titulo da etapa", labelStyle: TextStyle(color: Colors.white54))),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextField(controller: _colorController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Cor (ex: #7A0BD4)", labelStyle: TextStyle(color: Colors.white54)))),
                const SizedBox(width: 8),
                CircleAvatar(radius: 14, backgroundColor: _tryColor(_colorController.text)),
              ]),
              SwitchListTile(value: _isActive, onChanged: (v) => setState(() => _isActive = v), title: const Text("Ativa", style: TextStyle(color: Colors.white)), activeColor: const Color(0xFF7A0BD4), contentPadding: EdgeInsets.zero),
              if (_errorMessage != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 12))),
              if (widget.existing != null) ...[
                const SizedBox(height: 16),
                const Divider(color: Colors.white12),
                const Text("Checklist desta etapa", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                const Text("Itens obrigatorios para o card avancar para a proxima etapa.", style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic)),
                const SizedBox(height: 8),
                if (_loadingItems)
                  const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 8), child: CircularProgressIndicator()))
                else if (_items.isEmpty)
                  const Text("Nenhum item ainda.", style: TextStyle(color: Colors.white38, fontSize: 12))
                else
                  ..._items.map((it) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(children: [
                          Expanded(child: Text(it["label"] as String, style: const TextStyle(color: Colors.white70, fontSize: 13))),
                          IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 16), onPressed: () => _deleteItem(it["id"] as String), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                        ]),
                      )),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _newItemController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(labelText: "Novo item do checklist", labelStyle: TextStyle(color: Colors.white54, fontSize: 12), isDense: true),
                      onSubmitted: (_) => _addItem(),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.add_circle, color: Color(0xFF7A0BD4)), onPressed: _savingItem ? null : _addItem),
                ]),
                const SizedBox(height: 16),
                const Divider(color: Colors.white12),
                const Text("Check Materiais", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                const Text("Lista que o gestor marca ao revisar os materiais com o streamer (nao trava o avanco de etapa).", style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic)),
                const SizedBox(height: 8),
                if (_loadingMaterialCheckItems)
                  const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 8), child: CircularProgressIndicator()))
                else if (_materialCheckItems.isEmpty)
                  const Text("Nenhum item ainda.", style: TextStyle(color: Colors.white38, fontSize: 12))
                else
                  ..._materialCheckItems.map((it) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(children: [
                          Expanded(child: Text(it["label"] as String, style: const TextStyle(color: Colors.white70, fontSize: 13))),
                          IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 16), onPressed: () => _deleteMaterialCheckItem(it["id"] as String), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                        ]),
                      )),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _newMaterialCheckItemController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(labelText: "Novo item do Check Materiais", labelStyle: TextStyle(color: Colors.white54, fontSize: 12), isDense: true),
                      onSubmitted: (_) => _addMaterialCheckItem(),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.add_circle, color: Color(0xFF7A0BD4)), onPressed: _savingMaterialCheckItem ? null : _addMaterialCheckItem),
                ]),
              ],
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                if (widget.existing != null) TextButton(onPressed: _delete, child: const Text("Excluir", style: TextStyle(color: Colors.redAccent))),
                const SizedBox(width: 8),
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
