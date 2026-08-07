import "package:file_picker/file_picker.dart";
import "package:flutter/material.dart";
import "../max_lessons_service.dart";
import "../models/max_lesson.dart";

/// Retorna true quando a aula foi salva ou excluida, para a tela chamadora
/// recarregar a lista.
class LessonFormDialog extends StatefulWidget {
  final MaxLesson? existing;

  const LessonFormDialog({super.key, this.existing});

  @override
  State<LessonFormDialog> createState() => _LessonFormDialogState();
}

class _LessonFormDialogState extends State<LessonFormDialog> {
  final _service = MaxLessonsService();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _youtubeUrlController = TextEditingController();

  MaxLessonCategory _category = MaxLessonCategory.geral;
  MaxLessonLevel _level = MaxLessonLevel.iniciante;
  MaxLessonVideoSource _videoSource = MaxLessonVideoSource.youtube;
  String? _coverImageUrl;
  String? _uploadedVideoUrl;
  String? _uploadedVideoName;
  bool _isActive = true;

  bool _uploadingCover = false;
  bool _uploadingVideo = false;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _titleController.text = e.title;
      _descriptionController.text = e.description ?? "";
      _category = e.category;
      _level = e.level;
      _videoSource = e.videoSource;
      _coverImageUrl = e.coverImageUrl;
      _isActive = e.isActive;
      if (e.videoSource == MaxLessonVideoSource.youtube) {
        _youtubeUrlController.text = e.videoUrl;
      } else {
        _uploadedVideoUrl = e.videoUrl;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _youtubeUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result == null || result.files.single.bytes == null) return;
    setState(() => _uploadingCover = true);
    try {
      final url = await _service.uploadCoverImage(result.files.single);
      if (mounted) setState(() => _coverImageUrl = url);
    } finally {
      if (mounted) setState(() => _uploadingCover = false);
    }
  }

  Future<void> _pickVideoFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video, withData: true);
    if (result == null || result.files.single.bytes == null) return;
    setState(() => _uploadingVideo = true);
    try {
      final url = await _service.uploadVideoFile(result.files.single);
      if (mounted) {
        setState(() {
          _uploadedVideoUrl = url;
          _uploadedVideoName = result.files.single.name;
        });
      }
    } finally {
      if (mounted) setState(() => _uploadingVideo = false);
    }
  }

  String? get _videoUrl => _videoSource == MaxLessonVideoSource.youtube ? _youtubeUrlController.text.trim() : _uploadedVideoUrl;

  bool get _canSave {
    if (_titleController.text.trim().isEmpty) return false;
    if (_coverImageUrl == null) return false;
    final videoUrl = _videoUrl;
    if (videoUrl == null || videoUrl.isEmpty) return false;
    if (_videoSource == MaxLessonVideoSource.youtube && !(videoUrl.contains("youtube.com") || videoUrl.contains("youtu.be"))) return false;
    return true;
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    await _service.saveLesson(
      id: widget.existing?.id,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      category: _category,
      level: _level,
      coverImageUrl: _coverImageUrl!,
      videoSource: _videoSource,
      videoUrl: _videoUrl!,
      isActive: _isActive,
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    await _service.deleteLesson(widget.existing!.id);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_isEditing ? "Editar aula" : "Nova aula", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Capa", style: TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 6),
                      if (_coverImageUrl != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(_coverImageUrl!, height: 140, width: double.infinity, fit: BoxFit.cover),
                        ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _uploadingCover ? null : _pickCover,
                        icon: const Icon(Icons.image, size: 16, color: Colors.white70),
                        label: Text(_uploadingCover ? "Enviando..." : (_coverImageUrl != null ? "Trocar capa" : "Escolher capa"), style: const TextStyle(color: Colors.white70)),
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
                        decoration: const InputDecoration(labelText: "Descrição", labelStyle: TextStyle(color: Colors.white54)),
                      ),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(
                          child: DropdownButtonFormField<MaxLessonCategory>(
                            initialValue: _category,
                            dropdownColor: const Color(0xFF232323),
                            decoration: const InputDecoration(labelText: "Categoria", labelStyle: TextStyle(color: Colors.white54)),
                            style: const TextStyle(color: Colors.white),
                            items: MaxLessonCategory.values.map((c) => DropdownMenuItem(value: c, child: Text(maxLessonCategoryLabel(c)))).toList(),
                            onChanged: (v) => setState(() => _category = v!),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<MaxLessonLevel>(
                            initialValue: _level,
                            dropdownColor: const Color(0xFF232323),
                            decoration: const InputDecoration(labelText: "Nível", labelStyle: TextStyle(color: Colors.white54)),
                            style: const TextStyle(color: Colors.white),
                            items: MaxLessonLevel.values.map((l) => DropdownMenuItem(value: l, child: Text(maxLessonLevelLabel(l)))).toList(),
                            onChanged: (v) => setState(() => _level = v!),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 16),
                      const Text("Vídeo", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      SegmentedButton<MaxLessonVideoSource>(
                        segments: const [
                          ButtonSegment(value: MaxLessonVideoSource.youtube, label: Text("Link do YouTube"), icon: Icon(Icons.link, size: 16)),
                          ButtonSegment(value: MaxLessonVideoSource.upload, label: Text("Upload de vídeo"), icon: Icon(Icons.upload_file, size: 16)),
                        ],
                        selected: {_videoSource},
                        onSelectionChanged: (s) => setState(() => _videoSource = s.first),
                      ),
                      const SizedBox(height: 12),
                      if (_videoSource == MaxLessonVideoSource.youtube)
                        TextField(
                          controller: _youtubeUrlController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: "URL do YouTube",
                            labelStyle: TextStyle(color: Colors.white54),
                            hintText: "https://www.youtube.com/watch?v=...",
                            hintStyle: TextStyle(color: Colors.white38),
                          ),
                          onChanged: (_) => setState(() {}),
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _uploadingVideo ? null : _pickVideoFile,
                              icon: const Icon(Icons.upload_file, size: 16, color: Colors.white70),
                              label: Text(_uploadingVideo ? "Enviando..." : "Escolher arquivo de vídeo", style: const TextStyle(color: Colors.white70)),
                            ),
                            if (_uploadedVideoName != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text("Selecionado: " + _uploadedVideoName!, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                              )
                            else if (_uploadedVideoUrl != null)
                              const Padding(
                                padding: EdgeInsets.only(top: 6),
                                child: Text("Vídeo já enviado.", style: TextStyle(color: Colors.white54, fontSize: 12)),
                              ),
                          ],
                        ),
                      const SizedBox(height: 16),
                      Row(children: [
                        const Text("Aula ativa (visível no app)", style: TextStyle(color: Colors.white70, fontSize: 12)),
                        const Spacer(),
                        Switch(value: _isActive, onChanged: (v) => setState(() => _isActive = v), activeThumbColor: const Color(0xFF7A0BD4)),
                      ]),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                if (_isEditing) TextButton(onPressed: _delete, child: const Text("Excluir", style: TextStyle(color: Colors.redAccent))),
                const SizedBox(width: 8),
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancelar")),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _saving || !_canSave ? null : _save,
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
