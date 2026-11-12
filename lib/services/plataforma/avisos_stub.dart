import '../avisos_plan.dart';

/// Web: sin notificaciones del sistema.
class Avisos {
  static bool get disponible => false;
  static Future<void> init() async {}
  static Future<bool> permitido() async => false;
  static Future<bool> pedirPermiso() async => false;
  static Future<void> programar(List<Aviso> avisos) async {}
  static Future<void> cancelar() async {}
}
