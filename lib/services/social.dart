// Pedir valoración en la tienda y compartir. En la web no hacen nada.
import 'package:flutter/widgets.dart';


export 'plataforma/social_stub.dart' if (dart.library.io) 'plataforma/social_movil.dart';

/// Zona de la pantalla que ocupa [context]: sirve de origen al menú de compartir (lo exige el iPad).
Rect? origenDe(BuildContext context) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}
