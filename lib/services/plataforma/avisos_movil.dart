import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/i18n.dart';
import '../avisos_plan.dart';

/// Notificaciones locales: se programan al cerrar el juego con lo que va a pasar (obra terminada,
/// oferta, inquilino…) y se cancelan al volver. No hay servidor de notificaciones ni se envía nada fuera.
class Avisos {
  static final _fln = FlutterLocalNotificationsPlugin();
  static bool _ok = false;

  static bool get disponible => Platform.isAndroid || Platform.isIOS;

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      _fln.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  static IOSFlutterLocalNotificationsPlugin? get _ios =>
      _fln.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

  static Future<void> init() async {
    if (_ok || !disponible) return;
    try {
      await _fln.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_aviso'),
          // El permiso se pide más tarde, cuando tiene sentido (tras la primera obra o desde Ajustes).
          iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
        ),
      );
      _ok = true;
    } catch (e) {
      debugPrint('Avisos no disponibles: $e');
    }
  }

  /// ¿Puede la app mostrar notificaciones ahora mismo?
  static Future<bool> permitido() async {
    if (!_ok) await init();
    if (!_ok) return false;
    try {
      if (Platform.isAndroid) return await _android?.areNotificationsEnabled() ?? false;
      if (Platform.isIOS) return (await _ios?.checkPermissions())?.isEnabled ?? false;
    } catch (e) {
      debugPrint('Avisos.permitido: $e');
    }
    return false;
  }

  /// Muestra el permiso del sistema. Devuelve si ha quedado concedido.
  static Future<bool> pedirPermiso() async {
    if (!_ok) await init();
    if (!_ok) return false;
    try {
      if (Platform.isAndroid) return await _android?.requestNotificationsPermission() ?? false;
      if (Platform.isIOS) return await _ios?.requestPermissions(alert: true, badge: false, sound: true) ?? false;
    } catch (e) {
      debugPrint('Avisos.pedirPermiso: $e');
    }
    return false;
  }

  /// Sustituye lo programado por [avisos]. Sin permiso no hace nada.
  static Future<void> programar(List<Aviso> avisos) async {
    if (!await permitido()) return;
    try {
      await _fln.cancelAll();
      final detalles = NotificationDetails(
        android: AndroidNotificationDetails(
          'juego',
          tr('Avisos del juego'),
          channelDescription: tr('Obras terminadas, ofertas e inquilinos'),
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: const DarwinNotificationDetails(presentBadge: false),
      );
      final ahora = tz.TZDateTime.now(tz.UTC);
      for (final a in avisos) {
        await _fln.zonedSchedule(
          id: a.id,
          title: tr(a.titulo),
          body: tr(a.cuerpo),
          scheduledDate: ahora.add(a.en),
          notificationDetails: detalles,
          // Sin alarmas exactas: no hace falta un permiso más y unos minutos de margen dan igual.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (e) {
      debugPrint('Avisos.programar: $e');
    }
  }

  static Future<void> cancelar() async {
    if (!_ok) return;
    try {
      await _fln.cancelAll();
    } catch (e) {
      debugPrint('Avisos.cancelar: $e');
    }
  }
}
