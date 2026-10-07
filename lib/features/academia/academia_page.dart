import "package:flutter/material.dart";

import "academia_admin_service.dart";
import "app_ui/data/academy_models.dart";
import "app_ui/data/academy_repository.dart";
import "app_ui/ui/academy_home.dart";
import "lesson_editor.dart";

const _purple = Color(0xFF7A0BD4);
const _gold = Color(0xFFFFC94D);
const _card = Color(0xFF1B1626);

/// Home Central > Operações APP > Academia MDuck (antigo MAX Aulas).
class AcademiaPage extends StatefulWidget {
  const AcademiaPage({super.key});

  @override
  State<AcademiaPage> createState() => _AcademiaPageState();
}

class _AcademiaPageState extends State<AcademiaPage> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 5, vsync: this);
  String? _viewProfile;
  String? _viewAudience;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void viewAsStreamer(String profileId) {
    setState(() {
      _viewProfile = profileId;
      _viewAudience = null;
    });
    _tabs.animateTo(3);
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(28, 24, 28, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("🎓 ACADEMIA MDUCK", style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 1)),
          Text("Aprenda o que fazer, veja como funciona, pratique e aplique na próxima LIVE. Tudo aqui aparece na aba Academia do app.",
              style: TextStyle(color: Colors.white54, fontSize: 14)),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: _gold,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          labelStyle: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
          tabs: const [
            Tab(text: "📚  AULAS"),
            Tab(text: "🗂  CATEGORIAS E SÉRIES"),
            Tab(text: "📨  SOLICITAÇÕES"),
            Tab(text: "👁  VISUALIZAR COMO"),
            Tab(text: "📊  MÉTRICAS"),
          ],
        ),
      ),
      Expanded(
        child: TabBarView(controller: _tabs, children: [
          const _LessonsTab(),
          const _CategoriesTab(),
          _RequestsTab(onViewStreamer: viewAsStreamer),
          _ViewAsTab(
            profile: _viewProfile,
            audience: _viewAudience,
            onChanged: (p, a) => setState(() {
              _viewProfile = p;
              _viewAudience = a;
            }),
          ),
          const _MetricsTab(),
        ]),
      ),
    ]);
  }
}

// ============================================================================ AULAS

class _LessonsTab extends StatefulWidget {
  const _LessonsTab();

  @override
  State<_LessonsTab> createState() => _LessonsTabState();
}

class _LessonsTabState extends State<_LessonsTab> {
  final _s = AcademiaAdminService();
  List<Map<String, dynamic>> _lessons = [];
  List<Map<String, dynamic>> _cats = [];
  List<Map<String, dynamic>> _series = [];
  List<Map<String, dynamic>> _streamers = [];
  bool _loading = true;
  String? _error;
  String _query = "";
  String? _cat;
  String? _status;
  String? _availability;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait([_s.fetchLessons(), _s.fetchCategories(), _s.fetchSeries(), _s.fetchStreamers()]);
      if (!mounted) return;
      setState(() {
        _lessons = r[0];
        _cats = r[1];
        _series = r[2];
        _streamers = r[3];
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Não foi possível carregar. Rodou as migrações 0101 e 0102? ($e)";
          _loading = false;
        });
      }
    }
  }

  void _snack(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Future<void> _edit([Map<String, dynamic>? l]) async {
    final ok = await showLessonEditor(context, lesson: l, categories: _cats, series: _series, streamers: _streamers);
    if (ok == true) {
      _snack("Aula salva.");
      _load();
    }
  }

  Future<void> _quick(Map<String, dynamic> l, Map<String, dynamic> changes) async {
    try {
      await _s.updateLessons([l["id"] as String], changes);
      setState(() => l.addAll(changes));
    } catch (e) {
      _snack("Erro: $e");
    }
  }

  Future<void> _delete(Map<String, dynamic> l) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Excluir aula?"),
        content: Text("\"${l["title"]}\" será excluída, junto com o progresso e as solicitações dela. Não dá para desfazer."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Excluir", style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (ok != true) return;
    await _s.deleteLesson(l["id"] as String);
    _load();
  }

  Future<void> _bulkAvailability(List<Map<String, dynamic>> list, String value) async {
    await _s.updateLessons([for (final l in list) l["id"] as String], {"availability": value});
    _snack("${list.length} aula(s) atualizada(s).");
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!, style: const TextStyle(color: Colors.white70)));
    final q = academyNormalize(_query);
    bool match(Map l) =>
        (_cat == null || l["category_id"] == _cat) &&
        (_status == null || l["status"] == _status) &&
        (_availability == null || l["availability"] == _availability) &&
        (q.isEmpty || academyNormalize("${l["title"]} ${l["subtitle"] ?? ""} ${(l["tags"] as List?)?.join(" ") ?? ""}").contains(q));
    final filtered = _lessons.where(match).toList();
    final groups = <String?, List<Map<String, dynamic>>>{};
    for (final c in _cats) {
      groups[c["id"] as String] = [];
    }
    for (final l in filtered) {
      groups.putIfAbsent(l["category_id"] as String?, () => []).add(l);
    }

    return ListView(padding: const EdgeInsets.fromLTRB(24, 16, 24, 40), children: [
      Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
        ElevatedButton.icon(
          onPressed: () => _edit(),
          style: ElevatedButton.styleFrom(backgroundColor: _purple, foregroundColor: Colors.white),
          icon: const Icon(Icons.add),
          label: const Text("Nova aula"),
        ),
        const Tooltip(
          message: "Em breve: a IA gera um RASCUNHO (título, explicação, passos, quiz, Dica MDuck, checklist e desafio). Nunca publica sozinha: rascunho → revisão humana → publicação.",
          child: OutlinedButton(onPressed: null, child: Text("✨ Criar aula com IA (em breve)")),
        ),
        SizedBox(
          width: 240,
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: "Buscar aula", border: OutlineInputBorder(), isDense: true),
          ),
        ),
        _filter("Categoria", _cat, {for (final c in _cats) c["id"] as String: "${c["emoji"]} ${c["title"]}"}, (v) => setState(() => _cat = v)),
        _filter("Status", _status, academyStatus, (v) => setState(() => _status = v)),
        _filter("Disponibilidade", _availability, academyAvailability, (v) => setState(() => _availability = v)),
        PopupMenuButton<String>(
          tooltip: "Mudar a disponibilidade das aulas filtradas",
          onSelected: (v) => _bulkAvailability(filtered, v),
          itemBuilder: (_) => [for (final e in academyAvailability.entries) PopupMenuItem(value: e.key, child: Text("Todas filtradas → ${e.value}"))],
          child: const Chip(label: Text("Ação em massa")),
        ),
      ]),
      const SizedBox(height: 6),
      Text("${filtered.length} aula(s) · arraste para reordenar dentro da categoria", style: const TextStyle(color: Colors.white38, fontSize: 12)),
      for (final entry in groups.entries)
        if (entry.value.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: 22, bottom: 8),
            child: Text(
              () {
                final c = _cats.where((c) => c["id"] == entry.key).firstOrNull;
                return c == null ? "Sem categoria" : "${c["emoji"]}  ${c["title"]}".toUpperCase();
              }(),
              style: const TextStyle(color: _gold, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.4),
            ),
          ),
          ReorderableListView(
            shrinkWrap: true,
            buildDefaultDragHandles: false,
            physics: const NeverScrollableScrollPhysics(),
            onReorder: (a, b) async {
              final list = entry.value;
              if (b > a) b--;
              final item = list.removeAt(a);
              list.insert(b, item);
              setState(() {});
              await _s.reorder("academy_lessons", [for (final l in list) l["id"] as String]);
            },
            children: [for (var i = 0; i < entry.value.length; i++) _row(entry.value[i], i)],
          ),
        ],
    ]);
  }

  Widget _filter(String label, String? value, Map<String, String> options, ValueChanged<String?> onChanged) => SizedBox(
        width: 210,
        child: DropdownButtonFormField<String?>(
          initialValue: value,
          isExpanded: true,
          dropdownColor: _card,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text("Todas")),
            for (final e in options.entries) DropdownMenuItem<String?>(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: onChanged,
        ),
      );

  Widget _badge(String text, Color c) => Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: c.withValues(alpha: 0.5))),
        child: Text(text, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w700)),
      );

  Widget _row(Map<String, dynamic> l, int index) {
    final status = l["status"] as String? ?? "rascunho";
    final info = l["info_status"] as String? ?? "revisar";
    return Card(
      key: ValueKey(l["id"]),
      color: _card,
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(children: [
          ReorderableDragStartListener(index: index, child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.drag_indicator, color: Colors.white38))),
          Expanded(
            child: InkWell(
              onTap: () => _edit(l),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("${l["title"]}", style: TextStyle(color: l["is_active"] == false ? Colors.white38 : Colors.white, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Wrap(runSpacing: 4, children: [
                  _badge(academyStatus[status] ?? status, status == "publicado" ? const Color(0xFF3DDC97) : Colors.orangeAccent),
                  _badge(academyInfoStatus[info] ?? info, info == "atual" ? Colors.white54 : (info == "revisar" ? Colors.lightBlueAccent : Colors.redAccent)),
                  if (l["featured"] == true) _badge("🔥 destaque", _gold),
                  if (l["start_here"] == true) _badge("👋 comece aqui", _gold),
                  if (l["is_active"] == false) _badge("inativa", Colors.white38),
                  if (l["subcategory"] != null) _badge("${l["subcategory"]}", Colors.white54),
                  _badge("${(l["blocks"] as List?)?.length ?? 0} blocos", Colors.white54),
                ]),
              ]),
            ),
          ),
          SizedBox(
            width: 210,
            child: DropdownButton<String>(
              value: l["availability"] as String?,
              isExpanded: true,
              dropdownColor: _card,
              underline: const SizedBox.shrink(),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              items: [for (final e in academyAvailability.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
              onChanged: (v) => _quick(l, {"availability": v}),
            ),
          ),
          if (status != "publicado")
            TextButton(onPressed: () => _quick(l, {"status": "publicado"}), child: const Text("Publicar")),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white54),
            onSelected: (a) async {
              switch (a) {
                case "edit":
                  _edit(l);
                case "dup":
                  await _s.duplicateLesson(l);
                  _snack("Aula duplicada como rascunho.");
                  _load();
                case "active":
                  _quick(l, {"is_active": !(l["is_active"] as bool? ?? true)});
                case "draft":
                  _quick(l, {"status": "rascunho"});
                case "delete":
                  _delete(l);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: "edit", child: Text("Editar")),
              const PopupMenuItem(value: "dup", child: Text("Duplicar")),
              PopupMenuItem(value: "active", child: Text(l["is_active"] == false ? "Ativar" : "Desativar")),
              if (status == "publicado") const PopupMenuItem(value: "draft", child: Text("Voltar para rascunho")),
              const PopupMenuItem(value: "delete", child: Text("Excluir", style: TextStyle(color: Colors.redAccent))),
            ],
          ),
        ]),
      ),
    );
  }
}

// ============================================================ CATEGORIAS/SÉRIES

class _CategoriesTab extends StatefulWidget {
  const _CategoriesTab();

  @override
  State<_CategoriesTab> createState() => _CategoriesTabState();
}

class _CategoriesTabState extends State<_CategoriesTab> {
  final _s = AcademiaAdminService();
  List<Map<String, dynamic>> _cats = [];
  List<Map<String, dynamic>> _series = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait([_s.fetchCategories(), _s.fetchSeries()]);
      if (mounted) {
        setState(() {
          _cats = r[0];
          _series = r[1];
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editCategory([Map<String, dynamic>? c]) async {
    final data = Map<String, dynamic>.from(c ?? {"emoji": "📚", "theme": "fundamentos", "is_active": true, "sort_order": (_cats.length + 1) * 10});
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text(c == null ? "Nova categoria" : "Editar categoria"),
          content: SizedBox(
            width: 460,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _tf("Título", data, "title"),
              _tf("Descrição", data, "subtitle"),
              Row(children: [
                SizedBox(width: 90, child: _tf("Emoji", data, "emoji")),
                const SizedBox(width: 10),
                Expanded(child: _tf("Identificador (slug)", data, "slug", hint: "ex.: irl, fitness")),
              ]),
              DropdownButtonFormField<String>(
                initialValue: data["theme"] as String?,
                decoration: const InputDecoration(labelText: "Visual"),
                items: [for (final e in academyThemes.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                onChanged: (v) => data["theme"] = v,
              ),
              DropdownButtonFormField<String?>(
                initialValue: data["audience"] as String?,
                decoration: const InputDecoration(labelText: "Aparece primeiro para o perfil"),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text("— nenhum")),
                  for (final e in academyAudiences.entries.where((e) => e.key != "todos")) DropdownMenuItem<String?>(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) => data["audience"] = v,
              ),
              SwitchListTile(value: data["is_active"] == true, onChanged: (v) => set(() => data["is_active"] = v), title: const Text("Ativa")),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Salvar")),
          ],
        ),
      ),
    );
    if (ok != true) return;
    if ((data["slug"] as String? ?? "").trim().isEmpty) data["slug"] = academyNormalize(data["title"] as String? ?? "categoria").replaceAll(RegExp(r"[^a-z0-9]+"), "_");
    await _s.saveCategory(data);
    _load();
  }

  Future<void> _editSeries([Map<String, dynamic>? s]) async {
    final data = Map<String, dynamic>.from(s ?? {"emoji": "📚", "is_active": true, "sort_order": (_series.length + 1) * 10});
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text(s == null ? "Nova série" : "Editar série"),
          content: SizedBox(
            width: 460,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _tf("Título", data, "title"),
              _tf("Descrição", data, "subtitle"),
              Row(children: [
                SizedBox(width: 90, child: _tf("Emoji", data, "emoji")),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: data["category_id"] as String?,
                    decoration: const InputDecoration(labelText: "Categoria (visual)"),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text("—")),
                      for (final c in _cats) DropdownMenuItem<String?>(value: c["id"] as String, child: Text("${c["emoji"]} ${c["title"]}")),
                    ],
                    onChanged: (v) => data["category_id"] = v,
                  ),
                ),
              ]),
              SwitchListTile(value: data["is_active"] == true, onChanged: (v) => set(() => data["is_active"] = v), title: const Text("Ativa")),
              const Text("As aulas entram na série pelo editor da aula (campo Série e Ordem na série). É uma sequência de aulas — não um caminho visual.",
                  style: TextStyle(fontSize: 12, color: Colors.white54)),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Salvar")),
          ],
        ),
      ),
    );
    if (ok != true) return;
    if ((data["slug"] as String? ?? "").trim().isEmpty) data["slug"] = academyNormalize(data["title"] as String? ?? "serie").replaceAll(RegExp(r"[^a-z0-9]+"), "_");
    await _s.saveSeries(data);
    _load();
  }

  Widget _tf(String label, Map<String, dynamic> data, String key, {String? hint}) => TextFormField(
        initialValue: data[key] as String? ?? "",
        decoration: InputDecoration(labelText: label, hintText: hint),
        onChanged: (v) => data[key] = v,
      );

  Future<void> _confirmDelete(String what, Future<void> Function() action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Excluir $what?"),
        content: const Text("As aulas não são apagadas: só ficam sem essa categoria/série."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Excluir", style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (ok == true) {
      await action();
      _load();
    }
  }

  Widget _list(String title, List<Map<String, dynamic>> items, String table, VoidCallback onAdd, void Function(Map<String, dynamic>) onEdit,
          Future<void> Function(String id) onDelete) =>
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Text(title, style: const TextStyle(color: _gold, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.4)),
            const Spacer(),
            TextButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text("Adicionar")),
          ]),
          const Text("Arraste para mudar a ordem no app.", style: TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(height: 8),
          Expanded(
            child: ReorderableListView(
              buildDefaultDragHandles: false,
              onReorder: (a, b) async {
                if (b > a) b--;
                final it = items.removeAt(a);
                items.insert(b, it);
                setState(() {});
                await _s.reorder(table, [for (final x in items) x["id"] as String]);
              },
              children: [
                for (var i = 0; i < items.length; i++)
                  Card(
                    key: ValueKey(items[i]["id"]),
                    color: _card,
                    child: ListTile(
                      leading: ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_indicator, color: Colors.white38)),
                      title: Text("${items[i]["emoji"] ?? ""}  ${items[i]["title"]}",
                          style: TextStyle(color: items[i]["is_active"] == false ? Colors.white38 : Colors.white, fontWeight: FontWeight.w700)),
                      subtitle: Text(items[i]["subtitle"] as String? ?? "", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      onTap: () => onEdit(items[i]),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        onPressed: () => _confirmDelete("\"${items[i]["title"]}\"", () => onDelete(items[i]["id"] as String)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _list("CATEGORIAS", _cats, "academy_categories", () => _editCategory(), (c) => _editCategory(c), _s.deleteCategory),
        const SizedBox(width: 24),
        _list("AULAS EM SÉRIE", _series, "academy_series", () => _editSeries(), (s) => _editSeries(s), _s.deleteSeries),
      ]),
    );
  }
}

// ================================================================ SOLICITAÇÕES

class _RequestsTab extends StatefulWidget {
  final void Function(String profileId) onViewStreamer;
  const _RequestsTab({required this.onViewStreamer});

  @override
  State<_RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends State<_RequestsTab> {
  final _s = AcademiaAdminService();
  List<Map<String, dynamic>> _rows = [];
  List<Map<String, dynamic>> _cats = [];
  bool _loading = true;
  String? _status = "pendente";

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait([_s.fetchRequests(), _s.fetchCategories()]);
      if (mounted) {
        setState(() {
          _rows = r[0];
          _cats = r[1];
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handle(Map<String, dynamic> r, String status) async {
    final note = TextEditingController(text: r["note"] as String? ?? "");
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(status == "aprovado" ? "Aprovar acesso" : "Recusar acesso"),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(status == "aprovado" ? "A aula será liberada só para este streamer." : "O streamer verá que o conteúdo ainda não foi liberado."),
            const SizedBox(height: 10),
            TextField(controller: note, decoration: const InputDecoration(labelText: "Observação (interna)")),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(status == "aprovado" ? "Aprovar" : "Recusar")),
        ],
      ),
    );
    if (ok != true) return;
    await _s.handleRequest(r["id"] as String, status, note.text);
    _load();
  }

  Future<void> _viewLesson(Map<String, dynamic> r) async {
    final lessons = await _s.fetchLessons();
    final series = await _s.fetchSeries();
    final streamers = await _s.fetchStreamers();
    final l = lessons.where((x) => x["id"] == (r["lesson"] as Map?)?["id"]).firstOrNull;
    if (l == null || !mounted) return;
    await showLessonEditor(context, lesson: l, categories: _cats, series: series, streamers: streamers);
  }

  static String _date(String? iso) {
    final d = DateTime.tryParse(iso ?? "")?.toLocal();
    if (d == null) return "—";
    String two(int n) => n.toString().padLeft(2, "0");
    return "${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}";
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final rows = _rows.where((r) => _status == null || r["status"] == _status).toList();
    final colors = {"pendente": Colors.orangeAccent, "aprovado": const Color(0xFF3DDC97), "recusado": Colors.redAccent};
    return ListView(padding: const EdgeInsets.fromLTRB(24, 16, 24, 40), children: [
      Wrap(spacing: 8, children: [
        for (final e in {null: "Todas", "pendente": "Pendentes", "aprovado": "Aprovadas", "recusado": "Recusadas"}.entries)
          ChoiceChip(
            label: Text("${e.value} (${_rows.where((r) => e.key == null || r["status"] == e.key).length})"),
            selected: _status == e.key,
            onSelected: (_) => setState(() => _status = e.key),
          ),
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh, color: Colors.white54)),
      ]),
      const SizedBox(height: 12),
      if (rows.isEmpty) const Padding(padding: EdgeInsets.all(40), child: Center(child: Text("Nenhuma solicitação.", style: TextStyle(color: Colors.white38)))),
      for (final r in rows)
        Card(
          color: _card,
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text("${(r["profile"] as Map?)?["display_name"] ?? "—"}  ·  @${(r["profile"] as Map?)?["tiktok_username"] ?? "—"}",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(
                    "${(r["lesson"] as Map?)?["title"] ?? "aula removida"}  ·  ${() {
                      final c = _cats.where((c) => c["id"] == (r["lesson"] as Map?)?["category_id"]).firstOrNull;
                      return c == null ? "—" : "${c["emoji"]} ${c["title"]}";
                    }()}",
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    "Pedido em ${_date(r["created_at"] as String?)}${r["handled_by_name"] != null ? "  ·  Responsável: ${r["handled_by_name"]}" : ""}${r["note"] != null ? "  ·  Obs.: ${r["note"]}" : ""}",
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: colors[r["status"]] ?? Colors.white38)),
                child: Text("${r["status"]}", style: TextStyle(color: colors[r["status"]] ?? Colors.white38, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 10),
              if (r["status"] != "aprovado") TextButton(onPressed: () => _handle(r, "aprovado"), child: const Text("Aprovar")),
              if (r["status"] != "recusado") TextButton(onPressed: () => _handle(r, "recusado"), child: const Text("Recusar", style: TextStyle(color: Colors.redAccent))),
              TextButton(onPressed: () => _viewLesson(r), child: const Text("Ver conteúdo")),
              TextButton(
                onPressed: (r["profile"] as Map?)?["id"] == null ? null : () => widget.onViewStreamer((r["profile"] as Map)["id"] as String),
                child: const Text("Ver streamer"),
              ),
            ]),
          ),
        ),
    ]);
  }
}

// ============================================================== VISUALIZAR COMO

class _ViewAsTab extends StatefulWidget {
  final String? profile;
  final String? audience;
  final void Function(String? profile, String? audience) onChanged;
  const _ViewAsTab({required this.profile, required this.audience, required this.onChanged});

  @override
  State<_ViewAsTab> createState() => _ViewAsTabState();
}

class _ViewAsTabState extends State<_ViewAsTab> {
  final _s = AcademiaAdminService();
  List<Map<String, dynamic>> _streamers = [];

  @override
  void initState() {
    super.initState();
    _s.fetchStreamers().then((v) {
      if (mounted) setState(() => _streamers = v);
    }).catchError((_) {});
  }

  String _label(Map s) => "${s["display_name"] ?? "?"}${s["tiktok_username"] != null ? " (@${s["tiktok_username"]})" : ""}";

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final a = widget.audience;
    final viewing = p != null
        ? "Streamer: ${_label(_streamers.firstWhere((s) => s["id"] == p, orElse: () => {"display_name": "selecionado"}))}"
        : a == null
            ? "Equipe (tudo, inclusive rascunhos e bloqueados)"
            : "Perfil: ${academyAudiences[a]}";
    final repo = AcademyRepository(viewAsProfile: p, viewAsAudience: a);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        width: 380,
        child: ListView(padding: const EdgeInsets.all(24), children: [
          const Text("VISUALIZAR ACADEMIA COMO", style: TextStyle(color: _gold, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.4)),
          const SizedBox(height: 6),
          const Text("Teste a experiência sem mudar o perfil real de ninguém. Nada do que você fizer aqui conta como progresso.",
              style: TextStyle(color: Colors.white54, fontSize: 12.5)),
          const SizedBox(height: 14),
          RadioListTile<String?>(
            value: "__equipe",
            groupValue: p == null && a == null ? "__equipe" : (p != null ? "__s" : a),
            onChanged: (_) => widget.onChanged(null, null),
            title: const Text("👀 Equipe (vê tudo)", style: TextStyle(color: Colors.white)),
          ),
          for (final e in academyAudiences.entries)
            RadioListTile<String?>(
              value: e.key,
              groupValue: p == null && a == null ? "__equipe" : (p != null ? "__s" : a),
              onChanged: (v) => widget.onChanged(null, v),
              title: Text(e.key == "todos" ? "Todos (streamer sem perfil definido)" : e.value, style: const TextStyle(color: Colors.white)),
            ),
          const Divider(color: Colors.white12, height: 28),
          const Text("Visualizar como streamer específico", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Autocomplete<Map<String, dynamic>>(
            displayStringForOption: (s) => _label(s),
            optionsBuilder: (v) => _streamers.where((s) => academyNormalize(_label(s)).contains(academyNormalize(v.text))).take(15),
            onSelected: (s) => widget.onChanged(s["id"] as String, null),
            fieldViewBuilder: (context, controller, focus, submit) => TextField(
              controller: controller,
              focusNode: focus,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "Buscar streamer", border: OutlineInputBorder(), isDense: true),
            ),
          ),
          if (p != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text("Mostrando exatamente o que ${_label(_streamers.firstWhere((s) => s["id"] == p, orElse: () => {"display_name": "o streamer"}))} vê: perfil, liberações, solicitações e progresso.",
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ),
        ]),
      ),
      Expanded(
        child: Center(
          child: academyPhoneFrame(
            Navigator(
              key: ValueKey("$p|$a"),
              onGenerateRoute: (_) => MaterialPageRoute(
                builder: (_) => Scaffold(
                  backgroundColor: const Color(0xFF070A1C),
                  body: AcademyHome(
                    repo: repo,
                    banner: Container(
                      color: _purple,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Text("👁  Visualizando como — $viewing", style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

// ==================================================================== MÉTRICAS

class _MetricsTab extends StatefulWidget {
  const _MetricsTab();

  @override
  State<_MetricsTab> createState() => _MetricsTabState();
}

class _MetricsTabState extends State<_MetricsTab> {
  late Future<Map<String, dynamic>> _future = AcademiaAdminService().metrics();

  Widget _table(String title, List<String> headers, List<List<String>> rows) => Container(
        width: 520,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: const TextStyle(color: _gold, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          if (rows.isEmpty) const Text("Sem dados ainda.", style: TextStyle(color: Colors.white38)),
          if (rows.isNotEmpty)
            Table(
              columnWidths: {0: const FlexColumnWidth(3), for (var i = 1; i < headers.length; i++) i: const FlexColumnWidth(1)},
              children: [
                TableRow(children: [for (final h in headers) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(h, style: const TextStyle(color: Colors.white54, fontSize: 12)))]),
                for (final r in rows)
                  TableRow(children: [for (final c in r) Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Text(c, style: const TextStyle(color: Colors.white, fontSize: 13)))]),
              ],
            ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snap.hasError) return Center(child: Text("Não foi possível carregar: ${snap.error}", style: const TextStyle(color: Colors.white70)));
        final m = snap.data!;
        final lessons = [for (final x in (m["lessons"] as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
        int n(Map x, String k) => (x[k] as num?)?.toInt() ?? 0;
        String rate(Map x) => n(x, "learners") == 0 ? "—" : "${(100 * n(x, "completed") / n(x, "learners")).round()}%";
        final byViews = [...lessons]..sort((a, b) => n(b, "views").compareTo(n(a, "views")));
        final byDone = [...lessons]..sort((a, b) => n(b, "completed").compareTo(n(a, "completed")));
        final byReq = [...lessons]..sort((a, b) => n(b, "requests").compareTo(n(a, "requests")));
        final least = [...lessons]..sort((a, b) => n(a, "views").compareTo(n(b, "views")));
        final totalLearners = lessons.fold<int>(0, (s, x) => s + n(x, "learners"));
        final totalDone = lessons.fold<int>(0, (s, x) => s + n(x, "completed"));
        return ListView(padding: const EdgeInsets.all(24), children: [
          Row(children: [
            Text("Taxa de conclusão geral: ${totalLearners == 0 ? "—" : "${(100 * totalDone / totalLearners).round()}%"}",
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
            const Spacer(),
            IconButton(onPressed: () => setState(() => _future = AcademiaAdminService().metrics()), icon: const Icon(Icons.refresh, color: Colors.white54)),
          ]),
          const SizedBox(height: 14),
          Wrap(spacing: 16, runSpacing: 16, children: [
            _table("🔥 MAIS ACESSADAS", ["Aula", "Acessos", "Conclusão"], [for (final x in byViews.take(10)) ["${x["title"]}", "${n(x, "views")}", rate(x)]]),
            _table("✅ MAIS CONCLUÍDAS", ["Aula", "Concluídas"], [for (final x in byDone.take(10)) ["${x["title"]}", "${n(x, "completed")}"]]),
            _table("📨 MAIS SOLICITADAS", ["Aula", "Pedidos"], [for (final x in byReq.where((x) => n(x, "requests") > 0).take(10)) ["${x["title"]}", "${n(x, "requests")}"]]),
            _table("🧊 MENOS ACESSADAS", ["Aula", "Acessos"], [for (final x in least.take(10)) ["${x["title"]}", "${n(x, "views")}"]]),
            _table("🗂 CATEGORIAS MAIS POPULARES", ["Categoria", "Acessos", "Concluídas"],
                [for (final x in (m["categories"] as List? ?? const [])) ["${x["title"]}", "${(x as Map)["views"]}", "${x["completed"]}"]]),
            _table("🏅 STREAMERS QUE MAIS USAM", ["Streamer", "Acessos", "Concluídas"],
                [for (final x in (m["streamers"] as List? ?? const [])) ["${(x as Map)["display_name"] ?? x["tiktok_username"]}", "${x["views"]}", "${x["completed"]}"]]),
          ]),
        ]);
      },
    );
  }
}
