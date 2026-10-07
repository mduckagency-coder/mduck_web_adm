import "dart:math" as math;

import "package:flutter/material.dart";

/// Arte de uma conquista: insignia ilustrada em codigo, todas no mesmo estilo
/// (ilha tropical, oceano, diamantes, iluminacao de por do sol/noite).
/// Cada familia tem sua narrativa visual e o "tier" (1, 2, 3...) aumenta a
/// grandiosidade da cena. Se o painel enviar uma imagem propria
/// ([imageUrl]), ela substitui a arte desenhada.
///
/// art_key: "familia_tier" -- marco_1..8, mensal_1..7, consistencia_1..3,
/// horas_1..4, dias_1..3.
///
/// Este arquivo e copiado igual no painel web (mduck_web_adm), pra previa.
class AchievementArt extends StatelessWidget {
  final String? artKey;
  final String? imageUrl;
  final bool locked;
  final double radius;

  const AchievementArt({super.key, this.artKey, this.imageUrl, this.locked = false, this.radius = 22});

  static const _grayscale = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final parts = (artKey ?? "marco_1").split("_");
    final family = parts.first;
    final tier = int.tryParse(parts.length > 1 ? parts.last : "1") ?? 1;

    Widget art = CustomPaint(painter: _AchievementPainter(family, tier), child: const SizedBox.expand());
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      art = Image.network(imageUrl!, fit: BoxFit.cover, width: double.infinity, height: double.infinity, errorBuilder: (_, _, _) => art);
    }

    Widget framed = ClipRRect(borderRadius: BorderRadius.circular(radius), child: art);
    if (locked) {
      framed = ColorFiltered(
        colorFilter: _grayscale,
        child: Opacity(opacity: 0.55, child: framed),
      );
    }
    return AspectRatio(aspectRatio: 1, child: framed);
  }
}

class _Palette {
  final List<Color> sky;
  final Color sun;
  final Color sea;
  final Color seaDeep;
  final bool night;
  const _Palette(this.sky, this.sun, this.sea, this.seaDeep, {this.night = false});
}

/// Hora do dia de cada tier (amanhecer -> dia -> por do sol -> noite -> aurora).
_Palette _paletteFor(String family, int tier) {
  const dawn = _Palette([Color(0xFFFFC2A8), Color(0xFFFFE6C7), Color(0xFFFFF4E0)], Color(0xFFFFE08A), Color(0xFF4FB6D8), Color(0xFF1D6E99));
  const day = _Palette([Color(0xFF5BC8F5), Color(0xFF9EE3FF), Color(0xFFDDF6FF)], Color(0xFFFFF3B0), Color(0xFF22A7D6), Color(0xFF0C5E8E));
  const sunset = _Palette([Color(0xFF5B2A86), Color(0xFFE0567A), Color(0xFFFFB061)], Color(0xFFFFD36B), Color(0xFF6E3C8E), Color(0xFF2B1A4F));
  const night = _Palette([Color(0xFF0B0F2E), Color(0xFF1C2A66), Color(0xFF3A3F8F)], Color(0xFFF4F1D0), Color(0xFF1B2D6B), Color(0xFF070B24), night: true);
  const aurora = _Palette([Color(0xFF07122B), Color(0xFF123A4F), Color(0xFF1F6B6B)], Color(0xFFE8FFF6), Color(0xFF103A55), Color(0xFF04101F), night: true);
  switch (family) {
    case "horas":
      return tier >= 3 ? aurora : night;
    case "dias":
      return [dawn, day, sunset][(tier - 1).clamp(0, 2)];
    case "consistencia":
      return [sunset, night, aurora][(tier - 1).clamp(0, 2)];
    case "mensal":
      return [day, day, sunset, sunset, night, night, aurora][(tier - 1).clamp(0, 6)];
    default: // marco
      return [dawn, dawn, day, day, sunset, sunset, night, aurora][(tier - 1).clamp(0, 7)];
  }
}

class _AchievementPainter extends CustomPainter {
  final String family;
  final int tier;
  _AchievementPainter(this.family, this.tier);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final p = _paletteFor(family, tier);
    final rect = Offset.zero & size;
    final horizon = s * 0.54;

    // ceu
    canvas.drawRect(
      rect,
      Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: p.sky).createShader(Rect.fromLTWH(0, 0, s, horizon)),
    );
    if (p.night) _stars(canvas, s, horizon, 18 + tier * 6);
    if (p.night && (family == "horas" || family == "marco" || family == "mensal" || family == "consistencia") && tier >= 3) _aurora(canvas, s);

    // sol / lua
    final sunCenter = Offset(s * (family == "mensal" ? 0.5 : 0.72), horizon - s * (family == "mensal" ? 0.20 : 0.16));
    final sunR = s * (family == "mensal" ? 0.17 : 0.10);
    canvas.drawCircle(
      sunCenter,
      sunR * 2.6,
      Paint()..shader = RadialGradient(colors: [p.sun.withValues(alpha: 0.55), p.sun.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: sunCenter, radius: sunR * 2.6)),
    );
    canvas.drawCircle(sunCenter, sunR, Paint()..color = p.sun);

    // mar
    final seaRect = Rect.fromLTWH(0, horizon, s, s - horizon);
    canvas.drawRect(seaRect, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [p.sea, p.seaDeep]).createShader(seaRect));
    // reflexo do sol
    final glint = Paint()..color = p.sun.withValues(alpha: 0.35);
    for (var i = 0; i < 5; i++) {
      final y = horizon + s * 0.03 + i * s * 0.035;
      final w = s * (0.16 - i * 0.022);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(sunCenter.dx, y), width: w, height: s * 0.008), Radius.circular(s)), glint);
    }

    switch (family) {
      case "mensal":
        _floatingGem(canvas, s, horizon);
      case "consistencia":
        _stonePath(canvas, s, horizon);
      case "horas":
        _hourglass(canvas, s, horizon);
      case "dias":
        _days(canvas, s, horizon);
      default:
        _islandWithDiamonds(canvas, s, horizon);
    }

    // vinheta + aro dourado sutil
    canvas.drawRect(
      rect,
      Paint()..shader = RadialGradient(radius: 0.85, colors: [Colors.transparent, Colors.black.withValues(alpha: 0.35)], stops: const [0.65, 1]).createShader(rect),
    );
  }

  // ---------------------------------------------------------------- elementos

  void _stars(Canvas canvas, double s, double horizon, int count) {
    final rnd = math.Random(family.hashCode ^ tier);
    final star = Paint()..color = Colors.white;
    for (var i = 0; i < count; i++) {
      final o = Offset(rnd.nextDouble() * s, rnd.nextDouble() * horizon * 0.85);
      star.color = Colors.white.withValues(alpha: 0.35 + rnd.nextDouble() * 0.6);
      canvas.drawCircle(o, s * (0.003 + rnd.nextDouble() * 0.006), star);
    }
  }

  void _aurora(Canvas canvas, double s) {
    for (var band = 0; band < 2; band++) {
      final path = Path()..moveTo(0, s * (0.18 + band * 0.08));
      for (var x = 0.0; x <= s; x += s / 12) {
        path.lineTo(x, s * (0.18 + band * 0.08) + math.sin(x / s * math.pi * 2 + band) * s * 0.04);
      }
      path
        ..lineTo(s, s * (0.34 + band * 0.08))
        ..lineTo(0, s * (0.34 + band * 0.08))
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              (band == 0 ? const Color(0xFF6CFFC6) : const Color(0xFFB98CFF)).withValues(alpha: 0.35),
              Colors.transparent,
            ],
          ).createShader(Rect.fromLTWH(0, 0, s, s * 0.5)),
      );
    }
  }

  void _gem(Canvas canvas, Offset c, double w, {Color tint = const Color(0xFF7FE7FF)}) {
    final h = w * 0.9;
    final top = c.dy - h * 0.45;
    final mid = c.dy - h * 0.12;
    final bottom = c.dy + h * 0.55;
    final outline = Path()
      ..moveTo(c.dx - w * 0.30, top)
      ..lineTo(c.dx + w * 0.30, top)
      ..lineTo(c.dx + w * 0.5, mid)
      ..lineTo(c.dx, bottom)
      ..lineTo(c.dx - w * 0.5, mid)
      ..close();
    // brilho atras
    canvas.drawCircle(c, w * 0.9, Paint()..shader = RadialGradient(colors: [tint.withValues(alpha: 0.45), tint.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: c, radius: w * 0.9)));
    canvas.drawPath(
      outline,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, tint, Color.lerp(tint, const Color(0xFF1C3FAA), 0.55)!],
        ).createShader(outline.getBounds()),
    );
    final facet = Paint()
      ..color = Colors.white.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.025;
    canvas.drawLine(Offset(c.dx - w * 0.5, mid), Offset(c.dx + w * 0.5, mid), facet);
    canvas.drawLine(Offset(c.dx - w * 0.12, top), Offset(c.dx - w * 0.22, mid), facet);
    canvas.drawLine(Offset(c.dx + w * 0.12, top), Offset(c.dx + w * 0.22, mid), facet);
    canvas.drawLine(Offset(c.dx - w * 0.22, mid), Offset(c.dx, bottom), facet);
    canvas.drawLine(Offset(c.dx + w * 0.22, mid), Offset(c.dx, bottom), facet);
    // faisca
    _sparkle(canvas, Offset(c.dx + w * 0.28, top + h * 0.02), w * 0.16);
  }

  void _sparkle(Canvas canvas, Offset c, double r) {
    final p = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(p, Paint()..color = Colors.white.withValues(alpha: 0.9));
  }

  void _palm(Canvas canvas, Offset base, double h, {bool flip = false}) {
    final dir = flip ? -1.0 : 1.0;
    final trunk = Path()
      ..moveTo(base.dx - h * 0.03, base.dy)
      ..quadraticBezierTo(base.dx + dir * h * 0.10, base.dy - h * 0.5, base.dx + dir * h * 0.18, base.dy - h)
      ..lineTo(base.dx + dir * h * 0.22, base.dy - h)
      ..quadraticBezierTo(base.dx + dir * h * 0.15, base.dy - h * 0.5, base.dx + h * 0.04, base.dy)
      ..close();
    canvas.drawPath(trunk, Paint()..color = const Color(0xFF7A4E26));
    final crown = Offset(base.dx + dir * h * 0.2, base.dy - h);
    final leaf = Paint()..color = const Color(0xFF1F8A4C);
    for (final a in [-2.6, -2.0, -1.2, -0.5, 0.1]) {
      final tip = crown + Offset(math.cos(a) * h * 0.55, math.sin(a) * h * 0.30 + h * 0.18);
      final ctrl = crown + Offset(math.cos(a) * h * 0.30, math.sin(a) * h * 0.45 - h * 0.05);
      final l = Path()
        ..moveTo(crown.dx, crown.dy)
        ..quadraticBezierTo(ctrl.dx, ctrl.dy - h * 0.06, tip.dx, tip.dy)
        ..quadraticBezierTo(ctrl.dx, ctrl.dy + h * 0.04, crown.dx, crown.dy)
        ..close();
      canvas.drawPath(l, leaf);
    }
  }

  void _island(Canvas canvas, double s, double horizon, {double width = 0.78}) {
    final c = Offset(s * 0.5, horizon + s * 0.22);
    canvas.drawOval(Rect.fromCenter(center: c + Offset(0, s * 0.03), width: s * (width + 0.10), height: s * 0.22), Paint()..color = Colors.white.withValues(alpha: 0.22));
    canvas.drawOval(
      Rect.fromCenter(center: c, width: s * width, height: s * 0.19),
      Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFF7DDA0), Color(0xFFD8A95E)]).createShader(Rect.fromCenter(center: c, width: s * width, height: s * 0.19)),
    );
  }

  void _chest(Canvas canvas, Offset c, double w) {
    final body = RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: w, height: w * 0.62), Radius.circular(w * 0.1));
    canvas.drawRRect(body, Paint()..color = const Color(0xFF7A4A1E));
    final lid = Path()
      ..moveTo(c.dx - w / 2, c.dy - w * 0.18)
      ..quadraticBezierTo(c.dx, c.dy - w * 0.62, c.dx + w / 2, c.dy - w * 0.18)
      ..close();
    canvas.drawPath(lid, Paint()..color = const Color(0xFF9A5F28));
    final gold = Paint()..color = const Color(0xFFFFC94D);
    canvas.drawRect(Rect.fromCenter(center: c + Offset(0, -w * 0.05), width: w, height: w * 0.07), gold);
    canvas.drawRect(Rect.fromCenter(center: c, width: w * 0.12, height: w * 0.62), gold);
    // brilho saindo do bau
    canvas.drawCircle(c - Offset(0, w * 0.35), w * 0.5, Paint()..shader = RadialGradient(colors: [const Color(0xFFFFE08A).withValues(alpha: 0.5), Colors.transparent]).createShader(Rect.fromCircle(center: c - Offset(0, w * 0.35), radius: w * 0.5)));
  }

  /// Marcos historicos: a ilha vai ganhando diamantes (e um bau a partir do 4o).
  void _islandWithDiamonds(Canvas canvas, double s, double horizon) {
    _island(canvas, s, horizon);
    _palm(canvas, Offset(s * 0.24, horizon + s * 0.20), s * 0.46);
    if (tier >= 5) _palm(canvas, Offset(s * 0.80, horizon + s * 0.21), s * 0.34, flip: true);
    if (tier >= 4) _chest(canvas, Offset(s * 0.33, horizon + s * 0.24), s * 0.17);

    final count = math.min(tier, 5);
    final base = Offset(s * 0.57, horizon + s * 0.12);
    final sizes = [0.30, 0.19, 0.17, 0.14, 0.13];
    final offsets = [Offset.zero, Offset(-0.17, 0.07), Offset(0.17, 0.07), Offset(-0.08, 0.12), Offset(0.09, 0.13)];
    final boost = 1 + (tier - 1) * 0.05;
    for (var i = count - 1; i >= 0; i--) {
      _gem(canvas, base + Offset(offsets[i].dx * s, offsets[i].dy * s), s * sizes[i] * boost, tint: tier >= 7 ? const Color(0xFFB9F3FF) : const Color(0xFF7FE7FF));
    }
    if (tier == 8) {
      // aureola dourada do maior marco
      canvas.drawCircle(base, s * 0.30, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.012
        ..color = const Color(0xFFFFD36B).withValues(alpha: 0.8));
    }
  }

  /// Mensais: o mes como um grande astro no horizonte e uma gema flutuando,
  /// com aneis que aumentam a cada marco.
  void _floatingGem(Canvas canvas, double s, double horizon) {
    final c = Offset(s * 0.5, horizon - s * 0.20);
    final rings = math.min(tier, 4);
    for (var i = 1; i <= rings; i++) {
      canvas.drawCircle(c, s * (0.15 + i * 0.045), Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.006
        ..color = Colors.white.withValues(alpha: 0.35 - i * 0.05));
    }
    _gem(canvas, c, s * (0.28 + tier * 0.015));
    // pequena ilha no mar
    canvas.drawOval(Rect.fromCenter(center: Offset(s * 0.5, horizon + s * 0.22), width: s * 0.46, height: s * 0.10), Paint()..color = const Color(0xFFE5C17C));
    _palm(canvas, Offset(s * 0.42, horizon + s * 0.21), s * 0.26);
  }

  /// Consistencia: caminho de pedras sobre a agua ate a ilha (uma por mes).
  void _stonePath(Canvas canvas, double s, double horizon) {
    _island(canvas, s, horizon, width: 0.5);
    _palm(canvas, Offset(s * 0.46, horizon + s * 0.20), s * 0.34);
    final months = tier == 2 ? 6 : 3;
    final stone = Paint()..color = const Color(0xFFCFC6B8);
    for (var i = 0; i < months; i++) {
      final t = (i + 1) / (months + 1);
      final x = s * (0.15 + 0.30 * t + 0.05 * math.sin(t * math.pi * 2));
      final y = s - (s - horizon - s * 0.18) * t - s * 0.05;
      final w = s * (0.12 - t * 0.05);
      canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: w, height: w * 0.42), stone);
      canvas.drawOval(Rect.fromCenter(center: Offset(x, y - w * 0.06), width: w * 0.6, height: w * 0.16), Paint()..color = Colors.white.withValues(alpha: 0.35));
    }
    _gem(canvas, Offset(s * 0.64, horizon + s * 0.12), s * (tier == 3 ? 0.24 : 0.19));
  }

  /// Horas: ampulheta de cristal com areia de diamante sob o ceu estrelado.
  void _hourglass(Canvas canvas, double s, double horizon) {
    final c = Offset(s * 0.5, horizon + s * 0.02);
    final w = s * 0.38;
    final h = s * 0.56;
    final frame = Paint()..color = const Color(0xFFC79A55);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: c - Offset(0, h / 2), width: w * 1.15, height: s * 0.035), Radius.circular(s)), frame);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: c + Offset(0, h / 2), width: w * 1.15, height: s * 0.035), Radius.circular(s)), frame);
    final glass = Path()
      ..moveTo(c.dx - w / 2, c.dy - h / 2)
      ..lineTo(c.dx + w / 2, c.dy - h / 2)
      ..quadraticBezierTo(c.dx + w * 0.05, c.dy, c.dx + w / 2, c.dy + h / 2)
      ..lineTo(c.dx - w / 2, c.dy + h / 2)
      ..quadraticBezierTo(c.dx - w * 0.05, c.dy, c.dx - w / 2, c.dy - h / 2)
      ..close();
    canvas.drawPath(glass, Paint()..color = Colors.white.withValues(alpha: 0.18));
    canvas.drawPath(glass, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.008
      ..color = Colors.white.withValues(alpha: 0.7));
    // areia de diamante: mais cheia embaixo conforme o tier
    final fill = 0.25 + tier * 0.15;
    final sandTop = c.dy + h / 2 - h * 0.45 * fill;
    final sand = Path()
      ..moveTo(c.dx - w * 0.42, c.dy + h / 2 - s * 0.005)
      ..quadraticBezierTo(c.dx, sandTop - h * 0.08, c.dx + w * 0.42, c.dy + h / 2 - s * 0.005)
      ..close();
    canvas.drawPath(sand, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFB9F3FF), Color(0xFF4FA8E8)]).createShader(Rect.fromLTWH(0, sandTop - h * 0.1, s, h)));
    canvas.drawLine(Offset(c.dx, c.dy - h * 0.05), Offset(c.dx, c.dy + h * 0.4), Paint()
      ..strokeWidth = s * 0.006
      ..color = const Color(0xFFB9F3FF));
    _sparkle(canvas, Offset(c.dx + w * 0.45, c.dy - h * 0.35), s * 0.04);
  }

  /// Dias: nascer do sol com uma fileira de luzes (cada uma, uma semana de live).
  void _days(Canvas canvas, double s, double horizon) {
    _island(canvas, s, horizon, width: 0.66);
    _palm(canvas, Offset(s * 0.30, horizon + s * 0.20), s * 0.40);
    final lights = [2, 3, 4][(tier - 1).clamp(0, 2)];
    for (var i = 0; i < lights; i++) {
      final x = s * (0.5 + (i - (lights - 1) / 2) * 0.12);
      final o = Offset(x, horizon - s * 0.07);
      canvas.drawCircle(o, s * 0.05, Paint()..shader = RadialGradient(colors: [const Color(0xFFFFE08A), const Color(0xFFFFE08A).withValues(alpha: 0)]).createShader(Rect.fromCircle(center: o, radius: s * 0.05)));
      canvas.drawCircle(o, s * 0.018, Paint()..color = Colors.white);
    }
    _gem(canvas, Offset(s * 0.64, horizon + s * 0.12), s * 0.19);
  }

  @override
  bool shouldRepaint(covariant _AchievementPainter old) => old.family != family || old.tier != tier;
}
