import "dart:async";
import "dart:math" as math;

import "package:flutter/material.dart";

import "academy_theme.dart";

part "academy_live_tools.dart";

// Blocos interativos que recriam a interface do TikTok LIVE (sem prints e sem
// dados reais: nomes, @ e fotos sao ficticios e editaveis no painel).
//   tiktok_profile  Batalha → toque no perfil → perfil com pontos tocaveis
//   league_ladder   Classes da Liga (D5 … A1)
//   gift_gallery    Galeria de Presentes, com animacao "galeria iluminada"
//   feed            Sequencia animada (ex.: disputa pela Galeria)
//   recap           "Agora voce ja sabe"

String _s(Map b, String k, [String d = ""]) {
  final v = b[k];
  return v is String && v.trim().isNotEmpty ? v : d;
}

List<Map> _maps(Map b, String k) => [for (final x in (b[k] as List? ?? const [])) if (x is Map) x];
/// "asset:academy/gifts/x.png" = imagem que vem dentro do app; o resto, internet.
ImageProvider _imageOf(String url) => url.startsWith("asset:") ? AssetImage("assets/${url.substring(6)}") : academyImage(url);

bool _yes(dynamic v) => v == true || (v is String && ["sim", "s", "true", "1", "x"].contains(v.trim().toLowerCase()));

/// Ancora para rolar ate a Galeria quando tocam nela no perfil.
final Map<String, GlobalKey> academyAnchors = {};

Future<void> _scrollTo(BuildContext from, String anchor) async {
  // a lista so desenha o que esta perto da tela: desce ate a ancora existir
  final pos = Scrollable.maybeOf(from)?.position;
  for (var i = 0; i < 30; i++) {
    final ctx = academyAnchors[anchor]?.currentContext;
    if (ctx != null) {
      if (ctx.mounted) await Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 450), curve: Curves.easeInOutCubic, alignment: 0.04);
      return;
    }
    if (pos == null || pos.pixels >= pos.maxScrollExtent) return;
    await pos.animateTo(math.min(pos.pixels + pos.viewportDimension * 0.9, pos.maxScrollExtent), duration: const Duration(milliseconds: 160), curve: Curves.linear);
  }
}

// ---------------------------------------------------------------- comum

/// Explicacao que sobe de baixo quando tocam num elemento.
Future<void> showAcademyExplain(
  BuildContext context, {
  required String title,
  String? body,
  String? tip,
  Widget? extra,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
      decoration: const BoxDecoration(
        color: Color(0xFF17112F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        border: Border(top: BorderSide(color: Color(0x55C084FC))),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 18),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.92, end: 1),
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutBack,
            builder: (_, v, child) => Transform.scale(scale: v, alignment: Alignment.topCenter, child: child),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900, height: 1.2)),
              if (body != null && body.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(body, style: const TextStyle(color: Color(0xFFE6E0F5), fontSize: 15, height: 1.5)),
              ],
              if (extra != null) ...[const SizedBox(height: 14), extra],
              if (tip != null && tip.trim().isNotEmpty) ...[const SizedBox(height: 16), AcademyTipCard(tip)],
              const SizedBox(height: 18),
              if (actionLabel != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      onAction?.call();
                    },
                    style: FilledButton.styleFrom(backgroundColor: acPurple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: Text(actionLabel, style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              OutlinedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                child: const Text("Entendi · Continuar →", style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        ),
      ),
    ),
  );
}

class AcademyTipCard extends StatelessWidget {
  final String text;
  const AcademyTipCard(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(colors: [Color(0xFF6D28D9), Color(0xFF3B1786)]),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("🦆", style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text("💡 DICA MDUCK", style: TextStyle(color: acGold, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.3)),
              const SizedBox(height: 3),
              Text(text, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4, fontWeight: FontWeight.w700)),
            ]),
          ),
        ]),
      );
}

/// Foto de perfil ficticia: gradiente + iniciais (nunca rosto real).
class FakeAvatar extends StatelessWidget {
  final String name;
  final double size;
  final String? imageUrl;
  const FakeAvatar(this.name, {super.key, this.size = 36, this.imageUrl});

  static const _palettes = [
    [Color(0xFFFF7EB3), Color(0xFF7A2BE2)],
    [Color(0xFF34D399), Color(0xFF0E7490)],
    [Color(0xFFFFC94D), Color(0xFFE85D04)],
    [Color(0xFF60A5FA), Color(0xFF4338CA)],
    [Color(0xFFF472B6), Color(0xFFBE185D)],
    [Color(0xFFA78BFA), Color(0xFF5B21B6)],
  ];

  @override
  Widget build(BuildContext context) {
    final clean = name.replaceAll("@", "").trim();
    final parts = clean.split(RegExp(r"[\s._]+")).where((p) => p.isNotEmpty).toList();
    final initials = parts.isEmpty ? "?" : (parts.length == 1 ? parts.first[0] : "${parts[0][0]}${parts[1][0]}").toUpperCase();
    final pal = _palettes[clean.codeUnits.fold<int>(0, (a, b) => a + b) % _palettes.length];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: pal)),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: imageUrl != null && imageUrl!.isNotEmpty
          ? Image(image: academyImage(imageUrl!), width: size, height: size, fit: BoxFit.cover)
          : Text(initials, style: TextStyle(color: Colors.white, fontSize: size * 0.38, fontWeight: FontWeight.w900)),
    );
  }
}

/// Destaque pulsante em volta de um elemento tocavel ainda nao explorado.
class _Hot extends StatefulWidget {
  final bool active;
  final VoidCallback onTap;
  final Widget child;
  final double radius;
  const _Hot({required this.active, required this.onTap, required this.child, this.radius = 14});

  @override
  State<_Hot> createState() => _HotState();
}

class _HotState extends State<_Hot> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _c,
          child: widget.child,
          builder: (_, child) {
            final t = Curves.easeOut.transform(_c.value);
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.radius),
                border: Border.all(
                  color: widget.active ? const Color(0xFFB57BFF).withValues(alpha: 1 - t * 0.7) : Colors.transparent,
                  width: widget.active ? 2 : 0,
                ),
                boxShadow: widget.active ? [BoxShadow(color: const Color(0xFFB57BFF).withValues(alpha: 0.45 * (1 - t)), blurRadius: 4 + 14 * t, spreadRadius: 1 + 3 * t)] : null,
              ),
              child: child,
            );
          },
        ),
      );
}

class _TapHint extends StatefulWidget {
  final String text;
  const _TapHint(this.text);

  @override
  State<_TapHint> createState() => _TapHintState();
}

class _TapHintState extends State<_TapHint> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, child) => Transform.translate(offset: Offset(0, -3 * _c.value), child: child),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: const Color(0xFF7A2BE2), borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8)]),
          child: Text(widget.text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
        ),
      );
}

class _Progress extends StatelessWidget {
  final int done;
  final int total;
  const _Progress(this.done, this.total);

  @override
  Widget build(BuildContext context) {
    final all = done >= total;
    return Row(children: [
      Text(all ? "✨ Tudo explorado! Continue ↓" : "👆 Toque para entender", style: TextStyle(color: all ? const Color(0xFF7CF2B0) : acLilac, fontSize: 12.5, fontWeight: FontWeight.w800)),
      const Spacer(),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
        child: Text("$done/$total explorados", style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w700)),
      ),
    ]);
  }
}

// ---------------------------------------------------------------- perfil

const profileSpots = <String, String>{
  "perfil": "Nome e @",
  "livepro": "LIVE Pro",
  "bio": "Bio",
  "liga": "Liga",
  "comunidade": "Comunidade",
  "nivel": "Nível de presenteador",
  "galeria": "Galeria de Presentes",
};

class TikTokProfileBlock extends StatefulWidget {
  final Map block;
  const TikTokProfileBlock(this.block, {super.key});

  @override
  State<TikTokProfileBlock> createState() => _TikTokProfileBlockState();
}

class _TikTokProfileBlockState extends State<TikTokProfileBlock> {
  bool _open = false;
  final Set<String> _seen = {};

  Map get b => widget.block;
  Map _spot(String k) => (b["spots"] as Map?)?[k] as Map? ?? const {};

  void _explain(String k) {
    setState(() => _seen.add(k));
    final sp = _spot(k);
    showAcademyExplain(
      context,
      title: _s(sp, "title", profileSpots[k] ?? ""),
      body: _s(sp, "body"),
      tip: _s(sp, "tip"),
      actionLabel: k == "galeria" ? _s(sp, "action", "Abrir a Galeria 🎁") : null,
      onAction: k == "galeria" ? () => _scrollTo(context, "gift_gallery") : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (_s(b, "title").isNotEmpty)
        Text(_s(b, "title"), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, height: 1.2)),
      if (_s(b, "intro").isNotEmpty)
        Padding(padding: const EdgeInsets.only(top: 6), child: Text(_s(b, "intro"), style: const TextStyle(color: Color(0xFFE6E0F5), fontSize: 14.5, height: 1.45))),
      const SizedBox(height: 12),
      ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(color: Colors.black, border: Border.all(color: Colors.white12), borderRadius: BorderRadius.circular(24)),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _battle(compact: _open),
              if (_open)
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 1, end: 0),
                  duration: const Duration(milliseconds: 420),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, child) => Transform.translate(offset: Offset(0, 220 * v), child: child),
                  child: _profile(),
                ),
            ]),
          ),
        ),
      ),
      const SizedBox(height: 10),
      if (_open)
        _Progress(_seen.length, profileSpots.length)
      else
        Text(_s(b, "tap_hint_text", "Você está assistindo a uma Batalha. Toque no perfil do participante para abrir."),
            style: const TextStyle(color: Colors.white60, fontSize: 12.5)),
      if (_open)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() {
              _open = false;
              _seen.clear();
            }),
            icon: const Icon(Icons.replay, size: 15, color: Colors.white54),
            label: const Text("Ver de novo desde a Batalha", style: TextStyle(color: Colors.white54, fontSize: 12)),
          ),
        ),
    ]);
  }

  // Batalha (topo da LIVE + placar + dois videos)
  Widget _battle({required bool compact}) {
    final name = _s(b, "name", "Lucas Martins");
    final opp = _s(b, "opponent", "Rafa Souza");
    final topBar = Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
      child: Row(children: [
        _Hot(
          active: !_open,
          radius: 30,
          onTap: () => setState(() => _open = true),
          child: Container(
            padding: const EdgeInsets.fromLTRB(3, 3, 3, 3),
            decoration: BoxDecoration(color: const Color(0xFF1E2A5A), borderRadius: BorderRadius.circular(30)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              FakeAvatar(name, size: 34, imageUrl: _s(b, "avatar_url")),
              const SizedBox(width: 6),
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(name.length > 11 ? "${name.substring(0, 10)}…" : name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
                const Text("✦ LIVE Pro", style: TextStyle(color: Colors.white70, fontSize: 10.5)),
              ]),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFFFE2C55), borderRadius: BorderRadius.circular(16)),
                child: const Text("+ Seguir", style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800)),
              ),
            ]),
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(14)),
          child: Text(_s(b, "viewers", "3.5K"), style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 6),
        const Icon(Icons.close, color: Colors.white, size: 20),
      ]),
    );
    final scores = Row(children: [
      Expanded(
        flex: 47,
        child: Container(
          height: 22,
          padding: const EdgeInsets.only(left: 8),
          alignment: Alignment.centerLeft,
          decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFFF2D7A), Color(0xFFFF7EB3)])),
          child: Text(_s(b, "score_left", "4.542"), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
        ),
      ),
      Expanded(
        flex: 53,
        child: Container(
          height: 22,
          padding: const EdgeInsets.only(right: 8),
          alignment: Alignment.centerRight,
          decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF5CE1E6), Color(0xFF1FB6FF)])),
          child: Text(_s(b, "score_right", "5.027"), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
        ),
      ),
    ]);
    Widget video(String who, List<Color> colors, {bool right = false}) => Expanded(
          child: Container(
            decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors)),
            child: Stack(children: [
              Center(child: Icon(Icons.person_rounded, size: compact ? 54 : 110, color: Colors.white.withValues(alpha: 0.25))),
              Positioned(
                left: right ? null : 6,
                right: right ? 6 : null,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xAA5A3A10), borderRadius: BorderRadius.circular(6)),
                  child: Text("💎 ${_s(b, "league", "A1")}", style: const TextStyle(color: acGold, fontSize: 10.5, fontWeight: FontWeight.w800)),
                ),
              ),
              if (!compact)
                Positioned(left: 8, bottom: 8, child: Text(who, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700))),
            ]),
          ),
        );
    return Column(mainAxisSize: MainAxisSize.min, children: [
      topBar,
      if (!compact)
        const Padding(
          padding: EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Row(children: [
            _Chip("🔥 Nº 11 diário"),
            Spacer(),
            _Chip("Batalha ⚔️"),
          ]),
        ),
      if (!_open)
        const Padding(padding: EdgeInsets.only(bottom: 8), child: Align(alignment: Alignment(-0.75, 0), child: _TapHint("👆 Toque no perfil"))),
      scores,
      SizedBox(
        height: compact ? 92 : 300,
        child: Stack(children: [
          Row(children: [
            video(name, const [Color(0xFF4B3B2A), Color(0xFF1C1612)]),
            Container(width: 2, color: Colors.black),
            video(opp, const [Color(0xFF233A6B), Color(0xFF0E1630)], right: true),
          ]),
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: const BoxDecoration(color: Color(0xCC111111), borderRadius: BorderRadius.vertical(bottom: Radius.circular(10))),
              child: Text("⚔️ ${_s(b, "timer", "04:28")}", style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
      ),
    ]);
  }

  // Perfil aberto (folha clara, como no TikTok)
  Widget _profile() {
    final name = _s(b, "name", "Lucas Martins");
    final league = _s(b, "league", "A1");
    Widget hot(String k, Widget child, {double r = 14}) => _Hot(active: !_seen.contains(k), radius: r, onTap: () => _explain(k), child: child);
    const ink = Color(0xFF161823);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFE9E6FF), Colors.white], stops: [0, 0.35]),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(clipBehavior: Clip.none, children: [
            Container(
              padding: const EdgeInsets.all(2.5),
              decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFF9DB4FF), Color(0xFF5B6CFF)])),
              child: FakeAvatar(name, size: 64, imageUrl: _s(b, "avatar_url")),
            ),
            Positioned(
              bottom: -6,
              left: 22,
              child: Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF3B5BDB), border: Border.all(color: Colors.white, width: 2)),
                child: const Text("2", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
              ),
            ),
          ]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              hot(
                "perfil",
                Padding(
                  padding: const EdgeInsets.all(3),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Flexible(child: Text(name, overflow: TextOverflow.ellipsis, style: const TextStyle(color: ink, fontSize: 19, fontWeight: FontWeight.w900))),
                      const SizedBox(width: 4),
                      const Icon(Icons.verified, color: Color(0xFF20D5EC), size: 17),
                    ]),
                    Text(_s(b, "handle", "lucasmartins.live"), style: const TextStyle(color: Color(0xFF6B6F80), fontSize: 13)),
                  ]),
                ),
                r: 10,
              ),
              const SizedBox(height: 4),
              hot(
                "livepro",
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFFFFE4EA), borderRadius: BorderRadius.circular(6)),
                  child: const Text("✦ LIVE Pro ›", style: TextStyle(color: Color(0xFFFE2C55), fontSize: 12, fontWeight: FontWeight.w800)),
                ),
                r: 8,
              ),
            ]),
          ),
          const Icon(Icons.outlined_flag, color: Color(0xFF9A9CA8), size: 20),
        ]),
        const SizedBox(height: 12),
        Text("${_s(b, "followers", "128 mil")} seguidores · ${_s(b, "following", "312")} seguindo",
            style: const TextStyle(color: ink, fontSize: 13.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        hot(
          "bio",
          Padding(
            padding: const EdgeInsets.all(4),
            child: Text(_s(b, "bio", "🎤 Live streamer | Música & Batalhas\n🎙️ Lives de segunda a sábado\n🦆 MDuck Agency"),
                style: const TextStyle(color: Color(0xFF7A7D8C), fontSize: 13, height: 1.35)),
          ),
          r: 10,
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            flex: 31,
            child: hot(
              "liga",
              _profileCard(
                const Color(0xFFFFF7E0),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: const Color(0xFFFFC23D), borderRadius: BorderRadius.circular(5)),
                    child: Text(league.isEmpty ? "A" : league[0], style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(text: league, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900)),
                        TextSpan(text: " ${_s(b, "league_rank", "Nº 7")}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                      ]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFFB7791F)),
                    ),
                  ),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 40,
            child: hot(
              "comunidade",
              _profileCard(
                const Color(0xFFFFE9EC),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Flexible(child: Text("Comunidade", overflow: TextOverflow.ellipsis, style: TextStyle(color: Color(0xFFF0506E), fontSize: 11.5, fontWeight: FontWeight.w900))),
                  const SizedBox(width: 4),
                  const Icon(Icons.person, size: 12, color: Color(0xFFF0506E)),
                  Text(_s(b, "community", "1.240"), style: const TextStyle(color: Color(0xFFF0506E), fontSize: 11, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 29,
            child: hot(
              "nivel",
              _profileCard(
                const Color(0xFFEFE9FF),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text("🔷", style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 3),
                  Flexible(child: Text("Nível ${_s(b, "gifter_level", "45")}", overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF8B5CF6), fontSize: 12, fontWeight: FontWeight.w900))),
                ]),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        hot(
          "galeria",
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(color: const Color(0xFFFFF8E7), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFF5E2B0))),
            child: Row(children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), gradient: const LinearGradient(colors: [Color(0xFFFFE08A), Color(0xFFC98B2B)])),
                child: const Text("💎", style: TextStyle(fontSize: 17)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text("Galeria de Presentes de $league", style: const TextStyle(color: Color(0xFFC9932B), fontSize: 13.5, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: const LinearProgressIndicator(value: 0.75, minHeight: 3.5, backgroundColor: Color(0xFFF1E4C3), color: Color(0xFFC9932B)),
                  ),
                ]),
              ),
              const SizedBox(width: 8),
              const Text("🌌🦁", style: TextStyle(fontSize: 17)),
              const Icon(Icons.chevron_right, color: Color(0xFF9A9CA8)),
            ]),
          ),
          r: 12,
        ),
        const SizedBox(height: 12),
        Container(
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: const Color(0xFFFE2C55), borderRadius: BorderRadius.circular(22)),
          child: const Text("+ Seguir", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }

  Widget _profileCard(Color bg, Widget child) => Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: child,
      );
}

class _Chip extends StatelessWidget {
  final String text;
  const _Chip(this.text);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(14)),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
      );
}

// ---------------------------------------------------------------- liga

class LeagueLadderBlock extends StatefulWidget {
  final Map block;
  final Color accent;
  const LeagueLadderBlock(this.block, {super.key, required this.accent});

  @override
  State<LeagueLadderBlock> createState() => _LeagueLadderBlockState();
}

class _LeagueLadderBlockState extends State<LeagueLadderBlock> {
  int? _open;

  static const _colors = {
    "D": [Color(0xFF64748B), Color(0xFF334155)],
    "C": [Color(0xFF10B981), Color(0xFF065F46)],
    "B": [Color(0xFF6366F1), Color(0xFF3730A3)],
    "A": [Color(0xFFFFC94D), Color(0xFFB7791F)],
  };

  @override
  Widget build(BuildContext context) {
    final b = widget.block;
    final groups = _maps(b, "groups");
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text("🏆 ${_s(b, "label", "A Liga")}".toUpperCase(), style: TextStyle(color: widget.accent, fontSize: 11.5, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
      if (_s(b, "title").isNotEmpty)
        Padding(padding: const EdgeInsets.only(top: 3), child: Text(_s(b, "title"), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900))),
      if (_s(b, "intro").isNotEmpty)
        Padding(padding: const EdgeInsets.only(top: 6), child: Text(_s(b, "intro"), style: const TextStyle(color: Color(0xFFE6E0F5), fontSize: 14.5, height: 1.45))),
      const SizedBox(height: 12),
      for (var i = 0; i < groups.length; i++) ...[
        _group(i, groups[i]),
        if (i < groups.length - 1) const Center(child: Icon(Icons.keyboard_double_arrow_down_rounded, color: Colors.white30, size: 20)),
      ],
      if (_s(b, "note").isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text("ℹ️ ${_s(b, "note")}", style: const TextStyle(color: Colors.white54, fontSize: 12, fontStyle: FontStyle.italic)),
        ),
    ]);
  }

  Widget _group(int i, Map g) {
    final letter = _s(g, "letter", "?").toUpperCase();
    final pal = _colors[letter] ?? _colors["D"]!;
    final tiers = _s(g, "tiers").split(RegExp(r"[,\s]+")).where((t) => t.isNotEmpty).toList();
    final open = _open == i;
    return GestureDetector(
      onTap: () => setState(() => _open = open ? null : i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: open ? pal[0].withValues(alpha: 0.16) : acCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: open ? pal[0] : Colors.white12, width: open ? 1.6 : 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(9), gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: pal)),
              child: Text(letter, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Wrap(spacing: 5, runSpacing: 5, children: [
                for (final t in tiers) _tier(t, pal),
              ]),
            ),
            Icon(open ? Icons.remove_circle_outline : Icons.add_circle_outline, color: pal[0], size: 18),
          ]),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            child: open && _s(g, "body").isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.only(top: 8, left: 44),
                    child: Text(_s(g, "body"), style: const TextStyle(color: Color(0xFFE6E0F5), fontSize: 14, height: 1.4)),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ]),
      ),
    );
  }

  Widget _tier(String t, List<Color> pal) {
    final top = t.toUpperCase() == _s(widget.block, "top", "A1").toUpperCase();
    final chip = Container(
      padding: EdgeInsets.symmetric(horizontal: top ? 10 : 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: top ? null : Colors.white.withValues(alpha: 0.07),
        gradient: top ? const LinearGradient(colors: [Color(0xFFFFE08A), Color(0xFFE0A526)]) : null,
        boxShadow: top ? [BoxShadow(color: acGold.withValues(alpha: 0.6), blurRadius: 12)] : null,
      ),
      child: Text(top ? "🏆 $t" : t, style: TextStyle(color: top ? const Color(0xFF3A2400) : Colors.white, fontSize: 12.5, fontWeight: FontWeight.w900)),
    );
    if (!top) return chip;
    return GestureDetector(
      onTap: () => showAcademyExplain(
        context,
        title: _s(widget.block, "top_title", "🏆 $t"),
        body: _s(widget.block, "top_body"),
        tip: _s(widget.block, "top_tip"),
      ),
      child: chip,
    );
  }
}

// ---------------------------------------------------------------- galeria

class GiftGalleryBlock extends StatefulWidget {
  final Map block;
  final Color accent;
  const GiftGalleryBlock(this.block, {super.key, required this.accent});

  @override
  State<GiftGalleryBlock> createState() => _GiftGalleryBlockState();
}

class _GiftGalleryBlockState extends State<GiftGalleryBlock> {
  final _anchor = GlobalKey();
  final Set<int> _litByDemo = {};
  int? _demo;
  int _phase = 0; // 0 apagado · 1 iluminando · 2 quem enviou
  bool _demoDone = false;
  final List<Timer> _timers = [];

  Map get b => widget.block;
  List<Map> get gifts => _maps(b, "gifts");

  @override
  void initState() {
    super.initState();
    academyAnchors["gift_gallery"] = _anchor;
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    if (academyAnchors["gift_gallery"] == _anchor) academyAnchors.remove("gift_gallery");
    super.dispose();
  }

  bool _lit(int i) => _yes(gifts[i]["lit"]) || _litByDemo.contains(i);

  void _playDemo() {
    var i = gifts.indexWhere((g) => !_yes(g["lit"]));
    if (i < 0) i = gifts.length - 1;
    if (i < 0) return;
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
    setState(() {
      _litByDemo.remove(i);
      _demo = i;
      _phase = 0;
      _demoDone = false;
    });
    _timers.add(Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _phase = 1);
    }));
    _timers.add(Timer(const Duration(milliseconds: 2000), () {
      if (mounted) {
        setState(() {
          _phase = 2;
          _litByDemo.add(i);
        });
      }
    }));
    _timers.add(Timer(const Duration(milliseconds: 3000), () {
      if (mounted) setState(() => _demoDone = true);
    }));
  }

  String _demoUser(int i) => _s(gifts[i], "user", _s(b, "demo_user", "@gabriel_live"));

  void _openGift(int i) {
    final g = gifts[i];
    final lit = _lit(i);
    final user = i == _demo ? _demoUser(i) : _s(g, "user");
    showAcademyExplain(
      context,
      title: "🎁 ${_s(g, "name", "Presente")}",
      body: _s(g, "body", _s(b, "gift_body")),
      tip: lit ? _s(b, "sender_tip") : null,
      extra: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(child: _GiftArt(g, lit: true, size: 84)),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(14)),
          child: lit && user.isNotEmpty
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_s(b, "sender_title", "👤 Quem participou").toUpperCase(),
                      style: TextStyle(color: widget.accent, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                  const SizedBox(height: 8),
                  // principal (quem mais enviou) + ate 2 outros
                  for (final (k, u) in [user, ..._s(g, "others").split(",").map((x) => x.trim()).where((x) => x.isNotEmpty)].take(3).indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: k == 0 ? acGold.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.04),
                          border: Border.all(color: k == 0 ? acGold.withValues(alpha: 0.55) : Colors.white12),
                        ),
                        child: Row(children: [
                          FakeAvatar(u, size: k == 0 ? 32 : 26),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(u.startsWith("@") ? u : "@$u",
                                style: TextStyle(color: Colors.white, fontWeight: k == 0 ? FontWeight.w900 : FontWeight.w600, fontSize: k == 0 ? 14.5 : 13.5)),
                          ),
                          if (k == 0)
                            Text(_s(b, "top_label", "👑 Principal"), style: const TextStyle(color: acGold, fontSize: 12, fontWeight: FontWeight.w900)),
                        ]),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(_s(b, "sender_body", "Este usuário participou enviando este Presente."),
                      style: const TextStyle(color: Color(0xFFE6E0F5), fontSize: 13.5, height: 1.4)),
                ])
              : Text(_s(b, "unlit_body", "Este Presente ainda não foi registrado neste ciclo da Galeria."),
                  style: const TextStyle(color: Colors.white60, fontSize: 13.5, height: 1.4)),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final litCount = [for (var i = 0; i < gifts.length; i++) i].where(_lit).length;
    final total = int.tryParse(_s(b, "total")) ?? gifts.length;
    final owner = _s(b, "owner", "Lucas Martins");
    final league = _s(b, "league", "A1");
    return Column(key: _anchor, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text("🎁 ${_s(b, "label", "Galeria de Presentes")}".toUpperCase(),
          style: TextStyle(color: widget.accent, fontSize: 11.5, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
      if (_s(b, "title").isNotEmpty)
        Padding(padding: const EdgeInsets.only(top: 3), child: Text(_s(b, "title"), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900))),
      if (_s(b, "intro").isNotEmpty)
        Padding(padding: const EdgeInsets.only(top: 6), child: Text(_s(b, "intro"), style: const TextStyle(color: Color(0xFFE6E0F5), fontSize: 14.5, height: 1.45))),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0x33FFD27A)),
          gradient: const RadialGradient(center: Alignment(0.6, -1), radius: 1.3, colors: [Color(0xFF3A2E1E), Color(0xFF14110E), Color(0xFF0B0A09)], stops: [0, 0.45, 1]),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("Galeria de Presentes de $owner", maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFFF3DFB2), fontSize: 17, fontWeight: FontWeight.w900, height: 1.2)),
                const SizedBox(height: 8),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFFFD27A), borderRadius: BorderRadius.circular(6)),
                    child: Text("💎 $league ›", style: const TextStyle(color: Color(0xFF6B3E00), fontSize: 12, fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(width: 8),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                    child: Container(
                      key: ValueKey(litCount),
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(border: Border.all(color: Colors.white30), borderRadius: BorderRadius.circular(6)),
                      child: Text("$litCount/$total", style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ]),
              ]),
            ),
            const _GlowCube(),
          ]),
          const SizedBox(height: 14),
          LayoutBuilder(builder: (context, box) {
            final w = (box.maxWidth - 16) / 3;
            return Wrap(spacing: 8, runSpacing: 8, children: [
              for (var i = 0; i < gifts.length; i++) SizedBox(width: w, child: _card(i)),
            ]);
          }),
        ]),
      ),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
          child: Text(_s(b, "hint", "👆 Toque em um Presente para entender."), style: const TextStyle(color: acLilac, fontSize: 12.5, fontWeight: FontWeight.w700)),
        ),
      ]),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: _playDemo,
        style: OutlinedButton.styleFrom(
          foregroundColor: acGold,
          side: BorderSide(color: acGold.withValues(alpha: 0.6)),
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: const Icon(Icons.auto_awesome, size: 18),
        label: Text(_demo == null ? _s(b, "demo_button", "Ver a Galeria sendo iluminada") : "Ver de novo", style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      AnimatedSize(
        duration: const Duration(milliseconds: 300),
        child: _demoDone
            ? Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: acGold.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: acGold.withValues(alpha: 0.4)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_s(b, "lit_title", "✨ Galeria iluminada"), style: const TextStyle(color: acGold, fontSize: 15, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(_s(b, "lit_body"), style: const TextStyle(color: Color(0xFFE6E0F5), fontSize: 14, height: 1.45)),
                  ]),
                ),
              )
            : const SizedBox(width: double.infinity),
      ),
    ]);
  }

  Widget _card(int i) {
    final g = gifts[i];
    final demo = i == _demo;
    final lit = _lit(i) || (demo && _phase >= 1);
    final user = demo ? (_phase >= 2 ? _demoUser(i) : "") : (lit ? _s(g, "user") : "");
    return GestureDetector(
      onTap: () => _openGift(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: demo && _phase == 1 ? acGold : const Color(0x33FFFFFF)),
          gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF2A2621), Color(0xFF15130F)]),
          boxShadow: demo && _phase == 1 ? [BoxShadow(color: acGold.withValues(alpha: 0.55), blurRadius: 18)] : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          const SizedBox(height: 10),
          AnimatedScale(
            scale: demo && _phase == 1 ? 1.18 : 1,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutBack,
            child: _GiftArt(g, lit: lit, size: 60),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
            child: Text(_s(g, "name", "Presente"), maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: lit ? Colors.white : Colors.white38, fontSize: 11.5, fontWeight: FontWeight.w800)),
          ),
          Container(
            height: 26,
            color: Colors.black.withValues(alpha: 0.35),
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 450),
              transitionBuilder: (c, a) => FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: const Offset(0, 0.6), end: Offset.zero).animate(a), child: c)),
              child: user.isEmpty
                  ? const Center(key: ValueKey("vazio"), child: Text("—", style: TextStyle(color: Colors.white24, fontSize: 11)))
                  : Row(key: ValueKey(user), children: [
                      FakeAvatar(user, size: 16),
                      const SizedBox(width: 4),
                      Expanded(child: Text(user.replaceAll("@", ""), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 10.5))),
                    ]),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Arte do Presente: imagem enviada no painel ou emoji com brilho.
class _GiftArt extends StatelessWidget {
  final Map gift;
  final bool lit;
  final double size;
  const _GiftArt(this.gift, {required this.lit, required this.size});

  @override
  Widget build(BuildContext context) {
    final url = _s(gift, "image_url");
    final art = url.isNotEmpty
        ? Image(
            image: _imageOf(url),
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => Text(_s(gift, "emoji", "🎁"), style: TextStyle(fontSize: size * 0.72)),
          )
        : Text(_s(gift, "emoji", "🎁"), style: TextStyle(fontSize: size * 0.72));
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      width: size + 14,
      height: size + 10,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: lit ? RadialGradient(colors: [const Color(0xFFFFD27A).withValues(alpha: 0.35), Colors.transparent]) : null,
      ),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 600),
        opacity: lit ? 1 : 0.32,
        child: lit
            ? art
            : ColorFiltered(
                colorFilter: const ColorFilter.matrix([0.33, 0.33, 0.33, 0, 0, 0.33, 0.33, 0.33, 0, 0, 0.33, 0.33, 0.33, 0, 0, 0, 0, 0, 1, 0]),
                child: art,
              ),
      ),
    );
  }
}

class _GlowCube extends StatefulWidget {
  const _GlowCube();

  @override
  State<_GlowCube> createState() => _GlowCubeState();
}

class _GlowCubeState extends State<_GlowCube> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, _) => Container(
          width: 58,
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFF1CC), Color(0xFFC48A2C), Color(0xFF6B4410)]),
            boxShadow: [BoxShadow(color: acGold.withValues(alpha: 0.25 + 0.3 * _c.value), blurRadius: 10 + 12 * _c.value)],
          ),
          child: Transform.rotate(angle: math.pi / 4, child: Container(width: 20, height: 20, color: Colors.white.withValues(alpha: 0.85))),
        ),
      );
}

// ---------------------------------------------------------------- feed

class FeedBlock extends StatefulWidget {
  final Map block;
  final Color accent;
  const FeedBlock(this.block, {super.key, required this.accent});

  @override
  State<FeedBlock> createState() => _FeedBlockState();
}

class _FeedBlockState extends State<FeedBlock> {
  int _shown = 0;
  Timer? _t;

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  void _play() {
    _t?.cancel();
    final n = _maps(widget.block, "items").length;
    setState(() => _shown = 0);
    _t = Timer.periodic(const Duration(milliseconds: 900), (t) {
      if (!mounted || _shown >= n) {
        t.cancel();
        return;
      }
      setState(() => _shown++);
    });
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.block;
    final items = _maps(b, "items");
    final done = _shown >= items.length && items.isNotEmpty;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (_s(b, "label").isNotEmpty)
        Text(_s(b, "label").toUpperCase(), style: TextStyle(color: widget.accent, fontSize: 11.5, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
      if (_s(b, "title").isNotEmpty)
        Padding(padding: const EdgeInsets.only(top: 3), child: Text(_s(b, "title"), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900))),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(minHeight: 120),
        decoration: BoxDecoration(color: const Color(0xFF0E0B1A), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var i = 0; i < items.length && i < _shown; i++)
            TweenAnimationBuilder<double>(
              key: ValueKey("f$i"),
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeOutCubic,
              builder: (_, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(-24 * (1 - v), 0), child: child)),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  FakeAvatar(_s(items[i], "user", "?"), size: 28),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
                      child: Text.rich(TextSpan(children: [
                        TextSpan(text: "${_s(items[i], "user")} ", style: const TextStyle(color: acGold, fontWeight: FontWeight.w900)),
                        TextSpan(text: _s(items[i], "text"), style: const TextStyle(color: Colors.white)),
                      ]), style: const TextStyle(fontSize: 13.5)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (_s(items[i], "image_url").isNotEmpty)
                    Image(
                      image: _imageOf(_s(items[i], "image_url")),
                      width: 34,
                      height: 34,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => Text(_s(items[i], "emoji", "🎁"), style: const TextStyle(fontSize: 18)),
                    )
                  else
                    Text(_s(items[i], "emoji", "🎁"), style: const TextStyle(fontSize: 18)),
                ]),
              ),
            ),
          if (_shown == 0)
            Center(
              child: FilledButton.icon(
                onPressed: _play,
                style: FilledButton.styleFrom(backgroundColor: acPurple, foregroundColor: Colors.white),
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(_s(b, "button", "Ver a disputa"), style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
        ]),
      ),
      AnimatedSize(
        duration: const Duration(milliseconds: 300),
        child: done
            ? Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (_s(b, "body").isNotEmpty) Text(_s(b, "body"), style: const TextStyle(color: Color(0xFFE6E0F5), fontSize: 14.5, height: 1.45)),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _play,
                      icon: const Icon(Icons.replay, size: 15, color: Colors.white54),
                      label: const Text("Ver de novo", style: TextStyle(color: Colors.white54, fontSize: 12)),
                    ),
                  ),
                ]),
              )
            : const SizedBox(width: double.infinity),
      ),
    ]);
  }
}

// ---------------------------------------------------------------- resumo

class RecapBlock extends StatelessWidget {
  final Map block;
  const RecapBlock(this.block, {super.key});

  @override
  Widget build(BuildContext context) {
    final items = [for (final x in (block["items"] as List? ?? const [])) if (x != null && "$x".trim().isNotEmpty) "$x"];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1F5F4A), Color(0xFF15233A)]),
        border: Border.all(color: const Color(0xFF3DDC97).withValues(alpha: 0.5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_s(block, "title", "🎉 Agora você já sabe:"), style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        for (var i = 0; i < items.length; i++)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 300 + 90 * i),
            curve: Curves.easeOut,
            builder: (_, v, child) => Opacity(opacity: v, child: child),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.check_circle, color: Color(0xFF3DDC97), size: 19),
                const SizedBox(width: 9),
                Expanded(child: Text(items[i], style: const TextStyle(color: Colors.white, fontSize: 14.5, height: 1.35))),
              ]),
            ),
          ),
      ]),
    );
  }
}
