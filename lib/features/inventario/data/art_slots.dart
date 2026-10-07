import "dart:math" as math;
import "dart:typed_data";

import "package:image/image.dart" as img;

/// Areas reservadas numa arte de Marco do Mes, em coordenadas relativas (0..1):
///   photo  circulo onde entra a foto do streamer (cx, cy, r -- r relativo a largura)
///   plate  placa retangular onde entram @ e mes (x, y, w, h)
/// Detectadas automaticamente: regioes escuras e lisas, delimitadas por um
/// contorno (o anel/borda brilhante da arte). Circulo = regiao quase quadrada
/// com preenchimento ~pi/4; placa = regiao larga e bem retangular.
///
/// Arquivo igual no app (mduck_lives) e no painel (mduck_web_adm).
class ArtSlots {
  final double cx, cy, r;
  final double? px, py, pw, ph;
  const ArtSlots({required this.cx, required this.cy, required this.r, this.px, this.py, this.pw, this.ph});

  bool get hasPlate => px != null && py != null && pw != null && ph != null;

  Map<String, dynamic> toJson() => {
        "photo": {"cx": _r(cx), "cy": _r(cy), "r": _r(r)},
        if (hasPlate) "plate": {"x": _r(px!), "y": _r(py!), "w": _r(pw!), "h": _r(ph!)},
      };

  static double _r(double v) => (v * 10000).round() / 10000;

  static ArtSlots? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final photo = raw["photo"];
    if (photo is! Map) return null;
    double? d(Map m, String k) => (m[k] as num?)?.toDouble();
    final plate = raw["plate"] is Map ? raw["plate"] as Map : null;
    final cx = d(photo, "cx"), cy = d(photo, "cy"), r = d(photo, "r");
    if (cx == null || cy == null || r == null) return null;
    return ArtSlots(
      cx: cx,
      cy: cy,
      r: r,
      px: plate == null ? null : d(plate, "x"),
      py: plate == null ? null : d(plate, "y"),
      pw: plate == null ? null : d(plate, "w"),
      ph: plate == null ? null : d(plate, "h"),
    );
  }

  ArtSlots copyWith({double? cx, double? cy, double? r, double? px, double? py, double? pw, double? ph}) => ArtSlots(
        cx: cx ?? this.cx,
        cy: cy ?? this.cy,
        r: r ?? this.r,
        px: px ?? this.px,
        py: py ?? this.py,
        pw: pw ?? this.pw,
        ph: ph ?? this.ph,
      );
}

/// Detecta as areas na imagem (bytes PNG/JPG). null se nao achar o circulo.
ArtSlots? detectArtSlots(Uint8List bytes) {
  final src = img.decodeImage(bytes);
  if (src == null) return null;
  const targetW = 240;
  final small = img.copyResize(src, width: targetW, interpolation: img.Interpolation.average);
  final w = small.width, h = small.height;
  final n = w * h;
  final r = Uint8List(n), g = Uint8List(n), b = Uint8List(n), a = Uint8List(n);
  for (final p in small) {
    final i = p.y * w + p.x;
    r[i] = p.r.toInt();
    g[i] = p.g.toInt();
    b[i] = p.b.toInt();
    a[i] = small.numChannels == 4 ? p.a.toInt() : 255;
  }
  int luma(int i) => (r[i] * 299 + g[i] * 587 + b[i] * 114) ~/ 1000;
  // pixel "de area reservada": transparente, ou escuro
  bool candidate(int i) => a[i] < 40 || luma(i) < 70;
  bool similar(int i, int j) {
    if (a[i] < 40 && a[j] < 40) return true;
    return (r[i] - r[j]).abs() + (g[i] - g[j]).abs() + (b[i] - b[j]).abs() <= 14;
  }

  final label = Int32List(n)..fillRange(0, n, -1);
  final regions = <({int area, int minX, int maxX, int minY, int maxY, double sx, double sy, bool touchesEdge})>[];
  final stack = <int>[];
  for (var start = 0; start < n; start++) {
    if (label[start] != -1 || !candidate(start)) continue;
    final id = regions.length;
    var area = 0, minX = w, maxX = 0, minY = h, maxY = 0;
    var sx = 0.0, sy = 0.0;
    var edge = false;
    stack
      ..clear()
      ..add(start);
    label[start] = id;
    while (stack.isNotEmpty) {
      final i = stack.removeLast();
      final x = i % w, y = i ~/ w;
      area++;
      sx += x;
      sy += y;
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
      if (x == 0 || y == 0 || x == w - 1 || y == h - 1) edge = true;
      for (final j in [if (x > 0) i - 1, if (x < w - 1) i + 1, if (y > 0) i - w, if (y < h - 1) i + w]) {
        if (label[j] == -1 && candidate(j) && similar(i, j)) {
          label[j] = id;
          stack.add(j);
        }
      }
    }
    regions.add((area: area, minX: minX, maxX: maxX, minY: minY, maxY: maxY, sx: sx, sy: sy, touchesEdge: edge));
  }

  ({int area, int minX, int maxX, int minY, int maxY, double sx, double sy, bool touchesEdge})? circle;
  ({int area, int minX, int maxX, int minY, int maxY, double sx, double sy, bool touchesEdge})? plate;
  for (final reg in regions) {
    if (reg.touchesEdge || reg.area < n * 0.012) continue;
    final bw = reg.maxX - reg.minX + 1, bh = reg.maxY - reg.minY + 1;
    final aspect = bw / bh;
    final fill = reg.area / (bw * bh);
    if (aspect > 0.82 && aspect < 1.22 && fill > 0.66 && fill < 0.86) {
      if (circle == null || reg.area > circle.area) circle = reg;
    } else if (aspect > 2.4 && fill > 0.78) {
      if (plate == null || reg.area > plate.area) plate = reg;
    }
  }
  if (circle == null) return null;
  final c = circle;
  // raio pela area (robusto a borda irregular), centro pelo centroide
  final radiusPx = math.sqrt(c.area / math.pi);
  return ArtSlots(
    cx: (c.sx / c.area + 0.5) / w,
    cy: (c.sy / c.area + 0.5) / h,
    r: (radiusPx + 0.5) / w,
    px: plate == null ? null : plate.minX / w,
    py: plate == null ? null : plate.minY / h,
    pw: plate == null ? null : (plate.maxX - plate.minX + 1) / w,
    ph: plate == null ? null : (plate.maxY - plate.minY + 1) / h,
  );
}
