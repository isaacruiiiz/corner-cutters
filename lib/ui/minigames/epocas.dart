import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';

// =====================================================================
// DLC de épocas · escena del minijuego (propuesta C): la pared de la época
// alrededor del tablero y una balda con objetos de la época y la
// herramienta del oficio. Solo decorado: no cambia la mecánica.
// =====================================================================

/// Épocas con escena propia alrededor del tablero (1888 y 1929 llevan su estilo dentro del tablero).
bool eraScene(String? era) => era == '1980' || era == '2005' || era == '2020' || era == '2050';

/// Alto de la balda de objetos bajo el tablero.
const double kEraShelf = 50;

Color _sh(Color c, double f) =>
    f < 1 ? Color.lerp(c, const Color(0xFF000000), 1 - f)! : Color.lerp(c, const Color(0xFFFFFFFF), (f - 1).clamp(0.0, 1.0))!;

Paint _f(Color c) => Paint()..color = c;
Paint _s(Color c, double w) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

/// Rectángulo con contorno, sombra y brillo (mismo volumen que el resto del juego).
void _rr(Canvas c, Rect r, Color col, {double rad = 3, bool shadow = true}) {
  final rr = RRect.fromRectAndRadius(r, Radius.circular(rad));
  if (shadow) c.drawRRect(rr.shift(const Offset(2, 3)), _f(const Color(0x55000000)));
  c.drawRRect(rr.inflate(1.2), _f(Hc.line));
  c.drawRRect(rr, Paint()
    ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_sh(col, 1.12), _sh(col, 0.86)]).createShader(r));
}

void _txt(Canvas c, String s, Offset center, double size, Color col, {bool display = false}) {
  final tp = TextPainter(
    text: TextSpan(
        text: tr(s),
        style: TextStyle(
            fontFamily: display ? Hf.display : Hf.body, fontWeight: display ? FontWeight.w400 : FontWeight.w800, fontSize: size, color: col, letterSpacing: display ? 0 : 0.6)),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
}

/// Pinta la pared, la balda y los objetos. [trade]: 'alb', 'fon', 'ele', 'car' o 'dec'.
class EraScenePainter extends CustomPainter {
  final String era;
  final String trade;
  EraScenePainter(this.era, this.trade);

  @override
  void paint(Canvas c, Size size) {
    final shelfTop = size.height - 14;
    _wall(c, size, shelfTop);
    // Balda.
    final plank = switch (era) { '1980' => const Color(0xFF5A3420), '2005' => const Color(0xFFF1F2F2), _ => const Color(0xFFD9B98A) };
    c.drawRect(Rect.fromLTRB(0, shelfTop + 6, size.width, size.height), _f(_sh(plank, 0.45)));
    c.drawRect(Rect.fromLTRB(0, shelfTop, size.width, shelfTop + 6), _f(plank));
    c.drawLine(Offset(0, shelfTop), Offset(size.width, shelfTop), _s(Hc.line, 2));
    c.drawLine(Offset(0, shelfTop + 6), Offset(size.width, shelfTop + 6), _s(Hc.line, 1.5));
    c.drawRect(Rect.fromLTRB(0, shelfTop + 1, size.width, shelfTop + 2.5), _f(Colors.white.withValues(alpha: 0.25)));
    // Objetos: uno de la época a la izquierda y la herramienta del oficio a la derecha.
    const k = 1.4;
    c.save();
    c.translate(36, shelfTop);
    c.scale(k);
    _ambient(c, Offset.zero);
    c.restore();
    c.save();
    c.translate(size.width - 38, shelfTop);
    c.scale(k);
    _tool(c, Offset.zero);
    c.restore();
  }

  // ------------------------------------------------------------- paredes
  void _wall(Canvas c, Size size, double floor) {
    final r = Offset.zero & size;
    switch (era) {
      case '1980': // friso de madera
        c.drawRect(r, _f(const Color(0xFFB88A52)));
        for (var x = 8.0; x < size.width; x += 26) {
          c.drawRect(Rect.fromLTWH(x, 0, 6, size.height), _f(const Color(0xFFA87A44)));
          c.drawRect(Rect.fromLTWH(x + 10, 0, 2, size.height), _f(const Color(0xFFC99C66)));
        }
      case '2005': // gotelé
        c.drawRect(r, _f(const Color(0xFFE6D8B8)));
        final rng = math.Random(9);
        final n = (size.width * size.height / 260).round();
        for (var i = 0; i < n; i++) {
          c.drawCircle(Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height), 1.2 + rng.nextDouble() * 1.4, _f(const Color(0xFFD0BF98)));
        }
      case '2020': // blanco con zócalo verde salvia
        c.drawRect(r, _f(const Color(0xFFEDEEEA)));
        final z = floor - 34;
        c.drawRect(Rect.fromLTRB(0, z, size.width, floor), _f(const Color(0xFFA8B8A0)));
        c.drawRect(Rect.fromLTRB(0, z - 2, size.width, z + 2), _f(const Color(0xFF8FA088)));
      default: // 2050: yeso de arcilla, zócalo de lamas y marca de la última inundación
        c.drawRect(r, _f(const Color(0xFFEFE9DC)));
        final rng = math.Random(4);
        for (var i = 0; i < 6; i++) {
          c.drawOval(Rect.fromCenter(center: Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height), width: 60 + rng.nextDouble() * 50, height: 20 + rng.nextDouble() * 18),
              _f(const Color(0xB3E6DECC)));
        }
        final z = floor - 30;
        c.drawRect(Rect.fromLTRB(0, z, size.width, floor), _f(const Color(0xFFD9B98A)));
        c.drawRect(Rect.fromLTRB(0, z - 2, size.width, z + 1), _f(const Color(0xFFB8905A)));
        for (var x = 14.0; x < size.width; x += 14) {
          c.drawRect(Rect.fromLTWH(x, z, 1.5, floor - z), _f(const Color(0xFFC4A374)));
        }
        final cota = z + 11;
        c.drawRect(Rect.fromLTWH(0, cota, size.width, 2), _f(const Color(0xB33C7DC4)));
        final lab = Rect.fromCenter(center: Offset(size.width / 2, cota + 1), width: 74, height: 15);
        c.drawRRect(RRect.fromRectAndRadius(lab, const Radius.circular(3)), _f(const Color(0xFFF7F8F4)));
        c.drawRRect(RRect.fromRectAndRadius(lab, const Radius.circular(3)), _s(const Color(0xFF3C7DC4), 1.2));
        _txt(c, 'COTA 2047', lab.center, 8, const Color(0xFF2F5A8A));
    }
  }

  // ------------------------------------------------------------- objeto de la época
  void _ambient(Canvas c, Offset base) {
    final x = base.dx, y = base.dy;
    switch (era) {
      case '1980': // radiocasete
        final body = Rect.fromLTWH(x - 18, y - 26, 62, 26);
        c.drawLine(Offset(x + 30, y - 26), Offset(x + 40, y - 40), _s(const Color(0xFFC9CED1), 2));
        _rr(c, body, const Color(0xFF3A3F44), rad: 4);
        for (final cx in [x - 6, x + 32]) {
          c.drawCircle(Offset(cx, y - 13), 9, _f(Hc.line));
          c.drawCircle(Offset(cx, y - 13), 8, _f(const Color(0xFF1C1C1C)));
          c.drawCircle(Offset(cx, y - 13), 3.5, _f(const Color(0xFF5D6B72)));
        }
        _rr(c, Rect.fromLTWH(x + 6, y - 22, 14, 9), const Color(0xFFC9CED1), rad: 1.5, shadow: false);
        c.drawCircle(Offset(x + 10, y - 17.5), 1.8, _f(const Color(0xFF3A3F44)));
        c.drawCircle(Offset(x + 16, y - 17.5), 1.8, _f(const Color(0xFF3A3F44)));
        c.drawRect(Rect.fromLTWH(x + 7, y - 9, 12, 3), _f(const Color(0xFFC8443A)));
      case '2005': // caja de herramientas roja
        c.drawArc(Rect.fromLTWH(x - 6, y - 36, 28, 18), math.pi, math.pi, false, _s(const Color(0xFF1C1C1C), 3.5));
        _rr(c, Rect.fromLTWH(x - 18, y - 26, 52, 26), const Color(0xFFC8443A), rad: 3);
        c.drawRect(Rect.fromLTWH(x - 18, y - 19, 52, 2), _f(const Color(0xFF8A2A24)));
        _rr(c, Rect.fromLTWH(x + 3, y - 22, 10, 8), const Color(0xFFE3B23A), rad: 1.5, shadow: false);
      case '2020': // altavoz inteligente y móvil con la app de consumo
        _rr(c, Rect.fromLTWH(x - 18, y - 32, 26, 32), const Color(0xFF3A4146), rad: 9);
        c.drawOval(Rect.fromLTWH(x - 14, y - 32, 18, 5), _f(const Color(0xFF7FE0D8)));
        for (var k = 0; k < 4; k++) {
          c.drawLine(Offset(x - 13, y - 22 + k * 5.0), Offset(x + 3, y - 22 + k * 5.0), _s(const Color(0xFF2A3034), 1));
        }
        _rr(c, Rect.fromLTWH(x + 14, y - 30, 17, 30), const Color(0xFF1C1C1C), rad: 3);
        c.drawRect(Rect.fromLTWH(x + 16.5, y - 27, 12, 22), _f(const Color(0xFF0B1A14)));
        for (var k = 0; k < 3; k++) {
          final h = [8.0, 14.0, 11.0][k];
          c.drawRect(Rect.fromLTWH(x + 18 + k * 3.6, y - 7 - h, 2.6, h), _f(const Color(0xFF4FC08D)));
        }
      default: // 2050: planta en maceta de barro
        final pot = Path()
          ..moveTo(x - 12, y - 18)
          ..lineTo(x + 12, y - 18)
          ..lineTo(x + 9, y)
          ..lineTo(x - 9, y)
          ..close();
        c.drawPath(pot.shift(const Offset(2, 2)), _f(const Color(0x44000000)));
        c.drawPath(pot, _f(const Color(0xFFC98F6A)));
        c.drawPath(pot, _s(Hc.line, 1.8));
        _rr(c, Rect.fromLTWH(x - 14, y - 21, 28, 5), const Color(0xFFB87B58), rad: 2, shadow: false);
        void leaf(double dx, double dy, double ang, double h, Color col) {
          c.save();
          c.translate(x + dx, y - 21 + dy);
          c.rotate(ang);
          final r = Rect.fromCenter(center: Offset(0, -h / 2), width: h * 0.42, height: h);
          c.drawOval(r, _f(col));
          c.drawOval(r, _s(Hc.line, 1.5));
          c.drawLine(Offset(0, -2), Offset(0, -h + 3), _s(_sh(col, 0.7), 1));
          c.restore();
        }
        leaf(-4, 0, -0.45, 22, const Color(0xFF6FA07A));
        leaf(4, 0, 0.5, 20, const Color(0xFF8ABF8E));
        leaf(0, 0, 0.05, 26, const Color(0xFF4E8A5E));
    }
  }

  // ------------------------------------------------------------- herramienta del oficio
  Color get _handle => switch (era) {
        '1980' => const Color(0xFF8A5A34),
        '2005' => const Color(0xFFC8443A),
        '2020' => const Color(0xFF2B2B2B),
        _ => const Color(0xFFC9B38A),
      };
  Color get _accent => switch (era) {
        '1980' => const Color(0xFFD08A54),
        '2005' => const Color(0xFFE3B23A),
        '2020' => const Color(0xFFE3B23A),
        _ => const Color(0xFF8FA88A),
      };

  void _tool(Canvas c, Offset base) {
    final x = base.dx, y = base.dy;
    final steel = const Color(0xFFC9CED1);
    switch (trade) {
      case 'alb': // paleta de albañil y cubo
        _rr(c, Rect.fromLTWH(x - 42, y - 22, 24, 22), era == '2050' ? const Color(0xFF8FA88A) : const Color(0xFF2B2B2B), rad: 3);
        c.drawRect(Rect.fromLTWH(x - 40, y - 22, 20, 4), _f(const Color(0xFFB8AE9A)));
        final blade = Path()
          ..moveTo(x - 12, y - 2)
          ..lineTo(x + 14, y - 2)
          ..lineTo(x + 2, y - 16)
          ..close();
        c.drawPath(blade, _f(steel));
        c.drawPath(blade, _s(Hc.line, 1.6));
        c.drawLine(Offset(x + 2, y - 16), Offset(x + 6, y - 24), _s(Hc.line, 2));
        _rr(c, Rect.fromLTWH(x + 3, y - 34, 6, 11), _handle, rad: 2, shadow: false);
      case 'fon': // llave inglesa
        c.save();
        c.translate(x, y - 8);
        c.rotate(-0.25);
        _rr(c, Rect.fromLTWH(-24, -3.5, 34, 7), steel, rad: 3);
        _rr(c, Rect.fromLTWH(-30, -3.5, 14, 7), _handle, rad: 3, shadow: false);
        final head = Path()
          ..moveTo(10, -9)
          ..lineTo(22, -9)
          ..lineTo(22, -4)
          ..lineTo(15, -4)
          ..lineTo(15, 4)
          ..lineTo(22, 4)
          ..lineTo(22, 9)
          ..lineTo(10, 9)
          ..close();
        c.drawPath(head, _f(steel));
        c.drawPath(head, _s(Hc.line, 1.6));
        c.restore();
      case 'ele':
        switch (era) {
          case '1980': // destornillador buscapolos
            c.save();
            c.translate(x, y - 6);
            c.rotate(-0.2);
            _rr(c, Rect.fromLTWH(-30, -4, 26, 8), const Color(0xFFE3B23A), rad: 3);
            c.drawRect(Rect.fromLTWH(-24, -2, 12, 4), _f(const Color(0xFFE2675B)));
            _rr(c, Rect.fromLTWH(-4, -1.5, 26, 3), steel, rad: 1, shadow: false);
            c.restore();
          case '2005': // multímetro amarillo con sus puntas
            c.drawLine(Offset(x - 6, y - 30), Offset(x - 20, y - 46), _s(const Color(0xFFC8443A), 2));
            c.drawLine(Offset(x + 6, y - 30), Offset(x + 18, y - 46), _s(const Color(0xFF1C1C1C), 2));
            _rr(c, Rect.fromLTWH(x - 14, y - 32, 28, 32), const Color(0xFFE3B23A), rad: 5);
            _rr(c, Rect.fromLTWH(x - 10, y - 28, 20, 9), const Color(0xFFC9D8C0), rad: 1.5, shadow: false);
            _txt(c, '230', Offset(x, y - 23.5), 8, const Color(0xFF1C2523), display: true);
            c.drawCircle(Offset(x, y - 10), 6, _f(const Color(0xFF2B2B2B)));
            c.drawLine(Offset(x, y - 10), Offset(x + 3, y - 14), _s(const Color(0xFFF1F2F2), 1.5));
          case '2020': // móvil con la app del contador
            _rr(c, Rect.fromLTWH(x - 9, y - 34, 18, 34), const Color(0xFF1C1C1C), rad: 3);
            c.drawRect(Rect.fromLTWH(x - 6.5, y - 31, 13, 26), _f(const Color(0xFF0B1A14)));
            _txt(c, 'kW', Offset(x, y - 26), 6, const Color(0xFF4FC08D));
            for (var k = 0; k < 3; k++) {
              final h = [7.0, 12.0, 9.0][k];
              c.drawRect(Rect.fromLTWH(x - 5 + k * 3.6, y - 7 - h, 2.6, h), _f(const Color(0xFF4FC08D)));
            }
          default: // 2050: comprobador de baja tensión
            c.drawLine(Offset(x - 6, y - 32), Offset(x - 14, y - 46), _s(const Color(0xFFD8503F), 2));
            c.drawLine(Offset(x + 6, y - 32), Offset(x + 12, y - 46), _s(const Color(0xFF2B2B2B), 2));
            _rr(c, Rect.fromLTWH(x - 13, y - 34, 26, 34), const Color(0xFFF7F8F4), rad: 6);
            _rr(c, Rect.fromLTWH(x - 9, y - 30, 18, 11), const Color(0xFFDDE3D8), rad: 2, shadow: false);
            _txt(c, '48 V', Offset(x, y - 24.5), 7, const Color(0xFF2B2B2B));
            c.drawCircle(Offset(x, y - 9), 4.5, _f(const Color(0xFF8FA88A)));
            c.drawCircle(Offset(x, y - 9), 4.5, _s(Hc.line, 1.2));
        }
      case 'car': // martillo
        c.save();
        c.translate(x, y - 6);
        c.rotate(-0.15);
        _rr(c, Rect.fromLTWH(-30, -3, 34, 6), _handle, rad: 2);
        _rr(c, Rect.fromLTWH(2, -11, 9, 22), const Color(0xFF5D6B72), rad: 1.5, shadow: false);
        c.drawRect(Rect.fromLTWH(-30, -3, 10, 6), _f(_accent));
        c.restore();
      default: // 'dec': bote de pintura y brocha
        _rr(c, Rect.fromLTWH(x - 40, y - 22, 22, 22), const Color(0xFFC9CED1), rad: 2);
        c.drawRect(Rect.fromLTWH(x - 40, y - 15, 22, 8), _f(_accent));
        c.drawArc(Rect.fromLTWH(x - 36, y - 30, 14, 14), math.pi, math.pi, false, _s(Hc.line, 1.5));
        c.save();
        c.translate(x + 2, y - 10);
        c.rotate(-0.5);
        _rr(c, Rect.fromLTWH(-4, -22, 8, 16), _handle, rad: 3, shadow: false);
        _rr(c, Rect.fromLTWH(-6, -6, 12, 6), steel, rad: 1, shadow: false);
        _rr(c, Rect.fromLTWH(-7, 0, 14, 10), _accent, rad: 2, shadow: false);
        c.restore();
    }
  }

  @override
  bool shouldRepaint(EraScenePainter o) => o.era != era || o.trade != trade;
}
