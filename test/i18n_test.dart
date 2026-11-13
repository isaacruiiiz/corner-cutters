import 'package:flutter_test/flutter_test.dart';
import 'package:corner_cutters/core/format.dart';
import 'package:corner_cutters/core/i18n.dart';

void main() {
  tearDown(() => I18n.usarTabla('es', const {}));

  test('español: todo igual', () {
    I18n.usarTabla('es', const {});
    expect(tr('Reformar'), 'Reformar');
    expect(money(48250), r'$48.250');
    expect(pct(0.23), '23 %');
  });

  test('frase exacta, mayúsculas y minúsculas', () {
    I18n.usarTabla('en', const {'Reformar': 'Renovate', 'Estudiantes': 'Students'});
    expect(tr('Reformar'), 'Renovate');
    expect(tr('REFORMAR'), 'RENOVATE');
    expect(tr('estudiantes'), 'students');
    expect(tr('Nada que ver'), 'Nada que ver');
    expect(tr(r'$48.250'), r'$48.250');
  });

  test('plantillas con datos, y los datos también se traducen', () {
    I18n.usarTabla('en', const {
      'Nivel {0}': 'Level {0}',
      'Encaja con {0}': 'Good fit for {0}',
      'Estudiantes': 'Students',
      '{0} ene · Año {1}': 'Jan {0} · Year {1}',
      'Sube {0} a nivel {1}': 'Raise {0} to level {1}',
      'Fontanería': 'Plumbing',
    });
    expect(tr('Nivel 3'), 'Level 3');
    expect(tr('Encaja con estudiantes'), 'Good fit for students');
    expect(tr('4 ene · Año 1'), 'Jan 4 · Year 1');
    expect(tr('Sube Fontanería a nivel 2'), 'Raise Plumbing to level 2');
  });

  test('nombres de calle, etiquetas en mayúsculas y trozos con ·', () {
    I18n.usarTabla('en', const {
      '{0} de {1}': '{0} of {1}',
      'Siguiente · {0}': 'Next · {0}',
      'Expansión': 'Expansion',
      'Precios ×{0} · ': 'Prices ×{0} · ',
      'Alquileres ×{0}': 'Rents ×{0}',
    });
    // Las calles tienen su propio traductor: la plantilla '{0} de {1}' no las parte.
    expect(tr('C/ de la Plomada'), 'Plumb Line St.');
    expect(tr('2 de 5'), '2 of 5');
    expect(tr('SIGUIENTE · EXPANSIÓN'), 'NEXT · EXPANSION');
    expect(tr('Precios ×1,35 · Alquileres ×1,18'), 'Prices ×1,35 · Rents ×1,18');
    I18n.usarTabla('en', const {
      '«{0}» {1} · Tus {2} viviendas valen {3}.': '"{0}" {1} · Your {2} homes are worth {3}.',
      'Precios ×{0} · ': 'Prices ×{0} · ',
      'Alquileres ×{0}': 'Rents ×{0}',
    });
    expect(tr('«Hola» Precios ×1,35 · Alquileres ×1,18 · Tus 2 viviendas valen \$5.'),
        '"Hola" Prices ×1,35 · Rents ×1,18 · Your 2 homes are worth \$5.');
  });

  test('alemán no pasa los sustantivos a minúscula', () {
    I18n.usarTabla('de', const {'Estudiantes': 'Studenten'});
    expect(tr('estudiantes'), 'Studenten');
  });

  test('cifras según el idioma', () {
    I18n.usarTabla('en', const {});
    expect(money(48250), r'$48,250');
    expect(dec(4.25, 2), '4.25');
    expect(pct(0.23), '23%');
    I18n.usarTabla('de', const {});
    expect(money(48250), r'$48.250');
    expect(dec(4.25, 2), '4,25');
  });
}
