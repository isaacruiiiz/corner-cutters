import 'dart:typed_data';
import 'dart:ui' show Rect;

/// Web: sin valoración ni menú de compartir.
class Social {
  static bool get puedeCompartir => false;
  static Future<void> compartir(String texto, {Rect? origen}) async {}
  static Future<void> compartirImagen(Uint8List png, String texto, {Rect? origen}) async {}
  static Future<void> pedirValoracion() async {}
}
