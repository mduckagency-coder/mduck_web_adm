import "dart:math" as math;

import "package:flutter/material.dart";
import "mduck_diamond.dart";

/// Brasao do estagio atual da Jornada. Nao e conquista: representa o estagio.
/// Evolui visualmente por [crestKey] (configuravel no painel):
///   prata   -> pequeno e delicado, prata + roxo
///   cristal -> cristalino: estilhacos de cristal e mais brilho
///   premium -> forte: aro metalico dourado, asas de cristal e coroa
///   merito  -> raro: ouro, raios, louros, faixa e estrela
/// Se o painel enviar uma arte propria ([imageUrl]), ela substitui o desenho.
///
/// Este arquivo e copiado igual no painel web (mduck_web_adm), pra previa.
class JourneyCrest extends StatefulWidget {
  final String crestKey;
  final String? imageUrl;
  final double size;
  final bool animate;

  const JourneyCrest({super.key, required this.crestKey, this.imageUrl, this.size = 96, this.animate = true});

  @override
  State<JourneyCrest> createState() => _JourneyCrestState();
}

class _JourneyCrestState extends State<JourneyCrest> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 4200));
    if (widget.animate) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget painted(double shine) => CustomPaint(size: Size.square(widget.size), painter: _CrestPainter(widget.crestKey, shine));
    final drawn = widget.animate
        ? RepaintBoundary(
            child: AnimatedBuilder(animation: _c, builder: (_, _) => painted(_c.value < 0.3 ? _c.value / 0.3 : -1)),
          )
        : painted(-1);
    if (widget.imageUrl == null || widget.imageUrl!.isEmpty) return drawn;
    return SizedBox.square(
      dimension: widget.size,
      child: Image.network(widget.imageUrl!, fit: BoxFit.contain, errorBuilder: (_, _, _) => drawn),
    );
  }
}

class _CrestPainter extends CustomPainter {
  final String style;
  final double shine;
  _CrestPainter(this.style, this.shine);

  static const _gold = Color(0xFFFFC94D);
  static const _lilac = Color(0xFFC084FC);

  int get _rank => switch (style) { "cristal" => 2, "premium" => 3, "merito" => 4, _ => 1 };

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rank = _rank;
    final c = Offset(w / 2, h * 0.53);
    // brasao inicial e menor/delicado; cresce com o estagio
    final scale = 0.80 + rank * 0.05;
    final shieldRect = Rect.fromCenter(center: c, width: w * 0.56 * scale, height: h * 0.66 * scale);

    final rim = switch (rank) {
      1 => const [Color(0xFFFFFFFF), Color(0xFFCCD2DE), Color(0xFF7D8596), Color(0xFFEFF2F7)],
      2 => const [Color(0xFFFFFFFF), Color(0xFFE2CCFF), Color(0xFF8E5BE0), Color(0xFFF1E4FF)],
      _ => const [Color(0xFFFFF7DA), _gold, Color(0xFFB07A1E), Color(0xFFFFE9A8)],
    };

    // aura
    canvas.drawCircle(c, w * 0.42, Paint()
      ..color = (rank >= 4 ? _gold : _lilac).withValues(alpha: 0.18 + rank * 0.07)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.12));

    // raios (merito)
    if (rank >= 4) {
      final rays = Paint()..color = _gold.withValues(alpha: 0.22);
      for (var i = 0; i < 18; i++) {
        final a = i * math.pi / 9;
        canvas.drawPath(
          Path()
            ..moveTo(c.dx, c.dy)
            ..lineTo(c.dx + math.cos(a - 0.07) * w * 0.6, c.dy + math.sin(a - 0.07) * w * 0.6)
            ..lineTo(c.dx + math.cos(a + 0.07) * w * 0.6, c.dy + math.sin(a + 0.07) * w * 0.6)
            ..close(),
          rays,
        );
      }
    }

    // estilhacos / asas de cristal (cristal, premium, merito)
    if (rank >= 2) {
      for (final side in [-1.0, 1.0]) {
        for (var i = 0; i < (rank >= 3 ? 4 : 3); i++) {
          canvas.save();
          canvas.translate(c.dx + side * shieldRect.width * 0.42, c.dy - h * 0.04);
          canvas.rotate(side * (0.55 + i * 0.32));
          final len = w * (0.26 - i * 0.035) * (rank >= 3 ? 1.12 : 1);
          final shard = Path()
            ..moveTo(0, 0)
            ..lineTo(w * 0.035, -len * 0.55)
            ..lineTo(0, -len)
            ..lineTo(-w * 0.035, -len * 0.55)
            ..close();
          canvas.drawPath(
            shard,
            Paint()
              ..shader = LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [
                const Color(0xFF6B2FC2).withValues(alpha: 0.9),
                (rank >= 4 ? const Color(0xFFFFE9B0) : const Color(0xFFF1E4FF)).withValues(alpha: 0.95),
              ]).createShader(shard.getBounds()),
          );
          canvas.restore();
        }
      }
    }

    // louros (merito)
    if (rank >= 4) {
      for (final side in [-1.0, 1.0]) {
        for (var i = 0; i < 7; i++) {
          final t = i / 6;
          final ang = math.pi * (0.6 + 0.5 * t);
          final px = c.dx + side * math.cos(ang) * -w * 0.40;
          final py = c.dy + math.sin(ang) * w * 0.38;
          canvas.save();
          canvas.translate(px, py);
          canvas.rotate(side * (0.9 - t * 1.4));
          canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: w * 0.05, height: w * 0.12),
              Paint()..shader = const LinearGradient(colors: [Color(0xFFFFF1B8), _gold]).createShader(Rect.fromCenter(center: Offset.zero, width: w * 0.05, height: w * 0.12)));
          canvas.restore();
        }
      }
    }

    // escudo: aro metalico + bisel
    final outer = _shieldPath(shieldRect);
    canvas.drawPath(outer.shift(Offset(0, h * 0.02)), Paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.04));
    canvas.drawPath(outer, Paint()..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: rim).createShader(shieldRect));
    final bevelRect = shieldRect.deflate(w * 0.025);
    canvas.drawPath(_shieldPath(bevelRect), Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.008
      ..color = Colors.black.withValues(alpha: 0.25));

    // campo de cristal
    final fieldRect = shieldRect.deflate(w * 0.05);
    final field = _shieldPath(fieldRect);
    canvas.drawPath(
      field,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.25, -0.45),
          radius: 1.1,
          colors: rank >= 4
              ? const [Color(0xFFB065FF), Color(0xFF5A16B8), Color(0xFF22073F)]
              : const [Color(0xFF9A6BFF), Color(0xFF4B1A93), Color(0xFF1A0B3F)],
        ).createShader(fieldRect),
    );

    // filigrana
    final fil = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.007
      ..color = (rank >= 3 ? const Color(0xFFFFE9A8) : const Color(0xFFE9D5FF)).withValues(alpha: 0.55);
    canvas.drawPath(_shieldPath(fieldRect.deflate(w * 0.03)), fil);
    for (final side in [-1.0, 1.0]) {
      canvas.drawArc(Rect.fromCenter(center: Offset(c.dx + side * fieldRect.width * 0.18, fieldRect.bottom - fieldRect.height * 0.28), width: fieldRect.width * 0.36, height: fieldRect.height * 0.3),
          side < 0 ? math.pi * 0.1 : math.pi * 0.4, math.pi * 0.5, false, fil);
    }

    // reflexo de vidro e brilho que passa
    canvas.save();
    canvas.clipPath(field);
    canvas.drawOval(Rect.fromCenter(center: Offset(c.dx - fieldRect.width * 0.18, fieldRect.top + fieldRect.height * 0.12), width: fieldRect.width * 0.9, height: fieldRect.height * 0.35),
        Paint()..color = Colors.white.withValues(alpha: 0.10));
    if (shine >= 0) {
      final x = fieldRect.left - fieldRect.width * 0.4 + shine * fieldRect.width * 1.8;
      canvas.drawPath(
        Path()
          ..moveTo(x, fieldRect.top)
          ..lineTo(x + fieldRect.width * 0.18, fieldRect.top)
          ..lineTo(x - fieldRect.width * 0.12, fieldRect.bottom)
          ..lineTo(x - fieldRect.width * 0.3, fieldRect.bottom)
          ..close(),
        Paint()..color = Colors.white.withValues(alpha: 0.28),
      );
    }
    canvas.restore();

    // diamante MDUCK no centro
    final tier = switch (rank) { 1 => DiamondTier.normal, 2 => DiamondTier.marco, 3 => DiamondTier.grande, _ => DiamondTier.lendario };
    final gemSize = fieldRect.width * (0.62 + rank * 0.03);
    canvas.save();
    canvas.translate(c.dx - gemSize / 2, c.dy - gemSize * 0.52);
    GemPainter(tier: tier == DiamondTier.lendario ? DiamondTier.grande : tier, shine: shine).paint(canvas, Size.square(gemSize));
    canvas.restore();

    // coroa de cristais (premium/merito)
    if (rank >= 3) {
      final top = shieldRect.top - h * 0.015;
      for (final k in [(-0.16, 0.10), (0.0, 0.16), (0.16, 0.10)]) {
        final cx = c.dx + w * k.$1;
        final hh = h * k.$2;
        final cr = Path()
          ..moveTo(cx, top - hh)
          ..lineTo(cx + w * 0.045, top - hh * 0.45)
          ..lineTo(cx + w * 0.03, top + h * 0.02)
          ..lineTo(cx - w * 0.03, top + h * 0.02)
          ..lineTo(cx - w * 0.045, top - hh * 0.45)
          ..close();
        canvas.drawPath(cr, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.white, Color(0xFFD9B8FF), Color(0xFF7B22D6)]).createShader(cr.getBounds()));
        canvas.drawPath(cr, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.008
          ..color = _gold);
      }
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(c.dx, top + h * 0.02), width: w * 0.42, height: h * 0.035), Radius.circular(h * 0.02)),
        Paint()..shader = const LinearGradient(colors: [Color(0xFFFFF1B8), _gold, Color(0xFFB07A1E)]).createShader(Rect.fromCenter(center: Offset(c.dx, top), width: w * 0.42, height: h * 0.04)),
      );
    }

    // faixa + estrela (merito)
    if (rank >= 4) {
      final by = shieldRect.bottom - h * 0.10;
      final band = Path()
        ..moveTo(c.dx - w * 0.40, by)
        ..lineTo(c.dx + w * 0.40, by)
        ..lineTo(c.dx + w * 0.34, by + h * 0.05)
        ..lineTo(c.dx + w * 0.40, by + h * 0.10)
        ..lineTo(c.dx - w * 0.40, by + h * 0.10)
        ..lineTo(c.dx - w * 0.34, by + h * 0.05)
        ..close();
      canvas.drawPath(band, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF8E3BFF), Color(0xFF4A1499)]).createShader(band.getBounds()));
      canvas.drawPath(band, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.01
        ..color = _gold);
      _star(canvas, Offset(c.dx, by + h * 0.05), w * 0.04, _gold);
    }

    // faiscas
    for (var i = 0; i < rank + 2; i++) {
      final a = i * 2.2 + 0.4;
      _star(canvas, Offset(c.dx + math.cos(a) * w * 0.42, c.dy + math.sin(a) * h * 0.40), w * (0.018 + (i % 2) * 0.01), Colors.white.withValues(alpha: 0.9));
    }
  }

  Path _shieldPath(Rect r) => Path()
    ..moveTo(r.left, r.top + r.height * 0.10)
    ..quadraticBezierTo(r.center.dx, r.top - r.height * 0.06, r.right, r.top + r.height * 0.10)
    ..lineTo(r.right, r.top + r.height * 0.50)
    ..quadraticBezierTo(r.right, r.bottom - r.height * 0.14, r.center.dx, r.bottom)
    ..quadraticBezierTo(r.left, r.bottom - r.height * 0.14, r.left, r.top + r.height * 0.50)
    ..close();

  void _star(Canvas canvas, Offset c, double r, Color color) {
    final p = Path();
    for (var i = 0; i < 8; i++) {
      final rr = i.isEven ? r : r * 0.3;
      final a = i * math.pi / 4 - math.pi / 2;
      final pt = Offset(c.dx + math.cos(a) * rr, c.dy + math.sin(a) * rr);
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(p..close(), Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _CrestPainter old) => old.style != style || old.shine != shine;
}
