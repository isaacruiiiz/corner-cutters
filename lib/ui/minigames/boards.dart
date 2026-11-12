import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/gfx.dart';
import '../../core/theme.dart';
import '../../services/audio.dart';

import '../../core/i18n.dart';
import 'epocas.dart';
/// Épocas antiguas (1888 y 1929): latón, tela y hierro galvanizado en los tableros.
bool _oldEra(String? era) => era == '1929' || era == '1888';

/// Callback de trabajo: devuelve true si el toque contó.
typedef WorkFn = bool Function(Offset at);

/// Marco del tablero (board) con relieve. Sin [height] ocupa todo el alto disponible.
class BoardFrame extends StatelessWidget {
  final Widget child;
  final double? height;
  /// DLC de épocas: con [era] 1980, 2005, 2020 o 2050 el tablero cuelga de la pared de la época
  /// con una balda de objetos debajo ([trade]: 'alb', 'fon', 'ele', 'car' o 'dec').
  final String? era;
  final String trade;
  const BoardFrame({super.key, required this.child, this.height = 290, this.era, this.trade = 'alb'});

  @override
  Widget build(BuildContext context) => eraScene(era) ? _scene() : _plain();

  Widget _scene() => Container(
        height: height == null ? null : height! + kEraShelf,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Hc.line, width: 4),
          boxShadow: He.e2,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(children: [
            Positioned.fill(child: CustomPaint(painter: EraScenePainter(era!, trade))),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10 + kEraShelf),
              child: Container(
                foregroundDecoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: Hc.line, width: 2.5)),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), boxShadow: const [BoxShadow(color: Color(0x66000000), offset: Offset(3, 5), blurRadius: 4)]),
                child: ClipRRect(borderRadius: BorderRadius.circular(8), child: child),
              ),
            ),
          ]),
        ),
      );

  Widget _plain() => Container(
        height: height,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Hc.line, width: 4),
          gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Hc.boardTop, Hc.boardBot]),
          boxShadow: He.e2,
        ),
        child: Stack(children: [
          Positioned.fill(child: ClipRRect(borderRadius: BorderRadius.circular(8), child: child)),
          for (final a in const [Alignment.topLeft, Alignment.topRight, Alignment.bottomLeft, Alignment.bottomRight])
            Align(
              alignment: a,
              child: Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(shape: BoxShape.circle, color: Hc.lineSoft, border: Border.all(color: Hc.line)),
              ),
            ),
        ]),
      );
}

// =====================================================================
// Utilidades de dibujo: habitación en corte, bloques con volumen y partículas.
// =====================================================================

/// Oscurece (f < 1) o aclara (f > 1) un color.
Color _sh(Color c, double f) =>
    f < 1 ? Color.lerp(c, const Color(0xFF000000), 1 - f)! : Color.lerp(c, const Color(0xFFFFFFFF), (f - 1).clamp(0.0, 1.0))!;

/// Bloque con volumen: cara frontal, canto inferior/derecho oscuro y brillo arriba.
void _block(Canvas c, Rect r, Color col, {double d = 4, double radius = 2}) {
  final p = Paint();
  c.drawRRect(RRect.fromRectAndRadius(r.shift(Offset(d * 0.55, d)), Radius.circular(radius)), p..color = _sh(col, 0.5));
  c.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(radius)), p..color = col);
  c.drawRect(Rect.fromLTWH(r.left + 2, r.top + 1.5, math.max(0, r.width - 4), math.min(3, r.height * 0.22)), p..color = const Color(0x38FFFFFF));
}

void _label(Canvas c, String text, Offset at, {Color bg = const Color(0xCC0A1A19), Color fg = Hc.ink, double size = 11, bool center = false}) {
  final tp = TextPainter(
    text: TextSpan(text: tr(text), style: TextStyle(fontFamily: Hf.body, fontWeight: FontWeight.w800, fontSize: size, color: fg, letterSpacing: 0.4)),
    textDirection: TextDirection.ltr,
  )..layout();
  final o = center ? at - Offset(tp.width / 2 + 6, tp.height / 2 + 3) : at;
  c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(o.dx, o.dy, tp.width + 12, tp.height + 6), const Radius.circular(6)), Paint()..color = bg);
  tp.paint(c, o + const Offset(6, 3));
}

// =====================================================================
// Albañilería: toque repetido para demoler y levantar.
// =====================================================================
class BrickBoard extends StatefulWidget {
  final double progress;
  final WorkFn onWork;
  /// DLC de épocas: material del muro (ladrillo hueco, termoarcilla, pladur, bloque de cáñamo).
  final String? era;
  const BrickBoard({super.key, required this.progress, required this.onWork, this.era});
  @override
  State<BrickBoard> createState() => _BrickBoardState();
}

class _BrickBoardState extends State<BrickBoard> with SingleTickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 140));
  Offset? _hit;
  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (d) {
        if (widget.onWork(d.localPosition)) {
          Sfx.play(widget.progress >= 0.5 ? 'ladrillo' : 'martillo');
          _hit = d.localPosition;
          _shake.forward(from: 0);
        }
      },
      child: AnimatedBuilder(
        animation: _shake,
        builder: (context, _) {
          final s = math.sin(_shake.value * math.pi * 3) * (1 - _shake.value) * 3;
          return Transform.translate(
            offset: Offset(s, 0),
            child: CustomPaint(
              painter: _BrickPainter(widget.progress, _hit, _shake.value, widget.era),
              child: const SizedBox.expand(),
            ),
          );
        },
      ),
    );
  }
}

class _BrickPainter extends CustomPainter {
  final double p;
  final Offset? hit;
  final double t;
  final String? era;
  _BrickPainter(this.p, this.hit, this.t, [this.era]);

  /// Detalle de la cara de cada pieza según la época.
  void _face(Canvas c, Rect r, Color col, bool fresh, int seed) {
    switch (era) {
      case '1980': // ladrillo hueco: tres agujeros
        final hw = (r.width - 22) / 3;
        for (var i = 0; i < 3; i++) {
          final h = Rect.fromLTWH(r.left + 8 + i * (hw + 3), r.top + r.height * 0.32, hw, r.height * 0.38);
          c.drawRRect(RRect.fromRectAndRadius(h, const Radius.circular(3)), Paint()..color = Hc.line);
          c.drawRRect(RRect.fromRectAndRadius(h.deflate(1.2), const Radius.circular(2)), Paint()..color = _sh(col, 0.42));
        }
      case '2005': // termoarcilla: estrías verticales
        for (var x = r.left + 8; x < r.right - 6; x += (r.width - 14) / 7) {
          c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, r.top + 8, 3, r.height - 16), const Radius.circular(1.5)), Paint()..color = _sh(col, 0.62));
        }
      case '2020': // pladur: tornillos en los bordes y cinta en la junta
        if (fresh) {
          final sc = Paint()..color = const Color(0xFF8C979D);
          for (var y = r.top + 14; y < r.bottom - 8; y += 30) {
            c.drawCircle(Offset(r.left + 8, y), 2.2, sc);
            c.drawCircle(Offset(r.right - 8, y), 2.2, sc);
          }
          c.drawRect(Rect.fromLTWH(r.right - 3, r.top, 3, r.height), Paint()..color = const Color(0xFFF4F2EA));
        } else {
          c.drawPath(
              Path()
                ..moveTo(r.left + r.width * 0.3, r.top + 6)
                ..lineTo(r.left + r.width * 0.42, r.center.dy)
                ..lineTo(r.left + r.width * 0.34, r.bottom - 8),
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.5
                ..color = _sh(col, 0.6));
        }
      case '2050': // bloque de cáñamo y cal: fibras
        final rng = math.Random(seed);
        final fib = Paint()
          ..color = _sh(col, 0.72)
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round;
        for (var i = 0; i < 12; i++) {
          final q = Offset(r.left + 6 + rng.nextDouble() * (r.width - 16), r.top + 6 + rng.nextDouble() * (r.height - 12));
          final a = (rng.nextDouble() - 0.5) * 1.4;
          c.drawLine(q, q + Offset(math.cos(a) * 7, math.sin(a) * 7), fib);
        }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF1B3433));
    final (rows, cols) = switch (era) { '2005' || '2050' => (4, 3), '2020' => (3, 2), _ => (7, 5) };
    final (newCol, oldCol) = switch (era) {
      '1980' => (const Color(0xFFC8654A), const Color(0xFF8A4A36)),
      '2005' => (const Color(0xFFC99872), const Color(0xFF8E6A50)),
      '2020' => (const Color(0xFFE4E2DA), const Color(0xFFA89E8A)),
      '2050' => (const Color(0xFFCFC8A6), const Color(0xFF8E8870)),
      _ => (const Color(0xFFD9785B), const Color(0xFF9C5A45)),
    };
    final bw = size.width / cols, bh = size.height / rows;
    final total = rows * cols;
    // Primera mitad: demoler (los ladrillos viejos caen). Segunda: levantar (aparecen nuevos).
    final demolished = (math.min(1.0, p * 2) * total).floor();
    final rebuilt = (math.max(0.0, p * 2 - 1) * total).floor();
    final rng = math.Random(7);
    for (var r = 0; r < rows; r++) {
      final off = r.isOdd ? -bw / 2 : 0.0;
      for (var c = 0; c <= cols; c++) {
        final idx = r * cols + c % cols;
        final x = off + c * bw;
        final rect = Rect.fromLTWH(x + 2, r * bh + 2, bw - 4, bh - 4);
        final order = (idx * 11) % total;
        final old = order >= demolished;
        final fresh = (total - 1 - order) < rebuilt;
        if (!old && !fresh) {
          canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(2)), Paint()..color = const Color(0xFF243F3E));
          if (era == '2020') {
            // hueco: se ven los montantes de la estructura metálica
            for (final x in [rect.left + 4, rect.right - 14]) {
              canvas.drawRect(Rect.fromLTWH(x, rect.top, 10, rect.height), Paint()..color = Hc.line);
              canvas.drawRect(Rect.fromLTWH(x + 1, rect.top, 8, rect.height), Paint()..color = const Color(0xFFC9CED1));
              canvas.drawRect(Rect.fromLTWH(x + 3, rect.top, 2, rect.height), Paint()..color = Colors.white.withValues(alpha: 0.6));
            }
          }
          continue;
        }
        final col = fresh ? newCol : oldCol;
        canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(2)), Paint()..color = Hc.line);
        canvas.drawRRect(RRect.fromRectAndRadius(rect.deflate(1.5), const Radius.circular(2)), Paint()..color = col);
        canvas.drawRect(Rect.fromLTWH(rect.left + 2, rect.top + 2, rect.width - 4, 3), Paint()..color = Colors.white.withValues(alpha: fresh ? 0.18 : 0.08));
        _face(canvas, rect.deflate(1.5), col, fresh, idx);
        if (old && order < demolished + 6) {
          // grietas en los siguientes a caer
          final cp = Paint()
            ..color = Hc.line
            ..strokeWidth = 1.5
            ..style = PaintingStyle.stroke;
          final sx = rect.left + rect.width * (0.3 + rng.nextDouble() * 0.4);
          canvas.drawPath(
              Path()
                ..moveTo(sx, rect.top + 3)
                ..lineTo(sx + 4, rect.center.dy)
                ..lineTo(sx - 2, rect.bottom - 3),
              cp);
        }
      }
    }
    if (hit != null && t < 1) {
      canvas.drawCircle(hit!, 10 + 26 * t, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * (1 - t)
        ..color = Hc.accHi.withValues(alpha: 1 - t));
      for (var i = 0; i < 6; i++) {
        final a = i * math.pi / 3 + 0.3;
        final d = 8 + 30 * t;
        canvas.drawRect(Rect.fromCenter(center: hit! + Offset(math.cos(a) * d, math.sin(a) * d + 20 * t * t), width: 4, height: 4),
            Paint()..color = newCol.withValues(alpha: 1 - t));
      }
    }
  }

  @override
  bool shouldRepaint(_BrickPainter o) => o.p != p || o.t != t || o.era != era;
}

// =====================================================================
// Fontanería: mantener pulsado sobre cada junta.
// =====================================================================
class PipeBoard extends StatefulWidget {
  final double progress;
  /// Informa de la fracción de la fase sellada; false si no hay energía.
  final bool Function(double frac) onSeal;
  /// Circuitos que hay que sellar (cada uno con su recorrido al azar).
  final int routes;
  /// DLC de épocas: tubería de la época (null = cobre actual). Misma mecánica y mismo 3D.
  final String? era;
  const PipeBoard({super.key, required this.progress, required this.onSeal, this.routes = 3, this.era});
  @override
  State<PipeBoard> createState() => _PipeBoardState();
}

/// Un circuito: recorrido en ángulo recto de izquierda a derecha y sus juntas (codos y manguitos).
class _PipeRoute {
  final List<Offset> pts; // en fracciones del tablero
  final List<Offset> joints;
  _PipeRoute(this.pts, this.joints);
}

class _PipeBoardState extends State<PipeBoard> with SingleTickerProviderStateMixin {
  static const ticksPerJoint = 12;
  late List<_PipeRoute> _routes;
  int _r = 0, _active = 0;
  double _seal = 0;
  Timer? _hold;
  bool _holding = false;
  String? _banner;
  late final AnimationController _drip = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();

  @override
  void initState() {
    super.initState();
    _build();
    _syncTo(widget.progress);
  }

  void _build() {
    final rng = math.Random();
    _routes = [for (var i = 0; i < widget.routes; i++) _makeRoute(rng)];
    _r = 0;
    _active = 0;
    _seal = 0;
  }

  /// Recorrido con sentido: siempre avanza hacia la derecha, alternando tramos horizontales
  /// y verticales, sin cruzarse. Juntas en los codos y un manguito en el tramo más largo.
  static _PipeRoute _makeRoute(math.Random r) {
    final h = 3 + r.nextInt(2);
    final xs = <double>[];
    while (xs.length < h - 1) {
      final x = 0.16 + r.nextDouble() * 0.68;
      if (xs.every((o) => (o - x).abs() > 0.15)) xs.add(x);
    }
    xs.sort();
    final ys = <double>[0.16 + r.nextDouble() * 0.68];
    while (ys.length < h) {
      final y = 0.14 + r.nextDouble() * 0.72;
      if ((y - ys.last).abs() > 0.22) ys.add(y);
    }
    final pts = <Offset>[Offset(0, ys[0])];
    final joints = <Offset>[];
    for (var i = 0; i < h - 1; i++) {
      pts.add(Offset(xs[i], ys[i]));
      pts.add(Offset(xs[i], ys[i + 1]));
      joints.add(Offset(xs[i], ys[i]));
      joints.add(Offset(xs[i], ys[i + 1]));
    }
    pts.add(Offset(1, ys.last));
    // manguito a mitad del tramo horizontal más largo
    var best = 0, bl = 0.0;
    for (var i = 0; i < pts.length - 1; i++) {
      if (pts[i].dy == pts[i + 1].dy && (pts[i + 1].dx - pts[i].dx) > bl) {
        bl = pts[i + 1].dx - pts[i].dx;
        best = i;
      }
    }
    final mid = Offset((pts[best].dx + pts[best + 1].dx) / 2, pts[best].dy);
    final at = joints.indexWhere((j) => j.dx > mid.dx);
    joints.insert(at < 0 ? joints.length : at, mid);
    return _PipeRoute(pts, joints);
  }

  int get _total => _routes.fold(0, (a, r) => a + r.joints.length);
  int get _sealedBefore {
    var n = 0;
    for (var i = 0; i < _r; i++) {
      n += _routes[i].joints.length;
    }
    return n + _active;
  }

  double _frac() => _r >= _routes.length ? 1 : ((_sealedBefore + _seal) / _total).clamp(0.0, 1.0);

  void _syncTo(double p) {
    final target = p * _total;
    while (_r < _routes.length && _sealedBefore + 1 <= target + 1e-6) {
      _active++;
      if (_active >= _routes[_r].joints.length) {
        _active = 0;
        _r++;
      }
    }
    if (_r < _routes.length) _seal = (target - _sealedBefore).clamp(0.0, 0.99);
  }

  @override
  void didUpdateWidget(PipeBoard old) {
    super.didUpdateWidget(old);
    if (old.routes != widget.routes) {
      _build();
      _syncTo(widget.progress);
    } else if (widget.progress > _frac() + 0.01) {
      _syncTo(widget.progress); // golpe crítico o cuadrillas
    }
  }

  @override
  void dispose() {
    _hold?.cancel();
    _drip.dispose();
    super.dispose();
  }

  Offset _px(Offset f, Size s) => Offset(f.dx * s.width, f.dy * s.height);

  void _start(Offset at, Size size) {
    if (_r >= _routes.length) return;
    final j = _px(_routes[_r].joints[_active], size);
    if ((at - j).distance > 52) {
      HapticFeedback.lightImpact();
      return;
    }
    setState(() => _holding = true);
    _hold?.cancel();
    _hold = Timer.periodic(const Duration(milliseconds: 140), (_) {
      if (_r >= _routes.length) {
        _stop();
        return;
      }
      final next = _seal + 1 / ticksPerJoint;
      final done = next >= 1 - 1e-6;
      // al sellar la junta se informa ya con la junta completa
      final f = done ? ((_sealedBefore + 1) / _total) : ((_sealedBefore + next) / _total);
      if (!widget.onSeal(f.clamp(0.0, 1.0))) {
        _stop();
        return;
      }
      HapticFeedback.selectionClick();
      if (!mounted) return;
      setState(() {
        _seal = next;
        if (done) {
          _seal = 0;
          _active++;
          HapticFeedback.mediumImpact();
          Sfx.play('tuberia');
          if (_active >= _routes[_r].joints.length) {
            _active = 0;
            _r++;
            _banner = _r < _routes.length ? 'Circuito $_r/${_routes.length} sin fugas' : null;
            if (_banner != null) {
              Sfx.play('confirmar');
              Future.delayed(const Duration(milliseconds: 1100), () {
                if (mounted) setState(() => _banner = null);
              });
            }
          }
          _stop();
        }
      });
    });
  }

  void _stop() {
    _hold?.cancel();
    _hold = null;
    if (mounted) setState(() => _holding = false);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final size = Size(c.maxWidth, c.maxHeight);
      final route = _routes[math.min(_r, _routes.length - 1)];
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanDown: (d) => _start(d.localPosition, size),
        onPanEnd: (_) => _stop(),
        onPanCancel: _stop,
        child: AnimatedBuilder(
          animation: _drip,
          builder: (context, _) => CustomPaint(
            painter: _PipePainter(
              widget.progress,
              route,
              _r >= _routes.length ? route.joints.length : _active,
              _seal,
              _holding,
              _drip.value,
              _banner,
              '${math.min(_r + 1, _routes.length)}/${_routes.length}',
              era: widget.era,
            ),
            size: size,
          ),
        ),
      );
    });
  }
}

class _PipePainter extends CustomPainter {
  final double p;
  final _PipeRoute route;
  final int active;
  final double seal;
  final bool holding;
  final double t;
  final String? banner;
  final String count;
  final String? era;
  _PipePainter(this.p, this.route, this.active, this.seal, this.holding, this.t, this.banner, this.count, {this.era});

  static const _r0 = 9.0; // radio del tubo actual

  /// Radio del tubo según la época (el multicapa y el PEX son más finos).
  double get _r => switch (era) { '2005' => 7.0, '2020' => 5.5, '2050' => 6.0, _ => _r0 };

  /// Tubo cilíndrico: sombra en la pared, contorno, cuerpo, banda de luz y brillo especular.
  void _tube(Canvas canvas, Path path, Color metal) {
    Paint st(double w, Color c) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.round
      ..color = c;
    canvas.drawPath(path.shift(const Offset(5, 7)), st(_r * 2, const Color(0x40000000)));
    canvas.drawPath(path, st(_r * 2 + 4, Hc.line));
    canvas.drawPath(path, st(_r * 2, _sh(metal, 0.62)));
    canvas.drawPath(path.shift(const Offset(-1, -1.5)), st(_r * 1.4, metal));
    canvas.drawPath(path.shift(const Offset(-2, -3)), st(_r * 0.7, _sh(metal, 1.25)));
    canvas.drawPath(path.shift(const Offset(-2.5, -4.5)), st(2, Colors.white.withValues(alpha: 0.7)));
  }

  Path _hex(Offset o, double r) {
    final h = Path();
    for (var k = 0; k < 6; k++) {
      final a = k * math.pi / 3 + math.pi / 6;
      final q = o + Offset(math.cos(a) * r, math.sin(a) * r);
      if (k == 0) {
        h.moveTo(q.dx, q.dy);
      } else {
        h.lineTo(q.dx, q.dy);
      }
    }
    return h..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final (wallC, groutC) = switch (era) {
      '1980' => (const Color(0xFF2E2A22), const Color(0xFF3A342A)),
      '2005' => (const Color(0xFF26302F), const Color(0xFF2E3A39)),
      '2020' => (const Color(0xFF1E2A2C), const Color(0xFF263436)),
      '2050' => (const Color(0xFF243028), const Color(0xFF2C3A30)),
      _ => (const Color(0xFF1B3433), const Color(0xFF203B3A)),
    };
    canvas.drawRect(Offset.zero & size, Paint()..color = wallC);
    // Azulejo tenue para dar profundidad a la pared.
    final grout = Paint()..color = groutC;
    for (var x = 0.0; x < size.width; x += 28) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 2, size.height), grout);
    }
    for (var y = 0.0; y < size.height; y += 28) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 2), grout);
    }
    Offset at(Offset f) => Offset(f.dx * size.width, f.dy * size.height);
    final pts = route.pts.map(at).toList();
    // De cobre viejo (sin reparar) a cobre brillante según avanza la fase.
    // 1929: hierro galvanizado, de oxidado a gris plata.
    final metal = switch (era) {
      '1888' || '1929' => Color.lerp(const Color(0xFF7A6A5A), const Color(0xFFB8BEC0), p)!,
      '2005' => Color.lerp(const Color(0xFFB8B0A0), const Color(0xFFF1F2F2), p)!, // multicapa
      '2020' => Color.lerp(const Color(0xFF9A5A50), const Color(0xFFD8503F), p)!, // PEX de agua caliente
      '2050' => Color.lerp(const Color(0xFFB8C4C8), const Color(0xFFDCEBF2), p)!, // red de agua potable
      _ => Color.lerp(const Color(0xFF8C6A55), const Color(0xFFD08A54), p)!,
    };
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final q in pts.skip(1)) {
      path.lineTo(q.dx, q.dy);
    }
    if (era == '2005') {
      // bajante de PVC al fondo
      final x = size.width - 34;
      final bj = Rect.fromLTWH(x, 0, 24, size.height);
      canvas.drawRect(bj.shift(const Offset(4, 0)), Paint()..color = const Color(0x40000000));
      canvas.drawRect(bj.inflate(2), Paint()..color = Hc.line);
      canvas.drawRect(bj, Paint()..shader = const LinearGradient(colors: [Color(0xFFB4BCC0), Color(0xFF8E989E), Color(0xFF6E787E)]).createShader(bj));
      canvas.drawRect(Rect.fromLTWH(x + 4, 0, 3, size.height), Paint()..color = Colors.white.withValues(alpha: 0.35));
      for (final y in [size.height * 0.3, size.height * 0.75]) {
        canvas.drawRect(Rect.fromLTWH(x - 3, y, 30, 10), Paint()..color = Hc.line);
        canvas.drawRect(Rect.fromLTWH(x - 2, y + 1, 28, 8), Paint()..color = const Color(0xFF7D8A90));
      }
    }
    if (era == '2020' || era == '2050') {
      // segunda red en paralelo: agua fría (2020) o aguas grises recicladas (2050)
      final twin = era == '2020' ? Color.lerp(const Color(0xFF5A6A8A), const Color(0xFF3F7FD8), p)! : Color.lerp(const Color(0xFF7A6A8A), const Color(0xFF9A6CC8), p)!;
      _tube(canvas, path.shift(const Offset(-16, 16)), twin);
    }
    _tube(canvas, path, metal);
    if (era == '2020' && pts.length > 1) {
      // colector de latón al final del recorrido
      final e = pts.last - const Offset(28, 0);
      final col = Rect.fromCenter(center: e + const Offset(0, 8), width: 18, height: 48);
      canvas.drawRRect(RRect.fromRectAndRadius(col.shift(const Offset(3, 4)), const Radius.circular(4)), Paint()..color = const Color(0x55000000));
      canvas.drawRRect(RRect.fromRectAndRadius(col.inflate(1.5), const Radius.circular(4)), Paint()..color = Hc.line);
      canvas.drawRRect(RRect.fromRectAndRadius(col, const Radius.circular(4)),
          Paint()..shader = const LinearGradient(colors: [Color(0xFFE6CF8A), Color(0xFFC9A24A), Color(0xFF8A6A20)]).createShader(col));
      canvas.drawCircle(col.topRight + const Offset(6, 10), 5, Paint()..color = const Color(0xFFD8503F));
      canvas.drawCircle(col.bottomRight + const Offset(6, -10), 5, Paint()..color = const Color(0xFF3F7FD8));
    }
    if (era == '1980' && pts.length > 2) {
      // llave de escuadra con maneta roja en el primer tramo
      final a = pts[0], b = pts[1];
      final c = Offset(math.max(a.dx + 30, (a.dx + b.dx) / 2), a.dy);
      if ((b.dx - a.dx) > 60) {
        final body = Rect.fromCenter(center: c, width: 18, height: 22);
        canvas.drawRRect(RRect.fromRectAndRadius(body.inflate(1.5), const Radius.circular(3)), Paint()..color = Hc.line);
        canvas.drawRRect(RRect.fromRectAndRadius(body, const Radius.circular(3)),
            Paint()..shader = const LinearGradient(colors: [Color(0xFFF1F2F2), Color(0xFFAEB7BC)]).createShader(body));
        canvas.drawRect(Rect.fromCenter(center: c - const Offset(0, 18), width: 6, height: 16), Paint()..color = Hc.line);
        final h = RRect.fromRectAndRadius(Rect.fromCenter(center: c - const Offset(0, 28), width: 30, height: 9), const Radius.circular(4));
        canvas.drawRRect(h.inflate(1.5), Paint()..color = Hc.line);
        canvas.drawRRect(h, Paint()..color = const Color(0xFFC8443A));
        canvas.drawRect(Rect.fromLTWH(h.left + 3, h.top + 1.5, h.width - 6, 2), Paint()..color = Colors.white.withValues(alpha: 0.4));
      }
    }
    // Abrazaderas a la pared en los tramos horizontales.
    for (var i = 0; i < pts.length - 1; i++) {
      if (pts[i].dy != pts[i + 1].dy || (pts[i + 1].dx - pts[i].dx) < 70) continue;
      final c = Offset(pts[i].dx + (pts[i + 1].dx - pts[i].dx) * 0.28, pts[i].dy);
      canvas.drawRect(Rect.fromCenter(center: c, width: 6, height: _r * 2 + 10), Paint()..color = Hc.line);
      canvas.drawRect(Rect.fromCenter(center: c, width: 4, height: _r * 2 + 8), Paint()..color = const Color(0xFFA3AAB0));
    }
    // Juntas: selladas (verde), activa (azul, con anillo de progreso y gota) y pendientes (gris).
    for (var i = 0; i < route.joints.length; i++) {
      final c = at(route.joints[i]);
      final isA = i == active;
      final sealed = i < active;
      // Pendientes con el material de la época; activa en azul y selladas en verde (igual en todas).
      final idle = switch (era) {
        '1980' => const Color(0xFFB87444), // manguito de cobre soldado
        '2005' => const Color(0xFFC9A24A), // racor de latón
        '2020' => const Color(0xFFC9A24A), // casquillo de latón
        '2050' => const Color(0xFFC9CED1), // junta de clic
        _ => const Color(0xFF9AA6AC),
      };
      final nut = isA ? Hc.info : (sealed ? const Color(0xFF6FB98A) : idle);
      // Forma: tuerca hexagonal (actual y 2005), manguito redondo (1980, 2020 y 2050).
      final round = era == '1980' || era == '2020' || era == '2050';
      final rad = era == '2020' ? 10.0 : 13.0;
      Path shape(Offset o, double r) => round ? (Path()..addOval(Rect.fromCircle(center: o, radius: r))) : _hex(o, r);
      canvas.drawPath(shape(c + const Offset(2, 4), rad + 2), Paint()..color = const Color(0x55000000));
      canvas.drawPath(shape(c + const Offset(0, 3), rad + 2), Paint()..color = Hc.line);
      canvas.drawPath(shape(c + const Offset(0, 2), rad), Paint()..color = _sh(nut, 0.55));
      canvas.drawPath(shape(c, rad), Paint()
        ..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_sh(nut, 1.3), nut, _sh(nut, 0.75)])
            .createShader(Rect.fromCircle(center: c, radius: rad)));
      if (era == '1980') {
        // cordón de estaño de la soldadura
        canvas.drawCircle(c, rad - 2, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFFE6EBEE).withValues(alpha: 0.8));
      }
      if (era == '2050') {
        canvas.drawCircle(c, rad * 0.55, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFF5D6B72));
      } else {
        canvas.drawCircle(c, rad * 0.38, Paint()..color = _sh(nut, 0.6));
      }
      canvas.drawCircle(c - const Offset(1.5, 1.5), 2, Paint()..color = Colors.white.withValues(alpha: 0.6));
      if (!sealed && !isA) {
        // fuga pequeña en las pendientes
        final dy = 14 + 10 * ((t + i * 0.3) % 1);
        canvas.drawCircle(c + Offset(0, dy), 2, Paint()..color = Hc.info.withValues(alpha: 0.6));
      }
      if (isA) {
        canvas.drawArc(Rect.fromCircle(center: c, radius: 24), -math.pi / 2, math.pi * 2 * seal, false, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..color = Hc.ok);
        canvas.drawCircle(c, 30 + (holding ? 0 : 6 * math.sin(t * math.pi * 2)), Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Hc.info.withValues(alpha: 0.5));
        if (!holding) {
          final dy = 18 + 30 * t;
          final drop = c + Offset(0, dy);
          canvas.drawOval(Rect.fromCenter(center: drop, width: 7 * (1 - t * 0.5), height: 9 * (1 - t * 0.5)), Paint()..color = Hc.info.withValues(alpha: 1 - t));
          canvas.drawCircle(drop - const Offset(1, 2), 1.2, Paint()..color = Colors.white.withValues(alpha: 1 - t));
        }
      }
    }
    // Circuito actual / total.
    _label(canvas, 'Circuito $count', const Offset(8, 8));
    if (banner != null) {
      _label(canvas, banner!, Offset(size.width / 2, size.height / 2), bg: Hc.ok.withValues(alpha: 0.92), fg: const Color(0xFF0E2A20), size: 15, center: true);
    }
  }

  @override
  bool shouldRepaint(_PipePainter o) => true;
}

// =====================================================================
// Electricidad: cuadro eléctrico abierto. Une cada cable con el borne de su color
// arrastrando; al acertar, la corriente recorre el cable y se enciende el piloto;
// al fallar, chispazo con chispas que saltan y caen.
// =====================================================================
class WireBoard extends StatefulWidget {
  final double progress;
  final WorkFn onWork;
  final VoidCallback onMiss;
  /// Pares de cables (3 a 6 según el nivel de la obra).
  final int pairs;
  /// DLC de épocas: cuadro de la época (null = el cuadro actual). Misma mecánica y mismo 3D.
  final String? era;
  const WireBoard({super.key, required this.progress, required this.onWork, required this.onMiss, this.pairs = 4, this.era});
  @override
  State<WireBoard> createState() => _WireBoardState();
}

class _Spark {
  final Offset at;
  final bool big;
  final int seed;
  _Spark(this.at, this.big, this.seed);
}

class _WireBoardState extends State<WireBoard> with SingleTickerProviderStateMixin {
  static const colors = [Color(0xFFE2675B), Color(0xFF5AA6D6), Color(0xFFE3A93B), Color(0xFF4FC08D), Color(0xFFB98AD6), Color(0xFFECE4D0)];

  /// Colores de los cables de cada época (el número del borne sigue siendo la guía).
  static const _eraColors = <String, List<Color>>{
    '1980': [Color(0xFFC8443A), Color(0xFFA9AFAF), Color(0xFFD9B43A), Color(0xFFF1EAD6), Color(0xFFB07A4A), Color(0xFF4A7AB8)],
    '2005': [Color(0xFF8A5A3C), Color(0xFF3C7DC4), Color(0xFF3A3F44), Color(0xFFD9D03A), Color(0xFFC8443A), Color(0xFFF4F4F4)],
    '2020': [Color(0xFF8A5A3C), Color(0xFF3C7DC4), Color(0xFFD9D03A), Color(0xFFF08A3C), Color(0xFFA9AFAF), Color(0xFFEEF1F0)],
    '2050': [Color(0xFFD8503F), Color(0xFF3C7DC4), Color(0xFF8A5A3C), Color(0xFFD9D03A), Color(0xFFF08A3C), Color(0xFF9A6CC8)],
  };

  /// Cable de tierra (amarillo y verde a rayas).
  static const earth = Color(0xFFD9D03A);

  List<Color> get cols => _eraColors[widget.era] ?? colors;
  final _rng = math.Random();
  late List<int> _l, _r;
  final Set<int> _ok = {};
  int? _fromSide, _fromSlot;
  Offset? _cur;
  _Spark? _spark;
  int? _flow; // color del cable por el que pasa la corriente ahora
  bool _complete = false;
  int _seed = 0;
  late final AnimationController _fx = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));

  int get _n => widget.pairs.clamp(3, 6);

  @override
  void initState() {
    super.initState();
    _deal();
  }

  @override
  void didUpdateWidget(WireBoard old) {
    super.didUpdateWidget(old);
    if (old.pairs != widget.pairs) _deal();
  }

  @override
  void dispose() {
    _fx.dispose();
    super.dispose();
  }

  void _deal() {
    _l = List.generate(_n, (i) => i)..shuffle(_rng);
    _r = List.generate(_n, (i) => i)..shuffle(_rng);
    var tries = 0;
    while (tries++ < 4 && List.generate(_n, (i) => _l[i] == _r[i]).where((x) => x).length > 1) {
      _r.shuffle(_rng);
    }
    _ok.clear();
    _complete = false;
    _flow = null;
  }

  /// Placa de montaje (dentro de la caja metálica).
  static Rect plate(Size s) => Rect.fromLTRB(16, 16, s.width - 16, s.height - 16);

  /// Zona de bornes (debajo de la fila de magnetotérmicos).
  static Rect bay(Size s) {
    final p = plate(s);
    return Rect.fromLTRB(p.left, p.top + 52, p.right, p.bottom - 6);
  }

  Offset term(Size s, int side, int slot) {
    final b = bay(s);
    final x = side == 0 ? b.left + 40 : b.right - 40;
    final y = b.top + 12 + (b.height - 24) * (slot + 0.5) / _n;
    return Offset(x, y);
  }

  int _color(int side, int slot) => side == 0 ? _l[slot] : _r[slot];

  /// Siguiente número que toca conectar (van en orden: 1, 2, 3…).
  int get _nextNum {
    for (var i = 0; i < _n; i++) {
      if (!_ok.contains(i)) return i;
    }
    return _n;
  }

  (int, int)? _near(Size s, Offset q, {int? side, double max = 32}) {
    (int, int)? best;
    var bd = max;
    for (final sd in [0, 1]) {
      if (side != null && sd != side) continue;
      for (var i = 0; i < _n; i++) {
        final d = (term(s, sd, i) - q).distance;
        if (d < bd) {
          bd = d;
          best = (sd, i);
        }
      }
    }
    return best;
  }

  void _down(Offset q, Size s) {
    if (_complete) return;
    final t = _near(s, q);
    if (t == null || _ok.contains(_color(t.$1, t.$2))) return;
    setState(() {
      _fromSide = t.$1;
      _fromSlot = t.$2;
      _cur = q;
    });
  }

  void _end(Size s) {
    final fs = _fromSide, fl = _fromSlot, cur = _cur;
    setState(() {
      _fromSide = null;
      _fromSlot = null;
      _cur = null;
    });
    if (fs == null || fl == null || cur == null) return;
    final t = _near(s, cur, side: 1 - fs, max: 40);
    if (t == null) return;
    final a = term(s, fs, fl), b = term(s, t.$1, t.$2);
    final c0 = _color(fs, fl);
    if (c0 == _color(t.$1, t.$2) && c0 == _nextNum) {
      // Cada conexión vale cinco toques.
      var any = false;
      for (var k = 0; k < 5; k++) {
        if (!widget.onWork(Offset.lerp(a, b, 0.15 + 0.175 * k)! - const Offset(0, 14))) break;
        any = true;
      }
      if (!any) return;
      Sfx.play('cable');
      HapticFeedback.mediumImpact();
      setState(() {
        final c = _color(fs, fl);
        _ok.add(c);
        _flow = c;
        _spark = _Spark(b, false, _seed++);
        if (_ok.length >= _n) {
          _complete = true;
          Future.delayed(const Duration(milliseconds: 900), () {
            if (mounted) setState(_deal);
          });
        }
      });
      _fx.forward(from: 0);
    } else {
      HapticFeedback.heavyImpact();
      widget.onMiss();
      setState(() {
        _flow = null;
        _spark = _Spark(b, true, _seed++);
      });
      _fx.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final size = Size(c.maxWidth, c.maxHeight);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanDown: (d) => _down(d.localPosition, size),
        onPanUpdate: (d) {
          if (_fromSide != null) setState(() => _cur = d.localPosition);
        },
        onPanEnd: (_) => _end(size),
        onPanCancel: () => setState(() {
          _fromSide = null;
          _cur = null;
        }),
        child: AnimatedBuilder(
          animation: _fx,
          builder: (context, _) => CustomPaint(size: size, painter: _WirePainter(this, _fx.value)),
        ),
      );
    });
  }
}

class _WirePainter extends CustomPainter {
  final _WireBoardState s;
  final double t;
  _WirePainter(this.s, this.t);

  static List<Offset> _curve(Offset a, Offset b, double sag) {
    final pts = <Offset>[];
    for (var i = 0; i <= 24; i++) {
      final u = i / 24;
      final p = Offset.lerp(a, b, u)!;
      pts.add(p + Offset(0, math.sin(math.pi * u) * sag));
    }
    return pts;
  }

  Path _path(List<Offset> pts) {
    final p = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final q in pts.skip(1)) {
      p.lineTo(q.dx, q.dy);
    }
    return p;
  }

  /// Cable con volumen: sombra proyectada, funda con sombreado y brillo, y puntera de cobre.
  void _cable(Canvas c, List<Offset> pts, Color col, {bool live = false}) {
    final path = _path(pts);
    final cloth = _oldEra(s.widget.era);
    Paint st(double w, Color k) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = k;
    c.drawPath(path.shift(const Offset(3, 6)), st(8, const Color(0x55000000)));
    c.drawPath(path, st(10, Hc.line));
    c.drawPath(path, st(7.5, _sh(col, 0.62)));
    c.drawPath(path.shift(const Offset(0, -1)), st(5, col));
    if (cloth) {
      // 1929: funda de tela trenzada (rayas cruzadas sobre el color, sin brillo plástico).
      final braid = Paint()
        ..color = const Color(0x5C000000)
        ..strokeWidth = 1.2;
      for (var i = 0; i + 1 < pts.length; i++) {
        final a = pts[i], b = pts[i + 1];
        final d = b - a;
        final len = d.distance;
        if (len < 0.1) continue;
        final u = d / len;
        final nrm = Offset(-u.dy, u.dx);
        for (var t = 0.0; t < len; t += 3.2) {
          final q = a + u * t + const Offset(0, -1);
          c.drawLine(q - nrm * 2.4 - u * 1.2, q + nrm * 2.4 + u * 1.2, braid);
        }
      }
      c.drawPath(path.shift(const Offset(-0.5, -2)), st(1.2, Colors.white.withValues(alpha: 0.22)));
    } else {
      if (col == _WireBoardState.earth) {
        // tierra: rayas verdes sobre el amarillo
        for (final m in path.computeMetrics()) {
          for (var d = 0.0; d < m.length; d += 16) {
            c.drawPath(m.extractPath(d, math.min(d + 7, m.length)).shift(const Offset(0, -1)), st(5, const Color(0xFF3E9A4A))..strokeCap = StrokeCap.butt);
          }
        }
      }
      c.drawPath(path.shift(const Offset(-0.5, -2)), st(1.6, Colors.white.withValues(alpha: 0.55)));
    }
    if (live && Gfx.pulse) {
      c.drawPath(path, st(14, col.withValues(alpha: 0.18))..maskFilter = Gfx.liveBlur ? const MaskFilter.blur(BlurStyle.normal, 5) : null);
    }
  }

  void _screw(Canvas c, Offset o, {double r = 3.2}) {
    c.drawCircle(o + const Offset(0.8, 1), r, Paint()..color = const Color(0x66000000));
    final brass = _oldEra(s.widget.era) || s.widget.era == '1980';
    c.drawCircle(o, r, Paint()
      ..shader = RadialGradient(
              colors: brass ? const [Color(0xFFF6D98A), Color(0xFF9A6A24)] : const [Color(0xFFE6EBEE), Color(0xFF8C979D)],
              center: const Alignment(-0.4, -0.4))
          .createShader(Rect.fromCircle(center: o, radius: r)));
    c.drawLine(o - Offset(r * 0.6, -r * 0.6), o + Offset(r * 0.6, -r * 0.6), Paint()
      ..color = const Color(0xFF4A5459)
      ..strokeWidth = 1.2);
  }

  /// Borne de carril DIN: cuerpo gris con cara frontal, lateral de color, tornillo y número.
  void _terminal(Canvas c, Offset p, Color col, int n, {required bool left, bool done = false, bool active = false}) {
    final era = s.widget.era;
    final body = Rect.fromCenter(center: p, width: 44, height: 22);
    final rr = RRect.fromRectAndRadius(body, Radius.circular(era == '2020' || era == '2050' ? 6 : 3));
    final (faceTop, faceBot, numCol) = switch (era) {
      '1888' || '1929' => (const Color(0xFFFFFCF2), const Color(0xFFD8CFBC), const Color(0xFF1C2523)), // porcelana
      '1980' => (const Color(0xFF3A3230), const Color(0xFF1E1A18), const Color(0xFFF1EAD6)), // baquelita
      '2005' => (const Color(0xFFFBFBFA), const Color(0xFFE0E4E6), const Color(0xFF1C2523)),
      '2020' => (const Color(0xFFF2F4F3), const Color(0xFFC9CED1), const Color(0xFF3A4146)),
      '2050' => (const Color(0xFFFBFBF7), const Color(0xFFE3E6DE), const Color(0xFF2B2B2B)),
      _ => (const Color(0xFFE9ECEA), const Color(0xFFB9C0C0), const Color(0xFF1C2523)),
    };
    c.drawRRect(rr.shift(const Offset(3, 4)), Paint()..color = const Color(0x66000000));
    c.drawRRect(rr.inflate(1.5), Paint()..color = Hc.line);
    c.drawRRect(rr, Paint()
      ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [faceTop, faceBot])
          .createShader(body));
    // franja de color del circuito
    final band = Rect.fromLTWH(left ? body.left + 3 : body.right - 10, body.top + 3, 7, body.height - 6);
    c.drawRect(band, Paint()..color = col);
    c.drawRect(Rect.fromLTWH(band.left, band.top, band.width, 2), Paint()..color = _sh(col, 1.3));
    // número
    final tp = TextPainter(
      text: TextSpan(text: '${n + 1}', style: TextStyle(fontFamily: Hf.display, fontSize: 15, color: numCol)),
      textDirection: TextDirection.ltr,
    )..layout();
    // número centrado entre la franja y el tornillo
    final numX = left ? body.left + 19 : body.right - 19;
    tp.paint(c, Offset(numX - tp.width / 2, body.center.dy - tp.height / 2));
    // tornillo de apriete en el lado del cable, separado del número
    _screw(c, Offset(left ? body.right - 7 : body.left + 7, body.center.dy), r: 3.6);
    if (done) {
      c.drawCircle(Offset(left ? body.right - 7 : body.left + 7, body.top - 1), 2.2, Paint()..color = const Color(0xFF4FC08D));
    }
    if (active) {
      c.drawRRect(rr.inflate(5), Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Hc.accHi);
    }
  }

  /// Magnetotérmico: caja blanca con palanca (arriba = encendido) y piloto.
  void _breaker(Canvas c, Rect r, bool on, Color led) {
    final rr = RRect.fromRectAndRadius(r, const Radius.circular(2));
    c.drawRRect(rr.shift(const Offset(2, 3)), Paint()..color = const Color(0x55000000));
    c.drawRRect(rr.inflate(1.2), Paint()..color = Hc.line);
    c.drawRRect(rr, Paint()
      ..shader = const LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [Color(0xFFF7F5EE), Color(0xFFD7D3C8)]).createShader(r));
    final slot = Rect.fromCenter(center: r.center, width: r.width * 0.42, height: r.height * 0.5);
    c.drawRect(slot, Paint()..color = const Color(0xFF3B3A44));
    final lever = Rect.fromLTWH(slot.left + 1, on ? slot.top + 1 : slot.center.dy, slot.width - 2, slot.height / 2 - 1);
    c.drawRect(lever, Paint()..color = on ? const Color(0xFF4A8C6A) : const Color(0xFF9AA0A4));
    c.drawRect(Rect.fromLTWH(lever.left, lever.top, lever.width, 1.5), Paint()..color = Colors.white.withValues(alpha: 0.5));
    c.drawCircle(Offset(r.center.dx, r.top + 4), 2, Paint()..color = led);
  }

  /// 1929: caja de madera barnizada, tablero de tablas, tapones de porcelana roscados,
  /// interruptor rotativo de baquelita y tubos de cable negros. Misma luz y volumen que el cuadro actual.
  void _box1929(Canvas canvas, Size size, int n) {
    final box = Offset.zero & size;
    canvas.drawRect(box, Paint()
      ..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF7A4E2C), Color(0xFF4A2C16)]).createShader(box));
    final pl = _WireBoardState.plate(size);
    canvas.drawRRect(RRect.fromRectAndRadius(pl.inflate(4), const Radius.circular(6)), Paint()..color = const Color(0xFF3A2212));
    // tablero de tablas verticales
    canvas.drawRRect(RRect.fromRectAndRadius(pl, const Radius.circular(4)), Paint()..color = const Color(0xFF7A5232));
    for (var x = pl.left; x < pl.right; x += 24) {
      canvas.drawRect(Rect.fromLTWH(x, pl.top, 22, pl.height), Paint()
        ..shader = const LinearGradient(colors: [Color(0xFF86603C), Color(0xFF6E4A2C)]).createShader(Rect.fromLTWH(x, pl.top, 22, pl.height)));
      canvas.drawRect(Rect.fromLTWH(x + 22, pl.top, 2, pl.height), Paint()..color = const Color(0xFF4A3020));
      // vetas
      for (var y = pl.top + 18.0 + (x % 37); y < pl.bottom; y += 41) {
        canvas.drawLine(Offset(x + 4, y), Offset(x + 16, y + 6), Paint()
          ..color = const Color(0x33000000)
          ..strokeWidth = 1);
      }
    }
    canvas.drawRect(Rect.fromLTWH(pl.left, pl.top, pl.width, 10), Paint()
      ..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x88000000), Color(0x00000000)]).createShader(Rect.fromLTWH(pl.left, pl.top, pl.width, 10)));
    for (final o in [const Offset(6, 6), Offset(size.width - 6, 6), Offset(6, size.height - 6), Offset(size.width - 6, size.height - 6)]) {
      _screw(canvas, o, r: 3);
    }
    // --- Regleta de tapones: placa de mármol con un tapón de porcelana por circuito.
    final rail = Rect.fromLTWH(pl.left + 8, pl.top + 10, pl.width - 16, 36);
    final marble = RRect.fromRectAndRadius(rail, const Radius.circular(4));
    canvas.drawRRect(marble.shift(const Offset(2, 3)), Paint()..color = const Color(0x66000000));
    canvas.drawRRect(marble.inflate(1.2), Paint()..color = Hc.line);
    canvas.drawRRect(marble, Paint()
      ..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFF2EEE4), Color(0xFFD2CCBE)]).createShader(rail));
    final cell = math.min(30.0, (rail.width - 40) / (n + 1));
    // interruptor general rotativo de baquelita
    final gc = Offset(rail.left + 20, rail.center.dy);
    canvas.drawCircle(gc + const Offset(1.5, 2.5), 14, Paint()..color = const Color(0x66000000));
    canvas.drawCircle(gc, 14, Paint()..color = Hc.line);
    canvas.drawCircle(gc, 12.5, Paint()
      ..shader = const RadialGradient(center: Alignment(-0.4, -0.4), colors: [Color(0xFF4A3A30), Color(0xFF14100C)]).createShader(Rect.fromCircle(center: gc, radius: 12.5)));
    final ang = s._complete ? -math.pi / 4 : math.pi / 4;
    final hd = Offset(math.cos(ang - math.pi / 2), math.sin(ang - math.pi / 2)) * 9;
    canvas.drawLine(gc - hd, gc + hd, Paint()
      ..color = const Color(0xFF6A5444)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round);
    canvas.drawCircle(gc + hd, 2, Paint()..color = s._complete ? const Color(0xFF4FC08D) : const Color(0xFFB8A890));
    for (var i = 0; i < n; i++) {
      final on = s._ok.contains(i);
      final c0 = Offset(rail.left + 44 + cell * 0.5 + i * (cell + 2), rail.center.dy);
      final r = math.min(12.0, cell * 0.42);
      canvas.drawCircle(c0 + const Offset(1.2, 2), r, Paint()..color = const Color(0x55000000));
      canvas.drawCircle(c0, r + 1.2, Paint()..color = Hc.line);
      canvas.drawCircle(c0, r, Paint()
        ..shader = const RadialGradient(center: Alignment(-0.45, -0.45), colors: [Color(0xFFFFFFFF), Color(0xFFE6E0D2), Color(0xFFB4AC9A)], stops: [0, 0.5, 1])
            .createShader(Rect.fromCircle(center: c0, radius: r)));
      // ventanilla del fusible: se enciende con el color del circuito al conectarlo
      canvas.drawCircle(c0, r * 0.45, Paint()..color = Hc.line);
      canvas.drawCircle(c0, r * 0.36, Paint()..color = on ? s.cols[i] : const Color(0xFF8A7A5A));
      canvas.drawCircle(c0 - Offset(r * 0.12, r * 0.12), r * 0.12, Paint()..color = Colors.white.withValues(alpha: on ? 0.7 : 0.3));
    }
    // --- Tubos de cable negros con abrazaderas de latón.
    final bay = _WireBoardState.bay(size);
    for (final x in [bay.left + 2, bay.right - 14]) {
      final tube = RRect.fromRectAndRadius(Rect.fromLTWH(x, bay.top, 12, bay.height), const Radius.circular(6));
      canvas.drawRRect(tube.shift(const Offset(2, 2)), Paint()..color = const Color(0x55000000));
      canvas.drawRRect(tube, Paint()
        ..shader = const LinearGradient(colors: [Color(0xFF3A342E), Color(0xFF14110E), Color(0xFF2A2520)]).createShader(tube.outerRect));
      for (var y = bay.top + 16; y < bay.bottom - 8; y += 46) {
        canvas.drawRect(Rect.fromLTWH(x - 1, y, 14, 4), Paint()..color = const Color(0xFFC89A48));
        canvas.drawRect(Rect.fromLTWH(x - 1, y, 14, 1.2), Paint()..color = const Color(0xFFF6D98A));
      }
    }
  }

  /// Marco y placa de un cuadro de época: caja con bisel, placa con sombra interior y tornillos.
  Rect _shell(Canvas canvas, Size size, List<Color> frame, Color plate, {double radius = 4}) {
    final box = Offset.zero & size;
    canvas.drawRect(box, Paint()..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: frame).createShader(box));
    final pl = _WireBoardState.plate(size);
    canvas.drawRRect(RRect.fromRectAndRadius(pl.inflate(4), Radius.circular(radius + 2)), Paint()..color = _sh(frame.last, 0.7));
    canvas.drawRRect(RRect.fromRectAndRadius(pl, Radius.circular(radius)), Paint()..color = plate);
    canvas.drawRect(Rect.fromLTWH(pl.left, pl.top, pl.width, 10), Paint()
      ..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x66000000), Color(0x00000000)])
          .createShader(Rect.fromLTWH(pl.left, pl.top, pl.width, 10)));
    for (final o in [const Offset(6, 6), Offset(size.width - 6, 6), Offset(6, size.height - 6), Offset(size.width - 6, size.height - 6)]) {
      _screw(canvas, o, r: 3);
    }
    return pl;
  }

  /// Canaletas laterales ranuradas del color de la época.
  void _ducts(Canvas canvas, Size size, Color body, Color slot) {
    final bay = _WireBoardState.bay(size);
    for (final x in [bay.left + 2, bay.right - 14]) {
      final duct = Rect.fromLTWH(x, bay.top, 12, bay.height);
      canvas.drawRect(duct.shift(const Offset(2, 2)), Paint()..color = const Color(0x55000000));
      canvas.drawRect(duct.inflate(1), Paint()..color = Hc.line);
      canvas.drawRect(duct, Paint()..color = body);
      for (var y = duct.top + 4; y < duct.bottom - 2; y += 7) {
        canvas.drawRect(Rect.fromLTWH(duct.left + 2, y, 8, 3), Paint()..color = slot);
      }
    }
  }

  /// Fila de magnetotérmicos (general + uno por circuito) a partir de [x0].
  void _breakers(Canvas canvas, Rect rail, double x0, int n) {
    final bw = math.min(22.0, (rail.right - x0 - 22) / (n + 1.6));
    _breaker(canvas, Rect.fromLTWH(x0, rail.top, bw * 1.6, rail.height), s._complete, s._complete ? const Color(0xFF4FC08D) : const Color(0xFF6B7076));
    for (var i = 0; i < n; i++) {
      final on = s._ok.contains(i);
      _breaker(canvas, Rect.fromLTWH(x0 + 8 + bw * 1.6 + i * (bw + 3), rail.top, bw, rail.height), on, on ? s.cols[i] : const Color(0xFF6B7076));
    }
  }

  void _text(Canvas c, String t, Offset left, double size, Color col, {bool display = true}) {
    final tp = TextPainter(
      text: TextSpan(text: tr(t), style: TextStyle(fontFamily: display ? Hf.display : Hf.body, fontWeight: display ? FontWeight.w400 : FontWeight.w800, fontSize: size, color: col)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, left - Offset(0, tp.height / 2));
  }

  /// 1980: caja de baquelita crema, tablero de madera, tapones roscados de porcelana y placa de 220 V.
  void _box1980(Canvas canvas, Size size, int n) {
    final pl = _shell(canvas, size, const [Color(0xFFE8DCBC), Color(0xFFBFAF88)], const Color(0xFF5A3B2A), radius: 8);
    final rail = Rect.fromLTWH(pl.left + 8, pl.top + 10, pl.width - 16, 36);
    final rr = RRect.fromRectAndRadius(rail, const Radius.circular(6));
    canvas.drawRRect(rr.shift(const Offset(2, 3)), Paint()..color = const Color(0x66000000));
    canvas.drawRRect(rr.inflate(1.2), Paint()..color = Hc.line);
    canvas.drawRRect(rr, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFF6F1E2), Color(0xFFDDD4BC)]).createShader(rail));
    // interruptor general de palanca negro
    final g = Rect.fromLTWH(rail.left + 8, rail.top + 5, 22, rail.height - 10);
    canvas.drawRRect(RRect.fromRectAndRadius(g.inflate(1.2), const Radius.circular(3)), Paint()..color = Hc.line);
    canvas.drawRRect(RRect.fromRectAndRadius(g, const Radius.circular(3)), Paint()..color = const Color(0xFF2A2422));
    final lever = Rect.fromLTWH(g.left + 6, s._complete ? g.top + 3 : g.center.dy, 10, g.height / 2 - 3);
    canvas.drawRect(lever, Paint()..color = s._complete ? const Color(0xFFC8443A) : const Color(0xFF8A7A6A));
    // tapones roscados: latón con ventanilla del color del circuito al conectarlo
    final cell = math.min(30.0, (rail.width - 80) / n);
    for (var i = 0; i < n; i++) {
      final on = s._ok.contains(i);
      final c0 = Offset(rail.left + 46 + cell * 0.5 + i * cell, rail.center.dy);
      final r = math.min(11.0, cell * 0.4);
      canvas.drawCircle(c0 + const Offset(1.2, 2), r, Paint()..color = const Color(0x55000000));
      canvas.drawCircle(c0, r + 1.2, Paint()..color = Hc.line);
      canvas.drawCircle(c0, r, Paint()
        ..shader = const RadialGradient(center: Alignment(-0.4, -0.4), colors: [Color(0xFFF6D98A), Color(0xFFC9A24A), Color(0xFF7A5A1E)], stops: [0, 0.55, 1])
            .createShader(Rect.fromCircle(center: c0, radius: r)));
      canvas.drawCircle(c0, r * 0.45, Paint()..color = Hc.line);
      canvas.drawCircle(c0, r * 0.36, Paint()..color = on ? s.cols[i] : const Color(0xFF6A5A3A));
    }
    // placa de tensión
    final tag = Rect.fromLTWH(rail.right - 42, rail.top + 9, 36, rail.height - 18);
    if (rail.left + 46 + n * cell < tag.left - 4) {
      canvas.drawRRect(RRect.fromRectAndRadius(tag.inflate(1), const Radius.circular(2)), Paint()..color = Hc.line);
      canvas.drawRRect(RRect.fromRectAndRadius(tag, const Radius.circular(2)), Paint()..color = const Color(0xFFC9A24A));
      _text(canvas, '220 V', Offset(tag.left + 4, tag.center.dy), 12, const Color(0xFF3A2A10));
    }
    _ducts(canvas, size, const Color(0xFF6E6A62), const Color(0xFF4A4640));
  }

  /// 2005: caja de PVC blanca, carril DIN con magnetotérmicos y canaletas blancas.
  void _box2005(Canvas canvas, Size size, int n) {
    final pl = _shell(canvas, size, const [Color(0xFFFAFBFB), Color(0xFFD5DADD)], const Color(0xFFB4BEC4), radius: 6);
    final rail = Rect.fromLTWH(pl.left + 8, pl.top + 12, pl.width - 16, 32);
    canvas.drawRect(Rect.fromLTWH(rail.left, rail.center.dy - 4, rail.width, 8), Paint()..color = const Color(0xFF8C979D));
    canvas.drawRect(Rect.fromLTWH(rail.left, rail.center.dy - 4, rail.width, 1.5), Paint()..color = const Color(0xFFE6EBEE));
    _breakers(canvas, rail, rail.left + 6, n);
    _ducts(canvas, size, const Color(0xFFEEF1F2), const Color(0xFFB4BEC4));
  }

  /// 2020: caja antracita con contador inteligente (consumo en kW y wifi) y magnetotérmicos.
  void _box2020(Canvas canvas, Size size, int n) {
    final pl = _shell(canvas, size, const [Color(0xFF4A5358), Color(0xFF2E3438)], const Color(0xFF161C20), radius: 8);
    final rail = Rect.fromLTWH(pl.left + 8, pl.top + 12, pl.width - 16, 32);
    final scr = Rect.fromLTWH(rail.left + 2, rail.top, 78, rail.height);
    canvas.drawRRect(RRect.fromRectAndRadius(scr.inflate(1.5), const Radius.circular(6)), Paint()..color = Hc.line);
    canvas.drawRRect(RRect.fromRectAndRadius(scr, const Radius.circular(6)), Paint()..color = const Color(0xFF0B1A14));
    canvas.drawRRect(RRect.fromRectAndRadius(scr, const Radius.circular(6)), Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFF4FC08D));
    final kw = 0.4 + 3.0 * s._ok.length / n;
    _text(canvas, '${kw.toStringAsFixed(1).replaceAll('.', I18n.puntoMiles ? ',' : '.')} kW', Offset(scr.left + 7, scr.center.dy + 1), 15, const Color(0xFF4FC08D));
    final wc = Offset(scr.right - 12, scr.center.dy + 6);
    for (final r in [5.0, 9.0]) {
      canvas.drawArc(Rect.fromCircle(center: wc, radius: r), -math.pi * 0.8, math.pi * 0.6, false, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF4FC08D));
    }
    canvas.drawCircle(wc, 1.6, Paint()..color = const Color(0xFF4FC08D));
    canvas.drawRect(Rect.fromLTWH(scr.right + 8, rail.center.dy - 4, rail.right - scr.right - 8, 8), Paint()..color = const Color(0xFF5D6B72));
    _breakers(canvas, rail, scr.right + 12, n);
    _ducts(canvas, size, const Color(0xFF2A3034), const Color(0xFF3E474C));
  }

  /// 2050: cuadro de la instalación solar con batería (se carga al conectar) y magnetotérmicos.
  void _box2050(Canvas canvas, Size size, int n) {
    final pl = _shell(canvas, size, const [Color(0xFFF7F8F4), Color(0xFFD3D9CE)], const Color(0xFF9FAE9C), radius: 8);
    final rail = Rect.fromLTWH(pl.left + 8, pl.top + 12, pl.width - 16, 32);
    final bat = Rect.fromLTWH(rail.left + 2, rail.top, 100, rail.height);
    canvas.drawRRect(RRect.fromRectAndRadius(bat.inflate(1.5), const Radius.circular(6)), Paint()..color = Hc.line);
    canvas.drawRRect(RRect.fromRectAndRadius(bat, const Radius.circular(6)), Paint()..color = const Color(0xFFF7F8F4));
    final cell = Rect.fromLTWH(bat.left + 7, bat.center.dy - 6, 24, 12);
    final pct = (40 + 60 * s._ok.length / n).round();
    canvas.drawRRect(RRect.fromRectAndRadius(cell, const Radius.circular(2)), Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = const Color(0xFF2B2B2B));
    canvas.drawRect(Rect.fromLTWH(cell.right, cell.center.dy - 2.5, 2.5, 5), Paint()..color = const Color(0xFF2B2B2B));
    canvas.drawRect(Rect.fromLTWH(cell.left + 2, cell.top + 2, (cell.width - 4) * pct / 100, cell.height - 4), Paint()..color = const Color(0xFF4E8A5E));
    _text(canvas, '$pct %', Offset(cell.right + 9, bat.center.dy + 1), 15, const Color(0xFF2B2B2B));
    canvas.drawRect(Rect.fromLTWH(bat.right + 8, rail.center.dy - 4, rail.right - bat.right - 8, 8), Paint()..color = const Color(0xFF7D8A7A));
    _breakers(canvas, rail, bat.right + 12, n);
    _ducts(canvas, size, const Color(0xFFE6EAE2), const Color(0xFFB4BEAE));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final n = s._n;
    if (_oldEra(s.widget.era)) {
      _box1929(canvas, size, n);
    } else if (s.widget.era == '1980') {
      _box1980(canvas, size, n);
    } else if (s.widget.era == '2005') {
      _box2005(canvas, size, n);
    } else if (s.widget.era == '2020') {
      _box2020(canvas, size, n);
    } else if (s.widget.era == '2050') {
      _box2050(canvas, size, n);
    } else {
      // --- Caja metálica del cuadro (puerta abierta): marco con bisel y fondo de placa perforada.
      final box = Offset.zero & size;
      canvas.drawRect(box, Paint()
        ..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFB9C4C9), Color(0xFF7D8A90)]).createShader(box));
      final pl = _WireBoardState.plate(size);
      canvas.drawRRect(RRect.fromRectAndRadius(pl.inflate(4), const Radius.circular(6)), Paint()..color = const Color(0xFF5D6B72));
      canvas.drawRRect(RRect.fromRectAndRadius(pl, const Radius.circular(4)), Paint()..color = const Color(0xFF2B3A40));
      // sombra interior del marco (profundidad de la caja)
      canvas.drawRect(Rect.fromLTWH(pl.left, pl.top, pl.width, 10), Paint()
        ..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x88000000), Color(0x00000000)]).createShader(Rect.fromLTWH(pl.left, pl.top, pl.width, 10)));
      canvas.drawRect(Rect.fromLTWH(pl.left, pl.top, 8, pl.height), Paint()
        ..shader = const LinearGradient(colors: [Color(0x66000000), Color(0x00000000)]).createShader(Rect.fromLTWH(pl.left, pl.top, 8, pl.height)));
      // perforaciones de la placa
      final hole = Paint()..color = const Color(0xFF223036);
      for (var y = pl.top + 60; y < pl.bottom - 8; y += 12) {
        for (var x = pl.left + 70; x < pl.right - 70; x += 12) {
          canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, 6, 2.5), const Radius.circular(1)), hole);
        }
      }
      for (final o in [Offset(6, 6), Offset(size.width - 6, 6), Offset(6, size.height - 6), Offset(size.width - 6, size.height - 6)]) {
        _screw(canvas, o, r: 3);
      }
      // --- Fila de magnetotérmicos en su carril DIN.
      final rail = Rect.fromLTWH(pl.left + 8, pl.top + 12, pl.width - 16, 32);
      canvas.drawRect(Rect.fromLTWH(rail.left, rail.center.dy - 4, rail.width, 8), Paint()..color = const Color(0xFFA3AAB0));
      canvas.drawRect(Rect.fromLTWH(rail.left, rail.center.dy - 4, rail.width, 1.5), Paint()..color = const Color(0xFFDFE3E6));
      final bw = math.min(22.0, (rail.width - 30) / (n + 1));
      // general (más ancho) + uno por circuito, con el piloto de su color al conectar
      _breaker(canvas, Rect.fromLTWH(rail.left + 6, rail.top, bw * 1.6, rail.height), s._complete, s._complete ? const Color(0xFF4FC08D) : const Color(0xFF6B7076));
      for (var i = 0; i < n; i++) {
        final on = s._ok.contains(i);
        _breaker(canvas, Rect.fromLTWH(rail.left + 14 + bw * 1.6 + i * (bw + 3), rail.top, bw, rail.height), on,
            on ? s.cols[i] : const Color(0xFF6B7076));
      }
      // --- Canaletas laterales ranuradas.
      final bay = _WireBoardState.bay(size);
      for (final x in [bay.left + 2, bay.right - 14]) {
        final duct = Rect.fromLTWH(x, bay.top, 12, bay.height);
        canvas.drawRect(duct.shift(const Offset(2, 2)), Paint()..color = const Color(0x55000000));
        canvas.drawRect(duct, Paint()..color = const Color(0xFF8E9AA0));
        for (var y = duct.top + 4; y < duct.bottom - 2; y += 7) {
          canvas.drawRect(Rect.fromLTWH(duct.left + 2, y, 8, 3), Paint()..color = const Color(0xFF5D6B72));
        }
      }
    }
    // --- Cables conectados (y la corriente que recorre el último).
    for (var i = 0; i < n; i++) {
      final ci = s._l[i];
      if (!s._ok.contains(ci)) continue;
      final j = s._r.indexOf(ci);
      final pts = _curve(s.term(size, 0, i), s.term(size, 1, j), 24);
      final col = s.cols[ci];
      _cable(canvas, pts, col, live: true);
      if (s._flow == ci && t < 1) {
        // pulso de corriente: un punto brillante con estela que recorre el cable
        for (var k = 0; k < 5; k++) {
          final u = (t - k * 0.04).clamp(0.0, 1.0);
          final q = pts[(u * (pts.length - 1)).round()];
          canvas.drawCircle(q, 4.0 - k * 0.6, Paint()..color = Color.lerp(Colors.white, col, k / 5)!.withValues(alpha: 1 - k * 0.18));
        }
      }
    }
    // --- Rabos de cable sueltos y cable que se arrastra.
    for (final side in [0, 1]) {
      for (var i = 0; i < n; i++) {
        final ci = s._color(side, i);
        if (s._ok.contains(ci)) continue;
        if (s._fromSide == side && s._fromSlot == i) continue;
        final p = s.term(size, side, i);
        final dx = side == 0 ? 24.0 : -24.0;
        _cable(canvas, _curve(p, p + Offset(dx, 16), 3), s.cols[ci]);
        final tip = p + Offset(dx, 16);
        canvas.drawRect(Rect.fromCenter(center: tip, width: 5, height: 4), Paint()..color = const Color(0xFFF0B986));
      }
    }
    if (s._fromSide != null && s._cur != null) {
      final a = s.term(size, s._fromSide!, s._fromSlot!);
      final col = s.cols[s._color(s._fromSide!, s._fromSlot!)];
      _cable(canvas, _curve(a, s._cur!, 26), col);
      canvas.drawRect(Rect.fromCenter(center: s._cur!, width: 6, height: 5), Paint()..color = const Color(0xFFF0B986));
    }
    // --- Bornes.
    for (final side in [0, 1]) {
      for (var i = 0; i < n; i++) {
        final ci = s._color(side, i);
        _terminal(canvas, s.term(size, side, i), s.cols[ci], ci,
            left: side == 0, done: s._ok.contains(ci), active: (s._fromSide == side && s._fromSlot == i) || (s._fromSide == null && ci == s._nextNum && !s._complete));
      }
    }
    // --- Chispas: al acertar, unas pocas; al fallar, chispazo con destello, chispas que caen y humo.
    final sp = s._spark;
    if (sp != null && t < 1) {
      final r = math.Random(sp.seed);
      final count = sp.big ? 22 : 8;
      for (var k = 0; k < count; k++) {
        final ang = -math.pi / 2 + (r.nextDouble() - 0.5) * math.pi * 1.8;
        final v = (sp.big ? 70 : 35) + r.nextDouble() * (sp.big ? 90 : 40);
        final p0 = sp.at + Offset(math.cos(ang) * v * t, math.sin(ang) * v * t + 160 * t * t);
        final p1 = sp.at + Offset(math.cos(ang) * v * (t - 0.06), math.sin(ang) * v * (t - 0.06) + 160 * (t - 0.06) * (t - 0.06));
        final col = Color.lerp(const Color(0xFFFFF7C2), const Color(0xFFFF9A2E), t + r.nextDouble() * 0.3)!.withValues(alpha: (1 - t).clamp(0.0, 1.0));
        canvas.drawLine(p1, p0, Paint()
          ..color = col
          ..strokeWidth = sp.big ? 2.2 : 1.6
          ..strokeCap = StrokeCap.round);
      }
      final flash = (1 - t * 3).clamp(0.0, 1.0);
      if (flash > 0) {
        canvas.drawCircle(sp.at, (sp.big ? 22 : 10) * (0.6 + t), Paint()..color = const Color(0xFFFFF7C2).withValues(alpha: 0.85 * flash));
        // rayo en zigzag
        if (sp.big) {
          final bolt = Path()..moveTo(sp.at.dx - 18, sp.at.dy - 14);
          for (var k = 1; k <= 6; k++) {
            bolt.lineTo(sp.at.dx - 18 + k * 6, sp.at.dy - 14 + k * 4 + (k.isEven ? -6 : 6));
          }
          canvas.drawPath(bolt, Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..color = Colors.white.withValues(alpha: flash));
        }
      }
      if (sp.big) {
        // humo que sube y se disipa
        for (var k = 0; k < 4; k++) {
          final q = sp.at + Offset((k - 1.5) * 7 + math.sin(t * 6 + k) * 3, -14 - 40 * t - k * 4);
          canvas.drawCircle(q, 6 + 10 * t, Paint()..color = const Color(0xFF5D6B72).withValues(alpha: 0.35 * (1 - t)));
        }
        canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFFFF2A8).withValues(alpha: 0.22 * flash));
      }
    }
  }

  @override
  bool shouldRepaint(_WirePainter o) => true;
}

// =====================================================================
// Carpintería: tocar alternando dos puntos, cada vez más deprisa.
// =====================================================================
class JointBoard extends StatefulWidget {
  final double progress;
  final WorkFn onWork;
  const JointBoard({super.key, required this.progress, required this.onWork});
  @override
  State<JointBoard> createState() => _JointBoardState();
}

class _JointBoardState extends State<JointBoard> {
  int _next = 0; // 0 izquierda, 1 derecha
  int _hits = 0;

  void _tap(Offset q, Size size) {
    final side = q.dx < size.width / 2 ? 0 : 1;
    if (side != _next) {
      HapticFeedback.lightImpact();
      return;
    }
    if (!widget.onWork(q)) return;
    Sfx.play(_hits % 4 == 3 ? 'martillo' : 'sierra', gain: 0.8);
    setState(() {
      _next = 1 - _next;
      _hits++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final size = Size(c.maxWidth, c.maxHeight);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => _tap(d.localPosition, size),
        child: CustomPaint(size: size, painter: _JointPainter(_next, _hits, widget.progress)),
      );
    });
  }
}

class _JointPainter extends CustomPainter {
  final int next;
  final int hits;
  final double p;
  _JointPainter(this.next, this.hits, this.p);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF1B3433));
    // tablón
    final plank = Rect.fromLTWH(14, size.height * 0.38, size.width - 28, size.height * 0.24);
    canvas.drawRRect(RRect.fromRectAndRadius(plank.inflate(2), const Radius.circular(6)), Paint()..color = Hc.line);
    canvas.drawRRect(RRect.fromRectAndRadius(plank, const Radius.circular(5)), Paint()..color = const Color(0xFFB98A5A));
    final grain = Paint()
      ..color = const Color(0xFF8E6440)
      ..strokeWidth = 1.5;
    for (var i = 1; i < 5; i++) {
      final y = plank.top + plank.height * i / 5;
      canvas.drawLine(Offset(plank.left + 10, y), Offset(plank.right - 10, y + (i.isEven ? 3 : -3)), grain);
    }
    // corte avanzando
    final cutX = plank.left + plank.width * p;
    canvas.drawLine(Offset(cutX, plank.top - 6), Offset(cutX, plank.bottom + 6), Paint()
      ..color = Hc.ink
      ..strokeWidth = 2);
    // dos puntos
    for (var s = 0; s < 2; s++) {
      final c = Offset(s == 0 ? size.width * 0.25 : size.width * 0.75, size.height * 0.5);
      final on = s == next;
      canvas.drawCircle(c, 34, Paint()..color = on ? Hc.acc.withValues(alpha: 0.18) : Colors.transparent);
      canvas.drawCircle(c, 26, Paint()..color = Hc.line);
      canvas.drawCircle(c, 22, Paint()..color = on ? Hc.acc : const Color(0xFF5D7D76));
      final tp = TextPainter(
        text: TextSpan(text: s == 0 ? 'I' : 'D', style: TextStyle(fontFamily: Hf.display, fontSize: 26, color: on ? Hc.onAcc : Hc.ink)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    }
    // clavos
    for (var i = 0; i < math.min(12, hits ~/ 3); i++) {
      final x = plank.left + 16 + (plank.width - 32) * (i / 11);
      canvas.drawCircle(Offset(x, plank.top + 6), 2.5, Paint()..color = const Color(0xFF8FB0A8));
      canvas.drawCircle(Offset(x, plank.bottom - 6), 2.5, Paint()..color = const Color(0xFF8FB0A8));
    }
  }

  @override
  bool shouldRepaint(_JointPainter o) => true;
}

// =====================================================================
// Decoración por capas: imprimación, 1ª y 2ª capa (y acabado en niveles altos),
// después los recortes de esquinas y rodapié. Hay que cubrir toda la pared.
// =====================================================================
class PaintBoard extends StatefulWidget {
  final double progress;
  /// Informa de la fracción de la fase ya pintada; false si no hay energía.
  final bool Function(double frac) onPaint;
  final Color color;
  /// Paredes a pintar (según los m²).
  final int walls;
  /// Capas: 3 (imprimación, 1ª, 2ª) o 4 con acabado.
  final int coats;
  /// Radio del rodillo en píxeles (crece con la herramienta).
  final double brush;
  const PaintBoard({
    super.key,
    required this.progress,
    required this.onPaint,
    required this.color,
    this.walls = 1,
    this.coats = 3,
    this.brush = 16,
  });
  @override
  State<PaintBoard> createState() => _PaintBoardState();
}

class _Stage {
  final int wall;
  /// Capa (0 imprimación…), o -1 para los recortes.
  final int coat;
  const _Stage(this.wall, this.coat);
}

class _PaintBoardState extends State<PaintBoard> with SingleTickerProviderStateMixin {
  static const cols = 14, rows = 10, need = 0.9, spotTime = 0.3;
  static const spotsAt = [Offset(0.07, 0.09), Offset(0.5, 0.08), Offset(0.93, 0.09), Offset(0.07, 0.9), Offset(0.5, 0.9), Offset(0.93, 0.9)];
  static const coatNames = ['Imprimación', '1ª capa', '2ª capa', 'Acabado'];
  static const primer = Color(0xFFEDE9DF);

  late List<_Stage> _stages;
  int _k = 0;
  final List<bool> _cells = List.filled(cols * rows, false);
  int _covered = 0;
  final List<double> _spots = List.filled(6, 0);
  final List<int> _pending = [];
  Offset? _pos;
  bool _down = false;
  Timer? _hold;
  int _lastFlush = 0, _lastSnd = 0;
  String? _banner;
  final _rng = math.Random();
  late final AnimationController _fx = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void initState() {
    super.initState();
    _build();
    _syncTo(widget.progress);
  }

  void _build() {
    _stages = [
      for (var w = 0; w < widget.walls; w++) ...[
        for (var c = 0; c < widget.coats; c++) _Stage(w, c),
        _Stage(w, -1),
      ],
    ];
  }

  @override
  void didUpdateWidget(PaintBoard old) {
    super.didUpdateWidget(old);
    if (old.walls != widget.walls || old.coats != widget.coats) {
      _build();
      _k = 0;
      _reset();
      _syncTo(widget.progress);
    } else if (widget.progress > _frac() + 0.01) {
      // El motor va por delante (golpe crítico, cuadrillas): la pared se pone al día.
      _syncTo(widget.progress);
    }
  }

  @override
  void dispose() {
    _hold?.cancel();
    _fx.dispose();
    super.dispose();
  }

  double _w(_Stage s) => s.coat < 0 ? 0.6 : 1.0;
  double get _total => _stages.fold(0.0, (a, s) => a + _w(s));
  double _startOf(int k) {
    var d = 0.0;
    for (var i = 0; i < k; i++) {
      d += _w(_stages[i]);
    }
    return d / _total;
  }

  double _part() {
    if (_k >= _stages.length) return 1;
    final s = _stages[_k];
    if (s.coat < 0) return _spots.where((x) => x >= spotTime).length / _spots.length;
    return math.min(1.0, _covered / (cols * rows * need));
  }

  double _frac() {
    if (_k >= _stages.length) return 1;
    return (_startOf(_k) + _part() * _w(_stages[_k]) / _total).clamp(0.0, 1.0);
  }

  void _reset() {
    _cells.fillRange(0, _cells.length, false);
    _covered = 0;
    _spots.fillRange(0, 6, 0);
    _pending.clear();
  }

  void _advance({bool silent = false}) {
    final s = _stages[_k];
    _k++;
    _reset();
    if (_k >= _stages.length && !silent) {
      // Pared terminada: se asegura la fase entera en el motor (sin redondeos que la dejen a medias).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.progress < 1) widget.onPaint(1.0);
      });
    }
    if (silent) return;
    _banner = s.coat < 0 ? 'Recortes ✓' : '${coatNames[s.coat]} ✓';
    if (_k < _stages.length && _stages[_k].wall != s.wall) _banner = 'Pared ${s.wall + 1} lista';
    Sfx.play('confirmar');
    HapticFeedback.mediumImpact();
    _fx.forward(from: 0);
  }

  void _syncTo(double p) {
    while (_k < _stages.length) {
      if (p >= _startOf(_k + 1) - 1e-6) {
        _advance(silent: true);
        continue;
      }
      final s = _stages[_k];
      final part = ((p - _startOf(_k)) / (_w(s) / _total)).clamp(0.0, 1.0);
      if (s.coat < 0) {
        final n = (part * 6).floor();
        for (var i = 0; i < n; i++) {
          _spots[i] = spotTime;
        }
      } else {
        final target = (part * cols * rows * need).ceil();
        final free = [for (var i = 0; i < _cells.length; i++) if (!_cells[i]) i]..shuffle(_rng);
        for (final i in free) {
          if (_covered >= target) break;
          _cells[i] = true;
          _covered++;
        }
      }
      break;
    }
  }

  /// La pared ocupa todo el tablero salvo el rodapié (vista en primer plano, como antes).
  static Rect wallRect(Size s) => Rect.fromLTWH(0, 0, s.width, s.height - 14);
  Rect _wall(Size s) => wallRect(s);

  void _brush(Offset q, Offset? prev, Size size) {
    if (_k >= _stages.length) return;
    final s = _stages[_k];
    if (s.coat < 0) return;
    final b = _wall(size);
    final cw = b.width / cols, ch = b.height / rows;
    final r = widget.brush;
    final pts = <Offset>[q];
    if (prev != null) {
      final d = (q - prev).distance;
      final steps = (d / (r * 0.5)).ceil();
      for (var i = 1; i < steps; i++) {
        pts.add(Offset.lerp(prev, q, i / steps)!);
      }
    }
    for (final pt in pts) {
      final c0 = ((pt.dx - r - b.left) / cw).floor(), c1 = ((pt.dx + r - b.left) / cw).floor();
      final r0 = ((pt.dy - r - b.top) / ch).floor(), r1 = ((pt.dy + r - b.top) / ch).floor();
      for (var y = math.max(0, r0); y <= math.min(rows - 1, r1); y++) {
        for (var x = math.max(0, c0); x <= math.min(cols - 1, c1); x++) {
          final i = y * cols + x;
          if (_cells[i]) continue;
          final cc = Offset(b.left + (x + 0.5) * cw, b.top + (y + 0.5) * ch);
          if ((cc - pt).distance <= r + math.min(cw, ch) * 0.35) {
            _cells[i] = true;
            _covered++;
            _pending.add(i);
          }
        }
      }
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastFlush > 120) _flush();
  }

  void _flush() {
    _lastFlush = DateTime.now().millisecondsSinceEpoch;
    if (_pending.isEmpty) return;
    final f = _frac();
    if (widget.onPaint(f)) {
      _pending.clear();
      if (_lastFlush - _lastSnd > 320) {
        _lastSnd = _lastFlush;
        Sfx.play('rodillo', gain: 0.6);
      }
      if (_part() >= 1) _advance();
    } else {
      for (final i in _pending) {
        _cells[i] = false;
      }
      _covered -= _pending.length;
      _pending.clear();
      _down = false;
      _hold?.cancel();
    }
  }

  void _spotTick(Size size) {
    if (!_down || _pos == null || _k >= _stages.length) return;
    final s = _stages[_k];
    if (s.coat >= 0) return;
    final b = _wall(size);
    for (var i = 0; i < 6; i++) {
      if (_spots[i] >= spotTime) continue;
      final c = Offset(b.left + spotsAt[i].dx * b.width, b.top + spotsAt[i].dy * b.height);
      if ((c - _pos!).distance > 36) continue;
      setState(() => _spots[i] += 0.05);
      if (_spots[i] >= spotTime) {
        if (!widget.onPaint(_frac())) {
          setState(() => _spots[i] = spotTime - 0.05);
          _down = false;
          return;
        }
        Sfx.play('rodillo', gain: 0.5);
        HapticFeedback.selectionClick();
        if (_part() >= 1) setState(_advance);
      }
      break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_k >= _stages.length && widget.progress < 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.progress < 1) widget.onPaint(1.0);
      });
    }
    return LayoutBuilder(builder: (context, c) {
      final size = Size(c.maxWidth, c.maxHeight);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanDown: (d) {
          _down = true;
          _pos = d.localPosition;
          _brush(d.localPosition, null, size);
          _hold?.cancel();
          _hold = Timer.periodic(const Duration(milliseconds: 50), (_) => _spotTick(size));
          setState(() {});
        },
        onPanUpdate: (d) {
          if (!_down) return;
          final prev = _pos;
          _pos = d.localPosition;
          setState(() => _brush(d.localPosition, prev, size));
        },
        onPanEnd: (_) => setState(() {
          _flush();
          _down = false;
          _hold?.cancel();
        }),
        onPanCancel: () => setState(() {
          _flush();
          _down = false;
          _hold?.cancel();
        }),
        child: AnimatedBuilder(
          animation: _fx,
          builder: (context, _) => CustomPaint(size: size, painter: _PaintPainter(this, _fx.value)),
        ),
      );
    });
  }
}

class _PaintPainter extends CustomPainter {
  final _PaintBoardState s;
  final double t;
  _PaintPainter(this.s, this.t);

  Color _layer(int coat) {
    final c = s.widget.color;
    return switch (coat) {
      0 => _PaintBoardState.primer,
      1 => Color.lerp(_PaintBoardState.primer, c, 0.7)!,
      2 => c,
      _ => _sh(c, 1.04),
    };
  }

  @override
  void paint(Canvas canvas, Size size) {
    final done = s._k >= s._stages.length;
    final st = done ? s._stages.last : s._stages[s._k];
    final coats = s.widget.coats;
    // Lo que hay debajo de la capa actual.
    final coat = st.coat < 0 ? coats : st.coat;
    final base = coat == 0 ? const Color(0xFF8C8370) : _layer(coat - 1);
    final b = _PaintBoardState.wallRect(size);
    canvas.drawRect(Offset.zero & size, Paint()..color = base);
    if (coat == 0) {
      final stain = Paint()..color = const Color(0xFF6F6756);
      final r = math.Random(3 + st.wall);
      for (var i = 0; i < 12; i++) {
        canvas.drawCircle(Offset(b.left + r.nextDouble() * b.width, b.top + r.nextDouble() * b.height), 5 + r.nextDouble() * 14, stain);
      }
      // Desconchados.
      for (var i = 0; i < 5; i++) {
        final q = Offset(b.left + r.nextDouble() * b.width, b.top + r.nextDouble() * b.height);
        canvas.drawRect(Rect.fromCenter(center: q, width: 10, height: 6), Paint()..color = const Color(0xFFA79F8A));
      }
    }
    final cw = b.width / _PaintBoardState.cols, ch = b.height / _PaintBoardState.rows;
    if (st.coat >= 0 && !done) {
      final lc = _layer(st.coat);
      final p = Paint()..color = lc;
      for (var y = 0; y < _PaintBoardState.rows; y++) {
        for (var x = 0; x < _PaintBoardState.cols; x++) {
          if (!s._cells[y * _PaintBoardState.cols + x]) continue;
          // Primera capa algo irregular; las demás, lisas.
          if (st.coat == 1) p.color = (x + y).isEven ? lc : _sh(lc, 0.96);
          canvas.drawRect(Rect.fromLTWH(b.left + x * cw - 0.5, b.top + y * ch - 0.5, cw + 1, ch + 1), p);
        }
      }
      // Cinta de carrocero en el techo.
      canvas.drawRect(Rect.fromLTWH(b.left, b.top, b.width, 4), Paint()..color = const Color(0xFF5AA6D6));
    }
    if (done || st.coat < 0) {
      // Pared terminada (con brillo si lleva acabado).
      if (coats >= 4) {
        final r = Rect.fromLTWH(b.left, b.top, b.width, b.height * 0.45);
        canvas.drawRect(
            r,
            Paint()
              ..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0x00FFFFFF), Color(0x22FFFFFF), Color(0x00FFFFFF)])
                  .createShader(r));
      }
    }
    if (st.coat < 0 && !done) {
      for (var i = 0; i < 6; i++) {
        final c = Offset(b.left + _PaintBoardState.spotsAt[i].dx * b.width, b.top + _PaintBoardState.spotsAt[i].dy * b.height);
        final v = s._spots[i] / _PaintBoardState.spotTime;
        if (v >= 1) continue;
        canvas.drawOval(Rect.fromCenter(center: c, width: 26, height: 18), Paint()..color = _PaintBoardState.primer);
        canvas.drawOval(Rect.fromCenter(center: c, width: 26 * v, height: 18 * v), Paint()..color = _layer(coats - 1));
        canvas.drawCircle(c, 17 + 2 * math.sin(DateTime.now().millisecondsSinceEpoch / 160), Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Hc.acc);
        if (v > 0) {
          canvas.drawArc(Rect.fromCircle(center: c, radius: 21), -math.pi / 2, math.pi * 2 * v, false, Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = Hc.ok);
        }
      }
    }
    // Rodapié (como en la versión original).
    canvas.drawRect(Rect.fromLTWH(0, size.height - 14, size.width, 14), Paint()..color = const Color(0xFFECE4D0));
    canvas.drawLine(Offset(0, size.height - 14), Offset(size.width, size.height - 14), Paint()
      ..color = Hc.line
      ..strokeWidth = 2);
    // Etiqueta de la etapa.
    if (!done) {
      final name = st.coat < 0 ? 'Recortes' : _PaintBoardState.coatNames[st.coat];
      final wall = s.widget.walls > 1 ? 'Pared ${st.wall + 1}/${s.widget.walls} · ' : '';
      final how = st.coat < 0 ? ' · mantén pulsado cada círculo' : '';
      _label(canvas, '$wall$name ${(s._part() * 100).floor()}%$how', Offset(b.left + 6, b.center.dy - 8));
    }
    // Rodillo bajo el dedo.
    if (s._down && s._pos != null && !done) {
      final q = s._pos!;
      final r = s.widget.brush;
      final lc = st.coat < 0 ? _layer(coats - 1) : _layer(st.coat);
      canvas.drawLine(q + Offset(r * 0.6, 4), q + Offset(r * 0.6 + 8, 30), Paint()
        ..color = Hc.line
        ..strokeWidth = 3);
      canvas.drawRect(Rect.fromLTWH(q.dx + r * 0.6 + 4, q.dy + 26, 8, 16), Paint()..color = const Color(0xFFD9785B));
      final roll = Rect.fromCenter(center: q, width: r * 1.6, height: 9);
      _block(canvas, roll, lc, d: 3, radius: 4);
    }
    // Aviso al terminar una capa.
    if (s._banner != null && t > 0 && t < 1) {
      final a = t < 0.8 ? 1.0 : (1 - t) / 0.2;
      _label(canvas, s._banner!, b.center - Offset(0, 10 * t), bg: Hc.ok.withValues(alpha: 0.92 * a), fg: const Color(0xFF0E2A20).withValues(alpha: a), size: 15, center: true);
    }
  }

  @override
  bool shouldRepaint(_PaintPainter o) => true;
}

/// Punto crítico brillante: tocarlo en menos de 1,2 s vale ×10.
class CritSpot extends StatefulWidget {
  final VoidCallback onHit;
  final VoidCallback onMiss;
  const CritSpot({super.key, required this.onHit, required this.onMiss});
  @override
  State<CritSpot> createState() => _CritSpotState();
}

class _CritSpotState extends State<CritSpot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
    ..forward().whenComplete(() {
      if (!_hit) widget.onMiss();
    });
  bool _hit = false;
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        if (_hit) return;
        _hit = true;
        HapticFeedback.heavyImpact();
        Sfx.play('combo');
        widget.onHit();
      },
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          final pulse = 1 + 0.15 * math.sin(t * math.pi * 8);
          return SizedBox(
            width: 64,
            height: 64,
            child: Stack(alignment: Alignment.center, children: [
              Container(
                width: 56 * pulse,
                height: 56 * pulse,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Hc.crit.withValues(alpha: 0.6 * (1 - t)), blurRadius: 24, spreadRadius: 4)],
                ),
              ),
              CustomPaint(size: const Size(56, 56), painter: _StarPainter(1 - t)),
              Positioned.fill(
                child: CircularProgressIndicator(value: 1 - t, strokeWidth: 3, color: Hc.crit.withValues(alpha: 0.8)),
              ),
            ]),
          );
        },
      ),
    );
  }
}

class _StarPainter extends CustomPainter {
  final double a;
  _StarPainter(this.a);
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final r = i.isEven ? size.width * 0.42 : size.width * 0.14;
      final ang = i * math.pi / 4 - math.pi / 2;
      final q = c + Offset(math.cos(ang) * r, math.sin(ang) * r);
      if (i == 0) {
        path.moveTo(q.dx, q.dy);
      } else {
        path.lineTo(q.dx, q.dy);
      }
    }
    path.close();
    canvas.drawPath(path.shift(const Offset(0, 3)), Paint()..color = Hc.line);
    canvas.drawPath(path, Paint()..color = Hc.crit.withValues(alpha: 0.5 + 0.5 * a));
    canvas.drawCircle(c - const Offset(0, 2), 5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_StarPainter o) => o.a != a;
}
