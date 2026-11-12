/// Web: sin valoración ni menú de compartir.
class Social {
  static bool get puedeCompartir => false;
  static Future<void> compartir(String texto) async {}
  static Future<void> pedirValoracion() async {}
}
