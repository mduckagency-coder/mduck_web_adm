import "package:flutter/material.dart";

import "rich_html_editor.dart";
import "app_config_service.dart";

const _purple = Color(0xFF7A0BD4);
const _gold = Color(0xFFFFC94D);
const _card = Color(0xFF1B1626);

/// Qual parte das Configurações do Aplicativo a pagina edita.
enum AppConfigSection { sobre, ajuda, versao, textos }

class _Field {
  final String key;
  final String label;
  final String help;
  final int lines;
  const _Field(this.key, this.label, this.help, {this.lines = 1});
}

const _sections = <AppConfigSection, (String, String, List<_Field>)>{
  AppConfigSection.sobre: (
    "Sobre a MDuck",
    "Aparece em Configurações > Sobre a MDuck, no app.",
    [
      _Field("about_title", "Título", "Nome do item e título da tela."),

    ],
  ),
  AppConfigSection.ajuda: (
    "Ajuda e Suporte — Central de Informações",
    "Aparece no app em Configurações > Central de Informações. Cada item da lista abaixo é uma seção (título + texto). O botão \"Falar com minha gestão\" usa o gestor responsável e o WhatsApp do cadastro dele. Os contatos de suporte só aparecem se forem preenchidos.",
    [
      _Field("help_text", "Texto de abertura", "Frase no topo da Central de Informações.", lines: 3),
      _Field("info_version", "Versão das informações", "Aparece no fim da Central. Ex.: Versão 1.0 — Outubro/2026"),
      _Field("support_text", "Texto do suporte", "Frase acima dos contatos.", lines: 2),
      _Field("support_whatsapp", "WhatsApp do suporte", "Com DDD. Ex.: (11) 99999-9999"),
      _Field("support_email", "E-mail do suporte", "Ex.: suporte@..."),
    ],
  ),
  AppConfigSection.versao: (
    "Versão e Atualizações",
    "Rodapé de Configurações no app: \"Versão X\" e \"Última atualização: DD/MM/AAAA\".",
    [
      _Field("version_label", "Versão exibida", "Ex.: 1.0.0 Beta"),
    ],
  ),
  AppConfigSection.textos: (
    "Textos do Aplicativo",
    "Textos fixos das telas de Configurações e de Reportar um problema.",
    [
      _Field("welcome_title", "Boas-vindas: título", "Popup que aparece ao entrar na Home (uma vez por versão). Padrão: Boas-vindas ao MDuck Lives!"),
      _Field("welcome_text", "Boas-vindas: texto", "Deixe vazio para usar o texto padrão (versão Beta, atrasos nas métricas, como reportar e a Central de Informações). Para mostrar de novo a todos, mude a versão em Versão e Atualizações.", lines: 4),
      _Field("settings_title", "Título da tela de Configurações", ""),
      _Field("report_intro", "Introdução do Reportar um problema", "", lines: 3),
      _Field("report_success", "Mensagem após enviar o reporte", "", lines: 2),
      _Field("app_info_text", "Texto de Informações do app", "", lines: 3),
    ],
  ),
};

class AppConfigPage extends StatefulWidget {
  final AppConfigSection section;
  const AppConfigPage({super.key, required this.section});

  @override
  State<AppConfigPage> createState() => _AppConfigPageState();
}

class _AppConfigPageState extends State<AppConfigPage> {
  final _service = AppConfigService();
  final Map<String, TextEditingController> _controllers = {};
  List<(TextEditingController, TextEditingController)> _faq = [];
  DateTime? _lastUpdate;
  final _rich = RichHtmlEditorController();
  String _aboutHtml = "";
  bool _loaded = false;
  bool _saving = false;
  String? _error;

  (String, String, List<_Field>) get _def => _sections[widget.section]!;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final c = await _service.fetchConfig();
      if (!mounted) return;
      setState(() {
        for (final f in _def.$3) {
          _controllers[f.key] = TextEditingController(text: (c[f.key] ?? "").toString());
        }
        _faq = [
          for (final item in (c["faq"] as List? ?? const []))
            if (item is Map)
              (TextEditingController(text: (item["q"] ?? "").toString()), TextEditingController(text: (item["a"] ?? "").toString())),
        ];
        _lastUpdate = DateTime.tryParse((c["last_update"] ?? "").toString());
        _aboutHtml = _initialAboutHtml(c);
        _loaded = true;
      });
    } catch (e) {
      if (mounted) setState(() => _error = "Não foi possível carregar. Rodou a migração 0099? ($e)");
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final (q, a) in _faq) {
      q.dispose();
      a.dispose();
    }
    super.dispose();
  }

  /// HTML salvo; na primeira vez, monta a partir do texto simples antigo.
  static String _initialAboutHtml(Map<String, dynamic> c) {
    final saved = (c["about_html"] ?? "").toString().trim();
    if (saved.isNotEmpty) return saved;
    final text = (c["about_text"] ?? "").toString().trim();
    String esc(String s) => s.replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;");
    return [for (final p in text.split(RegExp(r"\n\s*\n"))) if (p.trim().isNotEmpty) "<p>${esc(p.trim()).replaceAll("\n", "<br>")}</p>"].join();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final changes = <String, dynamic>{
        for (final e in _controllers.entries) e.key: e.value.text.trim(),
      };
      if (widget.section == AppConfigSection.ajuda) {
        changes["faq"] = [
          for (final (q, a) in _faq)
            if (q.text.trim().isNotEmpty) {"q": q.text.trim(), "a": a.text.trim()},
        ];
      }
      if (widget.section == AppConfigSection.sobre) {
        final rich = _rich.html.trim();
        final plain = _rich.plainText;
        changes["about_html"] = plain.isEmpty && !rich.contains("<img") ? "" : rich;
        // versao sem formatacao (reserva pra versoes antigas do app)
        if (plain.isNotEmpty) changes["about_text"] = plain;
      }
      if (widget.section == AppConfigSection.versao && _lastUpdate != null) {
        final d = _lastUpdate!;
        changes["last_update"] = "${d.year}-${d.month.toString().padLeft(2, "0")}-${d.day.toString().padLeft(2, "0")}";
      }
      await _service.saveConfig(changes);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Salvo. O app mostra na próxima vez que abrir a tela.")));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao salvar: $e")));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        border: const OutlineInputBorder(),
        isDense: true,
        alignLabelWithHint: true,
      );

  Widget _box(String title, List<Widget> children) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: _gold, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          const SizedBox(height: 12),
          ...children,
        ]),
      );

  String _fmt(DateTime d) => "${d.day.toString().padLeft(2, "0")}/${d.month.toString().padLeft(2, "0")}/${d.year}";

  @override
  Widget build(BuildContext context) {
    if (_error != null) return Center(child: Text(_error!, style: const TextStyle(color: Colors.white70)));
    if (!_loaded) return const Center(child: CircularProgressIndicator());
    final (title, help, fields) = _def;
    return ListView(padding: const EdgeInsets.all(24), children: [
      Text(title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text(help, style: const TextStyle(color: Colors.white54, fontSize: 13)),
      const SizedBox(height: 20),
      _box("TEXTOS", [
        for (final f in fields)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(
                controller: _controllers[f.key],
                minLines: f.lines,
                maxLines: f.lines == 1 ? 1 : f.lines + 6,
                style: const TextStyle(color: Colors.white),
                decoration: _dec(f.label),
              ),
              if (f.help.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 2),
                  child: Text(f.help, style: const TextStyle(color: Colors.white38, fontSize: 11.5)),
                ),
            ]),
          ),
        if (widget.section == AppConfigSection.versao)
          Row(children: [
            Text("Última atualização: ${_lastUpdate == null ? "—" : _fmt(_lastUpdate!)}", style: const TextStyle(color: Colors.white)),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _lastUpdate ?? DateTime.now(),
                  firstDate: DateTime(2024),
                  lastDate: DateTime(2100),
                );
                if (d != null) setState(() => _lastUpdate = d);
              },
              child: const Text("Escolher data"),
            ),
            const SizedBox(width: 8),
            TextButton(onPressed: () => setState(() => _lastUpdate = DateTime.now()), child: const Text("Hoje")),
          ]),
      ]),
      if (widget.section == AppConfigSection.sobre)
        _box("TEXTO DA PÁGINA", [
          const Text(
            "Edite como um e-mail: negrito, títulos, cores, centralizar, listas, imagens e links. "
            "Para pôr link numa imagem, clique na imagem e depois em Link. O app mostra exatamente este visual.",
            style: TextStyle(color: Colors.white54, fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          RichHtmlEditor(initialHtml: _aboutHtml, controller: _rich, uploadImage: _service.uploadContentImage),
        ]),
      if (widget.section == AppConfigSection.ajuda)
        _box("SEÇÕES DA CENTRAL / PERGUNTAS FREQUENTES", [
          if (_faq.isEmpty) const Text("Nenhuma pergunta.", style: TextStyle(color: Colors.white38)),
          for (var i = 0; i < _faq.length; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(border: Border.all(color: Colors.white12), borderRadius: BorderRadius.circular(10)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(children: [
                    TextField(controller: _faq[i].$1, style: const TextStyle(color: Colors.white), decoration: _dec("Título da seção ou pergunta")),
                    const SizedBox(height: 8),
                    TextField(controller: _faq[i].$2, minLines: 3, maxLines: 20, style: const TextStyle(color: Colors.white), decoration: _dec("Texto")),
                  ]),
                ),
                Column(children: [
                  IconButton(
                    tooltip: "Subir",
                    onPressed: i == 0 ? null : () => setState(() => _faq.insert(i - 1, _faq.removeAt(i))),
                    icon: const Icon(Icons.arrow_upward, size: 18, color: Colors.white54),
                  ),
                  IconButton(
                    tooltip: "Descer",
                    onPressed: i == _faq.length - 1 ? null : () => setState(() => _faq.insert(i + 1, _faq.removeAt(i))),
                    icon: const Icon(Icons.arrow_downward, size: 18, color: Colors.white54),
                  ),
                  IconButton(
                    tooltip: "Remover",
                    onPressed: () => setState(() => _faq.removeAt(i)),
                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                  ),
                ]),
              ]),
            ),
          TextButton.icon(
            onPressed: () => setState(() => _faq.add((TextEditingController(), TextEditingController()))),
            icon: const Icon(Icons.add),
            label: const Text("Adicionar pergunta"),
          ),
        ]),
      Align(
        alignment: Alignment.centerLeft,
        child: ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(backgroundColor: _purple, foregroundColor: Colors.white),
          child: Text(_saving ? "Salvando..." : "Salvar"),
        ),
      ),
    ]);
  }
}
