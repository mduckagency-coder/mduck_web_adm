import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "team/team_sla_page.dart";
import "lead_category_icons.dart";
import "recruiter_templates_page.dart";

Color _hexToColor(String hex) {
  final cleaned = hex.replaceFirst("#", "");
  return Color(int.parse("FF" + cleaned, radix: 16));
}

class RecruiterSettingsPage extends StatefulWidget {
  const RecruiterSettingsPage({super.key});

  @override
  State<RecruiterSettingsPage> createState() => _RecruiterSettingsPageState();
}

class _RecruiterSettingsPageState extends State<RecruiterSettingsPage> {
  String _tab = "funil";

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Configuracoes do Recrutamento", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          const Text("Arraste os itens das listas para reorganizar. Clique em qualquer item para editar nome/cor.", style: TextStyle(color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic)),
          const SizedBox(height: 16),
          Wrap(spacing: 8, children: [
            ("funil", "Funil de Leads"),
            ("categorias_leads", "Categorias de Leads"),
            ("materiais", "Materiais"),
            ("modelos", "Modelos de Mensagens"),
            ("prazos", "Prazos"),
          ].map((t) {
            final selected = _tab == t.$1;
            return ChoiceChip(
              label: Text(t.$2),
              selected: selected,
              selectedColor: const Color(0xFF7A0BD4),
              labelStyle: TextStyle(color: selected ? Colors.white : Colors.white70),
              onSelected: (_) => setState(() => _tab = t.$1),
            );
          }).toList()),
          const SizedBox(height: 20),
          Expanded(
            child: _tab == "funil"
                ? const _KanbanStagesConfig()
                : _tab == "categorias_leads"
                    ? const _LeadCategoriesConfig()
                    : _tab == "materiais"
                        ? const _CategoriesConfig(table: "material_categories", title: "Categorias de Materiais")
                        : _tab == "modelos"
                            ? const _TemplatesSettingsTab()
                            : const TeamSlaPage(),
          ),
        ],
      ),
    );
  }
}

class _KanbanStagesConfig extends StatefulWidget {
  const _KanbanStagesConfig();

  @override
  State<_KanbanStagesConfig> createState() => _KanbanStagesConfigState();
}

class _KanbanStagesConfigState extends State<_KanbanStagesConfig> {
  List<Map<String, dynamic>> _stages = [];
  bool _loading = true;
  bool _hasChanges = false;
  bool _saving = false;
  String? _lastMessage;
  bool _lastMessageIsError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final client = Supabase.instance.client;
    final rows = await client.from("lead_kanban_stages").select().order("order_index");
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
        final result = await client.from("lead_kanban_stages").update({"order_index": i}).eq("id", id).select();
        if ((result as List).isEmpty) {
          setState(() {
            _saving = false;
            _lastMessage = "Nao foi possivel atualizar a etapa \"" + (_stages[i]["name"] as String) + "\" (id " + id.toString() + "). Provavel bloqueio de permissao (RLS). Confirme que seu usuario tem role coordenador ou admin.";
            _lastMessageIsError = true;
          });
          return;
        }
      }
      await _load();
      setState(() {
        _saving = false;
        _lastMessage = "Ordem salva com sucesso. Va na pagina de Leads (saia e entre de novo) para conferir.";
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

  void _openForm({Map<String, dynamic>? existing}) {
    showDialog(context: context, builder: (context) => _StageFormDialog(existing: existing)).then((saved) {
      if (saved == true) _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Text("Etapas do Kanban de Leads", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const Spacer(),
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
          child: ReorderableListView.builder(
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
                  subtitle: Text((s["is_initial"] == true ? "ETAPA INICIAL" : "") + (!active ? "  INATIVA" : ""), style: const TextStyle(color: Colors.white54, fontSize: 11)),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _StageFormDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const _StageFormDialog({this.existing});

  @override
  State<_StageFormDialog> createState() => _StageFormDialogState();
}

class _StageFormDialogState extends State<_StageFormDialog> {
  final _nameController = TextEditingController();
  final _colorController = TextEditingController(text: "#7A0BD4");
  bool _isInitial = false;
  bool _isActive = true;
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameController.text = e["name"] ?? "";
      _colorController.text = e["color"] ?? "#7A0BD4";
      _isInitial = e["is_initial"] ?? false;
      _isActive = e["is_active"] ?? true;
    }
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser!.id;
      final manager = await client.from("managers").select("agency_id").eq("id", userId).single();

      if (_isInitial) {
        await client.from("lead_kanban_stages").update({"is_initial": false}).eq("agency_id", manager["agency_id"]);
      }

      final stageKey = widget.existing != null ? widget.existing!["stage_key"] : _nameController.text.trim().toLowerCase().replaceAll(RegExp(r"[^a-z0-9]+"), "_");
      final maxOrder = widget.existing != null ? widget.existing!["order_index"] : 999;

      final data = {
        "agency_id": manager["agency_id"],
        "stage_key": stageKey,
        "name": _nameController.text.trim(),
        "color": _colorController.text.trim(),
        "order_index": maxOrder,
        "is_initial": _isInitial,
        "is_active": _isActive,
      };

      if (widget.existing != null) {
        final result = await client.from("lead_kanban_stages").update(data).eq("id", widget.existing!["id"]).select();
        if ((result as List).isEmpty) {
          setState(() {
            _saving = false;
            _errorMessage = "Nao foi possivel salvar - verifique se seu usuario tem permissao de coordenador/admin.";
          });
          return;
        }
      } else {
        await client.from("lead_kanban_stages").insert(data);
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
    await client.from("lead_kanban_stages").delete().eq("id", widget.existing!["id"]);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.existing != null ? "Editar etapa" : "Nova etapa", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text("A ordem e definida arrastando na lista. Aqui voce edita titulo, cor, se e a etapa inicial, e se esta ativa.", style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic)),
              const SizedBox(height: 16),
              TextField(controller: _nameController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Titulo da etapa", labelStyle: TextStyle(color: Colors.white54))),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextField(controller: _colorController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Cor (ex: #7A0BD4)", labelStyle: TextStyle(color: Colors.white54)))),
                const SizedBox(width: 8),
                CircleAvatar(radius: 14, backgroundColor: _tryColor(_colorController.text)),
              ]),
              SwitchListTile(value: _isInitial, onChanged: (v) => setState(() => _isInitial = v), title: const Text("Etapa inicial (novos leads comecam aqui)", style: TextStyle(color: Colors.white, fontSize: 13)), activeColor: const Color(0xFF7A0BD4), contentPadding: EdgeInsets.zero),
              SwitchListTile(value: _isActive, onChanged: (v) => setState(() => _isActive = v), title: const Text("Ativa", style: TextStyle(color: Colors.white)), activeColor: const Color(0xFF7A0BD4), contentPadding: EdgeInsets.zero),
              if (_errorMessage != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 12))),
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
    );
  }

  Color _tryColor(String hex) {
    try {
      return _hexToColor(hex);
    } catch (_) {
      return Colors.white24;
    }
  }
}

class _LeadCategoriesConfig extends StatefulWidget {
  const _LeadCategoriesConfig();

  @override
  State<_LeadCategoriesConfig> createState() => _LeadCategoriesConfigState();
}

class _LeadCategoriesConfigState extends State<_LeadCategoriesConfig> {
  List<Map<String, dynamic>> _categories = [];
  bool _loading = true;
  final _newNameController = TextEditingController();
  String _newIcon = "outro";

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final client = Supabase.instance.client;
    final rows = await client.from("lead_categories").select().order("order_index");
    setState(() {
      _categories = (rows as List).cast<Map<String, dynamic>>();
      _loading = false;
    });
  }

  Future<void> _toggleActive(String id, bool current) async {
    final client = Supabase.instance.client;
    await client.from("lead_categories").update({"is_active": !current}).eq("id", id);
    _load();
  }

  Future<void> _add() async {
    if (_newNameController.text.trim().isEmpty) return;
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;
    final manager = await client.from("managers").select("agency_id").eq("id", userId).single();
    await client.from("lead_categories").insert({"agency_id": manager["agency_id"], "name": _newNameController.text.trim(), "icon_key": _newIcon, "order_index": 999});
    _newNameController.clear();
    _load();
  }

  Future<void> _delete(String id) async {
    final client = Supabase.instance.client;
    await client.from("lead_categories").delete().eq("id", id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Categorias de Leads", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 4),
        const Text("Desative uma categoria para tira-la das opcoes sem apagar o historico dos leads que ja usam ela.", style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: TextField(controller: _newNameController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Nova categoria", labelStyle: TextStyle(color: Colors.white54)))),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: _newIcon,
            dropdownColor: const Color(0xFF1A1A1A),
            style: const TextStyle(color: Colors.white),
            items: categoryIconOptions.map((c) => DropdownMenuItem(value: c.$1, child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(c.$3, size: 16, color: Colors.white), const SizedBox(width: 4), Text(c.$2)]))).toList(),
            onChanged: (v) => setState(() => _newIcon = v!),
          ),
          const SizedBox(width: 8),
          ElevatedButton(onPressed: _add, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white), child: const Text("Adicionar")),
        ]),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final c = _categories[index];
              final active = c["is_active"] as bool? ?? true;
              return Card(
                color: Colors.white.withOpacity(0.05),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(categoryIcon(c["icon_key"] as String?), color: active ? const Color(0xFF7A0BD4) : Colors.white24),
                  title: Text(c["name"] as String, style: TextStyle(color: active ? Colors.white : Colors.white38)),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Switch(value: active, onChanged: (_) => _toggleActive(c["id"] as String, active), activeColor: const Color(0xFF7A0BD4)),
                    IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18), onPressed: () => _delete(c["id"] as String)),
                  ]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CategoriesConfig extends StatefulWidget {
  final String table;
  final String title;
  const _CategoriesConfig({required this.table, required this.title});

  @override
  State<_CategoriesConfig> createState() => _CategoriesConfigState();
}

class _CategoriesConfigState extends State<_CategoriesConfig> {
  List<Map<String, dynamic>> _categories = [];
  bool _loading = true;
  bool _hasChanges = false;
  bool _saving = false;
  final _newCategoryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final client = Supabase.instance.client;
    final rows = await client.from(widget.table).select().order("order_index");
    setState(() {
      _categories = (rows as List).cast<Map<String, dynamic>>();
      _loading = false;
      _hasChanges = false;
    });
  }

  Future<void> _persistOrder() async {
    final client = Supabase.instance.client;
    for (var i = 0; i < _categories.length; i++) {
      await client.from(widget.table).update({"order_index": i}).eq("id", _categories[i]["id"]);
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _categories.removeAt(oldIndex);
      _categories.insert(newIndex, item);
      _hasChanges = true;
    });
  }

  Future<void> _saveOrder() async {
    setState(() => _saving = true);
    await _persistOrder();
    setState(() {
      _hasChanges = false;
      _saving = false;
    });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ordem salva.")));
  }

  Future<void> _add() async {
    if (_newCategoryController.text.trim().isEmpty) return;
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;
    final manager = await client.from("managers").select("agency_id").eq("id", userId).single();
    await client.from(widget.table).insert({"agency_id": manager["agency_id"], "name": _newCategoryController.text.trim(), "order_index": 999});
    _newCategoryController.clear();
    _load();
  }

  Future<void> _delete(String id) async {
    final client = Supabase.instance.client;
    await client.from(widget.table).delete().eq("id", id);
    _load();
  }

  Future<void> _rename(String id, String currentName) async {
    final controller = TextEditingController(text: currentName);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text("Renomear categoria", style: TextStyle(color: Colors.white)),
        content: TextField(controller: controller, style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () async {
              final client = Supabase.instance.client;
              await client.from(widget.table).update({"name": controller.text.trim()}).eq("id", id);
              if (mounted) Navigator.of(context).pop();
              _load();
            },
            child: const Text("Salvar"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(child: Text(widget.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
          if (_hasChanges)
            ElevatedButton.icon(
              onPressed: _saving ? null : _saveOrder,
              icon: const Icon(Icons.save, size: 16),
              label: Text(_saving ? "Salvando..." : "Salvar ordem"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black),
            ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _newCategoryController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "Nova categoria", labelStyle: TextStyle(color: Colors.white54)),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(onPressed: _add, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white), child: const Text("Adicionar")),
        ]),
        const SizedBox(height: 16),
        Expanded(
          child: _categories.isEmpty
              ? const Center(child: Text("Nenhuma categoria ainda.", style: TextStyle(color: Colors.white54)))
              : ReorderableListView.builder(
                  itemCount: _categories.length,
                  onReorder: _onReorder,
                  itemBuilder: (context, index) {
                    final c = _categories[index];
                    return Card(
                      key: ValueKey(c["id"]),
                      color: Colors.white.withOpacity(0.05),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(Icons.drag_handle, color: Colors.white38),
                        title: Text(c["name"] as String, style: const TextStyle(color: Colors.white)),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(icon: const Icon(Icons.edit, color: Colors.white54, size: 18), onPressed: () => _rename(c["id"] as String, c["name"] as String)),
                          IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18), onPressed: () => _delete(c["id"] as String)),
                        ]),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _TemplatesSettingsTab extends StatelessWidget {
  const _TemplatesSettingsTab();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            title: const Text("Gerenciar categorias de modelos", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            iconColor: Colors.white70,
            collapsedIconColor: Colors.white70,
            children: [
              SizedBox(height: 260, child: _CategoriesConfig(table: "template_categories", title: "Categorias de Modelos de Mensagens")),
            ],
          ),
        ),
        const Divider(color: Colors.white12),
        const Expanded(child: RecruiterTemplatesPage()),
      ],
    );
  }
}
