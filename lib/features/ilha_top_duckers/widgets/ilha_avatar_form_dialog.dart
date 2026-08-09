import "package:file_picker/file_picker.dart";
import "package:flutter/material.dart";
import "../ilha_top_service.dart";
import "ilha_avatar_display_fields.dart";
import "ilha_crop_editor.dart";
import "ilha_media_playback_fields.dart";

const _maxFileSizeBytes = 15 * 1024 * 1024;

/// Cria/edita um avatar "pato" do banco que o streamer escolhe no app dele,
/// com elegibilidade (categoria + diamantes minimos), genero e raridade.
class IlhaAvatarFormDialog extends StatefulWidget {
  const IlhaAvatarFormDialog({super.key, this.existing});

  final Map<String, dynamic>? existing;

  @override
  State<IlhaAvatarFormDialog> createState() => _IlhaAvatarFormDialogState();
}

class _IlhaAvatarFormDialogState extends State<IlhaAvatarFormDialog> {
  final _service = IlhaTopService();
  final _labelController = TextEditingController();
  final _minDiamondsController = TextEditingController(text: "0");

  String? _mediaUrl;
  String? _previewImageUrl;
  bool _isActive = true;
  bool _muted = false;
  double _volume = 1;
  bool _loopVideo = true;
  double _cropScale = 1;
  double _cropOffsetX = 0;
  double _cropOffsetY = 0;
  String _displayShape = "circle_border";
  String _borderColor = "#FFFFFF";
  String _sizeMode = "default";
  double _sizePercent = 100;
  String? _defaultScope;
  bool _uploading = false;
  bool _uploadingPreview = false;
  bool _saving = false;
  bool _loadingCategories = true;
  String? _error;
  String? _gender;
  String _rarity = "comum";
  Set<String> _selectedCategoryIds = {};
  List<Map<String, dynamic>> _allCategories = [];
  bool _restrictToCategories = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _labelController.text = e["label"] as String? ?? "";
      _mediaUrl = e["media_url"] as String?;
      _previewImageUrl = e["preview_image_url"] as String?;
      _isActive = e["is_active"] as bool? ?? true;
      _minDiamondsController.text = (e["min_diamonds"] as int? ?? 0).toString();
      _gender = e["gender"] as String?;
      _rarity = e["rarity"] as String? ?? "comum";
      final cats = e["category_ids"];
      if (cats is List) _selectedCategoryIds = cats.map((c) => c as String).toSet();
      _restrictToCategories = _selectedCategoryIds.isNotEmpty;
      _muted = e["muted"] as bool? ?? false;
      _volume = (e["volume"] as num?)?.toDouble() ?? 1;
      _loopVideo = e["loop_video"] as bool? ?? true;
      _cropScale = (e["crop_scale"] as num?)?.toDouble() ?? 1;
      _cropOffsetX = (e["crop_offset_x"] as num?)?.toDouble() ?? 0;
      _cropOffsetY = (e["crop_offset_y"] as num?)?.toDouble() ?? 0;
      _displayShape = e["display_shape"] as String? ?? "circle_border";
      _borderColor = e["border_color"] as String? ?? "#FFFFFF";
      _sizeMode = e["size_mode"] as String? ?? "default";
      _sizePercent = (e["size_percent"] as num?)?.toDouble() ?? 100;
      _defaultScope = e["default_scope"] as String?;
    }
    _loadCategories();
  }

  bool get _mediaIsVideo => _mediaUrl != null && islandMediaLooksLikeVideo(_mediaUrl!);

  /// Imagem estatica usada como base do corte: o proprio arquivo se ja for
  /// imagem, ou o print cadastrado se for video.
  String? get _referenceImageForCrop => _mediaIsVideo ? _previewImageUrl : _mediaUrl;

  Future<void> _loadCategories() async {
    final categories = await _service.fetchCategories();
    if (mounted) {
      setState(() {
        _allCategories = categories;
        _loadingCategories = false;
      });
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: islandMediaAllowedExtensions, withData: true);
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
      setState(() => _mediaUrl = url);
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
    if (_gender == null) {
      setState(() => _error = "Escolha se o avatar é feminino ou masculino.");
      return;
    }
    if (_defaultScope == "category" && _selectedCategoryIds.isEmpty) {
      setState(() => _error = "Escolha ao menos uma categoria em \"Quem pode escolher\" pra usar como padrão por categoria.");
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _service.saveAvatar(
        id: widget.existing?["id"] as String?,
        label: _labelController.text.trim(),
        mediaUrl: _mediaUrl!,
        previewImageUrl: _previewImageUrl,
        isActive: _isActive,
        minDiamonds: int.tryParse(_minDiamondsController.text.trim()) ?? 0,
        categoryIds: _selectedCategoryIds.toList(),
        gender: _gender,
        rarity: _rarity,
        muted: _muted,
        volume: _volume,
        loopVideo: _loopVideo,
        cropScale: _cropScale,
        cropOffsetX: _cropOffsetX,
        cropOffsetY: _cropOffsetY,
        displayShape: _displayShape,
        borderColor: _borderColor,
        sizeMode: _sizeMode,
        sizePercent: _sizePercent,
        defaultScope: _defaultScope,
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
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 860),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.existing != null ? "Editar avatar" : "Novo avatar (pato)",
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text("Vídeo em loop que o streamer escolhe no app. Se ele ficar no ranking, o avatar aparece no local do slot dele na ilha.",
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 16),
              TextField(
                controller: _labelController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: "Nome (ex: Pato dourado)", labelStyle: TextStyle(color: Colors.white54)),
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
                  const Icon(Icons.movie, color: Colors.white54, size: 18),
                  const SizedBox(width: 4),
                  const Text("arquivo enviado", style: TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ]),
              const SizedBox(height: 6),
              const Text(
                "Formatos aceitos: MP4, MOV, WEBM, M4V, GIF, WEBP, PNG, JPG. Vídeo comum (MP4/MOV/WEBM) não sustenta fundo transparente em nenhum player -- pra avatar com fundo transparente use GIF ou WEBP animado, ou PNG estático se não precisar de animação.",
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
              if (_mediaUrl != null && !islandMediaSupportsTransparency(_mediaUrl!) && islandMediaLooksLikeVideo(_mediaUrl!)) ...[
                const SizedBox(height: 6),
                Row(children: const [
                  Icon(Icons.warning_amber, color: Colors.amberAccent, size: 14),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "Esse formato de vídeo não mantém fundo transparente no app. Se precisar de transparência, troque por um GIF ou WEBP animado.",
                      style: TextStyle(color: Colors.amberAccent, fontSize: 11),
                    ),
                  ),
                ]),
              ],
              if (_mediaIsVideo) ...[
                const SizedBox(height: 16),
                const Text("Imagem de referência (print do vídeo)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                const Text(
                  "Como o vídeo não toca aqui no admin, envie um print/frame dele pra habilitar o corte abaixo.",
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
              const SizedBox(height: 20),
              if (_referenceImageForCrop != null)
                IlhaCropEditor(
                  imageUrl: _referenceImageForCrop!,
                  aspectRatio: 1,
                  fit: BoxFit.contain,
                  scale: _cropScale,
                  offsetX: _cropOffsetX,
                  offsetY: _cropOffsetY,
                  onScaleChanged: (v) => setState(() => _cropScale = v),
                  onOffsetChanged: (x, y) => setState(() {
                    _cropOffsetX = x;
                    _cropOffsetY = y;
                  }),
                )
              else if (_mediaUrl != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white24)),
                  child: const Row(children: [
                    Icon(Icons.crop, color: Colors.white38, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text("Envie o print acima pra habilitar o corte (arrastar + zoom) sobre o vídeo.", style: TextStyle(color: Colors.white54, fontSize: 12)),
                    ),
                  ]),
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
              IlhaAvatarDisplayFields(
                displayShape: _displayShape,
                borderColor: _borderColor,
                sizeMode: _sizeMode,
                sizePercent: _sizePercent,
                onDisplayShapeChanged: (v) => setState(() => _displayShape = v),
                onBorderColorChanged: (v) => setState(() => _borderColor = v),
                onSizeModeChanged: (v) => setState(() => _sizeMode = v),
                onSizePercentChanged: (v) => setState(() => _sizePercent = v),
              ),
              const SizedBox(height: 20),
              const Text("Gênero", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                ChoiceChip(
                  label: const Text("Feminino"),
                  selected: _gender == "feminino",
                  selectedColor: const Color(0xFF7A0BD4),
                  labelStyle: TextStyle(color: _gender == "feminino" ? Colors.white : Colors.white70),
                  onSelected: (_) => setState(() => _gender = "feminino"),
                ),
                ChoiceChip(
                  label: const Text("Masculino"),
                  selected: _gender == "masculino",
                  selectedColor: const Color(0xFF7A0BD4),
                  labelStyle: TextStyle(color: _gender == "masculino" ? Colors.white : Colors.white70),
                  onSelected: (_) => setState(() => _gender = "masculino"),
                ),
              ]),
              const SizedBox(height: 20),
              const Text("Raridade da skin", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              DropdownButton<String>(
                value: _rarity,
                dropdownColor: const Color(0xFF1A1A1A),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                items: [for (final r in islandAvatarRarities) DropdownMenuItem(value: r.$1, child: Text(r.$2))],
                onChanged: (v) => setState(() => _rarity = v!),
              ),
              const SizedBox(height: 20),
              const Text("Diamantes mínimos no mês", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              const Text("Quantos diamantes o streamer precisa ter pra essa opção de avatar aparecer pra ele escolher. 0 = sem restrição extra.",
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 8),
              TextField(
                controller: _minDiamondsController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: "Diamantes mínimos", labelStyle: TextStyle(color: Colors.white54)),
              ),
              const SizedBox(height: 20),
              const Text("Quem pode escolher", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                ChoiceChip(
                  label: const Text("Todos"),
                  selected: !_restrictToCategories,
                  selectedColor: const Color(0xFF7A0BD4),
                  labelStyle: TextStyle(color: !_restrictToCategories ? Colors.white : Colors.white70),
                  onSelected: (_) => setState(() {
                    _restrictToCategories = false;
                    _selectedCategoryIds.clear();
                    if (_defaultScope == "category") _defaultScope = null;
                  }),
                ),
                ChoiceChip(
                  label: const Text("Categorias específicas"),
                  selected: _restrictToCategories,
                  selectedColor: const Color(0xFF7A0BD4),
                  labelStyle: TextStyle(color: _restrictToCategories ? Colors.white : Colors.white70),
                  onSelected: (_) => setState(() => _restrictToCategories = true),
                ),
              ]),
              if (_restrictToCategories) ...[
                const SizedBox(height: 8),
                _loadingCategories
                    ? const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                    : _allCategories.isEmpty
                        ? const Text("Nenhuma categoria cadastrada ainda.", style: TextStyle(color: Colors.white38, fontSize: 12))
                        : Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              for (final c in _allCategories)
                                FilterChip(
                                  label: Text(c["name"] as String),
                                  selected: _selectedCategoryIds.contains(c["id"] as String),
                                  selectedColor: const Color(0xFF7A0BD4),
                                  labelStyle: TextStyle(color: _selectedCategoryIds.contains(c["id"] as String) ? Colors.white : Colors.white70, fontSize: 12),
                                  onSelected: (selected) => setState(() {
                                    if (selected) {
                                      _selectedCategoryIds.add(c["id"] as String);
                                    } else {
                                      _selectedCategoryIds.remove(c["id"] as String);
                                    }
                                  }),
                                ),
                            ],
                          ),
              ],
              const SizedBox(height: 20),
              const Text("Avatar padrão", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              const Text("Usado quando o streamer ainda não escolheu nenhum avatar (ou perdeu o que tinha, ex: se o avatar escolhido foi excluído).",
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                ChoiceChip(
                  label: const Text("Não é padrão"),
                  selected: _defaultScope == null,
                  selectedColor: const Color(0xFF7A0BD4),
                  labelStyle: TextStyle(color: _defaultScope == null ? Colors.white : Colors.white70, fontSize: 12),
                  onSelected: (_) => setState(() => _defaultScope = null),
                ),
                ChoiceChip(
                  label: const Text("Padrão para todos"),
                  selected: _defaultScope == "all",
                  selectedColor: const Color(0xFF7A0BD4),
                  labelStyle: TextStyle(color: _defaultScope == "all" ? Colors.white : Colors.white70, fontSize: 12),
                  onSelected: (_) => setState(() => _defaultScope = "all"),
                ),
                ChoiceChip(
                  label: const Text("Padrão por categoria"),
                  selected: _defaultScope == "category",
                  selectedColor: const Color(0xFF7A0BD4),
                  labelStyle: TextStyle(color: _defaultScope == "category" ? Colors.white : Colors.white70, fontSize: 12),
                  onSelected: _restrictToCategories ? (_) => setState(() => _defaultScope = "category") : null,
                ),
              ]),
              if (!_restrictToCategories)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text("Escolha \"Categorias específicas\" acima pra usar \"Padrão por categoria\".", style: TextStyle(color: Colors.white38, fontSize: 11)),
                ),
              if (_defaultScope == "all")
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text("Só pode haver um avatar padrão \"para todos\" por agência -- ao salvar, o anterior deixa de ser padrão automaticamente.",
                      style: TextStyle(color: Colors.amberAccent, fontSize: 11)),
                ),
              if (_defaultScope == "category")
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text("Só pode haver um avatar padrão por categoria -- ao salvar, qualquer outro avatar padrão dessas categorias deixa de ser padrão automaticamente.",
                      style: TextStyle(color: Colors.amberAccent, fontSize: 11)),
                ),
              SwitchListTile(
                value: _isActive,
                dense: true,
                contentPadding: EdgeInsets.zero,
                activeThumbColor: const Color(0xFF7A0BD4),
                title: const Text("Ativo (disponível pro streamer escolher)", style: TextStyle(color: Colors.white70, fontSize: 13)),
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
