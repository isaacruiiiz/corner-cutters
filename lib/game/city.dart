import 'dart:math' as math;
import 'dart:typed_data';

import '../core/rng.dart';
import 'data.dart';

part 'city_v2.dart';

/// Tipos de casilla del mapa.
class Tile {
  static const water = 0;
  static const beach = 1;
  static const grass = 2;
  static const road = 3;
  static const lot = 4;
  static const park = 5;
  static const plaza = 6;
  static const avenue = 7;
  /// Ciudades de la versión 2.
  static const rail = 8;
  static const bridge = 9;
  static const dock = 10;
  static const mountain = 11;
  static const river = 12;

  static bool isWater(int t) => t == water || t == river;
  static bool isRoad(int t) => t == road || t == avenue || t == bridge;
}

enum Roof { flat, pitched, terrace }

/// Parcela con un edificio.
class Lot {
  final int id;
  final int x, y, w, d;
  final Zone zone;
  final int district;
  final int height; // píxeles
  final int style; // índice de paleta
  final Roof roof;
  final Kind kind;
  /// Versión del generador que la creó (cambia el surtido de edificios).
  final int gen;
  /// Monumento de la ciudad (no se compra): catedral, estadio, mercado, faro, ayuntamiento, torre.
  String? landmark;
  int street;
  int number;
  Lot({
    required this.id,
    required this.x,
    required this.y,
    required this.w,
    required this.d,
    required this.zone,
    required this.district,
    required this.height,
    required this.style,
    required this.roof,
    required this.kind,
    this.gen = 1,
    this.landmark,
    this.street = 0,
    this.number = 1,
  });

  double get cx => x + w / 2;
  double get cy => y + d / 2;
}

class Street {
  final int id;
  final String name;
  final bool horizontal; // a lo largo de x
  final int coord; // y si horizontal, x si vertical
  final bool avenue;
  Street(this.id, this.name, this.horizontal, this.coord, this.avenue);
}

class District {
  final int id;
  final String name;
  final Zone zone;
  final double priceFactor;
  final double cx, cy;
  District(this.id, this.name, this.zone, this.priceFactor, this.cx, this.cy);
}

class Tree {
  final double x, y;
  final int v;
  Tree(this.x, this.y, this.v);
}

/// Equipamientos (ciudades v3): no se venden pero tampoco suben el valor cercano,
/// así la economía queda igual que en las ciudades v2.
const kCivicLandmarks = {'estacion', 'hospital', 'museo', 'colegio', 'plaza_fuente'};

class CityMap {
  final int seed;
  final String name;
  final int w, h;
  final Uint8List tiles;
  final Uint8List districtAt;
  final List<Lot> lots;
  final List<Street> streets;
  final List<District> districts;
  final List<Tree> trees;
  /// Versión del generador (1 = ciudades antiguas; 2 = con río, montañas, puerto y monumentos).
  final int version;
  final CityTrait trait;
  CityMap(this.seed, this.name, this.w, this.h, this.tiles, this.districtAt, this.lots, this.streets,
      this.districts, this.trees, {this.version = 1, this.trait = CityTrait.equilibrada});

  int t(int x, int y) => (x < 0 || y < 0 || x >= w || y >= h) ? Tile.water : tiles[y * w + x];

  bool _near(Lot l, int r, bool Function(int) test) {
    for (var y = l.y - r; y < l.y + l.d + r; y++) {
      for (var x = l.x - r; x < l.x + l.w + r; x++) {
        if (x < 0 || y < 0 || x >= w || y >= h) continue;
        if (test(tiles[y * w + x])) return true;
      }
    }
    return false;
  }

  final Map<int, bool> _lmCache = {};

  /// Hay un monumento a menos de 4 casillas: +5 % de valor.
  bool nearLandmark(Lot l) => _lmCache.putIfAbsent(l.id, () {
        for (final o in lots) {
          if (o.landmark == null || o.id == l.id || kCivicLandmarks.contains(o.landmark)) continue;
          if ((o.cx - l.cx).abs() <= 4 && (o.cy - l.cy).abs() <= 4) return true;
        }
        return false;
      });

  /// Rasgos fijos de una parcela, deterministas por semilla (no consumen azar de la partida).
  List<Trait> traitsOf(Lot l) {
    if (l.landmark != null) return const [];
    final h = hash2(l.id * 31 + 7, seed);
    final out = <Trait>[];
    if (l.height >= 14 && l.zone != Zone.res && h % 10 < 4) out.add(Trait.sinAscensor);
    if (_near(l, 1, (t) => t == Tile.avenue || t == Tile.rail) ||
        (l.zone == Zone.cen && (h >> 4) % 3 == 0) ||
        (l.zone == Zone.uni && (h >> 4) % 4 == 0)) {
      out.add(Trait.ruido);
    }
    if (l.roof == Roof.terrace || l.kind == Kind.atico) out.add(Trait.terraza);
    if ((l.zone == Zone.res || l.zone == Zone.fam) && (h >> 8) % 3 == 0) out.add(Trait.parking);
    if (_near(l, 3, (t) => t == Tile.water)) out.add(Trait.vistas);
    return out;
  }
  District districtOf(int x, int y) => districts[districtAt[y.clamp(0, h - 1) * w + x.clamp(0, w - 1)]];
  Lot lot(int id) => lots[id];
  String address(Lot l) => '${streets[l.street].name} ${l.number}';
}

/// Nombres inventados (ninguno corresponde a un lugar real).
const cityNames = [
  'Villabruma', 'Puerto Ciruelo', 'Marisalta', 'Castrovela', 'Brisamar del Cardo',
  'Torrecana', 'Valdeolas', 'Rocaserena', 'Fuentelisa', 'Lindamar',
];

/// Nombres de ciudad de versiones anteriores → nombre nuevo (mismo índice).
const _legacyCityNames = [
  'Alba Nova', 'Port Lumen', 'Vallmar', 'North Haven', 'Ciudad Ferrara',
  'Lakemont', 'Santa Brisa', 'Rivergate', 'Nueva Olivera', 'East Calder',
];

/// Traduce un nombre de ciudad guardado por una versión anterior.
String? currentCityName(String? n) {
  if (n == null) return null;
  final i = _legacyCityNames.indexOf(n);
  return i < 0 ? n : cityNames[i];
}

const _districtNames = [
  'Barrio Candil', 'La Pañoleta', 'Ribera Mansa', 'El Terraplén', 'Huerta Sosegada', 'Los Faroles',
  'Cerro Pimienta', 'La Tejeruela', 'Arrabal del Junco', 'Vega Torcida', 'Las Carracas', 'Altozano Gris',
  'Puerto Menta', 'Ensanche Turquesa', 'Bajo Cardo', 'Las Veletas Rotas', 'Loma Ganchillo', 'El Remolino',
];

const _streetNames = [
  'C/ del Gato Sereno', 'Av. del Ladrillo', 'C/ Tres Cerillas', 'C/ del Reloj Parado', 'C/ Siete Ventanas', 'C/ de la Nube Baja',
  'Av. de las Grúas', 'C/ del Ancla Torcida', 'C/ Papel Mojado', 'C/ del Farol Tuerto', 'C/ Vinagrera', 'C/ del Botón',
  'C/ Media Luna Verde', 'C/ del Tejado Azul', 'C/ Limonar Viejo', 'C/ del Caracol', 'C/ Pluma Larga', 'C/ del Silbato',
  'C/ Cometa Roja', 'C/ del Peine', 'C/ Almohada', 'C/ del Ladrillo Feliz', 'C/ Gaviota Coja', 'C/ del Escalón',
  'Av. del Andamio', 'C/ del Rastrillo', 'C/ Hojalata', 'C/ del Candado', 'C/ Persiana', 'C/ del Desván',
  'C/ Teja Suelta', 'C/ del Azulejo', 'C/ Baldosa', 'C/ del Tabique', 'C/ Cemento Fresco', 'C/ Viga Maestra',
  'C/ del Ático', 'C/ Mortero', 'C/ de la Plomada', 'C/ del Capataz', 'C/ Escuadra', 'C/ del Ovillo',
  'Av. del Vaivén', 'C/ Trébol Rojo', 'C/ del Columpio', 'C/ Mandarina', 'C/ del Gorrión Listo', 'C/ Tintero',
];

/// Genera una ciudad ficticia pero realista a partir de una semilla.
class CityGen {
  static String nameFor(int seed) => cityNames[hash2(seed, 7) % cityNames.length];

  static CityMap generate(int seed, {int w = 56, int h = 44, String? name, int version = 1}) {
    if (version >= 2) return CityGenV2.generate(seed, w: w, h: h, name: name, civic: version >= 3);
    final r = Rng(hash2(seed, 101));
    final tiles = Uint8List(w * h)..fillRange(0, w * h, Tile.grass);
    final cityName = name ?? cityNames[hash2(seed, 7) % cityNames.length];

    // --- Costa: el borde inferior izquierdo (y alto) es mar, con playa.
    final coast = List<int>.filled(w, 0);
    var depth = r.range(5, 7).toDouble();
    for (var x = 0; x < w; x++) {
      depth += r.rangeD(-0.9, 0.9);
      depth = depth.clamp(3.0, 9.0);
      // la costa se retira hacia el este (más ciudad a la derecha)
      final d = (depth - x * 0.06).clamp(0.0, 9.0);
      coast[x] = (h - d).round();
    }
    for (var x = 0; x < w; x++) {
      for (var y = coast[x]; y < h; y++) {
        tiles[y * w + x] = Tile.water;
      }
      for (var y = coast[x] - 1; y >= coast[x] - 1 && y >= 0; y--) {
        if (coast[x] < h) tiles[y * w + x] = Tile.beach;
      }
    }

    // --- Red de calles: avenidas y calles en cuadrícula con desplazamientos.
    final vx = <int>[]; // x de calles verticales
    final hy = <int>[]; // y de calles horizontales
    var cx = r.range(2, 4);
    while (cx < w - 2) {
      vx.add(cx);
      cx += r.range(5, 6);
    }
    var cy = r.range(2, 4);
    while (cy < h - 4) {
      hy.add(cy);
      cy += r.range(4, 6);
    }
    final aveV = vx.isEmpty ? -1 : vx[vx.length ~/ 2];
    final aveH = hy.isEmpty ? -1 : hy[hy.length ~/ 2];
    for (final x in vx) {
      for (var y = 0; y < h; y++) {
        if (tiles[y * w + x] != Tile.water) tiles[y * w + x] = x == aveV ? Tile.avenue : Tile.road;
      }
    }
    for (final y in hy) {
      for (var x = 0; x < w; x++) {
        if (tiles[y * w + x] != Tile.water) tiles[y * w + x] = y == aveH ? Tile.avenue : Tile.road;
      }
    }
    // Paseo marítimo: calle paralela a la playa.
    for (var x = 0; x < w; x++) {
      final y = coast[x] - 2;
      if (y > 0 && tiles[y * w + x] == Tile.grass) tiles[y * w + x] = Tile.road;
    }

    // --- Barrios (Voronoi) con zona asignada.
    final nD = 9;
    final districts = <District>[];
    final names = List<String>.from(_districtNames);
    for (var i = names.length - 1; i > 0; i--) {
      final j = r.nextInt(i + 1);
      final t = names[i];
      names[i] = names[j];
      names[j] = t;
    }
    for (var i = 0; i < nD; i++) {
      final dx = r.rangeD(4, w - 4.0);
      final dy = r.rangeD(3, h - 8.0);
      // Zona según posición: centro en medio, residencial alto lejos del mar (arriba),
      // universitaria y familiar alrededor.
      final distC = math.sqrt(math.pow((dx - w * .5) / w, 2) + math.pow((dy - h * .45) / h, 2));
      Zone z;
      if (distC < 0.17) {
        z = Zone.cen;
      } else if (dy < h * 0.28 && r.chance(0.65)) {
        z = Zone.res;
      } else if (r.chance(0.5)) {
        z = Zone.uni;
      } else {
        z = Zone.fam;
      }
      districts.add(District(i, names[i], z, r.rangeD(0.9, 1.1), dx, dy));
    }
    // Garantiza al menos un barrio de cada zona.
    for (final z in Zone.values) {
      if (!districts.any((d) => d.zone == z)) {
        final idx = r.nextInt(nD);
        final o = districts[idx];
        districts[idx] = District(o.id, o.name, z, o.priceFactor, o.cx, o.cy);
      }
    }
    final districtAt = Uint8List(w * h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        var best = 0;
        var bd = 1e9;
        for (final d in districts) {
          final dd = math.pow(x - d.cx, 2) + math.pow((y - d.cy) * 1.15, 2);
          if (dd < bd) {
            bd = dd.toDouble();
            best = d.id;
          }
        }
        districtAt[y * w + x] = best;
      }
    }

    // --- Manzanas: rellenar con parques o parcelas.
    final lots = <Lot>[];
    final trees = <Tree>[];
    final xs = [-1, ...vx, w];
    final ys = [-1, ...hy, h];
    final used = Uint8List(w * h);
    for (var bi = 0; bi < xs.length - 1; bi++) {
      for (var bj = 0; bj < ys.length - 1; bj++) {
        final x0 = xs[bi] + 1, x1 = xs[bi + 1] - 1;
        final y0 = ys[bj] + 1, y1 = ys[bj + 1] - 1;
        if (x1 < x0 || y1 < y0) continue;
        final mid = districtAt[((y0 + y1) ~/ 2) * w + (x0 + x1) ~/ 2];
        final zone = districts[mid].zone;
        final parkChance = zone == Zone.cen ? 0.10 : (zone == Zone.res ? 0.22 : 0.13);
        final isPark = r.chance(parkChance);
        if (isPark) {
          final lake = r.chance(0.35) && (x1 - x0) >= 3 && (y1 - y0) >= 3;
          for (var y = y0; y <= y1; y++) {
            for (var x = x0; x <= x1; x++) {
              if (tiles[y * w + x] != Tile.grass) continue;
              final inLake = lake && x > x0 && x < x1 && y > y0 && y < y1 && r.chance(0.85);
              tiles[y * w + x] = inLake ? Tile.water : Tile.park;
              if (!inLake) {
                final n = r.range(1, 3);
                for (var k = 0; k < n; k++) {
                  trees.add(Tree(x + r.rangeD(0.15, 0.85), y + r.rangeD(0.15, 0.85), r.nextInt(3)));
                }
              }
            }
          }
          continue;
        }
        // Parcelas.
        for (var y = y0; y <= y1; y++) {
          for (var x = x0; x <= x1; x++) {
            if (used[y * w + x] == 1 || tiles[y * w + x] != Tile.grass) continue;
            var lw = 1, ld = 1;
            if (zone == Zone.cen && r.chance(0.55)) {
              lw = 2;
              ld = 2;
            } else if (zone != Zone.res && r.chance(0.3)) {
              if (r.chance(0.5)) {
                lw = 2;
              } else {
                ld = 2;
              }
            }
            bool fits(int a, int b) {
              for (var yy = y; yy < y + b; yy++) {
                for (var xx = x; xx < x + a; xx++) {
                  if (xx > x1 || yy > y1) return false;
                  if (used[yy * w + xx] == 1 || tiles[yy * w + xx] != Tile.grass) return false;
                }
              }
              return true;
            }

            if (!fits(lw, ld)) {
              lw = 1;
              ld = 1;
            }
            if (!fits(1, 1)) continue;
            // En residencial, deja jardines.
            if (zone == Zone.res && r.chance(0.32)) {
              tiles[y * w + x] = Tile.park;
              used[y * w + x] = 1;
              trees.add(Tree(x + 0.5, y + 0.5, r.nextInt(3)));
              continue;
            }
            if (zone != Zone.res && r.chance(0.04)) {
              tiles[y * w + x] = Tile.plaza;
              used[y * w + x] = 1;
              continue;
            }
            for (var yy = y; yy < y + ld; yy++) {
              for (var xx = x; xx < x + lw; xx++) {
                used[yy * w + xx] = 1;
                tiles[yy * w + xx] = Tile.lot;
              }
            }
            int height;
            Roof roof;
            Kind kind;
            switch (zone) {
              case Zone.cen:
                height = lw * ld >= 4 ? r.range(34, 70) : r.range(18, 36);
                roof = r.chance(0.3) ? Roof.terrace : Roof.flat;
                kind = r.weighted({Kind.piso: 3, Kind.familiar: 2, Kind.atico: 1.2, Kind.estudio: 1});
              case Zone.uni:
                height = r.range(11, 24);
                roof = r.chance(0.2) ? Roof.terrace : Roof.flat;
                kind = r.weighted({Kind.estudio: 2, Kind.piso: 3, Kind.familiar: 0.6});
              case Zone.fam:
                height = r.range(9, 19);
                roof = r.chance(0.25) ? Roof.pitched : Roof.flat;
                kind = r.weighted({Kind.piso: 2, Kind.familiar: 3, Kind.atico: 0.5});
              case Zone.res:
                height = r.range(6, 9);
                roof = r.chance(0.8) ? Roof.pitched : Roof.terrace;
                kind = r.weighted({Kind.familiar: 2, Kind.atico: 1.5});
            }
            final d = districtAt[(y + ld ~/ 2) * w + x + lw ~/ 2];
            lots.add(Lot(
              id: lots.length,
              x: x,
              y: y,
              w: lw,
              d: ld,
              zone: zone,
              district: d,
              height: height,
              style: r.nextInt(8),
              roof: roof,
              kind: kind,
            ));
          }
        }
      }
    }
    // Árboles sueltos en hierba sobrante.
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (tiles[y * w + x] == Tile.grass && r.chance(0.5)) {
          trees.add(Tree(x + r.rangeD(0.2, 0.8), y + r.rangeD(0.2, 0.8), r.nextInt(3)));
        }
      }
    }

    // --- Calles con nombre.
    final sn = List<String>.from(_streetNames);
    for (var i = sn.length - 1; i > 0; i--) {
      final j = r.nextInt(i + 1);
      final t = sn[i];
      sn[i] = sn[j];
      sn[j] = t;
    }
    final streets = <Street>[];
    var ni = 0;
    for (final y in hy) {
      final av = y == aveH;
      var n = sn[ni++ % sn.length];
      if (av && !n.startsWith('Av.')) n = n.replaceFirst('C/', 'Av.');
      streets.add(Street(streets.length, n, true, y, av));
    }
    for (final x in vx) {
      final av = x == aveV;
      var n = sn[ni++ % sn.length];
      if (av && !n.startsWith('Av.')) n = n.replaceFirst('C/', 'Av.');
      streets.add(Street(streets.length, n, false, x, av));
    }
    if (streets.isEmpty) streets.add(Street(0, 'C/ del Gato Sereno', true, 0, false));
    // Asigna a cada parcela la calle más cercana y numera.
    final counters = <int, int>{};
    for (final l in lots) {
      var best = 0;
      var bd = 1e9;
      for (final s in streets) {
        final dd = s.horizontal ? (l.cy - (s.coord + 0.5)).abs() : (l.cx - (s.coord + 0.5)).abs();
        if (dd < bd) {
          bd = dd;
          best = s.id;
        }
      }
      l.street = best;
    }
    final byStreet = <int, List<Lot>>{};
    for (final l in lots) {
      byStreet.putIfAbsent(l.street, () => []).add(l);
    }
    byStreet.forEach((sid, ls) {
      final s = streets[sid];
      ls.sort((a, b) => s.horizontal ? a.x.compareTo(b.x) : a.y.compareTo(b.y));
      for (final l in ls) {
        final c = (counters[sid] ?? 0) + 1;
        counters[sid] = c;
        l.number = c * 2 - (l.id % 2);
      }
    });

    _shoreline(tiles, w, h, coast);
    return CityMap(seed, cityName, w, h, tiles, districtAt, lots, streets, districts, trees);
  }

  /// Retoque de la costa al final (no consume azar ni toca parcelas, parques ni hierba):
  /// las calles no cruzan la playa, la playa gana una segunda fila y se rellenan
  /// las calas de una casilla que dejaban la orilla en dientes de sierra.
  static void _shoreline(Uint8List tiles, int w, int h, List<int> coast) {
    bool isRoad(int t) => t == Tile.road || t == Tile.avenue;
    for (var x = 0; x < w; x++) {
      final c = coast[x];
      if (c >= h) continue;
      // Fila de playa original: si una calle la pisó, vuelve a ser arena.
      if (c - 1 >= 0 && isRoad(tiles[(c - 1) * w + x])) tiles[(c - 1) * w + x] = Tile.beach;
      // Segunda fila de playa (sobre el agua), salvo que deje el mar sin ninguna casilla.
      if (c + 1 < h && tiles[c * w + x] == Tile.water) tiles[c * w + x] = Tile.beach;
    }
    // Calas sueltas: agua de mar rodeada de arena por tres lados.
    for (var pass = 0; pass < 2; pass++) {
      for (var x = 0; x < w; x++) {
        for (var y = math.max(0, coast[x]); y < h; y++) {
          if (tiles[y * w + x] != Tile.water) continue;
          int at(int xx, int yy) => (xx < 0 || yy < 0 || xx >= w || yy >= h) ? Tile.water : tiles[yy * w + xx];
          var sand = 0;
          for (final o in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
            if (at(x + o.$1, y + o.$2) == Tile.beach) sand++;
          }
          if (sand >= 3) tiles[y * w + x] = Tile.beach;
        }
      }
    }
    // Arena aislada que quedó en el agua (una sola casilla sin tierra al lado) vuelve al mar.
    for (var x = 0; x < w; x++) {
      for (var y = math.max(0, coast[x]); y < h; y++) {
        if (tiles[y * w + x] != Tile.beach) continue;
        final up = y > 0 ? tiles[(y - 1) * w + x] : Tile.water;
        final l = x > 0 ? tiles[y * w + x - 1] : Tile.water;
        final r = x < w - 1 ? tiles[y * w + x + 1] : Tile.water;
        if (up == Tile.water && l == Tile.water && r == Tile.water) tiles[y * w + x] = Tile.water;
      }
    }
  }
}
