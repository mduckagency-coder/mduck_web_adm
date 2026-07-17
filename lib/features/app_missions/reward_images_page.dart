import "package:file_picker/file_picker.dart";
import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";

class RewardImagesPage extends StatefulWidget {
  const RewardImagesPage({super.key});

  @override
  State<RewardImagesPage> createState() => _RewardImagesPageState();
}

class _RewardImagesPageState extends State<RewardImagesPage> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final client = Supabase.instance.client;
    final rows = await client.from("reward_images").select().order("label");
    return (rows as List).cast<Map<String, dynamic>>();
  }

  void _reload() => setState(() => _future = _load());

  void _openForm({Map<String, dynamic>? existing}) {
    showDialog(context: context, builder: (context) => _RewardImageFormDialog(existing: existing)).then((saved) {
      if (saved == true) _reload();
    });
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
              onPressed: () => _openForm(),
              backgroundColor: const Color(0xFF7A0BD4),
              foregroundColor: Colors.white,
              tooltip: "Nova imagem",
              child: const Icon(Icons.add),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final images = snapshot.data!;
              if (images.isEmpty) {
                return const Center(child: Text("Nenhuma imagem de premiacao cadastrada ainda.", style: TextStyle(color: Colors.white54)));
              }
              return GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 0.85),
                itemCount: images.length,
                itemBuilder: (context, index) {
                  final img = images[index];
                  return InkWell(
                    onTap: () => _openForm(existing: img),
                    child: Container(
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white24)),
                      child: Column(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                              child: Image.network(img["image_url"] as String, fit: BoxFit.cover, width: double.infinity),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(img["label"] as String, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
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
    );
  }
}

class _RewardImageFormDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const _RewardImageFormDialog({this.existing});

  @override
  State<_RewardImageFormDialog> createState() => _RewardImageFormDialogState();
}

class _RewardImageFormDialogState extends State<_RewardImageFormDialog> {
  final _labelController = TextEditingController();
  String? _imageUrl;
  bool _uploading = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _labelController.text = widget.existing!["label"] ?? "";
      _imageUrl = widget.existing!["image_url"];
    }
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result == null || result.files.single.bytes == null) return;
    setState(() => _uploading = true);
    try {
      final client = Supabase.instance.client;
      final fileName = DateTime.now().millisecondsSinceEpoch.toString() + "_" + result.files.single.name;
      await client.storage.from("reward_images").uploadBinary(fileName, result.files.single.bytes!);
      final url = client.storage.from("reward_images").getPublicUrl(fileName);
      setState(() => _imageUrl = url);
    } finally {
      setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    if (_labelController.text.trim().isEmpty || _imageUrl == null) return;
    setState(() => _saving = true);
    final client = Supabase.instance.client;
    final managerId = client.auth.currentUser!.id;
    final manager = await client.from("managers").select("agency_id").eq("id", managerId).single();

    if (widget.existing != null) {
      await client.from("reward_images").update({"label": _labelController.text.trim(), "image_url": _imageUrl}).eq("id", widget.existing!["id"]);
    } else {
      await client.from("reward_images").insert({"agency_id": manager["agency_id"], "label": _labelController.text.trim(), "image_url": _imageUrl});
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final client = Supabase.instance.client;
    await client.from("reward_images").delete().eq("id", widget.existing!["id"]);
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.existing != null ? "Editar imagem" : "Nova imagem de premiacao", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(controller: _labelController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Nome (ex: Placa 150k)", labelStyle: TextStyle(color: Colors.white54))),
              const SizedBox(height: 16),
              if (_imageUrl != null)
                ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(_imageUrl!, height: 140, fit: BoxFit.cover)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _uploading ? null : _pickImage,
                icon: const Icon(Icons.image, size: 16),
                label: Text(_uploading ? "Enviando..." : "Escolher imagem"),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (widget.existing != null) TextButton(onPressed: _delete, child: const Text("Excluir", style: TextStyle(color: Colors.redAccent))),
                  const SizedBox(width: 8),
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
    );
  }
}
