import "package:file_picker/file_picker.dart";
import "package:flutter/material.dart";
import "../max_estados_service.dart";
import "../models/max_state.dart";
import "../models/max_state_media.dart";
import "max_video_preview.dart";

/// Retorna true quando o conteudo foi salvo ou removido, para a tela
/// chamadora recarregar.
class MaxMediaFormDialog extends StatefulWidget {
  final MaxStateKey stateKey;
  final MaxStateMedia? existing;

  const MaxMediaFormDialog({super.key, required this.stateKey, this.existing});

  @override
  State<MaxMediaFormDialog> createState() => _MaxMediaFormDialogState();
}

class _MaxMediaFormDialogState extends State<MaxMediaFormDialog> {
  final _service = MaxEstadosService();

  late MaxMediaType _mediaType;
  String? _newStoragePath;
  bool _uploading = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _mediaType = widget.existing?.mediaType ?? MaxMediaType.image;
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(type: _mediaType == MaxMediaType.image ? FileType.image : FileType.video, withData: true);
    if (result == null || result.files.single.bytes == null) return;
    setState(() => _uploading = true);
    try {
      final path = await _service.uploadMedia(mediaType: _mediaType, file: result.files.single);
      if (mounted) setState(() => _newStoragePath = path);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Não foi possível enviar: $e"), duration: const Duration(seconds: 8)));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  bool get _canSave => _newStoragePath != null;

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    await _service.replaceMedia(stateKey: widget.stateKey, mediaType: _mediaType, storagePath: _newStoragePath!);
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _remove() async {
    await _service.removeMedia(widget.existing!);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final previewPath = _newStoragePath ?? (widget.existing != null && widget.existing!.mediaType == _mediaType ? widget.existing!.storagePath : null);

    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Conteúdo — " + maxStateKeyLabel(widget.stateKey), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              SegmentedButton<MaxMediaType>(
                segments: const [
                  ButtonSegment(value: MaxMediaType.image, label: Text("Imagem"), icon: Icon(Icons.image, size: 16)),
                  ButtonSegment(value: MaxMediaType.video, label: Text("Vídeo"), icon: Icon(Icons.videocam, size: 16)),
                ],
                selected: {_mediaType},
                onSelectionChanged: (s) => setState(() {
                  _mediaType = s.first;
                  _newStoragePath = null;
                }),
              ),
              const SizedBox(height: 16),
              if (previewPath != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: _mediaType == MaxMediaType.image
                        ? Image.network(_service.publicUrlFor(previewPath), fit: BoxFit.cover)
                        : Container(
                            color: Colors.black,
                            child: MaxVideoPreview(key: ValueKey(previewPath), url: _service.publicUrlFor(previewPath)),
                          ),
                  ),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _uploading ? null : _pickFile,
                icon: Icon(_mediaType == MaxMediaType.image ? Icons.image : Icons.upload_file, size: 16, color: Colors.white70),
                label: Text(_uploading ? "Enviando..." : (previewPath != null ? "Trocar arquivo" : "Escolher arquivo"), style: const TextStyle(color: Colors.white70)),
              ),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                if (widget.existing != null) TextButton(onPressed: _remove, child: const Text("Remover conteúdo", style: TextStyle(color: Colors.redAccent))),
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
