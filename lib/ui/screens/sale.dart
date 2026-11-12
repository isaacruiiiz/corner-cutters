import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../game/engine.dart';
import '../../game/model.dart';
import '../../game/texts.dart';
import '../common.dart';
import '../map/map_view.dart';
import '../widgets/atoms.dart';
import '../widgets/overlays.dart';
import 'buy.dart';

import '../../core/i18n.dart';
import '../../services/config.dart';
import '../../services/social.dart';
import '../../services/telemetria.dart';
import '../../core/texto.dart';
/// Tarjeta de oferta con aceptar/rechazar (offer_row).
class OfferCard extends ConsumerWidget {
  final Offer offer;
  final bool showAddress;
  const OfferCard({super.key, required this.offer, this.showAddress = false});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = ref.watch(gameProvider);
    final p = g.prop(offer.propId);
    if (p == null) return const SizedBox();
    final v = g.valueOf(p);
    final ratio = offer.amount / v;
    final left = Duration(milliseconds: ((offer.expires - g.clock) / g.speed).round());
    return Panel(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Cap(showAddress ? g.addressOf(p) : 'Oferta', color: Hc.info),
              const SizedBox(height: 2),
              Text(money(offer.amount), style: Ht.numM.copyWith(color: Hc.acc)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Tag('${mult(ratio)} valor', color: ratio >= 1 ? Hc.ok : Hc.warn),
            const SizedBox(height: 6),
            Text('caduca en ${dur(left)}', style: Ht.small.copyWith(fontSize: 11)),
          ]),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: HsButton('Aceptar', kind: BtnKind.ok, size: BtnSize.sm, block: true, onTap: () => g.acceptOffer(offer)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: HsButton('Rechazar', kind: BtnKind.sec, size: BtnSize.sm, block: true, onTap: () => g.rejectOffer(offer)),
          ),
        ]),
      ]),
    );
  }
}

/// Todas las ofertas recibidas.
class OffersScreen extends ConsumerWidget {
  const OffersScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = ref.watch(gameProvider);
    return Screen(
      child: Column(children: [
        BackHeader('Ofertas', sub: plural(g.offers.length, 'oferta pendiente', 'ofertas pendientes')),
        Expanded(
          child: Body([
            if (g.offers.isEmpty) const Note('Sin ofertas. Pedir menos atrae más compradores; pedir más, ofertas más altas.'),
            for (final o in g.offers) OfferCard(offer: o, showAddress: true),
            const Note('Cada oferta caduca a las 24 horas reales. Si un comprador paga el precio pedido, la venta se cierra sola y las ofertas pendientes se cancelan.',
                icon: Icons.info_outline),
          ]),
        ),
      ]),
    );
  }
}

/// Venta cerrada: resumen y siguiente decisión (reinvertir).
class SaleClosedScreen extends ConsumerWidget {
  final Notice notice;
  const SaleClosedScreen({super.key, required this.notice});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = ref.watch(gameProvider);
    final d = notice.data;
    final amount = (d['amount'] as num).toDouble();
    final debt = (d['debt'] as num).toDouble();
    final paid = (d['paid'] as num).toDouble();
    final profit = (d['profit'] as num).toDouble();
    final lot = d['lot'] as int;
    return Screen(
      dock: Column(mainAxisSize: MainAxisSize.min, children: [
        HsButton('Reinvertir', block: true, size: BtnSize.lg, icon: Icons.add_home_outlined, onTap: () {
          Navigator.of(context).pushReplacement(glassRoute(const BuyScreen()));
        }),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          HsButton('Volver al mapa', kind: BtnKind.ghost, size: BtnSize.sm, onTap: () => Navigator.pop(context)),
          if (profit > 0 && Social.puedeCompartir) ...[
            const SizedBox(width: 8),
            HsButton('Compartir', kind: BtnKind.ghost, size: BtnSize.sm, icon: Icons.ios_share_rounded, onTap: () {
              Telemetria.evento('compartir', {'que': 'venta'});
              Social.compartir(
                  '${tr('He vendido ${d['address']} por ${money(amount)} en Corner Cutters: ${money(profit)} de beneficio.')} ${AppConfig.current.webUrl}'.trim(),
                  origen: origenDe(context));
            }),
          ],
        ]),
      ]),
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: MapCrop(lotId: lot, height: 190, zoom: 3.2),
        ),
        const SizedBox(height: 12),
        const Center(child: Cap('Venta cerrada', color: Hc.ok)),
        const SizedBox(height: 6),
        Center(child: Text(d['address'] as String, style: Ht.display.copyWith(fontSize: 32), textAlign: TextAlign.center)),
        const SizedBox(height: 14),
        Center(
          child: Pose(rz: -7, child: GlowText(money(amount), style: Ht.display.copyWith(fontSize: 52))),
        ),
        const SizedBox(height: 18),
        Panel(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Column(children: [
            KV('Precio de venta', money(amount), color: Hc.acc),
            KV('Compra', money(-paid)),
            if (debt > 0) KV('Hipoteca cancelada', money(-debt), color: Hc.bad),
            KV('Beneficio', money(profit, sign: true), color: profit >= 0 ? Hc.ok : Hc.bad, big: true),
            KV('Efectivo ahora', money(g.cash)),
          ]),
        ),
        const SizedBox(height: 12),
        const Quote(Tx.ventaCerrada),
      ]),
    );
  }
}

/// Atajo para mostrar un toast de oferta aceptada.
void offerAccepted(BuildContext context, double amount) => toast(context, 'Vendida por ${money(amount)}');
