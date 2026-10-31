import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Nivel gráfico efectivo.
///  - alta: cristal con desenfoque en vivo, ambiente a 30 fps con coches y barcos, pulso continuo.
///  - media: cristal opaco (sin desenfoque), ambiente a 15 fps, el pulso se para a los pocos segundos.
///  - baja: sin ambiente ni pulso; lo mínimo para jugar fresco y con poca batería.
enum GfxLevel { baja, media, alta }

/// Calidad gráfica. En «auto» arranca en media y baja a baja si los fotogramas van lentos.
class Gfx {
  static final ValueNotifier<GfxLevel> level = ValueNotifier(GfxLevel.media);
  static String _mode = 'auto';
  static bool _listening = false;
  static int _slow = 0, _frames = 0;

  static bool get liveBlur => level.value == GfxLevel.alta;
  static bool get ambient => level.value != GfxLevel.baja;
  static bool get traffic => level.value == GfxLevel.alta;
  static int get ambientFps => level.value == GfxLevel.alta ? 30 : 15;
  static bool get pulse => level.value != GfxLevel.baja;
  static bool get pulseForever => level.value == GfxLevel.alta;

  static String get mode => _mode;

  /// Aplica el ajuste guardado: auto, alta, media o baja.
  static void apply(String mode) {
    _mode = mode;
    switch (mode) {
      case 'alta':
        level.value = GfxLevel.alta;
      case 'baja':
        level.value = GfxLevel.baja;
      case 'media':
        level.value = GfxLevel.media;
      default:
        if (level.value == GfxLevel.alta) level.value = GfxLevel.media;
        _listen();
    }
  }

  /// En automático: si más de la cuarta parte de 240 fotogramas tarda más de 20 ms en
  /// pintarse, baja un escalón (y no vuelve a subir solo para no oscilar).
  static void _listen() {
    if (_listening) return;
    _listening = true;
    SchedulerBinding.instance.addTimingsCallback((timings) {
      if (_mode != 'auto' || level.value == GfxLevel.baja) return;
      for (final t in timings) {
        _frames++;
        if (t.rasterDuration.inMilliseconds > 20 || t.buildDuration.inMilliseconds > 20) _slow++;
      }
      if (_frames >= 240) {
        if (_slow > _frames / 4) level.value = GfxLevel.values[level.value.index - 1];
        _frames = 0;
        _slow = 0;
      }
    });
  }
}
