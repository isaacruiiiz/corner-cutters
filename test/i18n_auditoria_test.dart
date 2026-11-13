// Auditoría de traducciones: juega partidas automáticas y pasa por el traductor real todo lo
// que el juego enseña (avisos, sucesos, titulares, objetivos, direcciones, barrios, fechas…).
// Falla si en catalán, inglés, alemán o chino se cuela español sin traducir.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:corner_cutters/core/calles.dart';
import 'package:corner_cutters/core/i18n.dart';
import 'package:corner_cutters/game/data.dart';
import 'package:corner_cutters/game/engine.dart';
import 'package:corner_cutters/game/era.dart';
import 'package:corner_cutters/game/model.dart';
import 'package:corner_cutters/game/texts.dart';

const _idiomas = ['ca', 'en', 'de', 'zh'];

Map<String, String> _tabla(String l) =>
    (jsonDecode(File('assets/i18n/$l.json').readAsStringSync()) as Map<String, dynamic>).map((k, v) => MapEntry(k, v as String));

/// Palabras que solo existen en español (no en catalán, inglés ni alemán).
const _soloEspanol = {
  'y', 'los', 'las', 'con', 'por', 'para', 'pero', 'muy', 'más', 'hay', 'sin', 'también', 'cuando', 'donde', 'porque',
  'está', 'están', 'esta', 'este', 'esto', 'como', 'hasta', 'desde', 'según', 'ningún', 'nadie', 'algo', 'alguien',
  'aún', 'ya', 'todavía', 'mientras', 'cada', 'todo', 'toda', 'todos', 'todas', 'otro', 'otra', 'mucho', 'poco',
  'su', 'sus', 'nuevo', 'nueva', 'viejo', 'vieja', 'obra', 'obras', 'reformas', 'calle', 'barrio', 'venta', 'ventas',
  'alquiler', 'alquilada', 'vendida', 'inquilino', 'inquilinos', 'comprador', 'compradores', 'precio', 'precios',
  'renta', 'rentas', 'meses', 'año', 'años', 'días', 'horas', 'ofertas', 'mercado', 'ruina', 'ruinas', 'edificio',
  'edificios', 'vivienda', 'viviendas', 'dinero', 'efectivo', 'patrimonio', 'banco', 'cuadrilla', 'cuadrillas',
  'oficio', 'oficios', 'nivel', 'niveles', 'energía', 'calidad', 'electricidad', 'fontanería', 'albañilería',
  'carpintería', 'decoración', 'humedades', 'instalación', 'peor', 'mejor', 'esperado', 'toques', 'deja', 'ene',
  'abr', 'ago', 'dic', 'activa', 'activas', 'terminada', 'reservada', 'mirando', 'solo', 'administradores', 'dañada',
  'dañadas', 'reparación', 'siguiente', 'lista', 'fundadas', 'misión', 'pasado',
};

/// Palabras que el catalán comparte con el español.
const _catalan = {'activa', 'cada', 'obra', 'obres', 'banc', 'mes', 'renda', 'hipoteca', 'reforma', 'pisos', 'les', 'nova', 'nou', 'abr', 'nivell'};

/// Nombres propios que no se traducen (personas, clientes, rivales y ciudades).
final Set<String> _nombres = {
  ...Tx.firstNames, ...Tx.lastNames,
  'Familia', 'Sra', 'Sr', 'Comunidad', 'Mancini', 'Capital', 'Torres', 'Vértice', 'Patrimonial', 'Ruina', 'Hermanos',
  'Gaviota', 'Inversiones', 'Andamio', 'Fondo', 'Grupo', 'Ladrillo', 'Feliz', 'Nuria', 'Soler',
  'Ortega', 'Pons', 'Delgado', 'Haddad', 'Lin', 'Abril', 'Vázquez', 'Moreau', 'Quintana', 'Bauer', 'Iglesias',
}.map((e) => e.toLowerCase()).toSet();

String? _resto(String lang, String salida) {
  final palabras = RegExp(r'[a-záéíóúüñàèòïç]+').allMatches(salida.toLowerCase()).map((m) => m[0]!).where((w) => !_nombres.contains(w));
  if (lang == 'zh') {
    final latinas = RegExp(r'[A-Za-záéíóúñ]{3,}').allMatches(salida).map((m) => m[0]!.toLowerCase()).where((w) => !_nombres.contains(w)).toList();
    return latinas.isEmpty ? null : latinas.join(', ');
  }
  final malas = palabras.where((w) => _soloEspanol.contains(w) && !(lang == 'ca' && _catalan.contains(w))).toSet();
  if (lang != 'ca' && palabras.any((w) => RegExp('[ñ]').hasMatch(w))) malas.add('ñ');
  return malas.isEmpty ? null : malas.join(', ');
}

/// Juega una partida automática y devuelve todo lo que se ha enseñado.
Set<String> _jugar(Game g, int vueltas) {
  final vistos = <String>{};
  void recoge() {
    for (final n in g.notices) {
      vistos.add(n.text);
    }
    g.notices.clear();
    for (final e in g.events) {
      vistos..add(e.title)..add(e.text);
    }
    for (final h in g.news) {
      vistos..add(h.title)..add(h.body);
    }
    for (final m in g.missions) {
      vistos.add(m.text);
    }
    for (final p in g.props) {
      vistos..add(g.addressOf(p))..add(g.districtOf(p).name);
    }
    vistos.add(g.dateLabel);
  }

  for (var i = 0; i < vueltas; i++) {
    for (final p in List<Property>.from(g.props)) {
      if (p.state == PState.ruina) {
        g.startReno(p, g.suggestedLevels(p));
      } else if (p.state == PState.obra && p.reno != null) {
        for (final t in Trade.values) {
          if (p.reno != null && p.reno!.has(t)) g.workTo(p, t, 1);
        }
        if (p.reno != null && p.reno!.allDone) g.finishReno(p);
      } else if (p.state == PState.lista) {
        p.id.isEven ? g.listForRent(p, 1.1) : g.listForSale(p, 1.1);
      }
    }
    for (final l in List.of(g.listings)) {
      if (g.cash > g.listingValue(l) * 1.3) g.buy(l);
    }
    for (final t in Trade.values) {
      g.train(t);
      if (g.hasCrews && g.crews.length < 5) g.hireCrew(t);
    }
    for (final j in List.of(g.jobs)) {
      g.acceptJob(j);
    }
    recoge();
    for (final e in List.of(g.events)) {
      for (final a in ['pagar', 'ignorar', 'esperar', 'aceptar', 'rechazar', 'cobrar']) {
        final r = g.resolveEvent(e.id, a);
        if (r != null) vistos.add(r);
        if (g.eventById(e.id) == null) break;
      }
    }
    g.debugAdvance(900, step: 10);
    recoge();
    if (g.eraOver) break;
  }
  return vistos..removeWhere((s) => s.trim().isEmpty);
}

void main() {
  tearDown(() => I18n.usarTabla('es', const {}));

  test('partidas en cada idioma: nada de español sin traducir', () {
    final vistos = <String>{};
    for (final s in [7, 42]) {
      vistos.addAll(_jugar(Game()..newGame(s), 90));
    }
    vistos.addAll(_jugar(Game()..newEraGame(era1929, 3), 120));
    vistos.addAll(_jugar(Game()..newEraGame(era2005, 5), 120));
    expect(vistos.length, greaterThan(300));
    final fallos = <String>[];
    for (final l in _idiomas) {
      I18n.usarTabla(l, _tabla(l));
      for (final s in vistos) {
        final r = _resto(l, I18n.t(s));
        if (r != null) fallos.add('$l · «$s» → «${I18n.t(s)}» ($r)');
      }
    }
    expect(fallos.take(40).toList(), isEmpty, reason: '${fallos.length} textos con español sin traducir');
  });

  test('calles con el nombre y el formato de cada idioma', () {
    expect(traducirCalle('C/ del Columpio 19', 'ca'), 'C/ del Gronxador, 19');
    expect(traducirCalle('C/ del Columpio 19', 'en'), '19 Swing St.');
    expect(traducirCalle('C/ del Columpio 19', 'de'), 'Schaukelstraße 19');
    expect(traducirCalle('C/ del Columpio 19', 'zh'), '秋千街19号');
    expect(traducirCalle('Av. del Reloj Parado 4, 2º 1ª', 'de'), 'Stehende-Uhr-Allee 4, 2. OG links');
    expect(traducirCalle('C/ del Ático 3, 2º 2ª', 'ca'), "C/ de l'Àtic, 3, 2n 2a");
    expect(traducirCalle('C/ del Ático 3, 2º 2ª', 'en'), '3 Penthouse St., Apt 2B');
    expect(traducirCalle('Av. de las Grúas', 'zh'), '吊车大道');
    expect(traducirCalle('C/ Inventada 3', 'en'), isNull);
    // Dentro de una frase también.
    I18n.usarTabla('en', _tabla('en'));
    expect(I18n.t('Irene Martín deja C/ Trébol Rojo 51: fin de curso'), contains('51 Red Clover St.'));
  });

  test('todas las calles y barrios de cualquier ciudad salen traducidos', () {
    for (final s in [1, 99, 2024]) {
      final g = Game()..newGame(s);
      for (final l in _idiomas) {
        I18n.usarTabla(l, _tabla(l));
        for (final st in g.city.streets) {
          expect(traducirCalle(st.name, l), isNotNull, reason: '$l: ${st.name}');
        }
        for (final d in g.city.districts) {
          expect(I18n.t(d.name), isNot(d.name), reason: '$l: ${d.name}');
        }
      }
    }
  });

  test('fechas de época y cambios de fase', () {
    I18n.usarTabla('en', _tabla('en'));
    expect(I18n.t('1 ene 1888'), '1 jan 1888');
    expect(I18n.t('Recuperación → Expansión'), 'Recovery → Expansion');
    I18n.usarTabla('zh', _tabla('zh'));
    expect(I18n.t('16 mar 1893'), '1893年3月16日');
    I18n.usarTabla('de', _tabla('de'));
    expect(I18n.t('4 may 2005'), '4. Mai 2005');
    // Una fecha de una sola palabra no se confunde con una frase normal.
    expect(I18n.t('Casas frente al mar con vistas'), 'Casas frente al mar con vistas');
  });

  // Frases que las pantallas montan a trozos (cifra + palabra, ternarios…): no salen al jugar
  // la partida automática, así que se comprueban aquí con ejemplos reales.
  test('frases compuestas de las pantallas', () {
    const muestras = [
      '0 ACTIVAS', '1 ACTIVA', '3 activas',
      'En tu ciudad han pasado 8 meses', 'En tu ciudad han pasado 1 mes', 'En tu ciudad han pasado 12 días',
      'Calidad Q 1,25', 'Calidad 1,25 · \$120.000', 'alquilada \$800/mes',
      'Decoración terminada', 'Fontanería terminada. Siguiente: Electricidad',
      'Activa · alquila lo reformado', 'Activa · vende lo reformado',
      'Lanzar 1 obra', 'LANZAR 3 OBRAS', 'ALQUILADA', 'Alquilada', 'LISTA',
      'Centro · 4 × 50 m² · reservada', 'Centro · 50 m² · 3 mirando',
      '2 embargos del banco a precio de saldo', '1 misión de crisis',
      'Reputación total 120 · 3 ciudades fundadas', '1 vivienda dañada · reparación \$4.000',
      'En gris, lo que ya tiene la vivienda: solo pagas y trabajas la diferencia. Por encima del nivel formado de cada oficio, primero hay que formarlo en Empresa.',
      'En gris, lo que ya tiene la vivienda: solo pagas y trabajas la diferencia. En crisis la obra sale un 25 % más barata. Por encima del nivel formado de cada oficio, primero hay que formarlo en Empresa.',
      'Solo para administradores',
    ];
    final fallos = <String>[];
    for (final l in ['ca', 'en', 'de', 'zh']) {
      I18n.usarTabla(l, _tabla(l));
      for (final m in muestras) {
        final r = I18n.t(m);
        final resto = _resto(l, r);
        if (resto != null) fallos.add('[$l] $m → $r  ($resto)');
      }
    }
    expect(fallos, isEmpty, reason: fallos.join('\n'));
    I18n.usarTabla('ca', _tabla('ca'));
    expect(I18n.t('Alquilada'), 'Llogat');
    expect(I18n.t('0 ACTIVAS'), '0 ACTIVES');
  });

  test('las tablas no tienen marcadores rotos', () {
    final ph = RegExp(r'\{\d+\}');
    for (final l in _idiomas) {
      _tabla(l).forEach((k, v) {
        final a = ph.allMatches(k).map((m) => m[0]).toList()..sort();
        final b = ph.allMatches(v).map((m) => m[0]).toList()..sort();
        expect(b, a, reason: '$l: $k');
      });
    }
  });
}
