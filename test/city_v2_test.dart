import 'package:flutter_test/flutter_test.dart';
import 'package:corner_cutters/game/city.dart';

void main() {
  test('ciudades v2: sierra siempre, ríos y puentes frecuentes, parcelas sobre suelo edificable', () {
    var rivers = 0, rails = 0, seas = 0, bridges = 0;
    const n = 40;
    for (var s = 1; s <= n; s++) {
      final c = CityGen.generate(s * 7919, version: 2);
      int count(int t) => c.tiles.where((x) => x == t).length;
      expect(count(Tile.mountain), greaterThan(0), reason: 'semilla ${s * 7919} sin montañas');
      if (count(Tile.river) > 0) rivers++;
      if (count(Tile.rail) > 0) rails++;
      if (count(Tile.water) > 20) seas++;
      if (count(Tile.bridge) > 0) bridges++;
      for (final l in c.lots) {
        for (var y = l.y; y < l.y + l.d; y++) {
          for (var x = l.x; x < l.x + l.w; x++) {
            expect(c.t(x, y), Tile.lot);
          }
        }
      }
      expect(c.lots.where((l) => l.landmark != null), isNotEmpty);
    }
    // ignore: avoid_print
    print('v2 en $n semillas: ríos $rivers, puentes $bridges, tren $rails, mar $seas');
    expect(rivers, greaterThan(n ~/ 3));
    expect(bridges, greaterThan(0));
  });

  test('la ciudad v1 de una partida antigua no cambia', () {
    final a = CityGen.generate(20261022);
    final b = CityGen.generate(20261022, version: 1);
    expect(a.lots.length, b.lots.length);
    expect(a.lots.every((l) => l.gen == 1), isTrue);
  });
}
