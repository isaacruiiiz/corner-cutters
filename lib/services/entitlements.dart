import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backend.dart';

/// Tipo de usuario (lo decide el servidor; el admin lo cambia en el panel).
enum Rol { usuario, pro, admin }

Rol rolFrom(String? s) => switch (s) {
      'admin' => Rol.admin,
      'pro' => Rol.pro,
      _ => Rol.usuario,
    };

/// Productos de la tienda (Google Play / App Store), no consumibles.
class Productos {
  static const epocas = 'cc_epocas';
  static const pro = 'cc_pro';
  static const all = {epocas, pro};
}

/// Qué tiene desbloqueado este usuario: rol y DLC regalado (servidor) + compras de la tienda (móvil).
///
/// - Admin: sin anuncios, pack de épocas y panel.
/// - Pro (por rol o por compra): sin anuncios.
/// - Pack de épocas: comprado en la tienda o regalado por el admin.
class Entitlements extends ChangeNotifier {
  Entitlements._();
  static final Entitlements instance = Entitlements._();

  Rol rol = Rol.usuario;
  bool dlcRegalado = false;
  final Set<String> comprado = {};
  String? email;

  bool get isAdmin => rol == Rol.admin;
  bool get isPro => rol == Rol.pro || rol == Rol.admin || comprado.contains(Productos.pro);
  bool get sinAnuncios => isPro;
  bool get hasEras => isAdmin || dlcRegalado || comprado.contains(Productos.epocas);

  /// Cómo se tiene el pack (para la ficha de la cuenta).
  String get erasOrigen => comprado.contains(Productos.epocas)
      ? 'Comprado'
      : dlcRegalado
          ? 'Regalado'
          : isAdmin
              ? 'Admin'
              : 'No';

  String get rolNombre => switch (rol) {
        Rol.admin => 'Admin',
        Rol.pro => 'Pro',
        Rol.usuario => comprado.contains(Productos.pro) ? 'Pro (compra)' : 'Normal',
      };

  static const _k = 'hs_derechos';

  /// Último estado conocido (sirve sin conexión).
  Future<void> loadCache() async {
    final p = await SharedPreferences.getInstance();
    final l = p.getStringList(_k);
    if (l == null) return;
    rol = rolFrom(l.isNotEmpty ? l[0] : null);
    dlcRegalado = l.length > 1 && l[1] == '1';
    comprado
      ..clear()
      ..addAll(l.skip(2).where(Productos.all.contains));
    notifyListeners();
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_k, [rol.name, dlcRegalado ? '1' : '0', ...comprado]);
  }

  /// Pide al servidor el rol y el DLC regalado de la cuenta con la que se ha entrado.
  Future<void> refresh() async {
    final j = await Backend.miPerfil();
    if (j == null) return;
    apply(rol: rolFrom(j['rol'] as String?), dlc: j['dlc_epocas'] == true, email: j['email'] as String?);
  }

  /// Cambio de cuenta: lo regalado era de la otra cuenta (las compras van con la tienda del móvil).
  void resetServer() {
    rol = Rol.usuario;
    dlcRegalado = false;
    email = null;
    _save();
    notifyListeners();
  }

  @visibleForTesting
  void apply({Rol? rol, bool? dlc, String? email, Set<String>? owned}) {
    if (rol != null) this.rol = rol;
    if (dlc != null) dlcRegalado = dlc;
    if (email != null) this.email = email;
    if (owned != null) {
      comprado
        ..clear()
        ..addAll(owned.where(Productos.all.contains));
    }
    _save();
    notifyListeners();
  }

  /// La tienda confirma una compra (nueva o restaurada).
  void owns(String product) {
    if (!Productos.all.contains(product) || comprado.contains(product)) return;
    comprado.add(product);
    _save();
    notifyListeners();
  }
}
