import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:corner_cutters/game/engine.dart';
import 'package:corner_cutters/game/era.dart';
import 'package:corner_cutters/game/model.dart';
import 'package:corner_cutters/services/avisos_plan.dart';
import 'package:corner_cutters/services/version.dart';

const _todo = {'obra': true, 'inquilino': true, 'venta': true, 'mercado': true, 'eventos': true, 'noche': false};
Forecast _f(String kind, int min, [String? title]) => Forecast(kind, Duration(minutes: min), title ?? kind, 'cuerpo de $kind');

void main() {
  group('Previsión con el juego cerrado', () {
    test('no toca la partida y no falla en una partida recién creada', () {
      final g = Game()..newGame(42);
      final antes = jsonEncode(g.toJson());
      final f = g.forecast();
      expect(jsonEncode(g.toJson()), antes);
      expect(g.notices, isEmpty);
      for (final x in f) {
        expect(x.at, lessThanOrEqualTo(const Duration(hours: Game.offlineCapHours)));
        expect(x.title, isNotEmpty);
        expect(x.body, isNotEmpty);
      }
    });

    test('una vivienda que busca inquilino avisa cuando se firma el contrato', () {
      final g = Game()..newGame(7);
      expect(g.props, isNotEmpty);
      final p = g.props.first;
      p.state = PState.buscando;
      p.vacancyLeft = 60; // un minuto de juego: media hora real con el juego cerrado
      final f = g.forecast();
      final firma = f.where((x) => x.kind == 'inquilino').toList();
      expect(firma, hasLength(1));
      expect(firma.first.at, greaterThan(const Duration(minutes: 20)));
      expect(firma.first.at, lessThan(const Duration(minutes: 45)));
      expect(firma.first.body, contains(g.addressOf(p)));
      // La partida de verdad sigue igual: el inquilino todavía no ha llegado.
      expect(p.state, PState.buscando);
      expect(p.tenant, isNull);
    });

    test('las épocas no avanzan cerradas: sin previsión', () {
      final g = Game()..newEraGame(era1929, 5);
      expect(g.forecast(), isEmpty);
    });
  });

  group('Plan de notificaciones', () {
    final mediodia = DateTime(2026, 11, 12, 12);

    test('una por tipo, separadas y sin lo que pasa nada más salir', () {
      final plan = planAvisos([
        _f('obra', 3), // demasiado pronto
        _f('obra', 30),
        _f('obra', 200), // mismo tipo: fuera
        _f('venta', 50), // a menos de 45 min de la anterior: fuera
        _f('inquilino', 120),
        _f('tope', 480),
      ], _todo, mediodia, ciudad: 'Alba Nova');
      expect(plan.map((a) => a.titulo).toList(), ['obra', 'inquilino', 'tope', 'Alba Nova sigue en pie']);
      expect(plan.map((a) => a.id).toSet(), hasLength(plan.length));
      expect(plan.last.en, const Duration(days: 3));
    });

    test('respeta los interruptores', () {
      final plan = planAvisos([_f('obra', 30), _f('venta', 120), _f('eventos', 240)],
          {..._todo, 'obra': false, 'eventos': false, 'mercado': false}, mediodia,
          ciudad: 'Alba Nova');
      expect(plan.map((a) => a.titulo).toList(), ['venta']);
    });

    test('todo apagado: nada', () {
      final nada = {for (final k in _todo.keys) k: false};
      expect(planAvisos([_f('obra', 30), _f('tope', 480)], nada, mediodia, ciudad: 'Alba Nova'), isEmpty);
    });

    test('silencio nocturno: lo de madrugada se junta a las 8:05', () {
      final noche = DateTime(2026, 11, 12, 21);
      final plan = planAvisos([
        _f('obra', 60), // 22:00 → se queda
        _f('venta', 180), // 00:00 → mañana
        _f('inquilino', 300), // 02:00 → mañana
      ], {..._todo, 'noche': true, 'mercado': false}, noche, ciudad: 'Alba Nova');
      expect(plan, hasLength(2));
      expect(plan.first.titulo, 'obra');
      expect(plan.last.titulo, 'Mientras dormías');
      final cuando = noche.add(plan.last.en);
      expect([cuando.day, cuando.hour, cuando.minute], [13, 8, 5]);
    });

    test('sin silencio nocturno no se mueve nada', () {
      final noche = DateTime(2026, 11, 12, 21);
      final plan = planAvisos([_f('venta', 180)], {..._todo, 'mercado': false}, noche, ciudad: 'Alba Nova');
      expect(plan.single.en, const Duration(minutes: 180));
    });
  });

  test('la versión del código es la de pubspec.yaml', () {
    final linea = File('pubspec.yaml').readAsLinesSync().firstWhere((l) => l.startsWith('version:'));
    expect(linea.split(':').last.trim().split('+').first, appVersion);
  });

  test('las traducciones tienen los textos de las notificaciones', () {
    for (final l in ['en', 'ca', 'de', 'zh']) {
      final t = jsonDecode(File('assets/i18n/$l.json').readAsStringSync()) as Map<String, dynamic>;
      for (final k in [
        '{0} está lista para alquilar o vender.',
        'Contrato firmado en {0}.',
        'Alguien quiere {0}. Caduca en 24 horas.',
        'Las cuadrillas han parado',
        '{0} sigue en pie',
        'Ni un dólar de más',
      ]) {
        expect(t[k], isNotNull, reason: '$l: $k');
      }
    }
  });
}
