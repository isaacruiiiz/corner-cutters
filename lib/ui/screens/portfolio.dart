import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../game/model.dart';
import '../common.dart';
import '../widgets/atoms.dart';
import 'property.dart';
import 'selector.dart';

import '../../core/texto.dart';
/// Cartera: todas las viviendas con su estado.
class PortfolioScreen extends ConsumerStatefulWidget {
  final int? lotId;
  const PortfolioScreen({super.key, this.lotId});
  @override
  ConsumerState<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends ConsumerState<PortfolioScreen> {
  PState? _f;
  @override
  Widget build(BuildContext context) {
    final g = ref.watch(gameProvider);
    var all = g.props.toList();
    if (widget.lotId != null) all = all.where((p) => p.lotId == widget.lotId).toList();
    final list = _f == null ? all : all.where((p) => p.state == _f).toList();
    int count(PState s) => all.where((p) => p.state == s).length;
    final groups = groupByLot(list);
    void renoAll(List<Property> ps) => push(context, SelectorScreen(propId: ps.first.id, propIds: [for (final p in ps) p.id]));
    return Screen(
      child: Column(children: [
        BackHeader(widget.lotId == null ? 'Cartera' : 'Edificio',
            sub: widget.lotId == null ? '${plural(all.length, 'vivienda', 'viviendas')} · ${g.city.name}' : g.addressOfLot(g.city.lots[widget.lotId!])),
        Expanded(
          child: Body([
            StatGrid([
              Stat('Patrimonio', money(g.netWorth, compact: true), color: Hc.acc),
              Stat('Activos', money(g.assets, compact: true)),
              Stat('Neto/mes', money(g.monthlyNet, compact: true), color: g.monthlyNet >= 0 ? Hc.ok : Hc.bad),
            ], columns: 3),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                FChip('Todas', on: _f == null, count: all.length, onTap: () => setState(() => _f = null)),
                for (final s in PState.values)
                  if (count(s) > 0) ...[
                    const SizedBox(width: 6),
                    FChip(pstateLabel[s]!.toLowerCase().replaceFirstMapped(RegExp(r'^.'), (m) => m[0]!.toUpperCase()),
                        on: _f == s, count: count(s), onTap: () => setState(() => _f = s)),
                  ],
              ]),
            ),
            if (widget.lotId != null && list.where((p) => p.state != PState.obra).length > 1)
              HsButton('Reformar ${list.where((p) => p.state != PState.obra).length} viviendas igual',
                  kind: BtnKind.sec, size: BtnSize.sm, icon: Icons.handyman_outlined, block: true, onTap: () => renoAll(list.where((p) => p.state != PState.obra).toList())),
            ListBlock([
                if (list.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('Nada con este filtro.', style: TextStyle(color: Hc.mut))),
                if (widget.lotId != null)
                  for (var i = 0; i < list.length; i++)
                    PropRow(g, list[i], title: unitLabel(list[i]), last: i == list.length - 1, onTap: () => push(context, PropertyScreen(propId: list[i].id)))
                else
                  for (var i = 0; i < groups.length; i++)
                    groups[i].length == 1
                        ? PropRow(g, groups[i].first, last: i == groups.length - 1, onTap: () => push(context, PropertyScreen(propId: groups[i].first.id)))
                        : BuildingRow(g, groups[i],
                            key: ValueKey('b${groups[i].first.lotId}'),
                            last: i == groups.length - 1,
                            onUnit: (p) => push(context, PropertyScreen(propId: p.id)),
                            onRenoAll: renoAll),
              ]),
            Panel(
              kind: PanelKind.inset,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Column(children: [
                KV('Efectivo', money(g.cash)),
                KV('Valor de las viviendas', money(g.assets)),
                KV('Deuda', money(-g.totalDebt), color: g.totalDebt > 0 ? Hc.bad : Hc.mut),
                KV('Rentas', '${money(g.monthlyRent)}/mes', color: Hc.ok),
                KV('Salarios', '${money(-g.monthlySalaries)}/mes'),
                KV('Intereses', '${money(-g.monthlyInterest)}/mes'),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}
