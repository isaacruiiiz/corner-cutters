import 'package:flutter_test/flutter_test.dart';
import 'package:corner_cutters/game/city.dart';

void main() {
  test('La ciudad se genera igual con la misma semilla', () {
    final a = CityGen.generate(42);
    final b = CityGen.generate(42);
    expect(a.lots.length, b.lots.length);
    expect(a.name, b.name);
    expect(a.lots.length, greaterThan(100));
  });

  test('Nombres de ciudad antiguos se traducen a los nuevos', () {
    expect(currentCityName('Lakemont'), cityNames[5]);
    expect(currentCityName('Villabruma'), 'Villabruma');
  });

  test('Ninguna calle cruza la playa', () {
    for (final seed in [1, 42, 999]) {
      final c = CityGen.generate(seed);
      for (var y = 0; y < c.h; y++) {
        for (var x = 0; x < c.w; x++) {
          final t = c.t(x, y);
          if (t == Tile.road || t == Tile.avenue) {
            // Ninguna calle desemboca directamente en el mar (siempre queda arena delante).
            expect(c.t(x, y + 1) == Tile.water && y + 1 < c.h, isFalse, reason: 'seed $seed ($x,$y)');
          }
        }
      }
    }
  });
}
