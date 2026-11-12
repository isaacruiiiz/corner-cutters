import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Guardado local de la partida.
class Storage {
  static const _key = 'hs_partida_v1';
  static const _bak = 'hs_partida_v1_bak';
  static SharedPreferences? _p;

  static Future<SharedPreferences> get _prefs async => _p ??= await SharedPreferences.getInstance();

  static Future<Map<String, dynamic>?> load() async {
    final p = await _prefs;
    for (final k in [_key, _bak]) {
      final raw = p.getString(k);
      if (raw == null) continue;
      try {
        return jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {}
    }
    return null;
  }

  static Future<void> save(Map<String, dynamic> j) async {
    final p = await _prefs;
    final old = p.getString(_key);
    if (old != null) await p.setString(_bak, old);
    await p.setString(_key, jsonEncode(j));
  }

  static Future<void> clear() async {
    final p = await _prefs;
    await p.remove(_key);
    await p.remove(_bak);
  }

  static Future<bool> hasSave() async => (await _prefs).containsKey(_key);

  // ---------- DLC de épocas: cada época guarda su partida aparte ----------
  static String _eraKey(String id) => 'hs_epoca_$id';
  static const _eraProgress = 'hs_epocas_progreso';

  static Future<Map<String, dynamic>?> loadEra(String id) async {
    final raw = (await _prefs).getString(_eraKey(id));
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveEra(String id, Map<String, dynamic> j) async => (await _prefs).setString(_eraKey(id), jsonEncode(j));

  static Future<void> clearEra(String id) async => (await _prefs).remove(_eraKey(id));

  /// Progreso por época: mejor medalla (0–3) y mejor patrimonio.
  static Future<Map<String, Map<String, num>>> eraProgress() async {
    final raw = (await _prefs).getString(_eraProgress);
    if (raw == null) return {};
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return m.map((k, v) => MapEntry(k, Map<String, num>.from(v as Map)));
    } catch (_) {
      return {};
    }
  }

  static Future<void> recordEra(String id, int medal, double netWorth) async {
    final all = await eraProgress();
    final cur = all[id] ?? {};
    all[id] = {
      'medal': medal > (cur['medal'] ?? 0) ? medal : (cur['medal'] ?? 0),
      'best': netWorth > (cur['best'] ?? 0) ? netWorth : (cur['best'] ?? 0),
      'played': (cur['played'] ?? 0) + 1,
    };
    await (await _prefs).setString(_eraProgress, jsonEncode(all));
  }

  /// Junta el progreso de épocas de la cuenta con el de este móvil: se queda la mejor medalla y la mejor marca.
  static Future<void> mergeEraProgress(Map<String, dynamic> cloud) async {
    final all = await eraProgress();
    cloud.forEach((id, v) {
      if (v is! Map) return;
      final c = <String, num>{for (final e in v.entries) if (e.value is num) '${e.key}': e.value as num};
      final cur = all[id] ?? {};
      num mayor(String k) => (c[k] ?? 0) > (cur[k] ?? 0) ? (c[k] ?? 0) : (cur[k] ?? 0);
      all[id] = {'medal': mayor('medal'), 'best': mayor('best'), 'played': mayor('played')};
    });
    await (await _prefs).setString(_eraProgress, jsonEncode(all));
  }

  static Future<bool> hasEra(String id) async => (await _prefs).containsKey(_eraKey(id));

  /// Correos con los que se ha entrado en este dispositivo (solo el correo, nunca la contraseña).
  static Future<List<String>> knownAccounts() async {
    final raw = (await _prefs).getString('cuentas');
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).cast<String>();
    } catch (_) {
      return [];
    }
  }

  static Future<void> rememberAccount(String email) async {
    final l = await knownAccounts();
    l.remove(email);
    l.insert(0, email);
    await (await _prefs).setString('cuentas', jsonEncode(l.take(5).toList()));
  }

  static Future<void> forgetAccount(String email) async {
    final l = await knownAccounts()..remove(email);
    await (await _prefs).setString('cuentas', jsonEncode(l));
  }

  static Future<String?> getString(String k) async => (await _prefs).getString(k);
  static Future<void> setString(String k, String v) async => (await _prefs).setString(k, v);
}
