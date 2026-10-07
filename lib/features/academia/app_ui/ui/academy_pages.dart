import "package:flutter/material.dart";

import "../data/academy_models.dart";
import "../data/academy_repository.dart";
import "academy_lesson_page.dart";
import "academy_theme.dart";
import "academy_widgets.dart";

/// Proxima aula: na serie (se a aula fizer parte de uma) ou na categoria.
AcademyLessonSummary? nextLessonOf(AcademyCatalog c, AcademyLessonSummary l) {
  final list = l.seriesId != null ? c.lessonsOfSeries(l.seriesId!) : (l.categoryId != null ? c.lessonsOf(l.categoryId!) : <AcademyLessonSummary>[]);
  final i = list.indexWhere((x) => x.id == l.id);
  for (var k = i + 1; k < list.length; k++) {
    if (!list[k].isSoon) return list[k];
  }
  return null;
}

/// Abre uma aula; ao voltar, [onReturn] recarrega o catalogo (progresso).
Future<void> openAcademyLesson(BuildContext context, AcademyRepository repo, AcademyCatalog catalog, AcademyLessonSummary lesson, {VoidCallback? onReturn, bool replace = false}) async {
  final route = MaterialPageRoute<void>(
    builder: (ctx) => AcademyLessonPage(
      repo: repo,
      summary: lesson,
      category: catalog.categoryOf(lesson),
      next: nextLessonOf(catalog, lesson),
      onOpenNext: (n) => openAcademyLesson(ctx, repo, catalog, n, replace: true),
    ),
  );
  final nav = Navigator.of(context);
  if (replace) {
    await nav.pushReplacement(route);
  } else {
    await nav.push(route);
  }
  onReturn?.call();
}

class _Page extends StatelessWidget {
  final String title;
  final Widget body;
  const _Page({required this.title, required this.body});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: acBgBottom,
        appBar: AppBar(backgroundColor: acBgTop, foregroundColor: Colors.white, title: Text(title)),
        body: AcademyBackground(child: body),
      );
}

const _statusFilters = <String?, String>{
  null: "Todos",
  "nao_iniciado": "Não iniciado",
  "em_andamento": "Em andamento",
  "concluido": "Concluído",
};

Widget _chip(String label, bool selected, VoidCallback onTap, {Color accent = acLilac}) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        selectedColor: accent.withValues(alpha: 0.28),
        backgroundColor: acCard,
        side: BorderSide(color: selected ? accent : Colors.white12),
        labelStyle: TextStyle(color: selected ? Colors.white : Colors.white70, fontWeight: FontWeight.w700, fontSize: 12.5),
      ),
    );

// ---------------------------------------------------------------- categoria

class AcademyCategoryPage extends StatefulWidget {
  final AcademyRepository repo;
  final AcademyCatalog catalog;
  final AcademyCategory category;
  final Future<AcademyCatalog> Function() reload;
  const AcademyCategoryPage({super.key, required this.repo, required this.catalog, required this.category, required this.reload});

  @override
  State<AcademyCategoryPage> createState() => _AcademyCategoryPageState();
}

class _AcademyCategoryPageState extends State<AcademyCategoryPage> {
  late AcademyCatalog _catalog = widget.catalog;
  String? _sub;
  String? _status;

  Future<void> _refresh() async {
    final c = await widget.reload();
    if (mounted) setState(() => _catalog = c);
  }

  @override
  Widget build(BuildContext context) {
    final cat = widget.category;
    final t = AcademyTheme.of(cat.theme);
    final all = _catalog.lessonsOf(cat.id);
    final subs = <String>{for (final l in all) if (l.subcategory != null) l.subcategory!}.toList();
    final lessons = all.where((l) => (_sub == null || l.subcategory == _sub) && (_status == null || l.learnStatus == _status)).toList();
    final done = all.where((l) => l.isDone).length;

    return Scaffold(
      backgroundColor: acBgBottom,
      body: AcademyBackground(
        child: CustomScrollView(slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 190,
            backgroundColor: t.gradient.last,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: t.gradient)),
                child: CustomPaint(
                  painter: AcademyPatternPainter(t.pattern, t.accent),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 80, 20, 18),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
                          Text(cat.title, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
                          if (cat.subtitle != null) Text(cat.subtitle!, style: const TextStyle(color: Colors.white70, fontSize: 13.5)),
                          const SizedBox(height: 6),
                          Text("${all.length} aulas · $done concluídas", style: TextStyle(color: t.accent, fontWeight: FontWeight.w800, fontSize: 12.5)),
                        ]),
                      ),
                      Text(cat.emoji, style: const TextStyle(fontSize: 52)),
                    ]),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (subs.length > 1)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      _chip("Tudo", _sub == null, () => setState(() => _sub = null), accent: t.accent),
                      for (final s in subs) _chip(s, _sub == s, () => setState(() => _sub = s), accent: t.accent),
                    ]),
                  ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    for (final e in _statusFilters.entries) _chip(e.value, _status == e.key, () => setState(() => _status = e.key), accent: t.accent),
                  ]),
                ),
              ]),
            ),
          ),
          if (lessons.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(padding: EdgeInsets.all(40), child: Center(child: Text("Nenhuma aula com esse filtro.", style: TextStyle(color: Colors.white54)))),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            sliver: SliverList.separated(
              itemCount: lessons.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => LessonTile(
                lesson: lessons[i],
                category: cat,
                onTap: () => openAcademyLesson(context, widget.repo, _catalog, lessons[i], onReturn: _refresh),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// -------------------------------------------------------------------- busca

class AcademySearchPage extends StatefulWidget {
  final AcademyRepository repo;
  final AcademyCatalog catalog;
  final Future<AcademyCatalog> Function() reload;
  const AcademySearchPage({super.key, required this.repo, required this.catalog, required this.reload});

  @override
  State<AcademySearchPage> createState() => _AcademySearchPageState();
}

class _AcademySearchPageState extends State<AcademySearchPage> {
  late AcademyCatalog _catalog = widget.catalog;
  final _query = TextEditingController();
  String? _category;
  String? _status;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final c = await widget.reload();
    if (mounted) setState(() => _catalog = c);
  }

  @override
  Widget build(BuildContext context) {
    final results = _catalog.search(_query.text, categoryId: _category, learnStatus: _status);
    return _Page(
      title: "Buscar na Academia",
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: TextField(
            controller: _query,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "🔎 O que você quer aprender?",
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: acCard,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              suffixIcon: _query.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () => setState(_query.clear),
                    ),
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.only(left: 16), children: [
            _chip("Todos", _category == null, () => setState(() => _category = null)),
            for (final c in _catalog.orderedCategories) _chip("${c.emoji} ${c.title}", _category == c.id, () => setState(() => _category = c.id)),
          ]),
        ),
        SizedBox(
          height: 44,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.only(left: 16), children: [
            for (final e in _statusFilters.entries) _chip(e.value, _status == e.key, () => setState(() => _status = e.key)),
          ]),
        ),
        Expanded(
          child: results.isEmpty
              ? const Center(child: Text("Nada encontrado. Tente outra palavra.", style: TextStyle(color: Colors.white54)))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  itemCount: results.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => LessonTile(
                    lesson: results[i],
                    category: _catalog.categoryOf(results[i]),
                    onTap: () => openAcademyLesson(context, widget.repo, _catalog, results[i], onReturn: _refresh),
                  ),
                ),
        ),
      ]),
    );
  }
}

// -------------------------------------------------------------------- serie

class AcademySeriesPage extends StatefulWidget {
  final AcademyRepository repo;
  final AcademyCatalog catalog;
  final AcademySeries series;
  final Future<AcademyCatalog> Function() reload;
  const AcademySeriesPage({super.key, required this.repo, required this.catalog, required this.series, required this.reload});

  @override
  State<AcademySeriesPage> createState() => _AcademySeriesPageState();
}

class _AcademySeriesPageState extends State<AcademySeriesPage> {
  late AcademyCatalog _catalog = widget.catalog;

  Future<void> _refresh() async {
    final c = await widget.reload();
    if (mounted) setState(() => _catalog = c);
  }

  @override
  Widget build(BuildContext context) {
    final lessons = _catalog.lessonsOfSeries(widget.series.id);
    final done = lessons.where((l) => l.isDone).length;
    return _Page(
      title: "${widget.series.emoji} ${widget.series.title}",
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 40), children: [
        if (widget.series.subtitle != null) Text(widget.series.subtitle!, style: const TextStyle(color: Colors.white70, fontSize: 14.5)),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(value: lessons.isEmpty ? 0 : done / lessons.length, minHeight: 8, backgroundColor: Colors.white10, color: acLilac),
        ),
        const SizedBox(height: 6),
        Text("$done de ${lessons.length} aulas concluídas · no seu ritmo", style: const TextStyle(color: Colors.white54, fontSize: 12.5)),
        const SizedBox(height: 16),
        for (var i = 0; i < lessons.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: LessonTile(
              lesson: lessons[i],
              number: i + 1,
              category: _catalog.categoryOf(lessons[i]),
              onTap: () => openAcademyLesson(context, widget.repo, _catalog, lessons[i], onReturn: _refresh),
            ),
          ),
      ]),
    );
  }
}
