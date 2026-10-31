import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../backend.dart';
import '../entitlements.dart';

/// Google Play / App Store. Productos no consumibles: `cc_epocas` (pack) y `cc_pro` (sin anuncios).
/// La tienda del móvil es la que dice qué se ha comprado; el servidor solo lo anota para el panel.
class Tienda {
  static final _iap = InAppPurchase.instance;
  static StreamSubscription<List<PurchaseDetails>>? _sub;
  static bool _ok = false;
  static final Map<String, ProductDetails> _productos = {};
  static Completer<String?>? _espera;

  static bool get disponible => _ok;
  static Map<String, String> get precios => {for (final e in _productos.entries) e.key: e.value.price};

  static Future<void> init() async {
    try {
      _ok = await _iap.isAvailable().timeout(const Duration(seconds: 8));
      if (!_ok) return;
      _sub ??= _iap.purchaseStream.listen(_onCompras, onError: (Object e) => debugPrint('compras: $e'));
      final r = await _iap.queryProductDetails(Productos.all);
      for (final p in r.productDetails) {
        _productos[p.id] = p;
      }
      // Lo comprado antes (en este u otro móvil con la misma cuenta de la tienda).
      await _iap.restorePurchases();
    } catch (e) {
      debugPrint('Tienda no disponible: $e');
      _ok = false;
    }
  }

  static Future<void> _onCompras(List<PurchaseDetails> list) async {
    for (final p in list) {
      switch (p.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          Entitlements.instance.owns(p.productID);
          unawaited(Backend.registrarCompra(p.productID, plataforma: Platform.operatingSystem, compraId: p.purchaseID));
          _fin(null);
        case PurchaseStatus.error:
          _fin(p.error?.message ?? 'La compra no se ha completado');
        case PurchaseStatus.canceled:
          _fin('Compra cancelada');
        case PurchaseStatus.pending:
          break;
      }
      if (p.pendingCompletePurchase) await _iap.completePurchase(p);
    }
  }

  static void _fin(String? r) {
    final e = _espera;
    _espera = null;
    if (e != null && !e.isCompleted) e.complete(r);
  }

  /// Compra un producto. Devuelve null si ha ido bien o el motivo si no.
  static Future<String?> comprar(String producto) async {
    if (!_ok) await init();
    if (!_ok) return 'La tienda no está disponible en este móvil';
    final pd = _productos[producto];
    if (pd == null) return 'Este producto todavía no está a la venta en la tienda';
    _espera = Completer<String?>();
    try {
      final ok = await _iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: pd));
      if (!ok) return 'No se ha podido abrir la compra';
    } catch (e) {
      _espera = null;
      return '$e';
    }
    return _espera!.future.timeout(const Duration(minutes: 5), onTimeout: () => 'La tienda no ha respondido');
  }

  static Future<String?> restaurar() async {
    if (!_ok) await init();
    if (!_ok) return 'La tienda no está disponible en este móvil';
    try {
      await _iap.restorePurchases();
      return null;
    } catch (e) {
      return '$e';
    }
  }
}
