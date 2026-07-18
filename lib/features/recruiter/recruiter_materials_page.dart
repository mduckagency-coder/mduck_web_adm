import "package:flutter/material.dart";
import "package:file_picker/file_picker.dart";
import "package:supabase_flutter/supabase_flutter.dart";

const _authorPalette = [
  Color(0xFF7A0BD4),
  Color(0xFF00BCD4),
  Color(0xFFFF9800),
  Color(0xFF4CAF50),
  Color(0xFFE91E63),
  Color(0xFF3F51B5),
  Color(0xFFFFC107),
];

Color colorForAuthor(String? email) {
  if (email == null || email.isEmpty) return _authorPalette[0];
  final index = email.codeUnits.fold<int>(0, (sum, c) => sum + c) % _authorPalette.length;
  return _authorPalette[index];
}

class RecruiterMaterialsPage extends StatefulWidget {
  const RecruiterMaterialsPage({super.key});

  @override
  State<RecruiterMaterialsPage> createState() => _RecruiterMaterialsPageState();
}

class _RecruiterMaterialsPageState extends State<RecruiterMaterialsPage> {
  late Future<List<Map<String, dynamic>>> _future;
  List<Map<String, dynamic>> _categoriesList = [];
  String? _categoryFilter;
  String? _myUserId;

  @override
  void initState() {
    super.initState();
    _myUserId = Supabase.instance.client.auth.currentUser!.id;
    _future = _load();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final client = Supabase.instance.client;
    final rows = await client.from("material_categories").select().order("order_index");
    setState(() => _categoriesList = (rows as List).cast<Map<String, dynamic>>());
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final client = Supabase.instance.client;
    final rows = await client.from("training_materials").select("*, managers(login_email, role)").eq("is_archived", false).order("category").order("order_index");
    return (rows as List).cast<Map<String, dynamic>>();
  }

  void _openDetail(Map<String, dynamic> material) {
    showDialog(context: context, builder: (context) => _MaterialDetailDialog(material: material, myUserId: _myUserId!, categories: _categoriesList)).then((_) {
      setState(() => _future = _load());
      _loadCategories();
    });
  }

  void _openCreate() {
    showDialog(context: context, builder: (context) => _MaterialFormDialog(categories: _categoriesList)).then((saved) {
      if (saved == true) {
        setState(() => _future = _load());
        _loadCategories();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text("Materiais de Treinamento", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(width: 12),
            IconButton(icon: const Icon(Icons.refresh, color: Colors.white70), onPressed: () {
              setState(() => _future = _load());
              _loadCategories();
            }),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _openCreate,
              icon: const Icon(Icons.add),
              label: const Text("Meu Material"),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
            ),
          ]),
          const SizedBox(height: 4),
          const Text("Voce pode criar seus proprios materiais (editaveis por voce). Materiais do gestor sao so leitura, com opcao de enviar nota.", style: TextStyle(color: Colors.white38, fontSize: 12, fontStyle: FontStyle.italic)),
          const SizedBox(height: 16),
          Wrap(spacing: 8, children: [
            ChoiceChip(label: const Text("Todas"), selected: _categoryFilter == null, selectedColor: Colors.white24, onSelected: (_) => setState(() => _categoryFilter = null)),
            ..._categoriesList.map((c) {
              final selected = _categoryFilter == c["name"];
              return ChoiceChip(
                label: Text(c["name"] as String, style: const TextStyle(fontSize: 11)),
                selected: selected,
                selectedColor: const Color(0xFF7A0BD4),
                labelStyle: TextStyle(color: selected ? Colors.white : Colors.white70),
                onSelected: (_) => setState(() => _categoryFilter = c["name"] as String),
              );
            }),
          ]),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final list = _categoryFilter == null ? snapshot.data! : snapshot.data!.where((m) => m["category"] == _categoryFilter).toList();
                if (list.isEmpty) return const Center(child: Text("Nenhum material cadastrado ainda.", style: TextStyle(color: Colors.white54)));
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final m = list[index];
                    final authorData = m["managers"];
                    final authorEmail = authorData is Map ? authorData["login_email"] as String? : null;
                    final authorRole = authorData is Map ? authorData["role"] as String? : null;
                    final isMine = m["author_id"] == _myUserId;
                    final isFromGestor = !isMine && (authorRole == "coordenador" || authorRole == "admin");
                    final createdDate = m["created_at"] != null ? DateTime.parse(m["created_at"]).toLocal().toString().substring(0, 10) : "-";
                    final authorColor = colorForAuthor(authorEmail);

                    return InkWell(
                      onTap: () => _openDetail(m),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isFromGestor ? authorColor.withOpacity(0.1) : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: isFromGestor ? Border.all(color: authorColor.withOpacity(0.6), width: 1.5) : (isMine ? Border.all(color: Colors.white24) : null),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Expanded(child: Text(m["title"] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15))),
                              if (isFromGestor)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                                  child: const Text("MATERIAL OBRIGATORIO", style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              if (isMine)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                                  child: const Text("MEU MATERIAL", style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                            ]),
                            const SizedBox(height: 4),
                            Text((m["category"] as String? ?? "-"), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                            if (isFromGestor && (m["description"] as String?)?.isNotEmpty == true) ...[
                              const SizedBox(height: 4),
                              Text(m["description"], style: const TextStyle(color: Colors.white70, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                            ],
                            const SizedBox(height: 6),
                            Text(
                              "Criado por: " + (authorEmail ?? "sistema") + "  -  " + createdDate,
                              style: TextStyle(color: isFromGestor ? authorColor : Colors.white38, fontSize: 11, fontStyle: FontStyle.italic, fontWeight: isFromGestor ? FontWeight.bold : FontWeight.normal),
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

class _MaterialDetailDialog extends StatefulWidget {
  final Map<String, dynamic> material;
  final String myUserId;
  final List<Map<String, dynamic>> categories;
  const _MaterialDetailDialog({required this.material, required this.myUserId, required this.categories});

  @override
  State<_MaterialDetailDialog> createState() => _MaterialDetailDialogState();
}

class _MaterialDetailDialogState extends State<_MaterialDetailDialog> {
  final _noteController = TextEditingController();
  bool _sending = false;
  bool _sent = false;
  bool _deleted = false;

  Future<void> _sendNote() async {
    if (_noteController.text.trim().isEmpty) return;
    setState(() => _sending = true);
    final client = Supabase.instance.client;
    await client.from("recruiter_feedbacks").insert({
      "recruiter_id": widget.myUserId,
      "title": "Nota sobre material: " + (widget.material["title"] as String),
      "notes": _noteController.text.trim(),
      "material_id": widget.material["id"],
      "raised_by_recruiter": true,
      "status": "pendente",
    });
    setState(() {
      _sending = false;
      _sent = true;
    });
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text("Excluir material?", style: TextStyle(color: Colors.white)),
        content: const Text("Nao pode ser desfeito.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancelar")),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(true), style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white), child: const Text("Excluir")),
        ],
      ),
    );
    if (confirmed == true) {
      final client = Supabase.instance.client;
      await client.from("training_materials").delete().eq("id", widget.material["id"]);
      setState(() => _deleted = true);
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _edit() {
    Navigator.of(context).pop();
    showDialog(context: context, builder: (context) => _MaterialFormDialog(existing: widget.material, categories: widget.categories));
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.material;
    final authorData = m["managers"];
    final authorEmail = authorData is Map ? authorData["login_email"] as String? : null;
    final authorRole = authorData is Map ? authorData["role"] as String? : null;
    final isMine = m["author_id"] == widget.myUserId;
    final isFromGestor = !isMine && (authorRole == "coordenador" || authorRole == "admin");
    final createdDate = m["created_at"] != null ? DateTime.parse(m["created_at"]).toLocal().toString().substring(0, 16) : "-";
    final authorColor = colorForAuthor(authorEmail);

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
                Row(children: [
                  Expanded(child: Text(m["title"] as String, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
                  if (isFromGestor)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                      child: const Text("MATERIAL OBRIGATORIO", style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  if (isMine) ...[
                    IconButton(icon: const Icon(Icons.edit, color: Colors.white54, size: 18), onPressed: _edit),
                    IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18), onPressed: _delete),
                  ],
                ]),
                const SizedBox(height: 8),
                Text("Categoria: " + (m["category"] as String? ?? "-"), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                Text("Criado por: " + (authorEmail ?? "sistema") + " em " + createdDate, style: TextStyle(color: isFromGestor ? authorColor : Colors.white54, fontSize: 12, fontStyle: FontStyle.italic)),
                const SizedBox(height: 16),
                if ((m["description"] as String?)?.isNotEmpty == true) ...[
                  const Text("Texto", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 4),
                  SelectableText(m["description"], style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 12),
                ],
                if ((m["link_url"] as String?)?.isNotEmpty == true) ...[
                  const Text("Link", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  SelectableText(m["link_url"], style: const TextStyle(color: Colors.tealAccent)),
                  const SizedBox(height: 12),
                ],
                if ((m["file_url"] as String?)?.isNotEmpty == true) ...[
                  const Text("Arquivo", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  SelectableText(m["file_url"], style: const TextStyle(color: Colors.orangeAccent)),
                  const SizedBox(height: 12),
                ],
                if ((m["image_url"] as String?)?.isNotEmpty == true) ...[
                  const Text("Imagem", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(m["image_url"], height: 160, fit: BoxFit.cover)),
                  const SizedBox(height: 12),
                ],
                if ((m["video_url"] as String?)?.isNotEmpty == true) ...[
                  const Text("Video", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  SelectableText(m["video_url"], style: const TextStyle(color: Colors.purpleAccent)),
                  const SizedBox(height: 12),
                ],
                if (isFromGestor) ...[
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 8),
                  const Text("Enviar nota para o gestor", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  const Text("Fica registrada como um ticket em aberto na sua aba Feedbacks.", style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic)),
                  const SizedBox(height: 8),
                  if (_sent)
                    const Text("Nota enviada! Confira em Feedbacks.", style: TextStyle(color: Colors.greenAccent))
                  else ...[
                    TextField(
                      controller: _noteController,
                      maxLines: 3,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(hintText: "Escreva sua duvida ou observacao sobre este material...", hintStyle: TextStyle(color: Colors.white24), border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: _sending ? null : _sendNote,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A0BD4), foregroundColor: Colors.white),
                        child: Text(_sending ? "Enviando..." : "Enviar nota"),
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Fechar"))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MaterialFormDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final List<Map<String, dynamic>> categories;
  const _MaterialFormDialog({this.existing, required this.categories});

  @override
  State<_MaterialFormDialog> createState() => _MaterialFormDialogState();
}

class _MaterialFormDialogState extends State<_MaterialFormDialog> {
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
    final result = await FilePicker.platform.pickFiles(type: isImage ? FileType.image : FileType.any, withData: true);
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
                Text(widget.existing != null ? "Editar meu material" : "Novo material meu", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
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
                if (_fileUrl != null) const Padding(padding: EdgeInsets.only(top: 4), child: Text("Arquivo pronto.", style: TextStyle(color: Colors.greenAccent, fontSize: 11))),
                if (_imageUrl != null) const Padding(padding: EdgeInsets.only(top: 4), child: Text("Imagem pronta.", style: TextStyle(color: Colors.greenAccent, fontSize: 11))),
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
