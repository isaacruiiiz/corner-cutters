import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../game/engine.dart';
import '../game/era.dart';
import '../services/audio.dart';
import '../services/backend.dart';
import '../services/entitlements.dart';
import '../services/storage.dart';

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
    });
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
    } else if (state == AppLifecycleState.resumed) {
      _startTick();
      Music.resume();
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
  // Las épocas no van a la nube ni al ranking: allí solo está la partida principal.
  if (!g.loaded || !Backend.ready || g.eraCfg != null) return false;
  return Backend.pushSave(g.toJson(),
      alias: ref.read(aliasProvider), netWorth: g.netWorth, reputation: g.meta.reputation, city: g.city.name);
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
