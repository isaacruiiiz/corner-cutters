import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../game/engine.dart';
import '../game/era.dart';
import '../services/audio.dart';
import '../services/avisos.dart';
import '../services/avisos_plan.dart';
import '../services/backend.dart';
import '../services/entitlements.dart';
import '../services/storage.dart';
import '../services/telemetria.dart';

/// Partida en curso.
final gameProvider = ChangeNotifierProvider<Game>((ref) => Game());

/// Tipo de usuario, pack de épocas y Pro (servidor + tienda).
final entitlementsProvider = ChangeNotifierProvider<Entitlements>((ref) => Entitlements.instance);

/// Pestaña activa del menú inferior.
final tabProvider = StateProvider<int>((ref) => 0);

/// Alias público para el ranking.
final aliasProvider = StateProvider<String>((ref) => 'Promotor anónimo');

/// Reloj de la partida: tick cada segundo, guardado y ciclo de vida.
class GameRunner extends ConsumerStatefulWidget {
  final Widget child;
  const GameRunner({super.key, required this.child});
  @override
  ConsumerState<GameRunner> createState() => _GameRunnerState();
}

class _GameRunnerState extends ConsumerState<GameRunner> with WidgetsBindingObserver {
  Timer? _tick;
  int _n = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTick();
  }

  void _startTick() {
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      final g = ref.read(gameProvider);
      if (!g.loaded) return;
      g.tick();
      _n++;
      if (_n % 10 == 0) saveGame(ref);
      if (_n % 120 == 0) cloudSave(ref);
      if (_n % 60 == 30) Telemetria.enviar();
    });
  }

  int _avisosMs = 0;

  /// Al salir: programa las notificaciones del sistema con lo que va a pasar mientras el juego está cerrado.
  void _programarAvisos(Game g) {
    final now = nowMs();
    // «hidden» y «paused» llegan seguidos: con una vez basta.
    if (now - _avisosMs < 3000) return;
    _avisosMs = now;
    try {
      Avisos.programar(planAvisos(g.forecast(), g.settings.notif, DateTime.now(), ciudad: g.city.name));
    } catch (e) {
      debugPrint('avisos: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final g = ref.read(gameProvider);
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden || state == AppLifecycleState.detached) {
      // En segundo plano no corre nada: ni reloj ni música. Al volver se calcula lo pasado.
      _tick?.cancel();
      Music.pause();
      if (!g.loaded) return;
      saveGame(ref);
      cloudSave(ref);
      _programarAvisos(g);
      Telemetria.evento('sesion', {'seg': Telemetria.segundosSesion});
      Telemetria.enviar();
    } else if (state == AppLifecycleState.resumed) {
      _startTick();
      Music.resume();
      Avisos.cancelar();
      if (g.loaded) g.catchUp();
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

Future<void> saveGame(WidgetRef ref) async {
  final g = ref.read(gameProvider);
  if (!g.loaded) return;
  // Una época se guarda en su propia ranura: nunca pisa la partida principal.
  final era = g.eraCfg;
  if (era != null) {
    await Storage.saveEra(era.id, g.toJson());
    return;
  }
  await Storage.save(g.toJson());
}

Future<bool> cloudSave(WidgetRef ref) async {
  final g = ref.read(gameProvider);
  if (!g.loaded || !Backend.ready) return false;
  // Una época sube a su propia ranura: nunca pisa la partida principal ni cuenta para el ranking.
  final era = g.eraCfg;
  if (era != null) return Backend.pushEra(era.id, g.toJson());
  return Backend.pushSave(g.toJson(),
      alias: ref.read(aliasProvider),
      netWorth: g.netWorth,
      reputation: g.meta.reputation,
      city: g.city.name,
      eras: await Storage.eraProgress());
}

/// Trae de la cuenta las medallas y las partidas de época que no estén en este móvil
/// (al entrar en la cuenta desde un móvil nuevo o tras reinstalar).
Future<void> pullErasFromCloud() async {
  if (!Backend.ready) return;
  final progreso = await Backend.pullEraProgress();
  if (progreso != null && progreso.isNotEmpty) await Storage.mergeEraProgress(progreso);
  final nube = await Backend.pullEras();
  for (final e in nube.entries) {
    if (EraConfig.byId(e.key) == null || await Storage.hasEra(e.key)) continue;
    await Storage.saveEra(e.key, e.value);
  }
}

// ======================================================================
// DLC de épocas: cambiar entre la partida principal y una época
// ======================================================================

/// Entra en una época. Guarda antes la partida actual en su ranura.
/// [fresh]: empieza de cero aunque haya una partida guardada de esa época.
Future<void> enterEra(WidgetRef ref, EraConfig c, {bool fresh = false}) async {
  final g = ref.read(gameProvider);
  await saveGame(ref);
  final settings = g.settings;
  final saved = fresh ? null : await Storage.loadEra(c.id);
  if (saved != null && EraConfig.byId(saved['era'] as String?) != null) {
    g.loadJson(saved);
    g.lastTick = nowMs();
  } else {
    g.newEraGame(c, nowMs() % 1000000007);
    Telemetria.evento('epoca_empezar', {'id': c.id});
  }
  g.settings = settings;
  g.notices.clear();
  g.sounds.clear();
  g.offlineReport = null;
  Money.scale = c.priceLevel;
  ref.read(tabProvider.notifier).state = 0;
  await saveGame(ref);
  g.touch();
}

/// Vuelve a la partida principal (la época queda guardada donde estaba).
Future<bool> exitEra(WidgetRef ref) async {
  final g = ref.read(gameProvider);
  if (g.eraCfg == null) return true;
  await saveGame(ref);
  final main = await Storage.load();
  if (main == null) return false;
  final settings = g.settings;
  g.loadJson(main);
  g.settings = settings;
  g.notices.clear();
  g.sounds.clear();
  Money.scale = 1;
  g.catchUp();
  ref.read(tabProvider.notifier).state = 0;
  await saveGame(ref);
  g.touch();
  return true;
}
