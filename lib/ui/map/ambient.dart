import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/gfx.dart';

/// Ambiente del mapa (decorativo, sin lógica): nubes con su sombra, pájaros, hojas y,
/// en calidad alta, coches, barcos y tren. Se repinta a 15 o 30 fps con un temporizador
/// (no a 60 fps) para no calentar el móvil, y se para del todo en calidad baja.
class AmbientLayer extends StatefulWidget {
  final Size size;
  /// Posiciones (coordenadas del mapa) de árboles de los que caen hojas.
  final List<Offset> trees;
  /// Tramos de calle (inicio, fin) por los que circulan coches.
  final List<(Offset, Offset)> roads;
  /// Puntos de agua donde fondean barcos.
  final List<Offset> boats;
  /// Vía del tren (inicio, fin), si la hay.
  final (Offset, Offset)? rail;
  const AmbientLayer({super.key, required this.size, required this.trees, this.roads = const [], this.boats = const [], this.rail});
  @override
  State<AmbientLayer> createState() => _AmbientLayerState();
}

class _AmbientLayerState extends State<AmbientLayer> {
  final _t = ValueNotifier<double>(0);
  Timer? _timer;
  final _sw = Stopwatch()..start();

  @override
  void initState() {
    super.initState();
    _start();
    Gfx.level.addListener(_start);
  }

  void _start() {
    _timer?.cancel();
    if (!Gfx.ambient) return;
    _timer = Timer.periodic(Duration(milliseconds: 1000 ~/ Gfx.ambientFps), (_) => _t.value = _sw.elapsedMilliseconds / 1000);
  }

  @override
  void dispose() {
    Gfx.level.removeListener(_start);
    _timer?.cancel();
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: RepaintBoundary(
          child: CustomPaint(size: widget.size, painter: _AmbientPainter(_t, widget)),
        ),
      );
}

class _AmbientPainter extends CustomPainter {
  final ValueNotifier<double> time;
  final AmbientLayer w;
  _AmbientPainter(this.time, this.w) : super(repaint: time);

  static const _cloudShapes = [
    [(2, 0, 4, 1), (1, 1, 7, 1), (0, 2, 10, 1), (1, 3, 8, 1)],
    [(3, 0, 3, 1), (1, 1, 8, 1), (0, 2, 12, 1), (2, 3, 7, 1)],
    [(1, 0, 3, 1), (0, 1, 6, 1), (0, 2, 7, 1)],
  ];
  static const _carColors = [Color(0xFFE2675B), Color(0xFF5AA6D6), Color(0xFFECE4D0), Color(0xFFE3A93B), Color(0xFF4FC08D)];

  @override
  void paint(Canvas canvas, Size size) {
    if (!Gfx.ambient) return;
    final t = time.value;
    if (Gfx.traffic) {
      _boats(canvas, t);
      _train(canvas, t);
      _cars(canvas, t);
    }
    _clouds(canvas, size, t);
    if (Gfx.traffic) _leaves(canvas, t);
    _birds(canvas, size, t);
  }

  void _cars(Canvas canvas, double t) {
    if (w.roads.isEmpty) return;
    final p = Paint();
    final shadow = Paint()..color = const Color(0x33000000);
    const n = 14;
    for (var i = 0; i < n; i++) {
      final r = w.roads[(i * 7) % w.roads.length];
      final speed = 0.012 + (i % 4) * 0.004;
      var u = (t * speed + i * 0.37) % 1.0;
      if (i.isOdd) u = 1 - u; // la mitad va en sentido contrario
      final pos = Offset.lerp(r.$1, r.$2, u)!;
      final dir = (r.$2 - r.$1);
      final along = dir.dx * dir.dy >= 0; // eje x o eje y del mapa
      final off = (i.isOdd ? 2.5 : -2.5);
      final c = pos + Offset(along ? -off : off, off * 0.5);
      canvas.drawRect(Rect.fromLTWH(c.dx - 3, c.dy - 1, 7, 3), shadow);
      p.color = _carColors[i % _carColors.length];
      canvas.drawRect(Rect.fromLTWH(c.dx - 3, c.dy - 3, 6, 3), p);
      p.color = const Color(0xCC1A2A2A);
      canvas.drawRect(Rect.fromLTWH(c.dx - 1, c.dy - 4, 3, 1), p);
    }
  }

  void _boats(Canvas canvas, double t) {
    final hull = Paint()..color = const Color(0xFFECE4D0);
    final sail = Paint()..color = const Color(0xFFE2675B);
    final wake = Paint()..color = const Color(0x66FFFFFF);
    for (var i = 0; i < w.boats.length; i++) {
      final b = w.boats[i];
      final dx = math.sin(t * 0.08 + i * 2) * 26;
      final c = b + Offset(dx, dx * 0.5);
      canvas.drawRect(Rect.fromLTWH(c.dx - 9, c.dy + 2, 4, 1), wake);
      canvas.drawRect(Rect.fromLTWH(c.dx - 5, c.dy - 1, 10, 3), hull);
      canvas.drawRect(Rect.fromLTWH(c.dx - 1, c.dy - 9, 1, 8), Paint()..color = const Color(0xFF3B2A1C));
      canvas.drawPath(
          Path()
            ..moveTo(c.dx, c.dy - 9)
            ..lineTo(c.dx + 5, c.dy - 2)
            ..lineTo(c.dx, c.dy - 2)
            ..close(),
          sail);
    }
  }

  void _train(Canvas canvas, double t) {
    final r = w.rail;
    if (r == null) return;
    const period = 60.0;
    final ph = (t % period) / period;
    if (ph > 0.5) return; // pasa un tren cada minuto
    final u = ph / 0.5;
    final body = Paint()..color = const Color(0xFFD9785B);
    final win = Paint()..color = const Color(0xFFF2D27A);
    for (var k = 0; k < 4; k++) {
      final p = Offset.lerp(r.$1, r.$2, (u * 1.2 - 0.1) - k * 0.012)!;
      canvas.drawRect(Rect.fromLTWH(p.dx - 6, p.dy - 7, 12, 6), body);
      canvas.drawRect(Rect.fromLTWH(p.dx - 4, p.dy - 6, 8, 2), win);
    }
  }

  void _clouds(Canvas canvas, Size size, double t) {
    final shadow = Paint()..color = const Color(0x1A000000);
    final body = Paint()..color = const Color(0x8CFFFFFF);
    final hi = Paint()..color = const Color(0x59FFFFFF);
    const n = 6;
    for (var i = 0; i < n; i++) {
      final speed = 6.0 + (i * 37 % 5);
      final span = size.width + 260;
      final x = (i * 211.0 + t * speed) % span - 130;
      final y = size.height * (0.08 + 0.8 * ((i * 0.61) % 1.0));
      final shape = _cloudShapes[i % _cloudShapes.length];
      final k = 4.0 + (i % 2) * 2;
      for (final r in shape) {
        canvas.drawRect(Rect.fromLTWH(x - 26 + r.$1 * k, y + 70 + r.$2 * k * 0.6, r.$3 * k, k * 0.6), shadow);
      }
      for (final r in shape) {
        canvas.drawRect(Rect.fromLTWH(x + r.$1 * k, y + r.$2 * k, r.$3 * k, k), body);
      }
      final top = shape.first;
      canvas.drawRect(Rect.fromLTWH(x + top.$1 * k, y + top.$2 * k, top.$3 * k, k * 0.5), hi);
    }
  }

  void _birds(Canvas canvas, Size size, double t) {
    final p = Paint()
      ..color = const Color(0xCC1A1A1A)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    for (var f = 0; f < 2; f++) {
      const period = 70.0;
      final ph = ((t + f * 31) % period) / period;
      if (ph > 0.6) continue;
      final u = ph / 0.6;
      final pass = ((t + f * 31) / period).floor();
      final dir = (pass + f).isEven ? 1.0 : -1.0;
      final y0 = size.height * (0.15 + 0.6 * (((pass * 0.37) + f * 0.5) % 1.0));
      final bx = dir > 0 ? -40 + u * (size.width + 80) : size.width + 40 - u * (size.width + 80);
      final by = y0 - u * 60;
      for (var b = 0; b < 5; b++) {
        final row = (b + 1) ~/ 2;
        final ox = -dir * row * 9.0;
        final oy = (b.isOdd ? -1 : 1) * row * 5.0;
        final flap = math.sin(t * 9 + b * 1.7) * 2.2;
        final cx = bx + ox, cy = by + oy;
        canvas.drawPath(
            Path()
              ..moveTo(cx - 3.5, cy - flap)
              ..lineTo(cx, cy)
              ..lineTo(cx + 3.5, cy - flap),
            p);
      }
    }
  }

  void _leaves(Canvas canvas, double t) {
    if (w.trees.isEmpty) return;
    const colors = [Color(0xFFE3A93B), Color(0xFFC8642F), Color(0xFF8DB04A)];
    final paint = Paint();
    const count = 14;
    for (var i = 0; i < count; i++) {
      final tree = w.trees[(i * 7919) % w.trees.length];
      const life = 4.0;
      final start = (i * 1.37) % 9.0;
      final local = (t + start) % 9.0;
      if (local > life) continue;
      final u = local / life;
      final x = tree.dx + math.sin(u * math.pi * 3 + i) * 4 + u * 6;
      final y = tree.dy - 12 + u * 18;
      paint.color = colors[i % colors.length].withValues(alpha: (1 - u) * 0.95);
      canvas.drawRect(Rect.fromLTWH(x - 1.5, y - 1, 3, 2), paint);
    }
  }

  @override
  bool shouldRepaint(_AmbientPainter o) => o.w != w;
}
