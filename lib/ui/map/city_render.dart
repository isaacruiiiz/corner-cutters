import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/rng.dart';
import '../../game/city.dart';
import 'sprites.dart';

/// Geometría isométrica: rombo de 40 × 20 píxeles por casilla (estilo A).
class Iso {
  static const tw = 40.0;
  static const th = 20.0;
  static const hw = tw / 2, hh = th / 2;
  static const maxH = SpriteAtlas.maxAbove;
  static const base = 16.0;
  final CityMap city;
  late final double ox, oy, width, height;
  Iso(this.city) {
    ox = city.h * hw + 10;
    oy = maxH + 10;
    width = (city.w + city.h) * hw + 20;
    height = (city.w + city.h) * hh + maxH + 10 + base + 10;
  }

  /// Vértice superior de la casilla (x, y).
  Offset p(double x, double y) => Offset(ox + (x - y) * hw, oy + (x + y) * hh);

  /// Casilla bajo un punto de la imagen (a nivel de suelo).
  (int, int) tileAt(Offset q) {
    final dx = (q.dx - ox) / hw;
    final dy = (q.dy - oy) / hh;
    return (((dy + dx) / 2).floor(), ((dy - dx) / 2).floor());
  }

  /// Sprite de la parcela en un estado: (sprite, espejo, ancla).
  (SpriteInfo, bool, Offset)? sprite(Lot l, [String state = 'normal']) {
    if (!SpriteAtlas.instance.ready) return null;
    final s = SpriteAtlas.instance.forLot(l, state);
    if (s == null) return null;
    return (s.$1, s.$2, p(l.x.toDouble(), l.y.toDouble()));
  }

  /// Rectángulo visible del edificio.
  Rect bounds(Lot l, [String state = 'normal']) {
    final s = sprite(l, state);
    if (s != null) return spriteRect(s.$1, s.$3, mirror: s.$2);
    final n = p(l.x.toDouble(), l.y.toDouble());
    final e = p((l.x + l.w).toDouble(), l.y.toDouble());
    final w = p(l.x.toDouble(), (l.y + l.d).toDouble());
    final s2 = p((l.x + l.w).toDouble(), (l.y + l.d).toDouble());
    return Rect.fromLTRB(w.dx, n.dy - 40, e.dx, s2.dy);
  }

  /// Silueta aproximada (huella extruida hasta lo alto del sprite) para recortes y avisos.
  Path silhouette(Lot l, {double extra = 0, String state = 'normal'}) {
    final b = bounds(l, state);
    final n = p(l.x.toDouble(), l.y.toDouble());
    final e = p((l.x + l.w).toDouble(), l.y.toDouble());
    final s = p((l.x + l.w).toDouble(), (l.y + l.d).toDouble());
    final w = p(l.x.toDouble(), (l.y + l.d).toDouble());
    final h = n.dy - b.top + extra;
    return Path()
      ..moveTo(n.dx, n.dy - h)
      ..lineTo(e.dx, e.dy - h)
      ..lineTo(e.dx, e.dy)
      ..lineTo(s.dx, s.dy)
      ..lineTo(w.dx, w.dy)
      ..lineTo(w.dx, w.dy - h)
      ..close();
  }

  /// Punto sobre el tejado (donde apoya el pin).
  Offset top(Lot l, [String state = 'normal']) {
    final b = bounds(l, state);
    final c = p(l.x + l.w / 2, l.y + l.d / 2);
    return Offset(c.dx, b.top + 2);
  }

  /// Centro de la huella a nivel de suelo.
  Offset ground(Lot l) => p(l.x + l.w / 2, l.y + l.d / 2);

  int depth(Lot l) => (l.x + l.w - 1) + (l.y + l.d - 1);
}

/// Paleta del suelo (temas cosméticos). Los edificios son sprites y no se tiñen por estado.
class MapPalette {
  final Color grass, grassDark, grassHi, park, flower, road, avenue, lane, curb, sidewalk, paving, pavingLine, plaza, plazaB, beach, water, waterHi, slab, slabDark, tree, treeDark, treeHi, trunk;
  /// Velo global del tema (atardecer, noche).
  final Color? wash;
  /// Ciudades v2: roca y nieve de las montañas, grava del tren, madera del muelle, río.
  final Color rock, rockDark, snow, gravel, wood, river;
  const MapPalette({
    required this.grass,
    required this.grassDark,
    required this.grassHi,
    required this.park,
    required this.flower,
    required this.road,
    required this.avenue,
    required this.lane,
    required this.curb,
    required this.sidewalk,
    required this.paving,
    required this.pavingLine,
    required this.plaza,
    required this.plazaB,
    required this.beach,
    required this.water,
    required this.waterHi,
    required this.slab,
    required this.slabDark,
    required this.tree,
    required this.treeDark,
    required this.treeHi,
    required this.trunk,
    this.wash,
    this.rock = const Color(0xFF8A8F7E),
    this.rockDark = const Color(0xFF6B705F),
    this.snow = const Color(0xFFF2EEDC),
    this.gravel = const Color(0xFF8C8273),
    this.wood = const Color(0xFF9C7450),
    this.river = const Color(0xFF4F93A8),
  });

  static const dia = MapPalette(
    grass: Color(0xFF6DA457),
    grassDark: Color(0xFF5E954C),
    grassHi: Color(0xFF82B865),
    park: Color(0xFF78B05E),
    flower: Color(0xFFF2D27A),
    road: Color(0xFF4A5052),
    avenue: Color(0xFF41464A),
    lane: Color(0xFFD9D2BC),
    curb: Color(0xFF8A877C),
    sidewalk: Color(0xFFB4AE9D),
    paving: Color(0xFFC9C1AC),
    pavingLine: Color(0xFFB8AF98),
    plaza: Color(0xFFD9CDAE),
    plazaB: Color(0xFFCBBE9C),
    beach: Color(0xFFE6D5A2),
    water: Color(0xFF4A8CB0),
    waterHi: Color(0xFF7DB4CF),
    slab: Color(0xFF2E3A36),
    slabDark: Color(0xFF1C2523),
    tree: Color(0xFF3F8B4E),
    treeDark: Color(0xFF2E6B3B),
    treeHi: Color(0xFF6CB46C),
    trunk: Color(0xFF6B4A2E),
  );

  static const atardecer = MapPalette(
    grass: Color(0xFF7D9550),
    grassDark: Color(0xFF6D8546),
    grassHi: Color(0xFF93A85E),
    park: Color(0xFF86A05A),
    flower: Color(0xFFFFC46B),
    road: Color(0xFF4D4346),
    avenue: Color(0xFF453B3E),
    lane: Color(0xFFE6C8A8),
    curb: Color(0xFF8E7A70),
    sidewalk: Color(0xFFB59E8E),
    paving: Color(0xFFCDB29A),
    pavingLine: Color(0xFFBBA08A),
    plaza: Color(0xFFDDBE9C),
    plazaB: Color(0xFFCDAE8C),
    beach: Color(0xFFEAC890),
    water: Color(0xFF6283AA),
    waterHi: Color(0xFFE7A77B),
    slab: Color(0xFF3A2F33),
    slabDark: Color(0xFF241D20),
    tree: Color(0xFF55804A),
    treeDark: Color(0xFF3F6338),
    treeHi: Color(0xFF8AA95E),
    trunk: Color(0xFF6B4A2E),
    wash: Color(0x26FF8A3C),
  );

  static const noche = MapPalette(
    grass: Color(0xFF2E4D3C),
    grassDark: Color(0xFF274334),
    grassHi: Color(0xFF365A46),
    park: Color(0xFF325842),
    flower: Color(0xFFFFD86B),
    road: Color(0xFF20272A),
    avenue: Color(0xFF1B2225),
    lane: Color(0xFF6E7468),
    curb: Color(0xFF3A423F),
    sidewalk: Color(0xFF3F4744),
    paving: Color(0xFF4C524B),
    pavingLine: Color(0xFF424841),
    plaza: Color(0xFF5B5A52),
    plazaB: Color(0xFF515048),
    beach: Color(0xFF6D6A58),
    water: Color(0xFF1B3D53),
    waterHi: Color(0xFF3F6E8A),
    slab: Color(0xFF141C1B),
    slabDark: Color(0xFF0B1110),
    tree: Color(0xFF24533A),
    treeDark: Color(0xFF1A3F2C),
    treeHi: Color(0xFF3B7350),
    trunk: Color(0xFF3B2A1C),
    wash: Color(0x66102040),
  );

  /// DLC de épocas · 1929: suelos apagados, adoquín oscuro, agua plomiza y velo sepia.
  static const epoca1929 = MapPalette(
    grass: Color(0xFF6E7550),
    grassDark: Color(0xFF616846),
    grassHi: Color(0xFF7F865D),
    park: Color(0xFF737A52),
    flower: Color(0xFFD8C08A),
    road: Color(0xFF3E3D3A),
    avenue: Color(0xFF363532),
    lane: Color(0xFFBDB49A),
    curb: Color(0xFF7A766A),
    sidewalk: Color(0xFF9C9584),
    paving: Color(0xFFB2A88F),
    pavingLine: Color(0xFFA09680),
    plaza: Color(0xFFC2B595),
    plazaB: Color(0xFFB3A585),
    beach: Color(0xFFCFC096),
    water: Color(0xFF5A7684),
    waterHi: Color(0xFF8AA3AE),
    slab: Color(0xFF2E2F2B),
    slabDark: Color(0xFF1E1F1C),
    tree: Color(0xFF55644A),
    treeDark: Color(0xFF43503A),
    treeHi: Color(0xFF6E7D5E),
    trunk: Color(0xFF5A4030),
    wash: Color(0x1F8A6A3A),
    river: Color(0xFF5E7A86),
  );

  static const epoca1888 = MapPalette(
    grass: Color(0xFF7A7448),
    grassDark: Color(0xFF6C6640),
    grassHi: Color(0xFF8A8452),
    park: Color(0xFF7E7A4A),
    flower: Color(0xFFE0B060),
    road: Color(0xFF5A4A3A),
    avenue: Color(0xFF524336),
    lane: Color(0xFFC8B08A),
    curb: Color(0xFF8A7458),
    sidewalk: Color(0xFFA08A68),
    paving: Color(0xFFB8A07C),
    pavingLine: Color(0xFFA68E6C),
    plaza: Color(0xFFC8B08A),
    plazaB: Color(0xFFB89E78),
    beach: Color(0xFFD8C090),
    water: Color(0xFF5A7A80),
    waterHi: Color(0xFF9AB0A8),
    slab: Color(0xFF3A3026),
    slabDark: Color(0xFF2A221A),
    tree: Color(0xFF5E6B38),
    treeDark: Color(0xFF4A5630),
    treeHi: Color(0xFF76844A),
    trunk: Color(0xFF5A4030),
    wash: Color(0x268A5A2A),
    river: Color(0xFF5E7A7E),
  );

  static const epoca1980 = MapPalette(
    grass: Color(0xFF6A6E48),
    grassDark: Color(0xFF5E6240),
    grassHi: Color(0xFF7A7E54),
    park: Color(0xFF70744C),
    flower: Color(0xFFE0A060),
    road: Color(0xFF3A3436),
    avenue: Color(0xFF332E30),
    lane: Color(0xFFD8C070),
    curb: Color(0xFF6E6466),
    sidewalk: Color(0xFF8E8486),
    paving: Color(0xFFA09496),
    pavingLine: Color(0xFF8E8284),
    plaza: Color(0xFFA89A90),
    plazaB: Color(0xFF988A80),
    beach: Color(0xFFC8B890),
    water: Color(0xFF4A6A7A),
    waterHi: Color(0xFF7A9AAA),
    slab: Color(0xFF2E2626),
    slabDark: Color(0xFF1E1919),
    tree: Color(0xFF4E5A36),
    treeDark: Color(0xFF3E482A),
    treeHi: Color(0xFF66724A),
    trunk: Color(0xFF4A3628),
    wash: Color(0x1F6A3A5A),
    river: Color(0xFF4E6E7E),
  );

  static const epoca2005 = MapPalette(
    grass: Color(0xFF7DA85E),
    grassDark: Color(0xFF6E9852),
    grassHi: Color(0xFF8EBA6C),
    park: Color(0xFF86B064),
    flower: Color(0xFFFFD86B),
    road: Color(0xFF4A5056),
    avenue: Color(0xFF42484E),
    lane: Color(0xFFF2F2E8),
    curb: Color(0xFF8E9498),
    sidewalk: Color(0xFFB4B8B8),
    paving: Color(0xFFC8CCC8),
    pavingLine: Color(0xFFB4B8B4),
    plaza: Color(0xFFD8D4C8),
    plazaB: Color(0xFFC8C4B8),
    beach: Color(0xFFEAD8A8),
    water: Color(0xFF3E8AB8),
    waterHi: Color(0xFF8AC8E8),
    slab: Color(0xFF3E5A48),
    slabDark: Color(0xFF2C3A3E),
    tree: Color(0xFF5E9A50),
    treeDark: Color(0xFF4A8040),
    treeHi: Color(0xFF78B46A),
    trunk: Color(0xFF6B4A2E),
    wash: Color(0x0F80C0FF),
    river: Color(0xFF3E8AB0),
  );

  static const epoca2020 = MapPalette(
    grass: Color(0xFF5E8A5A),
    grassDark: Color(0xFF527A4E),
    grassHi: Color(0xFF6E9A6A),
    park: Color(0xFF5E9460),
    flower: Color(0xFFF2C25F),
    road: Color(0xFF343C3E),
    avenue: Color(0xFF2E3638),
    lane: Color(0xFFE8E4D0),
    curb: Color(0xFF6E7A78),
    sidewalk: Color(0xFF8E9A96),
    paving: Color(0xFFA8B2AE),
    pavingLine: Color(0xFF96A09C),
    plaza: Color(0xFFB4BAB0),
    plazaB: Color(0xFFA4AAA0),
    beach: Color(0xFFD8CCA0),
    water: Color(0xFF2E6E8A),
    waterHi: Color(0xFF6EA8C0),
    slab: Color(0xFF1F3B38),
    slabDark: Color(0xFF142826),
    tree: Color(0xFF3E7A52),
    treeDark: Color(0xFF2E6040),
    treeHi: Color(0xFF5A9A6A),
    trunk: Color(0xFF5A4030),
    wash: Color(0x14204A40),
    river: Color(0xFF2E6E8A),
  );

  static const epoca2050 = MapPalette(
    grass: Color(0xFF4F8A62),
    grassDark: Color(0xFF447A56),
    grassHi: Color(0xFF5E9A70),
    park: Color(0xFF4FA36B),
    flower: Color(0xFF7FE0D8),
    road: Color(0xFF2E3A42),
    avenue: Color(0xFF28343C),
    lane: Color(0xFF7FE0D8),
    curb: Color(0xFF5A6A72),
    sidewalk: Color(0xFF7A8A92),
    paving: Color(0xFF8E9EA6),
    pavingLine: Color(0xFF7E8E96),
    plaza: Color(0xFF9AAAB0),
    plazaB: Color(0xFF8A9AA0),
    beach: Color(0xFFB8B8A0),
    water: Color(0xFF2D6F8F),
    waterHi: Color(0xFF7FC3DA),
    slab: Color(0xFF1B2C33),
    slabDark: Color(0xFF12202A),
    tree: Color(0xFF4FA36B),
    treeDark: Color(0xFF3E8A58),
    treeHi: Color(0xFF6FC08B),
    trunk: Color(0xFF4A3A2A),
    wash: Color(0x1A40A0C0),
    river: Color(0xFF2D6F8F),
  );

  static MapPalette of(String theme) => switch (theme) {
        'atardecer' => atardecer,
        'noche' => noche,
        'epoca_1929' => epoca1929,
        'epoca_1888' => epoca1888,
        'epoca_1980' => epoca1980,
        'epoca_2005' => epoca2005,
        'epoca_2020' => epoca2020,
        'epoca_2050' => epoca2050,

        _ => dia,
      };
}

Color _shade(Color c, double f) => Color.fromARGB(
      (c.a * 255).round(),
      (c.r * 255 * f).round().clamp(0, 255),
      (c.g * 255 * f).round().clamp(0, 255),
      (c.b * 255 * f).round().clamp(0, 255),
    );

/// Pinta la ciudad completa en una imagen de píxeles (sin antialias): suelo procedural
/// en rombos de 40 × 20 y edificios con los sprites del estilo A.
class CityRenderer {
  /// [states]: estado de sprite por parcela (las que no aparecen se pintan en "normal").
  static Future<ui.Image> render(
    CityMap city, {
    Map<int, String> states = const {},
    Map<int, int> flags = const {},
    required String theme,
  }) async {
    await SpriteAtlas.instance.load();
    final iso = Iso(city);
    final pal = MapPalette.of(theme);
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final paint = Paint()..isAntiAlias = false;
    final r = Rng(hash2(city.seed, 999));

    void poly(List<Offset> pts, Color col) {
      final path = Path()..moveTo(pts[0].dx, pts[0].dy);
      for (var i = 1; i < pts.length; i++) {
        path.lineTo(pts[i].dx, pts[i].dy);
      }
      path.close();
      c.drawPath(path, paint..color = col..style = PaintingStyle.fill);
    }

    void px(double x, double y, Color col, [double w = 1, double h = 1]) {
      c.drawRect(Rect.fromLTWH(x.floorToDouble(), y.floorToDouble(), w, h), paint..color = col..style = PaintingStyle.fill);
    }

    /// Punto aleatorio dentro del rombo (k < 1 = más hacia el centro).
    Offset inside(Offset ctr, double k) {
      while (true) {
        final a = r.rangeD(-1, 1), b = r.rangeD(-1, 1);
        if (a.abs() + b.abs() <= k) return ctr + Offset(a * Iso.hw, b * Iso.hh);
      }
    }

    bool isRoad(int t) => Tile.isRoad(t);

    // --- Losa base con canto.
    final a = iso.p(0, 0), b = iso.p(city.w.toDouble(), 0), cc = iso.p(city.w.toDouble(), city.h.toDouble()), d = iso.p(0, city.h.toDouble());
    poly([d, cc, cc.translate(0, Iso.base), d.translate(0, Iso.base)], pal.slab);
    poly([cc, b, b.translate(0, Iso.base), cc.translate(0, Iso.base)], pal.slabDark);
    poly([a, b, cc, d], pal.grass);

    // --- Suelo.
    for (var y = 0; y < city.h; y++) {
      for (var x = 0; x < city.w; x++) {
        final t = city.t(x, y);
        final n = iso.p(x.toDouble(), y.toDouble());
        final e = iso.p(x + 1.0, y.toDouble());
        final s = iso.p(x + 1.0, y + 1.0);
        final w = iso.p(x.toDouble(), y + 1.0);
        final ctr = Offset((n.dx + s.dx) / 2, (n.dy + s.dy) / 2);
        switch (t) {
          case Tile.water:
            poly([n, e, s, w], pal.water);
            for (var k = 0; k < 2; k++) {
              if (r.chance(0.5)) {
                final q = inside(ctr, 0.7);
                px(q.dx, q.dy, pal.waterHi, 3, 1);
              }
            }
          case Tile.beach:
            poly([n, e, s, w], pal.beach);
            for (var k = 0; k < 4; k++) {
              final q = inside(ctr, 0.85);
              px(q.dx, q.dy, _shade(pal.beach, 0.9));
            }
          case Tile.river:
            poly([n, e, s, w], pal.river);
            if (r.chance(0.6)) {
              final q = inside(ctr, 0.6);
              px(q.dx, q.dy, pal.waterHi, 4, 1);
            }
          case Tile.bridge:
            poly([n, e, s, w], pal.river);
            final alongXb = isRoad(city.t(x - 1, y)) || isRoad(city.t(x + 1, y));
            Offset lp(Offset a, Offset b, double f) => Offset.lerp(a, b, f)!;
            if (alongXb) {
              final a0 = lp(n, w, 0.12), b0 = lp(e, s, 0.12), b1 = lp(e, s, 0.88), a1 = lp(n, w, 0.88);
              poly([a0, b0, b1, a1], pal.road);
              c.drawLine(a0, b0, paint..color = pal.lane..strokeWidth = 1);
              c.drawLine(a1, b1, paint..color = pal.lane..strokeWidth = 1);
              poly([a1, b1, b1.translate(0, 3), a1.translate(0, 3)], pal.slab);
            } else {
              final a0 = lp(n, e, 0.12), b0 = lp(w, s, 0.12), b1 = lp(w, s, 0.88), a1 = lp(n, e, 0.88);
              poly([a0, b0, b1, a1], pal.road);
              c.drawLine(a0, b0, paint..color = pal.lane..strokeWidth = 1);
              c.drawLine(a1, b1, paint..color = pal.lane..strokeWidth = 1);
              poly([a1, b1, b1.translate(0, 3), a1.translate(0, 3)], pal.slabDark);
            }
          case Tile.rail:
            poly([n, e, s, w], (x + y).isEven ? pal.grass : pal.grassDark);
            Offset at(double fx, double fy) => iso.p(x + fx, y + fy);
            poly([at(0, 0.22), at(1, 0.22), at(1, 0.78), at(0, 0.78)], pal.gravel);
            for (final fx in const [0.15, 0.4, 0.65, 0.9]) {
              c.drawLine(at(fx, 0.28), at(fx, 0.72), paint..color = pal.wood..strokeWidth = 1.5);
            }
            c.drawLine(at(0, 0.38), at(1, 0.38), paint..color = const Color(0xFF5A5A62)..strokeWidth = 1);
            c.drawLine(at(0, 0.62), at(1, 0.62), paint..color = const Color(0xFF5A5A62)..strokeWidth = 1);
          case Tile.dock:
            poly([n, e, s, w], pal.wood);
            for (var k = 1; k < 4; k++) {
              c.drawLine(Offset.lerp(n, w, k / 4)!, Offset.lerp(e, s, k / 4)!, paint..color = _shade(pal.wood, 0.8)..strokeWidth = 1);
            }
            poly([w, s, s.translate(0, 3), w.translate(0, 3)], _shade(pal.wood, 0.6));
          case Tile.road:
          case Tile.avenue:
            poly([n, e, s, w], t == Tile.avenue ? pal.avenue : pal.road);
            // Aceras donde la calle linda con otra cosa.
            const k = 0.2;
            Offset lp(Offset p0, double f) => Offset.lerp(p0, ctr, f)!;
            final edges = [
              (city.t(x, y - 1), n, e), // borde NE (y-1)
              (city.t(x + 1, y), e, s), // borde SE (x+1)
              (city.t(x, y + 1), s, w), // borde SO (y+1)
              (city.t(x - 1, y), w, n), // borde NO (x-1)
            ];
            for (final ed in edges) {
              if (isRoad(ed.$1) || Tile.isWater(ed.$1)) continue;
              poly([ed.$2, ed.$3, lp(ed.$3, k), lp(ed.$2, k)], pal.sidewalk);
              poly([lp(ed.$2, k), lp(ed.$3, k), lp(ed.$3, k + 0.05), lp(ed.$2, k + 0.05)], pal.curb);
            }
            // Marcas viales discontinuas a lo largo de la calle.
            final alongX = isRoad(city.t(x - 1, y)) || isRoad(city.t(x + 1, y));
            final alongY = isRoad(city.t(x, y - 1)) || isRoad(city.t(x, y + 1));
            if (alongX && !alongY) {
              for (var k2 = -4; k2 <= 4; k2++) {
                if (k2.abs() == 2) continue;
                px(ctr.dx + k2 * 2 - 1, ctr.dy + k2, pal.lane, 2, 1);
              }
            } else if (alongY && !alongX) {
              for (var k2 = -4; k2 <= 4; k2++) {
                if (k2.abs() == 2) continue;
                px(ctr.dx - k2 * 2 - 1, ctr.dy + k2, pal.lane, 2, 1);
              }
            } else if (alongX && alongY) {
              // Cruce: paso de cebra.
              for (var k2 = -3; k2 <= 3; k2++) {
                px(ctr.dx + k2 * 4 - 1, ctr.dy + 5 + (k2.isEven ? 0 : 0), pal.lane, 2, 1);
              }
            }
          case Tile.park:
            poly([n, e, s, w], (x + y).isEven ? pal.park : _shade(pal.park, 0.96));
            for (var k = 0; k < 3; k++) {
              final q = inside(ctr, 0.8);
              px(q.dx, q.dy, k == 0 && r.chance(0.5) ? pal.flower : pal.grassHi);
            }
          case Tile.plaza:
            poly([n, e, s, w], pal.plaza);
            poly([Offset.lerp(n, ctr, 0.5)!, Offset.lerp(e, ctr, 0.5)!, Offset.lerp(s, ctr, 0.5)!, Offset.lerp(w, ctr, 0.5)!], pal.plazaB);
          case Tile.lot:
            poly([n, e, s, w], pal.paving);
            // Junta de baldosas.
            px(ctr.dx - 10, ctr.dy, pal.pavingLine, 20, 1);
          default:
            poly([n, e, s, w], (hash2(x, y) % 5 == 0) ? pal.grassDark : pal.grass);
            for (var k = 0; k < 3; k++) {
              final q = inside(ctr, 0.85);
              px(q.dx, q.dy, k == 0 ? pal.grassHi : pal.grassDark);
            }
        }
        // Espuma en la orilla.
        if (!Tile.isWater(t) && t != Tile.bridge && t != Tile.dock && Tile.isWater(city.t(x, y + 1)) && y + 1 < city.h) {
          poly([w, s, s.translate(0, 1), w.translate(0, 1)], const Color(0xFFF2EEDC));
        }
        if (!Tile.isWater(t) && t != Tile.bridge && t != Tile.dock && Tile.isWater(city.t(x + 1, y)) && x + 1 < city.w) {
          poly([e, s, s.translate(0, 1), e.translate(0, 1)], const Color(0xFFF2EEDC));
        }
      }
    }
    // Canto frontal del agua donde el mar toca el borde.
    for (var x = 0; x < city.w; x++) {
      if (Tile.isWater(city.t(x, city.h - 1))) {
        final w = iso.p(x.toDouble(), city.h.toDouble());
        final s = iso.p(x + 1.0, city.h.toDouble());
        poly([w, s, s.translate(0, Iso.base), w.translate(0, Iso.base)], _shade(pal.water, 0.7));
      }
    }
    for (var y = 0; y < city.h; y++) {
      if (Tile.isWater(city.t(city.w - 1, y))) {
        final e = iso.p(city.w.toDouble(), y.toDouble());
        final s = iso.p(city.w.toDouble(), y + 1.0);
        poly([e, s, s.translate(0, Iso.base), e.translate(0, Iso.base)], _shade(pal.water, 0.55));
      }
    }

    // --- Objetos ordenados por profundidad (de atrás hacia delante).
    final objs = <(double, int, Object)>[];
    for (final l in city.lots) {
      objs.add((iso.depth(l) + 0.5, 0, l));
    }
    for (final t in city.trees) {
      objs.add((t.x.floor() + t.y.floor() + 0.0, 1, t));
    }
    for (var y = 0; y < city.h; y++) {
      for (var x = 0; x < city.w; x++) {
        final t = city.t(x, y);
        // Las casillas de sierra (ciudades v2) se dibujan de momento como borde de bosque.
        if (t == Tile.mountain && hash2(x * 3 + 1, y * 5 + 2) % 3 != 0) {
          final h = hash2(x * 7 + 3, y * 11 + 5);
          final tr = Tree(x + 0.3 + (h % 5) * 0.1, y + 0.3 + ((h >> 3) % 5) * 0.1, h % 3);
          objs.add((tr.x.floor() + tr.y.floor() + 0.0, 1, tr));
        }
        if (t == Tile.dock && hash2(x, y + 9) % 3 == 0) objs.add((x + y + 0.3, 2, (x, y, 'c')));
      }
    }
    objs.sort((x, y) {
      final cmp = x.$1.compareTo(y.$1);
      return cmp != 0 ? cmp : x.$2.compareTo(y.$2);
    });

    final spritePaint = Paint()..filterQuality = FilterQuality.none;
    for (final o in objs) {
      final obj = o.$3;
      if (obj is Tree) {
        final q = iso.p(obj.x, obj.y);
        final big = obj.v == 2 ? 2.0 : 0.0;
        // Sombra, tronco y copa en capas.
        px(q.dx - 5, q.dy - 1, const Color(0x33000000), 11, 3);
        px(q.dx - 1, q.dy - 6, pal.trunk, 2, 6);
        px(q.dx - 6 - big, q.dy - 15 - big * 2, pal.treeDark, 12 + big * 2, 10 + big);
        px(q.dx - 5 - big, q.dy - 18 - big * 2, pal.tree, 10 + big * 2, 8 + big);
        px(q.dx - 3, q.dy - 20 - big * 2, pal.tree, 6, 3);
        px(q.dx - 3, q.dy - 17 - big * 2, pal.treeHi, 3, 2);
        px(q.dx + 2 + big, q.dy - 11 - big, _shade(pal.treeDark, 0.85), 3, 3);
        continue;
      }
      if (obj is (int, int, String)) {
        final (x, y, kind) = obj;
        if (kind == 'c') _crane(c, iso, x, y, paint);
        continue;
      }
      final l = obj as Lot;
      final sp = iso.sprite(l, states[l.id] ?? 'normal');
      if (sp == null) continue;
      paintSprite(c, sp.$1, sp.$3, mirror: sp.$2, paint: spritePaint);
      final f = flags[l.id] ?? 0;
      if (f != 0) _levelDetails(c, spriteRect(sp.$1, sp.$3, mirror: sp.$2), f, paint);
    }

    // Velo del tema (atardecer, noche): afecta a todo el mapa por igual.
    if (pal.wash != null) {
      c.drawRect(Rect.fromLTWH(0, 0, iso.width, iso.height), Paint()..color = pal.wash!);
    }

    final pic = rec.endRecording();
    return pic.toImage(iso.width.ceil(), iso.height.ceil());
  }
}

/// Grúa portuaria amarilla.
void _crane(Canvas c, Iso iso, int x, int y, Paint paint) {
  final b = iso.p(x + 0.5, y + 0.5);
  const yel = Color(0xFFE8B43C);
  paint.style = PaintingStyle.fill;
  c.drawRect(Rect.fromLTWH(b.dx - 5, b.dy - 3, 2, 3), paint..color = const Color(0xFF3B3A44));
  c.drawRect(Rect.fromLTWH(b.dx + 3, b.dy - 3, 2, 3), paint);
  c.drawRect(Rect.fromLTWH(b.dx - 1, b.dy - 30, 2, 28), paint..color = yel);
  c.drawRect(Rect.fromLTWH(b.dx - 12, b.dy - 31, 22, 2), paint);
  c.drawRect(Rect.fromLTWH(b.dx - 4, b.dy - 34, 6, 4), paint..color = const Color(0xFFD9785B));
  c.drawRect(Rect.fromLTWH(b.dx - 11, b.dy - 29, 1, 9), paint..color = const Color(0xFF1C2523));
  c.drawRect(Rect.fromLTWH(b.dx - 13, b.dy - 20, 5, 3), paint..color = const Color(0xFF5AA6D6));
}

/// Detalles que delatan el nivel de una vivienda reformada:
/// placas solares (electricidad ≥ 18), plantas (decoración ≥ 14), toldos nuevos (carpintería ≥ 14).
void _levelDetails(Canvas c, Rect r, int flags, Paint paint) {
  paint.style = PaintingStyle.fill;
  if (flags & 1 != 0) {
    for (var k = 0; k < 2; k++) {
      final x = r.center.dx - 6 + k * 7;
      final y = r.top + 6 + k;
      c.drawRect(Rect.fromLTWH(x, y, 5, 3), paint..color = const Color(0xFF1F3550));
      c.drawRect(Rect.fromLTWH(x, y, 5, 1), paint..color = const Color(0xFF5AA6D6));
    }
  }
  if (flags & 2 != 0) {
    for (final dx in const [3.0, 10.0]) {
      c.drawRect(Rect.fromLTWH(r.left + dx, r.bottom - 14, 3, 3), paint..color = const Color(0xFF4FA05A));
      c.drawRect(Rect.fromLTWH(r.left + dx + 1, r.bottom - 15, 1, 1), paint..color = const Color(0xFFE2675B));
    }
  }
  if (flags & 4 != 0) {
    for (var k = 0; k < 3; k++) {
      c.drawRect(Rect.fromLTWH(r.left + 4 + k * 5, r.bottom - 10 + k * 2, 4, 2), paint..color = k.isEven ? const Color(0xFF4A8C6A) : const Color(0xFFECE4D0));
    }
  }
}

/// Utilidad: radio de pulsación para la selección.
double pulse(double t) => 1 - 0.45 * (0.5 - 0.5 * math.cos(t * 2 * math.pi));
