import "package:file_picker/file_picker.dart";
import "package:flutter/material.dart";
import "../novidades_home_service.dart";

const _purple = Color(0xFF7A0BD4);
const _maxImageBytes = 5 * 1024 * 1024;

/// Cadastra ou edita uma novidade da Home (titulo, texto, imagem opcional,
/// datas, status, publico e link opcional). Devolve a linha salva.
class NovidadeFormDialog extends StatefulWidget {
  const NovidadeFormDialog({super.key, this.existing, required this.groups, required this.streamers});

  final Map<String, dynamic>? existing;
  final List<NewsAudienceOption> groups;
  final List<NewsAudienceOption> streamers;

  @override
  State<NovidadeFormDialog> createState() => _NovidadeFormDialogState();
}

class _NovidadeFormDialogState extends State<NovidadeFormDialog> {
  final _service = NovidadesHomeService();
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _linkUrl = TextEditingController();
  final _linkLabel = TextEditingController();

  String? _imageUrl;
  DateTime _publishedAt = DateTime.now();
  DateTime? _expiresAt;
  bool _isActive = true;
  String _targetType = newsTargetAll;
  String? _targetId;
  bool _showLink = false;
  bool _uploading = false;
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _title.text = e["title"] as String? ?? "";
      _body.text = e["body"] as String? ?? "";
      _imageUrl = e["image_url"] as String?;
      _linkUrl.text = e["link_url"] as String? ?? "";
      _linkLabel.text = e["link_label"] as String? ?? "";
      _publishedAt = DateTime.tryParse(e["published_at"] as String? ?? "")?.toLocal() ?? _publishedAt;
      final exp = e["expires_at"] as String?;
      _expiresAt = exp == null ? null : DateTime.tryParse(exp)?.toLocal();
      _isActive = e["is_active"] as bool? ?? true;
      _targetType = e["target_type"] as String? ?? newsTargetAll;
      _targetId = e["target_id"] as String?;
      _showLink = _linkUrl.text.isNotEmpty;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _linkUrl.dispose();
    _linkLabel.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) =>
      "${d.day.toString().padLeft(2, "0")}/${d.month.toString().padLeft(2, "0")}/${d.year} "
      "${d.hour.toString().padLeft(2, "0")}:${d.minute.toString().padLeft(2, "0")}";

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: newsImageExtensions, withData: true);
    if (result == null || result.files.single.bytes == null) return;
    final file = result.files.single;
    if (file.size > _maxImageBytes) {
      setState(() => _error = "Imagem acima de 5MB.");
      return;
    }
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final url = await _service.uploadImage(file);
      setState(() => _imageUrl = url);
    } catch (e) {
      setState(() => _error = "Erro ao enviar a imagem: $e");
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty || _body.text.trim().isEmpty) {
      setState(() => _error = "Preencha o título e o texto.");
      return;
    }
    if (_targetType != newsTargetAll && _targetId == null) {
      setState(() => _error = _targetType == newsTargetGroup ? "Escolha o grupo." : "Escolha o streamer.");
      return;
    }
    if (_expiresAt != null && !_expiresAt!.isAfter(_publishedAt)) {
      setState(() => _error = "A data de expiração precisa ser depois da publicação.");
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await _service.save(
        id: widget.existing?["id"] as String?,
        title: _title.text,
        body: _body.text,
        imageUrl: _imageUrl,
        linkUrl: _showLink ? _linkUrl.text : null,
        linkLabel: _showLink ? _linkLabel.text : null,
        publishedAt: _publishedAt,
        expiresAt: _expiresAt,
        isActive: _isActive,
        targetType: _targetType,
        targetId: _targetId,
      );
      if (mounted) Navigator.of(context).pop(saved);
    } catch (e) {
      if (mounted) setState(() => _error = "Erro ao salvar: $e");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _section(String text, [String? help]) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          if (help != null) Text(help, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ]),
      );

  InputDecoration _input(String hint) => InputDecoration(
        border: const OutlineInputBorder(),
        isDense: true,
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        counterStyle: const TextStyle(color: Colors.white38),
      );

  Widget _audienceSelector() {
    if (_targetType == newsTargetGroup) {
      return DropdownButtonFormField<String>(
        initialValue: widget.groups.any((g) => g.id == _targetId) ? _targetId : null,
        dropdownColor: const Color(0xFF2A2A2A),
        style: const TextStyle(color: Colors.white),
        decoration: _input("Escolha o grupo"),
        items: [for (final g in widget.groups) DropdownMenuItem(value: g.id, child: Text(g.name))],
        onChanged: (v) => setState(() => _targetId = v),
      );
    }
    if (_targetType == newsTargetIndividual) {
      final current = widget.streamers.where((s) => s.id == _targetId).firstOrNull;
      return Autocomplete<NewsAudienceOption>(
        initialValue: TextEditingValue(text: current?.name ?? ""),
        displayStringForOption: (o) => o.name,
        optionsBuilder: (value) {
          final q = value.text.toLowerCase().replaceAll("@", "").trim();
          if (q.isEmpty) return widget.streamers.take(30);
          return widget.streamers.where((s) => s.name.toLowerCase().contains(q)).take(30);
        },
        onSelected: (o) => setState(() => _targetId = o.id),
        fieldViewBuilder: (context, controller, focus, onSubmit) => TextField(
          controller: controller,
          focusNode: focus,
          style: const TextStyle(color: Colors.white),
          decoration: _input("Digite o nome do streamer (ex: gidreams_)"),
          onChanged: (_) => setState(() => _targetId = null),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 860),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_isEditing ? "Editar novidade" : "Nova novidade",
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const Text("Aparece no pergaminho 📜 da Home do app. Não gera notificação no sino.",
                  style: TextStyle(color: Colors.white54, fontSize: 12)),

              _section("Título"),
              TextField(
                controller: _title,
                maxLength: 80,
                style: const TextStyle(color: Colors.white),
                decoration: _input("Ex: Nova parceria disponível"),
              ),
              _section("Texto"),
              TextField(
                controller: _body,
                minLines: 3,
                maxLines: 8,
                maxLength: 800,
                style: const TextStyle(color: Colors.white),
                decoration: _input("Ex: Fechamos uma nova parceria para a agência. Confira as informações no grupo."),
              ),

              _section("Imagem (opcional)", "PNG, JPG, WEBP ou GIF até 5MB."),
              Row(children: [
                if (_imageUrl != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(_imageUrl!, width: 72, height: 72, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 10),
                ],
                OutlinedButton.icon(
                  onPressed: _uploading ? null : _pickImage,
                  icon: const Icon(Icons.image, size: 16, color: Colors.white70),
                  label: Text(_uploading ? "Enviando..." : (_imageUrl == null ? "Escolher imagem" : "Trocar imagem"),
                      style: const TextStyle(color: Colors.white70)),
                ),
                if (_imageUrl != null)
                  TextButton(
                    onPressed: () => setState(() => _imageUrl = null),
                    child: const Text("Remover", style: TextStyle(color: Colors.redAccent)),
                  ),
              ]),

              _section("Publicação"),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final d = await _pickDateTime(_publishedAt);
                      if (d != null) setState(() => _publishedAt = d);
                    },
                    icon: const Icon(Icons.event, size: 16, color: Colors.white70),
                    label: Text("Publicar em: ${_fmt(_publishedAt)}", style: const TextStyle(color: Colors.white70)),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final d = await _pickDateTime(_expiresAt ?? _publishedAt.add(const Duration(days: 7)));
                      if (d != null) setState(() => _expiresAt = d);
                    },
                    icon: const Icon(Icons.event_busy, size: 16, color: Colors.white70),
                    label: Text(_expiresAt == null ? "Sem data de expiração" : "Expira em: ${_fmt(_expiresAt!)}",
                        style: const TextStyle(color: Colors.white70)),
                  ),
                ),
                if (_expiresAt != null)
                  IconButton(
                    tooltip: "Tirar expiração",
                    icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                    onPressed: () => setState(() => _expiresAt = null),
                  ),
              ]),
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text("Data futura = a novidade só aparece no app a partir dela. Depois de expirar, some do app mas continua no histórico.",
                    style: TextStyle(color: Colors.white38, fontSize: 11)),
              ),

              _section("Público"),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: newsTargetAll, icon: Icon(Icons.groups, size: 16), label: Text("Todos")),
                  ButtonSegment(value: newsTargetGroup, icon: Icon(Icons.group_work, size: 16), label: Text("Grupo")),
                  ButtonSegment(value: newsTargetIndividual, icon: Icon(Icons.person, size: 16), label: Text("Streamer")),
                ],
                selected: {_targetType},
                onSelectionChanged: (s) => setState(() {
                  _targetType = s.first;
                  _targetId = null;
                }),
                style: SegmentedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  selectedForegroundColor: Colors.white,
                  selectedBackgroundColor: _purple,
                ),
              ),
              const SizedBox(height: 8),
              _audienceSelector(),

              const SizedBox(height: 8),
              CheckboxListTile(
                value: _showLink,
                dense: true,
                contentPadding: EdgeInsets.zero,
                activeColor: _purple,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text("Adicionar link / ação (opcional)", style: TextStyle(color: Colors.white70, fontSize: 13)),
                onChanged: (v) => setState(() => _showLink = v ?? false),
              ),
              if (_showLink) ...[
                TextField(
                  controller: _linkUrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: _input("https://..."),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _linkLabel,
                  maxLength: 30,
                  style: const TextStyle(color: Colors.white),
                  decoration: _input("Texto do botão (ex: Ver detalhes)"),
                ),
              ],

              SwitchListTile(
                value: _isActive,
                dense: true,
                contentPadding: EdgeInsets.zero,
                activeThumbColor: _purple,
                title: const Text("Ativo", style: TextStyle(color: Colors.white70, fontSize: 13)),
                subtitle: const Text("Inativo some do app, mas continua guardado no histórico.",
                    style: TextStyle(color: Colors.white38, fontSize: 11)),
                onChanged: (v) => setState(() => _isActive = v),
              ),
              if (_error != null) Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancelar")),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _saving || _uploading ? null : _save,
                  style: ElevatedButton.styleFrom(backgroundColor: _purple, foregroundColor: Colors.white),
                  child: Text(_saving ? "Salvando..." : (_isEditing ? "Salvar" : "Publicar")),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
