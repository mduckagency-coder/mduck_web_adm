import "dart:math" as math;

import "package:flutter/material.dart";

/// Intensidade visual do diamante da MDUCK Agency.
///   normal   -> diamante comum (lilas)
///   marco    -> marco (mais brilho e contraste)
///   grande   -> grande marco (80K): maior brilho + aro dourado
///   lendario -> 150K+ raro: ouro, raios e mais faiscas
enum DiamondTier { normal, marco, grande, lendario }

/// Importancia (1..8, configurada no painel) -> intensidade do diamante.
DiamondTier diamondTierForImportance(int importance) {
  if (importance >= 5) return DiamondTier.lendario;
  if (importance == 4) return DiamondTier.grande;
  if (importance == 3) return DiamondTier.marco;
  return DiamondTier.normal;
}

/// Diamante proprio da MDUCK Agency: cristal facetado com profundidade,
/// reflexos e um brilho que passa de tempos em tempos. Desenhado em codigo
/// (leve, nitido em qualquer tamanho), reconhecivel mesmo pequeno.
class MDuckDiamond extends StatefulWidget {
  final double size;
  final DiamondTier tier;
  final bool animate;

  const MDuckDiamond({super.key, this.size = 40, this.tier = DiamondTier.normal, this.animate = true});

  @override
  State<MDuckDiamond> createState() => _MDuckDiamondState();
}

class _MDuckDiamondState extends State<MDuckDiamond> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3600));
    if (widget.animate) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate) {
      return CustomPaint(size: Size.square(widget.size), painter: GemPainter(tier: widget.tier, shine: -1));
    }
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) {
          final t = _c.value;
          // flutua de leve; o brilho passa no primeiro terco do ciclo
          final dy = math.sin(t * math.pi * 2) * widget.size * 0.025;
          final shine = t < 0.35 ? t / 0.35 : -1.0;
          return Transform.translate(
            offset: Offset(0, dy),
            child: CustomPaint(size: Size.square(widget.size), painter: GemPainter(tier: widget.tier, shine: shine)),
          );
        },
      ),
    );
  }
}

/// Pintor do diamante (reutilizado pelos emblemas, brasoes e artes).
/// [shine] 0..1 = posicao do reflexo que passa; -1 = sem reflexo.
class GemPainter extends CustomPainter {
  final DiamondTier tier;
  final double shine;
  GemPainter({this.tier = DiamondTier.normal, this.shine = -1});

  static List<Color> palette(DiamondTier tier) => switch (tier) {
        DiamondTier.normal => const [Color(0xFFF5EBFF), Color(0xFFDCC3FF), Color(0xFFB98AF5), Color(0xFF9257E6), Color(0xFF6B2FC2), Color(0xFF41177E)],
        DiamondTier.marco => const [Color(0xFFFFF1FF), Color(0xFFF0C8FF), Color(0xFFD08CFF), Color(0xFFA64DF2), Color(0xFF7B22D6), Color(0xFF4A0F94)],
        DiamondTier.grande => const [Color(0xFFFFFFFF), Color(0xFFEBD4FF), Color(0xFFC98BFF), Color(0xFFA24CFF), Color(0xFF7417E0), Color(0xFF3F0A8C)],
        DiamondTier.lendario => const [Color(0xFFFFFFFF), Color(0xFFFFE9B0), Color(0xFFE6B6FF), Color(0xFFB45CFF), Color(0xFF7E1FE8), Color(0xFF3B0A86)],
      };

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final c = palette(tier);
    final big = tier == DiamondTier.grande || tier == DiamondTier.lendario;

    // brilho de fundo (bloom)
    final glow = switch (tier) {
      DiamondTier.normal => 0.28,
      DiamondTier.marco => 0.42,
      DiamondTier.grande => 0.6,
      DiamondTier.lendario => 0.7,
    };
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.52),
      w * 0.46,
      Paint()
        ..color = (tier == DiamondTier.lendario ? const Color(0xFFFFC94D) : const Color(0xFFB45CFF)).withValues(alpha: glow * 0.55)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.16),
    );

    // raios (lendario)
    if (tier == DiamondTier.lendario) {
      final ray = Paint()..color = const Color(0xFFFFE08A).withValues(alpha: 0.35);
      final cc = Offset(w * 0.5, h * 0.48);
      for (var i = 0; i < 12; i++) {
        final a = i * math.pi / 6;
        canvas.drawPath(
          Path()
            ..moveTo(cc.dx, cc.dy)
            ..lineTo(cc.dx + math.cos(a - 0.07) * w * 0.62, cc.dy + math.sin(a - 0.07) * w * 0.62)
            ..lineTo(cc.dx + math.cos(a + 0.07) * w * 0.62, cc.dy + math.sin(a + 0.07) * w * 0.62)
            ..close(),
          ray,
        );
      }
    }

    Offset p(double x, double y) => Offset(w * x, h * y);
    final tl = p(0.30, 0.16), tr = p(0.70, 0.16), tm = p(0.5, 0.16);
    final g0 = p(0.05, 0.40), g1 = p(0.27, 0.40), g2 = p(0.5, 0.40), g3 = p(0.73, 0.40), g4 = p(0.95, 0.40);
    final b = p(0.5, 0.95);

    final outline = Path()
      ..moveTo(tl.dx, tl.dy)
      ..lineTo(tr.dx, tr.dy)
      ..lineTo(g4.dx, g4.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo(g0.dx, g0.dy)
      ..close();

    // sombra de contato
    canvas.drawOval(
      Rect.fromCenter(center: p(0.5, 0.97), width: w * 0.5, height: h * 0.06),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.03),
    );

    void facet(List<Offset> pts, Color a, Color bb, {Alignment from = Alignment.topLeft, Alignment to = Alignment.bottomRight}) {
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final q in pts.skip(1)) {
        path.lineTo(q.dx, q.dy);
      }
      path.close();
      canvas.drawPath(path, Paint()..shader = LinearGradient(begin: from, end: to, colors: [a, bb]).createShader(path.getBounds()));
    }

    // coroa (parte de cima): mais clara
    facet([g0, tl, g1], c[1], c[3]);
    facet([tl, tm, g1], c[0], c[2]);
    facet([tm, g2, g1], c[1], c[3], from: Alignment.topCenter, to: Alignment.bottomCenter);
    facet([tm, tr, g3, g2], c[0], c[2], from: Alignment.topRight, to: Alignment.bottomLeft);
    facet([tr, g4, g3], c[2], c[4], from: Alignment.topRight, to: Alignment.bottomLeft);
    // pavilhao (parte de baixo): mais profunda
    facet([g0, g1, b], c[3], c[5]);
    facet([g1, g2, b], c[2], c[4], from: Alignment.topCenter, to: Alignment.bottomCenter);
    facet([g2, g3, b], c[3], c[5], from: Alignment.topCenter, to: Alignment.bottomCenter);
    facet([g3, g4, b], c[4], c[5], from: Alignment.topRight, to: Alignment.bottomLeft);

    // arestas
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.6, w * 0.012)
      ..color = Colors.white.withValues(alpha: 0.45);
    canvas.drawPath(
      Path()
        ..moveTo(g0.dx, g0.dy)
        ..lineTo(g4.dx, g4.dy)
        ..moveTo(tl.dx, tl.dy)
        ..lineTo(g1.dx, g1.dy)
        ..lineTo(tm.dx, tm.dy)
        ..lineTo(g2.dx, g2.dy)
        ..moveTo(tm.dx, tm.dy)
        ..lineTo(g3.dx, g3.dy)
        ..lineTo(tr.dx, tr.dy)
        ..moveTo(g1.dx, g1.dy)
        ..lineTo(b.dx, b.dy)
        ..lineTo(g3.dx, g3.dy)
        ..moveTo(g2.dx, g2.dy)
        ..lineTo(b.dx, b.dy),
      edge,
    );
    canvas.drawPath(outline, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.8, w * (big ? 0.03 : 0.018))
      ..color = tier == DiamondTier.normal
          ? Colors.white.withValues(alpha: 0.65)
          : (big ? const Color(0xFFFFD978) : const Color(0xFFF7E3FF)));

    // reflexo que passa
    if (shine >= 0) {
      canvas.save();
      canvas.clipPath(outline);
      final x = -w * 0.4 + shine * w * 1.8;
      canvas.drawPath(
        Path()
          ..moveTo(x, 0)
          ..lineTo(x + w * 0.22, 0)
          ..lineTo(x - w * 0.18, h)
          ..lineTo(x - w * 0.4, h)
          ..close(),
        Paint()..color = Colors.white.withValues(alpha: 0.55),
      );
      canvas.restore();
    }

    // highlight fixo + faiscas
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.33, h * 0.20)
        ..lineTo(w * 0.44, h * 0.20)
        ..lineTo(w * 0.30, h * 0.36)
        ..lineTo(w * 0.20, h * 0.36)
        ..close(),
      Paint()..color = Colors.white.withValues(alpha: 0.55),
    );
    _sparkle(canvas, p(0.80, 0.14), w * (big ? 0.11 : 0.08));
    if (tier != DiamondTier.normal) _sparkle(canvas, p(0.16, 0.62), w * 0.06);
    if (big) _sparkle(canvas, p(0.86, 0.66), w * 0.05);
  }

  static void _sparkle(Canvas canvas, Offset c, double r) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final rr = i.isEven ? r : r * 0.22;
      final a = i * math.pi / 4 - math.pi / 2;
      final pt = Offset(c.dx + math.cos(a) * rr, c.dy + math.sin(a) * rr);
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(path..close(), Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant GemPainter old) => old.tier != tier || old.shine != shine;
}
