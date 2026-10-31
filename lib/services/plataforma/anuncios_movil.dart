import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config.dart';
import '../entitlements.dart';

/// AdMob: anuncios bonificados (opcionales, para impulsos) y algún intersticial al terminar obras.
/// Pro y admin no ven ninguno. Antes de pedir anuncios se pide el consentimiento (UMP, RGPD).
class Anuncios {
  static bool _init = false;
  static RewardedAd? _rew;
  static InterstitialAd? _int;
  static bool _loadingRew = false, _loadingInt = false;
  static DateTime _lastInt = DateTime.now();
  static int _obras = 0;

  // Unidades de prueba de Google: se usan mientras config.json no traiga las reales.
  static const _testRew = {'android': 'ca-app-pub-3940256099942544/5224354917', 'ios': 'ca-app-pub-3940256099942544/1712485313'};
  static const _testInt = {'android': 'ca-app-pub-3940256099942544/1033173712', 'ios': 'ca-app-pub-3940256099942544/4411468910'};

  static String get _os => Platform.isIOS ? 'ios' : 'android';
  static String get _rewId => AppConfig.current.adUnit('rewarded', _os) ?? _testRew[_os]!;
  static String get _intId => AppConfig.current.adUnit('interstitial', _os) ?? _testInt[_os]!;

  static bool get _off => Entitlements.instance.sinAnuncios;

  static Future<void> init() async {
    if (_init) return;
    try {
      await _consent();
      if (!await ConsentInformation.instance.canRequestAds()) return;
      await MobileAds.instance.initialize();
      _init = true;
      if (!_off) {
        _loadRew();
        _loadInt();
      }
    } catch (e) {
      debugPrint('Anuncios no disponibles: $e');
    }
  }

  static Future<void> _consent() {
    final c = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(ConsentRequestParameters(), () {
      ConsentForm.loadAndShowConsentFormIfRequired((FormError? e) {
        if (!c.isCompleted) c.complete();
      });
    }, (FormError e) {
      if (!c.isCompleted) c.complete();
    });
    return c.future.timeout(const Duration(seconds: 15), onTimeout: () {});
  }

  static bool get puedePrivacidad => _init;

  /// Ajustes de privacidad (para cambiar el consentimiento).
  static Future<void> privacidad() async {
    final c = Completer<void>();
    ConsentForm.showPrivacyOptionsForm((FormError? e) {
      if (!c.isCompleted) c.complete();
    });
    return c.future;
  }

  static void _loadRew() {
    if (_loadingRew || _rew != null) return;
    _loadingRew = true;
    RewardedAd.load(
      adUnitId: _rewId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rew = ad;
          _loadingRew = false;
        },
        onAdFailedToLoad: (e) {
          _loadingRew = false;
          debugPrint('bonificado: $e');
        },
      ),
    );
  }

  static void _loadInt() {
    if (_loadingInt || _int != null) return;
    _loadingInt = true;
    InterstitialAd.load(
      adUnitId: _intId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _int = ad;
          _loadingInt = false;
        },
        onAdFailedToLoad: (e) {
          _loadingInt = false;
          debugPrint('intersticial: $e');
        },
      ),
    );
  }

  /// Anuncio bonificado. true: recompensa ganada; false: cerrado antes; null: no hay anuncio ahora.
  static Future<bool?> recompensa() async {
    if (_off) return true;
    if (!_init) await init();
    if (!_init) return null;
    if (_rew == null) {
      _loadRew();
      for (var i = 0; i < 12 && _rew == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }
    final ad = _rew;
    if (ad == null) return null;
    _rew = null;
    final done = Completer<bool>();
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _loadRew();
        if (!done.isCompleted) done.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (a, e) {
        a.dispose();
        _loadRew();
        if (!done.isCompleted) done.complete(false);
      },
    );
    await ad.show(onUserEarnedReward: (a, r) => earned = true);
    return done.future;
  }

  /// Intersticial al terminar una obra: nunca en las 3 primeras ni más de uno cada 5 minutos.
  static Future<void> intersticial() async {
    _obras++;
    if (_off || !_init || _obras <= 3) return;
    if (DateTime.now().difference(_lastInt) < const Duration(minutes: 5)) return;
    final ad = _int;
    if (ad == null) {
      _loadInt();
      return;
    }
    _int = null;
    _lastInt = DateTime.now();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _loadInt();
      },
      onAdFailedToShowFullScreenContent: (a, e) {
        a.dispose();
        _loadInt();
      },
    );
    await ad.show();
  }
}
