import "package:file_picker/file_picker.dart";
import "package:flutter/material.dart";
import "../inventario_service.dart";
import "../models/inventory_entry.dart";

/// Retorna true quando um registro foi adicionado, para a tela chamadora
/// recarregar a lista.
class InventoryEntryFormDialog extends StatefulWidget {
  final String streamerId;
  final String streamerName;
  final InventoryCategory initialCategory;

  const InventoryEntryFormDialog({
    super.key,
    required this.streamerId,
    required this.streamerName,
    this.initialCategory = InventoryCategory.conquista,
  });

  @override
  State<InventoryEntryFormDialog> createState() => _InventoryEntryFormDialogState();
}

class _InventoryEntryFormDialogState extends State<InventoryEntryFormDialog> {
  final _service = InventarioService();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _pointsController = TextEditingController();

  late InventoryCategory _category;
  DateTime _occurredAt = DateTime.now();
  String? _imageUrl;
  bool _uploadingImage = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: _occurredAt, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (picked != null) setState(() => _occurredAt = picked);
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result == null || result.files.single.bytes == null) return;
    setState(() => _uploadingImage = true);
    try {
      final url = await _service.uploadImage(result.files.single);
      if (mounted) setState(() => _imageUrl = url);
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) return;
    setState(() => _saving = true);
    await _service.addEntry(
      streamerId: widget.streamerId,
      category: _category,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      occurredAt: _occurredAt,
      points: int.tryParse(_pointsController.text.trim()),
      imageUrl: _imageUrl,
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = _occurredAt.day.toString().padLeft(2, "0") + "/" + _occurredAt.month.toString().padLeft(2, "0") + "/" + _occurredAt.year.toString();
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Novo registro — " + widget.streamerName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: InventoryCategory.values.map((c) {
                          final selected = _category == c;
                          return ChoiceChip(
                            avatar: Icon(inventoryCategoryIcon(c), size: 16, color: selected ? Colors.white : inventoryCategoryColor(c)),
                            label: Text(inventoryCategoryLabel(c)),
                            selected: selected,
                            onSelected: (_) => setState(() => _category = c),
                            selectedColor: inventoryCategoryColor(c),
                            backgroundColor: const Color(0xFF232323),
                            labelStyle: TextStyle(color: selected ? Colors.white : Colors.white70, fontWeight: selected ? FontWeight.bold : FontWeight.normal),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _titleController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: "Título", labelStyle: TextStyle(color: Colors.white54)),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _descriptionController,
                        maxLines: 3,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: "Descrição (opcional)", labelStyle: TextStyle(color: Colors.white54)),
                      ),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickDate,
                            icon: const Icon(Icons.calendar_today, size: 16, color: Colors.white70),
                            label: Text(dateLabel, style: const TextStyle(color: Colors.white70)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _pointsController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(labelText: "XP (opcional)", labelStyle: TextStyle(color: Colors.white54)),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 16),
                      const Text("Foto (opcional)", style: TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 6),
                      if (_imageUrl != null) ...[
                        ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(_imageUrl!, height: 120, fit: BoxFit.cover)),
                        const SizedBox(height: 8),
                      ],
                      OutlinedButton.icon(
                        onPressed: _uploadingImage ? null : _pickImage,
                        icon: const Icon(Icons.image, size: 16, color: Colors.white70),
                        label: Text(_uploadingImage ? "Enviando..." : (_imageUrl != null ? "Trocar foto" : "Escolher foto"), style: const TextStyle(color: Colors.white70)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancelar")),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _saving || _titleController.text.trim().isEmpty ? null : _save,
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
