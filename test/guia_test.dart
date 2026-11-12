import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:corner_cutters/game/engine.dart';
import 'package:corner_cutters/game/era.dart';
import 'package:corner_cutters/game/model.dart';
import 'package:corner_cutters/ui/guia.dart';

void main() {
  group('Fases de la guía del capataz', () {
    test('partida nueva: primera obra; con la guía hecha, nada', () {
      final g = Game()..newGame(42);
      g.meta.guideDone = false;
      expect(faseGuia(g), GuiaFase.primeraObra);
      g.meta.guideDone = true;
      expect(faseGuia(g), isNull);
    });

    test('obra lanzada → en obra; terminada → decidir; alquilada → fin', () {
      final g = Game()..newGame(7);
      final p = g.props.first;
      expect(g.startReno(p, g.suggestedLevels(p)), isNull);
      expect(faseGuia(g), GuiaFase.enObra);
      g.finishReno(p);
      expect(g.renosDone, 1);
      expect(faseGuia(g), GuiaFase.decidir);
      expect(g.listForRent(p, 1), isNull);
      expect(faseGuia(g), GuiaFase.fin);
    });

    test('vender también cierra el paso de decidir', () {
      final g = Game()..newGame(9);
      final p = g.props.first;
      g.startReno(p, g.suggestedLevels(p));
      g.finishReno(p);
      expect(g.listForSale(p, 1.1), isNull);
      expect(faseGuia(g), GuiaFase.fin);
    });

    test('en las épocas no hay guía', () {
      final g = Game()..newEraGame(era1929, 5);
      g.meta.guideDone = false;
      expect(faseGuia(g), isNull);
    });

    test('se guarda y se carga', () {
      final g = Game()..newGame(3);
      g.meta.guideDone = true;
      final b = Game()..loadJson(jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>);
      expect(b.meta.guideDone, isTrue);
    });

    test('partidas de antes de la guía: quien ya había reformado no la ve', () {
      final g = Game()..newGame(11);
      final j = jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>;
      (j['meta'] as Map).remove('guide');
      j['renosDone'] = 2;
      expect((Game()..loadJson(j)).meta.guideDone, isTrue);
      j['renosDone'] = 0;
      expect((Game()..loadJson(j)).meta.guideDone, isFalse);
    });

    test('el estado de la vivienda que señala existe al empezar', () {
      final g = Game()..newGame(5);
      expect(g.props.where((p) => p.state == PState.ruina), isNotEmpty);
    });
  });

  test('las traducciones tienen los textos del capataz', () {
    final fuente = File('lib/ui/guia.dart').readAsStringSync();
    // Todas las frases entre comillas simples de los pasos (texto, título y botón).
    final frases = RegExp(r"_Paso\(\d, '([^']+)', '([^']+)'(?:,\s*boton: '([^']+)')?").allMatches(fuente).expand((m) => [m[1], m[2], m[3]]).whereType<String>().toSet();
    expect(frases.length, greaterThan(15));
    for (final l in ['en', 'ca', 'de', 'zh']) {
      final t = jsonDecode(File('assets/i18n/$l.json').readAsStringSync()) as Map<String, dynamic>;
      for (final k in [...frases, 'Paco, capataz', 'Paso {0} de {1} · {2}', 'Saltar guía', 'Repetir la guía']) {
        expect(t[k], isNotNull, reason: '$l: $k');
      }
    }
  });
}
