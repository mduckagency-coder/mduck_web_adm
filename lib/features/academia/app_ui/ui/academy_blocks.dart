import "package:flutter/material.dart";
import "package:url_launcher/url_launcher.dart";

import "academy_interactive.dart";
import "academy_theme.dart";
import "live_scenes.dart";

/// Desenha um bloco de aula. Tipos (todos editaveis no painel):
///   text, platform ("Como o TikTok funciona"), tip (Dica MDuck), strategy
///   (Experiencia / estrategia MDuck), image (imagem/GIF), youtube, video,
///   steps, example, discover (toque para descobrir), flow, simulation,
///   identify, quiz, checklist, challenge (Coloque em pratica).
class AcademyBlock extends StatelessWidget {
  final Map<String, dynamic> block;
  final int index;
  final Color accent;

  /// respostas ja salvas (quiz/checklist), por indice do bloco
  final Map<String, dynamic> saved;
  final void Function(String key, dynamic value)? onAnswer;

  const AcademyBlock({super.key, required this.block, required this.index, required this.accent, this.saved = const {}, this.onAnswer});

  String? s(String k) {
    final v = block[k];
    return v is String && v.trim().isNotEmpty ? v : null;
  }

  List<String> list(String k) => [for (final x in (block[k] as List? ?? const [])) if (x != null) x.toString()];
  List<Map> maps(String k) => [for (final x in (block[k] as List? ?? const [])) if (x is Map) x];

  @override
  Widget build(BuildContext context) {
    switch (block["type"]) {
      case "text":
        return _Section(
          label: s("label"),
          title: s("title"),
          accent: accent,
          child: _Body(s("body") ?? ""),
        );
      case "platform":
        return _Callout(
          icon: const _TikTokMark(),
          title: s("title") ?? "Como o TikTok funciona",
          color: const Color(0xFF25F4EE),
          children: [
            _Body(s("body") ?? ""),
            if (block["varies"] == true)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text("ℹ️ A disponibilidade deste recurso pode variar.", style: TextStyle(color: Colors.white60, fontSize: 12.5, fontStyle: FontStyle.italic)),
              ),
            if (s("source_url") != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                  onPressed: () => launchUrl(Uri.parse(s("source_url")!), mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.open_in_new, size: 14, color: Color(0xFF25F4EE)),
                  label: const Text("Ver página oficial", style: TextStyle(color: Color(0xFF25F4EE), fontSize: 12.5)),
                ),
              ),
          ],
        );
      case "tip":
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(colors: [Color(0xFF6D28D9), Color(0xFF3B1786)]),
            boxShadow: [BoxShadow(color: acPurple.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 6))],
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("🦆", style: TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text("💡 DICA MDUCK", style: TextStyle(color: acGold, fontSize: 11.5, fontWeight: FontWeight.w900, letterSpacing: 1.4)),
                const SizedBox(height: 4),
                Text(s("body") ?? "", style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4, fontWeight: FontWeight.w700)),
              ]),
            ),
          ]),
        );
      case "strategy":
        return _Callout(
          icon: const Text("🧪", style: TextStyle(fontSize: 18)),
          title: s("title") ?? "Experiência / estratégia MDuck",
          color: const Color(0xFFFFB020),
          children: [_Body(s("body") ?? "")],
        );
      case "image":
        final url = s("url");
        if (url == null) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image(image: academyImage(url), fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox(height: 60, child: Center(child: Icon(Icons.broken_image, color: Colors.white38)))),
          ),
          if (s("caption") != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(s("caption")!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 12.5)),
            ),
        ]);
      case "youtube":
      case "video":
        return _VideoCard(block: block, accent: accent);
      case "steps":
        final items = list("items");
        return _Section(
          label: "Como faço?",
          title: s("title"),
          accent: accent,
          child: Column(children: [
            for (var i = 0; i < items.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: accent.withValues(alpha: 0.2), border: Border.all(color: accent.withValues(alpha: 0.6))),
                    child: Text("${i + 1}", style: TextStyle(color: accent, fontWeight: FontWeight.w900, fontSize: 12.5)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Padding(padding: const EdgeInsets.only(top: 3), child: _Body(items[i]))),
                ]),
              ),
          ]),
        );
      case "example":
        return _Callout(
          icon: const Text("📌", style: TextStyle(fontSize: 18)),
          title: s("title") ?? "Exemplo",
          color: accent,
          children: [_Body(s("body") ?? "")],
        );
      case "discover":
        return _Section(
          label: "Toque para descobrir",
          title: s("title"),
          accent: accent,
          child: _Discover(items: maps("items"), accent: accent),
        );
      case "flow":
        return _Section(label: "Como funciona?", title: s("title"), accent: accent, child: _Flow(items: maps("items"), accent: accent));
      case "simulation":
        return _Section(
          label: "✨ Simulação",
          title: s("title") ?? "Explore a LIVE",
          accent: accent,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (s("intro") != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: _Body(s("intro")!)),
            LiveScene(scene: s("scene") ?? "conversa", overrides: block["hotspots"] as Map?, accent: accent),
          ]),
        );
      case "tiktok_profile":
        return TikTokProfileBlock(block);
      case "league_ladder":
        return LeagueLadderBlock(block, accent: accent);
      case "gift_gallery":
        return GiftGalleryBlock(block, accent: accent);
      case "feed":
        return FeedBlock(block, accent: accent);
      case "recap":
        return RecapBlock(block);
      case "live_menu":
        return LiveMenuBlock(block, accent: accent);
      case "tiktok_sheet":
        return TikTokSheetBlock(block, accent: accent);
      case "compare":
        return CompareBlock(block, accent: accent);
      case "viewer_view":
        return ViewerViewBlock(block, accent: accent);
      case "identify":
        return _Section(
          label: "✨ Desafio de olhar",
          title: s("title") ?? "Identifique na tela",
          accent: accent,
          child: LiveScene(scene: s("scene") ?? "games", identify: true, prompts: maps("prompts"), accent: accent),
        );
      case "quiz":
        return _Quiz(
          question: s("question") ?? "",
          options: list("options"),
          correct: (block["correct"] as num?)?.toInt() ?? 0,
          explanation: s("explanation"),
          accent: accent,
          initial: (saved["$index"] as num?)?.toInt(),
          onAnswer: (i) => onAnswer?.call("$index", i),
        );
      case "checklist":
        return _Checklist(
          title: s("title") ?? "Checklist",
          items: list("items"),
          accent: accent,
          initial: [for (final x in (saved["c$index"] as List? ?? const [])) (x as num).toInt()],
          onChanged: (v) => onAnswer?.call("c$index", v),
        );
      case "challenge":
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: const Color(0xFF3DDC97).withValues(alpha: 0.10),
            border: Border.all(color: const Color(0xFF3DDC97).withValues(alpha: 0.5), width: 1.4),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("🎯", style: TextStyle(fontSize: 26)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text("COLOQUE EM PRÁTICA", style: TextStyle(color: Color(0xFF7CF2B0), fontSize: 11.5, fontWeight: FontWeight.w900, letterSpacing: 1.4)),
                const SizedBox(height: 4),
                Text(s("body") ?? "", style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                const Text("Sem obrigação: é um convite para a sua próxima LIVE.", style: TextStyle(color: Colors.white54, fontSize: 12)),
              ]),
            ),
          ]),
        );
    }
    return const SizedBox.shrink();
  }
}

class _Body extends StatelessWidget {
  final String text;
  const _Body(this.text);

  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(color: Color(0xFFE6E0F5), fontSize: 15, height: 1.5));
}

class _Section extends StatelessWidget {
  final String? label;
  final String? title;
  final Color accent;
  final Widget child;
  const _Section({this.label, this.title, required this.accent, required this.child});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (label != null)
          Text(label!.toUpperCase(), style: TextStyle(color: accent, fontSize: 11.5, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(title!, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, height: 1.2)),
          ),
        const SizedBox(height: 10),
        child,
      ]);
}

class _Callout extends StatelessWidget {
  final Widget icon;
  final String title;
  final Color color;
  final List<Widget> children;
  const _Callout({required this.icon, required this.title, required this.color, required this.children});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            icon,
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.3))),
          ]),
          const SizedBox(height: 8),
          ...children,
        ]),
      );
}

/// Marca simples "nota musical" nas cores do TikTok (sem usar a logo).
class _TikTokMark extends StatelessWidget {
  const _TikTokMark();

  @override
  Widget build(BuildContext context) => Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(7)),
        child: const Stack(children: [
          Positioned(left: 1, top: 1, child: Icon(Icons.music_note, size: 16, color: Color(0xFF25F4EE))),
          Positioned(left: 3, top: 3, child: Icon(Icons.music_note, size: 16, color: Color(0xFFFE2C55))),
          Positioned(left: 2, top: 2, child: Icon(Icons.music_note, size: 16, color: Colors.white)),
        ]),
      );
}

class _VideoCard extends StatelessWidget {
  final Map<String, dynamic> block;
  final Color accent;
  const _VideoCard({required this.block, required this.accent});

  @override
  Widget build(BuildContext context) {
    final url = (block["url"] as String?) ?? "";
    final yt = block["type"] == "youtube";
    final thumb = yt ? youtubeThumb(url) : (block["thumbnail_url"] as String?);
    final title = block["title"] as String?;
    final desc = block["description"] as String?;
    final dur = block["duration"] as String?;
    if (url.isEmpty) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => academyVideoOpener(context, url: url, youtube: yt, title: title),
      child: Container(
        decoration: BoxDecoration(color: acCard, borderRadius: BorderRadius.circular(18)),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(fit: StackFit.expand, children: [
              if (thumb != null)
                Image(image: academyImage(thumb), fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: Colors.black26))
              else
                Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [accent.withValues(alpha: 0.4), acCard]))),
              Container(color: Colors.black26),
              Center(
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: yt ? const Color(0xFFFF0033) : acPurple),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 38),
                ),
              ),
              if (dur != null)
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(6)),
                    child: Text(dur, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(yt ? "🎬 VÍDEO NO YOUTUBE" : "🎬 VÍDEO", style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
              if (title != null) ...[
                const SizedBox(height: 3),
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
              ],
              if (desc != null) ...[
                const SizedBox(height: 3),
                Text(desc, style: const TextStyle(color: Colors.white60, fontSize: 13)),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Discover extends StatefulWidget {
  final List<Map> items;
  final Color accent;
  const _Discover({required this.items, required this.accent});

  @override
  State<_Discover> createState() => _DiscoverState();
}

class _DiscoverState extends State<_Discover> {
  final Set<int> _open = {};

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final w = (box.maxWidth - 10) / 2;
      return Wrap(spacing: 10, runSpacing: 10, children: [
        for (var i = 0; i < widget.items.length; i++)
          GestureDetector(
            onTap: () => setState(() => _open.contains(i) ? _open.remove(i) : _open.add(i)),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              width: _open.contains(i) ? box.maxWidth : w,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _open.contains(i) ? widget.accent.withValues(alpha: 0.16) : acCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _open.contains(i) ? widget.accent : Colors.white12),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text("${widget.items[i]["emoji"] ?? "✨"}", style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text("${widget.items[i]["title"] ?? ""}",
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                  ),
                  Icon(_open.contains(i) ? Icons.remove_circle_outline : Icons.add_circle_outline, color: widget.accent, size: 18),
                ]),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  child: _open.contains(i)
                      ? Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text("${widget.items[i]["body"] ?? ""}", style: const TextStyle(color: Color(0xFFE6E0F5), fontSize: 14, height: 1.45)),
                        )
                      : const SizedBox(width: double.infinity),
                ),
              ]),
            ),
          ),
      ]);
    });
  }
}

class _Flow extends StatefulWidget {
  final List<Map> items;
  final Color accent;
  const _Flow({required this.items, required this.accent});

  @override
  State<_Flow> createState() => _FlowState();
}

class _FlowState extends State<_Flow> {
  int _step = -1;

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < items.length; i++) ...[
        GestureDetector(
          onTap: () => setState(() => _step = i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: i <= _step ? widget.accent.withValues(alpha: 0.16) : acCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: i == _step ? widget.accent : Colors.white12, width: i == _step ? 1.6 : 1),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                AnimatedScale(
                  scale: i == _step ? 1.25 : 1,
                  duration: const Duration(milliseconds: 280),
                  child: Text("${items[i]["emoji"] ?? "•"}", style: const TextStyle(fontSize: 24)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text("${items[i]["label"] ?? ""}", style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800))),
                if (i > _step) Text("toque", style: TextStyle(color: widget.accent.withValues(alpha: 0.7), fontSize: 11)),
              ]),
              if (i <= _step && (items[i]["body"] ?? "").toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 36),
                  child: Text("${items[i]["body"]}", style: const TextStyle(color: Color(0xFFE6E0F5), fontSize: 13.5, height: 1.4)),
                ),
            ]),
          ),
        ),
        if (i < items.length - 1)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Icon(Icons.arrow_downward_rounded, color: i < _step ? widget.accent : Colors.white24, size: 20),
          ),
      ],
    ]);
  }
}

class _Quiz extends StatefulWidget {
  final String question;
  final List<String> options;
  final int correct;
  final String? explanation;
  final Color accent;
  final int? initial;
  final ValueChanged<int> onAnswer;
  const _Quiz({required this.question, required this.options, required this.correct, this.explanation, required this.accent, this.initial, required this.onAnswer});

  @override
  State<_Quiz> createState() => _QuizState();
}

class _QuizState extends State<_Quiz> {
  late int? _chosen = widget.initial;

  @override
  Widget build(BuildContext context) {
    final answered = _chosen != null;
    final right = _chosen == widget.correct;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: acCard, borderRadius: BorderRadius.circular(18), border: Border.all(color: widget.accent.withValues(alpha: 0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text("🧩 QUIZ RÁPIDO", style: TextStyle(color: widget.accent, fontSize: 11.5, fontWeight: FontWeight.w900, letterSpacing: 1.4)),
        const SizedBox(height: 6),
        Text(widget.question, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, height: 1.35)),
        const SizedBox(height: 12),
        for (var i = 0; i < widget.options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: !answered
                  ? Colors.white.withValues(alpha: 0.05)
                  : i == widget.correct
                      ? const Color(0xFF3DDC97).withValues(alpha: 0.18)
                      : i == _chosen
                          ? const Color(0xFFFF6B81).withValues(alpha: 0.18)
                          : Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  setState(() => _chosen = i);
                  widget.onAnswer(i);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Row(children: [
                    Text("${String.fromCharCode(65 + i)})", style: TextStyle(color: widget.accent, fontWeight: FontWeight.w900)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(widget.options[i], style: const TextStyle(color: Colors.white, fontSize: 14.5))),
                    if (answered && i == widget.correct) const Icon(Icons.check_circle, color: Color(0xFF3DDC97), size: 20),
                    if (answered && i == _chosen && i != widget.correct) const Icon(Icons.cancel, color: Color(0xFFFF6B81), size: 20),
                  ]),
                ),
              ),
            ),
          ),
        if (answered)
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(right ? "Boa! 🎉" : "Quase! 💜", style: TextStyle(color: right ? const Color(0xFF7CF2B0) : const Color(0xFFFFB4C2), fontSize: 16, fontWeight: FontWeight.w900)),
                if (widget.explanation != null)
                  Padding(padding: const EdgeInsets.only(top: 4), child: Text(widget.explanation!, style: const TextStyle(color: Color(0xFFE6E0F5), fontSize: 14, height: 1.4))),
              ]),
            ),
          ),
      ]),
    );
  }
}

class _Checklist extends StatefulWidget {
  final String title;
  final List<String> items;
  final Color accent;
  final List<int> initial;
  final ValueChanged<List<int>> onChanged;
  const _Checklist({required this.title, required this.items, required this.accent, required this.initial, required this.onChanged});

  @override
  State<_Checklist> createState() => _ChecklistState();
}

class _ChecklistState extends State<_Checklist> {
  late final Set<int> _done = {...widget.initial};

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        decoration: BoxDecoration(color: acCard, borderRadius: BorderRadius.circular(18)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Text("✅ ${widget.title.toUpperCase()}", style: TextStyle(color: widget.accent, fontSize: 11.5, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
            const Spacer(),
            Text("${_done.length}/${widget.items.length}", style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 6),
          for (var i = 0; i < widget.items.length; i++)
            InkWell(
              onTap: () {
                setState(() => _done.contains(i) ? _done.remove(i) : _done.add(i));
                widget.onChanged(_done.toList()..sort());
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: _done.contains(i) ? const Color(0xFF3DDC97) : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _done.contains(i) ? const Color(0xFF3DDC97) : Colors.white38, width: 1.6),
                    ),
                    child: _done.contains(i) ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(widget.items[i],
                        style: TextStyle(
                          color: _done.contains(i) ? Colors.white54 : Colors.white,
                          fontSize: 14.5,
                          decoration: _done.contains(i) ? TextDecoration.lineThrough : null,
                        )),
                  ),
                ]),
              ),
            ),
        ]),
      );
}
