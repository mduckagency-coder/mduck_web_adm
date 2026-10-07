import "package:flutter/material.dart";

import "../data/academy_models.dart";
import "academy_theme.dart";

/// Selo de estado da aula (cadeado, em breve, concluida, em andamento).
class LessonStatusBadge extends StatelessWidget {
  final AcademyLessonSummary lesson;
  const LessonStatusBadge({super.key, required this.lesson});

  @override
  Widget build(BuildContext context) {
    final l = lesson;
    final (String text, Color c) = l.isSoon
        ? ("👁️ Em breve", const Color(0xFF8EC5FF))
        : l.isLocked
            ? (l.requestStatus == "pendente" ? "⏳ Solicitado" : "🔒 Bloqueado", Colors.white70)
            : l.isDone
                ? ("✓ Concluída", const Color(0xFF3DDC97))
                : l.isStarted
                    ? ("▶ ${(l.progress * 100).clamp(5, 99).round()}%", acGold)
                    : ("", Colors.transparent);
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(20), border: Border.all(color: c.withValues(alpha: 0.6))),
      child: Text(text, style: TextStyle(color: c, fontSize: 10.5, fontWeight: FontWeight.w800)),
    );
  }
}

/// Miniatura da aula: imagem do painel ou arte da categoria.
class LessonThumb extends StatelessWidget {
  final AcademyLessonSummary lesson;
  final AcademyCategory? category;
  final double emojiSize;
  const LessonThumb({super.key, required this.lesson, this.category, this.emojiSize = 34});

  @override
  Widget build(BuildContext context) {
    final t = AcademyTheme.of(category?.theme);
    final url = lesson.thumbnailUrl;
    final art = Container(
      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: t.gradient)),
      child: CustomPaint(
        painter: AcademyPatternPainter(t.pattern, t.accent),
        child: Center(child: Text(category?.emoji ?? "📚", style: TextStyle(fontSize: emojiSize))),
      ),
    );
    return Stack(fit: StackFit.expand, children: [
      if (url != null && url.isNotEmpty) Image(image: academyImage(url), fit: BoxFit.cover, errorBuilder: (_, _, _) => art) else art,
      if (lesson.isLocked || lesson.isSoon) Container(color: Colors.black.withValues(alpha: 0.35)),
    ]);
  }
}

String lessonMeta(AcademyLessonSummary l) => [
      academyLevels[l.level] ?? l.level,
      if (l.durationMin != null) "${l.durationMin} min",
      if (l.hasVideo) "🎬",
      if (l.hasSimulation) "✨",
      if (l.hasQuiz) "🧩",
    ].join("  ·  ");

/// Card vertical (listas horizontais da home).
class LessonCard extends StatelessWidget {
  final AcademyLessonSummary lesson;
  final AcademyCategory? category;
  final VoidCallback onTap;
  final double width;
  const LessonCard({super.key, required this.lesson, this.category, required this.onTap, this.width = 210});

  @override
  Widget build(BuildContext context) {
    final t = AcademyTheme.of(category?.theme);
    return SizedBox(
      width: width,
      child: Material(
        color: acCard,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              height: 104,
              child: Stack(fit: StackFit.expand, children: [
                LessonThumb(lesson: lesson, category: category),
                Positioned(right: 8, top: 8, child: LessonStatusBadge(lesson: lesson)),
                if (lesson.isStarted)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: LinearProgressIndicator(value: lesson.progress.clamp(0.05, 1), minHeight: 3, backgroundColor: Colors.black26, color: acGold),
                  ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text((category?.title ?? "").toUpperCase(),
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.accent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                const SizedBox(height: 3),
                Text(lesson.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w800, height: 1.25)),
                const SizedBox(height: 6),
                Text(lessonMeta(lesson), maxLines: 1, style: const TextStyle(color: Colors.white54, fontSize: 11.5)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Linha de aula (listas de categoria, busca, serie).
class LessonTile extends StatelessWidget {
  final AcademyLessonSummary lesson;
  final AcademyCategory? category;
  final VoidCallback onTap;
  final int? number;
  const LessonTile({super.key, required this.lesson, this.category, required this.onTap, this.number});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: acCard,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 74,
                height: 74,
                child: Stack(fit: StackFit.expand, children: [
                  LessonThumb(lesson: lesson, category: category, emojiSize: 26),
                  if (number != null)
                    Align(
                      alignment: Alignment.topLeft,
                      child: Container(
                        margin: const EdgeInsets.all(4),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                        child: Text("$number", style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                      ),
                    ),
                ]),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(lesson.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800, height: 1.25)),
                if (lesson.subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(lesson.subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60, fontSize: 12.5)),
                ],
                const SizedBox(height: 5),
                Row(children: [
                  Expanded(child: Text(lessonMeta(lesson), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white38, fontSize: 11.5))),
                  LessonStatusBadge(lesson: lesson),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Card grande de categoria ("O que voce quer aprender hoje?").
class CategoryCard extends StatelessWidget {
  final AcademyCategory category;
  final int total;
  final int done;
  final bool forYou;
  final VoidCallback onTap;
  const CategoryCard({super.key, required this.category, required this.total, required this.done, required this.forYou, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = AcademyTheme.of(category.theme);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: forYou ? 150 : 128,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: t.gradient),
          border: Border.all(color: t.accent.withValues(alpha: forYou ? 0.8 : 0.3), width: forYou ? 1.6 : 1),
          boxShadow: [BoxShadow(color: t.gradient.first.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 8))],
        ),
        clipBehavior: Clip.antiAlias,
        child: CustomPaint(
          painter: AcademyPatternPainter(t.pattern, t.accent),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  if (forYou)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(20)),
                      child: const Text("⭐ Para o seu perfil", style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)),
                    ),
                  Text(category.title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, height: 1.1)),
                  if (category.subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(category.subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.3)),
                  ],
                  const SizedBox(height: 8),
                  Text("$total aulas${done > 0 ? "  ·  $done concluídas" : ""}",
                      style: TextStyle(color: t.accent, fontSize: 12, fontWeight: FontWeight.w800)),
                ]),
              ),
              const SizedBox(width: 8),
              Text(category.emoji, style: TextStyle(fontSize: forYou ? 54 : 46)),
            ]),
          ),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final String? action;
  final VoidCallback? onAction;
  const SectionTitle(this.text, {super.key, this.action, this.onAction});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 26, 8, 10),
        child: Row(children: [
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900))),
          if (action != null) TextButton(onPressed: onAction, child: Text(action!, style: const TextStyle(color: acLilac))),
        ]),
      );
}

class AcademyBackground extends StatelessWidget {
  final Widget child;
  const AcademyBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [acBgTop, acBgMid, acBgBottom]),
        ),
        child: child,
      );
}
