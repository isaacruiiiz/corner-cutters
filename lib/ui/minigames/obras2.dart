import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../services/audio.dart';
import 'boards.dart' show WorkFn;

import '../../core/i18n.dart';
// =====================================================================
// Carpintería «Montar»: cada obra saca un mueble al azar de una bolsa
// (sin repetir hasta que salen todos los desbloqueados). Se coloca cada
// pieza tocando su hueco y se fija tocando sus uniones, una a una.
// Decoración: a suerte entre empapelar y pintar, con papel o color al azar.
// Solo presentación: el progreso sigue siendo el de la fase en el motor.
// =====================================================================

/// Clase de pieza (cómo se dibuja su frente).
enum PartKind { plain, panel, drawer, door, glass, books, cushion, metal, screen }

/// Pieza de un mueble en coordenadas de diseño (200 × 150, origen arriba a la izquierda).
/// [d] es la profundidad del volumen (0 = pieza plana sobre la anterior).
class FPart {
  final String label;
  final double x, y, w, h, d;
  /// Tono: 0 madera clara, 1 media, 2 oscura, 3 blanco, 4 azul, 5 metal, 6 oscuro.
  final int tone;
  final PartKind kind;
  const FPart(this.label, this.x, this.y, this.w, this.h, this.d, this.tone, [this.kind = PartKind.plain]);
  Rect get rect => Rect.fromLTWH(x, y, w, h);
}

class Furniture {
  final String id, name;
  /// Nivel de carpintería de la obra desde el que puede salir.
  final int minLv;
  final List<FPart> parts;
  const Furniture(this.id, this.name, this.minLv, this.parts);
}

const kFurniture = <Furniture>[
  Furniture('puerta', 'Puerta', 1, [
    FPart('Dintel', 60, 30, 80, 10, 8, 2),
    FPart('Jamba', 60, 40, 10, 100, 8, 2),
    FPart('Jamba', 130, 40, 10, 100, 8, 2),
    FPart('Hoja', 70, 40, 60, 100, 0, 0, PartKind.door),
    FPart('Bisagra', 70, 52, 5, 9, 2, 5, PartKind.metal),
    FPart('Bisagra', 70, 118, 5, 9, 2, 5, PartKind.metal),
  ]),
  Furniture('silla', 'Silla', 1, [
    FPart('Pata', 70, 40, 10, 60, 8, 1),
    FPart('Pata', 116, 40, 10, 60, 8, 1),
    FPart('Respaldo', 70, 40, 56, 10, 6, 0),
    FPart('Asiento', 64, 92, 72, 8, 36, 0),
    FPart('Pata', 66, 100, 8, 40, 8, 1),
    FPart('Pata', 122, 100, 8, 40, 8, 1),
  ]),
  Furniture('mesilla', 'Mesilla', 2, [
    FPart('Cuerpo', 66, 70, 68, 52, 34, 0),
    FPart('Cajón', 72, 77, 56, 19, 0, 1, PartKind.drawer),
    FPart('Cajón', 72, 99, 56, 19, 0, 1, PartKind.drawer),
    FPart('Pata', 70, 122, 6, 16, 4, 2),
    FPart('Pata', 124, 122, 6, 16, 4, 2),
  ]),
  Furniture('banco', 'Banco', 2, [
    FPart('Pata', 46, 110, 12, 30, 18, 1),
    FPart('Pata', 142, 110, 12, 30, 18, 1),
    FPart('Travesaño', 58, 124, 84, 6, 10, 2),
    FPart('Tablero', 36, 100, 128, 10, 26, 0),
  ]),
  Furniture('estanteria', 'Estantería', 3, [
    FPart('Armazón', 56, 24, 90, 116, 24, 2),
    FPart('Balda', 62, 30, 78, 4, 18, 0),
    FPart('Balda', 62, 58, 78, 4, 18, 0),
    FPart('Balda', 62, 86, 78, 4, 18, 0),
    FPart('Balda', 62, 114, 78, 4, 18, 0),
    FPart('Libros', 64, 36, 74, 20, 0, 4, PartKind.books),
    FPart('Libros', 64, 64, 60, 20, 0, 4, PartKind.books),
    FPart('Libros', 70, 92, 66, 20, 0, 4, PartKind.books),
  ]),
  Furniture('mesa', 'Mesa de comedor', 4, [
    FPart('Pata', 66, 70, 9, 46, 6, 1),
    FPart('Pata', 150, 70, 9, 46, 6, 1),
    FPart('Faldón', 50, 90, 102, 7, 30, 2),
    FPart('Tablero', 40, 80, 120, 10, 40, 0),
    FPart('Pata', 46, 90, 10, 50, 6, 1),
    FPart('Pata', 144, 90, 10, 50, 6, 1),
  ]),
  Furniture('ventana', 'Ventana', 4, [
    FPart('Marco', 56, 30, 88, 100, 10, 3),
    FPart('Cristal', 64, 38, 36, 84, 0, 4, PartKind.glass),
    FPart('Cristal', 100, 38, 36, 84, 0, 4, PartKind.glass),
    FPart('Alféizar', 50, 130, 100, 6, 14, 3),
  ]),
  Furniture('comoda', 'Cómoda', 6, [
    FPart('Cuerpo', 48, 60, 104, 70, 30, 0),
    FPart('Cajón', 54, 66, 92, 18, 0, 1, PartKind.drawer),
    FPart('Cajón', 54, 87, 92, 18, 0, 1, PartKind.drawer),
    FPart('Cajón', 54, 108, 92, 18, 0, 1, PartKind.drawer),
    FPart('Pata', 52, 130, 8, 10, 4, 2),
    FPart('Pata', 140, 130, 8, 10, 4, 2),
  ]),
  Furniture('escritorio', 'Escritorio', 7, [
    FPart('Pata', 42, 84, 8, 56, 6, 1),
    FPart('Cajonera', 120, 84, 40, 56, 30, 1),
    FPart('Cajón', 124, 90, 32, 14, 0, 0, PartKind.drawer),
    FPart('Cajón', 124, 107, 32, 14, 0, 0, PartKind.drawer),
    FPart('Cajón', 124, 124, 32, 14, 0, 0, PartKind.drawer),
    FPart('Tablero', 36, 76, 128, 8, 40, 0),
    FPart('Pantalla', 70, 54, 32, 22, 4, 6, PartKind.screen),
  ]),
  Furniture('cama', 'Cama', 8, [
    FPart('Cabecero', 30, 60, 14, 80, 40, 1),
    FPart('Somier', 44, 104, 124, 22, 40, 0),
    FPart('Colchón', 44, 94, 120, 10, 36, 3, PartKind.cushion),
    FPart('Almohada', 50, 86, 34, 8, 30, 3, PartKind.cushion),
    FPart('Manta', 96, 94, 68, 10, 36, 4, PartKind.cushion),
  ]),
  Furniture('aparador', 'Aparador', 9, [
    FPart('Cuerpo', 30, 66, 140, 60, 32, 0),
    FPart('Cajón', 36, 72, 62, 16, 0, 1, PartKind.drawer),
    FPart('Cajón', 102, 72, 62, 16, 0, 1, PartKind.drawer),
    FPart('Puerta', 36, 92, 62, 30, 0, 1, PartKind.door),
    FPart('Puerta', 102, 92, 62, 30, 0, 1, PartKind.door),
    FPart('Pata', 34, 126, 6, 14, 4, 2),
    FPart('Pata', 160, 126, 6, 14, 4, 2),
    FPart('Tapa', 26, 60, 148, 6, 36, 1),
  ]),
  Furniture('armario', 'Armario', 10, [
    FPart('Zócalo', 56, 132, 88, 8, 28, 2),
    FPart('Cuerpo', 56, 16, 88, 116, 28, 0),
    FPart('Puerta', 62, 22, 37, 104, 0, 1, PartKind.door),
    FPart('Puerta', 101, 22, 37, 104, 0, 1, PartKind.door),
    FPart('Corona', 52, 10, 96, 6, 34, 2),
  ]),
];

/// Bolsa de encargos: no repite un mueble hasta haber sacado todos los desbloqueados.
class FurnitureBag {
  FurnitureBag._();
  static final _left = <int>[];
  static final _rng = math.Random();
  static final _chosen = Expando<Furniture>('mueble');

  /// Mueble de una obra concreta ([key] = el objeto de la obra): se sortea una vez y se mantiene.
  static Furniture forWork(Object key, int level) => _chosen[key] ??= draw(level);

  static Furniture draw(int level) {
    final open = [for (var i = 0; i < kFurniture.length; i++) if (kFurniture[i].minLv <= level) i];
    _left.removeWhere((i) => !open.contains(i));
    if (_left.isEmpty) _left.addAll(open..shuffle(_rng));
    return kFurniture[_left.removeLast()];
  }
}

/// Paleta de madera por época (la mecánica es igual; cambia el material).
List<Color> _woods(String? era) => switch (era) {
      '1888' => const [Color(0xFFB07A48), Color(0xFF8A5A34), Color(0xFF5E3A22)],
      '1929' => const [Color(0xFF9A5E3A), Color(0xFF6E3E24), Color(0xFF4A2818)],
      '1980' => const [Color(0xFFD8C8A0), Color(0xFFB8A070), Color(0xFF8A7048)],
      '2050' => const [Color(0xFFE2C89A), Color(0xFFC8A878), Color(0xFF9A7A50)],
      _ => const [Color(0xFFC98F5A), Color(0xFFA8743F), Color(0xFF8A5A34)],
    };

Color _toneColor(int t, String? era) => switch (t) {
      0 || 1 || 2 => _woods(era)[t],
      3 => const Color(0xFFECE4D0),
      4 => const Color(0xFF5AA6D6),
      5 => const Color(0xFFC8C8C0),
      _ => const Color(0xFF2A2622),
    };

Color _sh(Color c, double f) =>
    f < 1 ? Color.lerp(c, const Color(0xFF000000), 1 - f)! : Color.lerp(c, const Color(0xFFFFFFFF), (f - 1).clamp(0.0, 1.0))!;

/// Caja con volumen (frente, tapa y costado) con contorno de 2 px.
void _box3d(Canvas c, Rect r, double d, Color col, {double k = 1, bool ghost = false, double alpha = 1}) {
  final dx = d * 0.55 * k, dy = d * 0.45 * k;
  final line = Paint()
    ..color = ghost ? Hc.acc : Hc.line.withValues(alpha: alpha)
    ..style = PaintingStyle.stroke
    ..strokeWidth = ghost ? 2 : 2
    ..strokeJoin = StrokeJoin.round;
  Path top() => Path()
    ..moveTo(r.left, r.top)
    ..lineTo(r.right, r.top)
    ..lineTo(r.right + dx, r.top - dy)
    ..lineTo(r.left + dx, r.top - dy)
    ..close();
  Path side() => Path()
    ..moveTo(r.right, r.top)
    ..lineTo(r.right + dx, r.top - dy)
    ..lineTo(r.right + dx, r.bottom - dy)
    ..lineTo(r.right, r.bottom)
    ..close();
  if (ghost) {
    final fill = Paint()..color = Hc.acc.withValues(alpha: 0.16);
    for (final p in [if (d > 0) top(), if (d > 0) side(), Path()..addRect(r)]) {
      c.drawPath(p, fill);
      _dashPath(c, p, line);
    }
    return;
  }
  final f = Paint();
  if (d > 0) {
    c.drawPath(top(), f..color = _sh(col, 1.18).withValues(alpha: alpha));
    c.drawPath(top(), line);
    c.drawPath(side(), f..color = _sh(col, 0.72).withValues(alpha: alpha));
    c.drawPath(side(), line);
  }
  c.drawRect(r, f..color = col.withValues(alpha: alpha));
  c.drawRect(r, line);
}

void _dashPath(Canvas c, Path p, Paint paint) {
  for (final m in p.computeMetrics()) {
    var dist = 0.0;
    while (dist < m.length) {
      c.drawPath(m.extractPath(dist, math.min(dist + 5, m.length)), paint);
      dist += 9;
    }
  }
}

/// Detalle del frente de cada clase de pieza.
void _partFace(Canvas c, FPart p, Rect r, Color col, double k, String? era) {
  final ink = Paint()
    ..color = Hc.line
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;
  final gold = era == '1980' ? const Color(0xFFC8C8C0) : (era == '2050' ? const Color(0xFF7FE0D8) : Hc.acc);
  switch (p.kind) {
    case PartKind.plain:
      // veta
      if (r.height > 14 * k && p.tone <= 2) {
        final g = Paint()
          ..color = _sh(col, 0.86)
          ..strokeWidth = 1;
        for (var i = 1; i < 3; i++) {
          final y = r.top + r.height * i / 3;
          c.drawLine(Offset(r.left + 3, y), Offset(r.right - 3, y + (i.isEven ? 1.5 : -1.5)), g);
        }
      }
    case PartKind.panel:
      c.drawRect(r.deflate(5 * k), ink..color = _sh(col, 0.7));
    case PartKind.drawer:
      c.drawRect(r.deflate(2.5 * k), ink..color = _sh(col, 0.75));
      final hw = math.min(18.0 * k, r.width * 0.3);
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: r.center, width: hw, height: 4 * k), const Radius.circular(2)), Paint()..color = gold);
    case PartKind.door:
      c.drawRect(Rect.fromLTRB(r.left + 5 * k, r.top + 5 * k, r.right - 5 * k, r.center.dy - 2 * k), ink..color = _sh(col, 0.72));
      c.drawRect(Rect.fromLTRB(r.left + 5 * k, r.center.dy + 2 * k, r.right - 5 * k, r.bottom - 5 * k), ink);
      // Tirador hacia el centro del mueble (las puertas pareadas se abren desde el medio).
      final hx = p.x + p.w / 2 < 100 ? r.right - 8 * k : r.left + 5 * k;
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(hx, r.center.dy - 6 * k, 3 * k, 12 * k), const Radius.circular(2)), Paint()..color = gold);
    case PartKind.glass:
      c.drawRect(r, Paint()..color = const Color(0xFF9CC8E0));
      c.drawLine(Offset(r.left + 4 * k, r.top + 8 * k), Offset(r.left + 14 * k, r.top + 4 * k), Paint()
        ..color = const Color(0xCCFFFFFF)
        ..strokeWidth = 2);
      c.drawLine(Offset(r.left, r.center.dy), Offset(r.right, r.center.dy), Paint()
        ..color = const Color(0xFFECE4D0)
        ..strokeWidth = 3 * k);
      c.drawRect(r, ink..color = Hc.line);
    case PartKind.books:
      const cols = [Color(0xFFC8553D), Color(0xFF3E5FA8), Color(0xFFE3A93B), Color(0xFF4FA36B), Color(0xFFECE4D0)];
      var x = r.left;
      var i = 0;
      while (x < r.right - 4 * k) {
        final w = (6 + (i * 7) % 5) * k;
        final h = r.height * (0.7 + 0.3 * ((i * 3) % 4) / 3);
        final b = Rect.fromLTWH(x, r.bottom - h, math.min(w, r.right - x), h);
        c.drawRect(b, Paint()..color = cols[i % cols.length]);
        c.drawRect(b, ink..color = Hc.line);
        x += w + 1;
        i++;
      }
    case PartKind.cushion:
      c.drawLine(Offset(r.left + 6 * k, r.top + 3 * k), Offset(r.right - 10 * k, r.top + 3 * k), Paint()
        ..color = const Color(0x66FFFFFF)
        ..strokeWidth = 2);
    case PartKind.metal:
      c.drawCircle(r.center, 1.2 * k, Paint()..color = Hc.line);
    case PartKind.screen:
      c.drawRect(r.deflate(2.5 * k), Paint()..color = const Color(0xFF3E5A6A));
      c.drawLine(Offset(r.left + 5 * k, r.top + 6 * k), Offset(r.left + 14 * k, r.top + 6 * k), Paint()
        ..color = const Color(0xFF7FE0D8)
        ..strokeWidth = 1.5);
  }
}

/// Uniones de una pieza: dos, en los extremos de su lado largo.
List<Offset> _joints(FPart p) {
  final r = p.rect;
  if (r.height > r.width) return [Offset(r.center.dx, r.top + math.min(8, r.height * 0.2)), Offset(r.center.dx, r.bottom - math.min(8, r.height * 0.2))];
  return [Offset(r.left + math.min(8, r.width * 0.2), r.center.dy), Offset(r.right - math.min(8, r.width * 0.2), r.center.dy)];
}

/// Carpintería: montar el mueble del encargo.
class AssembleBoard extends StatefulWidget {
  final double progress;
  final WorkFn onWork;
  final Furniture item;
  final String? era;
  const AssembleBoard({super.key, required this.progress, required this.onWork, required this.item, this.era});
  @override
  State<AssembleBoard> createState() => _AssembleBoardState();
}

class _AssembleBoardState extends State<AssembleBoard> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  int _hits = 0;

  /// Reparto de cada pieza: colocar (40 %) y dos uniones (30 % cada una).
  static const place = 0.4, perJoint = 0.3;

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  /// Pieza en curso, fracción dentro de ella y objetivo (null si está terminado).
  (int, double, Offset?, bool) _state(_Layout lay) {
    final n = widget.item.parts.length;
    final p = widget.progress.clamp(0.0, 1.0);
    if (p >= 1) return (n, 1, null, false);
    final k = math.min(n - 1, (p * n).floor());
    final sub = p * n - k;
    final part = widget.item.parts[k];
    if (sub < place) return (k, sub, lay.map(part.rect.center), true);
    final j = math.min(1, ((sub - place) / perJoint).floor());
    return (k, sub, lay.map(_joints(part)[j]), false);
  }

  void _tap(Offset q, Size size) {
    final lay = _Layout(size);
    final (_, _, target, placing) = _state(lay);
    if (target == null) return;
    final part = widget.item.parts[_state(lay).$1];
    final hitRect = lay.rect(part.rect).inflate(placing ? 14 : 0);
    final ok = placing ? (hitRect.contains(q) || (q - target).distance < 34) : (q - target).distance < 34;
    if (!ok) {
      HapticFeedback.lightImpact();
      return;
    }
    if (!widget.onWork(q)) return;
    _hits++;
    Sfx.play(placing ? 'sierra' : (_hits % 3 == 0 ? 'taladro' : 'martillo'), gain: 0.8);
    HapticFeedback.selectionClick();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final size = Size(c.maxWidth, c.maxHeight);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => _tap(d.localPosition, size),
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) => CustomPaint(size: size, painter: _AssemblePainter(this, _pulse.value)),
        ),
      );
    });
  }
}

/// Encaja el lienzo de diseño (200 × 150) en el tablero, dejando sitio a la cabecera y a la bandeja.
class _Layout {
  final Size size;
  late final double k, ox, oy;
  _Layout(this.size) {
    const top = 64.0, bottom = 86.0;
    final h = math.max(80.0, size.height - top - bottom);
    k = math.min((size.width - 24) / 200, h / 150);
    ox = (size.width - 200 * k) / 2;
    oy = top + (h - 150 * k) / 2 + 6;
  }
  Offset map(Offset p) => Offset(ox + p.dx * k, oy + p.dy * k);
  Rect rect(Rect r) => Rect.fromLTWH(ox + r.left * k, oy + r.top * k, r.width * k, r.height * k);
}

class _AssemblePainter extends CustomPainter {
  final _AssembleBoardState s;
  final double t;
  _AssemblePainter(this.s, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = s.widget;
    final lay = _Layout(size);
    final k = lay.k;
    // Taller: pared de tablones y suelo.
    final floorY = lay.oy + 140 * k;
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF2A4441));
    final joint = Paint()
      ..color = const Color(0xFF1F3735)
      ..strokeWidth = 2;
    for (var y = 40.0; y < floorY; y += 44) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), joint);
      final off = (y ~/ 44).isEven ? 0.0 : 40.0;
      for (var x = off; x < size.width; x += 80) {
        canvas.drawLine(Offset(x, y), Offset(x, math.min(floorY, y + 44)), joint);
      }
    }
    canvas.drawRect(Rect.fromLTRB(0, floorY, size.width, size.height), Paint()..color = const Color(0xFF4A3B2C));
    canvas.drawRect(Rect.fromLTRB(0, floorY - 3, size.width, floorY + 3), Paint()..color = const Color(0xFF6B5440));
    final plank = Paint()
      ..color = const Color(0xFF3E3124)
      ..strokeWidth = 2;
    for (var y = floorY + 22; y < size.height; y += 26) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), plank);
    }

    final n = w.item.parts.length;
    final (cur, sub, target, placing) = s._state(lay);
    // Piezas ya colocadas (y la que se está fijando).
    for (var i = 0; i < math.min(cur + (placing ? 0 : 1), n); i++) {
      _part(canvas, lay, w.item.parts[i], k);
    }
    if (cur < n) {
      final part = w.item.parts[cur];
      if (placing) {
        // Hueco fantasma y la pieza llegando desde la bandeja.
        _box3d(canvas, lay.rect(part.rect), part.d, Hc.acc, k: k, ghost: true);
        final e = Curves.easeOutCubic.transform((sub / _AssembleBoardState.place).clamp(0.0, 1.0));
        final from = Offset(size.width * 0.82, size.height - 40) - lay.rect(part.rect).center;
        canvas.save();
        canvas.translate(from.dx * (1 - e), from.dy * (1 - e));
        _part(canvas, lay, part, k, alpha: 0.55 + 0.45 * e);
        canvas.restore();
      }
      // Uniones de la pieza en curso.
      final js = _joints(part);
      for (var j = 0; j < js.length; j++) {
        final done = !placing && (sub - _AssembleBoardState.place) >= (j + 1) * _AssembleBoardState.perJoint;
        final active = !placing && !done && (sub - _AssembleBoardState.place) >= j * _AssembleBoardState.perJoint;
        _diamond(canvas, lay.map(js[j]), done ? Hc.ok : (active ? Hc.crit : const Color(0xFF5D7D76)), active ? t : -1, placing);
      }
      if (target != null) {
        _hint(canvas, placing ? 'Toca el hueco' : 'Toca la unión', target + Offset(0, placing ? 0 : 22));
      }
    } else {
      _hint(canvas, '¡Montado!', Offset(size.width / 2, lay.oy + 6));
    }

    // Cabecera: encargo y el siguiente (secreto).
    _chip(canvas, Rect.fromLTWH(8, 8, size.width * 0.66, 44), 'Encargo al azar · $n piezas', w.item.name, Hc.acc);
    _chip(canvas, Rect.fromLTWH(size.width * 0.66 + 16, 8, size.width * 0.34 - 24, 44), 'Siguiente', '?', Hc.dim, dashed: true, center: true);

    // Bandeja con las próximas piezas.
    final trayTop = size.height - 74;
    canvas.drawRect(Rect.fromLTRB(0, trayTop - 6, size.width, size.height), Paint()..color = const Color(0xE615292A));
    final next = [for (var i = cur + (placing ? 0 : 1); i < n && i < cur + 5; i++) w.item.parts[i]];
    final cw = (size.width - 16 - 3 * 8) / 4;
    for (var i = 0; i < 4; i++) {
      final r = Rect.fromLTWH(8 + i * (cw + 8), trayTop, cw, 64);
      final rr = RRect.fromRectAndRadius(r, const Radius.circular(10));
      if (i >= next.length) {
        canvas.drawRRect(rr, Paint()..color = const Color(0x660A1A19));
        continue;
      }
      final inHand = i == 0 && placing;
      canvas.drawRRect(rr, Paint()..color = Hc.panelIn);
      canvas.drawRRect(rr, Paint()
        ..color = inHand ? Hc.acc : Hc.line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
      final p = next[i];
      // Icono: la pieza a escala reducida.
      final ik = math.min((cw - 24) / math.max(p.w, 20), 26 / math.max(p.h, 10)).clamp(0.12, 0.8);
      final ir = Rect.fromCenter(center: r.topCenter + const Offset(0, 22), width: p.w * ik, height: p.h * ik);
      _box3d(canvas, ir, p.d * ik, _toneColor(p.tone, w.era), k: 1);
      _text(canvas, p.label.toUpperCase(), Offset(r.center.dx, r.bottom - 12), 10, inHand ? Hc.acc : Hc.ink, center: true, body: true);
    }
  }

  void _part(Canvas c, _Layout lay, FPart p, double k, {double alpha = 1}) {
    final col = _toneColor(p.tone, s.widget.era);
    final r = lay.rect(p.rect);
    _box3d(c, r, p.d, col, k: k, alpha: alpha);
    if (alpha >= 0.99) _partFace(c, p, r, col, k, s.widget.era);
  }

  void _diamond(Canvas c, Offset at, Color col, double pulse, bool small) {
    final sz = small ? 4.0 : 6.0;
    c.save();
    c.translate(at.dx, at.dy);
    c.rotate(math.pi / 4);
    if (pulse >= 0) {
      final h = 10 + 4 * pulse;
      c.drawRect(Rect.fromCenter(center: Offset.zero, width: h * 2, height: h * 2), Paint()
        ..color = col.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5);
    }
    c.drawRect(Rect.fromCenter(center: Offset.zero, width: sz * 2, height: sz * 2), Paint()..color = col);
    c.drawRect(Rect.fromCenter(center: Offset.zero, width: sz * 2, height: sz * 2), Paint()
      ..color = Hc.line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
    c.restore();
  }

  void _hint(Canvas c, String text, Offset at) {
    final tp = _tp(text, 11, Hc.ink, body: true)..layout();
    final r = Rect.fromCenter(center: at + Offset(0, 22), width: tp.width + 14, height: tp.height + 6);
    c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(6)), Paint()..color = const Color(0xCC0A1A19));
    tp.paint(c, r.topLeft + const Offset(7, 3));
  }

  @override
  bool shouldRepaint(_AssemblePainter o) => true;
}

TextPainter _tp(String text, double size, Color color, {bool body = false}) => TextPainter(
      text: TextSpan(
          text: tr(text),
          style: TextStyle(
              fontFamily: body ? Hf.body : Hf.display,
              fontWeight: body ? FontWeight.w800 : FontWeight.normal,
              fontSize: size,
              color: color,
              letterSpacing: body ? 0.6 : 0)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    );

void _text(Canvas c, String text, Offset at, double size, Color color, {bool center = false, bool body = false, double? maxW}) {
  final tp = _tp(text, size, color, body: body)..layout(maxWidth: maxW ?? double.infinity);
  tp.paint(c, center ? at - Offset(tp.width / 2, tp.height / 2) : at);
}

/// Ficha de la cabecera del tablero (encargo, siguiente…).
void _chip(Canvas c, Rect r, String cap, String value, Color valueColor, {bool dashed = false, bool center = false, Color? swatch}) {
  final rr = RRect.fromRectAndRadius(r, const Radius.circular(10));
  c.drawRRect(rr, Paint()..color = dashed ? const Color(0xCC0A1A19) : const Color(0xF2102726));
  final border = Paint()
    ..color = dashed ? Hc.lineSoft : Hc.line
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  if (dashed) {
    _dashPath(c, Path()..addRRect(rr), border);
  } else {
    c.drawRRect(rr, border);
  }
  var x = r.left + 10;
  if (swatch != null) {
    final s = Rect.fromLTWH(r.left + 7, r.top + 7, r.height - 14, r.height - 14);
    c.drawRRect(RRect.fromRectAndRadius(s, const Radius.circular(6)), Paint()..color = swatch);
    c.drawRRect(RRect.fromRectAndRadius(s, const Radius.circular(6)), border..color = Hc.line);
    x = s.right + 8;
  }
  final mw = r.right - x - 8;
  if (center) {
    _text(c, cap.toUpperCase(), Offset(r.center.dx, r.top + 12), 8.5, Hc.dim, center: true, body: true);
    _text(c, value, Offset(r.center.dx, r.top + 30), 20, valueColor, center: true);
  } else {
    _text(c, cap.toUpperCase(), Offset(x, r.top + 6), 8.5, Hc.mut, body: true, maxW: mw);
    _text(c, value, Offset(x, r.top + 18), 20, valueColor, maxW: mw);
  }
}

// =====================================================================
// Decoración: a suerte entre empapelar y pintar; papel y color al azar.
// =====================================================================

class WallPaper {
  final String id, name;
  const WallPaper(this.id, this.name);
}

const kPapers = <WallPaper>[
  WallPaper('rayas', 'Rayas crema'),
  WallPaper('damasco', 'Damasco salvia'),
  WallPaper('vichy', 'Vichy teja'),
  WallPaper('zigurat', 'Zigurat déco'),
  WallPaper('hojas', 'Hojas de higuera'),
  WallPaper('setenta', 'Cuadros 70'),
  WallPaper('espiga', 'Espiga gris'),
  WallPaper('tulipan', 'Tulipán'),
];

const kPaints = <(String, Color)>[
  ('Terracota', Color(0xFFC8603A)),
  ('Salvia', Color(0xFF8FA58A)),
  ('Azul petróleo', Color(0xFF2E5E6E)),
  ('Mostaza', Color(0xFFD8A43A)),
  ('Blanco roto', Color(0xFFECE6D8)),
  ('Gris perla', Color(0xFFB8B8B0)),
  ('Verde botella', Color(0xFF2E5A3E)),
  ('Rosa empolvado', Color(0xFFD8A8A0)),
  ('Azul cielo', Color(0xFF8CB8D8)),
  ('Burdeos', Color(0xFF7A2A34)),
];

/// Papeles que tienen sentido en cada época.
const _eraPapers = <String, List<String>>{
  '1888': ['damasco', 'rayas', 'tulipan'],
  '1929': ['zigurat', 'rayas', 'espiga', 'damasco'],
  '1980': ['setenta', 'vichy', 'hojas'],
  '2005': ['rayas', 'espiga', 'vichy', 'hojas'],
  '2020': ['hojas', 'espiga', 'vichy', 'rayas'],
  '2050': ['hojas', 'espiga'],
};

/// Encargo de decoración de una obra: papel o pintura, y cuál.
class DecoPick {
  final bool paper;
  final WallPaper? pattern;
  final (String, Color)? paint;
  const DecoPick.paper(WallPaper p)
      : paper = true,
        pattern = p,
        paint = null;
  const DecoPick.paint((String, Color) c)
      : paper = false,
        pattern = null,
        paint = c;
  String get name => paper ? pattern!.name : paint!.$1;

  static final _chosen = Expando<DecoPick>('deco');
  static final _rng = math.Random();

  static DecoPick forWork(Object key, String? era) => _chosen[key] ??= draw(era);

  static DecoPick draw(String? era) {
    if (_rng.nextBool()) {
      final ids = _eraPapers[era];
      final pool = ids == null ? kPapers : kPapers.where((p) => ids.contains(p.id)).toList();
      return DecoPick.paper(pool[_rng.nextInt(pool.length)]);
    }
    return DecoPick.paint(kPaints[_rng.nextInt(kPaints.length)]);
  }
}

/// Dibuja un papel pintado en [r] (recortado), con el dibujo desplazado [dy] px.
void paintPattern(Canvas c, Rect r, String id, {double dy = 0}) {
  c.save();
  c.clipRect(r);
  final f = Paint();
  void fill(Color col) => c.drawRect(r, f..color = col);
  Iterable<Offset> tiles(double tw, double th) sync* {
    final y0 = r.top - th + (dy % th);
    for (var y = y0; y < r.bottom; y += th) {
      for (var x = r.left - (r.left % tw); x < r.right; x += tw) {
        yield Offset(x, y);
      }
    }
  }

  switch (id) {
    case 'rayas':
      fill(const Color(0xFFEAE0C8));
      for (final o in tiles(24, 24)) {
        c.drawRect(Rect.fromLTWH(o.dx, o.dy, 9, 24), f..color = const Color(0xFFCDB98E));
        c.drawRect(Rect.fromLTWH(o.dx + 12, o.dy, 2, 24), f..color = const Color(0xFFA8905E));
      }
    case 'damasco':
      fill(const Color(0xFF8FA58A));
      for (final o in tiles(28, 36)) {
        Path dia(double cx, double cy, double rx, double ry) => Path()
          ..moveTo(cx, cy - ry)
          ..lineTo(cx + rx, cy)
          ..lineTo(cx, cy + ry)
          ..lineTo(cx - rx, cy)
          ..close();
        c.drawPath(dia(o.dx + 14, o.dy + 18, 9, 15), f..color = const Color(0xFFA9BDA3));
        c.drawPath(dia(o.dx + 14, o.dy + 18, 4, 8), f..color = const Color(0xFF7A9075));
        c.drawPath(dia(o.dx + 14, o.dy + 18, 2, 4), f..color = const Color(0xFFC8D6C2));
        c.drawPath(dia(o.dx, o.dy, 3, 5), f..color = const Color(0xFFA9BDA3));
      }
    case 'vichy':
      fill(const Color(0xFFF2ECE0));
      for (final o in tiles(18, 18)) {
        c.drawRect(Rect.fromLTWH(o.dx, o.dy, 9, 18), f..color = const Color(0x59C8603A));
        c.drawRect(Rect.fromLTWH(o.dx, o.dy, 18, 9), f..color = const Color(0x59C8603A));
      }
    case 'zigurat':
      fill(const Color(0xFF1F3A3A));
      for (final o in tiles(32, 26)) {
        final p = Path()
          ..moveTo(o.dx + 4, o.dy + 24)
          ..lineTo(o.dx + 28, o.dy + 24)
          ..lineTo(o.dx + 28, o.dy + 20)
          ..lineTo(o.dx + 24, o.dy + 20)
          ..lineTo(o.dx + 24, o.dy + 16)
          ..lineTo(o.dx + 20, o.dy + 16)
          ..lineTo(o.dx + 20, o.dy + 12)
          ..lineTo(o.dx + 12, o.dy + 12)
          ..lineTo(o.dx + 12, o.dy + 16)
          ..lineTo(o.dx + 8, o.dy + 16)
          ..lineTo(o.dx + 8, o.dy + 20)
          ..lineTo(o.dx + 4, o.dy + 20)
          ..close();
        c.drawPath(p, f..color = const Color(0xFFC8A050));
        c.drawRect(Rect.fromLTWH(o.dx + 12, o.dy + 18, 8, 6), f..color = const Color(0xFF1F3A3A));
        c.drawRect(Rect.fromLTWH(o.dx + 15, o.dy + 5, 2, 6), f..color = const Color(0xFFC8A050));
      }
    case 'hojas':
      fill(const Color(0xFFE8E0C8));
      for (final o in tiles(34, 34)) {
        final a = Path()
          ..moveTo(o.dx + 6, o.dy + 24)
          ..quadraticBezierTo(o.dx + 6, o.dy + 8, o.dx + 22, o.dy + 5)
          ..quadraticBezierTo(o.dx + 22, o.dy + 21, o.dx + 6, o.dy + 24)
          ..close();
        c.drawPath(a, f..color = const Color(0xFF6E8E5A));
        c.drawLine(Offset(o.dx + 6, o.dy + 24), Offset(o.dx + 20, o.dy + 7), Paint()
          ..color = const Color(0xFF4E6E3E)
          ..strokeWidth = 1.2);
        final b = Path()
          ..moveTo(o.dx + 20, o.dy + 32)
          ..quadraticBezierTo(o.dx + 28, o.dy + 22, o.dx + 34, o.dy + 24)
          ..quadraticBezierTo(o.dx + 30, o.dy + 33, o.dx + 20, o.dy + 32)
          ..close();
        c.drawPath(b, f..color = const Color(0xFF8AA874));
      }
    case 'setenta':
      fill(const Color(0xFFE8892E));
      for (final o in tiles(24, 24)) {
        c.drawRect(Rect.fromLTWH(o.dx + 2, o.dy + 2, 20, 20), f..color = const Color(0xFFA8551E));
        c.drawRect(Rect.fromLTWH(o.dx + 6, o.dy + 6, 12, 12), f..color = const Color(0xFFF2C25F));
        c.drawRect(Rect.fromLTWH(o.dx + 10, o.dy + 10, 4, 4), f..color = const Color(0xFF6A3A18));
      }
    case 'espiga':
      fill(const Color(0xFFD8D4CC));
      final l = Paint()
        ..color = const Color(0xFF9E9A92)
        ..strokeWidth = 3;
      for (final o in tiles(16, 16)) {
        c.drawLine(o + const Offset(0, 8), o + const Offset(8, 0), l);
        c.drawLine(o + const Offset(0, 16), o + const Offset(8, 8), l);
        c.drawLine(o + const Offset(8, 0), o + const Offset(16, 8), l);
        c.drawLine(o + const Offset(8, 8), o + const Offset(16, 16), l);
      }
    case 'tulipan':
      fill(const Color(0xFFE9DFC6));
      for (final o in tiles(26, 34)) {
        final t = Path()
          ..moveTo(o.dx + 13, o.dy + 5)
          ..lineTo(o.dx + 17, o.dy + 9)
          ..lineTo(o.dx + 16, o.dy + 16)
          ..lineTo(o.dx + 10, o.dy + 16)
          ..lineTo(o.dx + 9, o.dy + 9)
          ..close();
        c.drawPath(t, f..color = const Color(0xFFC8553D));
        c.drawRect(Rect.fromLTWH(o.dx + 12, o.dy + 16, 2, 12), f..color = const Color(0xFF4E6E3E));
        final lv = Path()
          ..moveTo(o.dx + 13, o.dy + 24)
          ..lineTo(o.dx + 7, o.dy + 19)
          ..lineTo(o.dx + 8, o.dy + 25)
          ..close()
          ..moveTo(o.dx + 13, o.dy + 22)
          ..lineTo(o.dx + 19, o.dy + 17)
          ..lineTo(o.dx + 18, o.dy + 23)
          ..close();
        c.drawPath(lv, f..color = const Color(0xFF6E8E5A));
      }
    default:
      fill(const Color(0xFFE9DFC6));
  }
  c.restore();
}

/// Fondo común de la decoración: pared de yeso, rodapié y suelo.
Rect _decoWall(Canvas canvas, Size size) {
  final wall = Rect.fromLTWH(0, 60, size.width, size.height - 60 - 34);
  canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF2A4441));
  canvas.drawRect(wall, Paint()..color = const Color(0xFFCFC8B8));
  final l = Paint()
    ..color = const Color(0xFFBDB6A6)
    ..strokeWidth = 1;
  for (var y = wall.top + 40; y < wall.bottom; y += 40) {
    canvas.drawLine(Offset(0, y), Offset(size.width, y), l);
  }
  canvas.drawRect(Rect.fromLTRB(0, wall.bottom, size.width, wall.bottom + 8), Paint()..color = const Color(0xFFE8E0CC));
  canvas.drawLine(Offset(0, wall.bottom), Offset(size.width, wall.bottom), Paint()
    ..color = Hc.line
    ..strokeWidth = 2);
  canvas.drawRect(Rect.fromLTRB(0, wall.bottom + 8, size.width, size.height), Paint()..color = const Color(0xFF8E6440));
  return wall;
}

/// Empapelar: bajar cada tira (toques en la tira) y alisar sus burbujas (toques en cada burbuja).
class WallpaperBoard extends StatefulWidget {
  final double progress;
  final WorkFn onWork;
  final WallPaper pattern;
  final int strips;
  const WallpaperBoard({super.key, required this.progress, required this.onWork, required this.pattern, this.strips = 6});
  @override
  State<WallpaperBoard> createState() => _WallpaperBoardState();
}

class _WallpaperBoardState extends State<WallpaperBoard> {
  static const drop = 0.55, bubbles = 3;
  int _taps = 0;

  /// Tira en curso, fracción dentro de ella.
  (int, double) _at() {
    final n = widget.strips;
    final p = widget.progress.clamp(0.0, 1.0);
    if (p >= 1) return (n, 1);
    final k = math.min(n - 1, (p * n).floor());
    return (k, p * n - k);
  }

  static List<Offset> bubblesOf(int k) {
    final r = math.Random(k * 7919 + 13);
    return [for (var i = 0; i < bubbles; i++) Offset(0.25 + r.nextDouble() * 0.5, 0.15 + (i + r.nextDouble() * 0.6) / bubbles * 0.75)];
  }

  int _left(double sub) => sub < drop ? bubbles : (bubbles * (1 - (sub - drop) / (1 - drop))).ceil().clamp(0, bubbles);

  void _tap(Offset q, Size size) {
    final (k, sub) = _at();
    if (k >= widget.strips) return;
    final wall = Rect.fromLTWH(0, 60, size.width, size.height - 94);
    final sw = wall.width / widget.strips;
    final col = Rect.fromLTWH(wall.left + k * sw, wall.top, sw, wall.height);
    bool ok;
    if (sub < drop) {
      ok = col.inflate(8).contains(q);
    } else {
      final bs = bubblesOf(k).take(_left(sub));
      ok = bs.any((b) => (Offset(col.left + b.dx * col.width, col.top + b.dy * col.height) - q).distance < 32);
    }
    if (!ok) {
      HapticFeedback.lightImpact();
      return;
    }
    if (!widget.onWork(q)) return;
    _taps++;
    Sfx.play(sub < drop ? 'rodillo' : 'pestana', gain: 0.7);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _tap(d.localPosition, size),
          child: CustomPaint(size: size, painter: _PaperPainter(this, _taps)),
        );
      });
}

class _PaperPainter extends CustomPainter {
  final _WallpaperBoardState s;
  final int taps;
  _PaperPainter(this.s, this.taps);
  @override
  void paint(Canvas canvas, Size size) {
    final w = s.widget;
    final wall = _decoWall(canvas, size);
    final n = w.strips;
    final sw = wall.width / n;
    final (k, sub) = s._at();
    final edge = Paint()
      ..color = Hc.line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (var i = 0; i < math.min(k, n); i++) {
      final r = Rect.fromLTWH(wall.left + i * sw, wall.top, sw, wall.height);
      paintPattern(canvas, r, w.pattern.id);
      canvas.drawRect(r, edge);
    }
    if (k < n) {
      final col = Rect.fromLTWH(wall.left + k * sw, wall.top, sw, wall.height);
      if (sub < _WallpaperBoardState.drop) {
        // Tira bajando desde el rollo, con el dibujo aún sin cuadrar.
        final e = Curves.easeOut.transform(sub / _WallpaperBoardState.drop);
        final h = math.max(16.0, col.height * e);
        final strip = Rect.fromLTWH(col.left, col.top, sw, h);
        canvas.drawRect(col, Paint()..color = Hc.acc.withValues(alpha: 0.12));
        _dashPath(canvas, Path()..addRect(col.deflate(1)), Paint()
          ..color = Hc.acc
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
        final off = (1 - e) * 14;
        paintPattern(canvas, strip, w.pattern.id, dy: off);
        canvas.drawRect(strip, edge);
        // rollo
        final roll = Rect.fromCenter(center: Offset(col.center.dx, strip.bottom), width: sw + 8, height: 14);
        canvas.drawRRect(RRect.fromRectAndRadius(roll, const Radius.circular(6)), Paint()..color = const Color(0xFFE8E0CC));
        canvas.drawRRect(RRect.fromRectAndRadius(roll, const Radius.circular(6)), edge..strokeWidth = 2);
        if (off > 3 && k > 0) {
          final y = col.top + col.height * 0.3;
          final red = Paint()
            ..color = Hc.bad
            ..strokeWidth = 2.5;
          canvas.drawLine(Offset(col.left - 4, y), Offset(col.left + 20, y), red);
          canvas.drawLine(Offset(col.left - 4, y + off), Offset(col.left + 20, y + off), red);
        }
        _hint(canvas, 'Toca la tira', Offset(col.center.dx, col.top + h * 0.5));
      } else {
        paintPattern(canvas, col, w.pattern.id);
        canvas.drawRect(col, edge);
        final left = s._left(sub);
        final bs = _WallpaperBoardState.bubblesOf(k);
        for (var i = 0; i < left; i++) {
          final b = Offset(col.left + bs[i].dx * col.width, col.top + bs[i].dy * col.height);
          final p = Path()
            ..moveTo(b.dx - 12, b.dy)
            ..quadraticBezierTo(b.dx, b.dy - 10, b.dx + 12, b.dy)
            ..quadraticBezierTo(b.dx, b.dy + 10, b.dx - 12, b.dy)
            ..close();
          canvas.drawPath(p, Paint()..color = const Color(0x66FFFFFF));
          canvas.drawPath(p, edge..strokeWidth = 1.5);
        }
        if (left > 0) {
          final b = Offset(col.left + bs[0].dx * col.width, col.top + bs[0].dy * col.height);
          _hint(canvas, 'Alisa las burbujas', b + const Offset(0, 14));
        }
      }
    }
    _chip(canvas, Rect.fromLTWH(8, 8, size.width * 0.66, 44), 'Hoy toca · empapelar', w.pattern.name, Hc.acc,
        swatch: const Color(0x00000000));
    // muestra del papel dentro de la ficha
    final sw0 = const Rect.fromLTWH(15, 15, 30, 30);
    paintPattern(canvas, sw0, w.pattern.id);
    canvas.drawRect(sw0, edge..strokeWidth = 2);
    _chip(canvas, Rect.fromLTWH(size.width * 0.66 + 16, 8, size.width * 0.34 - 24, 44), 'Tira', '${math.min(k + 1, n)}/$n', Hc.ink, center: true);
  }

  void _hint(Canvas c, String text, Offset at) {
    final tp = _tp(text, 10.5, Hc.ink, body: true)..layout();
    final r = Rect.fromCenter(center: at, width: tp.width + 14, height: tp.height + 6);
    c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(6)), Paint()..color = const Color(0xCC0A1A19));
    tp.paint(c, r.topLeft + const Offset(7, 3));
  }

  @override
  bool shouldRepaint(_PaperPainter o) => true;
}

/// Pintar: cada toque, una pasada de rodillo en la franja; dos manos.
/// Tocar a lo loco suelta chorretones que hay que tocar para limpiar.
class RollerBoard extends StatefulWidget {
  final double progress;
  final WorkFn onWork;
  final (String, Color) paint;
  final int strips;
  const RollerBoard({super.key, required this.progress, required this.onWork, required this.paint, this.strips = 5});
  @override
  State<RollerBoard> createState() => _RollerBoardState();
}

class _RollerBoardState extends State<RollerBoard> {
  static const coats = 2;
  final _drips = <Offset>[];
  int _last = 0;
  final _rng = math.Random();

  /// Unidad en curso (mano × franja) y fracción dentro de ella.
  (int, double) _at() {
    final n = widget.strips * coats;
    final p = widget.progress.clamp(0.0, 1.0);
    if (p >= 1) return (n, 1);
    final u = math.min(n - 1, (p * n).floor());
    return (u, p * n - u);
  }

  void _tap(Offset q, Size size) {
    final (u, sub) = _at();
    if (u >= widget.strips * coats) return;
    final wall = Rect.fromLTWH(0, 60, size.width, size.height - 94).deflate(10);
    // Primero los chorretones.
    for (var i = 0; i < _drips.length; i++) {
      final d = Offset(wall.left + _drips[i].dx * wall.width, wall.top + _drips[i].dy * wall.height);
      if ((d - q).distance < 30) {
        if (!widget.onWork(q)) return;
        Sfx.play('pestana', gain: 0.6);
        setState(() => _drips.removeAt(i));
        return;
      }
    }
    final sw = wall.width / widget.strips;
    final strip = u % widget.strips;
    final col = Rect.fromLTWH(wall.left + strip * sw, wall.top, sw, wall.height);
    if (_drips.isNotEmpty || !col.inflate(8).contains(q)) {
      HapticFeedback.lightImpact();
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final fast = now - _last < 110;
    _last = now;
    if (!widget.onWork(q)) return;
    Sfx.play('rodillo', gain: 0.6);
    setState(() {
      if (fast && _drips.length < 2 && _rng.nextDouble() < 0.35) {
        final y = (sub * 0.9).clamp(0.1, 0.9);
        _drips.add(Offset((strip + 0.3 + _rng.nextDouble() * 0.4) / widget.strips, y));
        HapticFeedback.mediumImpact();
      }
    });
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _tap(d.localPosition, size),
          child: CustomPaint(size: size, painter: _RollerPainter(this, _drips.length, widget.progress)),
        );
      });
}

class _RollerPainter extends CustomPainter {
  final _RollerBoardState s;
  final int drips;
  final double p;
  _RollerPainter(this.s, this.drips, this.p);
  @override
  void paint(Canvas canvas, Size size) {
    final w = s.widget;
    final outer = _decoWall(canvas, size);
    final wall = outer.deflate(10);
    final color = w.paint.$2;
    const plaster = Color(0xFFCFC8B8);
    final first = Color.lerp(plaster, color, 0.62)!;
    final n = w.strips;
    final sw = wall.width / n;
    final (u, sub) = s._at();
    final coat = u ~/ n, strip = u % n;
    for (var i = 0; i < n; i++) {
      final r = Rect.fromLTWH(wall.left + i * sw, wall.top, sw + 0.5, wall.height);
      // Mano terminada en esta franja: 0 (yeso), 1 (primera) o 2 (acabada).
      final doneCoats = coat + (i < strip ? 1 : 0);
      final base = doneCoats >= 2 || u >= n * 2 ? color : (doneCoats == 1 ? first : plaster);
      canvas.drawRect(r, Paint()..color = base);
      if (doneCoats == 1 && u < n * 2) {
        final streak = Paint()..color = color.withValues(alpha: 0.45);
        for (var x = r.left + 5; x < r.right - 3; x += 10) {
          canvas.drawRect(Rect.fromLTWH(x, r.top, 3, r.height), streak);
        }
      }
    }
    if (u < n * 2) {
      final r = Rect.fromLTWH(wall.left + strip * sw, wall.top, sw, wall.height);
      final h = r.height * sub;
      final fresh = coat == 0 ? first : color;
      canvas.drawRect(Rect.fromLTWH(r.left, r.top, r.width, h), Paint()..color = fresh);
      _dashPath(canvas, Path()..addRect(r.deflate(1)), Paint()
        ..color = Hc.acc
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
      // Rodillo en el borde de la pintura.
      final ry = r.top + math.max(10.0, h);
      final roller = Rect.fromCenter(center: Offset(r.center.dx, ry), width: sw - 6, height: 16);
      canvas.drawRRect(RRect.fromRectAndRadius(roller, const Radius.circular(4)), Paint()..color = color);
      canvas.drawRRect(RRect.fromRectAndRadius(roller, const Radius.circular(4)), Paint()
        ..color = Hc.line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
      final handle = Paint()
        ..color = const Color(0xFFC8C8C0)
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke;
      final hp = Path()
        ..moveTo(roller.center.dx, roller.bottom)
        ..lineTo(roller.center.dx, roller.bottom + 12)
        ..lineTo(roller.center.dx + 22, roller.bottom + 12)
        ..lineTo(roller.center.dx + 22, roller.bottom + 36);
      canvas.drawPath(hp, handle);
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(roller.center.dx + 16, roller.bottom + 34, 12, 26), const Radius.circular(4)), Paint()..color = Hc.acc);
    }
    // Cinta de carrocero.
    final tape = Paint()..color = const Color(0xFF4A8AC8);
    canvas.drawRect(Rect.fromLTRB(outer.left, outer.top, outer.right, wall.top), tape);
    canvas.drawRect(Rect.fromLTRB(outer.left, wall.bottom, outer.right, outer.bottom), tape);
    canvas.drawRect(Rect.fromLTRB(outer.left, outer.top, wall.left, outer.bottom), tape);
    canvas.drawRect(Rect.fromLTRB(wall.right, outer.top, outer.right, outer.bottom), tape);
    // Chorretones.
    for (final d in s._drips) {
      final at = Offset(wall.left + d.dx * wall.width, wall.top + d.dy * wall.height);
      canvas.drawRect(Rect.fromLTWH(at.dx - 1.5, at.dy - 16, 3, 16), Paint()..color = color);
      final drop = Path()
        ..moveTo(at.dx, at.dy - 2)
        ..quadraticBezierTo(at.dx - 6, at.dy + 8, at.dx, at.dy + 10)
        ..quadraticBezierTo(at.dx + 6, at.dy + 8, at.dx, at.dy - 2);
      canvas.drawPath(drop, Paint()..color = color);
      canvas.drawPath(drop, Paint()
        ..color = Hc.line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5);
      final tp = _tp('CHORRETÓN', 9, const Color(0xFF1A0705), body: true)..layout();
      final lr = Rect.fromCenter(center: at + const Offset(0, 24), width: tp.width + 12, height: tp.height + 4);
      canvas.drawRRect(RRect.fromRectAndRadius(lr, const Radius.circular(4)), Paint()..color = Hc.bad);
      tp.paint(canvas, lr.topLeft + const Offset(6, 2));
    }
    _chip(canvas, Rect.fromLTWH(8, 8, size.width * 0.66, 44), 'Hoy toca · pintar', w.paint.$1, Hc.acc, swatch: color);
    _chip(canvas, Rect.fromLTWH(size.width * 0.66 + 16, 8, size.width * 0.34 - 24, 44), 'Mano', '${math.min(coat + 1, 2)}/2', Hc.ink, center: true);
  }

  @override
  bool shouldRepaint(_RollerPainter o) => true;
}
