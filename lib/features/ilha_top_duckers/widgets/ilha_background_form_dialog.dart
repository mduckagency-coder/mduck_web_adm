import "package:file_picker/file_picker.dart";
import "package:flutter/material.dart";
import "../ilha_top_service.dart";
import "ilha_crop_editor.dart";
import "ilha_media_playback_fields.dart";

const _maxFileSizeBytes = 15 * 1024 * 1024;

/// Cria/edita um video ou imagem de fundo da Ilha Top, com janela de
/// horario e modo fixo/aleatorio.
class IlhaBackgroundFormDialog extends StatefulWidget {
  const IlhaBackgroundFormDialog({super.key, this.existing});

  final Map<String, dynamic>? existing;

  @override
  State<IlhaBackgroundFormDialog> createState() => _IlhaBackgroundFormDialogState();
}

class _IlhaBackgroundFormDialogState extends State<IlhaBackgroundFormDialog> {
  final _service = IlhaTopService();
  final _labelController = TextEditingController();

  String? _mediaUrl;
  String _mediaType = "video";
  String? _previewImageUrl;
  TimeOfDay _startTime = const TimeOfDay(hour: 0, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 23, minute: 59);
  String _mode = "fixed";
  bool _isActive = true;
  bool _muted = false;
  double _volume = 1;
  bool _loopVideo = true;
  double _cropScale = 1;
  double _cropOffsetX = 0;
  double _cropOffsetY = 0;
  bool _uploading = false;
  bool _uploadingPreview = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _labelController.text = e["label"] as String? ?? "";
      _mediaUrl = e["media_url"] as String?;
      _mediaType = e["media_type"] as String? ?? "video";
      _previewImageUrl = e["preview_image_url"] as String?;
      _startTime = _parseTime(e["start_time"] as String?) ?? _startTime;
      _endTime = _parseTime(e["end_time"] as String?) ?? _endTime;
      _mode = e["mode"] as String? ?? "fixed";
      _isActive = e["is_active"] as bool? ?? true;
      _muted = e["muted"] as bool? ?? false;
      _volume = (e["volume"] as num?)?.toDouble() ?? 1;
      _loopVideo = e["loop_video"] as bool? ?? true;
      _cropScale = (e["crop_scale"] as num?)?.toDouble() ?? 1;
      _cropOffsetX = (e["crop_offset_x"] as num?)?.toDouble() ?? 0;
      _cropOffsetY = (e["crop_offset_y"] as num?)?.toDouble() ?? 0;
    }
  }

  TimeOfDay? _parseTime(String? value) {
    if (value == null) return null;
    final parts = value.split(":");
    if (parts.length < 2) return null;
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _formatTime(TimeOfDay t) => t.hour.toString().padLeft(2, "0") + ":" + t.minute.toString().padLeft(2, "0");

  /// Imagem estatica usada como base do corte: a propria imagem se o fundo
  /// for do tipo imagem, ou o print cadastrado se for video.
  String? get _referenceImageForCrop => _mediaType == "image" ? _mediaUrl : _previewImageUrl;

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(context: context, initialTime: isStart ? _startTime : _endTime);
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
    });
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.media, withData: true);
    if (result == null || result.files.single.bytes == null) return;
    final file = result.files.single;
    if (file.size > _maxFileSizeBytes) {
      setState(() => _error = "Arquivo muito grande (" + (file.size / (1024 * 1024)).toStringAsFixed(1) + "MB). O limite e 15MB.");
      return;
    }
    setState(() {
      _error = null;
      _uploading = true;
    });
    try {
      final url = await _service.uploadMedia(file);
      final ext = file.name.toLowerCase();
      setState(() {
        _mediaUrl = url;
        _mediaType = islandMediaLooksLikeVideo(ext) ? "video" : "image";
      });
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickPreviewFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result == null || result.files.single.bytes == null) return;
    final file = result.files.single;
    if (file.size > _maxFileSizeBytes) {
      setState(() => _error = "Arquivo muito grande (" + (file.size / (1024 * 1024)).toStringAsFixed(1) + "MB). O limite e 15MB.");
      return;
    }
    setState(() {
      _error = null;
      _uploadingPreview = true;
    });
    try {
      final url = await _service.uploadMedia(file);
      setState(() => _previewImageUrl = url);
    } catch (e) {
      if (mounted) setState(() => _error = "Erro ao enviar o print: " + e.toString());
    } finally {
      if (mounted) setState(() => _uploadingPreview = false);
    }
  }

  Future<void> _save() async {
    if (_labelController.text.trim().isEmpty || _mediaUrl == null) {
      setState(() => _error = "Preencha o nome e envie um arquivo.");
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _service.saveBackground(
        id: widget.existing?["id"] as String?,
        label: _labelController.text.trim(),
        mediaUrl: _mediaUrl!,
        mediaType: _mediaType,
        previewImageUrl: _previewImageUrl,
        startTime: _formatTime(_startTime),
        endTime: _formatTime(_endTime),
        mode: _mode,
        isActive: _isActive,
        muted: _muted,
        volume: _volume,
        loopVideo: _loopVideo,
        cropScale: _cropScale,
        cropOffsetX: _cropOffsetX,
        cropOffsetY: _cropOffsetY,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = "Erro ao salvar: " + e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 820),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.existing != null ? "Editar vídeo de fundo" : "Novo vídeo de fundo",
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: _labelController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: "Nome (ex: Ilha ao amanhecer)", labelStyle: TextStyle(color: Colors.white54)),
              ),
              const SizedBox(height: 16),
              Row(children: [
                OutlinedButton.icon(
                  onPressed: _uploading ? null : _pickFile,
                  icon: const Icon(Icons.upload_file, size: 16, color: Colors.white70),
                  label: Text(_uploading ? "Enviando..." : (_mediaUrl != null ? "Trocar arquivo" : "Escolher arquivo"), style: const TextStyle(color: Colors.white70)),
                ),
                if (_mediaUrl != null) ...[
                  const SizedBox(width: 10),
                  Icon(_mediaType == "video" ? Icons.movie : Icons.image, color: Colors.white54, size: 18),
                  const SizedBox(width: 4),
                  const Text("arquivo enviado", style: TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ]),
              if (_mediaType == "video") ...[
                const SizedBox(height: 16),
                const Text("Imagem de referência (print do vídeo)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                const Text(
                  "Opcional. Como o vídeo não toca no editor de posições do admin, envie um print/frame dele pra usar como referência visual na hora de posicionar cada avatar.",
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  OutlinedButton.icon(
                    onPressed: _uploadingPreview ? null : _pickPreviewFile,
                    icon: const Icon(Icons.image_outlined, size: 16, color: Colors.white70),
                    label: Text(_uploadingPreview ? "Enviando..." : (_previewImageUrl != null ? "Trocar print" : "Enviar print"), style: const TextStyle(color: Colors.white70)),
                  ),
                  if (_previewImageUrl != null) ...[
                    const SizedBox(width: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(_previewImageUrl!, width: 40, height: 40, fit: BoxFit.cover),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.redAccent, size: 16),
                      onPressed: () => setState(() => _previewImageUrl = null),
                    ),
                  ],
                ]),
              ],
              if (_referenceImageForCrop != null) ...[
                const SizedBox(height: 20),
                IlhaCropEditor(
                  imageUrl: _referenceImageForCrop!,
                  aspectRatio: 9 / 16,
                  scale: _cropScale,
                  offsetX: _cropOffsetX,
                  offsetY: _cropOffsetY,
                  onScaleChanged: (v) => setState(() => _cropScale = v),
                  onOffsetChanged: (x, y) => setState(() {
                    _cropOffsetX = x;
                    _cropOffsetY = y;
                  }),
                ),
              ],
              const SizedBox(height: 20),
              IlhaMediaPlaybackFields(
                muted: _muted,
                volume: _volume,
                loop: _loopVideo,
                onMutedChanged: (v) => setState(() => _muted = v),
                onVolumeChanged: (v) => setState(() => _volume = v),
                onLoopChanged: (v) => setState(() => _loopVideo = v),
              ),
              const SizedBox(height: 20),
              const Text("Janela de horário", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              const Text("Quando o streamer abrir o app dentro dessa faixa, esse fundo pode aparecer.", style: TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickTime(true),
                    child: Text("Início: " + _formatTime(_startTime), style: const TextStyle(color: Colors.white70)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickTime(false),
                    child: Text("Fim: " + _formatTime(_endTime), style: const TextStyle(color: Colors.white70)),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              const Text("Modo", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              RadioListTile<String>(
                value: "fixed",
                groupValue: _mode,
                dense: true,
                activeColor: const Color(0xFF7A0BD4),
                title: const Text("Fixo — sempre aparece nessa janela de horário", style: TextStyle(color: Colors.white70, fontSize: 13)),
                onChanged: (v) => setState(() => _mode = v!),
              ),
              RadioListTile<String>(
                value: "random",
                groupValue: _mode,
                dense: true,
                activeColor: const Color(0xFF7A0BD4),
                title: const Text("Aleatório — sorteado entre os fundos aleatórios dessa janela", style: TextStyle(color: Colors.white70, fontSize: 13)),
                onChanged: (v) => setState(() => _mode = v!),
              ),
              SwitchListTile(
                value: _isActive,
                dense: true,
                activeThumbColor: const Color(0xFF7A0BD4),
                title: const Text("Ativo", style: TextStyle(color: Colors.white70, fontSize: 13)),
                onChanged: (v) => setState(() => _isActive = v),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
              ],
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
    );
  }
}
