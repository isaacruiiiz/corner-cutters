import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';

/// Fila del panel admin.
class AdminUser {
  final String id;
  final String? email, alias, nota;
  final String rol;
  final bool dlc, comproEpocas, comproPro;
  final DateTime? visto, creado;
  final double patrimonio;
  AdminUser.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        email = j['email'] as String?,
        alias = j['alias'] as String?,
        nota = j['nota'] as String?,
        rol = j['rol'] as String? ?? 'usuario',
        dlc = j['dlc_epocas'] == true,
        comproEpocas = j['compro_epocas'] == true,
        comproPro = j['compro_pro'] == true,
        visto = DateTime.tryParse(j['visto'] as String? ?? ''),
        creado = DateTime.tryParse(j['creado'] as String? ?? ''),
        patrimonio = (j['patrimonio'] as num?)?.toDouble() ?? 0;
}

class RankRow {
  final String name;
  final double netWorth;
  final int reputation;
  final String city;
  final bool me;
  RankRow(this.name, this.netWorth, this.reputation, this.city, this.me);
}

/// Supabase: cuenta (anónima o email), guardado en la nube y ranking.
/// Si no hay claves en assets/config.json, todo funciona en local.
class Backend {
  static bool ready = false;
  static SupabaseClient get _db => Supabase.instance.client;

  /// Último estado de la conexión (se muestra en Cuenta si algo falla).
  static String status = 'Sin iniciar';

  static Future<void> init() async {
    final cfg = AppConfig.current;
    if (!cfg.hasSupabase) {
      status = 'Faltan las claves en assets/config.json';
      return;
    }
    try {
      if (!_initialized) {
        await Supabase.initialize(url: cfg.supabaseUrl, publishableKey: cfg.supabaseKey);
        _initialized = true;
      }
      ready = true;
      if (_db.auth.currentUser == null) {
        await _db.auth.signInAnonymously().timeout(const Duration(seconds: 12));
      }
      status = 'Conectado';
    } catch (e) {
      status = '$e';
      debugPrint('Supabase no disponible: $e');
      ready = _initialized && _db.auth.currentUser != null;
    }
  }

  static bool _initialized = false;

  static User? get user => ready ? _db.auth.currentUser : null;
  static bool get isAnonymous => user?.isAnonymous ?? true;
  static String? get email => user?.email;

  /// Convierte la cuenta anónima en una con email (enlace mágico).
  static Future<String?> linkEmail(String email) async {
    if (!ready) return 'Sin conexión con el servidor';
    try {
      await _db.auth.updateUser(UserAttributes(email: email), emailRedirectTo: kIsWeb ? null : redirect);
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return '$e';
    }
  }

  /// Dirección a la que vuelve el enlace del correo (abre la app).
  static const redirect = 'cornercutters://login-callback';

  static Future<String?> signInEmail(String email) async {
    if (!ready) return 'Sin conexión con el servidor';
    try {
      await _db.auth.signInWithOtp(email: email, shouldCreateUser: true, emailRedirectTo: kIsWeb ? null : redirect);
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return '$e';
    }
  }

  /// Envía el enlace de acceso a una cuenta que ya existe (partida empezada en otro dispositivo).
  static Future<String?> sendLoginLink(String email) async {
    if (!ready) await init();
    if (!ready) return 'Sin conexión con el servidor';
    try {
      await _db.auth.signInWithOtp(email: email.trim(), shouldCreateUser: false, emailRedirectTo: kIsWeb ? null : redirect);
      return null;
    } on AuthException catch (e) {
      if (e.message.toLowerCase().contains('signups not allowed') || e.statusCode == '422') {
        return 'No hay ninguna partida con ese correo';
      }
      return e.message;
    } catch (e) {
      return '$e';
    }
  }

  /// Cambios de sesión (al volver del enlace del correo).
  static Stream<AuthState>? get authChanges => ready ? _db.auth.onAuthStateChange : null;

  /// Mientras se cambia de cuenta no se sube nada: evita pisar la partida de la cuenta nueva
  /// con la que todavía está cargada en el móvil.
  static bool hold = false;

  /// Traduce los errores de Supabase más habituales.
  static String authError(Object e) {
    if (e is! AuthException) return '$e';
    final m = e.message.toLowerCase();
    if (m.contains('invalid login credentials')) return 'Correo o contraseña incorrectos';
    if (m.contains('email not confirmed')) return 'Falta confirmar el correo: abre el enlace que te enviamos al crear la cuenta';
    if (m.contains('already registered') || m.contains('already been registered')) return 'Ya hay una cuenta con ese correo: entra con tu contraseña';
    if (m.contains('password should be at least') || m.contains('weak')) return 'La contraseña necesita al menos 6 caracteres';
    if (m.contains('rate limit') || m.contains('security purposes') || e.statusCode == '429') return 'Demasiados intentos seguidos: espera un minuto';
    if (m.contains('signups not allowed') || m.contains('user not found')) return 'No hay ninguna cuenta con ese correo';
    if (m.contains('same_password') || m.contains('different from the old')) return 'Es la misma contraseña que ya tenías';
    return e.message;
  }

  /// Entrar con correo y contraseña. Si ya había otra sesión (invitado u otra cuenta), se sustituye.
  static Future<String?> signInPassword(String email, String password) async {
    if (!ready) await init();
    if (!ready) return 'Sin conexión con el servidor';
    try {
      await _db.auth.signInWithPassword(email: email.trim(), password: password);
      return null;
    } catch (e) {
      return authError(e);
    }
  }

  /// Crea una cuenta con contraseña. Devuelve (error, hay que confirmar el correo).
  static Future<(String?, bool)> signUp(String email, String password) async {
    if (!ready) await init();
    if (!ready) return ('Sin conexión con el servidor', false);
    try {
      final r = await _db.auth.signUp(email: email.trim(), password: password, emailRedirectTo: kIsWeb ? null : redirect);
      // Con la confirmación de correo activada no llega sesión hasta abrir el enlace.
      // Si el correo ya existía, Supabase devuelve un usuario sin identidades.
      if (r.user != null && (r.user!.identities?.isEmpty ?? false)) return ('Ya hay una cuenta con ese correo: entra con tu contraseña', false);
      return (null, r.session == null);
    } catch (e) {
      return (authError(e), false);
    }
  }

  /// Pone o cambia la contraseña de la cuenta con la que se ha entrado.
  static Future<String?> setPassword(String password) async {
    if (!ready || user == null) return 'Sin conexión con el servidor';
    try {
      await _db.auth.updateUser(UserAttributes(password: password));
      return null;
    } catch (e) {
      return authError(e);
    }
  }

  /// Cierra la sesión y deja una de invitado nueva (para poder seguir jugando sin cuenta).
  static Future<void> signOut() async {
    if (!ready) return;
    try {
      await _db.auth.signOut();
    } catch (e) {
      debugPrint('signOut: $e');
    }
    try {
      await _db.auth.signInAnonymously().timeout(const Duration(seconds: 12));
    } catch (e) {
      debugPrint('signInAnonymously: $e');
    }
  }

  /// El servidor ya tiene `guardar_partida` (supabase/seguridad.sql). Si no, se usa el camino antiguo.
  static bool _sinFuncionGuardar = false;

  /// Alias con el que la cuenta sale de verdad en el ranking (lo decide el servidor) y si es de invitado.
  static String? aliasPublico;
  static bool aliasDeInvitado = false;

  static bool _faltaFuncion(Object e) {
    final s = e is PostgrestException ? '${e.code} ${e.message}' : '$e';
    return s.contains('PGRST202') || s.contains('Could not find the function') || s.contains('does not exist');
  }

  /// Sube la partida y la fila del ranking. Devuelve true si llegó al servidor.
  ///
  /// El ranking lo escribe el servidor (`guardar_partida`): recorta cifras imposibles, filtra el
  /// alias y deja a los invitados como «Promotor anónimo».
  static Future<bool> pushSave(Map<String, dynamic> save,
      {required String alias, required double netWorth, required int reputation, required String city, Map<String, dynamic>? eras}) async {
    final u = user;
    if (u == null || hold) return false;
    if (!_sinFuncionGuardar) {
      try {
        final r = await _db.rpc('guardar_partida', params: {
          'p_datos': jsonEncode(save),
          'p_alias': alias,
          'p_patrimonio': netWorth.isFinite ? netWorth : 0,
          'p_reputacion': reputation,
          'p_ciudad': city,
          'p_epocas': eras == null || eras.isEmpty ? null : eras,
        });
        final j = r is Map ? Map<String, dynamic>.from(r) : const <String, dynamic>{};
        if (j['ok'] != true) return false; // demasiado seguido: se sube en el siguiente intento
        aliasPublico = j['alias'] as String?;
        aliasDeInvitado = j['invitado'] == true;
        lastPush = DateTime.now();
        return true;
      } catch (e) {
        if (!_faltaFuncion(e)) {
          debugPrint('guardar_partida: $e');
          return false;
        }
        _sinFuncionGuardar = true;
      }
    }
    try {
      await _db.from('partidas').upsert({
        'user_id': u.id,
        'datos': jsonEncode(save),
        'patrimonio': netWorth,
        'reputacion': reputation,
        'ciudad': city,
        'actualizado': DateTime.now().toUtc().toIso8601String(),
      });
      await _db.from('ranking').upsert({
        'user_id': u.id,
        'alias': alias,
        'patrimonio': netWorth,
        'reputacion': reputation,
        'ciudad': city,
        'actualizado': DateTime.now().toUtc().toIso8601String(),
      });
      lastPush = DateTime.now();
      return true;
    } catch (e) {
      debugPrint('pushSave: $e');
      return false;
    }
  }

  // ------------------------------------------------------------------ épocas en la nube

  /// Sube la partida de una época a su ranura.
  static Future<bool> pushEra(String id, Map<String, dynamic> save) async {
    final u = user;
    if (u == null || hold) return false;
    try {
      await _db.from('partidas_epoca').upsert({
        'user_id': u.id,
        'epoca': id,
        'datos': jsonEncode(save),
        'actualizado': DateTime.now().toUtc().toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('pushEra: $e');
      return false;
    }
  }

  /// Partidas de época guardadas en la cuenta (id de época → partida).
  static Future<Map<String, Map<String, dynamic>>> pullEras() async {
    final u = user;
    if (u == null) return {};
    try {
      final rows = await _db.from('partidas_epoca').select('epoca, datos').eq('user_id', u.id);
      final out = <String, Map<String, dynamic>>{};
      for (final r in rows) {
        try {
          out[r['epoca'] as String] = jsonDecode(r['datos'] as String) as Map<String, dynamic>;
        } catch (_) {}
      }
      return out;
    } catch (e) {
      debugPrint('pullEras: $e');
      return {};
    }
  }

  /// Borra la ranura de una época (al reiniciarla o terminarla).
  static Future<void> deleteEra(String id) async {
    final u = user;
    if (u == null) return;
    try {
      await _db.from('partidas_epoca').delete().eq('user_id', u.id).eq('epoca', id);
    } catch (e) {
      debugPrint('deleteEra: $e');
    }
  }

  /// Medallas y mejores marcas de las épocas guardadas en la cuenta.
  static Future<Map<String, dynamic>?> pullEraProgress() async {
    final u = user;
    if (u == null) return null;
    try {
      final row = await _db.from('partidas').select('epocas').eq('user_id', u.id).maybeSingle();
      final e = row?['epocas'];
      return e is Map ? Map<String, dynamic>.from(e) : null;
    } catch (e) {
      debugPrint('pullEraProgress: $e');
      return null;
    }
  }

  /// Guarda las medallas en la cuenta sin esperar a la siguiente subida de la partida.
  static Future<void> pushEraProgress(Map<String, dynamic> eras) async {
    final u = user;
    if (u == null || hold || eras.isEmpty) return;
    try {
      await _db.from('partidas').update({'epocas': eras}).eq('user_id', u.id);
    } catch (e) {
      debugPrint('pushEraProgress: $e');
    }
  }

  // ------------------------------------------------------------------ datos de uso y errores

  /// Envía un lote de eventos. true: guardado; false: fallo de red (reintentar); null: el servidor no tiene la función.
  static Future<bool?> registrarEventos(List<Map<String, dynamic>> lote, {String? version, String? plataforma, String? idioma}) async {
    if (!ready || user == null) return false;
    try {
      await _db.rpc('registrar_eventos', params: {
        'lote': lote,
        'p_version': version,
        'p_plataforma': plataforma,
        'p_idioma': idioma,
      }).timeout(const Duration(seconds: 10));
      return true;
    } catch (e) {
      return _faltaFuncion(e) ? null : false;
    }
  }

  static Future<void> registrarError(String mensaje, String pila, {String? version, String? plataforma}) async {
    if (!ready || user == null) return;
    try {
      await _db.rpc('registrar_error', params: {
        'p_mensaje': mensaje,
        'p_pila': pila,
        'p_version': version,
        'p_plataforma': plataforma,
      }).timeout(const Duration(seconds: 10));
    } catch (_) {
      // Sin red o sin la función: se pierde ese error, no pasa nada.
    }
  }

  /// Última subida correcta a la nube (se muestra en Cuenta).
  static DateTime? lastPush;

  static Future<Map<String, dynamic>?> pullSave() async {
    final u = user;
    if (u == null) return null;
    try {
      final row = await _db.from('partidas').select('datos').eq('user_id', u.id).maybeSingle();
      if (row == null) return null;
      return jsonDecode(row['datos'] as String) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('pullSave: $e');
      return null;
    }
  }

  static Future<List<RankRow>> ranking() async {
    if (!ready) return [];
    try {
      final rows = await _db
          .from('ranking')
          .select('user_id, alias, patrimonio, reputacion, ciudad')
          .order('reputacion', ascending: false)
          .order('patrimonio', ascending: false)
          .limit(50);
      final me = user?.id;
      return [
        for (final r in rows)
          RankRow(
            r['alias'] as String? ?? 'Promotor anónimo',
            (r['patrimonio'] as num?)?.toDouble() ?? 0,
            (r['reputacion'] as num?)?.toInt() ?? 0,
            r['ciudad'] as String? ?? '',
            r['user_id'] == me,
          )
      ];
    } catch (e) {
      debugPrint('ranking: $e');
      return [];
    }
  }

  // ------------------------------------------------------------------ cuentas y DLC

  /// Rol y DLC regalado de la cuenta (y marca la última visita).
  static Future<Map<String, dynamic>?> miPerfil() async {
    if (!ready || user == null) return null;
    try {
      final r = await _db.rpc('mi_perfil').timeout(const Duration(seconds: 10));
      return r == null ? null : Map<String, dynamic>.from(r as Map);
    } catch (e) {
      debugPrint('mi_perfil: $e');
      return null;
    }
  }

  /// Anota una compra de la tienda (para verla en el panel; la valida la tienda en el móvil).
  static Future<void> registrarCompra(String producto, {String? plataforma, String? compraId}) async {
    final u = user;
    if (u == null) return;
    try {
      await _db.from('compras').upsert({
        'user_id': u.id,
        'producto': producto,
        'plataforma': plataforma,
        'compra_id': compraId ?? 'sin-id',
      }, onConflict: 'user_id,producto,compra_id', ignoreDuplicates: true);
    } catch (e) {
      debugPrint('registrarCompra: $e');
    }
  }

  // ------------------------------------------------------------------ panel admin

  static Future<Map<String, dynamic>> adminResumen() async {
    final r = await _db.rpc('admin_resumen');
    return Map<String, dynamic>.from(r as Map);
  }

  static Future<List<AdminUser>> adminUsuarios({String buscar = '', bool soloCorreo = false, int desde = 0}) async {
    final r = await _db.rpc('admin_usuarios', params: {'buscar': buscar, 'solo_correo': soloCorreo, 'limite': 50, 'desde': desde});
    return [for (final x in r as List) AdminUser.fromJson(Map<String, dynamic>.from(x as Map))];
  }

  static Future<void> adminSetRol(String userId, String rol) => _db.rpc('admin_set_rol', params: {'usuario': userId, 'nuevo_rol': rol});

  static Future<void> adminRegalarDlc(String userId, bool regalar) => _db.rpc('admin_regalar_dlc', params: {'usuario': userId, 'regalar': regalar});

  static Future<void> adminNota(String userId, String texto) => _db.rpc('admin_nota', params: {'usuario': userId, 'texto': texto});

  /// Mensaje legible de un error del panel.
  static String adminError(Object e) {
    final s = e is PostgrestException ? e.message : '$e';
    if (s.contains('Solo para administradores')) return 'Tu cuenta no es admin';
    if (s.contains('quitarte el admin')) return 'No puedes quitarte el admin a ti mismo';
    if (s.contains('Could not find the function') || s.contains('does not exist')) return 'Falta ejecutar supabase/cuentas.sql';
    return s;
  }

  /// Borra la cuenta del jugador en el servidor (partida, ranking, perfil y compras anotadas)
  /// y deja una sesión de invitado nueva. Devuelve el error o null.
  static Future<String?> borrarCuenta() async {
    if (!ready) return 'Sin conexión con el servidor';
    try {
      await _db.rpc('borrar_mi_cuenta');
    } catch (e) {
      final s = adminError(e);
      return s.contains('cuentas.sql') ? 'Falta ejecutar supabase/cuentas.sql' : s;
    }
    await signOut();
    return null;
  }

  /// Titulares remotos opcionales (tabla titulares).
  static Future<List<String>> headlines() async {
    if (!ready) return [];
    try {
      final rows = await _db.from('titulares').select('texto').eq('activo', true).limit(20);
      return [for (final r in rows) r['texto'] as String];
    } catch (_) {
      return [];
    }
  }
}
