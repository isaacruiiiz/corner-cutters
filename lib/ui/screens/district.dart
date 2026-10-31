import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../game/data.dart';
import '../../game/economy.dart';
import '../../game/model.dart';
import '../common.dart';
import '../widgets/atoms.dart';
import '../widgets/overlays.dart';
import 'company.dart';
import 'property.dart';

/// Barrio: efecto barrio, servicios y lotes.
class DistrictScreen extends ConsumerWidget {
  final int districtId;
  const DistrictScreen({super.key, required this.districtId});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = ref.watch(gameProvider);
    final d = g.city.districts[districtId];
    final mine = g.props.where((p) => g.lotOf(p).district == d.id).toList();
    final lots = g.city.lots.where((l) => l.district == d.id).length;
    final sv = g.services[d.id] ?? const <Service>[];
    final streets = <int, List<Property>>{};
    for (final p in mine) {
      streets.putIfAbsent(g.lotOf(p).street, () => []).add(p);
    }
    final ref0 = zi(d.zone).price * d.priceFactor * (1 + 0.05 * sv.length);
    return Screen(
      child: Column(children: [
        BackHeader(d.name, sub: '${zi(d.zone).name} · ${g.city.name}'),
        Expanded(
          child: Body([
            StatGrid([
              Stat('Precio ref.', '${money(ref0)}/m²', color: Hc.acc),
              Stat('Tus viviendas', '${mine.length} de $lots'),
              Stat('Servicios', '${sv.length}/3', extra: SegMeter(total: 3, ok: sv.length)),
              Stat('Variación semilla', '${d.priceFactor >= 1 ? '+' : ''}${dec((d.priceFactor - 1) * 100, 0)} %'),
            ]),
            if (!g.isPromoter)
              const Note('Efecto barrio, servicios y edificios enteros llegan con el Promotor (patrimonio de \$500.000).', icon: Icons.lock_outline),
            const SectionHead('Servicios'),
            ListBlock([
                for (final s in Service.values)
                  Li(
                    last: s == Service.metro,
                    lead: IconBox(serviceIcons[s]!, color: sv.contains(s) ? Hc.ok : Hc.mut),
                    title: serviceNames[s]!,
                    sub: sv.contains(s) ? 'Construido · +5 % al precio del barrio' : '+5 % al precio de referencia del barrio',
                    trail: sv.contains(s)
                        ? const Tag('Hecho', color: Hc.ok)
                        : HsButton(money(Eco.serviceCost(sv.length), compact: true), size: BtnSize.xs, onTap: g.isPromoter && sv.length < 3
                            ? () {
                                final e = g.buyService(d.id, s);
                                if (e != null) toast(context, e, error: true);
                              }
                            : null),
                  ),
              ]),
            if (streets.isNotEmpty) ...[
              const SectionHead('Efecto barrio por calle'),
              for (final e in streets.entries)
                Panel(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      Expanded(child: Text(g.city.streets[e.key].name, style: Ht.bodyB)),
                      Text('+${(math.min(0.10, 0.02 * math.max(0, e.value.where((p) => p.everRenovated).length - 1)) * 100).round()} %',
                          style: Ht.numS.copyWith(color: Hc.acc)),
                    ]),
                    const SizedBox(height: 8),
                    SegMeter(total: 5, ok: math.min(5, math.max(0, e.value.where((p) => p.everRenovated).length - 1))),
                    const SizedBox(height: 6),
                    for (final p in e.value)
                      GestureDetector(
                        onTap: () => push(context, PropertyScreen(propId: p.id)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(children: [
                            Dot(stateColor(p.state)),
                            const SizedBox(width: 8),
                            Expanded(child: Text(g.addressOf(p), style: Ht.small.copyWith(color: Hc.ink))),
                            Text(stateLabel(g, p), style: Ht.cap.copyWith(fontSize: 9, color: stateColor(p.state))),
                          ]),
                        ),
                      ),
                  ]),
                ),
            ],
            if (g.meta.templates.isNotEmpty && mine.any((p) => p.state == PState.ruina))
              HsButton('Aplicar plantilla a las ruinas', kind: BtnKind.sec, block: true, onTap: () => push(context, const TemplatesScreen())),
            const Note('Cada vivienda reformada en una misma calle suma un 2 % al valor y a la renta de las demás, hasta un 10 %.', icon: Icons.info_outline),
          ]),
        ),
      ]),
    );
  }
}
