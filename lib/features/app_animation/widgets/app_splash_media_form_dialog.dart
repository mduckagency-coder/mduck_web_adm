import "package:file_picker/file_picker.dart";
import "package:flutter/material.dart";
import "../../ilha_top_duckers/widgets/ilha_media_playback_fields.dart";
import "../app_splash_media_service.dart";

const _maxFileSizeBytes = 15 * 1024 * 1024;

/// Cria/edita um video ou imagem de Carregamento ou Introducao do app, com
/// janela de horario e modo fixo/aleatorio -- mesmo esquema dos fundos da
/// Ilha Top.
class AppSplashMediaFormDialog extends StatefulWidget {
  const AppSplashMediaFormDialog({super.key, required this.kind, required this.kindLabel, this.existing});

  final String kind;
  final String kindLabel;
  final Map<String, dynamic>? existing;

  @override
  State<AppSplashMediaFormDialog> createState() => _AppSplashMediaFormDialogState();
}

class _AppSplashMediaFormDialogState extends State<AppSplashMediaFormDialog> {
  final _service = AppSplashMediaService();
  final _labelController = TextEditingController();

  String? _mediaUrl;
  String _mediaType = "video";
  TimeOfDay _startTime = const TimeOfDay(hour: 0, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 23, minute: 59);
  String _mode = "fixed";
  bool _isActive = true;
  bool _muted = false;
  double _volume = 1;
  bool _loopVideo = false;
  bool _uploading = false;
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
      _startTime = _parseTime(e["start_time"] as String?) ?? _startTime;
      _endTime = _parseTime(e["end_time"] as String?) ?? _endTime;
      _mode = e["mode"] as String? ?? "fixed";
      _isActive = e["is_active"] as bool? ?? true;
      _muted = e["muted"] as bool? ?? false;
      _volume = (e["volume"] as num?)?.toDouble() ?? 1;
      _loopVideo = e["loop_video"] as bool? ?? false;
    }
  }

  TimeOfDay? _parseTime(String? value) {
    if (value == null) return null;
    final parts = value.split(":");
    if (parts.length < 2) return null;
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _formatTime(TimeOfDay t) => t.hour.toString().padLeft(2, "0") + ":" + t.minute.toString().padLeft(2, "0");

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
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: splashMediaAllowedExtensions, withData: true);
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
      setState(() {
        _mediaUrl = url;
        _mediaType = splashMediaLooksLikeVideo(url) ? "video" : "image";
      });
    } finally {
      if (mounted) setState(() => _uploading = false);
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
      await _service.saveMedia(
        id: widget.existing?["id"] as String?,
        kind: widget.kind,
        label: _labelController.text.trim(),
        mediaUrl: _mediaUrl!,
        mediaType: _mediaType,
        startTime: _formatTime(_startTime),
        endTime: _formatTime(_endTime),
        mode: _mode,
        isActive: _isActive,
        muted: _muted,
        volume: _volume,
        loopVideo: _loopVideo,
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
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 780),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.existing != null ? "Editar " + widget.kindLabel.toLowerCase() : "Novo(a) " + widget.kindLabel.toLowerCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: _labelController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: "Nome (ex: Abertura de fim de ano)", labelStyle: TextStyle(color: Colors.white54)),
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
              const SizedBox(height: 6),
              const Text(
                "Formatos aceitos: MP4, MOV, WEBM, M4V, GIF, WEBP, PNG, JPG.",
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
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
              const Text("Quando o streamer abrir o app dentro dessa faixa, esse vídeo pode aparecer.", style: TextStyle(color: Colors.white54, fontSize: 12)),
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
                title: const Text("Aleatório — sorteado entre os vídeos aleatórios dessa janela", style: TextStyle(color: Colors.white70, fontSize: 13)),
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
