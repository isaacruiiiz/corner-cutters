import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../guia.dart';
import '../../app/providers.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../game/data.dart';
import '../../game/engine.dart';
import '../../game/texts.dart';
import '../common.dart';
import '../map/map_view.dart';
import '../widgets/atoms.dart';
import 'property.dart';

import '../../core/texto.dart';
/// Obra terminada: calidad, coste y beneficio. Siguiente decisión: alquilar o vender.
class ObraFinScreen extends ConsumerWidget {
  final Notice notice;
  const ObraFinScreen({super.key, required this.notice});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = ref.watch(gameProvider);
    final p = notice.propId == null ? null : g.prop(notice.propId!);
    final d = notice.data;
    final q = (d['quality'] as num).toDouble();
    final cost = (d['cost'] as num).toDouble();
    final paid = (d['paid'] as num).toDouble();
    final value = p == null ? (d['value'] as num).toDouble() : g.valueOf(p);
    final profit = value - paid - cost;
    final levels = <Trade, int>{for (final t in Trade.values) t: ((d['levels'] as Map)[t.name] as num).toInt()};
    final sector = Sector.values[d['sector'] as int];
    final partial = d['partial'] == true;
    return Screen(
      dock: p == null
          ? HsButton('Volver', block: true, onTap: () => Navigator.pop(context))
          : Column(mainAxisSize: MainAxisSize.min, children: [
              if (g.canBuy)
                Row(children: [
                  Expanded(
                    child: GuiaMarca(GuiaPunto.alquilarFin,
                        child: HsButton('Alquilar', kind: BtnKind.ok, block: true, size: BtnSize.lg, icon: Icons.key_outlined,
                            onTap: () => Navigator.of(context).pushReplacement(glassRoute(RentScreen(propId: p.id))))),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: HsButton('Vender', block: true, size: BtnSize.lg, icon: Icons.sell_outlined,
                        onTap: () => Navigator.of(context).pushReplacement(glassRoute(SellScreen(propId: p.id)))),
                  ),
                ])
              else
                HsButton('Ver ficha', block: true, size: BtnSize.lg,
                    onTap: () => Navigator.of(context).pushReplacement(glassRoute(PropertyScreen(propId: p.id)))),
              const SizedBox(height: 8),
              HsButton('Decidir más tarde', kind: BtnKind.ghost, size: BtnSize.sm, onTap: () => Navigator.pop(context)),
            ]),
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), children: [
        if (p != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(children: [
              MapCrop(lotId: p.lotId, height: 200, zoom: 3.4),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 90,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x000E2221), Hg.panel]),
                  ),
                ),
              ),
            ]),
          ),
        const SizedBox(height: 6),
        Center(child: Cap(partial ? 'Obra cerrada a medias' : 'Obra terminada', color: partial ? Hc.warn : Hc.ok)),
        const SizedBox(height: 6),
        Center(child: Text(p == null ? 'Reforma' : g.addressOf(p), style: Ht.display.copyWith(fontSize: 34), textAlign: TextAlign.center)),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Ring(q, size: 92, stroke: 8, color: q >= 0.999 ? Hc.ok : Hc.acc,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(dec(q, 2), style: Ht.numM),
                const Cap('Calidad'),
              ])),
          const SizedBox(width: 18),
          Pose.paper(
            child: Panel(
              kind: PanelKind.pop,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('BENEFICIO', style: Ht.cap.copyWith(color: const Color(0xB81A1304))),
                Text(money(profit), style: Ht.numL.copyWith(color: Hc.onAcc)),
                Text('sobre la compra', style: Ht.small.copyWith(color: const Color(0xB81A1304), fontSize: 11)),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        Panel(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Column(children: [
            KV('Valor de mercado', money(value), color: Hc.acc),
            KV('Compra', money(-paid)),
            KV('Coste de obra', money(-cost)),
            if (p != null) KV('Renta de referencia', '${money(g.rentRef(p))}/mes', color: Hc.ok),
            KV('Sector', si(sector).name),
          ]),
        ),
        const SizedBox(height: 12),
        Panel(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(children: [
            for (final t in Trade.values)
              Expanded(
                child: Column(children: [
                  Icon(ti(t).icon, size: 18, color: (levels[t] ?? 0) == 0 ? Hc.dim : (levels[t]! >= si(sector).optimal[t]! ? Hc.ok : Hc.warn)),
                  const SizedBox(height: 4),
                  Text((levels[t] ?? 0) == 0 ? '—' : '${levels[t]}', style: Ht.numS),
                  Text(ti(t).code, style: Ht.cap.copyWith(fontSize: 9)),
                ]),
              ),
          ]),
        ),
        const SizedBox(height: 12),
        Quote(Tx.finishedQuote(q, levels, sector)),
      ]),
    );
  }
}
