import 'package:flutter_test/flutter_test.dart';
import 'package:corner_cutters/core/format.dart';
import 'package:corner_cutters/game/data.dart';
import 'package:corner_cutters/game/economy.dart';
import 'package:corner_cutters/game/engine.dart';
import 'package:corner_cutters/game/era.dart';

void main() {
  group('Modo principal: las épocas no lo tocan', () {
    test('una partida normal no tiene época ni guarda campos de época', () {
      final g = Game()..newGame(42);
      expect(g.eraCfg, isNull);
      expect(g.eraOver, isFalse);
      final j = g.toJson();
      expect(j.containsKey('era'), isFalse);
      expect(j.containsKey('eraOver'), isFalse);
      expect(j.containsKey('eraFired'), isFalse);
      expect(g.m, mph(g.phase).m);
      expect(g.ma, mph(g.phase).ma);
      expect(g.dateLabel, contains('Año'));
      expect(g.mortgageLock, 'Las hipotecas llegan con la Empresa de reformas');
    });

    test('cargar una partida principal deja la época a null', () {
      final a = Game()..newGame(7);
      final b = Game()..loadJson(a.toJson());
      expect(b.eraCfg, isNull);
      expect(b.toJson().containsKey('era'), isFalse);
    });

    test('newGame borra cualquier época anterior', () {
      final g = Game()..newEraGame(era1929, 5);
      expect(g.eraCfg, isNotNull);
      g.newGame(5);
      expect(g.eraCfg, isNull);
      expect(g.city.name, isNot('Alba Nova'));
    });
  });

  group('1929 · El crac', () {
    test('calendario de la época', () {
      const e = era1929;
      expect(e.months, 60);
      expect(e.phaseAt(0), MarketPhase.burbuja);
      expect(e.phaseAt(8), MarketPhase.burbuja);
      expect(e.phaseAt(9), MarketPhase.crisis);
      expect(e.phaseAt(36), MarketPhase.estanc);
      expect(e.phaseAt(48), MarketPhase.recup);
      expect(e.creditAt(47), isFalse);
      expect(e.creditAt(48), isTrue);
      expect(e.priceMult(11), lessThan(e.priceMult(8)));
      expect(e.nextChange(0), 9);
      expect(e.medalFor(100000), 0);
      expect(e.medalFor(600000), 2);
      expect(e.medalFor(1000000), 3);
    });

    test('empieza en Alba Nova, en euforia y sin crédito', () {
      final g = Game()..newEraGame(era1929, 11);
      expect(g.eraCfg!.id, '1929');
      expect(g.city.name, 'Alba Nova');
      expect(g.cash, 40000);
      expect(g.phase, MarketPhase.burbuja);
      expect(g.stage, Stage.empresa);
      expect(g.hasMortgage, isFalse);
      expect(g.mortgageLock, 'Sin crédito hasta 1933');
      expect(g.dateLabel, contains('1929'));
      expect(g.canPrestige, isFalse);
      expect(g.listings, isNotEmpty);
      expect(g.news, isNotEmpty);
    });

    test('el crac llega en octubre y hunde los precios', () {
      final g = Game()..newEraGame(era1929, 3);
      final before = g.m;
      g.debugAdvance(9 * Eco.monthSeconds + 5.0);
      expect(g.monthIndex, 9);
      expect(g.phase, MarketPhase.crisis);
      expect(g.m, lessThan(before * 0.6));
      expect(g.eraFired, contains(9));
      expect(g.news.any((h) => h.title.contains('Jueves Negro')), isTrue);
    });

    test('vuelve el crédito en 1933 y la época termina en diciembre', () {
      final g = Game()..newEraGame(era1929, 9);
      g.debugAdvance(48 * Eco.monthSeconds + 5.0, step: 30);
      expect(g.eraYear, 1933);
      expect(g.hasMortgage, isTrue);
      g.debugAdvance(12 * Eco.monthSeconds + 5.0, step: 30);
      expect(g.eraOver, isTrue);
      expect(g.notices.any((n) => n.kind == NoticeKind.eraEnd), isTrue);
      final clock = g.clock;
      g.debugAdvance(600);
      expect(g.clock, clock, reason: 'terminada la época, el reloj se para');
    });

    test('guardar y cargar conserva la época', () {
      final a = Game()..newEraGame(era1929, 21);
      a.debugAdvance(10 * Eco.monthSeconds + 5.0);
      final j = a.toJson();
      expect(j['era'], '1929');
      final b = Game()..loadJson(j);
      expect(b.eraCfg!.id, '1929');
      expect(b.eraFired, a.eraFired);
      expect(b.phase, MarketPhase.crisis);
      expect(b.m, closeTo(a.m, 1e-9));
    });

    test('los precios se muestran en dólares de la época sin tocar el motor', () {
      final g = Game()..newEraGame(era1929, 4);
      Money.scale = era1929.priceLevel;
      expect(g.cash, 40000);
      expect(money(g.cash), '\$4.000');
      expect(money(era1929.medals.last, compact: true), '\$100 k');
      Money.scale = 1;
      expect(money(g.cash), '\$40.000');
    });

    test('sin conexión la época no avanza', () {
      final g = Game()..newEraGame(era1929, 4);
      final s = g.gameSec;
      g.lastTick -= 3 * 3600 * 1000;
      g.catchUp();
      expect(g.gameSec, s);
    });
  });
}
