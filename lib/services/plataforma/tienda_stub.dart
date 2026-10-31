/// Web: sin tienda. El pack y el Pro se consiguen en el móvil (o regalados por el admin).
class Tienda {
  static bool get disponible => false;
  static Map<String, String> get precios => const {};
  static Future<void> init() async {}
  static Future<String?> comprar(String producto) async => 'Las compras se hacen desde la app del móvil';
  static Future<String?> restaurar() async => 'Las compras se restauran desde la app del móvil';
}
