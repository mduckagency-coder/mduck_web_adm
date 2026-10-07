// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import "dart:async";
import "dart:html" as html;
import "dart:math" as math;
import "dart:typed_data";

import "package:flutter/material.dart";

import "../../core/upload_optimizer.dart";
import "academia_admin_service.dart";
import "app_ui/data/academy_models.dart";
import "app_ui/data/academy_repository.dart";
import "app_ui/ui/academy_interactive.dart";
import "app_ui/ui/academy_lesson_page.dart";
import "app_ui/ui/live_scenes.dart";

const _card = Color(0xFF1B1626);
const _purple = Color(0xFF7A0BD4);
const _gold = Color(0xFFFFC94D);

/// Tipos de bloco que a equipe pode montar numa aula.
const blockTypes = <String, (String, String)>{
  "text": ("📖", "Texto (O que é / Como funciona...)"),
  "platform": ("🎵", "Como o TikTok funciona (informação oficial)"),
  "tip": ("💡", "Dica MDuck"),
  "strategy": ("🧪", "Experiência / estratégia MDuck"),
  "image": ("🖼️", "Imagem / GIF"),
  "youtube": ("▶️", "Vídeo do YouTube"),
  "video": ("🎬", "Vídeo (arquivo)"),
  "steps": ("🪜", "Passo a passo"),
  "example": ("📌", "Exemplo"),
  "discover": ("👆", "Toque para descobrir"),
  "flow": ("➡️", "Fluxo animado (A → B → C)"),
  "simulation": ("✨", "Simulação de LIVE"),
  "identify": ("🎯", "Identifique na tela"),
  "quiz": ("🧩", "Quiz"),
  "checklist": ("✅", "Checklist"),
  "challenge": ("🎯", "Coloque em prática (desafio)"),
  "tiktok_profile": ("📱", "Batalha + perfil interativo (TikTok)"),
  "league_ladder": ("🏆", "Classes da Liga (D5 … A1)"),
  "gift_gallery": ("🎁", "Galeria de Presentes interativa"),
  "feed": ("💬", "Sequência animada (ex.: disputa)"),
  "recap": ("🎉", "Resumo final (Agora você já sabe)"),
  "live_menu": ("⋯", "LIVE + menu de recursos (achar um item)"),
  "tiktok_sheet": ("📲", "Tela do TikTok (Baú, Portal, Sacola...)"),
  "compare": ("⚖️", "Comparação (qual usar?)"),
  "viewer_view": ("👀", "Visão do espectador (ícones na LIVE)"),
};

Map<String, dynamic> newBlock(String type) => switch (type) {
      "text" => {"type": type, "label": "O que é?", "body": ""},
      "platform" => {"type": type, "title": "Como o TikTok funciona", "body": "", "varies": true},
      "steps" => {"type": type, "title": "Como fazer", "items": <String>[]},
      "discover" || "flow" => {"type": type, "title": "", "items": <Map<String, dynamic>>[]},
      "simulation" => {"type": type, "scene": "batalha", "title": "Toque nos elementos da LIVE", "hotspots": <String, dynamic>{}},
      "identify" => {"type": type, "scene": "games", "title": "Toque na parte certa da tela", "prompts": <Map<String, dynamic>>[]},
      "quiz" => {"type": type, "question": "", "options": <String>["", ""], "correct": 0, "explanation": ""},
      "checklist" => {"type": type, "title": "Checklist", "items": <String>[]},
      "tiktok_profile" => {"type": type, "title": "Você está em uma Batalha", "name": "Lucas Martins", "handle": "lucasmartins.live", "league": "A1", "spots": <String, dynamic>{}},
      "league_ladder" => {"type": type, "title": "Do D5 ao A1", "top": "A1", "groups": [
          {"letter": "D", "tiers": "D5, D4, D3, D2, D1", "body": ""},
          {"letter": "C", "tiers": "C5, C4, C3, C2, C1", "body": ""},
          {"letter": "B", "tiers": "B5, B4, B3, B2, B1", "body": ""},
          {"letter": "A", "tiers": "A3, A2, A1", "body": ""},
        ]},
      "gift_gallery" => {"type": type, "title": "Explore a Galeria", "owner": "Lucas Martins", "league": "A1", "gifts": <Map<String, dynamic>>[]},
      "feed" => {"type": type, "title": "", "items": <Map<String, dynamic>>[]},
      "recap" => {"type": type, "title": "🎉 Agora você já sabe:", "items": <String>[]},
      "live_menu" => {"type": type, "title": "Onde fica?", "host": "Lucas Martins", "target": "", "items": <Map<String, dynamic>>[], "chat": <Map<String, dynamic>>[]},
      "tiktok_sheet" => {"type": type, "title": "", "sheet_title": "", "button": "Enviar", "elements": <Map<String, dynamic>>[], "send_steps": <Map<String, dynamic>>[]},
      "compare" => {"type": type, "title": "Qual usar?", "items": <Map<String, dynamic>>[]},
      "viewer_view" => {"type": type, "title": "Como o espectador vê", "host": "Lucas Martins", "icons": <Map<String, dynamic>>[]},
      _ => {"type": type},
    };

/// Abre o editor de aula (nova: [lesson] == null).
Future<bool?> showLessonEditor(BuildContext context,
    {Map<String, dynamic>? lesson, required List<Map<String, dynamic>> categories, required List<Map<String, dynamic>> series, required List<Map<String, dynamic>> streamers}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => Dialog.fullscreen(
      backgroundColor: const Color(0xFF120E1C),
      child: _LessonEditor(lesson: lesson, categories: categories, series: series, streamers: streamers),
    ),
  );
}

class _LessonEditor extends StatefulWidget {
  final Map<String, dynamic>? lesson;
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> series;
  final List<Map<String, dynamic>> streamers;
  const _LessonEditor({this.lesson, required this.categories, required this.series, required this.streamers});

  @override
  State<_LessonEditor> createState() => _LessonEditorState();
}

class _LessonEditorState extends State<_LessonEditor> {
  final _service = AcademiaAdminService();
  late Map<String, dynamic> _l;
  late List<Map<String, dynamic>> _blocks;
  int _rev = 0; // muda a cada edicao -> previa atualiza
  Timer? _previewTimer;
  bool _saving = false;
  final _keys = <Map, Key>{};
  List<String> _grants = [];

  Key _k(Map m) => _keys.putIfAbsent(m, () => UniqueKey());

  @override
  void initState() {
    super.initState();
    final src = widget.lesson ?? {};
    _l = {
      "title": "",
      "audience": ["todos"],
      "level": "iniciante",
      "availability": "bloqueado",
      "status": "rascunho",
      "is_active": true,
      "access_mode": "todos",
      "allowed_streamer_ids": <String>[],
      "allowed_audiences": <String>[],
      "sources": <Map<String, dynamic>>[],
      "tags": <String>[],
      "info_status": "revisar",
      ...src,
    };
    _blocks = [for (final b in (src["blocks"] as List? ?? const [])) _deepCopy(Map<String, dynamic>.from(b as Map))];
    if (_l["id"] != null) {
      _service.fetchGrants(_l["id"] as String).then((g) {
        if (mounted) setState(() => _grants = [for (final x in g) x["profile_id"] as String]);
      });
    }
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    super.dispose();
  }

  static Map<String, dynamic> _deepCopy(Map<String, dynamic> m) => m.map((k, v) => MapEntry(
      k,
      v is Map
          ? _deepCopy(Map<String, dynamic>.from(v))
          : v is List
              ? [for (final x in v) x is Map ? _deepCopy(Map<String, dynamic>.from(x)) : x]
              : v));

  void _changed() {
    _previewTimer?.cancel();
    _previewTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _rev++);
    });
  }

  void _set(String key, dynamic value) {
    setState(() => _l[key] = value);
    _changed();
  }

  Future<void> _save({String? status}) async {
    if ((_l["title"] as String? ?? "").trim().isEmpty) {
      _snack("Dê um título para a aula.");
      return;
    }
    setState(() => _saving = true);
    try {
      final data = {..._l, "blocks": _blocks};
      if (status != null) data["status"] = status;
      for (final k in ["access", "block_types", "progress_status", "progress", "request_status", "quiz"]) {
        data.remove(k);
      }
      final saved = await _service.saveLesson(data);
      _l = {..._l, ...saved};
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      _snack("Erro ao salvar: $e");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Future<String?> _pickAndUpload({String accept = "image/*"}) async {
    final input = html.FileUploadInputElement()..accept = accept;
    input.click();
    await input.onChange.first;
    final file = input.files?.isNotEmpty == true ? input.files!.first : null;
    if (file == null) return null;
    final reader = html.FileReader()..readAsArrayBuffer(file);
    await reader.onLoad.first;
    // o navegador pode devolver Uint8List ou ByteBuffer, conforme a versao
    final result = reader.result;
    final bytes = result is Uint8List ? result : (result as ByteBuffer).asUint8List();
    _snack("Enviando ${file.name}...");
    final String? url;
    try {
      url = await _service.upload(bytes, file.name);
    } on UploadTooLarge catch (e) {
      _snack(e.message);
      return null;
    }
    if (url == null) _snack("Não foi possível enviar o arquivo.");
    return url;
  }

  // ------------------------------------------------------------------ campos

  InputDecoration _dec(String label, {String? hint, String? helper}) => InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        helperMaxLines: 3,
        helperStyle: const TextStyle(color: Colors.white30, fontSize: 11),
        labelStyle: const TextStyle(color: Colors.white54),
        hintStyle: const TextStyle(color: Colors.white24),
        border: const OutlineInputBorder(),
        isDense: true,
        alignLabelWithHint: true,
      );

  Widget _text(String label, String? value, ValueChanged<String> onChanged, {int lines = 1, String? hint, String? helper, Key? key}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextFormField(
          key: key,
          initialValue: value ?? "",
          minLines: lines,
          maxLines: lines == 1 ? 1 : lines + 8,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: _dec(label, hint: hint, helper: helper),
          onChanged: (v) {
            onChanged(v);
            _changed();
          },
        ),
      );

  Widget _lField(String key, String label, {int lines = 1, String? hint}) =>
      _text(label, _l[key]?.toString(), (v) => _l[key] = v.trim().isEmpty ? null : v, lines: lines, hint: hint, key: ValueKey("l_$key"));

  Widget _dropdown<T>(String label, T? value, Map<T, String> options, ValueChanged<T?> onChanged, {bool allowNull = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: DropdownButtonFormField<T?>(
          initialValue: options.containsKey(value) ? value : null,
          isExpanded: true,
          dropdownColor: _card,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: _dec(label),
          items: [
            if (allowNull) DropdownMenuItem<T?>(value: null, child: const Text("—")),
            for (final e in options.entries) DropdownMenuItem<T?>(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) {
            onChanged(v);
            _changed();
          },
        ),
      );

  Widget _box(String title, List<Widget> children, {String? help}) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: const TextStyle(color: _gold, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.4)),
          if (help != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(help, style: const TextStyle(color: Colors.white38, fontSize: 11.5))),
          const SizedBox(height: 12),
          ...children,
        ]),
      );

  Widget _switch(String label, String key, {String? help}) => SwitchListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13.5)),
        subtitle: help == null ? null : Text(help, style: const TextStyle(color: Colors.white38, fontSize: 11.5)),
        value: _l[key] == true,
        onChanged: (v) => _set(key, v),
      );

  Widget _multiChips(String label, List<String> selected, Map<String, String> options, ValueChanged<List<String>> onChanged) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final e in options.entries)
              FilterChip(
                label: Text(e.value, style: const TextStyle(fontSize: 12)),
                selected: selected.contains(e.key),
                onSelected: (v) {
                  final next = [...selected];
                  v ? next.add(e.key) : next.remove(e.key);
                  onChanged(next);
                  _changed();
                },
              ),
          ]),
        ]),
      );

  // ------------------------------------------------------------------- tela

  @override
  Widget build(BuildContext context) {
    final cats = {for (final c in widget.categories) c["id"] as String: "${c["emoji"] ?? ""} ${c["title"]}"};
    final series = {for (final s in widget.series) s["id"] as String: "${s["emoji"] ?? ""} ${s["title"]}"};
    return Scaffold(
      backgroundColor: const Color(0xFF120E1C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B1626),
        foregroundColor: Colors.white,
        title: Text(_l["id"] == null ? "Nova aula" : "Editar aula"),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop(false)),
        actions: [
          TextButton(onPressed: _saving ? null : () => _save(status: "rascunho"), child: const Text("Salvar como rascunho")),
          TextButton(onPressed: _saving ? null : () => _save(status: "revisao"), child: const Text("Enviar para revisão")),
          const SizedBox(width: 6),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ElevatedButton(
              onPressed: _saving ? null : () => _save(),
              style: ElevatedButton.styleFrom(backgroundColor: _purple, foregroundColor: Colors.white),
              child: Text(_saving ? "Salvando..." : "Salvar"),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: ListView(padding: const EdgeInsets.all(20), children: [
            _box("CONTEÚDO BÁSICO", [
              _lField("title", "Título *"),
              _lField("subtitle", "Subtítulo"),
              _lField("summary", "Resumo (aparece no topo da aula)", lines: 2),
              Row(children: [
                Expanded(child: _dropdown<String>("Categoria", _l["category_id"] as String?, cats, (v) => _l["category_id"] = v, allowNull: true)),
                const SizedBox(width: 10),
                Expanded(child: _lField("subcategory", "Subcategoria", hint: "Ex.: Gameplay, Setup")),
              ]),
              _multiChips("Público (só ordena e recomenda — nunca bloqueia)", List<String>.from(_l["audience"] as List? ?? const []), academyAudiences,
                  (v) => _l["audience"] = v.isEmpty ? ["todos"] : v),
              Row(children: [
                Expanded(child: _dropdown<String>("Nível", _l["level"] as String?, academyLevels, (v) => _l["level"] = v ?? "iniciante")),
                const SizedBox(width: 10),
                Expanded(
                  child: _text("Duração (min)", _l["duration_min"]?.toString(), (v) => _l["duration_min"] = int.tryParse(v), key: const ValueKey("dur")),
                ),
              ]),
              _text("Palavras-chave (para a busca), separadas por vírgula", (List<String>.from(_l["tags"] as List? ?? const [])).join(", "),
                  (v) => _l["tags"] = [for (final t in v.split(",")) if (t.trim().isNotEmpty) t.trim()], key: const ValueKey("tags")),
            ]),
            _box("IMAGENS", [
              _imageField("Miniatura (cards)", "thumbnail_url"),
              _imageField("Capa (topo da aula)", "cover_url"),
            ], help: "Sem imagem, o app usa a arte da categoria."),
            _box("PUBLICAÇÃO E DESTAQUES", [
              Row(children: [
                Expanded(child: _dropdown<String>("Status", _l["status"] as String?, academyStatus, (v) => _l["status"] = v ?? "rascunho")),
                const SizedBox(width: 10),
                Expanded(child: _dropdown<String>("Disponibilidade", _l["availability"] as String?, academyAvailability, (v) => _l["availability"] = v ?? "bloqueado")),
              ]),
              const Text(
                "Só aulas PUBLICADAS aparecem no app. Bloqueado / Solicitação: o streamer vê a aula com cadeado e pode pedir acesso. Em breve: aparece como \"em preparação\".",
                style: TextStyle(color: Colors.white38, fontSize: 11.5),
              ),
              _switch("Ativa", "is_active"),
              _switch("🔥 Em destaque na home", "featured"),
              _switch("✨ Recomendada (peso extra em \"Recomendado para você\")", "recommended"),
              _switch("👋 \"Comece por aqui\" (novos streamers)", "start_here"),
              Row(children: [
                Expanded(child: _dropdown<String>("Série (aulas em sequência)", _l["series_id"] as String?, series, (v) => _l["series_id"] = v, allowNull: true)),
                const SizedBox(width: 10),
                SizedBox(
                  width: 140,
                  child: _text("Ordem na série", _l["series_order"]?.toString(), (v) => _l["series_order"] = int.tryParse(v), key: const ValueKey("so")),
                ),
              ]),
            ]),
            _accessBox(),
            _box("BLOCOS DA AULA", [
              const Text(
                "Sugestão de ordem: O que é? → Como funciona? → Onde encontro? → Como faço? → Como usar melhor? → Dica MDuck → Coloque em prática.",
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 10),
              for (var i = 0; i < _blocks.length; i++) _blockEditor(i),
              Row(children: [
                PopupMenuButton<String>(
                  onSelected: (t) {
                    setState(() => _blocks.add(newBlock(t)));
                    _changed();
                  },
                  itemBuilder: (_) => [
                    for (final e in blockTypes.entries) PopupMenuItem(value: e.key, child: Text("${e.value.$1}  ${e.value.$2}")),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(color: _purple, borderRadius: BorderRadius.circular(8)),
                    child: const Text("+ Adicionar bloco", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ]),
            _sourcesBox(),
          ]),
        ),
        Container(
          width: 430,
          color: const Color(0xFF0B0915),
          child: Column(children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text("PRÉVIA NO APP", style: TextStyle(color: _gold, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.4)),
            ),
            Expanded(child: Center(child: _phone(_preview()))),
            const Padding(
              padding: EdgeInsets.all(10),
              child: Text("A prévia atualiza sozinha enquanto você edita.", style: TextStyle(color: Colors.white38, fontSize: 11.5)),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _imageField(String label, String key) => Row(children: [
        if ((_l[key] as String?)?.isNotEmpty == true)
          Padding(
            padding: const EdgeInsets.only(right: 10, bottom: 10),
            child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(_l[key] as String, width: 64, height: 48, fit: BoxFit.cover)),
          ),
        Expanded(child: _text(label, _l[key] as String?, (v) => _l[key] = v.trim().isEmpty ? null : v.trim(), key: ValueKey("img_${key}_${_l[key]}"))),
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 10),
          child: OutlinedButton.icon(
            onPressed: () async {
              final url = await _pickAndUpload();
              if (url != null) _set(key, url);
            },
            icon: const Icon(Icons.upload, size: 16),
            label: const Text("Enviar"),
          ),
        ),
      ]);

  Widget _accessBox() {
    final mode = _l["access_mode"] as String? ?? "todos";
    final streamers = {for (final s in widget.streamers) s["id"] as String: "${s["display_name"] ?? s["tiktok_username"] ?? "?"}${s["tiktok_username"] != null ? " (@${s["tiktok_username"]})" : ""}"};
    return _box("CONTROLE DE ACESSO", [
      _dropdown<String>("Quem pode ver o conteúdo (quando disponível)", mode,
          const {"todos": "Liberar para todos", "streamers": "Apenas streamers escolhidos", "audiencias": "Apenas alguns perfis de streamer"},
          (v) => _set("access_mode", v ?? "todos")),
      if (mode == "streamers")
        _streamerPicker("Streamers com acesso", List<String>.from(_l["allowed_streamer_ids"] as List? ?? const []), streamers,
            (v) => _set("allowed_streamer_ids", v)),
      if (mode == "audiencias")
        _multiChips("Perfis com acesso", List<String>.from(_l["allowed_audiences"] as List? ?? const []),
            Map.fromEntries(academyAudiences.entries.where((e) => e.key != "todos")), (v) => _l["allowed_audiences"] = v),
      if (_l["id"] != null) ...[
        const Divider(color: Colors.white12),
        const Text("Liberações manuais (inclui solicitações aprovadas). Aula \"Em revisão\" também aparece para quem estiver liberado aqui (testadores).", style: TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 6),
        _streamerPicker("Liberado para", _grants, streamers, (v) async {
          final id = _l["id"] as String;
          for (final add in v.where((x) => !_grants.contains(x))) {
            await _service.grant(id, add);
          }
          for (final rem in _grants.where((x) => !v.contains(x))) {
            await _service.revoke(id, rem);
          }
          if (mounted) setState(() => _grants = v);
        }),
      ],
    ], help: "A liberação manual funciona mesmo com a aula bloqueada.");
  }

  Widget _streamerPicker(String label, List<String> selected, Map<String, String> all, ValueChanged<List<String>> onChanged) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text("$label:", style: const TextStyle(color: Colors.white54, fontSize: 12)),
            for (final id in selected)
              InputChip(
                label: Text(all[id] ?? id, style: const TextStyle(fontSize: 12)),
                onDeleted: () => onChanged([...selected]..remove(id)),
              ),
            Autocomplete<MapEntry<String, String>>(
              displayStringForOption: (e) => e.value,
              optionsBuilder: (v) => all.entries
                  .where((e) => !selected.contains(e.key) && academyNormalize(e.value).contains(academyNormalize(v.text)))
                  .take(12),
              onSelected: (e) => onChanged([...selected, e.key]),
              fieldViewBuilder: (context, controller, focus, submit) => SizedBox(
                width: 240,
                child: TextField(
                  controller: controller,
                  focusNode: focus,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: _dec("Adicionar streamer..."),
                ),
              ),
            ),
          ]),
        ]),
      );

  Widget _sourcesBox() {
    final sources = [for (final s in (_l["sources"] as List? ?? const [])) Map<String, dynamic>.from(s as Map)];
    return _box("FONTES E REVISÃO", [
      for (var i = 0; i < sources.length; i++)
        Row(key: _k(sources[i]), children: [
          Expanded(flex: 3, child: _text("Título da fonte", sources[i]["title"] as String?, (v) => _updateSource(sources, i, "title", v))),
          const SizedBox(width: 8),
          Expanded(flex: 4, child: _text("URL", sources[i]["url"] as String?, (v) => _updateSource(sources, i, "url", v))),
          const SizedBox(width: 8),
          SizedBox(width: 130, child: _text("Consultado em", sources[i]["consulted_at"] as String?, (v) => _updateSource(sources, i, "consulted_at", v), hint: "AAAA-MM-DD")),
          IconButton(
            onPressed: () => _set("sources", [...sources]..removeAt(i)),
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
          ),
        ]),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () {
            final today = DateTime.now().toIso8601String().substring(0, 10);
            _set("sources", [...sources, {"title": "", "url": "", "consulted_at": today}]);
          },
          icon: const Icon(Icons.add),
          label: const Text("Adicionar fonte"),
        ),
      ),
      Row(children: [
        Expanded(child: _dropdown<String>("Status da informação", _l["info_status"] as String?, academyInfoStatus, (v) => _l["info_status"] = v ?? "revisar")),
        const SizedBox(width: 10),
        Expanded(
          child: Row(children: [
            Expanded(child: Text("Última revisão: ${_l["reviewed_at"] ?? "—"}", style: const TextStyle(color: Colors.white70))),
            TextButton(
              onPressed: () {
                _set("reviewed_at", DateTime.now().toIso8601String().substring(0, 10));
                _set("info_status", "atual");
              },
              child: const Text("Revisado hoje"),
            ),
          ]),
        ),
      ]),
    ], help: "Prefira TikTok Newsroom, TikTok Support e páginas oficiais. Os recursos do TikTok mudam: revise de tempos em tempos.");
  }

  void _updateSource(List<Map<String, dynamic>> sources, int i, String key, String v) {
    sources[i][key] = v;
    _l["sources"] = sources;
  }

  // ------------------------------------------------------------------ blocos

  Widget _blockEditor(int i) {
    final b = _blocks[i];
    final type = b["type"] as String? ?? "text";
    final (emoji, label) = blockTypes[type] ?? ("•", type);
    return Container(
      key: _k(b),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(border: Border.all(color: Colors.white12), borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: const BoxDecoration(color: Color(0xFF241C33), borderRadius: BorderRadius.vertical(top: Radius.circular(10))),
          child: Row(children: [
            Text("${i + 1}. $emoji  $label", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
            const Spacer(),
            IconButton(tooltip: "Subir", onPressed: i == 0 ? null : () => _moveBlock(i, -1), icon: const Icon(Icons.arrow_upward, size: 17, color: Colors.white60)),
            IconButton(tooltip: "Descer", onPressed: i == _blocks.length - 1 ? null : () => _moveBlock(i, 1), icon: const Icon(Icons.arrow_downward, size: 17, color: Colors.white60)),
            IconButton(
              tooltip: "Duplicar",
              onPressed: () {
                setState(() => _blocks.insert(i + 1, _deepCopy(b)));
                _changed();
              },
              icon: const Icon(Icons.copy, size: 16, color: Colors.white60),
            ),
            IconButton(
              tooltip: "Remover",
              onPressed: () {
                setState(() => _blocks.removeAt(i));
                _changed();
              },
              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
            ),
          ]),
        ),
        Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _blockFields(b))),
      ]),
    );
  }

  void _moveBlock(int i, int d) {
    setState(() {
      final b = _blocks.removeAt(i);
      _blocks.insert(i + d, b);
    });
    _changed();
  }

  Widget _bf(Map b, String key, String label, {int lines = 1, String? hint}) =>
      _text(label, b[key]?.toString(), (v) => b[key] = v, lines: lines, hint: hint, key: ValueKey("${identityHashCode(b)}_$key"));

  Widget _lines(Map b, String key, String label) => _text(
        "$label (um por linha)",
        (b[key] as List? ?? const []).join("\n"),
        (v) => b[key] = [for (final x in v.split("\n")) if (x.trim().isNotEmpty) x.trim()],
        lines: 4,
        key: ValueKey("${identityHashCode(b)}_$key"),
      );

  List<Widget> _blockFields(Map<String, dynamic> b) {
    switch (b["type"]) {
      case "text":
        return [_bf(b, "label", "Etiqueta (ex.: O que é?, Como funciona?)"), _bf(b, "title", "Título (opcional)"), _bf(b, "body", "Texto", lines: 4)];
      case "platform":
        return [
          _bf(b, "title", "Título"),
          _bf(b, "body", "Informação oficial (descreva como a plataforma funciona)", lines: 4),
          _bf(b, "source_url", "Link da página oficial"),
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            value: b["varies"] == true,
            onChanged: (v) {
              setState(() => b["varies"] = v);
              _changed();
            },
            title: const Text("Mostrar \"A disponibilidade deste recurso pode variar.\"", style: TextStyle(color: Colors.white, fontSize: 13)),
          ),
        ];
      case "tip":
        return [_bf(b, "body", "Dica MDuck", lines: 2)];
      case "strategy":
        return [_bf(b, "title", "Título", hint: "Experiência / estratégia MDuck"), _bf(b, "body", "Texto", lines: 3)];
      case "image":
        return [
          Row(children: [
            Expanded(child: _text("URL da imagem / GIF", b["url"] as String?, (v) => b["url"] = v, key: ValueKey("${identityHashCode(b)}_url_${b["url"]}"))),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: OutlinedButton.icon(
                onPressed: () async {
                  final url = await _pickAndUpload();
                  if (url != null) {
                    setState(() => b["url"] = url);
                    _changed();
                  }
                },
                icon: const Icon(Icons.upload, size: 16),
                label: const Text("Enviar"),
              ),
            ),
          ]),
          _bf(b, "caption", "Legenda"),
        ];
      case "youtube":
        final thumb = youtubeThumbAdmin(b["url"] as String? ?? "");
        return [
          _bf(b, "url", "URL do YouTube", hint: "https://www.youtube.com/watch?v=..."),
          if (thumb != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Image.network(thumb, height: 90, alignment: Alignment.centerLeft)),
          _bf(b, "title", "Título"),
          _bf(b, "description", "Descrição", lines: 2),
          _bf(b, "duration", "Duração", hint: "ex.: 6:30"),
        ];
      case "video":
        return [
          Row(children: [
            Expanded(child: _text("URL do vídeo", b["url"] as String?, (v) => b["url"] = v, key: ValueKey("${identityHashCode(b)}_v_${b["url"]}"))),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: OutlinedButton.icon(
                onPressed: () async {
                  final url = await _pickAndUpload(accept: "video/*");
                  if (url != null) {
                    setState(() => b["url"] = url);
                    _changed();
                  }
                },
                icon: const Icon(Icons.upload, size: 16),
                label: const Text("Enviar"),
              ),
            ),
          ]),
          _bf(b, "title", "Título"),
          const Text("Prefira YouTube para não pesar o app.", style: TextStyle(color: Colors.white38, fontSize: 11.5)),
        ];
      case "steps":
        return [_bf(b, "title", "Título"), _lines(b, "items", "Passos")];
      case "example":
        return [_bf(b, "title", "Título", hint: "Exemplo"), _bf(b, "body", "Texto", lines: 3)];
      case "checklist":
        return [_bf(b, "title", "Título"), _lines(b, "items", "Itens")];
      case "challenge":
        return [_bf(b, "body", "Desafio para a próxima LIVE", lines: 2)];
      case "discover":
        return [_bf(b, "title", "Título"), ..._itemsEditor(b, const [("emoji", "Emoji", 70.0), ("title", "Título", 0.0), ("body", "Texto ao tocar", 0.0)])];
      case "flow":
        return [_bf(b, "title", "Título"), ..._itemsEditor(b, const [("emoji", "Emoji", 70.0), ("label", "Etapa", 0.0), ("body", "Explicação", 0.0)])];
      case "quiz":
        final options = List<String>.from(b["options"] as List? ?? const []);
        return [
          _bf(b, "question", "Pergunta", lines: 2),
          for (var i = 0; i < options.length; i++)
            Row(key: ValueKey("${identityHashCode(b)}_opt_${i}_${options.length}"), children: [
              Radio<int>(
                value: i,
                groupValue: (b["correct"] as num?)?.toInt() ?? 0,
                onChanged: (v) {
                  setState(() => b["correct"] = v);
                  _changed();
                },
              ),
              Expanded(child: _text("Opção ${String.fromCharCode(65 + i)}", options[i], (v) {
                options[i] = v;
                b["options"] = options;
              })),
              IconButton(
                onPressed: options.length <= 2
                    ? null
                    : () {
                        setState(() {
                          options.removeAt(i);
                          b["options"] = options;
                          if (((b["correct"] as num?) ?? 0) >= options.length) b["correct"] = 0;
                        });
                        _changed();
                      },
                icon: const Icon(Icons.remove_circle_outline, size: 18, color: Colors.white38),
              ),
            ]),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () {
                setState(() => b["options"] = [...options, ""]);
                _changed();
              },
              child: const Text("+ opção"),
            ),
          ),
          const Text("Marque a bolinha da resposta certa.", style: TextStyle(color: Colors.white38, fontSize: 11.5)),
          const SizedBox(height: 8),
          _bf(b, "explanation", "Explicação (aparece depois de responder)", lines: 2),
        ];
      case "simulation":
        final scene = b["scene"] as String? ?? "batalha";
        final hotspots = Map<String, dynamic>.from(b["hotspots"] as Map? ?? {});
        return [
          _sceneDropdown(b),
          _bf(b, "title", "Título"),
          _bf(b, "intro", "Introdução", lines: 2),
          const Text("Textos de cada ponto (deixe vazio para usar o padrão):", style: TextStyle(color: Colors.white54, fontSize: 12)),
          for (final spot in liveSceneSpots[scene] ?? const <LiveSpot>[])
            ExpansionTile(
              key: ValueKey("${identityHashCode(b)}_$scene${spot.key}"),
              tilePadding: EdgeInsets.zero,
              title: Text("${spot.emoji}  ${spot.label}", style: const TextStyle(color: Colors.white, fontSize: 13)),
              children: [
                for (final (k, l, def) in [("label", "Nome", spot.label), ("meaning", "Isso significa…", spot.meaning), ("usage", "Isso pode ser usado para…", spot.usage), ("tip", "Dica MDuck", spot.tip)])
                  _text(l, (hotspots[spot.key] as Map?)?[k] as String?, (v) {
                    final o = Map<String, dynamic>.from(hotspots[spot.key] as Map? ?? {});
                    v.trim().isEmpty ? o.remove(k) : o[k] = v;
                    hotspots[spot.key] = o;
                    b["hotspots"] = hotspots;
                  }, helper: "Padrão: $def", lines: k == "label" ? 1 : 2),
              ],
            ),
        ];
      case "tiktok_profile":
        final spots = Map<String, dynamic>.from(b["spots"] as Map? ?? {});
        return [
          _bf(b, "title", "Título"),
          _bf(b, "intro", "Introdução", lines: 2),
          _bf(b, "tap_hint_text", "Texto abaixo da Batalha (antes de tocar)"),
          const Text("Perfil fictício (nunca use dados reais):", style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, children: [
            for (final (k, l) in const [
              ("name", "Nome"),
              ("handle", "@ (sem o @)"),
              ("followers", "Seguidores"),
              ("following", "Seguindo"),
              ("league", "Liga"),
              ("league_rank", "Posição na Liga"),
              ("community", "Comunidade"),
              ("gifter_level", "Nível"),
              ("opponent", "Nome do oponente"),
              ("score_left", "Placar esquerdo"),
              ("score_right", "Placar direito"),
              ("timer", "Tempo"),
              ("viewers", "Espectadores"),
            ])
              SizedBox(width: 190, child: _bf(b, k, l)),
          ]),
          _bf(b, "bio", "Bio", lines: 3),
          const Text("Explicação de cada elemento tocável:", style: TextStyle(color: Colors.white54, fontSize: 12)),
          for (final e in profileSpots.entries)
            ExpansionTile(
              key: ValueKey("${identityHashCode(b)}_spot_${e.key}"),
              tilePadding: EdgeInsets.zero,
              title: Text("👆 ${e.value}", style: const TextStyle(color: Colors.white, fontSize: 13)),
              children: [
                for (final (k, l) in [("title", "Título"), ("body", "Explicação"), ("tip", "Dica MDuck (opcional)"), if (e.key == "galeria") ("action", "Texto do botão que rola até a Galeria")])
                  _text(l, (spots[e.key] as Map?)?[k] as String?, (v) {
                    final o = Map<String, dynamic>.from(spots[e.key] as Map? ?? {});
                    o[k] = v;
                    spots[e.key] = o;
                    b["spots"] = spots;
                  }, lines: k == "body" ? 4 : (k == "tip" ? 2 : 1)),
              ],
            ),
        ];
      case "league_ladder":
        return [
          _bf(b, "label", "Etiqueta", hint: "A Liga"),
          _bf(b, "title", "Título"),
          _bf(b, "intro", "Introdução", lines: 2),
          ..._itemsEditor(b, const [("letter", "Letra", 70.0), ("tiers", "Classes (separadas por vírgula)", 0.0), ("body", "Texto ao tocar", 0.0)],
              listKey: "groups", addLabel: "+ faixa"),
          _bf(b, "top", "Classe do topo (destacada com 🏆)", hint: "A1"),
          _bf(b, "top_title", "Título ao tocar no topo"),
          _bf(b, "top_body", "Texto ao tocar no topo", lines: 2),
          _bf(b, "note", "Observação discreta"),
        ];
      case "gift_gallery":
        final gifts = [for (final x in (b["gifts"] as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
        return [
          _bf(b, "label", "Etiqueta", hint: "Galeria de Presentes"),
          _bf(b, "title", "Título"),
          _bf(b, "intro", "Introdução", lines: 2),
          Row(children: [
            Expanded(child: _bf(b, "owner", "Dono da Galeria (fictício)")),
            const SizedBox(width: 8),
            SizedBox(width: 90, child: _bf(b, "league", "Liga")),
            const SizedBox(width: 8),
            SizedBox(width: 120, child: _bf(b, "total", "Total de Presentes")),
          ]),
          const Text("Presentes (Iluminado: sim/não · @ fictício · imagem opcional, sem imagem usa o emoji):", style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 6),
          ..._itemsEditor(
              b,
              const [
                ("emoji", "Emoji", 64.0),
                ("name", "Presente", 0.0),
                ("user", "Principal (@)", 150.0),
                ("others", "Outros 2 (@, separados por vírgula)", 0.0),
                ("lit", "Iluminado?", 90.0),
                ("image_url", "URL da imagem", 0.0),
                ("body", "Texto ao tocar (opcional)", 0.0),
              ],
              listKey: "gifts",
              addLabel: "+ Presente"),
          if (gifts.isNotEmpty)
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (var i = 0; i < gifts.length; i++)
                OutlinedButton.icon(
                  onPressed: () async {
                    final url = await _pickAndUpload();
                    if (url == null) return;
                    gifts[i]["image_url"] = url;
                    setState(() => b["gifts"] = gifts);
                    _changed();
                  },
                  icon: const Icon(Icons.upload, size: 14),
                  label: Text("Imagem: ${gifts[i]["name"] ?? i + 1}", style: const TextStyle(fontSize: 12)),
                ),
            ]),
          const SizedBox(height: 10),
          _bf(b, "hint", "Texto de toque"),
          _bf(b, "gift_body", "Texto padrão ao tocar num Presente", lines: 2),
          _bf(b, "unlit_body", "Texto de Presente ainda apagado", lines: 2),
          _bf(b, "sender_title", "Título \"Quem enviou?\""),
          _bf(b, "sender_body", "Explicação de quem enviou", lines: 2),
          _bf(b, "sender_tip", "Dica MDuck (ao tocar num Presente iluminado)", lines: 2),
          _bf(b, "demo_button", "Botão da animação"),
          _bf(b, "lit_title", "Título depois da animação"),
          _bf(b, "lit_body", "Texto depois da animação", lines: 2),
        ];
      case "feed":
        return [
          _bf(b, "label", "Etiqueta"),
          _bf(b, "title", "Título"),
          _bf(b, "button", "Texto do botão", hint: "Ver a disputa"),
          ..._itemsEditor(b, const [("user", "@ (fictício)", 160.0), ("text", "Ação", 0.0), ("emoji", "Emoji", 64.0), ("image_url", "Imagem do Presente (opcional)", 0.0)]),
          _bf(b, "body", "Texto depois da animação", lines: 2),
        ];
      case "recap":
        return [_bf(b, "title", "Título"), _lines(b, "items", "Itens")];
      case "live_menu":
        return [
          _bf(b, "label", "Etiqueta"),
          _bf(b, "title", "Título"),
          _bf(b, "intro", "Introdução", lines: 2),
          Row(children: [
            Expanded(child: _bf(b, "host", "Nome do host (fictício)")),
            const SizedBox(width: 8),
            Expanded(child: _bf(b, "target", "Item a encontrar (igual ao nome no menu)")),
          ]),
          _bf(b, "target_title", "Título ao tocar no item"),
          _bf(b, "target_body", "Explicação ao tocar no item", lines: 2),
          _bf(b, "done_text", "Texto depois de achar"),
          _bf(b, "hint", "Dica antes de abrir o menu"),
          const Text("Itens do menu (ícone: enquete, manual, bau, bau_superfa, sacola, papel, desejos, musicas, portal):",
              style: TextStyle(color: Colors.white54, fontSize: 12)),
          ..._itemsEditor(b, const [("icon", "Ícone", 130.0), ("label", "Nome no menu", 0.0)], addLabel: "+ item do menu"),
          const Text("Comentários do chat (fictícios):", style: TextStyle(color: Colors.white54, fontSize: 12)),
          ..._itemsEditor(b, const [("user", "@", 170.0), ("text", "Comentário", 0.0)], listKey: "chat", addLabel: "+ comentário"),
        ];
      case "tiktok_sheet":
        return [
          _bf(b, "label", "Etiqueta"),
          _bf(b, "title", "Título"),
          _bf(b, "intro", "Introdução", lines: 2),
          Wrap(spacing: 8, children: [
            for (final (k, l) in const [
              ("host", "Host (fictício)"),
              ("sheet_title", "Título da tela"),
              ("tabs", "Abas (A|B)"),
              ("tab_active", "Aba ativa (0, 1...)"),
              ("corner", "Canto (help, icons, close)"),
              ("back", "Seta voltar? (sim/não)"),
              ("section", "Seção (ex.: Itens)"),
              ("section_action", "Ação da seção"),
              ("button", "Botão"),
              ("rewards", "Ganhadores na animação"),
            ])
              SizedBox(width: 200, child: _bf(b, k, l)),
          ]),
          _bf(b, "tab_explain", "Explicação ao tocar na outra aba", lines: 2),
          _bf(b, "terms", "Texto dos termos"),
          const Text(
              "Elementos da tela. Tipos: option (card com moedas), field (campo), row (linha › valor), radio, chips (Nv.1, Nv.3...), "
              "stat (número grande), pair (rótulo e valor), slider, comment, note.",
              style: TextStyle(color: Colors.white54, fontSize: 12)),
          ..._mapListEditor(b, "elements", const [
            ("kind", "Tipo"),
            ("label", "Rótulo"),
            ("left", "Texto do card"),
            ("coins", "Moedas"),
            ("right", "Texto à direita"),
            ("value", "Valor"),
            ("sub", "Subtexto"),
            ("hint", "Texto do campo"),
            ("options", "Opções (vírgula)"),
            ("selected", "Selecionado (sim / índice)"),
            ("icon", "Ícone (people)"),
            ("big_min", "Número mínimo"),
            ("big_max", "Número máximo"),
            ("value_max", "Valor no máximo"),
            ("min", "Slider mínimo"),
            ("max", "Slider máximo"),
            ("note", "Observação"),
            ("explain_title", "Título da explicação"),
            ("explain", "Explicação ao tocar"),
          ]),
          const SizedBox(height: 8),
          _bf(b, "send_title", "Título depois de Enviar"),
          ..._itemsEditor(b, const [("emoji", "Emoji", 70.0), ("art", "Desenho (bau/portal)", 110.0), ("label", "Passo depois de Enviar", 0.0)], listKey: "send_steps", addLabel: "+ passo"),
          _bf(b, "send_body", "Texto final", lines: 2),
        ];
      case "viewer_view":
        return [
          _bf(b, "label", "Etiqueta"),
          _bf(b, "title", "Título"),
          _bf(b, "intro", "Introdução", lines: 2),
          _bf(b, "host", "Host (fictício)"),
          ..._itemsEditor(b, const [("emoji", "Emoji", 70.0), ("art", "Desenho (bau/portal)", 110.0), ("badge", "Selo (ex.: 01:46)", 120.0), ("title", "Título ao tocar", 0.0), ("body", "Explicação", 0.0)],
              listKey: "icons", addLabel: "+ ícone"),
        ];
      case "compare":
        return [
          _bf(b, "label", "Etiqueta"),
          _bf(b, "title", "Título"),
          _bf(b, "intro", "Introdução", lines: 2),
          ..._itemsEditor(b, const [
            ("emoji", "Emoji", 64.0),
            ("art", "Desenho (bau/portal)", 110.0),
            ("title", "Nome", 110.0),
            ("goal", "Objetivo", 0.0),
            ("steps", "Caminho (A | B | C)", 0.0),
            ("question", "Pergunta", 0.0),
          ]),
          _bf(b, "footer", "Frase final"),
        ];
      case "identify":
        final scene = b["scene"] as String? ?? "games";
        final prompts = [for (final p in (b["prompts"] as List? ?? const [])) Map<String, dynamic>.from(p as Map)];
        final keys = {for (final s in liveSceneSpots[scene] ?? const <LiveSpot>[]) s.key: "${s.emoji} ${s.label}"};
        return [
          _sceneDropdown(b),
          _bf(b, "title", "Título"),
          for (var i = 0; i < prompts.length; i++)
            Row(key: ValueKey("${identityHashCode(b)}_p$i${prompts.length}"), children: [
              Expanded(flex: 3, child: _text("Pergunta ${i + 1}", prompts[i]["ask"] as String?, (v) {
                prompts[i]["ask"] = v;
                b["prompts"] = prompts;
              })),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: _dropdown<String>("Parte certa", prompts[i]["key"] as String?, keys, (v) {
                  prompts[i]["key"] = v;
                  b["prompts"] = prompts;
                }),
              ),
              const SizedBox(width: 8),
              Expanded(flex: 3, child: _text("Mensagem de acerto", prompts[i]["ok"] as String?, (v) {
                prompts[i]["ok"] = v;
                b["prompts"] = prompts;
              })),
              IconButton(
                onPressed: () {
                  setState(() => b["prompts"] = [...prompts]..removeAt(i));
                  _changed();
                },
                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
              ),
            ]),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () {
                setState(() => b["prompts"] = [...prompts, {"ask": "", "key": keys.keys.first, "ok": "Isso!"}]);
                _changed();
              },
              child: const Text("+ pergunta"),
            ),
          ),
        ];
    }
    return const [];
  }

  Widget _sceneDropdown(Map<String, dynamic> b) => _dropdown<String>("Cena", b["scene"] as String?, liveSceneNames, (v) {
        setState(() => b["scene"] = v ?? "batalha");
      });

  List<Widget> _itemsEditor(Map<String, dynamic> b, List<(String, String, double)> fields, {String listKey = "items", String addLabel = "+ item"}) {
    final items = [for (final x in (b[listKey] as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
    return [
      for (var i = 0; i < items.length; i++)
        Row(key: ValueKey("${identityHashCode(b)}_it$i${items.length}"), crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final (k, label, w) in fields) ...[
            if (w > 0)
              SizedBox(width: w, child: _text(label, items[i][k] as String?, (v) {
                items[i][k] = v;
                b[listKey] = items;
              }))
            else
              Expanded(child: _text(label, items[i][k] as String?, (v) {
                items[i][k] = v;
                b[listKey] = items;
              }, lines: k == "body" ? 2 : 1)),
            const SizedBox(width: 6),
          ],
          IconButton(
            onPressed: () {
              setState(() => b[listKey] = [...items]..removeAt(i));
              _changed();
            },
            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
          ),
        ]),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: () {
            setState(() => b[listKey] = [...items, {for (final f in fields) f.$1: f.$1 == "emoji" ? "✨" : ""}]);
            _changed();
          },
          child: Text(addLabel),
        ),
      ),
    ];
  }

  /// Lista de itens com muitos campos: cada item vira um painel que abre.
  List<Widget> _mapListEditor(Map<String, dynamic> b, String listKey, List<(String, String)> fields) {
    final items = [for (final x in (b[listKey] as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
    return [
      for (var i = 0; i < items.length; i++)
        ExpansionTile(
          key: ValueKey("${identityHashCode(b)}_$listKey$i${items.length}"),
          tilePadding: EdgeInsets.zero,
          title: Text("${i + 1}. ${items[i]["kind"] ?? ""} · ${items[i]["label"] ?? items[i]["left"] ?? items[i]["coins"] ?? ""}",
              style: const TextStyle(color: Colors.white, fontSize: 13)),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
              tooltip: "Subir",
              onPressed: i == 0
                  ? null
                  : () {
                      setState(() => b[listKey] = [...items]..insert(i - 1, items[i])..removeAt(i + 1));
                      _changed();
                    },
              icon: const Icon(Icons.arrow_upward, size: 16, color: Colors.white54),
            ),
            IconButton(
              tooltip: "Remover",
              onPressed: () {
                setState(() => b[listKey] = [...items]..removeAt(i));
                _changed();
              },
              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
            ),
          ]),
          children: [
            Wrap(spacing: 8, children: [
              for (final (k, l) in fields)
                SizedBox(
                  width: k == "explain" ? 620 : 200,
                  child: _text(l, items[i][k]?.toString(), (v) {
                    v.trim().isEmpty ? items[i].remove(k) : items[i][k] = v;
                    b[listKey] = items;
                  }, lines: k == "explain" || k == "sub" ? 3 : 1),
                ),
            ]),
          ],
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: () {
            setState(() => b[listKey] = [...items, {"kind": "row", "label": ""}]);
            _changed();
          },
          child: const Text("+ elemento"),
        ),
      ),
    ];
  }

  // ------------------------------------------------------------------ previa

  Widget _preview() {
    final cat = widget.categories.where((c) => c["id"] == _l["category_id"]).firstOrNull;
    final json = {
      ..._l,
      "id": _l["id"] ?? "previa",
      "blocks": _blocks,
      "access": "open",
      "block_types": [for (final b in _blocks) b["type"]],
    };
    final lesson = AcademyLesson.fromJson(json);
    return KeyedSubtree(
      key: ValueKey(_rev),
      child: Navigator(
        onGenerateRoute: (_) => MaterialPageRoute(
          builder: (_) => AcademyLessonPage(
            repo: _PreviewRepo(lesson),
            summary: lesson.info,
            category: cat == null ? null : AcademyCategory.fromJson(cat),
          ),
        ),
      ),
    );
  }
}

/// Moldura de celular para as previas.
Widget _phone(Widget child) => Container(
      width: 380,
      height: math.min(780, 780),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(36), border: Border.all(color: Colors.white24, width: 2)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Theme(data: ThemeData.dark(useMaterial3: true), child: MediaQuery(data: const MediaQueryData(size: Size(364, 764)), child: child)),
      ),
    );

Widget academyPhoneFrame(Widget child) => _phone(child);

class _PreviewRepo extends AcademyRepository {
  final AcademyLesson lesson;
  const _PreviewRepo(this.lesson) : super(viewAsAudience: "previa");

  @override
  Future<AcademyLesson?> fetchLesson(String id) async => lesson;

  @override
  Future<void> track(String lessonId, String event, {double? progress, Map<String, dynamic>? quiz}) async {}
}

String? youtubeThumbAdmin(String url) {
  final m = RegExp(r"(?:youtu\.be/|[?&]v=|youtube\.com/(?:embed|shorts|live)/)([A-Za-z0-9_-]{6,})").firstMatch(url);
  return m == null ? null : "https://img.youtube.com/vi/${m.group(1)}/hqdefault.jpg";
}
