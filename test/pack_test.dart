import 'package:flutter_test/flutter_test.dart';
import 'package:corner_cutters/game/data.dart';
import 'package:corner_cutters/game/economy.dart';
import 'package:corner_cutters/game/engine.dart';
import 'package:corner_cutters/game/era.dart';
import 'package:corner_cutters/services/entitlements.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Pack de épocas: las seis se juegan', () {
    test('todas jugables; solo 1929 es gratis', () {
      for (final e in EraConfig.all) {
        expect(e.playable, isTrue, reason: e.id);
        expect(e.free, e.id == '1929', reason: e.id);
        expect(e.medals.length, 3);
        expect(e.medals[0] < e.medals[1] && e.medals[1] < e.medals[2], isTrue, reason: e.id);
        expect(e.rules.length, 3, reason: e.id);
        expect(e.events, isNotEmpty, reason: e.id);
        expect(e.news, isNotEmpty, reason: e.id);
        expect(e.quoteGold, isNotEmpty, reason: e.id);
        expect(e.spans.first.from, 0, reason: e.id);
        // Los sucesos caen dentro de la época.
        for (final ev in e.events) {
          expect(ev.month, lessThan(e.months), reason: '${e.id} ${ev.title}');
        }
      }
    });

    test('cada época arranca, avanza y termina', () {
      for (final e in EraConfig.all) {
        final g = Game()..newEraGame(e, 7);
        expect(g.eraCfg!.id, e.id);
        expect(g.city.name, 'Alba Nova');
        expect(g.cash, e.startCash);
        expect(g.phase, e.phaseAt(0));
        expect(g.listings, isNotEmpty, reason: e.id);
        g.debugAdvance(e.months * Eco.monthSeconds + 5.0, step: 60);
        expect(g.eraOver, isTrue, reason: e.id);
        expect(g.eraYear, greaterThanOrEqualTo(e.endYear));
      }
    });

    test('el objetivo mide lo que dice', () {
      final a = Game()..newEraGame(era1888, 1);
      expect(a.eraScore, a.props.where((p) => !p.isClient).length.toDouble());
      final b = Game()..newEraGame(era2020, 1);
      expect(b.eraScore, b.props.where((p) => p.tenant != null).length.toDouble());
      final c = Game()..newEraGame(era1980, 1);
      expect(c.eraScore, c.stat('renos'));
      final d = Game()..newEraGame(era2005, 1);
      expect(d.eraScore, d.netWorth);
      expect(era1888.medalFor(5), 0);
      expect(era1888.medalFor(12), 2);
    });

    test('reglas con efecto: interés en 1980, obras a mano en 1888, drones en 2050', () {
      final g = Game()..newEraGame(era1980, 2);
      expect(g.mortgageRate, closeTo(Eco.mortgageRate * 3, 1e-12));
      final main = Game()..newGame(2);
      expect(main.mortgageRate, Eco.mortgageRate);
      expect(era1888.tapMult, lessThan(1));
      expect(era2050.crewMult, greaterThan(1));
      // 2005: sube cada año y pincha en septiembre de 2008.
      expect(era2005.priceMult(30), greaterThan(era2005.priceMult(5)));
      expect(era2005.phaseAt(44), MarketPhase.crisis);
      expect(era2005.creditAt(45), isFalse);
    });
  });

  group('Tipos de usuario y pack', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('normal: con anuncios y sin pack', () {
      final e = Entitlements.instance..apply(rol: Rol.usuario, dlc: false, owned: {});
      expect(e.isPro, isFalse);
      expect(e.sinAnuncios, isFalse);
      expect(e.hasEras, isFalse);
      expect(e.isAdmin, isFalse);
    });

    test('pro (rol o compra): sin anuncios, pero el pack aparte', () {
      final e = Entitlements.instance..apply(rol: Rol.pro, dlc: false, owned: {});
      expect(e.sinAnuncios, isTrue);
      expect(e.hasEras, isFalse);
      e.apply(rol: Rol.usuario, owned: {Productos.pro});
      expect(e.sinAnuncios, isTrue);
      expect(e.rolNombre, 'Pro (compra)');
    });

    test('cualquiera puede tener el pack: comprado o regalado', () {
      final e = Entitlements.instance..apply(rol: Rol.usuario, dlc: true, owned: {});
      expect(e.hasEras, isTrue);
      expect(e.erasOrigen, 'Regalado');
      e.apply(dlc: false, owned: {Productos.epocas});
      expect(e.hasEras, isTrue);
      expect(e.erasOrigen, 'Comprado');
      expect(e.sinAnuncios, isFalse);
    });

    test('admin: todo, y al cerrar sesión se pierde lo del servidor pero no lo comprado', () {
      final e = Entitlements.instance..apply(rol: Rol.admin, dlc: false, owned: {Productos.pro});
      expect(e.isAdmin && e.sinAnuncios && e.hasEras, isTrue);
      e.resetServer();
      expect(e.isAdmin, isFalse);
      expect(e.hasEras, isFalse);
      expect(e.sinAnuncios, isTrue, reason: 'el Pro comprado va con la tienda del móvil');
      e.apply(owned: {});
    });

    test('lo desconocido no cuela', () {
      expect(rolFrom('superadmin'), Rol.usuario);
      final e = Entitlements.instance..apply(rol: Rol.usuario, owned: {'gratis_todo'});
      expect(e.comprado, isEmpty);
    });
  });
}
