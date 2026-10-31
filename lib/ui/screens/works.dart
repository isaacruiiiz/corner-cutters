import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../game/data.dart';
import '../../game/economy.dart';
import '../../game/engine.dart';
import '../../game/model.dart';
import '../common.dart';
import '../widgets/atoms.dart';
import '../map/sprites.dart';
import '../widgets/boosts.dart';
import 'buy.dart';
import 'company.dart';
import 'obra.dart';
import 'portfolio.dart';
import 'property.dart';
import 'selector.dart';

/// Obras en curso.
class WorksScreen extends ConsumerWidget {
  const WorksScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = ref.watch(gameProvider);
    final obras = g.props.where((p) => p.state == PState.obra).toList();
    final ruins = g.props.where((p) => p.state == PState.ruina).toList();
    final ready = g.props.where((p) => p.state == PState.lista).toList();
    return Screen(
      safeBottom: false,
      child: Column(children: [
        TabHeader('Obras', trail: [
          Tag('${obras.length} ${obras.length == 1 ? 'activa' : 'activas'}', color: Hc.acc),
        ]),
        Expanded(
          child: Body([
            StatGrid([
              Stat('Activas', '${obras.length}/${g.maxRenos >= 99 ? '∞' : g.maxRenos}'),
              Stat('Libres', '${g.crews.where((c) => c.propId == null).length} / ${g.crews.length}', color: Hc.ok),
              Stat('Energía', '${g.energy.floor()}/${Game.maxEnergy.round()}', color: Hc.acc),
            ], columns: 3),
            if (obras.isEmpty)
              Panel(
                child: Column(children: [
                  const Icon(Icons.construction_outlined, size: 36, color: Hc.mut),
                  const SizedBox(height: 6),
                  Text('Sin obras en marcha', style: Ht.card),
                  const SizedBox(height: 2),
                  Text(ruins.isEmpty ? 'Compra una ruina para empezar.' : 'Tienes ${plural(ruins.length, 'ruina', 'ruinas')} esperando.', style: Ht.small),
                ]),
              ),
            if (obras.isNotEmpty)
              Row(children: [
                Expanded(child: Text(g.workBoost ? 'Obra ×2 activa' : 'Termina antes', style: Ht.small)),
                BoostOffer(g, Boost.obra),
                if (g.tiredCrews > 0) ...[const SizedBox(width: 8), BoostOffer(g, Boost.cafe)],
              ]),
            for (final p in obras) _ObraCard(g: g, p: p),
            if (g.jobs.isNotEmpty) ...[
              SectionHead('Encargos de clientes', trail: '${g.jobs.length}'),
              ListBlock([for (var i = 0; i < g.jobs.length; i++) JobRow(g: g, j: g.jobs[i], last: i == g.jobs.length - 1)]),
            ],
            if (ruins.isNotEmpty) ...[
              SectionHead('Por reformar', trail: '${ruins.length}'),
              ListBlock([
                  for (var i = 0; i < ruins.length; i++)
                    PropRow(g, ruins[i],
                        last: i == ruins.length - 1,
                        trail: HsButton('Reformar', size: BtnSize.sm, onTap: () => push(context, SelectorScreen(propId: ruins[i].id)))),
                ]),
            ],
            if (ready.isNotEmpty) ...[
              SectionHead('Listas para el mercado', trail: '${ready.length}'),
              ListBlock([
                  for (var i = 0; i < ready.length; i++)
                    PropRow(g, ready[i], last: i == ready.length - 1, onTap: () => push(context, PropertyScreen(propId: ready[i].id))),
                ]),
            ],
            if (g.hasCrews)
              HsButton('Cuadrillas', kind: BtnKind.sec, block: true, icon: Icons.groups_outlined, onTap: () => push(context, const CrewsScreen()))
            else
              Note('Con tres reformas terminadas llegan las cuadrillas: reforman solas, también sin conexión. Llevas ${g.renosDone}.',
                  icon: Icons.groups_outlined),
            HsButton('Toda la cartera', kind: BtnKind.ghost, onTap: () => push(context, const PortfolioScreen())),
          ]),
        ),
      ]),
    );
  }
}

/// Fila de obra: miniatura, dirección, fase actual, barra de 5 fases y cuadrillas.
class _ObraCard extends StatelessWidget {
  final Game g;
  final Property p;
  const _ObraCard({required this.g, required this.p});
  @override
  Widget build(BuildContext context) {
    final r = p.reno!;
    final cur = r.current;
    final crews = g.crews.where((c) => c.propId == p.id).toList();
    final rate = crews.fold<double>(0, (a, c) => a + Eco.crewRate(g.tradeLv[c.trade]!) * g.meta.speedBonus);
    final idle = g.clock - r.lastActivity > 10 * 60000 && crews.isEmpty;
    return Pressable(
      depth: 2,
      onTap: () => push(context, ObraScreen(propId: p.id)),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        decoration: BoxDecoration(
          color: Hc.panelIn,
          borderRadius: BorderRadius.circular(Hr.tile),
          border: Border.all(color: Hc.line, width: 2),
          boxShadow: He.e1,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            LotThumb(lot: g.lotOf(p), state: 'obra'),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(g.addressOf(p), style: Ht.numS, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                    cur == null
                        ? 'Lista para cerrar · obra ${money(r.cost, compact: true)}'
                        : '${ti(cur).name} · fase ${r.phasesDone + 1} de ${r.phasesTotal}',
                    style: Ht.mini),
              ]),
            ),
            Text('${(r.totalFrac * 100).round()} %', style: Ht.numS.copyWith(color: Hc.acc)),
          ]),
          const SizedBox(height: 8),
          PhaseBar(total: r.phasesTotal, done: r.phasesDone),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
              child: crews.isNotEmpty
                  ? Text('${plural(crews.length, 'cuadrilla', 'cuadrillas')} · ${dec(rate, 1)} toques/s', style: Ht.mini.copyWith(color: Hc.ok))
                  : Text(cur == null ? 'Lista' : 'A mano · ${ti(cur).phase}', style: Ht.mini),
            ),
            if (idle) const Tag('Detenida', color: Hc.warn) else if (crews.isEmpty && g.hasCrews) const Tag('Sin cuadrilla', color: Hc.mut),
          ]),
          if (idle) ...[
            const SizedBox(height: 8),
            const Note('Mientras no se termine, no se puede alquilar ni vender.', bold: 'Obra detenida.', kind: NoteKind.warn, icon: Icons.pause_circle_outline),
          ],
        ]),
      ),
    );
  }
}

