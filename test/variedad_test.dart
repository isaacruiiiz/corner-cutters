import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:corner_cutters/game/city.dart';
import 'package:corner_cutters/game/engine.dart';
import 'package:corner_cutters/ui/map/sprites.dart';
import 'package:corner_cutters/ui/minigames/obras2.dart';

Set<String> _manifest(String dir) {
  final j = jsonDecode(File('$dir/manifest.json').readAsStringSync()) as Map<String, dynamic>;
  return (j['sprites'] as Map<String, dynamic>).keys.toSet();
}

void main() {
  group('Ciudades v3: equipamientos sin tocar el resto', () {
    test('misma semilla: v3 = v2 salvo los equipamientos', () {
      for (final s in [7, 42, 20261022, 99991]) {
        final a = CityGen.generate(s, version: 2);
        final b = CityGen.generate(s, version: 3);
        expect(b.version, 3);
        expect(a.lots.length, b.lots.length);
        expect(a.streets.map((e) => e.name).toList(), b.streets.map((e) => e.name).toList());
        for (var i = 0; i < a.lots.length; i++) {
          final la = a.lots[i], lb = b.lots[i];
          expect([lb.x, lb.y, lb.w, lb.d, lb.style], [la.x, la.y, la.w, la.d, la.style]);
          if (la.landmark != null) expect(lb.landmark, la.landmark);
          if (lb.landmark != la.landmark) expect(kCivicLandmarks, contains(lb.landmark));
        }
        expect(b.lots.where((l) => kCivicLandmarks.contains(l.landmark)), isNotEmpty);
      }
    });

    test('los equipamientos no suben el valor cercano', () {
      final c = CityGen.generate(42, version: 3);
      for (final l in c.lots.where((l) => l.landmark == null)) {
        final real = c.lots.any((o) =>
            o.landmark != null && !kCivicLandmarks.contains(o.landmark) && (o.cx - l.cx).abs() <= 4 && (o.cy - l.cy).abs() <= 4);
        expect(c.nearLandmark(l), real);
      }
    });

    test('las partidas guardadas en v2 siguen cargando su ciudad v2', () {
      final g = Game()..newGame(5);
      expect(g.city.version, 3);
      final j = g.toJson()..['cityV'] = 2;
      final b = Game()..loadJson(j);
      expect(b.city.version, 2);
      expect(b.city.lots.any((l) => kCivicLandmarks.contains(l.landmark)), isFalse);
    });
  });

  group('Sprites: cada arquetipo que pide el mapa existe', () {
    test('ciudad actual (con monumentos y equipamientos)', () {
      final man = _manifest('assets/sprites/A');
      for (final s in [1, 2, 3, 42, 20261022]) {
        final c = CityGen.generate(s, version: 3);
        for (final l in c.lots) {
          final a = archetypeOf(l);
          final base = a.replaceAll(RegExp(r'_v\d$'), '');
          expect(man.contains('${a}_normal.png') || man.contains('${base}_normal.png'), isTrue, reason: a);
        }
      }
    });

    test('las seis épocas, monumentos incluidos', () {
      for (final era in ['1888', '1929', '1980', '2005', '2020', '2050']) {
        final man = _manifest('assets/eras/$era/sprites');
        final main = _manifest('assets/sprites/A');
        final used = <String>{};
        for (final s in [3, 11, 42]) {
          final c = CityGen.generate(s, name: 'Alba Nova', version: 3);
          for (final l in c.lots) {
            final a = eraArchetypeOf(era, l);
            if (a == null) {
              // Sin versión de época: el monumento de la ciudad actual.
              expect(l.landmark, isNotNull);
              expect(main.contains('${l.landmark}_normal.png'), isTrue, reason: '$era ${l.landmark}');
              continue;
            }
            used.add(a);
            for (final st in ['normal', 'ruina', 'obra', 'reformada', 'alquilada']) {
              expect(man.contains('${a}_$st.png'), isTrue, reason: '$era $a $st');
            }
          }
        }
        // Las ciudades de época ya no tienen solo cuatro tipos.
        expect(used.length, greaterThanOrEqualTo(8), reason: '$era: $used');
      }
    });
  });

  group('Minijuegos: encargos al azar', () {
    test('la bolsa de muebles no repite hasta agotar los desbloqueados', () {
      final open = kFurniture.where((f) => f.minLv <= 4).length;
      final seen = <String>{};
      for (var i = 0; i < open; i++) {
        seen.add(FurnitureBag.draw(4).id);
      }
      expect(seen.length, open);
      expect(seen.every((id) => kFurniture.firstWhere((f) => f.id == id).minLv <= 4), isTrue);
    });

    test('el mismo encargo se mantiene durante la obra', () {
      final key = Object();
      final a = FurnitureBag.forWork(key, 12);
      for (var i = 0; i < 5; i++) {
        expect(FurnitureBag.forWork(key, 12), same(a));
      }
      final d = DecoPick.forWork(key, '1929');
      expect(DecoPick.forWork(key, '1929'), same(d));
    });

    test('épocas del pack: su mueble sale el primero, y papeles y pinturas de la época', () {
      const papers = {'1980': 'circulos', '2005': 'gotele', '2020': 'tropical', '2050': 'fibra'};
      for (final era in ['1980', '2005', '2020', '2050']) {
        expect(FurnitureBag.draw(1, era).id, kEraFurniture[era]!.first.id);
        var own = false;
        for (var i = 0; i < 300; i++) {
          final d = DecoPick.draw(era);
          if (d.paper && d.pattern!.id == papers[era]) own = true;
        }
        expect(own, isTrue);
      }
      // Al volver a la ciudad normal no salen muebles de época.
      for (var i = 0; i < 20; i++) {
        expect(kFurniture.map((f) => f.id), contains(FurnitureBag.draw(12).id));
      }
    });

    test('decoración: salen papel y pintura, y el papel encaja con la época', () {
      var paper = 0, paint = 0;
      for (var i = 0; i < 400; i++) {
        final d = DecoPick.draw('1888');
        if (d.paper) {
          paper++;
          expect(['damasco', 'rayas', 'tulipan'], contains(d.pattern!.id));
        } else {
          paint++;
        }
      }
      expect(paper, greaterThan(100));
      expect(paint, greaterThan(100));
    });

    test('cada mueble tiene piezas y todas caben en el lienzo', () {
      for (final f in kFurniture) {
        expect(f.parts.length, greaterThanOrEqualTo(4), reason: f.id);
        for (final p in f.parts) {
          expect(p.x >= 0 && p.y >= 0 && p.x + p.w <= 200 && p.y + p.h <= 150, isTrue, reason: '${f.id} ${p.label}');
        }
      }
    });
  });
}
