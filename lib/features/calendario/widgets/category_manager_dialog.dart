import "package:flutter/material.dart";
import "../calendar_colors.dart";
import "../models/event_category.dart";
import "../services/calendar_service.dart";

class CategoryManagerDialog extends StatefulWidget {
  const CategoryManagerDialog({super.key});

  @override
  State<CategoryManagerDialog> createState() => _CategoryManagerDialogState();
}

class _CategoryManagerDialogState extends State<CategoryManagerDialog> {
  final _service = CalendarService();
  List<EventCategory> _categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await _service.seedDefaultCategories();
    final categories = await _service.fetchCategories();
    if (mounted) {
      setState(() {
        _categories = categories;
        _loading = false;
      });
    }
  }

  Future<void> _openForm({EventCategory? existing}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => CategoryFormDialog(existing: existing),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(child: Text("Categorias de evento", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))),
                  ElevatedButton.icon(
                    onPressed: () => _openForm(),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text("Nova"),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        itemCount: _categories.length,
                        itemBuilder: (context, index) {
                          final c = _categories[index];
                          return ListTile(
                            onTap: () => _openForm(existing: c),
                            leading: CircleAvatar(radius: 10, backgroundColor: hexToColor(c.color)),
                            title: Text(c.name, style: TextStyle(color: c.isActive ? Colors.white : Colors.white38, fontSize: 13)),
                            subtitle: Text(scopeLabel(c.scope), style: const TextStyle(color: Colors.white38, fontSize: 11)),
                            trailing: !c.isActive ? const Text("inativa", style: TextStyle(color: Colors.white38, fontSize: 11)) : null,
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

class CategoryFormDialog extends StatefulWidget {
  final EventCategory? existing;
  const CategoryFormDialog({super.key, this.existing});

  @override
  State<CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<CategoryFormDialog> {
  final _service = CalendarService();
  final _nameController = TextEditingController();
  final _colorController = TextEditingController(text: "#7A0BD4");
  bool _isActive = true;
  bool _saving = false;
  String _scope = "ambos";

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameController.text = e.name;
      _colorController.text = e.color;
      _isActive = e.isActive;
      _scope = e.scope;
    }
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _saving = true);
    await _service.saveCategory(
      id: widget.existing?.id,
      name: _nameController.text.trim(),
      color: _colorController.text.trim(),
      scope: _scope,
      orderIndex: widget.existing?.orderIndex ?? 999,
      isActive: _isActive,
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    await _service.deleteCategory(widget.existing!.id);
    if (mounted) Navigator.of(context).pop(true);
  }

  Color _tryColor(String hex) {
    try {
      return hexToColor(hex);
    } catch (_) {
      return Colors.white24;
    }
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
              Text(widget.existing != null ? "Editar categoria" : "Nova categoria", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(controller: _nameController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Nome", labelStyle: TextStyle(color: Colors.white54))),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextField(controller: _colorController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Cor (ex: #7A0BD4)", labelStyle: TextStyle(color: Colors.white54)), onChanged: (_) => setState(() {}))),
                const SizedBox(width: 8),
                CircleAvatar(radius: 14, backgroundColor: _tryColor(_colorController.text)),
              ]),
              const SizedBox(height: 12),
              const Text("Visível para", style: TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 6),
              SegmentedButton<String>(
                segments: categoryScopeOptions.map((s) => ButtonSegment(value: s, label: Text(scopeLabel(s)))).toList(),
                selected: {_scope},
                onSelectionChanged: (s) => setState(() => _scope = s.first),
              ),
              SwitchListTile(value: _isActive, onChanged: (v) => setState(() => _isActive = v), title: const Text("Ativa", style: TextStyle(color: Colors.white)), activeColor: const Color(0xFF7A0BD4), contentPadding: EdgeInsets.zero),
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
}
