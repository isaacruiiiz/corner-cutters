import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../game/city.dart';
import '../../game/data.dart';
import '../../game/engine.dart';
import '../../game/model.dart';

// =====================================================================
// Tabla de equivalencias (presentación): parcela del juego → arquetipo
// del estilo A "Ciudad cálida". No toca el modelo: solo lee zona,
// tamaño, altura y estilo de cada parcela.
// =====================================================================

/// Arquetipos del estilo A.
const kArchetypes = [
  'casa', 'chalet', 'bloque', 'casco', 'brown', 'fire', 'torre',
  'deco', 'campus', 'fabrica', 'cont', 'tienda', 'iglesia',
];

/// Arquetipo para una parcela según su zona, huella (1×1, 2×1/1×2, 2×2), altura y estilo.
/// Las ciudades de la versión 2 usan un surtido más amplio y variantes de color (_v1, _v2).
String archetypeOf(Lot l) {
  if (l.landmark != null) return l.landmark!;
  if (l.gen >= 2) return _archetypeV2(l);
  final s = l.style;
  final big = l.w == 2 && l.d == 2;
  final wide = !big && (l.w == 2 || l.d == 2);
  if (big) return s.isEven ? 'torre' : 'deco';
  switch (l.zone) {
    case Zone.cen:
      if (wide) return s % 3 == 0 ? 'iglesia' : 'campus';
      if (l.height >= 28) return 'fire';
      return const ['bloque', 'casco', 'brown', 'bloque'][s % 4];
    case Zone.uni:
      if (wide) return s % 3 == 0 ? 'fabrica' : 'campus';
      return const ['brown', 'bloque', 'tienda', 'casco', 'cont', 'brown', 'bloque', 'fire'][s % 8];
    case Zone.fam:
      if (wide) return s.isEven ? 'iglesia' : 'fabrica';
      return const ['casco', 'brown', 'casa', 'tienda', 'casco', 'casa', 'brown', 'bloque'][s % 8];
    case Zone.res:
      if (wide) return 'iglesia';
      return s % 3 == 0 ? 'casa' : 'chalet';
  }
}

String _archetypeV2(Lot l) {
  final s = l.style;
  final v = s % 3;
  final k = s ~/ 3;
  final big = l.w == 2 && l.d == 2;
  final wide = !big && (l.w == 2 || l.d == 2);
  List<String> pool;
  if (big) {
    pool = l.zone == Zone.cen || l.height >= 50 ? const ['cristal', 'torre', 'deco', 'cristal'] : const ['torre', 'deco', 'cristal'];
  } else if (wide) {
    pool = switch (l.zone) {
      Zone.cen => const ['campus', 'loft', 'iglesia', 'adosadas'],
      Zone.uni => const ['campus', 'fabrica', 'loft', 'adosadas'],
      Zone.fam => const ['adosadas', 'fabrica', 'loft', 'adosadas', 'iglesia'],
      Zone.res => const ['masia', 'adosadas', 'masia'],
    };
  } else {
    pool = switch (l.zone) {
      Zone.cen => l.height >= 30
          ? const ['fire', 'atico', 'sesenta', 'ensanche', 'hotel', 'chaflan']
          : const ['ensanche', 'modernista', 'atico', 'bloque', 'chaflan', 'casco', 'ensanche', 'brown', 'modernista', 'chaflan'],
      Zone.uni => const ['brown', 'bloque', 'tienda', 'casco', 'cont', 'sesenta', 'ensanche', 'fire', 'hotel', 'chaflan'],
      Zone.fam => const ['casco', 'brown', 'casa', 'tienda', 'atico', 'sesenta', 'bloque', 'modernista', 'gasolinera', 'chaflan'],
      Zone.res => const ['casa', 'chalet', 'atico', 'chalet', 'casa', 'gasolinera'],
    };
  }
  final a = pool[k % pool.length];
  return v == 0 ? a : '${a}_v$v';
}

// =====================================================================
// DLC de épocas: arquetipos propios de cada época (assets/eras/<id>/sprites).
// Solo se usan con una época activa; el modo principal no pasa por aquí.
// =====================================================================

/// Arquetipo de época para una parcela (misma huella que la parcela).
/// Los monumentos también cambian: en 1888 no hay torre de televisión ni estadio.
String? eraArchetypeOf(String era, Lot l) {
  final s = l.style;
  final lm = l.landmark;
  if (lm != null) return _eraLandmark[era]?[lm];
  final big = l.w == 2 && l.d == 2;
  final wide = !big && (l.w == 2 || l.d == 2);
  final pools = _eraPools[era];
  if (pools == null) return null;
  final List<String> pool;
  if (big) {
    pool = pools.big;
  } else if (wide) {
    pool = pools.wide;
  } else {
    final tall = l.zone == Zone.cen && (l.height >= 30 || s % 4 == 0);
    pool = tall && pools.tall.isNotEmpty ? pools.tall : pools.small;
  }
  return pool[(s ~/ 3 + s) % pool.length];
}

class _EraPools {
  final List<String> big, wide, small, tall;
  const _EraPools(this.big, this.wide, this.small, this.tall);
}

/// Surtido por época y huella. Repetir un nombre lo hace más frecuente.
const _eraPools = <String, _EraPools>{
  '1888': _EraPools(['finca_ensanche', 'fabrica_vapor', 'finca_ensanche', 'mercado_hierro', 'palacete'], ['cuadras', 'iglesia_neogotica', 'cuadras'],
      ['casa_cos', 'colmado', 'casa_cos', 'casa_cos', 'colmado', 'kiosco_musica'], []),
  '1929': _EraPools(['banco', 'fabrica_dientes', 'banco_v1', 'fabrica_dientes', 'palacio_exposiciones'], ['cine', 'cochera_tranvias', 'cine_v1'],
      ['vecinos_deco', 'tienda_deco', 'vecinos_deco_v1', 'gasolinera_deco', 'vecinos_deco_v2', 'tienda_deco', 'chaflan_deco', 'vecinos_deco'],
      ['torre_deco', 'hotel_deco', 'vecinos_deco_v1', 'chaflan_deco']),
  '1980': _EraPools(['torre_brutalista', 'nave_abandonada', 'polideportivo', 'torre_brutalista'], ['colmena', 'mercado_barrio', 'colmena'],
      ['bloque_ladrillo', 'local_persiana', 'bloque_ladrillo', 'recreativos', 'oficinas_70', 'gasolinera_80', 'local_persiana'],
      ['bloque_ladrillo', 'oficinas_70']),
  '2005': _EraPools(['urbanizacion', 'centro_comercial', 'multicines', 'urbanizacion'], ['adosados'],
      ['obra_nueva', 'chalet_piscina', 'obra_nueva', 'grua_obra', 'torre_cristal', 'chalet_piscina', 'rotonda'], ['torre_cristal', 'obra_nueva']),
  '2020': _EraPools(['coworking'], ['rehabilitado', 'coliving', 'mercado_gourmet'],
      ['bloque_terrazas', 'piso_turistico', 'dark_kitchen', 'hotel_boutique', 'fachada_verde', 'piso_turistico', 'electrolinera'],
      ['bloque_terrazas', 'fachada_verde', 'torre_jardines']),
  '2050': _EraPools(['granja_vertical', 'biodomo', 'granja_vertical'], ['bloque_muro', 'escuela_solar', 'hyperloop'],
      ['torre_madera', 'anfibio', 'hub_drones', 'torre_madera', 'torre_eolica', 'plaza_flotante'], ['torre_madera', 'hub_drones', 'torre_eolica']),
};

/// Monumentos por época (misma huella que el de la ciudad actual). Sin entrada: el de la ciudad actual.
const _eraLandmark = <String, Map<String, String>>{
  '1888': {'estadio': 'estacion_hierro', 'torre_tv': 'kiosco_musica', 'estacion': 'estacion_hierro', 'hospital': 'teatro', 'museo': 'palacete',
      'colegio': 'iglesia_neogotica', 'plaza_fuente': 'kiosco_musica'},
  '1929': {'estadio': 'palacio_exposiciones', 'torre_tv': 'torre_deco', 'estacion': 'palacio_exposiciones', 'hospital': 'banco',
      'museo': 'rascacielos_deco', 'colegio': 'cochera_tranvias'},
  '1980': {'torre_tv': 'torre_telefonica', 'estacion': 'polideportivo', 'hospital': 'torre_brutalista', 'colegio': 'mercado_barrio'},
  '2005': {'torre_tv': 'torre_bala', 'estacion': 'multicines', 'hospital': 'centro_comercial', 'museo': 'museo_titanio'},
  '2020': {'torre_tv': 'torre_jardines', 'colegio': 'mercado_gourmet'},
  '2050': {'estadio': 'arcologia', 'torre_tv': 'torre_eolica', 'estacion': 'biodomo', 'hospital': 'arcologia', 'museo': 'granja_vertical',
      'colegio': 'escuela_solar', 'plaza_fuente': 'plaza_flotante'},
};

/// Estado visual del sprite (normal, ruina, obra, reformada, alquilada).
String spriteStateOf(PState? s, {bool listed = false}) {
  if (s == null) return listed ? 'ruina' : 'normal';
  return switch (s) {
    PState.ruina => 'ruina',
    PState.obra => 'obra',
    PState.lista || PState.buscando || PState.venta => 'reformada',
    PState.alquilada => 'alquilada',
  };
}

/// Estado del sprite de una parcela con los datos actuales de la partida.
/// En edificios con varias viviendas manda la obra; si no, la alquilada.
String lotSpriteState(Game g, int lotId) {
  PState? best;
  for (final p in g.props) {
    if (p.lotId != lotId) continue;
    if (p.state == PState.obra) {
      best = PState.obra;
      break;
    }
    if (best == null || p.state == PState.alquilada) best = p.state;
  }
  if (best == null) {
    for (final l in g.listings) {
      // Las subastas son viviendas habitables; las demás, ruinas.
      if (l.lotId == lotId) return l.auction && !l.building ? 'reformada' : 'ruina';
    }
  }
  return spriteStateOf(best);
}

// =====================================================================
// Atlas: carga los PNG + manifest y guarda máscaras para el toque.
// =====================================================================

class SpriteInfo {
  final String name;
  final int w, h, ax, ay, fx, fy;
  final ui.Image image;
  final Uint8List rgba;
  SpriteInfo(this.name, this.w, this.h, this.ax, this.ay, this.fx, this.fy, this.image, this.rgba);

  bool opaqueAt(int u, int v) {
    if (u < 0 || v < 0 || u >= w || v >= h) return false;
    return rgba[(v * w + u) * 4 + 3] > 40;
  }
}

class SpriteAtlas {
  SpriteAtlas._();
  static final SpriteAtlas instance = SpriteAtlas._();

  final Map<String, SpriteInfo> _s = {};
  final Map<String, ui.Image> _outline = {};
  Future<void>? _loading;
  bool get ready => _s.isNotEmpty;

  /// Época activa (null en el modo principal) y sprites de épocas ya cargados («1929:banco_normal»).
  String? _era;
  final Map<String, SpriteInfo> _eraS = {};
  final Map<String, Future<void>> _eraLoading = {};

  /// Activa los sprites de una época (o los del modo principal con null).
  Future<void> useEra(String? id) async {
    _era = id;
    if (id == null) return;
    await (_eraLoading[id] ??= _loadEra(id));
  }

  Future<void> _loadEra(String id) async {
    final dir = 'assets/eras/$id/sprites';
    final raw = await rootBundle.loadString('$dir/manifest.json');
    final man = (jsonDecode(raw) as Map<String, dynamic>)['sprites'] as Map<String, dynamic>;
    await Future.wait(man.entries.map((e) async {
      final m = e.value as Map<String, dynamic>;
      final data = await rootBundle.load('$dir/${e.key}');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final img = (await codec.getNextFrame()).image;
      final bd = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      final fp = (m['footprint'] as List).cast<num>();
      final name = '$id:${e.key.replaceAll('.png', '')}';
      _eraS[name] = SpriteInfo(name, img.width, img.height, (m['anchor_x'] as num).toInt(), (m['anchor_y'] as num).toInt(),
          fp[0].toInt(), fp[1].toInt(), img, bd!.buffer.asUint8List());
    }));
  }

  /// Altura máxima por encima del ancla (para el margen superior del mapa).
  static const maxAbove = 124.0;

  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    final raw = await rootBundle.loadString('assets/sprites/A/manifest.json');
    final man = (jsonDecode(raw) as Map<String, dynamic>)['sprites'] as Map<String, dynamic>;
    // En paralelo: hay más de 200 sprites pequeños.
    await Future.wait(man.entries.map((e) async {
      final m = e.value as Map<String, dynamic>;
      final data = await rootBundle.load('assets/sprites/A/${e.key}');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final img = (await codec.getNextFrame()).image;
      final bd = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      final fp = (m['footprint'] as List).cast<num>();
      final name = e.key.replaceAll('.png', '');
      _s[name] = SpriteInfo(name, img.width, img.height, (m['anchor_x'] as num).toInt(), (m['anchor_y'] as num).toInt(),
          fp[0].toInt(), fp[1].toInt(), img, bd!.buffer.asUint8List());
    }));
  }

  /// Sprite de un arquetipo (o variante _vN) en un estado. Si la variante no tiene ese estado
  /// (ruina y obra son comunes), usa el del arquetipo base.
  SpriteInfo? get(String archetype, String state) {
    final i = archetype.indexOf('_v');
    final base = i > 0 && RegExp(r'_v\d$').hasMatch(archetype) ? archetype.substring(0, i) : archetype;
    return _s['${archetype}_$state'] ?? _s['${base}_$state'] ?? _s['${archetype}_normal'] ?? _s['${base}_normal'];
  }

  /// Sprite de una parcela y si va en espejo (las parcelas 1×2 usan el sprite 2×1 reflejado).
  (SpriteInfo, bool)? forLot(Lot l, String state) {
    final era = _era;
    if (era != null) {
      final a = eraArchetypeOf(era, l);
      if (a != null) {
        final es = _eraS['$era:${a}_$state'] ?? _eraS['$era:${a}_normal'];
        if (es != null) return (es, l.w == 1 && l.d == 2);
      }
    }
    final s = get(archetypeOf(l), state);
    if (s == null) return null;
    return (s, l.w == 1 && l.d == 2);
  }

  /// Contorno de 1 px alrededor de la silueta visible (imagen de w+2 × h+2).
  Future<ui.Image> outline(SpriteInfo s) async {
    final cached = _outline[s.name];
    if (cached != null) return cached;
    final w = s.w + 2, h = s.h + 2;
    final out = Uint8List(w * h * 4);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final u = x - 1, v = y - 1;
        if (s.opaqueAt(u, v)) continue;
        if (s.opaqueAt(u - 1, v) || s.opaqueAt(u + 1, v) || s.opaqueAt(u, v - 1) || s.opaqueAt(u, v + 1)) {
          final i = (y * w + x) * 4;
          out[i] = 0xFF;
          out[i + 1] = 0xEC;
          out[i + 2] = 0xAA;
          out[i + 3] = 0xFF;
        }
      }
    }
    final buf = await ui.ImmutableBuffer.fromUint8List(out);
    final desc = ui.ImageDescriptor.raw(buf, width: w, height: h, pixelFormat: ui.PixelFormat.rgba8888);
    final codec = await desc.instantiateCodec();
    final img = (await codec.getNextFrame()).image;
    _outline[s.name] = img;
    return img;
  }
}

/// Dibuja un sprite con el ancla en [anchor] (vértice superior de la casilla de origen).
void paintSprite(Canvas c, SpriteInfo s, Offset anchor, {bool mirror = false, Paint? paint}) {
  final p = paint ?? (Paint()..filterQuality = FilterQuality.none);
  if (!mirror) {
    c.drawImage(s.image, Offset(anchor.dx - s.ax, anchor.dy - s.ay), p);
    return;
  }
  c.save();
  c.translate(anchor.dx, anchor.dy - s.ay);
  c.scale(-1, 1);
  c.drawImage(s.image, Offset(-s.ax.toDouble(), 0), p);
  c.restore();
}

/// Rectángulo que ocupa el sprite de una parcela en coordenadas del mapa.
Rect spriteRect(SpriteInfo s, Offset anchor, {bool mirror = false}) {
  final left = mirror ? anchor.dx - (s.w - s.ax) : anchor.dx - s.ax;
  return Rect.fromLTWH(left, anchor.dy - s.ay, s.w.toDouble(), s.h.toDouble());
}

/// ¿El punto [q] (coordenadas del mapa) toca un píxel visible del sprite?
bool spriteHit(SpriteInfo s, Offset anchor, Offset q, {bool mirror = false}) {
  final r = spriteRect(s, anchor, mirror: mirror);
  if (!r.contains(q)) return false;
  var u = (q.dx - r.left).floor();
  final v = (q.dy - r.top).floor();
  if (mirror) u = s.w - 1 - u;
  return s.opaqueAt(u, v);
}

// =====================================================================
// Miniatura 54 × 54 para filas de lista y cabeceras de hoja.
// =====================================================================

class LotThumb extends StatefulWidget {
  final Lot lot;
  final String state;
  final double size;
  const LotThumb({super.key, required this.lot, required this.state, this.size = 54});
  @override
  State<LotThumb> createState() => _LotThumbState();
}

class _LotThumbState extends State<LotThumb> {
  @override
  void initState() {
    super.initState();
    if (!SpriteAtlas.instance.ready) {
      SpriteAtlas.instance.load().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sp = SpriteAtlas.instance.ready ? SpriteAtlas.instance.forLot(widget.lot, widget.state) : null;
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: const Color(0xFF16322F),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF050B0B), width: 2),
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          stops: [0, 0.18],
          colors: [Color(0x55000000), Color(0x00000000)],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: sp == null ? null : CustomPaint(painter: _ThumbPainter(sp.$1, sp.$2)),
      ),
    );
  }
}

class _ThumbPainter extends CustomPainter {
  final SpriteInfo s;
  final bool mirror;
  _ThumbPainter(this.s, this.mirror);
  @override
  void paint(Canvas canvas, Size size) {
    // Escala entera cuando cabe; si el sprite es grande, se reduce para que se vea entero.
    final fit = (size.width - 8) / s.w < (size.height - 6) / s.h ? (size.width - 8) / s.w : (size.height - 6) / s.h;
    final k = fit >= 1 ? fit.floorToDouble() : fit;
    canvas.save();
    canvas.translate((size.width - s.w * k) / 2, size.height - 3 - s.h * k);
    canvas.scale(k);
    if (mirror) {
      canvas.translate(s.w.toDouble(), 0);
      canvas.scale(-1, 1);
    }
    canvas.drawImage(s.image, Offset.zero, Paint()..filterQuality = FilterQuality.none);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ThumbPainter o) => o.s != s || o.mirror != mirror;
}
