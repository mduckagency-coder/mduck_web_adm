import "package:flutter/material.dart";
import "package:file_picker/file_picker.dart";
import "package:supabase_flutter/supabase_flutter.dart";

class TeamMaterialsAdminPage extends StatefulWidget {
  const TeamMaterialsAdminPage({super.key});

  @override
  State<TeamMaterialsAdminPage> createState() => _TeamMaterialsAdminPageState();
}

class _TeamMaterialsAdminPageState extends State<TeamMaterialsAdminPage> {
  late Future<List<Map<String, dynamic>>> _future;
  List<Map<String, dynamic>> _categories = [];

  @override
  void initState() {
    super.initState();
    _future = _load();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final client = Supabase.instance.client;
    final rows = await client.from("material_categories").select().order("order_index");
    setState(() => _categories = (rows as List).cast<Map<String, dynamic>>());
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final client = Supabase.instance.client;
    final rows = await client.from("training_materials").select("*, managers(login_email)").eq("is_archived", false).order("category").order("order_index");
    return (rows as List).cast<Map<String, dynamic>>();
  }

  void _openForm({Map<String, dynamic>? existing}) {
    showDialog(context: context, builder: (context) => _MaterialAdminFormDialog(existing: existing, categories: _categories)).then((saved) {
      if (saved == true) {
        setState(() => _future = _load());
        _loadCategories();
      }
    });
  }

  Future<void> _delete(String id) async {
    final client = Supabase.instance.client;
    await client.from("training_materials").delete().eq("id", id);
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
            const Text("Cadastrar Materiais", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(width: 12),
            IconButton(icon: const Icon(Icons.refresh, color: Colors.white70), onPressed: () => setState(() => _future = _load())),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add),
              label: const Text("Novo Material"),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
            ),
          ]),
          const SizedBox(height: 4),
          const Text("Materiais cadastrados aqui aparecem para todos os recrutadores na aba Materiais e nao podem ser excluidos por eles.", style: TextStyle(color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic)),
          const SizedBox(height: 20),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final list = snapshot.data!;
                if (list.isEmpty) return const Center(child: Text("Nenhum material cadastrado ainda.", style: TextStyle(color: Colors.white54)));
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final m = list[index];
                    final authorData = m["managers"];
                    final authorEmail = authorData is Map ? authorData["login_email"] as String? : null;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7A0BD4).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF7A0BD4).withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(m["title"] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                const SizedBox(height: 2),
                                Text("Coluna: " + (m["category"] as String? ?? "-"), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                if ((m["description"] as String?)?.isNotEmpty == true) Text(m["description"], style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                if ((m["link_url"] as String?)?.isNotEmpty == true) Text("Link: " + m["link_url"], style: const TextStyle(color: Colors.tealAccent, fontSize: 12)),
                                if ((m["file_url"] as String?)?.isNotEmpty == true) const Text("Arquivo anexado", style: TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                                if ((m["image_url"] as String?)?.isNotEmpty == true) const Text("Imagem anexada", style: TextStyle(color: Colors.pinkAccent, fontSize: 12)),
                                if (authorEmail != null) Text("Criado por: " + authorEmail, style: const TextStyle(color: Color(0xFF7A0BD4), fontSize: 11, fontStyle: FontStyle.italic)),
                              ],
                            ),
                          ),
                          IconButton(icon: const Icon(Icons.edit, color: Colors.white54, size: 18), onPressed: () => _openForm(existing: m)),
                          IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18), onPressed: () => _delete(m["id"] as String)),
                        ],
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

class _MaterialAdminFormDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final List<Map<String, dynamic>> categories;
  const _MaterialAdminFormDialog({this.existing, required this.categories});

  @override
  State<_MaterialAdminFormDialog> createState() => _MaterialAdminFormDialogState();
}

class _MaterialAdminFormDialogState extends State<_MaterialAdminFormDialog> {
  final _titleController = TextEditingController();
  final _textController = TextEditingController();
  final _linkController = TextEditingController();
  final _newCategoryController = TextEditingController();
  String? _category;
  String? _fileUrl;
  String? _imageUrl;
  String? _fileName;
  String? _imageName;
  bool _saving = false;
  bool _uploadingFile = false;
  bool _uploadingImage = false;
  bool _showNewCategory = false;

  @override
  void initState() {
    super.initState();
    _category = widget.categories.isNotEmpty ? widget.categories.first["name"] as String : null;
    final e = widget.existing;
    if (e != null) {
      _titleController.text = e["title"] ?? "";
      _textController.text = e["description"] ?? "";
      _linkController.text = e["link_url"] ?? "";
      _category = e["category"] ?? _category;
      _fileUrl = e["file_url"];
      _imageUrl = e["image_url"];
    }
  }

  Future<void> _pickFile({required bool isImage}) async {
    setState(() {
      if (isImage) { _uploadingImage = true; } else { _uploadingFile = true; }
    });
    final result = await FilePicker.platform.pickFiles(
      type: isImage ? FileType.image : FileType.any,
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      setState(() {
        if (isImage) { _uploadingImage = false; } else { _uploadingFile = false; }
      });
      return;
    }
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      setState(() {
        if (isImage) { _uploadingImage = false; } else { _uploadingFile = false; }
      });
      return;
    }
    final client = Supabase.instance.client;
    final path = DateTime.now().millisecondsSinceEpoch.toString() + "_" + file.name;
    try {
      await client.storage.from("material_attachments").uploadBinary(path, bytes);
      final publicUrl = client.storage.from("material_attachments").getPublicUrl(path);
      setState(() {
        if (isImage) {
          _imageUrl = publicUrl;
          _imageName = file.name;
          _uploadingImage = false;
        } else {
          _fileUrl = publicUrl;
          _fileName = file.name;
          _uploadingFile = false;
        }
      });
    } catch (e) {
      setState(() {
        if (isImage) { _uploadingImage = false; } else { _uploadingFile = false; }
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao enviar: " + e.toString())));
    }
  }

  Future<void> _addNewCategory() async {
    if (_newCategoryController.text.trim().isEmpty) return;
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;
    final manager = await client.from("managers").select("agency_id").eq("id", userId).single();
    final inserted = await client.from("material_categories").insert({"agency_id": manager["agency_id"], "name": _newCategoryController.text.trim(), "order_index": 999}).select().single();
    setState(() {
      widget.categories.add(inserted);
      _category = inserted["name"] as String;
      _newCategoryController.clear();
      _showNewCategory = false;
    });
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty || _category == null) return;
    setState(() => _saving = true);
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser!.id;
    final manager = await client.from("managers").select("agency_id").eq("id", userId).single();

    final data = {
      "agency_id": manager["agency_id"],
      "category": _category,
      "title": _titleController.text.trim(),
      "description": _textController.text.trim(),
      "link_url": _linkController.text.trim(),
      "file_url": _fileUrl,
      "image_url": _imageUrl,
      "author_id": userId,
      "updated_at": DateTime.now().toIso8601String(),
    };

    if (widget.existing != null) {
      await client.from("training_materials").update(data).eq("id", widget.existing!["id"]);
    } else {
      await client.from("training_materials").insert(data);
    }

    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
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
                Text(widget.existing != null ? "Editar material" : "Novo material", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                const Text("Coluna (categoria)", style: TextStyle(color: Colors.white54, fontSize: 12)),
                Row(children: [
                  Expanded(
                    child: DropdownButton<String>(
                      value: _category,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF1A1A1A),
                      style: const TextStyle(color: Colors.white),
                      items: widget.categories.map((c) => DropdownMenuItem(value: c["name"] as String, child: Text(c["name"] as String))).toList(),
                      onChanged: (v) => setState(() => _category = v),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.add_circle_outline, color: Color(0xFF7A0BD4)), tooltip: "Adicionar nova coluna", onPressed: () => setState(() => _showNewCategory = !_showNewCategory)),
                ]),
                if (_showNewCategory)
                  Row(children: [
                    Expanded(child: TextField(controller: _newCategoryController, style: const TextStyle(color: Colors.white, fontSize: 13), decoration: const InputDecoration(labelText: "Nome da nova coluna", labelStyle: TextStyle(color: Colors.white54, fontSize: 12)))),
                    TextButton(onPressed: _addNewCategory, child: const Text("Criar")),
                  ]),
                const SizedBox(height: 12),
                TextField(controller: _titleController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Titulo", labelStyle: TextStyle(color: Colors.white54))),
                const SizedBox(height: 8),
                TextField(controller: _textController, maxLines: 4, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Texto", labelStyle: TextStyle(color: Colors.white54))),
                const SizedBox(height: 8),
                TextField(controller: _linkController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Link (opcional)", labelStyle: TextStyle(color: Colors.white54))),
                const SizedBox(height: 12),
                Row(children: [
                  OutlinedButton.icon(
                    onPressed: _uploadingFile ? null : () => _pickFile(isImage: false),
                    icon: const Icon(Icons.attach_file, size: 16),
                    label: Text(_uploadingFile ? "Enviando..." : (_fileName ?? "Anexar arquivo")),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _uploadingImage ? null : () => _pickFile(isImage: true),
                    icon: const Icon(Icons.image, size: 16),
                    label: Text(_uploadingImage ? "Enviando..." : (_imageName ?? "Anexar imagem")),
                  ),
                ]),
                if (_fileUrl != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text("Arquivo pronto.", style: const TextStyle(color: Colors.greenAccent, fontSize: 11))),
                if (_imageUrl != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text("Imagem pronta.", style: const TextStyle(color: Colors.greenAccent, fontSize: 11))),
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
