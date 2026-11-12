import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/i18n.dart';
import 'backend.dart';
import 'version.dart';

/// Datos de uso propios (sin SDK de terceros): qué pasos del juego alcanza cada jugador y qué
/// errores da la app. Van a Supabase y solo se ven en el panel admin. El jugador puede apagarlo
/// en Ajustes → Datos de uso.
class Telemetria {
  /// Interruptor del jugador. Antes de cargar la partida vale el valor por defecto.
  static bool activa = true;

  static final List<Map<String, dynamic>> _cola = [];
  static final Set<String> _erroresVistos = {};
  static int _erroresSesion = 0;
  static bool _enviando = false;
  static final int _inicio = DateTime.now().millisecondsSinceEpoch;

  static String get plataforma => kIsWeb ? 'web' : defaultTargetPlatform.name.toLowerCase();

  /// Segundos desde que se abrió la app.
  static int get segundosSesion => (DateTime.now().millisecondsSinceEpoch - _inicio) ~/ 1000;

  /// Apunta un evento (nombre en minúsculas, cifras y guion bajo). Se envía por lotes.
  static void evento(String nombre, [Map<String, Object?>? datos]) {
    if (!activa || _cola.length >= 200) return;
    _cola.add({
      'n': nombre,
      't': DateTime.now().millisecondsSinceEpoch,
      if (datos != null && datos.isNotEmpty) 'd': datos,
    });
  }

  /// Envía lo pendiente. Si falla la red se reintenta en la siguiente llamada.
  static Future<void> enviar() async {
    if (!activa) {
      _cola.clear();
      return;
    }
    if (_enviando || _cola.isEmpty || !Backend.ready) return;
    _enviando = true;
    final lote = _cola.take(60).toList();
    try {
      final ok = await Backend.registrarEventos(lote, version: appVersion, plataforma: plataforma, idioma: I18n.codigo);
      // null: el servidor todavía no tiene la función (falta supabase/seguridad.sql). No se acumula.
      if (ok != false) _cola.removeRange(0, lote.length.clamp(0, _cola.length));
    } finally {
      _enviando = false;
    }
  }

  /// Un error de la app. Como mucho ocho por sesión y sin repetir el mismo.
  static void error(Object e, StackTrace? pila) {
    if (!activa || _erroresSesion >= 8) return;
    try {
      var msg = '$e';
      if (msg.length > 300) msg = msg.substring(0, 300);
      final lineas = (pila?.toString() ?? '').split('\n').where((l) => l.trim().isNotEmpty).take(12).join('\n');
      if (!_erroresVistos.add('$msg|${lineas.split('\n').first}')) return;
      _erroresSesion++;
      unawaited(Backend.registrarError(msg, lineas, version: appVersion, plataforma: plataforma));
    } catch (_) {
      // Informar de un error nunca debe provocar otro.
    }
  }
}
