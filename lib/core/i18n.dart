import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'calles.dart';

/// Idiomas del juego. El texto original está en español dentro del código; el resto de
/// idiomas son tablas `assets/i18n/<código>.json` con la frase española como clave.
///
/// Las frases con datos (`'Nivel $n'`) se guardan como plantillas (`Nivel {0}`): si un texto
/// no está tal cual en la tabla, se busca la plantilla que encaje y se traducen también los
/// trozos variables que tengan traducción.
class I18n {
  I18n._();

  static const idiomas = <String, String>{
    'es': 'Español',
    'ca': 'Català',
    'en': 'English',
    'de': 'Deutsch',
    'zh': '中文',
  };
  static const _prefKey = 'hs_idioma';

  /// Idioma activo y elección del jugador ('' = el del sistema).
  static final ValueNotifier<String> actual = ValueNotifier('es');
  static String eleccion = '';

  static Map<String, String> _tabla = const {};
  static List<_Plantilla> _plantillas = const [];
  static final Map<String, String> _cache = {};
  static Map<String, String> _mayus = const {};
  static Map<String, String> _minus = const {};

  static String get codigo => actual.value;
  static Locale get locale => Locale(codigo);

  /// Separadores de cifras del idioma activo.
  static bool get puntoMiles => codigo == 'es' || codigo == 'ca' || codigo == 'de';

  static String get _sistema {
    final l = PlatformDispatcher.instance.locale.languageCode;
    return idiomas.containsKey(l) ? l : (l == 'gl' || l == 'eu' ? 'es' : 'en');
  }

  /// Al arrancar: lee la elección guardada (o el idioma del móvil) y carga su tabla.
  static Future<void> init() async {
    try {
      final p = await SharedPreferences.getInstance();
      eleccion = p.getString(_prefKey) ?? '';
    } catch (_) {}
    await _cargar(eleccion.isEmpty ? _sistema : eleccion);
  }

  /// Cambia de idioma ('' = el del sistema) y lo guarda.
  static Future<void> elegir(String code) async {
    eleccion = code;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_prefKey, code);
    } catch (_) {}
    await _cargar(code.isEmpty ? _sistema : code);
  }

  static Future<void> _cargar(String code) async {
    if (!idiomas.containsKey(code)) code = 'es';
    var tabla = <String, String>{};
    if (code != 'es') {
      try {
        final raw = await rootBundle.loadString('assets/i18n/$code.json');
        tabla = (jsonDecode(raw) as Map<String, dynamic>).map((k, v) => MapEntry(k, v as String));
      } catch (e) {
        debugPrint('i18n: no se pudo cargar $code: $e');
        code = 'es';
      }
    }
    usarTabla(code, tabla);
  }

  /// Pone una tabla ya cargada (también para tests).
  @visibleForTesting
  static void usarTabla(String code, Map<String, String> tabla) {
    _tabla = tabla;
    _cache.clear();
    // Variantes en mayúsculas ('REFORMAR') y minúsculas ('estudiantes') de cada frase.
    final may = <String, String>{}, min = <String, String>{};
    tabla.forEach((es, otro) {
      may.putIfAbsent(es.toUpperCase(), () => otro.toUpperCase());
      min.putIfAbsent(es.toLowerCase(), () => otro);
    });
    _mayus = may;
    _minus = min;
    final ps = <_Plantilla>[];
    final extra = <String, String>{};
    void anade(String es, String otro) {
      final p = _Plantilla.de(es, otro);
      if (p != null) ps.add(p);
      // También en mayúsculas (etiquetas que se pintan con toUpperCase()).
      final up = es.toUpperCase();
      if (up != es) {
        final q = _Plantilla.de(up, otro.toUpperCase());
        if (q != null) ps.add(q);
      }
    }
    tabla.forEach((es, otro) {
      // Trozos que en el código acaban en ' · ' o empiezan con espacio: también sin los bordes.
      final limpia = es.replaceAll(RegExp(r'^[\s·]+|[\s·]+$'), '');
      if (limpia != es && limpia.isNotEmpty) {
        final otroLimpio = otro.replaceAll(RegExp(r'^[\s·]+|[\s·]+$'), '');
        if (!tabla.containsKey(limpia)) extra[limpia] = otroLimpio;
        if (limpia.contains('{')) anade(limpia, otroLimpio);
      }
      if (es.contains('{')) anade(es, otro);
    });
    if (extra.isNotEmpty) _tabla = {...tabla, ...extra};
    // Primero las más concretas (más texto fijo).
    ps.sort((a, b) => b.fijo.compareTo(a.fijo));
    _plantillas = ps;
    actual.value = code;
  }

  static final _letra = RegExp(r'[A-Za-zÀ-ÿ]');

  /// Traduce un texto en español. Si no hay traducción, lo devuelve igual.
  static String t(String s, [int prof = 0]) {
    if (codigo == 'es' || s.isEmpty || !_letra.hasMatch(s)) return s;
    final c = _cache[s];
    if (c != null) return c;
    // Calles y direcciones («C/ del Columpio 19, 2º 1ª»): nombre y formato de cada idioma.
    if (s.startsWith('C/ ') || s.startsWith('Av. ')) {
      final calle = traducirCalle(s, codigo);
      if (calle != null) return _cache[s] = calle;
    }
    final exacta = _tabla[s];
    if (exacta != null) return exacta;
    var r = s;
    final may = s == s.toUpperCase() ? _mayus[s] : null;
    if (may != null) return _cache[s] = may;
    final min = _minus[s.toLowerCase()];
    if (min != null) {
      // Si el original va en minúscula, la traducción también (menos en alemán, por los sustantivos).
      final ini = s[0];
      final enMin = ini == ini.toLowerCase() && ini != ini.toUpperCase();
      return _cache[s] = enMin && codigo != 'de' && min.isNotEmpty ? min[0].toLowerCase() + min.substring(1) : min;
    }
    if (prof < 6) {
      for (final p in _plantillas) {
        final x = p.aplicar(s, prof);
        if (x != null) {
          r = x;
          break;
        }
      }
      // Texto con saltos de línea o hecho de trozos unidos con ' · ' o ' → ': se traduce por trozos.
      if (identical(r, s) && s.contains('\n')) {
        r = s.split('\n').map((l) => t(l, prof + 1)).join('\n');
      } else if (identical(r, s) && s.contains(' · ')) {
        r = s.split(' · ').map((l) => t(l, prof + 1)).join(' · ');
      } else if (identical(r, s) && s.contains(' → ')) {
        r = s.split(' → ').map((l) => t(l, prof + 1)).join(' → ');
      }
    }
    if (_cache.length > 3000) _cache.clear();
    _cache[s] = r;
    return r;
  }
}

/// Atajo para traducir en código (pistas de campos de texto, dibujos con TextPainter…).
String tr(String s) => I18n.t(s);

class _Plantilla {
  final RegExp re;
  final String destino;
  final List<String> trozos;
  final int fijo;
  /// Plantilla débil ('{0} en {1}'): solo si el texto empieza por una cifra.
  final bool conCifra;
  _Plantilla(this.re, this.destino, this.trozos, this.fijo, [this.conCifra = false]);
  static final _cifra = RegExp(r'^[−+\-$]?\d');

  static final _hueco = RegExp(r'\{(\d+)\}');
  static const _enlaces = {'de', 'del', 'en', 'al', 'la', 'el', 'los', 'las', 'y', 'a', 'con'};

  static _Plantilla? de(String es, String otro) {
    final partes = es.split(_hueco);
    final fijo = partes.fold<int>(0, (a, p) => a + p.trim().length);
    // Plantillas sin texto propio ('{0} · {1}') o con huecos pegados no sirven para buscar.
    // Hace falta texto propio suficiente: con '{0} de {1}' se traducirían trozos de nombres de calle.
    final palabras = RegExp(r'[A-Za-zÀ-ÿ]{2,}').allMatches(partes.join()).map((m) => m[0]!.toLowerCase());
    if (palabras.isEmpty) return null;
    // Solo con 'de', 'en'…: vale para '3 en Rocaserena', no para nombres de calle.
    final soloEnlaces = palabras.every(_enlaces.contains);
    // Una sola palabra corta ('{0} mar {1}', fechas): solo si el texto empieza por cifra,
    // para que «vistas al mar y …» no se tome por una fecha.
    final corta = RegExp(r'^\{0\} [A-Za-zÀ-ÿ]{2,4} \{1\}$').hasMatch(es);
    if (es.contains(RegExp(r'\}\{'))) return null;
    final b = StringBuffer('^');
    var i = 0;
    for (final m in _hueco.allMatches(es)) {
      b.write(RegExp.escape(es.substring(i, m.start)));
      b.write('(.+?)');
      i = m.end;
    }
    b.write(RegExp.escape(es.substring(i)));
    b.write(r'$');
    final trozo = partes.reduce((a, b) => a.length >= b.length ? a : b);
    return _Plantilla(RegExp(b.toString(), dotAll: true), otro, [trozo], fijo, (soloEnlaces || corta) && es.startsWith('{0}'));
  }

  String? aplicar(String s, int prof) {
    if (!s.contains(trozos.first)) return null;
    if (conCifra && !_cifra.hasMatch(s)) return null;
    final m = re.firstMatch(s);
    if (m == null) return null;
    return destino.replaceAllMapped(_hueco, (h) {
      final n = int.parse(h.group(1)!);
      if (n >= m.groupCount) return h.group(0)!;
      return I18n.t(m.group(n + 1)!, prof + 1);
    });
  }
}

/// Hace que los textos se vuelvan a pintar al cambiar de idioma.
class I18nScope extends InheritedNotifier<ValueNotifier<String>> {
  I18nScope({super.key, required super.child}) : super(notifier: I18n.actual);

  static void escuchar(BuildContext context) => context.dependOnInheritedWidgetOfExactType<I18nScope>();
}
