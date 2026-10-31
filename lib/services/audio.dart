import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Efectos de sonido (biblioteca elegida por Isaac). Todos cortos, precargados y con
/// un máximo de reproducciones simultáneas por efecto para no saturar.
class Sfx {
  static bool enabled = true;
  static double volume = 0.8;
  static final Map<String, AudioPool> _pools = {};
  static final Map<String, int> _last = {};
  static bool _loading = false;

  static const names = [
    'hoja_abre', 'hoja_cierra', 'pestana', 'error', 'confirmar',
    'renta', 'renta_multi', 'venta', 'compra', 'patrimonio', 'pago',
    'martillo', 'taladro', 'sierra', 'rodillo', 'cable', 'chispazo', 'tuberia', 'ladrillo', 'combo', 'fase',
    'fase_mercado', 'crisis', 'auge', 'aviso', 'rival',
    'impulso', 'objetivo', 'ciudad',
  ];

  /// Cuántas copias del mismo efecto pueden sonar a la vez.
  static int _max(String n) => switch (n) {
        'martillo' || 'ladrillo' || 'rodillo' || 'cable' || 'sierra' => 4,
        _ => 2,
      };

  static Future<void> init() async {
    if (_loading) return;
    _loading = true;
    await Audio.setup();
    for (final n in names) {
      try {
        _pools[n] = await AudioPool.create(source: AssetSource('audio/sfx/$n.wav'), maxPlayers: _max(n));
      } catch (e) {
        debugPrint('Sfx $n: $e');
      }
    }
  }

  /// Reproduce un efecto. Ignora repeticiones del mismo efecto a menos de 45 ms (ráfagas).
  static void play(String name, {double gain = 1}) {
    if (!enabled || volume <= 0) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - (_last[name] ?? 0) < 45) return;
    _last[name] = now;
    final p = _pools[name];
    if (p == null) return;
    unawaited(p.start(volume: (volume * gain).clamp(0.0, 1.0)).catchError((_) => () async {}));
  }
}

/// Música en bucle con fundido entre pistas: «menu», «mapa» y «crisis».
/// Los minijuegos usan la misma música que el mapa (no cambia).
///
/// Todas las órdenes pasan por una cola, así que dos cambios seguidos no se pisan, y con la
/// app en segundo plano solo se apunta la pista que toca: nada suena hasta volver.
class Music {
  static bool enabled = true;
  static double volume = 0.6;
  static final AudioPlayer _a = AudioPlayer(playerId: 'musicA');
  static final AudioPlayer _b = AudioPlayer(playerId: 'musicB');
  static bool _aOn = true;
  /// Pista que suena (o sonaba al pausar).
  static String? _track;
  /// Pista que debería sonar.
  static String? _want;
  static bool _paused = false;
  static Timer? _fade;
  static Future<void> _queue = Future.value();

  static AudioPlayer get _cur => _aOn ? _a : _b;
  static AudioPlayer get _next => _aOn ? _b : _a;
  static bool get _audible => enabled && volume > 0 && !_paused;

  static void _run(Future<void> Function() job) {
    _queue = _queue.then((_) => job()).catchError((Object e) => debugPrint('Music: $e'));
  }

  /// Pide una pista. Si ya es la que suena, no hace nada.
  static Future<void> play(String track) async {
    _want = track;
    if (!_audible || _track == track) return;
    _run(_switch);
  }

  static Future<void> _switch() async {
    final track = _want;
    if (track == null || !_audible || track == _track) return;
    await Audio.setup();
    final from = _cur;
    final to = _next;
    _fade?.cancel();
    await to.stop();
    await to.setReleaseMode(ReleaseMode.loop);
    await to.setVolume(0);
    await to.play(AssetSource('audio/music/$track.wav'));
    _track = track;
    _aOn = !_aOn;
    _crossfade(from, to);
  }

  static void _crossfade(AudioPlayer from, AudioPlayer to) {
    _fade?.cancel();
    var t = 0;
    const steps = 12;
    _fade = Timer.periodic(const Duration(milliseconds: 100), (tm) {
      t++;
      final k = t / steps;
      to.setVolume(volume * k);
      from.setVolume(volume * (1 - k));
      if (t >= steps) {
        tm.cancel();
        from.stop();
      }
    });
  }

  static Future<void> setVolume(double v) async {
    volume = v;
    _run(() async {
      if (v <= 0) {
        _fade?.cancel();
        await _a.pause();
        await _b.pause();
        return;
      }
      await _cur.setVolume(v);
      if (_audible && _cur.state != PlayerState.playing) {
        _track = null;
        await _switch();
      }
    });
  }

  static Future<void> setEnabled(bool on) async {
    enabled = on;
    if (!on) {
      _run(() async {
        _fade?.cancel();
        await _a.stop();
        await _b.stop();
        _track = null;
      });
    } else {
      _run(_switch);
    }
  }

  /// App en segundo plano: silencio total hasta [resume].
  static Future<void> pause() async {
    if (_paused) return;
    _paused = true;
    _run(() async {
      _fade?.cancel();
      await _a.pause();
      await _b.pause();
    });
  }

  static Future<void> resume() async {
    if (!_paused) return;
    _paused = false;
    _run(() async {
      if (!_audible) return;
      if (_track != null && _track == _want) {
        await _cur.setVolume(volume);
        await _cur.resume();
      } else {
        await _switch();
      }
    });
  }
}

/// Contexto de audio común: los efectos y la música se mezclan entre sí sin quitarse el foco
/// (en Android cada efecto pedía el foco y cortaba la música un instante).
class Audio {
  static Future<void>? _setup;
  static Future<void> setup() => _setup ??= _apply();

  static Future<void> _apply() async {
    try {
      final ctx = AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build();
      await AudioPlayer.global.setAudioContext(ctx);
      await Music._a.setAudioContext(ctx);
      await Music._b.setAudioContext(ctx);
    } catch (e) {
      debugPrint('AudioContext: $e');
    }
  }
}
