/// Web: sin red de anuncios (se usa el anuncio de prueba de la app).
class Anuncios {
  static Future<void> init() async {}

  /// null: no hay anuncio real disponible.
  static Future<bool?> recompensa() async => null;
  static Future<void> intersticial() async {}
  static bool get puedePrivacidad => false;
  static Future<void> privacidad() async {}
}
