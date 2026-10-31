import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../game/data.dart';
import '../../game/engine.dart';
import '../../game/era.dart';
import '../../services/storage.dart';
import '../common.dart';
import '../widgets/atoms.dart';
import '../widgets/overlays.dart';
import 'offline.dart';
import 'premium.dart';
import 'title_screen.dart';
import '../shell.dart';

import '../../core/texto.dart';
// =====================================================================
// DLC de épocas: hemeroteca (selector), ficha previa, banda del periódico
// en el mapa y resultado final. Solo se usa cuando el jugador entra en una época.
// =====================================================================

/// Familias tipográficas de las portadas (OFL, en assets/fonts/epocas).
class EraFonts {
  static const fraktur = 'Fraktur';
  static const serif = 'OldStandard';
  static const anton = 'Anton';
  static const typewriter = 'CourierPrime';
  static const rounded = 'Nunito';
  static const sans = 'Inter';
  static const mono = 'JetBrainsMono';
}

const _medalColors = [Hc.dim, Color(0xFFC07A45), Color(0xFFBFC9CC), Hc.accHi];

String _portada(String id) => 'assets/eras/portadas/$id.png';

ColorFilter _matrix(double sat, {double r = 1, double g = 1, double b = 1, double contrast = 1}) {
  // Saturación + tinte + contraste en una sola matriz.
  final s = sat, i = 1 - s;
  const lr = 0.2126, lg = 0.7152, lb = 0.0722;
  final o = 128 * (1 - contrast);
  return ColorFilter.matrix(<double>[
    (lr * i + s) * r * contrast, lg * i * r * contrast, lb * i * r * contrast, 0, o,
    lr * i * g * contrast, (lg * i + s) * g * contrast, lb * i * g * contrast, 0, o,
    lr * i * b * contrast, lg * i * b * contrast, (lb * i + s) * b * contrast, 0, o,
    0, 0, 0, 1, 0,
  ]);
}

/// Foto de portada: el mapa de la época en pixel art, con el revelado de su prensa.
class _Photo extends StatelessWidget {
  final String id;
  final double height;
  final ColorFilter? filter;
  final Color border;
  final double radius;
  final Widget? overlay;
  const _Photo(this.id, {required this.height, this.filter, this.border = Hc.line, this.radius = 0, this.overlay});
  @override
  Widget build(BuildContext context) {
    Widget img = Image.asset(_portada(id), fit: BoxFit.cover, filterQuality: FilterQuality.none);
    if (filter != null) img = ColorFiltered(colorFilter: filter!, child: img);
    return Container(
      height: height,
      decoration: BoxDecoration(border: Border.all(color: border, width: 2), borderRadius: BorderRadius.circular(radius)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(math.max(0, radius - 2)),
        child: Stack(fit: StackFit.expand, children: [img, if (overlay != null) overlay!]),
      ),
    );
  }
}

TextStyle _t(String family, double size, Color c, {FontWeight? w, bool italic = false, double h = 1.2, double ls = 0, double? wght}) => TextStyle(
      fontFamily: family,
      fontSize: size,
      color: c,
      fontWeight: w,
      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      height: h,
      letterSpacing: ls,
      fontVariations: wght == null ? null : [FontVariation('wght', wght)],
    );

TextStyle _head(double size, Color c) => TextStyle(fontFamily: Hf.display, fontSize: size, color: c, height: 0.9);

/// Tres breves de reglas en columnas (para las portadas de papel).
class _Briefs extends StatelessWidget {
  final EraConfig e;
  final Color ink;
  final String family;
  static const size = 10.5;
  const _Briefs(this.e, {required this.ink, required this.family});
  @override
  Widget build(BuildContext context) => IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var i = 0; i < e.rules.length; i++) ...[
            if (i > 0) Container(width: 1, margin: const EdgeInsets.symmetric(horizontal: 6), color: ink.withValues(alpha: 0.4)),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.rules[i].title.toUpperCase(), style: _t(family, size - 1.5, _ruleColor(e.rules[i].kind, paper: true), w: FontWeight.w700, ls: 0.5)),
                const SizedBox(height: 2),
                Text(e.rules[i].desc, style: _t(family, size, ink, h: 1.25)),
              ]),
            ),
          ],
        ]),
      );
}

Color _ruleColor(EraRuleKind k, {bool paper = false}) => switch (k) {
      EraRuleKind.ventaja => paper ? const Color(0xFF2E7D4F) : Hc.ok,
      EraRuleKind.pega => paper ? const Color(0xFFB8432F) : Hc.bad,
      EraRuleKind.ojo => paper ? const Color(0xFF2F6E96) : Hc.info,
    };

String _ruleLabel(EraRuleKind k) => switch (k) {
      EraRuleKind.ventaja => 'Ventaja',
      EraRuleKind.pega => 'Pega',
      EraRuleKind.ojo => 'Ojo',
    };

/// Portada de una época, con el estilo de prensa de su año y el marco del juego.
class EraFrontPage extends StatelessWidget {
  final EraConfig e;
  const EraFrontPage(this.e, {super.key});

  @override
  Widget build(BuildContext context) {
    final page = switch (e.press) {
      PressStyle.gaceta => _gaceta(),
      PressStyle.broadsheet => _broadsheet(),
      PressStyle.vespertino => _vespertino(),
      PressStyle.correo => _correo(),
      PressStyle.app => _app(),
      PressStyle.feed => _feed(),
    };
    // Una sola inclinación leve, estática: es papel encima de la mesa.
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: 330,
        child: Transform.rotate(angle: e.press == PressStyle.app || e.press == PressStyle.feed ? 0 : -0.024, child: page),
      ),
    );
  }

  BoxDecoration _paper(Color c, {double r = 4}) => BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(r),
        border: Border.all(color: Hc.line, width: 2),
        boxShadow: const [BoxShadow(color: Color(0x8C000000), offset: Offset(0, 4))],
      );

  Widget _gaceta() {
    const ink = Color(0xFF2A1F12), mut = Color(0xFF5C4A30);
    return Container(
      decoration: _paper(const Color(0xFFE6D3A8)),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Text(e.issue, style: _t(EraFonts.serif, 10, mut)),
          const Spacer(),
          Text(e.price, style: _t(EraFonts.serif, 10, mut)),
        ]),
        const SizedBox(height: 4),
        FittedBox(fit: BoxFit.scaleDown, child: Text(e.masthead, maxLines: 1, style: _t(EraFonts.fraktur, 30, ink, h: 1))),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 2),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: ink, width: 3), bottom: BorderSide(color: ink, width: 1))),
          child: Text(e.date, textAlign: TextAlign.center, style: _t(EraFonts.serif, 10.5, mut, italic: true)),
        ),
        const SizedBox(height: 7),
        Text(e.headline.toUpperCase(), textAlign: TextAlign.center, style: _head(40, ink)),
        const SizedBox(height: 6),
        Text(e.deck, textAlign: TextAlign.center, style: _t(EraFonts.serif, 12.5, mut, italic: true, h: 1.3)),
        const SizedBox(height: 7),
        _Photo(e.id, height: 124, border: ink, filter: _matrix(0.1, r: 1.08, g: 0.92, b: 0.7, contrast: 1.1)),
        const SizedBox(height: 7),
        _Briefs(e, ink: ink, family: EraFonts.serif),
        const SizedBox(height: 7),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(border: Border.all(color: ink, width: 1)),
          child: Text(e.footer, textAlign: TextAlign.center, style: _t(EraFonts.serif, 10, ink)),
        ),
      ]),
    );
  }

  Widget _broadsheet() {
    const ink = Color(0xFF1E1A14), mut = Color(0xFF554B3C), red = Color(0xFFB8432F);
    return Stack(clipBehavior: Clip.none, children: [
      Container(
        decoration: _paper(const Color(0xFFE9DFC6)),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Text(e.issue, style: _t(EraFonts.serif, 10, mut)),
            const Spacer(),
            Text(e.price, style: _t(EraFonts.serif, 10, mut)),
          ]),
          const SizedBox(height: 4),
          FittedBox(fit: BoxFit.scaleDown, child: Text(e.masthead, maxLines: 1, style: _t(EraFonts.fraktur, 31, ink, h: 1))),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 2),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: ink, width: 2), bottom: BorderSide(color: ink, width: 2))),
            child: Text(e.date.toUpperCase(), textAlign: TextAlign.center, style: _t(EraFonts.serif, 9.5, mut, w: FontWeight.w700, ls: 0.5)),
          ),
          const SizedBox(height: 7),
          Text(e.headline.toUpperCase(), textAlign: TextAlign.center, style: _head(46, ink)),
          const SizedBox(height: 6),
          Text(e.deck, textAlign: TextAlign.center, style: _t(EraFonts.serif, 12.5, mut, italic: true, h: 1.3)),
          const SizedBox(height: 7),
          _Photo(e.id, height: 118, border: ink, filter: _matrix(0, contrast: 1.25), overlay: const CustomPaint(painter: _HalftonePainter())),
          const SizedBox(height: 7),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 11, child: Text(e.footer, style: _t(EraFonts.serif, 11, ink, h: 1.3))),
            Container(width: 1, height: 64, margin: const EdgeInsets.symmetric(horizontal: 8), color: ink),
            Expanded(
              flex: 10,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('COTIZACIONES', style: _t(EraFonts.serif, 9.5, ink, w: FontWeight.w700, ls: 1)),
                for (final r in const [('Ferrocarriles', '−34 %'), ('Cementos', '−41 %'), ('Banca Alba', '−52 %')])
                  Row(children: [
                    Expanded(child: Text(r.$1, style: _head(15, ink))),
                    Text(r.$2, style: _head(15, red)),
                  ]),
              ]),
            ),
          ]),
        ]),
      ),
      Positioned(
        right: -6,
        top: 56,
        child: Transform.rotate(
          angle: 0.2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(color: const Color(0xD9E9DFC6), border: Border.all(color: red, width: 3)),
            child: Text('EXTRA', style: _t(EraFonts.anton, 20, red, ls: 2)),
          ),
        ),
      ),
    ]);
  }

  Widget _vespertino() {
    const ink = Color(0xFF1C1714), mut = Color(0xFF54493F), red = Color(0xFFB8432F);
    return Container(
      decoration: _paper(const Color(0xFFE8E2D2)),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Container(
          color: red,
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 5),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(child: Text(e.masthead, style: _t(EraFonts.anton, 29, const Color(0xFFF4ECDC), h: 1, ls: 1))),
            Text(e.price, style: _t(EraFonts.typewriter, 10, const Color(0xFFF4ECDC))),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text(e.date, style: _t(EraFonts.typewriter, 10, mut))),
              Text(e.issue, style: _t(EraFonts.typewriter, 10, mut)),
            ]),
            const SizedBox(height: 6),
            Text(e.headline.toUpperCase(), style: _t(EraFonts.anton, 42, ink, h: 0.95)),
            const SizedBox(height: 6),
            Text(e.deck, style: _t(EraFonts.typewriter, 11.5, mut, h: 1.3)),
            const SizedBox(height: 7),
            _Photo(e.id, height: 124, border: ink, filter: _matrix(0.15, contrast: 1.35)),
            const SizedBox(height: 7),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Text('Uno de cada tres edificios está vacío. Quien tenga efectivo, que levante la mano. Despacio.', style: _t(EraFonts.typewriter, 10.5, ink, h: 1.3))),
              const SizedBox(width: 10),
              Container(
                width: 96,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(border: Border.all(color: ink, width: 2)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('TIPO HIPOTECARIO', style: _t(EraFonts.typewriter, 8.5, ink, w: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    for (final h in const [8.0, 12.0, 15.0, 21.0, 26.0]) ...[
                      Container(width: 9, height: h, color: h == 26 ? red : ink),
                      const SizedBox(width: 3),
                    ],
                  ]),
                  const SizedBox(height: 3),
                  Text('17,25 %', style: _t(EraFonts.anton, 18, red, h: 1)),
                ]),
              ),
            ]),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.only(top: 4),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: ink, width: 2))),
              child: Text(e.footer, style: _t(EraFonts.typewriter, 10, ink)),
            ),
          ]),
        ),
      ]),
    );
  }

  /// 2005: correo electrónico con brillo Y2K (inspirado en la época, sin ninguna marca real).
  Widget _correo() {
    const ink = Color(0xFF1A2A36), mut = Color(0xFF4A5A66);
    TextStyle r(double s, Color c, {double w = 700}) => _t(EraFonts.rounded, s, c, wght: w, h: 1.25);
    Widget orb(List<Color> cols, double size) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Hc.line, width: 2),
            gradient: RadialGradient(center: const Alignment(-0.35, -0.4), colors: cols, stops: const [0.0, 0.25, 1.0]),
          ),
        );
    return Container(
      decoration: _paper(const Color(0xFFF4F8FB), r: 10),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        // Barra de título brillante (dos mitades de degradado).
        Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Hc.line, width: 2)),
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [
              Color(0xFF8FD0EE), Color(0xFF4FA3D1), Color(0xFF2C7DB8), Color(0xFF4FA3D1),
            ], stops: [0, 0.49, 0.51, 1]),
          ),
          child: Row(children: [
            orb(const [Colors.white, Color(0xFF6FE07A), Color(0xFF1F9A3A)], 20),
            const SizedBox(width: 8),
            Text(e.masthead, style: r(13, Colors.white, w: 900).copyWith(shadows: const [Shadow(color: Color(0xFF1A4E78), offset: Offset(0, 1))])),
            const SizedBox(width: 6),
            Expanded(child: Text('· ${e.issue}', maxLines: 1, overflow: TextOverflow.ellipsis, style: r(10.5, const Color(0xFFEAF6FF), w: 600))),
          ]),
        ),
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              width: 84,
              padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
              decoration: const BoxDecoration(
                border: Border(right: BorderSide(color: Hc.line, width: 2)),
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFE4F2FA), Color(0xFFCBE4F2)]),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF4F8FBF), width: 1.5),
                    gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.white, Color(0xFFBFE3F7)]),
                  ),
                  child: Text('Entrada', style: r(10.5, ink, w: 800)),
                ),
                for (final f in const ['¡Ofertas! (88)', 'Hipotecas', 'Recalificaciones'])
                  Padding(padding: const EdgeInsets.fromLTRB(5, 6, 0, 0), child: Text(f, style: r(10, ink))),
                Padding(padding: const EdgeInsets.fromLTRB(5, 6, 0, 0), child: Text('Correo no deseado', style: r(10, const Color(0xFF7A8A96)))),
              ]),
            ),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Color(0xFFC8B050))),
                    gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFF6C8), Color(0xFFFFE38A)]),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('FW: FW: RE: ¡¡PISOS SOBRE PLANO!!', maxLines: 1, overflow: TextOverflow.ellipsis, style: r(10.5, ink, w: 900)),
                    Text('inmobiliaria@pelotazo.an · ${e.date}', maxLines: 1, overflow: TextOverflow.ellipsis, style: r(9.5, mut, w: 600)),
                  ]),
                ),
                for (final x in const ['Tu hipoteca al 110 % ya está preaprobada', 'Cuñado: «esto no baja nunca»'])
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFD8E4EC)))),
                    child: Text(x, maxLines: 1, overflow: TextOverflow.ellipsis, style: r(9.5, mut, w: 600)),
                  ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(e.headline.toUpperCase(), style: _head(32, const Color(0xFF1E4A8A))),
                    const SizedBox(height: 6),
                    Stack(clipBehavior: Clip.none, children: [
                      _Photo(e.id, height: 88, radius: 8),
                      Positioned(
                        right: -4,
                        top: -6,
                        child: Transform.rotate(
                          angle: 0.24,
                          child: Container(
                            width: 50,
                            height: 50,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Hc.line, width: 2),
                              gradient: const RadialGradient(center: Alignment(-0.3, -0.4), colors: [Color(0xFFFFF3A0), Color(0xFFFFB020), Color(0xFFE86A2E)]),
                            ),
                            child: Text('¡YA\nES TUYO!', textAlign: TextAlign.center, style: r(9.5, Hc.onAcc, w: 900).copyWith(height: 1.1)),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    Text(e.deck, style: r(10.5, const Color(0xFF3A4A56), w: 600)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: Hc.line, width: 2),
                        boxShadow: const [BoxShadow(color: Hc.line, offset: Offset(0, 2))],
                        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [
                          Color(0xFFA8F0B0), Hc.ok, Color(0xFF2E9A64), Hc.ok,
                        ], stops: [0, 0.5, 0.51, 1]),
                      ),
                      child: Text('Quiero el mío', style: r(10.5, const Color(0xFF06170E), w: 900)),
                    ),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }

  /// 2020: app de noticias en el móvil.
  Widget _app() {
    const ink = Color(0xFF141414), mut = Color(0xFF6A6A66), red = Color(0xFFE2675B);
    TextStyle s(double z, Color c, {double w = 600}) => _t(EraFonts.sans, z, c, wght: w, h: 1.3);
    Widget pill(String t, {bool dark = false}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: dark ? ink : null,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: ink, width: 1.5),
          ),
          child: Text(t, style: s(10, dark ? const Color(0xFFF4F4F0) : ink, w: 700)),
        );
    return Center(
      child: Container(
        width: 300,
        decoration: _paper(const Color(0xFFF4F4F0), r: 26),
        clipBehavior: Clip.antiAlias,
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Container(
            margin: const EdgeInsets.fromLTRB(8, 8, 8, 6),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xE0141414),
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [BoxShadow(color: Hc.line, offset: Offset(0, 2))],
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: red, borderRadius: BorderRadius.circular(6)),
                child: Text('a.', style: s(11, Colors.white, w: 900)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('alba.news · ahora', style: s(9.5, const Color(0xFFB8B8B4))),
                  Text('Última hora: ${e.deck.toLowerCase()}', style: s(10.5, const Color(0xFFF4F4F0), w: 700)),
                ]),
              ),
            ]),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFDCDCD6)))),
            child: Row(children: [
              Text.rich(TextSpan(children: [
                TextSpan(text: 'alba', style: s(20, ink, w: 900).copyWith(letterSpacing: -1)),
                TextSpan(text: '.', style: s(20, red, w: 900)),
                TextSpan(text: 'news', style: s(20, ink, w: 900).copyWith(letterSpacing: -1)),
              ])),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: red, borderRadius: BorderRadius.circular(99)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  Text('EN DIRECTO', style: s(9.5, Colors.white, w: 800).copyWith(letterSpacing: 0.6)),
                ]),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.date.toUpperCase(), style: s(9.5, mut, w: 800).copyWith(letterSpacing: 1)),
              const SizedBox(height: 4),
              Text(e.headline.toUpperCase(), style: _head(34, ink)),
              const SizedBox(height: 6),
              _Photo(e.id, height: 92, border: ink, radius: 12),
              const SizedBox(height: 6),
              Row(children: [pill('Compartir'), const SizedBox(width: 6), pill('Guardar'), const SizedBox(width: 6), pill('4 min', dark: true)]),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.only(left: 9),
                decoration: const BoxDecoration(border: Border(left: BorderSide(color: red, width: 2))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  for (final l in const [
                    ('21:04', 'El alquiler turístico cae a cero reservas.'),
                    ('20:40', 'Los pisos con terraza ya cotizan un 30 % más.'),
                    ('19:15', 'El Ayuntamiento estudia topar el alquiler en el casco.'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text.rich(TextSpan(children: [
                        TextSpan(text: '${l.$1} ', style: s(10.5, red, w: 800)),
                        TextSpan(text: l.$2, style: s(10.5, ink)),
                      ])),
                    ),
                ]),
              ),
            ]),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(8, 6, 8, 0),
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: ink, width: 1.5)),
            child: Row(children: [
              Expanded(child: Text('Usamos cookies para venderte un piso.', style: s(10, ink))),
              for (var i = 0; i < 2; i++) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(8)),
                  child: Text('Aceptar', style: s(10, Colors.white, w: 800)),
                ),
              ],
            ]),
          ),
        ]),
      ),
    );
  }

  /// 2050: resumen holográfico generado.
  Widget _feed() {
    const cyan = Color(0xFF7FE0D8), ink = Color(0xFFDDF4F2), mut = Color(0xFF9CC9D0);
    TextStyle m(double z, Color c, {double w = 500}) => _t(EraFonts.mono, z, c, wght: w, h: 1.3);
    Widget chip(String t, Color c) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(7), border: Border.all(color: c, width: 1.5)),
          child: Text(t, style: m(9.5, c, w: 700)),
        );
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0C1A26),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Hc.line, width: 2),
        boxShadow: const [BoxShadow(color: Color(0x8C000000), offset: Offset(0, 4))],
      ),
      clipBehavior: Clip.antiAlias,
      child: CustomPaint(
        painter: const _ScanPainter(),
        child: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: cyan.withValues(alpha: 0.35))),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Text(e.masthead, style: _head(30, cyan).copyWith(letterSpacing: 4)),
              const Spacer(),
              Text(e.date.replaceFirst(' · ', '\n'), textAlign: TextAlign.right, style: m(9.5, mut)),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [chip(e.issue.toUpperCase(), cyan), chip('FUENTES 3/7 VERIFICADAS', Hc.acc)]),
            const SizedBox(height: 8),
            Text(e.headline.toUpperCase(), style: _head(38, const Color(0xFFECFBFA)).copyWith(shadows: const [Shadow(color: Hc.line, offset: Offset(0, 3))])),
            const SizedBox(height: 6),
            Text('${e.deck} Tu cartera tiene 2 edificios en zona roja.', style: m(10.5, mut)),
            const SizedBox(height: 8),
            _Photo(
              e.id,
              height: 120,
              border: cyan,
              radius: 12,
              overlay: Stack(children: [
                Positioned(left: 0, right: 0, bottom: 26, child: Container(height: 2, color: Hc.bad)),
                Positioned(
                  right: 6,
                  bottom: 30,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(color: Hc.bad, borderRadius: BorderRadius.circular(6)),
                    child: Text('COTA +38 cm', style: m(9.5, const Color(0xFF1A0705), w: 800)),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 8),
            Row(children: [
              for (var i = 0; i < e.rules.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xCC102436),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF2C4B58), width: 1.5),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_ruleLabel(e.rules[i].kind).toUpperCase(), style: m(8.5, _ruleColor(e.rules[i].kind), w: 800)),
                      Text(e.rules[i].title, style: m(10, ink)),
                    ]),
                  ),
                ),
              ],
            ]),
          ]),
        ),
      ),
    );
  }
}

/// Trama de puntos de la foto impresa (1929).
class _HalftonePainter extends CustomPainter {
  const _HalftonePainter();
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()..color = const Color(0x591E1A14);
    for (var y = 1.5; y < s.height; y += 3) {
      for (var x = 1.5; x < s.width; x += 3) {
        c.drawCircle(Offset(x, y), 0.6, p);
      }
    }
  }

  @override
  bool shouldRepaint(_HalftonePainter o) => false;
}

/// Líneas de barrido del holograma (2050).
class _ScanPainter extends CustomPainter {
  const _ScanPainter();
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()..color = const Color(0x0D7FE0D8);
    for (var y = 0.0; y < s.height; y += 4) {
      c.drawRect(Rect.fromLTWH(0, y, s.width, 1), p);
    }
  }

  @override
  bool shouldRepaint(_ScanPainter o) => false;
}

// =====================================================================
// Hemeroteca: carrusel de portadas
// =====================================================================

class HemerotecaScreen extends ConsumerStatefulWidget {
  const HemerotecaScreen({super.key});
  @override
  ConsumerState<HemerotecaScreen> createState() => _HemerotecaState();
}

class _HemerotecaState extends ConsumerState<HemerotecaScreen> {
  static const _eras = EraConfig.all;
  late final PageController _pc;
  int _i = 1;
  Map<String, Map<String, num>> _progress = {};
  final Set<String> _saved = {};

  @override
  void initState() {
    super.initState();
    final cur = ref.read(gameProvider).eraCfg;
    final idx = cur == null ? -1 : _eras.indexWhere((e) => e.id == cur.id);
    _i = idx >= 0 ? idx : _eras.indexWhere((e) => e.id == '1929');
    _pc = PageController(initialPage: _i, viewportFraction: 0.92);
    _load();
  }

  Future<void> _load() async {
    final p = await Storage.eraProgress();
    final s = <String>{};
    for (final e in _eras.where((e) => e.playable)) {
      final j = await Storage.loadEra(e.id);
      // Una época terminada no se «continúa»: se vuelve a jugar.
      if (j != null && j['eraOver'] != true) s.add(e.id);
    }
    if (!mounted) return;
    setState(() {
      _progress = p;
      _saved
        ..clear()
        ..addAll(s);
    });
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _go(int i) {
    final n = _eras.length;
    final t = (i + n) % n;
    HapticFeedback.selectionClick();
    _pc.animateToPage(t, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final g = ref.watch(gameProvider);
    final ent = ref.watch(entitlementsProvider);
    final e = _eras[_i];
    final here = g.eraCfg?.id == e.id;
    final medal = (_progress[e.id]?['medal'] ?? 0).toInt();
    final locked = e.playable && !e.free && !ent.hasEras;
    final Widget status = !e.playable
        ? const Tag('Pack · pronto', color: Hc.mut)
        : locked
            ? const Tag('Pack', color: Hc.acc, icon: Icons.lock_outline_rounded)
            : medal > 0
                ? Tag(medalNames[medal], color: _medalColors[medal], icon: Icons.emoji_events_outlined)
                : e.free
                    ? const Tag('Gratis', color: Hc.ok)
                    : const Tag('Pack', color: Hc.ok, icon: Icons.check_rounded);
    final String label;
    VoidCallback? onTap;
    if (!e.playable) {
      label = 'Próximamente en el pack';
    } else if (locked) {
      label = 'Desbloquear el pack de épocas';
      onTap = () => showPackSheet(context);
    } else if (here) {
      label = 'Seguir en ${e.id}';
      onTap = () => Navigator.of(context).popUntil((r) => r.isFirst);
    } else {
      label = _saved.contains(e.id) ? 'Continuar ${e.id}' : 'Jugar ${e.id}';
      onTap = () => showEraBrief(context, ref, e, hasSave: _saved.contains(e.id));
    }
    return Screen(
      dock: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          SqButton(Icons.chevron_left_rounded, tooltip: 'Época anterior', onTap: () => _go(_i - 1)),
          Expanded(
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var k = 0; k < _eras.length; k++)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _go(k),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 14),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: k == _i ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: k == _i ? Hc.acc : Hc.lineSoft,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Hc.line, width: 2),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
          SqButton(Icons.chevron_right_rounded, tooltip: 'Época siguiente', onTap: () => _go(_i + 1)),
        ]),
        const SizedBox(height: 8),
        HsButton(label, block: true, size: BtnSize.lg, onTap: onTap, kind: e.playable ? BtnKind.primary : BtnKind.ghost),
      ]),
      child: Column(children: [
        BackHeader('Hemeroteca', sub: '${e.id} · ${e.name}', trail: status),
        Expanded(
          child: PageView.builder(
            controller: _pc,
            itemCount: _eras.length,
            onPageChanged: (k) => setState(() => _i = k),
            itemBuilder: (_, k) => Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
              child: Center(child: EraFrontPage(_eras[k])),
            ),
          ),
        ),
      ]),
    );
  }
}

// =====================================================================
// Ficha antes de empezar
// =====================================================================

Widget _ruleRow(EraRule r) {
  final c = _ruleColor(r.kind);
  return Li(
    lead: Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(8), border: Border.all(color: Hc.line, width: 2)),
      child: Icon(
          switch (r.kind) {
            EraRuleKind.pega => Icons.trending_down_rounded,
            EraRuleKind.ojo => Icons.info_outline_rounded,
            EraRuleKind.ventaja => Icons.sell_outlined,
          },
          size: 16,
          color: Hc.line),
    ),
    title: r.title,
    display: true,
    sub: r.desc,
  );
}

Widget _medalTile(int i, String value, {bool hi = false}) => StatTile(
      border: hi ? Hc.acc : null,
      child: Row(children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(shape: BoxShape.circle, color: _medalColors[i], border: Border.all(color: Hc.line, width: 2)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(medalNames[i], style: Ht.mini),
            FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: Ht.numS.copyWith(color: hi ? Hc.accHi : Hc.ink))),
          ]),
        ),
      ]),
    );

/// Cifras de la ficha en dólares de la época (aunque todavía se esté en otra partida).
String _eraMoney(EraConfig e, double v, {bool compact = true}) {
  final keep = Money.scale;
  Money.scale = e.priceLevel;
  final s = money(v, compact: compact);
  Money.scale = keep;
  return s;
}

String _goalValue(EraConfig e, double v) => e.metric == EraMetric.patrimonio ? _eraMoney(e, v) : intg(v);

/// Nombre corto de lo que mide la época.
String _metricName(EraConfig e) => switch (e.metric) {
      EraMetric.patrimonio => 'Patrimonio',
      EraMetric.viviendas => 'Viviendas',
      EraMetric.alquiladas => 'Alquiladas',
      EraMetric.reformas => 'Reformas',
    };

Future<void> showEraBrief(BuildContext context, WidgetRef ref, EraConfig e, {bool hasSave = false}) {
  if (!e.free && !ref.read(entitlementsProvider).hasEras) return showPackSheet(context);
  return showHsSheet(context, scroll: true, builder: (ctx) {
    Future<void> start(bool fresh) async {
      if (fresh && hasSave) {
        final ok = await confirm(ctx,
            title: 'Empezar de nuevo', body: 'Se borra la partida guardada de ${e.id}. Tu ciudad principal no se toca.', ok: 'Empezar', danger: true);
        if (!ok) return;
      }
      if (!ctx.mounted) return;
      Navigator.pop(ctx);
      await enterEra(ref, e, fresh: fresh);
      if (context.mounted) _openGame(context);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        Container(
          width: 54,
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Hc.panelIn,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Hc.acc, width: 2),
            boxShadow: He.pop,
          ),
          child: Text(e.id, style: Ht.numS.copyWith(fontSize: 24, color: Hc.acc)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.name, style: Ht.h2.copyWith(fontSize: 30)),
            Text('Partida cerrada · ene ${e.startYear} → dic ${e.endYear}', style: Ht.small),
          ]),
        ),
        if (e.free) const Tag('Gratis', color: Hc.ok),
      ]),
      const SizedBox(height: 10),
      StatGrid([
        Stat('Duración', plural(e.years, 'año', 'años')),
        Stat('Efectivo', _eraMoney(e, e.startCash), color: Hc.acc),
        Stat('Mercado', mph(e.phaseAt(0)).name, color: mph(e.phaseAt(0)).color),
      ], columns: 3),
      const SizedBox(height: 10),
      Cap('Objetivo · ${e.goal.toLowerCase()}'),
      const SizedBox(height: 6),
      Row(children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: _medalTile(i + 1, _goalValue(e, e.medals[i]), hi: i == 2)),
        ],
      ]),
      const SizedBox(height: 10),
      const Cap('Reglas de la época'),
      const SizedBox(height: 6),
      ListBlock([for (final r in e.rules) _ruleRow(r)]),
      const SizedBox(height: 8),
      const Note('Tu ciudad principal queda guardada tal cual y no avanza mientras juegas la época. Las épocas no cuentan para el ranking.',
          icon: Icons.lock_clock_outlined),
      const SizedBox(height: 12),
      if (hasSave)
        Row(children: [
          Expanded(flex: 4, child: HsButton('Reiniciar', kind: BtnKind.sec, block: true, onTap: () => start(true))),
          const SizedBox(width: 8),
          Expanded(flex: 5, child: HsButton('Continuar ${e.id}', block: true, onTap: () => start(false))),
        ])
      else
        Row(children: [
          Expanded(child: HsButton('Volver', kind: BtnKind.sec, block: true, onTap: () => Navigator.pop(ctx))),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: HsButton('Empezar en ${e.id}', block: true, onTap: () => start(true))),
        ]),
    ]);
  });
}

// =====================================================================
// Resultado de la época
// =====================================================================

Future<void> showEraEndDialog(BuildContext context, WidgetRef ref, {bool record = true}) async {
  final g = ref.read(gameProvider);
  final e = g.eraCfg;
  if (e == null) return;
  final medal = g.eraMedal;
  final nw = g.eraScore;
  if (record) await Storage.recordEra(e.id, medal, nw);
  if (!context.mounted) return;
  final top = e.medals.last;
  await showHsDialog(context, dismissible: false, builder: (ctx) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: _medalColors[medal],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Hc.line, width: 2),
            boxShadow: He.chip,
          ),
          child: const Icon(Icons.emoji_events_outlined, color: Hc.line, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Cap('Fin de época · dic ${e.endYear}'),
            Text(medal == 0 ? 'Sin medalla' : 'Medalla de ${medalNames[medal].toLowerCase()}', style: Ht.title),
          ]),
        ),
      ]),
      const SizedBox(height: 12),
      SideQuote(e.quoteFor(medal)),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: Cap(_metricName(e))),
        Text('${_goalValue(e, nw)} / ${_goalValue(e, top)}', style: Ht.mini.copyWith(color: Hc.ink)),
      ]),
      const SizedBox(height: 6),
      Meter((nw / top).clamp(0.0, 1.0), large: true),
      const SizedBox(height: 4),
      SizedBox(
        height: 14,
        child: LayoutBuilder(builder: (c, k) {
          return Stack(clipBehavior: Clip.none, children: [
            for (var i = 0; i < 3; i++)
              Positioned(
                left: (k.maxWidth * e.medals[i] / top - 40).clamp(0.0, k.maxWidth - 40),
                width: 40,
                child: Text(medalNames[i + 1], textAlign: i == 2 ? TextAlign.right : TextAlign.center, style: Ht.mini.copyWith(fontSize: 10)),
              ),
          ]);
        }),
      ),
      const SizedBox(height: 10),
      StatGrid([
        Stat('Viviendas', '${g.props.where((p) => !p.isClient).length}'),
        Stat('Ventas', intg(g.stat('sales'))),
        Stat('Rentas cobradas', money(g.stat('rentTotal'), compact: true), color: Hc.ok),
        Stat('Efectivo', money(g.cash, compact: true), color: Hc.acc),
      ]),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(
          child: HsButton('Reintentar', kind: BtnKind.sec, block: true, onTap: () async {
            Navigator.pop(ctx);
            await enterEra(ref, e, fresh: true);
          }),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: HsButton('Volver a mi ciudad', block: true, onTap: () async {
            Navigator.pop(ctx);
            await leaveEra(context, ref);
          }),
        ),
      ]),
    ]);
  });
}

/// Sale de la época y, si la ciudad principal avanzó mientras tanto, enseña el informe.
/// Abre la partida (época o ciudad) en un Shell nuevo, venga de donde venga.
void _openGame(BuildContext context) {
  Navigator.of(context).pushAndRemoveUntil(
    PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (c, a, b) => const Shell(),
      transitionsBuilder: (c, a, b, child) => FadeTransition(opacity: a, child: child),
    ),
    (_) => false,
  );
}

Future<void> leaveEra(BuildContext context, WidgetRef ref) async {
  final ok = await exitEra(ref);
  if (!context.mounted) return;
  if (!ok) {
    // Se entró en la época desde la portada sin ciudad propia: se vuelve a la portada.
    Money.scale = 1;
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => TitleScreen(hasSave: false, onContinue: () {})), (_) => false);
    return;
  }
  Navigator.of(context).popUntil((r) => r.isFirst);
  final g = ref.read(gameProvider);
  final r = g.offlineReport;
  if (r != null) {
    g.offlineReport = null;
    await push(context, OfflineScreen(report: r));
  }
}

// =====================================================================
// Banda del periódico en el mapa
// =====================================================================

class EraBanner extends StatelessWidget {
  final Game g;
  const EraBanner(this.g, {super.key});
  @override
  Widget build(BuildContext context) {
    final e = g.eraCfg;
    if (e == null) return const SizedBox.shrink();
    final h = g.news.isNotEmpty ? g.news.first : null;
    const ink = Color(0xFF1E1A14);
    return Transform.rotate(
      angle: -0.017,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 5, 10, 6),
        decoration: BoxDecoration(
          color: const Color(0xFFE9DFC6),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Hc.line, width: 2),
          boxShadow: He.e1,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Expanded(child: Text(e.masthead, maxLines: 1, overflow: TextOverflow.ellipsis, style: _t(EraFonts.fraktur, 14, ink, h: 1.1))),
            Text(g.eraOver ? 'ÚLTIMA' : 'EXTRA', style: _t(Hf.body, 9, const Color(0xFFB8432F), w: FontWeight.w800, ls: 1)),
          ]),
          Text((h?.title ?? e.headline).toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: _head(21, ink).copyWith(height: 1.05)),
          if (h != null && h.body.isNotEmpty)
            Text(h.body, maxLines: 1, overflow: TextOverflow.ellipsis, style: _t(EraFonts.serif, 11, const Color(0xFF554B3C), italic: true, h: 1.25)),
        ]),
      ),
    );
  }
}
