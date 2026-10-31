import 'package:flutter_test/flutter_test.dart';
import 'package:corner_cutters/game/data.dart';
import 'package:corner_cutters/game/economy.dart';

void main() {
  test('k(L) del documento', () {
    expect(Eco.k(1), 1.0);
    expect(Eco.k(10), closeTo(3.43, 0.01));
    expect(Eco.k(20), closeTo(11.83, 0.01));
  });

  test('Ejemplo resuelto: piso de 50 m² ajustado a estudiantes', () {
    final lv = {Trade.ele: 4, Trade.fon: 4, Trade.alb: 5, Trade.car: 3, Trade.dec: 3};
    var cost = 0.0;
    for (final t in Trade.values) {
      cost += Eco.phaseCost(t, 50, lv[t]!);
    }
    expect(cost, closeTo(9788, 1));
    final q = Eco.quality(Sector.est, Zone.uni, lv, {for (final t in Trade.values) t: 1.0});
    expect(q, closeTo(1.0, 1e-9));
    expect(Eco.value(50, 1200, 1, q), 60000);
    expect(Eco.value(50, 1200, 1, 0), 30000);
  });

  test('Toques de albañilería a nivel 5 en 50 m²', () {
    expect(Eco.phaseWork(Trade.alb, 50, 5), closeTo(210, 0.01));
  });

  test('Venta: a y = 1 la probabilidad es del 50 %', () {
    expect(Eco.buyProb(1.0, Sector.fam), closeTo(0.5, 0.001));
    expect(Eco.buyProb(1.1, Sector.fam), closeTo(0.23, 0.01));
  });

  test('Reputación', () {
    expect(Eco.reputation(5000000), 4);
    expect(Eco.reputation(20000000), 8);
    expect(Eco.reputation(50000000), 14);
  });
}
