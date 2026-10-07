// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import "dart:async";
import "dart:html" as html;
import "dart:typed_data";
import "dart:ui_web" as ui_web;

import "package:flutter/material.dart";

/// Le o HTML atual do editor.
class RichHtmlEditorController {
  _RichHtmlEditorState? _state;
  String get html => (_state?._editor.innerHtml ?? "").replaceAll("mduck-sel", "").replaceAll(' class=""', "");
  String get plainText => (_state?._editor.innerText ?? "").trim();
}

/// Editor de texto rico "tipo e-mail" (painel web): negrito, italico,
/// sublinhado, titulos, cores, alinhamento, listas, imagens (com tamanho e
/// alinhamento) e links em texto ou em imagem. Gera HTML, que o app mostra
/// com o mesmo visual (fundo escuro).
class RichHtmlEditor extends StatefulWidget {
  final String initialHtml;
  final RichHtmlEditorController controller;

  /// Sobe a imagem e devolve a URL publica (null = falhou).
  final Future<String?> Function(Uint8List bytes, String fileName) uploadImage;
  final double height;

  const RichHtmlEditor({
    super.key,
    required this.initialHtml,
    required this.controller,
    required this.uploadImage,
    this.height = 520,
  });

  @override
  State<RichHtmlEditor> createState() => _RichHtmlEditorState();
}

class _RichHtmlEditorState extends State<RichHtmlEditor> {
  static int _seq = 0;
  late final String _viewType = "mduck-rte-${_seq++}";
  late final html.DivElement _editor;
  html.Range? _saved;
  html.ImageElement? _selectedImg;
  StreamSubscription? _selectionSub;
  bool _uploading = false;

  static const _css = """
.mduck-rte { width:100%; height:100%; box-sizing:border-box; overflow:auto; padding:18px 20px;
  background:#0E0820; color:rgba(255,255,255,.78); font:14px/1.5 Roboto, Arial, sans-serif; outline:none; }
.mduck-rte h2 { color:#fff; font-size:22px; margin:.6em 0 .3em; }
.mduck-rte h3 { color:#fff; font-size:17px; margin:.6em 0 .3em; }
.mduck-rte p { margin:0 0 .7em; }
.mduck-rte a { color:#C084FC; }
.mduck-rte img { max-width:100%; height:auto; border-radius:10px; cursor:pointer; }
.mduck-rte img.mduck-sel { outline:3px solid #7A0BD4; outline-offset:2px; }
.mduck-rte hr { border:none; border-top:1px solid rgba(255,255,255,.18); margin:1em 0; }
.mduck-rte:empty:before { content:'Escreva aqui...'; color:rgba(255,255,255,.3); }
""";

  @override
  void initState() {
    super.initState();
    widget.controller._state = this;
    final style = html.StyleElement()..text = _css;
    _editor = html.DivElement()
      ..className = "mduck-rte"
      ..contentEditable = "true"
      ..style.width = "100%"
      ..style.height = "100%";
    _editor.setInnerHtml(widget.initialHtml, treeSanitizer: html.NodeTreeSanitizer.trusted);
    final wrapper = html.DivElement()
      ..style.width = "100%"
      ..style.height = "100%"
      ..append(style)
      ..append(_editor);
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) => wrapper);

    _selectionSub = html.document.onSelectionChange.listen((_) {
      final sel = html.window.getSelection();
      if (sel == null || sel.rangeCount == 0) return;
      final r = sel.getRangeAt(0);
      if (_editor.contains(r.commonAncestorContainer)) _saved = r.cloneRange();
    });
    _editor.onClick.listen((e) {
      final t = e.target;
      _selectImage(t is html.ImageElement ? t : null);
    });
    _editor.onKeyDown.listen((_) => _selectImage(null));
  }

  @override
  void dispose() {
    _selectionSub?.cancel();
    if (widget.controller._state == this) widget.controller._state = null;
    super.dispose();
  }

  void _selectImage(html.ImageElement? img) {
    _selectedImg?.classes.remove("mduck-sel");
    _selectedImg = img;
    if (img != null) {
      img.classes.add("mduck-sel");
      final r = html.document.createRange()..selectNode(img);
      final sel = html.window.getSelection();
      sel?.removeAllRanges();
      sel?.addRange(r);
      _saved = r.cloneRange();
    }
    setState(() {});
  }

  void _restore() {
    _editor.focus();
    final sel = html.window.getSelection();
    if (_saved != null && sel != null) {
      sel.removeAllRanges();
      sel.addRange(_saved!);
    }
  }

  void _exec(String command, [String? value]) {
    _restore();
    // cores/estilos como CSS inline (o app entende melhor que <font>)
    html.document.execCommand("styleWithCSS", false, "true");
    html.document.execCommand(command, false, value);
  }

  /// Alinhamento: com imagem selecionada, alinha o bloco da imagem.
  void _align(String command) {
    _exec(command);
  }

  static String _normalizeUrl(String url) {
    final u = url.trim();
    if (u.isEmpty) return u;
    if (RegExp(r"^(https?:|mailto:|tel:)", caseSensitive: false).hasMatch(u)) return u;
    if (u.contains("@") && !u.contains("/")) return "mailto:$u";
    return "https://$u";
  }

  Future<void> _link() async {
    final img = _selectedImg;
    final sel = _saved;
    final hasText = sel != null && !sel.collapsed;
    String? currentHref;
    if (img != null && img.parent is html.AnchorElement) currentHref = (img.parent as html.AnchorElement).href;

    final urlCtrl = TextEditingController(text: currentHref ?? "");
    final textCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(img != null ? "Link na imagem" : "Inserir link"),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (img == null && !hasText)
              TextField(controller: textCtrl, decoration: const InputDecoration(labelText: "Texto do link")),
            TextField(
              controller: urlCtrl,
              autofocus: true,
              onSubmitted: (_) => Navigator.pop(ctx, true),
              decoration: const InputDecoration(labelText: "Endereço (https://..., e-mail ou WhatsApp wa.me/...)"),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Aplicar")),
        ],
      ),
    );
    if (ok != true) return;
    final url = _normalizeUrl(urlCtrl.text);
    if (url.isEmpty) return;

    if (img != null) {
      final parent = img.parent;
      if (parent is html.AnchorElement) {
        parent.href = url;
      } else {
        final a = html.AnchorElement(href: url);
        img.replaceWith(a);
        a.append(img);
      }
      return;
    }
    if (hasText) {
      _exec("createLink", url);
    } else {
      final text = textCtrl.text.trim().isEmpty ? urlCtrl.text.trim() : textCtrl.text.trim();
      _exec("insertHTML", '<a href="${_escapeAttr(url)}">${_escapeText(text)}</a>&nbsp;');
    }
  }

  void _unlink() {
    final img = _selectedImg;
    if (img != null && img.parent is html.AnchorElement) {
      img.parent!.replaceWith(img);
      return;
    }
    _exec("unlink");
  }

  static String _escapeText(String s) => s.replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;");
  static String _escapeAttr(String s) => _escapeText(s).replaceAll('"', "&quot;");

  Future<void> _pickImage() async {
    final input = html.FileUploadInputElement()..accept = "image/*";
    input.click();
    await input.onChange.first;
    final file = input.files?.isNotEmpty == true ? input.files!.first : null;
    if (file == null) return;
    if (file.size > 8 * 1024 * 1024) {
      _snack("Imagem muito grande (máx. 8 MB).");
      return;
    }
    setState(() => _uploading = true);
    try {
      final reader = html.FileReader()..readAsArrayBuffer(file);
      await reader.onLoad.first;
      // o navegador pode devolver Uint8List ou ByteBuffer, conforme a versao
      final result = reader.result;
      final bytes = result is Uint8List ? result : (result as ByteBuffer).asUint8List();
      final url = await widget.uploadImage(bytes, file.name);
      if (url == null) {
        _snack("Não foi possível enviar a imagem. Tente de novo.");
        return;
      }
      final snippet = '<p style="text-align:center"><img src="${_escapeAttr(url)}" style="max-width:100%"></p><p><br></p>';
      if (_saved == null) {
        // cursor nunca esteve no texto: coloca a imagem no fim
        _editor.insertAdjacentHtml("beforeend", snippet, treeSanitizer: html.NodeTreeSanitizer.trusted);
      } else {
        _exec("insertHTML", snippet);
      }
      _snack("Imagem inserida. Lembre de Salvar.");
    } catch (e) {
      _snack("Não foi possível enviar a imagem: $e");
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _imageWidth(String width) {
    final img = _selectedImg;
    if (img == null) return;
    img.style.width = width;
    img.style.height = "auto";
  }

  void _snack(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Widget _btn(IconData icon, String tip, VoidCallback onTap, {bool active = false}) => Tooltip(
        message: tip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: active ? const Color(0xFF7A0BD4).withValues(alpha: 0.35) : null,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 19, color: Colors.white),
          ),
        ),
      );

  Widget _sep() => Container(width: 1, height: 22, margin: const EdgeInsets.symmetric(horizontal: 4), color: Colors.white24);

  Widget _color(Color c, String css) => Tooltip(
        message: "Cor do texto",
        child: InkWell(
          onTap: () => _exec("foreColor", css),
          child: Container(
            width: 18,
            height: 18,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: Colors.white38)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final imgSelected = _selectedImg != null;
    return Container(
      decoration: BoxDecoration(border: Border.all(color: Colors.white24), borderRadius: BorderRadius.circular(10)),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          color: const Color(0xFF241C33),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 2, runSpacing: 4, children: [
            _btn(Icons.undo, "Desfazer", () => _exec("undo")),
            _btn(Icons.redo, "Refazer", () => _exec("redo")),
            _sep(),
            PopupMenuButton<String>(
              tooltip: "Estilo do texto",
              onSelected: (v) => _exec("formatBlock", v),
              itemBuilder: (_) => const [
                PopupMenuItem(value: "<h2>", child: Text("Título", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                PopupMenuItem(value: "<h3>", child: Text("Subtítulo", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                PopupMenuItem(value: "<p>", child: Text("Parágrafo")),
              ],
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.title, size: 19, color: Colors.white),
                  Icon(Icons.arrow_drop_down, size: 18, color: Colors.white70),
                ]),
              ),
            ),
            _btn(Icons.format_bold, "Negrito", () => _exec("bold")),
            _btn(Icons.format_italic, "Itálico", () => _exec("italic")),
            _btn(Icons.format_underlined, "Sublinhado", () => _exec("underline")),
            _btn(Icons.format_strikethrough, "Riscado", () => _exec("strikeThrough")),
            _sep(),
            _color(Colors.white, "#FFFFFF"),
            _color(const Color(0xFFC084FC), "#C084FC"),
            _color(const Color(0xFFFFC94D), "#FFC94D"),
            _color(const Color(0xFF3DDC97), "#3DDC97"),
            _color(const Color(0xFFFF6B81), "#FF6B81"),
            _color(const Color(0xFFB0A8C0), "#B0A8C0"),
            _sep(),
            _btn(Icons.format_align_left, "Alinhar à esquerda", () => _align("justifyLeft")),
            _btn(Icons.format_align_center, "Centralizar", () => _align("justifyCenter")),
            _btn(Icons.format_align_right, "Alinhar à direita", () => _align("justifyRight")),
            _btn(Icons.format_align_justify, "Justificar", () => _align("justifyFull")),
            _sep(),
            _btn(Icons.format_list_bulleted, "Lista", () => _exec("insertUnorderedList")),
            _btn(Icons.format_list_numbered, "Lista numerada", () => _exec("insertOrderedList")),
            _btn(Icons.horizontal_rule, "Linha divisória", () => _exec("insertHorizontalRule")),
            _sep(),
            _btn(Icons.link, imgSelected ? "Link na imagem" : "Link (selecione um texto)", _link),
            _btn(Icons.link_off, "Remover link", _unlink),
            _uploading
                ? const Padding(
                    padding: EdgeInsets.all(6),
                    child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : _btn(Icons.add_photo_alternate_outlined, "Inserir imagem", _pickImage),
            _btn(Icons.format_clear, "Limpar formatação", () => _exec("removeFormat")),
          ]),
        ),
        if (imgSelected)
          Container(
            color: const Color(0xFF2E2240),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, runSpacing: 4, children: [
              const Text("Imagem selecionada:", style: TextStyle(color: Colors.white70, fontSize: 12.5)),
              for (final w in ["25%", "50%", "75%", "100%"])
                OutlinedButton(
                  onPressed: () => _imageWidth(w),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white38),
                  ),
                  child: Text(w),
                ),
              TextButton.icon(
                onPressed: _link,
                icon: const Icon(Icons.link, size: 16, color: Color(0xFFC084FC)),
                label: const Text("Link", style: TextStyle(color: Color(0xFFC084FC))),
              ),
              TextButton.icon(
                onPressed: () {
                  final img = _selectedImg;
                  if (img == null) return;
                  final target = img.parent is html.AnchorElement ? img.parent! : img;
                  target.remove();
                  _selectImage(null);
                },
                icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                label: const Text("Remover", style: TextStyle(color: Colors.redAccent)),
              ),
              const Text("Use os botões de alinhamento para centralizar.", style: TextStyle(color: Colors.white38, fontSize: 11.5)),
            ]),
          ),
        SizedBox(height: widget.height, child: HtmlElementView(viewType: _viewType)),
      ]),
    );
  }
}
