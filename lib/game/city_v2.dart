part of 'city.dart';

/// Generador de ciudades v2: costa a un lado u otro (o ninguna), río con puentes, montañas
/// en el fondo, vía de tren, puerto y monumentos. Cada semilla da un mapa y un rasgo distintos.
class CityGenV2 {
  static CityMap generate(int seed, {int w = 56, int h = 44, String? name, bool civic = false}) {
    final r = Rng(hash2(seed, 202));
    final trait = CityTrait.values[hash2(seed, 17) % CityTrait.values.length];
    final cityName = name ?? CityGen.nameFor(seed);
    final tiles = Uint8List(w * h)..fillRange(0, w * h, Tile.grass);
    int at(int x, int y) => (x < 0 || y < 0 || x >= w || y >= h) ? Tile.water : tiles[y * w + x];
    void put(int x, int y, int t) {
      if (x >= 0 && y >= 0 && x < w && y < h) tiles[y * w + x] = t;
    }

    // --- Geografía.
    final hasSea = trait == CityTrait.costera || r.chance(0.72);
    final seaRight = hasSea && r.chance(0.5); // mar en el borde x = w (si no, en y = h)
    final hasRiver = !hasSea || r.chance(0.75);
    // Siempre hay sierra al fondo; la tirada se mantiene para no mover el resto de la semilla.
    r.chance(0.8);
    const hasMountains = true;
    final hasRail = trait == CityTrait.industrial || r.chance(0.55);
    // (i, j): i recorre la costa, j es la distancia perpendicular hacia el mar.
    final n = seaRight ? h : w;
    final lim = seaRight ? w : h;
    void putIJ(int i, int j, int t) => seaRight ? put(j, i, t) : put(i, j, t);
    final coast = List<int>.filled(n, lim + 2);
    if (hasSea) {
      var depth = r.range(5, 7).toDouble();
      for (var i = 0; i < n; i++) {
        depth += r.rangeD(-0.9, 0.9);
        depth = depth.clamp(3.0, 9.0);
        final d = (depth - i * 0.06).clamp(2.0, 9.0);
        coast[i] = (lim - d).round();
        for (var j = coast[i] + 1; j < lim; j++) {
          putIJ(i, j, Tile.water);
        }
        putIJ(i, coast[i], Tile.beach);
        putIJ(i, coast[i] - 1, Tile.beach);
      }
    }

    // --- Montañas en los bordes del fondo (decorativas, no se construye).
    if (hasMountains) {
      var a = r.range(2, 3).toDouble(), b = r.range(2, 3).toDouble();
      for (var x = 0; x < w; x++) {
        a = (a + r.rangeD(-0.6, 0.6)).clamp(1.0, 4.0);
        for (var y = 0; y < a.round(); y++) {
          if (at(x, y) == Tile.grass) put(x, y, Tile.mountain);
        }
      }
      for (var y = 0; y < h; y++) {
        b = (b + r.rangeD(-0.6, 0.6)).clamp(1.0, 4.0);
        for (var x = 0; x < b.round(); x++) {
          if (at(x, y) == Tile.grass) put(x, y, Tile.mountain);
        }
      }
    }

    // --- Río: baja desde el fondo hasta el mar (o hasta el borde), dos casillas de ancho.
    if (hasRiver) {
      var c = r.rangeD(n * 0.3, n * 0.7);
      for (var j = 0; j < lim; j++) {
        c = (c + r.rangeD(-0.7, 0.7)).clamp(4.0, n - 6.0);
        final ci = c.round();
        var reachedSea = false;
        for (var k = 0; k < 2; k++) {
          final x = seaRight ? j : ci + k;
          final y = seaRight ? ci + k : j;
          final t = at(x, y);
          if (t == Tile.water) {
            reachedSea = true;
            continue;
          }
          put(x, y, Tile.river);
        }
        if (reachedSea) break;
      }
    }

    // --- Calles: cuadrícula; sobre el río, puentes; nunca sobre mar, playa ni montaña.
    final vx = <int>[];
    final hy = <int>[];
    var cx = r.range(3, 5);
    while (cx < w - 2) {
      vx.add(cx);
      cx += r.range(5, 6);
    }
    var cy = r.range(3, 5);
    while (cy < h - 3) {
      hy.add(cy);
      cy += r.range(4, 6);
    }
    final aveV = vx.isEmpty ? -1 : vx[vx.length ~/ 2];
    final aveH = hy.isEmpty ? -1 : hy[hy.length ~/ 2];
    void street(int x, int y, bool ave) {
      final t = at(x, y);
      if (t == Tile.grass || t == Tile.road || t == Tile.avenue) {
        put(x, y, ave ? Tile.avenue : Tile.road);
      } else if (t == Tile.river) {
        put(x, y, Tile.bridge);
      }
    }

    for (final x in vx) {
      for (var y = 0; y < h; y++) {
        street(x, y, x == aveV);
      }
    }
    for (final y in hy) {
      for (var x = 0; x < w; x++) {
        street(x, y, y == aveH);
      }
    }
    // Paseo marítimo.
    if (hasSea) {
      for (var i = 0; i < n; i++) {
        final j = coast[i] - 2;
        final x = seaRight ? j : i, y = seaRight ? i : j;
        if (at(x, y) == Tile.grass) put(x, y, Tile.road);
      }
    }
    // Vía de tren: atraviesa la ciudad entre dos calles.
    if (hasRail && hy.length > 2) {
      final ry = hy[1 + r.nextInt(hy.length - 2)] + 2;
      for (var x = 0; x < w; x++) {
        final t = at(x, ry);
        if (t == Tile.grass || t == Tile.river) put(x, ry, Tile.rail);
      }
    }
    // Puerto: unas casillas de muelle en la costa, cerca del centro.
    if (hasSea) {
      final start = (n * 0.35 + r.nextInt((n * 0.3).round())).round();
      final len = r.range(4, 6);
      for (var i = start; i < math.min(n, start + len); i++) {
        putIJ(i, coast[i], Tile.dock);
        putIJ(i, coast[i] + 1, Tile.dock);
      }
    }

    // --- Barrios (Voronoi). Lejos del mar, residencial alto.
    const nD = 9;
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
      final dy = r.rangeD(4, h - 6.0);
      final distC = math.sqrt(math.pow((dx - w * .5) / w, 2) + math.pow((dy - h * .45) / h, 2));
      final far = seaRight ? dx < w * 0.30 : dy < h * 0.30;
      Zone z;
      if (distC < 0.17) {
        z = Zone.cen;
      } else if (far && r.chance(0.65)) {
        z = Zone.res;
      } else if (r.chance(trait == CityTrait.universitaria ? 0.65 : (trait == CityTrait.industrial ? 0.3 : 0.5))) {
        z = Zone.uni;
      } else {
        z = Zone.fam;
      }
      final pf = r.rangeD(0.9, 1.1) * cityTraitInfo[trait]!.price;
      districts.add(District(i, names[i], z, pf, dx, dy));
    }
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

    // --- Manzanas: parques o parcelas.
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
        if (r.chance(parkChance)) {
          final lake = r.chance(0.35) && (x1 - x0) >= 3 && (y1 - y0) >= 3;
          for (var y = y0; y <= y1; y++) {
            for (var x = x0; x <= x1; x++) {
              if (tiles[y * w + x] != Tile.grass) continue;
              final inLake = lake && x > x0 && x < x1 && y > y0 && y < y1 && r.chance(0.85);
              tiles[y * w + x] = inLake ? Tile.water : Tile.park;
              if (!inLake) {
                final k = r.range(1, 3);
                for (var q = 0; q < k; q++) {
                  trees.add(Tree(x + r.rangeD(0.15, 0.85), y + r.rangeD(0.15, 0.85), r.nextInt(3)));
                }
              }
            }
          }
          continue;
        }
        for (var y = y0; y <= y1; y++) {
          for (var x = x0; x <= x1; x++) {
            if (used[y * w + x] == 1 || tiles[y * w + x] != Tile.grass) continue;
            var lw = 1, ld = 1;
            if (zone == Zone.cen && r.chance(0.5)) {
              lw = 2;
              ld = 2;
            } else if (r.chance(zone == Zone.res ? 0.18 : 0.3)) {
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
            if (zone == Zone.res && r.chance(0.30)) {
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
                height = lw * ld >= 4 ? r.range(34, 80) : r.range(18, 40);
                roof = r.chance(0.3) ? Roof.terrace : Roof.flat;
                kind = r.weighted({Kind.piso: 3, Kind.familiar: 2, Kind.atico: 1.2, Kind.estudio: 1});
              case Zone.uni:
                height = r.range(11, 26);
                roof = r.chance(0.2) ? Roof.terrace : Roof.flat;
                kind = r.weighted({Kind.estudio: 2, Kind.piso: 3, Kind.familiar: 0.6});
              case Zone.fam:
                height = r.range(8, 20);
                roof = r.chance(0.3) ? Roof.pitched : Roof.flat;
                kind = r.weighted({Kind.piso: 2, Kind.familiar: 3, Kind.atico: 0.5});
              case Zone.res:
                height = r.range(6, 10);
                roof = r.chance(0.75) ? Roof.pitched : Roof.terrace;
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
              style: r.nextInt(24),
              roof: roof,
              kind: kind,
              gen: 2,
            ));
          }
        }
      }
    }
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (tiles[y * w + x] == Tile.grass && r.chance(0.5)) {
          trees.add(Tree(x + r.rangeD(0.2, 0.8), y + r.rangeD(0.2, 0.8), r.nextInt(3)));
        }
      }
    }

    // --- Monumentos (uno o varios por ciudad; no se compran y suben el valor cercano).
    bool hasNear(Lot l, int t, int rad) {
      for (var y = l.y - rad; y < l.y + l.d + rad; y++) {
        for (var x = l.x - rad; x < l.x + l.w + rad; x++) {
          if (at(x, y) == t) return true;
        }
      }
      return false;
    }
    Lot? pickLot(bool Function(Lot) ok) {
      final c = lots.where((l) => l.landmark == null && ok(l)).toList();
      if (c.isEmpty) return null;
      return c[r.nextInt(c.length)];
    }

    const main = ['catedral', 'ayuntamiento', 'estadio', 'mercado'];
    final first = main[r.nextInt(main.length)];
    final l1 = switch (first) {
      'estadio' => pickLot((l) => l.w == 2 && l.d == 2),
      'mercado' => pickLot((l) => (l.w == 2) != (l.d == 2) && l.zone != Zone.res),
      _ => pickLot((l) => l.w == 2 && l.d == 2 && l.zone == Zone.cen) ?? pickLot((l) => l.w == 2 && l.d == 2),
    };
    l1?.landmark = first;
    if (hasSea) pickLot((l) => l.w == 1 && l.d == 1 && hasNear(l, Tile.beach, 1))?.landmark = 'faro';
    if (r.chance(0.5)) pickLot((l) => l.w == 1 && l.d == 1 && l.zone != Zone.cen)?.landmark = 'torre_tv';

    // --- Equipamientos (v3): azar aparte para no mover nada de lo que viene después.
    if (civic) {
      final r2 = Rng(hash2(seed, 303));
      Lot? pick2(bool Function(Lot) ok) {
        final c = lots.where((l) => l.landmark == null && ok(l)).toList();
        if (c.isEmpty) return null;
        return c[r2.nextInt(c.length)];
      }
      bool big(Lot l) => l.w == 2 && l.d == 2;
      bool wide(Lot l) => (l.w == 2) != (l.d == 2);
      (pick2((l) => big(l) && l.zone != Zone.res) ?? pick2(big))?.landmark = 'estacion';
      (pick2((l) => big(l) && l.zone == Zone.fam) ?? pick2(big))?.landmark = 'hospital';
      if (r2.chance(0.7)) (pick2((l) => big(l) && l.zone == Zone.cen) ?? pick2(big))?.landmark = 'museo';
      pick2((l) => wide(l) && l.zone != Zone.cen)?.landmark = 'colegio';
      for (var i = 0; i < 2; i++) {
        pick2((l) => l.w == 1 && l.d == 1 && l.zone != Zone.uni)?.landmark = 'plaza_fuente';
      }
    }

    // --- Calles con nombre y numeración.
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
      var nm = sn[ni++ % sn.length];
      if (av && !nm.startsWith('Av.')) nm = nm.replaceFirst('C/', 'Av.');
      streets.add(Street(streets.length, nm, true, y, av));
    }
    for (final x in vx) {
      final av = x == aveV;
      var nm = sn[ni++ % sn.length];
      if (av && !nm.startsWith('Av.')) nm = nm.replaceFirst('C/', 'Av.');
      streets.add(Street(streets.length, nm, false, x, av));
    }
    if (streets.isEmpty) streets.add(Street(0, 'C/ del Gato Sereno', true, 0, false));
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
    final counters = <int, int>{};
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
    return CityMap(seed, cityName, w, h, tiles, districtAt, lots, streets, districts, trees, version: civic ? 3 : 2, trait: trait);
  }
}
