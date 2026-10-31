import 'package:flutter/material.dart';

/// Tokens del sistema de diseño "cristal sobre el mapa" (Corner Cutters).
/// Teal profundo, dorado apagado y estados desaturados. El color nunca decora: significa.
class Hc {
  static const bg = Color(0xFF0E2221);
  static const bgDeep = Color(0xFF0A1A19);
  static const panel = Color(0xFF17302F);
  static const panelHi = Color(0xFF1D3C3A);
  static const panelIn = Color(0xFF102726);
  static const line = Color(0xFF050B0B);
  static const lineSoft = Color(0xFF2C4B48);
  static const ink = Color(0xFFECE4D0);
  static const mut = Color(0xFF8FB0A8);
  static const dim = Color(0xFF5D7D76);
  static const acc = Color(0xFFE3A93B);
  static const accHi = Color(0xFFF2C25F);
  static const accLo = Color(0xFF6D4D0C);
  static const accDeep = Color(0xFFD99A2B);
  static const onAcc = Color(0xFF1A1304);
  static const ok = Color(0xFF4FC08D);
  static const okHi = Color(0xFF78D9AB);
  static const okLo = Color(0xFF1D6B4A);
  static const warn = Color(0xFFE3A93B);
  static const bad = Color(0xFFE2675B);
  static const badHi = Color(0xFFEE8579);
  static const badLo = Color(0xFF7A2A22);
  static const info = Color(0xFF5AA6D6);
  static const crit = Color(0xFFFFD35C);
  static const paper = Color(0xFFECE4D0);
  static const onPaper = Color(0xFF1A1304);
  static const paperMut = Color(0xFF5A4A28);
  static const boardTop = Color(0xFF244544);
  static const boardBot = Color(0xFF15292A);
}

/// Familias tipográficas.
class Hf {
  static const display = 'Jersey';
  static const body = 'Manrope';
}

/// Estilos de texto. Jersey 15 es más pequeña que Manrope: tamaños ya multiplicados (×1,2).
/// Cifras siempre tabulares.
class Ht {
  static TextStyle _d(double s, {Color c = Hc.ink, double h = 1.1}) => TextStyle(
        fontFamily: Hf.display,
        fontSize: s,
        height: h,
        color: c,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
  static TextStyle _b(double s, FontWeight w, {Color c = Hc.ink, double h = 1.43}) =>
      TextStyle(fontFamily: Hf.body, fontSize: s, fontWeight: w, height: h, color: c);

  static final display = _d(41, h: 1.0);
  /// H1 de panel y hoja.
  static final title = _d(34, h: 1.05);
  static final h2 = _d(25, h: 1.1);
  /// Título de tarjeta / fila destacada.
  static final card = _d(22, h: 1.1);
  static final numXl = _d(43);
  /// Cifra grande.
  static final numL = _d(34);
  /// Cifra de stat tile.
  static final numM = _d(26, h: 1.1);
  /// Cifra del HUD.
  static final numS = _d(20, h: 1.15);
  static final body = _b(14, FontWeight.w500);
  static final bodyB = _b(14, FontWeight.w700, h: 1.3);
  static final small = _b(12, FontWeight.w500, c: Hc.mut, h: 1.35);
  static final mini = _b(11, FontWeight.w500, c: Hc.mut, h: 1.3);
  /// Etiqueta "cap": mayúsculas, 9,5 w800.
  static final cap = TextStyle(
      fontFamily: Hf.body,
      fontSize: 9.5,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.3,
      height: 1.2,
      color: Hc.mut);
  static final quote = TextStyle(
      fontFamily: Hf.body,
      fontSize: 12.5,
      fontWeight: FontWeight.w500,
      fontStyle: FontStyle.italic,
      height: 1.45,
      color: Hc.mut);
  static final btn = TextStyle(
      fontFamily: Hf.body, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2);
}

/// Sombras duras (sin desenfoque).
class He {
  /// Reposo: (0,3) negro 50 %.
  static const e1 = [BoxShadow(color: Color(0x80000000), offset: Offset(0, 3))];
  static const e2 = [BoxShadow(color: Color(0x80000000), offset: Offset(0, 4))];
  static const pop = [BoxShadow(color: Hc.accLo, offset: Offset(0, 3))];
  static const chip = [BoxShadow(color: Color(0x80000000), offset: Offset(0, 2))];
}

/// Radios.
class Hr {
  static const xs = 6.0, sm = 8.0, md = 12.0, lg = 16.0, xl = 20.0;
  static const tag = 7.0, btn = 10.0, tile = 12.0, hud = 12.0, panel = 18.0, sheet = 20.0;
}

/// Cristal: fondos translúcidos de cada capa y el velo.
class Hg {
  /// HUD, barra de navegación, raíl y píldoras: rgba(16,38,37,.80) + blur 8.
  static const hud = Color(0xCC102625);
  static const blur = 8.0;
  /// Panel de pestaña (.94), hoja (.95) y diálogo (.97).
  static const panel = Color(0xF00E2221);
  static const sheet = Color(0xF20E2221);
  static const dialog = Color(0xF70E2221);
  /// Velo tras panel o diálogo: rgba(6,16,16,.58) + blur 2,5.
  static const veil = Color(0x94061010);
  static const veilBlur = 2.5;
  /// Filo interior superior de 1 px.
  static const hilite = Color(0x14FFECBE);
  /// Contorno de selección en el mapa.
  static const select = Color(0xFFFFECAA);
}

ThemeData buildTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: Hc.bg,
    fontFamily: Hf.body,
    colorScheme: const ColorScheme.dark(
      primary: Hc.acc,
      onPrimary: Hc.onAcc,
      secondary: Hc.info,
      surface: Hc.panel,
      onSurface: Hc.ink,
      error: Hc.bad,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: Hc.ink, displayColor: Hc.ink, fontFamily: Hf.body),
    sliderTheme: const SliderThemeData(
      activeTrackColor: Hc.acc,
      inactiveTrackColor: Hc.panelIn,
      thumbColor: Hc.accHi,
      overlayColor: Color(0x33E3A93B),
      trackHeight: 8,
    ),
  );
}
