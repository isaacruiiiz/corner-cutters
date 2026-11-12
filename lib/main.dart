import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/gfx.dart';
import 'services/audio.dart';
import 'services/backend.dart';
import 'services/anuncios.dart';
import 'services/avisos.dart';
import 'services/telemetria.dart';
import 'services/config.dart';
import 'services/entitlements.dart';
import 'services/tienda.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthChangeEvent;

import 'core/i18n.dart';
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Errores de la app: se siguen viendo en consola y, además, se anotan (agrupados y sin datos personales).
  final porDefecto = FlutterError.onError;
  FlutterError.onError = (d) {
    porDefecto?.call(d);
    Telemetria.error(d.exception, d.stack);
  };
  PlatformDispatcher.instance.onError = (e, st) {
    debugPrint('Error sin capturar: $e\n$st');
    Telemetria.error(e, st);
    return true;
  };
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0A1A19),
  ));
  await AppConfig.load();
  await I18n.init();
  await Backend.init();
  // Tipo de usuario y compras: lo guardado sirve sin conexión; luego se actualiza.
  await Entitlements.instance.loadCache();
  unawaited(Entitlements.instance.refresh());
  Backend.authChanges?.listen((st) {
    if (st.event == AuthChangeEvent.signedOut) {
      Entitlements.instance.resetServer();
    } else if (st.event == AuthChangeEvent.signedIn || st.event == AuthChangeEvent.userUpdated) {
      Entitlements.instance.refresh();
    }
  });
  unawaited(Tienda.init());
  if (!Entitlements.instance.sinAnuncios) unawaited(Anuncios.init());
  Gfx.apply('auto');
  unawaited(Sfx.init());
  unawaited(Avisos.init().then((_) => Avisos.cancelar()));
  Telemetria.evento('abrir');
  runApp(const ProviderScope(child: CornerCuttersApp()));
}
