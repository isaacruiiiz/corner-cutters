import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:corner_cutters/ui/widgets/recibo.dart';

void main() {
  Future<void> pintar(WidgetTester t, VentaRecibo v) async {
    await t.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: ReciboVenta(v)))));
    await t.pump();
    expect(t.takeException(), isNull);
    expect(find.byType(ReciboVenta), findsOneWidget);
    expect(t.getSize(find.byType(ReciboVenta)), const Size(432, 540));
  }

  testWidgets('recibo normal', (t) async {
    await pintar(
        t,
        const VentaRecibo(
            ciudad: 'Alba Nova', fecha: '4 ene · Año 3', direccion: 'C/ del Reloj Parado, 4', compra: 18400, obra: 6250, venta: 41900, beneficio: 17250));
  });

  testWidgets('recibo con dirección larga, cifras enormes y pérdidas: no se sale', (t) async {
    await pintar(
        t,
        const VentaRecibo(
            ciudad: 'Ciudad Ferrara',
            fecha: '28 sep · Año 112',
            direccion: 'Av. de los Promotores Inmobiliarios Ilustres, 1234',
            compra: 98765432,
            obra: 12345678,
            venta: 987654321,
            beneficio: -876543210));
  });

  test('la frase depende del margen', () {
    const base = VentaRecibo(ciudad: '', fecha: '', direccion: '', compra: 100, obra: 0, venta: 0, beneficio: 0);
    VentaRecibo con(double b) => VentaRecibo(ciudad: '', fecha: '', direccion: '', compra: 100, obra: 0, venta: 0, beneficio: b);
    expect(con(150).frase, 'Comprar barato tiene estas cosas.');
    expect(con(50).frase, 'Sin luz no se vendía; con luz, por poco.');
    expect(con(5).frase, 'Ganar es ganar. Aunque sea poco.');
    expect(base.frase, 'Hay ventas que se cuentan y otras que se comparten.');
  });

  test('las frases del recibo están traducidas', () {
    final fuente = File('lib/ui/widgets/recibo.dart').readAsStringSync();
    final frases = RegExp(r"return '([^']+)';").allMatches(fuente).map((m) => m[1]!).toList();
    expect(frases, hasLength(4));
    for (final l in ['en', 'ca', 'de', 'zh']) {
      final tabla = jsonDecode(File('assets/i18n/$l.json').readAsStringSync()) as Map<String, dynamic>;
      for (final k in [...frases, 'Obra, a mano', 'Gracias por especular', 'Compartir la venta']) {
        expect(tabla[k], isNotNull, reason: '$l: $k');
      }
    }
  });
}
