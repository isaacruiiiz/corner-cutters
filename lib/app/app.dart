import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../core/i18n.dart';
import '../core/gfx.dart';
import '../core/theme.dart';
import '../services/audio.dart';
import '../services/storage.dart';
import '../services/telemetria.dart';
import '../ui/screens/title_screen.dart';
import '../ui/shell.dart';
import 'providers.dart';

final navKey = GlobalKey<NavigatorState>();

class CornerCuttersApp extends StatelessWidget {
  const CornerCuttersApp({super.key});
  @override
  Widget build(BuildContext context) {
    return GameRunner(
      child: I18nScope(
        child: ValueListenableBuilder<String>(
          valueListenable: I18n.actual,
          builder: (context, idioma, _) => MaterialApp(
        title: 'Corner Cutters',
        locale: I18n.locale,
        supportedLocales: [for (final c in I18n.idiomas.keys) Locale(c)],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        navigatorKey: navKey,
        home: const Boot(),
        builder: (context, child) {
          // Pantalla completa en móvil, tablet y horizontal. La letra del sistema se respeta
          // hasta ×1,3; por encima, el HUD y la barra se encogen para no cortarse.
          final mq = MediaQuery.of(context);
          final scale = mq.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.3);
          return ColoredBox(
            color: Hc.bgDeep,
            child: MediaQuery(data: mq.copyWith(textScaler: scale), child: child!),
          );
        },
          ),
        ),
      ),
    );
  }
}

/// Carga la partida guardada o muestra la portada.
class Boot extends ConsumerStatefulWidget {
  const Boot({super.key});
  @override
  ConsumerState<Boot> createState() => _BootState();
}

class _BootState extends ConsumerState<Boot> {
  bool _ready = false;
  bool _hasSave = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final g = ref.read(gameProvider);
    final j = await Storage.load();
    if (j != null) {
      try {
        g.loadJson(j);
        g.catchUp();
        Money.scale = g.eraCfg?.priceLevel ?? 1;
        _hasSave = true;
      } catch (e) {
        debugPrint('Partida dañada: $e');
        _hasSave = false;
      }
    }
    // Ajustes de calidad gráfica y sonido.
    Gfx.apply(g.settings.quality);
    Sfx.enabled = g.settings.sound;
    Sfx.volume = g.settings.sfx;
    Music.enabled = g.settings.sound;
    Music.volume = g.settings.music;
    if (_hasSave) Telemetria.activa = g.settings.telemetry;
    unawaited(Telemetria.enviar());
    final a = await Storage.getString('alias');
    if (a != null && a.isNotEmpty) ref.read(aliasProvider.notifier).state = a;
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        backgroundColor: Hc.bg,
        body: Center(child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(color: Hc.acc, strokeWidth: 3))),
      );
    }
    return TitleScreen(hasSave: _hasSave, onContinue: () => _go(context));
  }

  void _go(BuildContext context) {
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (c, a, b) => const Shell(),
      transitionsBuilder: (c, a, b, child) => FadeTransition(opacity: a, child: child),
    ));
  }
}
