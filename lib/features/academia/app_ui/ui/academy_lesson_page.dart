import "dart:async";

import "package:flutter/material.dart";
import "package:url_launcher/url_launcher.dart";

import "../data/academy_models.dart";
import "../data/academy_repository.dart";
import "academy_blocks.dart";
import "academy_theme.dart";
import "academy_widgets.dart";

/// Aula da Academia. Segue a logica: O que e? → Como funciona? → Onde
/// encontro? → Como faco? → Como usar melhor? → Dica MDuck → Coloque em pratica
/// (a ordem dos blocos vem do painel).
class AcademyLessonPage extends StatefulWidget {
  final AcademyRepository repo;
  final AcademyLessonSummary summary;
  final AcademyCategory? category;

  /// proxima aula sugerida (serie ou categoria)
  final AcademyLessonSummary? next;
  final void Function(AcademyLessonSummary next)? onOpenNext;

  const AcademyLessonPage({super.key, required this.repo, required this.summary, this.category, this.next, this.onOpenNext});

  @override
  State<AcademyLessonPage> createState() => _AcademyLessonPageState();
}

class _AcademyLessonPageState extends State<AcademyLessonPage> {
  AcademyLesson? _lesson;
  bool _loading = true;
  String? _error;
  final _scroll = ScrollController();
  double _maxProgress = 0;
  bool _completed = false;
  bool _requesting = false;
  String? _requestStatus;
  Map<String, dynamic> _answers = {};
  Timer? _saveTimer;

  AcademyTheme get _theme => AcademyTheme.of(widget.category?.theme);

  @override
  void initState() {
    super.initState();
    _completed = widget.summary.isDone;
    _requestStatus = widget.summary.requestStatus;
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    if (_lesson != null && widget.summary.isOpen && !_completed && _maxProgress > 0) {
      widget.repo.track(widget.summary.id, "progress", progress: _maxProgress, quiz: _answers);
    }
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final l = await widget.repo.fetchLesson(widget.summary.id);
      if (!mounted) return;
      setState(() {
        _lesson = l;
        _answers = Map<String, dynamic>.from(l?.quiz ?? {});
        _requestStatus = l?.info.requestStatus ?? _requestStatus;
        _completed = l?.info.isDone ?? _completed;
        _loading = false;
      });
      if (l != null && l.info.isOpen) widget.repo.track(l.info.id, "open");
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Não foi possível abrir a aula.";
          _loading = false;
        });
      }
    }
  }

  void _onScroll() {
    if (!_scroll.hasClients || _scroll.position.maxScrollExtent <= 0) return;
    final p = (_scroll.offset / _scroll.position.maxScrollExtent).clamp(0.0, 1.0);
    if (p > _maxProgress + 0.05) _maxProgress = p;
  }

  void _answer(String key, dynamic value) {
    _answers[key] = value;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 2), () {
      widget.repo.track(widget.summary.id, "progress", progress: _maxProgress, quiz: {key: value});
    });
  }

  Future<void> _complete() async {
    setState(() => _completed = true);
    await widget.repo.track(widget.summary.id, "complete", quiz: _answers);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Aula concluída! 🎉")));
  }

  Future<void> _request() async {
    setState(() => _requesting = true);
    try {
      await widget.repo.requestAccess(widget.summary.id);
      if (mounted) setState(() => _requestStatus = "pendente");
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Não foi possível enviar agora. Tente de novo.")));
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _lesson?.info ?? widget.summary;
    return Scaffold(
      backgroundColor: acBgBottom,
      body: AcademyBackground(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: acLilac))
            : _error != null
                ? _ErrorView(message: _error!, onRetry: _load)
                : CustomScrollView(controller: _scroll, slivers: [
                    _header(s),
                    if (s.isSoon)
                      SliverToBoxAdapter(child: _soon())
                    else if (!s.isOpen || _lesson == null)
                      SliverToBoxAdapter(child: _locked())
                    else ...[
                      if (s.summary != null)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                            child: Text(s.summary!, style: const TextStyle(color: Colors.white, fontSize: 16.5, height: 1.45, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                        sliver: SliverList.separated(
                          itemCount: _lesson!.blocks.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 24),
                          itemBuilder: (_, i) => AcademyBlock(
                            block: _lesson!.blocks[i],
                            index: i,
                            accent: _theme.accent,
                            saved: _answers,
                            onAnswer: _answer,
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(child: _footer()),
                    ],
                  ]),
      ),
    );
  }

  Widget _header(AcademyLessonSummary s) {
    final t = _theme;
    final cover = _lesson?.info.coverUrl ?? s.coverUrl;
    return SliverAppBar(
      pinned: true,
      expandedHeight: 250,
      backgroundColor: t.gradient.last,
      foregroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(fit: StackFit.expand, children: [
          if (cover != null && cover.isNotEmpty)
            Image(image: academyImage(cover), fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink())
          else
            Container(
              decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: t.gradient)),
              child: CustomPaint(painter: AcademyPatternPainter(t.pattern, t.accent)),
            ),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xEE0C1230)], stops: [0.25, 1]),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 18,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text("${widget.category?.emoji ?? "📚"} ${(widget.category?.title ?? "Academia").toUpperCase()}",
                    style: TextStyle(color: t.accent, fontSize: 11.5, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                if (s.subcategory != null) Text("  ·  ${s.subcategory}", style: const TextStyle(color: Colors.white60, fontSize: 11.5)),
              ]),
              const SizedBox(height: 6),
              Text(s.title, style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900, height: 1.15)),
              if (s.subtitle != null) ...[
                const SizedBox(height: 4),
                Text(s.subtitle!, style: const TextStyle(color: Colors.white70, fontSize: 14)),
              ],
              const SizedBox(height: 8),
              Row(children: [
                Text(lessonMeta(s), style: const TextStyle(color: Colors.white60, fontSize: 12)),
                const Spacer(),
                if (s.status != "publicado")
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(10)),
                    child: Text(s.status == "rascunho" ? "Rascunho" : "Em revisão", style: const TextStyle(color: Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _locked() {
    final pending = _requestStatus == "pendente";
    final refused = _requestStatus == "recusado";
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 40),
      child: Column(children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.06), border: Border.all(color: Colors.white24)),
          child: Center(child: Text(pending ? "⏳" : "🔒", style: const TextStyle(fontSize: 38))),
        ),
        const SizedBox(height: 18),
        Text(pending ? "Solicitação enviada" : "Conteúdo ainda não disponível",
            textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text(
          pending
              ? "A equipe da MDuck recebeu sua solicitação e irá analisar a disponibilidade deste conteúdo."
              : refused
                  ? "Este conteúdo ainda não foi liberado para você. Você pode pedir de novo mais tarde."
                  : "Este conteúdo faz parte da Academia MDuck e ainda não está disponível para você.",
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 14.5, height: 1.45),
        ),
        const SizedBox(height: 22),
        if (!pending)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _requesting ? null : _request,
              style: FilledButton.styleFrom(backgroundColor: acPurple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)),
              icon: _requesting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.lock_open_rounded),
              label: const Text("Solicitar acesso", style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
      ]),
    );
  }

  Widget _soon() => const Padding(
        padding: EdgeInsets.fromLTRB(20, 36, 20, 40),
        child: Column(children: [
          Text("🔒", style: TextStyle(fontSize: 42)),
          SizedBox(height: 14),
          Text("Em preparação", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
          SizedBox(height: 8),
          Text("Estamos preparando novos conteúdos para você.", textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 14.5)),
        ]),
      );

  Widget _footer() {
    final l = _lesson!;
    final next = widget.next;
    final outdated = l.infoStatus == "desatualizado";
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (_completed)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFF3DDC97).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.check_circle, color: Color(0xFF3DDC97)),
              SizedBox(width: 8),
              Text("Aula concluída", style: TextStyle(color: Color(0xFF7CF2B0), fontWeight: FontWeight.w900, fontSize: 15)),
            ]),
          )
        else
          FilledButton(
            onPressed: _complete,
            style: FilledButton.styleFrom(backgroundColor: acPurple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)),
            child: const Text("Concluir aula", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          ),
        if (next != null) ...[
          const SizedBox(height: 18),
          const Text("PRÓXIMA AULA", style: TextStyle(color: Colors.white54, fontSize: 11.5, fontWeight: FontWeight.w900, letterSpacing: 1.4)),
          const SizedBox(height: 8),
          LessonTile(lesson: next, category: widget.category, onTap: () => widget.onOpenNext?.call(next)),
        ],
        if (l.sources.isNotEmpty) ...[
          const SizedBox(height: 26),
          Text("FONTES${l.reviewedAt != null ? " · revisado em ${_date(l.reviewedAt!)}" : ""}",
              style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
          if (outdated)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text("⚠️ Algumas informações podem estar desatualizadas e estão em revisão.", style: TextStyle(color: Colors.orangeAccent, fontSize: 12)),
            ),
          const SizedBox(height: 4),
          for (final src in l.sources)
            InkWell(
              onTap: src["url"] == null ? null : () => launchUrl(Uri.parse(src["url"] as String), mode: LaunchMode.externalApplication),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  "• ${src["title"] ?? src["url"]}${src["consulted_at"] != null ? " (consultado em ${_date(DateTime.tryParse("${src["consulted_at"]}") ?? DateTime.now())})" : ""}",
                  style: const TextStyle(color: Colors.white54, fontSize: 12, decoration: TextDecoration.underline, decorationColor: Colors.white24),
                ),
              ),
            ),
        ],
      ]),
    );
  }

  static String _date(DateTime d) => "${d.day.toString().padLeft(2, "0")}/${d.month.toString().padLeft(2, "0")}/${d.year}";
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Column(children: [
          Align(alignment: Alignment.topLeft, child: BackButton(color: Colors.white, onPressed: () => Navigator.of(context).maybePop())),
          Expanded(
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(message, style: const TextStyle(color: Colors.white70)),
                TextButton(onPressed: onRetry, child: const Text("Tentar de novo")),
              ]),
            ),
          ),
        ]),
      );
}
