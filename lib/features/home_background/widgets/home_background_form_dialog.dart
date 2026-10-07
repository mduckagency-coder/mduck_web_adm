import "package:file_picker/file_picker.dart";
import "package:flutter/material.dart";
import "../home_background_service.dart";

const _maxFileSizeBytes = 15 * 1024 * 1024;
const _purple = Color(0xFF7A0BD4);

/// Cadastra um ou VARIOS videos de fundo da Home de uma vez (todos com a
/// mesma faixa de horario, modo e audio), ou edita um existente.
class HomeBackgroundFormDialog extends StatefulWidget {
  const HomeBackgroundFormDialog({
    super.key,
    this.existing,
    this.initialStart,
    this.initialEnd,
    this.initialCategory = homeCategoryNormal,
  });

  final Map<String, dynamic>? existing;

  /// Tipo ja selecionado quando o admin adiciona a partir da aba
  /// "Inatividade" ou "Vídeos normais".
  final String initialCategory;

  /// Faixa ja preenchida quando o admin clica em "Adicionar" dentro de uma
  /// faixa de horario da lista.
  final String? initialStart;
  final String? initialEnd;

  @override
  State<HomeBackgroundFormDialog> createState() => _HomeBackgroundFormDialogState();
}

class _PendingVideo {
  final TextEditingController label;
  final String url;
  _PendingVideo(String name, this.url) : label = TextEditingController(text: name);
}

class _HomeBackgroundFormDialogState extends State<HomeBackgroundFormDialog> {
  final _service = HomeBackgroundService();
  final List<_PendingVideo> _videos = [];
  final _overlayController = TextEditingController();
  String _category = homeCategoryNormal;

  bool get _isInactivity => _category == homeCategoryInactivity;

  TimeOfDay _startTime = const TimeOfDay(hour: 6, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 11, minute: 59);
  String _mode = "random";
  String _audioMode = "video";
  double _volume = 1;
  bool _isActive = true;
  String? _uploadProgress;
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _videos.add(_PendingVideo(e["label"] as String? ?? "", e["media_url"] as String));
      _startTime = _parseTime(e["start_time"] as String?) ?? _startTime;
      _endTime = _parseTime(e["end_time"] as String?) ?? _endTime;
      _mode = e["mode"] as String? ?? "random";
      _audioMode = e["audio_mode"] as String? ?? "video";
      _volume = (e["volume"] as num?)?.toDouble() ?? 1;
      _isActive = e["is_active"] as bool? ?? true;
      _category = e["category"] as String? ?? homeCategoryNormal;
      _overlayController.text = e["overlay_text"] as String? ?? "";
    } else {
      _category = widget.initialCategory;
      if (_isInactivity) {
        _overlayController.text = homeInactivityDefaultText;
        _startTime = const TimeOfDay(hour: 6, minute: 0);
        _endTime = const TimeOfDay(hour: 17, minute: 59);
      }
      _startTime = _parseTime(widget.initialStart) ?? _startTime;
      _endTime = _parseTime(widget.initialEnd) ?? _endTime;
    }
  }

  @override
  void dispose() {
    for (final v in _videos) {
      v.label.dispose();
    }
    _overlayController.dispose();
    super.dispose();
  }

  void _setCategory(String category) {
    setState(() {
      _category = category;
      if (_isInactivity && _overlayController.text.trim().isEmpty) {
        _overlayController.text = homeInactivityDefaultText;
      }
    });
  }

  TimeOfDay? _parseTime(String? value) {
    if (value == null) return null;
    final parts = value.split(":");
    if (parts.length < 2) return null;
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _formatTime(TimeOfDay t) => "${t.hour.toString().padLeft(2, "0")}:${t.minute.toString().padLeft(2, "0")}";

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(context: context, initialTime: isStart ? _startTime : _endTime);
    if (picked == null) return;
    setState(() => isStart ? _startTime = picked : _endTime = picked);
  }

  void _applyPreset(String start, String end) {
    setState(() {
      _startTime = _parseTime(start)!;
      _endTime = _parseTime(end)!;
    });
  }

  /// "pato_dormindo.mp4" -> "pato dormindo"
  String _nameFromFile(String fileName) {
    final dot = fileName.lastIndexOf(".");
    final base = dot > 0 ? fileName.substring(0, dot) : fileName;
    return base.replaceAll(RegExp(r"[_\-]+"), " ").trim();
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: homeBackgroundAllowedExtensions,
      allowMultiple: !_isEditing,
      withData: true,
    );
    if (result == null) return;
    final files = result.files.where((f) => f.bytes != null).toList();
    final tooBig = files.where((f) => f.size > _maxFileSizeBytes).map((f) => f.name).toList();
    final ok = files.where((f) => f.size <= _maxFileSizeBytes).toList();
    setState(() => _error = tooBig.isEmpty ? null : "Acima de 15MB (não enviados): ${tooBig.join(", ")}");
    if (ok.isEmpty) return;

    try {
      for (var i = 0; i < ok.length; i++) {
        setState(() => _uploadProgress = "Enviando ${i + 1} de ${ok.length}...");
        final url = await _service.uploadVideo(ok[i]);
        setState(() {
          if (_isEditing) {
            // editando: troca o arquivo mantendo o nome que ja estava
            final old = _videos.single;
            _videos[0] = _PendingVideo(old.label.text, url);
          } else {
            _videos.add(_PendingVideo(_nameFromFile(ok[i].name), url));
          }
        });
      }
    } catch (e) {
      setState(() => _error = "Erro ao enviar: $e");
    } finally {
      if (mounted) setState(() => _uploadProgress = null);
    }
  }

  Future<void> _save() async {
    if (_videos.isEmpty) {
      setState(() => _error = "Envie pelo menos um vídeo.");
      return;
    }
    if (_videos.any((v) => v.label.text.trim().isEmpty)) {
      setState(() => _error = "Dê um nome para cada vídeo.");
      return;
    }
    if (_isInactivity && _overlayController.text.trim().isEmpty) {
      setState(() => _error = "Escreva o texto que aparece sobre o vídeo de inatividade.");
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await _service.save(
        id: widget.existing?["id"] as String?,
        videos: [for (final v in _videos) (label: v.label.text.trim(), mediaUrl: v.url)],
        startTime: _formatTime(_startTime),
        endTime: _formatTime(_endTime),
        mode: _mode,
        audioMode: _audioMode,
        volume: _volume,
        isActive: _isActive,
        category: _category,
        overlayText: _overlayController.text,
      );
      // devolve as linhas salvas pra lista atualizar sem recarregar a pagina
      if (mounted) Navigator.of(context).pop(saved);
    } catch (e) {
      if (mounted) setState(() => _error = "Erro ao salvar: $e");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _sectionTitle(String text, [String? help]) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            if (help != null) ...[
              const SizedBox(height: 2),
              Text(help, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final start = _formatTime(_startTime);
    final end = _formatTime(_endTime);
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 820),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  _isEditing
                      ? (_isInactivity ? "Editar vídeo de inatividade" : "Editar vídeo de fundo")
                      : (_isInactivity ? "Adicionar vídeos de inatividade" : "Adicionar vídeos de fundo"),
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              if (!_isEditing)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    "Você pode escolher vários vídeos de uma vez: todos ficam com o mesmo horário, modo e áudio.",
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),

              // ---------------- Tipo ----------------
              _sectionTitle("Tipo do vídeo"),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: homeCategoryNormal, icon: Icon(Icons.wb_sunny_outlined, size: 16), label: Text("Normal")),
                  ButtonSegment(value: homeCategoryInactivity, icon: Icon(Icons.bedtime_outlined, size: 16), label: Text("Inatividade")),
                ],
                selected: {_category},
                onSelectionChanged: (s) => _setCategory(s.first),
                style: SegmentedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  selectedForegroundColor: Colors.white,
                  selectedBackgroundColor: _purple,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _isInactivity
                    ? "Aparece só para quem está há mais de 7 dias sem live, no lugar dos vídeos normais (ilha sem o pato). Quando o streamer volta a fazer live, ele volta sozinho para os normais."
                    : "Programação do dia a dia da Home, para streamers ativos.",
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              if (_isInactivity) ...[
                _sectionTitle("Texto sobre o vídeo", "Mensagem que aparece na Home por cima do vídeo de inatividade."),
                TextField(
                  controller: _overlayController,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 160,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: homeInactivityDefaultText,
                    hintStyle: TextStyle(color: Colors.white38),
                    counterStyle: TextStyle(color: Colors.white38),
                  ),
                ),
              ],

              // ---------------- Videos ----------------
              _sectionTitle(_isEditing ? "Vídeo" : "Vídeos", "MP4, MOV, WEBM ou M4V, até 15MB cada. No app o vídeo fica sempre em loop."),
              for (var i = 0; i < _videos.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    const Icon(Icons.movie, color: Colors.white54, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _videos[i].label,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: const InputDecoration(
                          isDense: true,
                          hintText: "Nome (ex: Pato dormindo na rede)",
                          hintStyle: TextStyle(color: Colors.white38),
                        ),
                      ),
                    ),
                    if (!_isEditing)
                      IconButton(
                        tooltip: "Remover da lista",
                        icon: const Icon(Icons.close, color: Colors.white38, size: 18),
                        onPressed: () => setState(() => _videos.removeAt(i).label.dispose()),
                      ),
                  ]),
                ),
              OutlinedButton.icon(
                onPressed: _uploadProgress != null ? null : _pickFiles,
                icon: const Icon(Icons.upload_file, size: 16, color: Colors.white70),
                label: Text(
                  _uploadProgress ??
                      (_isEditing ? "Trocar arquivo" : (_videos.isEmpty ? "Escolher vídeos" : "Adicionar mais vídeos")),
                  style: const TextStyle(color: Colors.white70),
                ),
              ),

              // ---------------- Horario ----------------
              _sectionTitle("Quando aparece", "Se o streamer abrir o app nessa faixa de horário, esse vídeo pode aparecer na Home."),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final p in _isInactivity ? homeInactivityPresets : homePeriodPresets)
                  ChoiceChip(
                    label: Text("${p.emoji} ${p.label}"),
                    selected: start == p.start && end == p.end,
                    selectedColor: _purple,
                    backgroundColor: Colors.white10,
                    labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
                    onSelected: (_) => _applyPreset(p.start, p.end),
                  ),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickTime(true),
                    child: Text("Início: $start", style: const TextStyle(color: Colors.white70)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickTime(false),
                    child: Text("Fim: $end", style: const TextStyle(color: Colors.white70)),
                  ),
                ),
              ]),

              // ---------------- Modo ----------------
              _sectionTitle("Modo"),
              RadioListTile<String>(
                value: "random",
                groupValue: _mode,
                dense: true,
                activeColor: _purple,
                title: const Text("Aleatório (recomendado)", style: TextStyle(color: Colors.white, fontSize: 13)),
                subtitle: const Text(
                  "Cada dia é sorteado um dos vídeos aleatórios dessa faixa para cada streamer. No mesmo dia ele vê sempre o mesmo; no dia seguinte pode ser outro.",
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                onChanged: (v) => setState(() => _mode = v!),
              ),
              RadioListTile<String>(
                value: "fixed",
                groupValue: _mode,
                dense: true,
                activeColor: _purple,
                title: const Text("Fixo", style: TextStyle(color: Colors.white, fontSize: 13)),
                subtitle: const Text(
                  "Aparece sempre nessa faixa e passa na frente dos aleatórios (ex: um vídeo especial de uma data).",
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                onChanged: (v) => setState(() => _mode = v!),
              ),

              // ---------------- Audio ----------------
              _sectionTitle("Som"),
              RadioListTile<String>(
                value: "video",
                groupValue: _audioMode,
                dense: true,
                activeColor: _purple,
                title: const Text("Som do próprio vídeo", style: TextStyle(color: Colors.white, fontSize: 13)),
                onChanged: (v) => setState(() => _audioMode = v!),
              ),
              if (_audioMode == "video")
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Row(children: [
                    const Icon(Icons.volume_down, color: Colors.white54, size: 18),
                    Expanded(
                      child: Slider(
                        value: _volume,
                        activeColor: _purple,
                        onChanged: (v) => setState(() => _volume = v),
                      ),
                    ),
                    Text("${(_volume * 100).round()}%", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ]),
                ),
              RadioListTile<String>(
                value: "default",
                groupValue: _audioMode,
                dense: true,
                activeColor: _purple,
                title: const Text("Áudio padrão da Home", style: TextStyle(color: Colors.white, fontSize: 13)),
                subtitle: const Text("Tira o som do vídeo e toca o áudio padrão configurado no topo da página.",
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
                onChanged: (v) => setState(() => _audioMode = v!),
              ),
              RadioListTile<String>(
                value: "mute",
                groupValue: _audioMode,
                dense: true,
                activeColor: _purple,
                title: const Text("Sem som", style: TextStyle(color: Colors.white, fontSize: 13)),
                onChanged: (v) => setState(() => _audioMode = v!),
              ),

              SwitchListTile(
                value: _isActive,
                dense: true,
                activeThumbColor: _purple,
                contentPadding: EdgeInsets.zero,
                title: const Text("Ativo", style: TextStyle(color: Colors.white70, fontSize: 13)),
                subtitle: const Text("Desligado, o vídeo fica guardado mas não aparece no app.",
                    style: TextStyle(color: Colors.white38, fontSize: 11)),
                onChanged: (v) => setState(() => _isActive = v),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
              ],
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancelar")),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _saving || _uploadProgress != null ? null : _save,
                  style: ElevatedButton.styleFrom(backgroundColor: _purple, foregroundColor: Colors.white),
                  child: Text(_saving
                      ? "Salvando..."
                      : (!_isEditing && _videos.length > 1 ? "Salvar ${_videos.length} vídeos" : "Salvar")),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
