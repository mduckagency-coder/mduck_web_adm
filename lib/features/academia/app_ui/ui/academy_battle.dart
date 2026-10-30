part of "academy_interactive.dart";

// Missões de Batalha:
//   battle_sim   Batalha animada em passos (placar, cronômetro, missão,
//                chat, presente voando, Tap Tap, luva, WIN/LOSE)
//   multiplier   presentes x1/x2/x3 com a conta na tela
//   tap_tap      o streamer toca e vê os pontos subirem
// Tudo vem do painel; nomes e números são fictícios/ilustrativos.

int _int(Map m, String k, [int d = 0]) => int.tryParse(_s(m, k).replaceAll(".", "")) ?? d;
String _fmt(int v) {
  final s = v.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(".");
    b.write(s[i]);
  }
  return b.toString();
}

// ---------------------------------------------------------------- batalha animada

class BattleSimBlock extends StatefulWidget {
  final Map block;
  final Color accent;
  const BattleSimBlock(this.block, {super.key, required this.accent});

  @override
  State<BattleSimBlock> createState() => _BattleSimBlockState();
}

class _BattleSimBlockState extends State<BattleSimBlock> {
  int _i = 0;
  int _secs = 0;
  Timer? _tick;
  Timer? _auto;
  final List<Map> _chat = [];

  Map get b => widget.block;
  List<Map> get steps => _maps(b, "steps");
  Map get st => steps.isEmpty ? const {} : steps[_i.clamp(0, steps.length - 1)];

  @override
  void initState() {
    super.initState();
    _enter();
  }

  @override
  void dispose() {
    _tick?.cancel();
    _auto?.cancel();
    super.dispose();
  }

  void _enter() {
    _tick?.cancel();
    _secs = _int(st, "seconds");
    // chat acumulado até este passo
    _chat
      ..clear()
      ..addAll([
        for (var k = 0; k <= _i && k < steps.length; k++)
          for (final line in _s(steps[k], "chat").split("|").map((x) => x.trim()).where((x) => x.isNotEmpty))
            {"user": line.contains(":") ? line.split(":").first.trim() : "@fã", "text": line.contains(":") ? line.split(":").skip(1).join(":").trim() : line},
      ]);
    if (_chat.length > 4) _chat.removeRange(0, _chat.length - 4);
    _tick = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        if (_secs > 0) _secs--;

      });
    });
  }

  void _go(int d) {
    final n = (_i + d).clamp(0, steps.length - 1);
    if (n == _i) return;
    setState(() => _i = n);
    _enter();
  }

  void _toggleAuto() {
    if (_auto != null) {
      _auto!.cancel();
      setState(() => _auto = null);
      return;
    }
    if (_i >= steps.length - 1) {
      setState(() => _i = 0);
      _enter();
    }
    setState(() {
      _auto = Timer.periodic(Duration(milliseconds: _int(b, "auto_ms", 3800)), (t) {
        if (!mounted || _i >= steps.length - 1) {
          t.cancel();
          if (mounted) setState(() => _auto = null);
          return;
        }
        _go(1);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _blockHeader(b, widget.accent),
      ClipRRect(borderRadius: BorderRadius.circular(24), child: _screen()),
      const SizedBox(height: 10),
      // legenda do passo
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: Container(
          key: ValueKey(_i),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: acCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: widget.accent.withValues(alpha: 0.35))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (steps.length > 1)
              Text("${_i + 1} de ${steps.length}", style: TextStyle(color: widget.accent, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
            if (_s(st, "caption").isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: IconText(_s(st, "caption"), style: const TextStyle(color: Colors.white, fontSize: 14.5, height: 1.45, fontWeight: FontWeight.w600)),
              ),
          ]),
        ),
      ),
      if (steps.length > 1) ...[
        const SizedBox(height: 8),
        Row(children: [
          IconButton(
            onPressed: _i == 0 ? null : () => _go(-1),
            icon: const Icon(Icons.chevron_left_rounded),
            color: Colors.white70,
            disabledColor: Colors.white12,
          ),
          Expanded(
            child: steps.length > 8
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(value: (_i + 1) / steps.length, minHeight: 5, backgroundColor: Colors.white12, color: widget.accent),
                  )
                : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var k = 0; k < steps.length; k++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: k == _i ? 16 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(color: k <= _i ? widget.accent : Colors.white24, borderRadius: BorderRadius.circular(3)),
                ),
            ]),
          ),
          TextButton(
            onPressed: _toggleAuto,
            child: Text(_auto != null ? "⏸ Pausar" : "▶ Assistir", style: TextStyle(color: widget.accent, fontWeight: FontWeight.w800)),
          ),
          _Hot(
            active: _i == 0 && _auto == null,
            radius: 20,
            onTap: _i >= steps.length - 1 ? () {} : () => _go(1),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: _i >= steps.length - 1 ? Colors.white12 : acPurple, borderRadius: BorderRadius.circular(20)),
              child: const Text("Próximo ›", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
      ],
    ]);
  }

  // ----- tela da batalha (igual ao TikTok LIVE)
  static const _red = Color(0xFFE5254F);

  Widget _screen() {
    final left = _int(st, "left");
    final right = _int(st, "right");
    final total = left + right;
    final frac = total == 0 ? 0.5 : (left / total).clamp(0.12, 0.88);
    final result = _s(st, "result");
    final gift = _s(st, "gift");
    return Container(
      height: 540,
      color: Colors.black,
      child: Column(children: [
        // topo: host + espectadores
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(color: const Color(0xFF3A1020), borderRadius: BorderRadius.circular(22)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                FakeAvatar(_s(b, "left_name", "@LucasLive"), size: 28),
                const SizedBox(width: 5),
                Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(_s(b, "left_name", "@LucasLive"), style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800)),
                  const Text("✦ LIVE Pro", style: TextStyle(color: Colors.white70, fontSize: 9.5)),
                ]),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(color: const Color(0xFFFE2C55), borderRadius: BorderRadius.circular(14)),
                  child: const Text("+ Seguir", style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)),
                ),
              ]),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(12)),
              child: Text(_s(b, "viewers", "1.6K"), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.close, color: Colors.white, size: 18),
          ]),
        ),
        // placar
        LayoutBuilder(builder: (context, box) {
          return Row(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              width: box.maxWidth * frac,
              height: 22,
              padding: const EdgeInsets.only(left: 8),
              alignment: Alignment.centerLeft,
              decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFFF2D7A), Color(0xFFFF7EB3)])),
              child: _count(left),
            ),
            Expanded(
              child: Container(
                height: 22,
                padding: const EdgeInsets.only(right: 8),
                alignment: Alignment.centerRight,
                decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF5CE1E6), Color(0xFF1FB6FF)])),
                child: _count(right),
              ),
            ),
          ]);
        }),
        // vídeos
        SizedBox(
          height: 300,
          child: Stack(children: [
            Row(children: [
              _video(const [Color(0xFF6B3A7A), Color(0xFF2A1630)], result == "win" ? "WIN" : result == "lose" ? "LOSE" : null),
              Container(width: 2, color: Colors.black),
              _video(const [Color(0xFF7A8FA6), Color(0xFF3A4A5E)], result == "win" ? "LOSE" : result == "lose" ? "WIN" : null),
            ]),
            // cronômetro
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: const BoxDecoration(color: Color(0xCC111111), borderRadius: BorderRadius.vertical(bottom: Radius.circular(10))),
                child: Text("⚔️ ${_s(st, "timer", "04:28")}  ›", style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800)),
              ),
            ),
            // WIN xN de cada lado
            Positioned(left: 6, top: 6, child: _winBadge(_wins(true))),
            Positioned(right: 6, top: 6, child: _winBadge(_wins(false))),
            // cartão "enviou Rosa" (sem x1)
            if (gift.isNotEmpty)
              Positioned(
                left: 6,
                top: 108,
                child: TweenAnimationBuilder<double>(
                  key: ValueKey("n$_i"),
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutBack,
                  builder: (_, v, child) => Transform.translate(offset: Offset(-60 * (1 - v), 0), child: Opacity(opacity: v.clamp(0.0, 1.0), child: child)),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
                    decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(24)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      FakeAvatar(_s(st, "gift_from", "@ana_live"), size: 30),
                      const SizedBox(width: 6),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text(_s(st, "gift_from", "@ana_live"), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                        Text(_s(st, "gift_name", gift == "🌹" ? "enviou Rosa" : "enviou um presente"), style: const TextStyle(color: Colors.white70, fontSize: 9.5)),
                      ]),
                      const SizedBox(width: 6),
                      Text(gift, style: const TextStyle(fontSize: 26)),
                    ]),
                  ),
                ),
              ),
            // luva
            if (_yes(st["glove"]))
              Positioned(
                left: 8,
                top: 34,
                child: _pulse(Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12), border: Border.all(color: acGold)),
                  child: Column(children: [
                    const Text("🥊", style: TextStyle(fontSize: 26)),
                    Text(_s(st, "glove_label", "x5"), style: const TextStyle(color: acGold, fontSize: 12, fontWeight: FontWeight.w900)),
                  ]),
                )),
              ),
            // missão: tarja vermelha embaixo dos vídeos
            Positioned(left: 0, right: 0, bottom: 10, child: Center(child: _banner())),
            // conta / presente voando
            if (gift.isNotEmpty || _s(st, "calc").isNotEmpty)
              Positioned.fill(child: _GiftFly(key: ValueKey("g$_i"), gift: gift, calc: _s(st, "calc"), toGlove: _yes(st["glove"]))),
            if (_yes(st["taps"])) Positioned.fill(child: _TapRain(key: ValueKey("t$_i"), points: _int(st, "tap_points", 3))),
          ]),
        ),
        // parte de baixo: chat + corações
        Expanded(
          child: Stack(children: [
            Positioned(
              left: 8,
              right: 70,
              bottom: 8,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final c in _chat)
                  TweenAnimationBuilder<double>(
                    key: ValueKey("${c["user"]}${c["text"]}$_i"),
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 300),
                    builder: (_, v, child) => Opacity(opacity: v.clamp(0.0, 1.0), child: child),
                    child: Container(
                      margin: const EdgeInsets.only(top: 5),
                      padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(18)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        FakeAvatar("${c["user"]}", size: 24),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text.rich(TextSpan(children: [
                            TextSpan(text: "${c["user"]}  ", style: const TextStyle(color: Colors.white60, fontWeight: FontWeight.w600)),
                            TextSpan(text: "${c["text"]}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                          ]), style: const TextStyle(fontSize: 11.5)),
                        ),
                      ]),
                    ),
                  ),
              ]),
            ),
            const Positioned(right: 6, top: 0, bottom: 0, width: 56, child: _HeartsUp()),
          ]),
        ),
      ]),
    );
  }

  /// Vitórias seguidas: quem perde volta a 0; quem ganha soma +1 no resultado.
  String _wins(bool left) {
    final base = int.tryParse(_s(st, left ? "left_wins" : "right_wins", _s(b, left ? "left_wins" : "right_wins", left ? "3" : "0"))) ?? 0;
    final r = _s(st, "result");
    if (r.isEmpty) return "$base";
    final won = (r == "win") == left;
    return won ? "${base + 1}" : "0";
  }

  Widget _winBadge(String n) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(6)),
        child: Text("WIN x$n", style: const TextStyle(color: Color(0xFFFFE08A), fontSize: 12, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic)),
      );

  Widget _count(int v) => TweenAnimationBuilder<double>(
        tween: Tween(end: v.toDouble()),
        duration: const Duration(milliseconds: 700),
        builder: (_, x, _) => Text(_fmt(x.round()), style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w900)),
      );

  Widget _video(List<Color> colors, String? result) => Expanded(
        child: Container(
          decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors)),
          child: Stack(children: [
            Center(child: Icon(Icons.person_rounded, size: 110, color: Colors.white.withValues(alpha: 0.22))),
            if (result != null)
              Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.3, end: 1),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.elasticOut,
                  builder: (_, v, child) => Transform.scale(scale: v, child: child),
                  child: Text(result,
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                        color: result == "WIN" ? acGold : Colors.white60,
                        shadows: const [Shadow(color: Colors.black, blurRadius: 10)],
                      )),
                ),
              ),
          ]),
        ),
      );

  Widget _pulse(Widget child) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.85, end: 1),
        duration: const Duration(milliseconds: 700),
        curve: Curves.elasticOut,
        builder: (_, v, c) => Transform.scale(scale: v, child: c),
        child: child,
      );

  // ----- tarja vermelha da missão (como no TikTok)
  Widget _banner() {
    final kind = _s(st, "banner");
    if (kind.isEmpty) return const SizedBox.shrink();
    final title = _s(st, "banner_title");
    final sub = _s(st, "banner_sub");
    const txt = TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w800);
    Widget secs() => _secs > 0
        ? Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 1, height: 16, margin: const EdgeInsets.symmetric(horizontal: 10), color: Colors.white54),
            Text("$_secs s", style: txt),
          ])
        : const SizedBox.shrink();
    Widget pill(List<Widget> children, {bool glow = false}) => _pulse(Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _red,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0x55FFFFFF)),
            boxShadow: glow ? [BoxShadow(color: _red.withValues(alpha: 0.7), blurRadius: 16)] : null,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: children),
        ));
    switch (kind) {
      case "first": // Primeiro presente x3 pontos de presente | 26 s
        return pill([
          Text(title.isEmpty ? "Primeiro presente " : "$title ", style: txt),
          Text(sub, style: txt.copyWith(color: const Color(0xFFFFE08A))),
          secs(),
        ], glow: true);
      case "progress": // 👥 0/1 ▸ | 58 s
        final icon = _s(st, "progress_icon", "🎁");
        return pill([
          if (icon == "👥") const Icon(Icons.people_alt_rounded, color: Colors.white, size: 18) else Text(icon, style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 6),
          Text(_s(st, "progress", "0/1"), style: txt),
          const SizedBox(width: 6),
          const Text("▸", style: TextStyle(color: Colors.white70, fontSize: 12)),
          if (sub.isNotEmpty) ...[const SizedBox(width: 6), Text(sub, style: txt.copyWith(fontSize: 11.5, color: const Color(0xFFFFE08A)))],
          secs(),
        ]);
      case "goal": // 👥 Meta de presenteador: 1
        return pill([
          const Icon(Icons.people_alt_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 6),
          Text(title.isEmpty ? "Meta de presenteador: " : "$title ", style: txt),
          Text(sub, style: txt.copyWith(color: const Color(0xFFFFE08A))),
        ]);
      case "unlocked": // x2 pontos de presentes iniciando em breve
        return pill([Text(title.isEmpty ? "$sub iniciando em breve" : title, style: txt)], glow: true);
      case "bonus": // x2 pontos de presentes | 45 s
        return pill([Text(title.isEmpty ? sub : title, style: txt), secs()], glow: true);
      default:
        return pill([
          IconText(title, style: txt),
          if (sub.isNotEmpty) ...[const SizedBox(width: 6), IconText(sub, style: txt.copyWith(color: const Color(0xFFFFE08A), fontSize: 12))],
          secs(),
        ]);
    }
  }
}

/// Corações vermelhos subindo no canto direito (curtidas da LIVE).
class _HeartsUp extends StatefulWidget {
  const _HeartsUp();

  @override
  State<_HeartsUp> createState() => _HeartsUpState();
}

class _HeartsUpState extends State<_HeartsUp> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) => Stack(children: [
            for (var k = 0; k < 3; k++)
              Builder(builder: (_) {
                final p = (_c.value + k / 3) % 1;
                return Align(
                  alignment: Alignment(0.4 * (k.isEven ? 1 : -1) * (1 - p), 1 - 2 * p),
                  child: Opacity(
                    opacity: (1 - p).clamp(0.0, 1.0),
                    child: Transform.scale(scale: 0.8 + 0.5 * p, child: const Icon(Icons.favorite, color: Color(0xFFFF4D5E), size: 30)),
                  ),
                );
              }),
          ]),
        ),
      );
}

/// Presente subindo até o placar + a conta (ex.: "1 × 3 = 3 pontos").
class _GiftFly extends StatefulWidget {
  final String gift;
  final String calc;
  final bool toGlove;
  const _GiftFly({super.key, required this.gift, required this.calc, required this.toGlove});

  @override
  State<_GiftFly> createState() => _GiftFlyState();
}

class _GiftFlyState extends State<_GiftFly> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) {
            final t = Curves.easeOutCubic.transform(_c.value.clamp(0, 0.6) / 0.6);
            final end = widget.toGlove ? const Alignment(-0.82, -0.62) : const Alignment(-0.5, -0.85);
            final pos = Alignment.lerp(const Alignment(-0.45, 0.6), end, t)!;
            final calcOn = _c.value > 0.55;
            return Stack(children: [
              if (widget.gift.isNotEmpty)
                Align(
                  alignment: pos,
                  child: Opacity(
                    opacity: _c.value < 0.85 ? 1 : (1 - (_c.value - 0.85) / 0.15).clamp(0.0, 1.0),
                    child: Transform.scale(scale: 0.7 + 0.6 * t, child: Text(widget.gift, style: const TextStyle(fontSize: 38))),
                  ),
                ),
              if (widget.calc.isNotEmpty && calcOn)
                Align(
                  alignment: const Alignment(0, 0.3),
                  child: Transform.scale(
                    scale: Curves.elasticOut.transform(((_c.value - 0.55) / 0.45).clamp(0, 1)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xE6000000),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: acGold, width: 1.5),
                        boxShadow: [BoxShadow(color: acGold.withValues(alpha: 0.5), blurRadius: 16)],
                      ),
                      child: Text(widget.calc, style: const TextStyle(color: acGold, fontSize: 18, fontWeight: FontWeight.w900)),
                    ),
                  ),
                ),
            ]);
          },
        ),
      );
}

/// Corações e "+3" subindo (Tap Tap do chat).
class _TapRain extends StatefulWidget {
  final int points;
  const _TapRain({super.key, required this.points});

  @override
  State<_TapRain> createState() => _TapRainState();
}

class _TapRainState extends State<_TapRain> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) => Stack(children: [
            for (var k = 0; k < 5; k++)
              Builder(builder: (_) {
                final p = (_c.value + k / 5) % 1;
                return Align(
                  alignment: Alignment(-0.85 + k * 0.17, 0.9 - 1.3 * p),
                  child: Opacity(
                    opacity: (1 - p).clamp(0.0, 1.0),
                    child: const Icon(Icons.favorite, color: Color(0xFFFF4D5E), size: 22),
                  ),
                );
              }),
          ]),
        ),
      );
}

// ---------------------------------------------------------------- multiplicador

class MultiplierBlock extends StatefulWidget {
  final Map block;
  final Color accent;
  const MultiplierBlock(this.block, {super.key, required this.accent});

  @override
  State<MultiplierBlock> createState() => _MultiplierBlockState();
}

class _MultiplierBlockState extends State<MultiplierBlock> {
  late int _m = _mults.first;

  List<int> get _mults => [for (final x in _s(widget.block, "multipliers", "1,2,3").split(",")) int.tryParse(x.trim()) ?? 1];

  @override
  Widget build(BuildContext context) {
    final b = widget.block;
    final gifts = _maps(b, "gifts");
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _blockHeader(b, widget.accent),
      Row(children: [
        for (final m in _mults)
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _m = m),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: m == _m ? acGold.withValues(alpha: 0.18) : acCard,
                  border: Border.all(color: m == _m ? acGold : Colors.white12, width: m == _m ? 1.8 : 1),
                ),
                child: Text(m == 1 ? "Sem missão" : "Missão x$m",
                    style: TextStyle(color: m == _m ? acGold : Colors.white70, fontSize: 13.5, fontWeight: FontWeight.w900)),
              ),
            ),
          ),
      ]),
      const SizedBox(height: 12),
      for (final g in gifts)
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: acCard, borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            SizedBox(width: 48, child: Center(child: chestOrEmoji(g, size: 40, fallback: "🎁"))),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_s(g, "name"), style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                Text("${_fmt(_int(g, "points", 1))} ${_int(g, "points", 1) == 1 ? "ponto" : "pontos"}", style: const TextStyle(color: Colors.white54, fontSize: 12.5)),
              ]),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
              child: Column(key: ValueKey(_m), crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text("${_fmt(_int(g, "points", 1))} × $_m", style: const TextStyle(color: Colors.white60, fontSize: 12.5, fontWeight: FontWeight.w700)),
                Text("= ${_fmt(_int(g, "points", 1) * _m)}", style: const TextStyle(color: acGold, fontSize: 20, fontWeight: FontWeight.w900)),
              ]),
            ),
          ]),
        ),
      if (_s(b, "note").isNotEmpty) IconText(_s(b, "note"), style: const TextStyle(color: Colors.white60, fontSize: 12.5, height: 1.4)),
    ]);
  }
}

// ---------------------------------------------------------------- tap tap

class TapTapBlock extends StatefulWidget {
  final Map block;
  final Color accent;
  const TapTapBlock(this.block, {super.key, required this.accent});

  @override
  State<TapTapBlock> createState() => _TapTapBlockState();
}

class _TapTapBlockState extends State<TapTapBlock> {
  int _taps = 0;
  final List<(int, Offset)> _pops = [];

  @override
  Widget build(BuildContext context) {
    final b = widget.block;
    final pts = _int(b, "points", 3);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _blockHeader(b, widget.accent),
      GestureDetector(
        onTapDown: (d) => setState(() {
          _taps++;
          _pops.add((_taps, d.localPosition));
          if (_pops.length > 8) _pops.removeAt(0);
        }),
        child: Container(
          height: 230,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF3A1550), Color(0xFF140A26)]),
            border: Border.all(color: const Color(0x55FF7EB3)),
          ),
          child: Stack(children: [
            Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_taps == 0 ? "👆" : "❤️", style: const TextStyle(fontSize: 44)),
                const SizedBox(height: 6),
                Text("${_taps == 0 ? 0 : pts} pontos na batalha", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(
                  _taps == 0 ? _s(b, "hint", "Toque várias vezes aqui!") : "❤️ $_taps curtidas · os pontos contam 1 vez por batalha",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white60, fontSize: 12.5),
                ),
              ]),
            ),
            for (final (id, p) in _pops)
              TweenAnimationBuilder<double>(
                key: ValueKey(id),
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 900),
                builder: (_, v, child) => Positioned(
                  left: p.dx - 16,
                  top: p.dy - 20 - 50 * v,
                  child: Opacity(opacity: 1 - v, child: child!),
                ),
                child: Text(id == 1 ? "+$pts" : "❤️", style: const TextStyle(color: Color(0xFFFF7EB3), fontSize: 18, fontWeight: FontWeight.w900)),
              ),
          ]),
        ),
      ),
      if (_s(b, "warning").isNotEmpty) ...[
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0x22FFB020), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0x88FFB020))),
          child: IconText(_s(b, "warning"), style: const TextStyle(color: Color(0xFFFFD27A), fontSize: 13.5, height: 1.4, fontWeight: FontWeight.w700)),
        ),
      ],
    ]);
  }
}
