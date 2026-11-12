import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Valoración en la tienda (diálogo nativo) y menú de compartir del sistema.
class Social {
  static const _kUltima = 'hs_valoracion_ms';
  static const _kVeces = 'hs_valoracion_veces';
  static const _kPrimera = 'hs_primer_dia_ms';

  static bool get puedeCompartir => true;

  /// [origen]: de dónde sale el menú en pantalla. En iPad es obligatorio (sin él, el menú no se abre).
  static Future<void> compartir(String texto, {Rect? origen}) async {
    try {
      await SharePlus.instance.share(ShareParams(text: texto, sharePositionOrigin: origen));
    } catch (e) {
      debugPrint('compartir: $e');
    }
  }

  /// Pide la valoración después de un buen momento (una venta con beneficio, una medalla).
  /// Nunca el primer día, como mucho tres veces y con 60 días entre una y otra. La tienda decide
  /// además si llega a mostrar el diálogo.
  static Future<void> pedirValoracion() async {
    try {
      final p = await SharedPreferences.getInstance();
      final ahora = DateTime.now().millisecondsSinceEpoch;
      final primera = p.getInt(_kPrimera);
      if (primera == null) {
        await p.setInt(_kPrimera, ahora);
        return;
      }
      const dia = 24 * 3600 * 1000;
      if (ahora - primera < dia) return;
      final veces = p.getInt(_kVeces) ?? 0;
      final ultima = p.getInt(_kUltima) ?? 0;
      if (veces >= 3 || ahora - ultima < 60 * dia) return;
      final r = InAppReview.instance;
      if (!await r.isAvailable()) return;
      await p.setInt(_kUltima, ahora);
      await p.setInt(_kVeces, veces + 1);
      await r.requestReview();
    } catch (e) {
      debugPrint('valoración: $e');
    }
  }
}
