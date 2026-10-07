import "package:flutter/material.dart";

import "../data/academy_models.dart";
import "../data/academy_repository.dart";
import "academy_pages.dart";
import "academy_theme.dart";
import "academy_widgets.dart";

/// 🎓 Academia MDuck: home (aba do app e previa do painel).
class AcademyHome extends StatefulWidget {
  final AcademyRepository repo;

  /// faixa extra no topo (ex.: "Visualizando como..." no painel)
  final Widget? banner;
  const AcademyHome({super.key, this.repo = const AcademyRepository(), this.banner});

  @override
  State<AcademyHome> createState() => _AcademyHomeState();
}

class _AcademyHomeState extends State<AcademyHome> {
  AcademyCatalog? _catalog;
  Object? _error;
  final _scroll = ScrollController();
  final _categoriesKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant AcademyHome old) {
    super.didUpdateWidget(old);
    if (old.repo.viewAsProfile != widget.repo.viewAsProfile || old.repo.viewAsAudience != widget.repo.viewAsAudience) {
      setState(() => _catalog = null);
      _reload();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<AcademyCatalog> _reload() async {
    try {
      final c = await widget.repo.fetchCatalog();
      if (mounted) {
        setState(() {
          _catalog = c;
          _error = null;
        });
      }
      return c;
    } catch (e) {
      if (mounted) setState(() => _error = e);
      rethrow;
    }
  }

  void _open(AcademyLessonSummary l) => openAcademyLesson(context, widget.repo, _catalog!, l, onReturn: _reload);

  void _push(Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page)).then((_) => _reload());

  @override
  Widget build(BuildContext context) {
    final c = _catalog;
    if (c == null) {
      return AcademyBackground(
        child: Center(
          child: _error == null
              ? const CircularProgressIndicator(color: acLilac)
              : Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text("Não foi possível carregar a Academia.", style: TextStyle(color: Colors.white70)),
                  TextButton(onPressed: _reload, child: const Text("Tentar de novo")),
                ]),
        ),
      );
    }
    final overall = c.overall;
    final cats = c.orderedCategories;

    return AcademyBackground(
      child: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(controller: _scroll, padding: const EdgeInsets.only(bottom: 40), children: [
          ?widget.banner,
          _header(c),
          _searchBar(c),
          if (overall.total > 0) _progressCard(overall.done, overall.total),
          if (c.continueLearning.isNotEmpty) ...[
            const SectionTitle("▶️ Continue de onde parou"),
            _hList(c, c.continueLearning),
          ],
          if (c.isNewcomer && c.startHere.isNotEmpty) _startHere(c),
          if (c.recommended.isNotEmpty) ...[
            const SectionTitle("✨ Recomendado para você"),
            _hList(c, c.recommended),
          ],
          if (c.featured.isNotEmpty) ...[
            const SectionTitle("🔥 Em destaque"),
            _hList(c, c.featured),
          ],
          SectionTitle("O que você quer aprender hoje?", key: _categoriesKey),
          for (final cat in cats)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: CategoryCard(
                category: cat,
                total: c.lessonsOf(cat.id).where((l) => !l.isSoon).length,
                done: c.lessonsOf(cat.id).where((l) => l.isDone).length,
                forYou: c.audience != "todos" && cat.audience == c.audience,
                onTap: () => _push(AcademyCategoryPage(repo: widget.repo, catalog: c, category: cat, reload: _reload)),
              ),
            ),
          if (c.series.any((s) => c.lessonsOfSeries(s.id).isNotEmpty)) ...[
            const SectionTitle("📚 Aulas em série"),
            for (final s in c.series.where((s) => c.lessonsOfSeries(s.id).isNotEmpty)) _seriesTile(c, s),
          ],
          if (c.comingSoon.isNotEmpty) ...[
            const SectionTitle("👁️ Em breve"),
            _hList(c, c.comingSoon),
          ],
        ]),
      ),
    );
  }

  Widget _header(AcademyCatalog c) {
    final profileLine = switch (c.audience) {
      "games" => "Conteúdos de 🎮 Games aparecem primeiro para você — e a Academia inteira continua aberta.",
      "musica" => "Conteúdos de 🎤 Música aparecem primeiro para você — e a Academia inteira continua aberta.",
      "batalhas" => "Conteúdos de ⚔️ Batalhas aparecem primeiro para você — e a Academia inteira continua aberta.",
      _ => null,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("🎓 Academia MDuck", style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900, height: 1.1)),
        const SizedBox(height: 4),
        const Text("Aprenda, pratique e evolua na sua LIVE.", style: TextStyle(color: acLilacSoft, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        const Text("Conteúdos selecionados para ajudar você a aproveitar melhor suas LIVEs.", style: TextStyle(color: Colors.white60, fontSize: 13.5, height: 1.35)),
        if (profileLine != null) ...[
          const SizedBox(height: 4),
          Text(profileLine, style: const TextStyle(color: Colors.white38, fontSize: 12, height: 1.35)),
        ],
      ]),
    );
  }

  Widget _searchBar(AcademyCatalog c) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Material(
          color: acCard,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _push(AcademySearchPage(repo: widget.repo, catalog: c, reload: _reload)),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(children: [
                Icon(Icons.search, color: Colors.white54),
                SizedBox(width: 10),
                Text("O que você quer aprender?", style: TextStyle(color: Colors.white54, fontSize: 15)),
              ]),
            ),
          ),
        ),
      );

  Widget _progressCard(int done, int total) {
    final p = total == 0 ? 0.0 : done / total;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(colors: [Color(0xFF2B1260), Color(0xFF151A45)]),
        border: Border.all(color: acLilac.withValues(alpha: 0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text("Seu progresso na Academia", style: TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w800)),
          const Spacer(),
          Text("${(p * 100).round()}%", style: const TextStyle(color: acGold, fontSize: 16, fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: p),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 9, backgroundColor: Colors.white10, color: acLilac),
          ),
        ),
        const SizedBox(height: 8),
        Text("$done de $total aulas concluídas · aprenda no seu ritmo", style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ]),
    );
  }

  Widget _startHere(AcademyCatalog c) => Container(
        margin: const EdgeInsets.fromLTRB(16, 22, 16, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text("👋 Não sabe por onde começar?", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text("Separamos três conteúdos para você dar o primeiro passo.", style: TextStyle(color: Colors.white60, fontSize: 13)),
          const SizedBox(height: 12),
          for (var i = 0; i < c.startHere.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: LessonTile(lesson: c.startHere[i], number: i + 1, category: c.categoryOf(c.startHere[i]), onTap: () => _open(c.startHere[i])),
            ),
          TextButton(
            onPressed: () {
              final ctx = _categoriesKey.currentContext;
              if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 500), curve: Curves.easeOutCubic);
            },
            child: const Text("Explorar Academia →", style: TextStyle(color: acLilac, fontWeight: FontWeight.w800)),
          ),
        ]),
      );

  Widget _hList(AcademyCatalog c, List<AcademyLessonSummary> list) => SizedBox(
        height: 206,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (_, i) => LessonCard(lesson: list[i], category: c.categoryOf(list[i]), onTap: () => _open(list[i])),
        ),
      );

  Widget _seriesTile(AcademyCatalog c, AcademySeries s) {
    final lessons = c.lessonsOfSeries(s.id);
    final done = lessons.where((l) => l.isDone).length;
    final cat = c.categories.where((x) => x.id == s.categoryId).firstOrNull;
    final t = AcademyTheme.of(cat?.theme);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Material(
        color: acCard,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _push(AcademySeriesPage(repo: widget.repo, catalog: c, series: s, reload: _reload)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), gradient: LinearGradient(colors: t.gradient)),
                child: Text(s.emoji, style: const TextStyle(fontSize: 26)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.title, style: const TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w800)),
                  if (s.subtitle != null) Text(s.subtitle!, style: const TextStyle(color: Colors.white60, fontSize: 12.5)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(value: lessons.isEmpty ? 0 : done / lessons.length, minHeight: 5, backgroundColor: Colors.white10, color: t.accent),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text("$done/${lessons.length}", style: const TextStyle(color: Colors.white54, fontSize: 11.5, fontWeight: FontWeight.w700)),
                  ]),
                ]),
              ),
              const Icon(Icons.chevron_right, color: Colors.white38),
            ]),
          ),
        ),
      ),
    );
  }
}
