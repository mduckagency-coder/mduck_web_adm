import "dart:math" as math;

import "package:flutter/material.dart";
import "package:url_launcher/url_launcher.dart";

// Paleta base MDuck
const acBgTop = Color(0xFF120A33);
const acBgMid = Color(0xFF0C1230);
const acBgBottom = Color(0xFF070A1C);
const acCard = Color(0xFF1A1438);
const acPurple = Color(0xFF7A2BE2);
const acLilac = Color(0xFFC084FC);
const acLilacSoft = Color(0xFFD6CCF2);
const acGold = Color(0xFFFFC94D);

/// Identidade de cada categoria (dentro da identidade MDuck).
class AcademyTheme {
  final List<Color> gradient;
  final Color accent;
  final String pattern; // desenho de fundo do card
  const AcademyTheme(this.gradient, this.accent, this.pattern);

  static const _themes = <String, AcademyTheme>{
    "fundamentos": AcademyTheme([Color(0xFF5B2BC9), Color(0xFF2B1470)], Color(0xFFC9A8FF), "bolhas"),
    "batalhas": AcademyTheme([Color(0xFFC2185B), Color(0xFF4A0E5C)], Color(0xFFFF7A9C), "raios"),
    "games": AcademyTheme([Color(0xFF0E7C9E), Color(0xFF1B1464)], Color(0xFF5CF2FF), "grade"),
    "musica": AcademyTheme([Color(0xFFB0379F), Color(0xFF341060)], Color(0xFFFF9BE8), "ondas"),
    "engajamento": AcademyTheme([Color(0xFF2563EB), Color(0xFF1E1B5C)], Color(0xFF8EC5FF), "bolhas"),
    "todos": AcademyTheme([Color(0xFF8A5A10), Color(0xFF3A1A60)], acGold, "estrelas"),
    "recursos": AcademyTheme([Color(0xFF4338CA), Color(0xFF1E1250)], Color(0xFFA5B4FC), "grade"),
    "seguranca": AcademyTheme([Color(0xFF0F766E), Color(0xFF14204A)], Color(0xFF7CF2D4), "bolhas"),
    "exclusivo": AcademyTheme([Color(0xFF6D28D9), Color(0xFF2A0B4A)], acGold, "estrelas"),
  };

  static AcademyTheme of(String? key) => _themes[key] ?? _themes["fundamentos"]!;
}

/// Desenho decorativo leve no fundo dos cards (cada categoria com o seu).
class AcademyPatternPainter extends CustomPainter {
  final String pattern;
  final Color color;
  AcademyPatternPainter(this.pattern, this.color);

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color.withValues(alpha: 0.13)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final f = Paint()..color = color.withValues(alpha: 0.10);
    switch (pattern) {
      case "raios":
        for (var i = 0; i < 6; i++) {
          final x = s.width * (0.55 + i * 0.09);
          canvas.drawPath(
              Path()
                ..moveTo(x, -4)
                ..lineTo(x - 18, s.height * 0.5)
                ..lineTo(x - 6, s.height * 0.5)
                ..lineTo(x - 24, s.height + 4),
              p);
        }
      case "grade":
        for (var x = s.width * 0.45; x < s.width; x += 16) {
          canvas.drawLine(Offset(x, 0), Offset(x, s.height), p);
        }
        for (var y = 8.0; y < s.height; y += 16) {
          canvas.drawLine(Offset(s.width * 0.45, y), Offset(s.width, y), p);
        }
      case "ondas":
        for (var k = 0; k < 4; k++) {
          final path = Path();
          for (var x = 0.0; x <= s.width; x += 4) {
            final y = s.height * (0.35 + k * 0.17) + math.sin(x / 18 + k) * 7;
            x == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
          }
          canvas.drawPath(path, p);
        }
      case "estrelas":
        final r = math.Random(7);
        for (var i = 0; i < 14; i++) {
          canvas.drawCircle(Offset(s.width * (0.4 + r.nextDouble() * 0.6), s.height * r.nextDouble()), 1 + r.nextDouble() * 2, f);
        }
      default: // bolhas
        canvas.drawCircle(Offset(s.width * 0.92, s.height * 0.15), s.height * 0.45, f);
        canvas.drawCircle(Offset(s.width * 0.75, s.height * 1.05), s.height * 0.35, f);
    }
  }

  @override
  bool shouldRepaint(AcademyPatternPainter old) => old.pattern != pattern || old.color != color;
}

/// Abrir video (YouTube ou arquivo). O app troca pelo player interno; o
/// painel web abre em nova aba.
typedef AcademyVideoOpener = Future<void> Function(BuildContext context, {required String url, required bool youtube, String? title});

AcademyVideoOpener academyVideoOpener = (context, {required url, required youtube, title}) async {
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
};

String? youtubeId(String url) {
  final patterns = [
    RegExp(r"youtu\.be/([A-Za-z0-9_-]{6,})"),
    RegExp(r"[?&]v=([A-Za-z0-9_-]{6,})"),
    RegExp(r"youtube\.com/(?:embed|shorts|live)/([A-Za-z0-9_-]{6,})"),
  ];
  for (final p in patterns) {
    final m = p.firstMatch(url);
    if (m != null) return m.group(1);
  }
  return null;
}

String? youtubeThumb(String url) {
  final id = youtubeId(url);
  return id == null ? null : "https://img.youtube.com/vi/$id/hqdefault.jpg";
}

/// Como carregar imagens da internet. O app troca por um cache em disco
/// (cada imagem baixada uma vez so); o painel usa a rede direto.
ImageProvider Function(String url) academyImage = (url) => NetworkImage(url);
