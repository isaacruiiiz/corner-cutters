import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../game/data.dart';
import '../../game/economy.dart';
import '../../game/engine.dart';
import '../../game/model.dart';
import '../common.dart';
import '../widgets/atoms.dart';
import '../widgets/overlays.dart';
import '../widgets/boosts.dart';
import 'selector.dart';

import '../../core/texto.dart';
final companyTradeSel = StateProvider<Trade>((ref) => Trade.ele);

/// Empresa: resumen, una fila por oficio (nivel, cuadrillas, herramienta y mejora) y plantillas.
class CompanyScreen extends ConsumerWidget {
  const CompanyScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = ref.watch(gameProvider);
    final sel = ref.watch(companyTradeSel);
    final sal = g.monthlySalaries;
    final busy = g.crews.where((c) => c.propId != null).length;
    return Screen(
      safeBottom: false,
      child: Column(children: [
        TabHeader('Empresa', trail: [
          if (sal > 0) Tag('−${money(sal)}/mes', color: Hc.bad),
        ]),
        Expanded(
          child: Body([
            StatGrid([
              Stat('Cuadrillas', '${g.crews.length}'),
              Stat('Ocupadas', '$busy', color: busy > 0 ? Hc.acc : Hc.ink),
              Stat('Plantillas', '${g.meta.templates.length}'),
            ], columns: 3),
            const SectionHead('Oficios'),
            ListBlock([
              for (final t in Trade.values)
                _TradeRow(g: g, t: t, selected: t == sel, last: t == Trade.values.last, onTap: () => ref.read(companyTradeSel.notifier).state = t),
            ]),
            _TradePanel(g: g, t: sel),
            _TemplatesPanel(g: g),
            if (g.isPromoter)
              Li(
                onTap: () => push(context, const GestoriaScreen()),
                lead: const IconBox(Icons.support_agent_outlined, color: Hc.acc),
                title: 'Gestoría',
                sub: g.gestoria.on ? 'Activa · ${g.gestoria.autoRent ? 'alquila' : 'vende'} lo reformado' : 'Alquila y vende sola con tus reglas',
                trail: const Icon(Icons.chevron_right_rounded, color: Hc.mut),
                last: true,
              ),
            Row(children: [
              Expanded(child: HsButton('Plantillas', kind: BtnKind.sec, block: true, size: BtnSize.sm, onTap: () => push(context, const TemplatesScreen()))),
              const SizedBox(width: 8),
              Expanded(
                  child: HsButton('Cuadrillas', kind: BtnKind.sec, block: true, size: BtnSize.sm, onTap: g.hasCrews ? () => push(context, const CrewsScreen()) : null)),
            ]),
            Text(g.hasCrews ? 'Sin conexión, las cuadrillas trabajan hasta 8 horas.' : 'Cuadrillas e hipotecas llegan con la Empresa de reformas.',
                style: Ht.mini, textAlign: TextAlign.center),
          ]),
        ),
      ]),
    );
  }
}


/// Fila de oficio: icono, nombre, «Nivel · cuadrillas · herramienta» y botón de mejora con su coste.
class _TradeRow extends StatelessWidget {
  final Game g;
  final Trade t;
  final bool selected;
  final bool last;
  final VoidCallback onTap;
  const _TradeRow({required this.g, required this.t, required this.selected, required this.last, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final lv = g.tradeLv[t]!;
    final n = g.crewCount(t);
    const roman = ['—', 'I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X'];
    final tool = g.toolLv[t]!;
    final row = Li(
      onTap: onTap,
      last: last,
      display: true,
      titleColor: selected ? Hc.acc : null,
      lead: IconBox(ti(t).icon, color: selected ? Hc.acc : Hc.ink, size: 38),
      title: ti(t).name,
      sub: 'Nivel $lv · ${plural(n, 'cuadrilla', 'cuadrillas')} · Herr. ${tool < roman.length ? roman[tool] : '$tool'}',
      trail: lv >= g.levelCap
          ? const Tag('Tope', color: Hc.mut)
          : HsButton(money(g.trainCost(lv + 1), compact: g.trainCost(lv + 1) >= 1e5), size: BtnSize.sm, onTap: () => _TradePanel.confirmTrain(context, g, t)),
    );
    if (!selected) return row;
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Hr.tile),
        border: Border.all(color: Hc.acc, width: 2),
      ),
      child: row,
    );
  }
}


class _TradePanel extends StatelessWidget {
  final Game g;
  final Trade t;
  const _TradePanel({required this.g, required this.t});
  @override
  Widget build(BuildContext context) {
    final lv = g.tradeLv[t]!;
    final n = g.crewCount(t);
    final tool = g.toolLv[t]!;
    final rate = g.crewRateTotal(t);
    void run(String? e, String ok) => e != null ? toast(context, e, error: true) : toast(context, ok);
    return ListBlock([
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 4, 2, 8),
          child: Row(children: [
            Expanded(child: Cap('${ti(t).name} · mejoras')),
            Cap('${dec(rate, 1)} toques/s'),
          ]),
        ),
        Li(
          title: lv >= g.levelCap ? 'Nivel $lv (máximo)' : 'Nivel $lv → ${lv + 1}',
          sub: 'Calidad máxima de la reforma',
          onTap: () => push(context, TradeDetailScreen(trade: t)),
          trail: lv >= g.levelCap
              ? const Tag('Tope', color: Hc.mut)
              : HsButton(money(g.trainCost(lv + 1)), size: BtnSize.sm,
                  onTap: () => confirmTrain(context, g, t)),
        ),
        Li(
          title: 'Cuadrillas $n → ${n + 1}',
          sub: g.hasCrews
              ? '+${dec(Eco.crewRate(lv) * g.meta.speedBonus, 1)} toques/s · salario ${money(Eco.crewSalary(n + 1))}/mes'
              : 'Desde la fase Empresa de reformas',
          trail: HsButton(money(g.crewCost(n + 1)), size: BtnSize.sm,
              onTap: g.hasCrews ? () => run(g.hireCrew(t), 'Cuadrilla de ${ti(t).name.toLowerCase()}s contratada') : null),
        ),
        Li(
          last: true,
          title: 'Herramienta $tool → ${tool + 1}',
          sub: 'Toque manual: potencia ${1 + tool} → ${2 + tool}',
          trail: HsButton(money(g.toolCost(tool + 1)), size: BtnSize.sm, onTap: () => run(g.upgradeTool(t), 'Herramienta mejorada')),
        ),
      ]);
  }

  static Future<void> confirmTrain(BuildContext context, Game g, Trade t) async {
    final lv = g.tradeLv[t]!;
    final cost = g.trainCost(lv + 1);
    await showHsSheet(context, builder: (ctx) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          IconBox(ti(t).icon, color: Hc.acc, size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Cap('Formación'),
              Text('${ti(t).name}: nivel ${lv + 1}', style: Ht.h2),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Panel(
          kind: PanelKind.inset,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Column(children: [
            KV('Coste (una sola vez)', money(cost), color: Hc.acc),
            KV('Coste por m² a nivel ${lv + 1}', '${money(ti(t).costPerM2 * Eco.k(lv + 1))}/m²'),
            KV('Toques por m²', dec(ti(t).tapsPerM2 * (1 + 0.1 * lv), 2)),
            KV('Cuadrillas', '${dec(Eco.crewRate(lv + 1), 2)} toques/s cada una'),
            KV('Efectivo tras pagar', money(g.cash - cost), color: g.cash < cost ? Hc.bad : Hc.ink),
          ]),
        ),
        const SizedBox(height: 10),
        Text('El coste de cada obra depende del nivel usado, no del disponible: puedes seguir reformando a niveles bajos.', style: Ht.small),
        const SizedBox(height: 14),
        HsButton('Formar', block: true, price: money(cost), onTap: g.cash < cost
            ? null
            : () {
                final e = g.train(t);
                Navigator.pop(ctx);
                if (e != null) toast(context, e, error: true);
              }),
      ]);
    });
  }
}

class _TemplatesPanel extends StatelessWidget {
  final Game g;
  const _TemplatesPanel({required this.g});
  @override
  Widget build(BuildContext context) {
    final ts = g.meta.templates;
    return Panel(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text('Plantillas de reforma', style: Ht.bodyB)),
          Cap('${ts.length} de ${g.templateSlots}'),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (var i = 0; i < ts.length; i++)
            FChip(ts[i].name, onTap: () => push(context, SelectorScreen(templateIndex: i))),
          FChip('+ Nueva', onTap: () => push(context, const SelectorScreen(editTemplate: true))),
          if (ts.isNotEmpty) FChip('Gestionar', icon: Icons.tune_rounded, onTap: () => push(context, const TemplatesScreen())),
        ]),
      ]),
    );
  }
}

/// Detalle de oficio: qué entrega cada tramo de niveles.
class TradeDetailScreen extends ConsumerWidget {
  final Trade trade;
  const TradeDetailScreen({super.key, required this.trade});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = ref.watch(gameProvider);
    final lv = g.tradeLv[trade]!;
    final tiers = tradeTiers[trade]!;
    return Screen(
      dock: lv >= g.levelCap
          ? null
          : HsButton('Subir a nivel ${lv + 1}', block: true, size: BtnSize.lg, price: money(g.trainCost(lv + 1)),
              onTap: g.cash >= g.trainCost(lv + 1)
                  ? () {
                      final e = g.train(trade);
                      if (e != null) toast(context, e, error: true);
                    }
                  : null),
      child: Column(children: [
        BackHeader(ti(trade).name, sub: '${ti(trade).phase} · ${ti(trade).gesture}'),
        Expanded(
          child: Body([
            Row(children: [
              Ring(lv / g.levelCap, size: 92, stroke: 8, child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('$lv', style: Ht.numL),
                Cap('de ${g.levelCap}'),
              ])),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Stat('Cuadrillas', '${g.crewCount(trade)} · ${dec(g.crewRateTotal(trade), 1)} t/s'),
                  const SizedBox(height: 8),
                  Stat('Herramienta', 'nv. ${g.toolLv[trade]} · ${1 + g.toolLv[trade]!}/toque', style: Ht.numS),
                ]),
              ),
            ]),
            ListBlock([
                for (var i = 0; i < 3; i++)
                  Container(
                    color: (i == 0 && lv < 10) || (i == 1 && lv >= 10 && lv < 20) || (i == 2 && lv >= 20) ? const Color(0x1FE3A93B) : null,
                    child: Li(
                      last: i == 2,
                      lead: Container(
                        width: 44,
                        alignment: Alignment.center,
                        child: Text(['1', '10', '20'][i], style: Ht.numM.copyWith(color: Hc.acc)),
                      ),
                      title: tiers[i],
                      sub: 'Nivel ${['1', '10', '20'][i]}',
                    ),
                  ),
              ]),
            if (trade == Trade.ele) ...[
              const SectionHead('Electricista en detalle'),
              ListBlock([
                  for (var i = 0; i < eleDetail.length; i++)
                    Container(
                      color: lv >= (eleDetail[i][0] as int) && lv <= (eleDetail[i][1] as int) ? const Color(0x1FE3A93B) : null,
                      child: Li(
                        last: i == eleDetail.length - 1,
                        lead: SizedBox(
                          width: 44,
                          child: Text(
                              eleDetail[i][0] == eleDetail[i][1] ? '${eleDetail[i][0]}' : '${eleDetail[i][0]}-${eleDetail[i][1]}',
                              style: Ht.numS.copyWith(color: Hc.acc)),
                        ),
                        title: eleDetail[i][2] as String,
                        sub: '${eleDetail[i][3]} · ${eleDetail[i][4]}',
                      ),
                    ),
                ]),
              const Note('La fase eléctrica no se puede omitir: ninguna vivienda sale al mercado sin ella.', icon: Icons.bolt_rounded, kind: NoteKind.warn),
            ],
            const SectionHead('Óptimo por sector'),
            Panel(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Column(children: [
                for (final s in Sector.values) KV(si(s).name, 'nv. ${si(s).optimal[trade]}', color: si(s).optimal[trade]! <= lv ? Hc.ok : Hc.mut),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// Cuadrillas: una fase de una vivienda a la vez.
class CrewsScreen extends ConsumerWidget {
  const CrewsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = ref.watch(gameProvider);
    final obras = g.props.where((p) => p.state == PState.obra).toList();
    return Screen(
      child: Column(children: [
        BackHeader('Cuadrillas', sub: '${g.crews.length} contratadas · ${money(g.monthlySalaries)}/mes'),
        Expanded(
          child: Body([
            if (g.crews.isNotEmpty)
              Panel(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Row(children: [
                  const IconBox(Icons.coffee_outlined, color: Color(0xFFB98A5A)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Café para todos', style: Ht.bodyB),
                      Text(g.tiredCrews > 0 ? '${plural(g.tiredCrews, 'cuadrilla descansa', 'cuadrillas descansan')}: recuperan la jornada al momento'
                          : 'Todas las cuadrillas recuperan su jornada', style: Ht.small),
                    ]),
                  ),
                  BoostOffer(g, Boost.cafe),
                ]),
              ),
            for (final t in Trade.values) ...[
              SectionHead(ti(t).name,
                  trailWidget: HsButton('Contratar', size: BtnSize.xs, price: money(g.crewCost(g.crewCount(t) + 1), compact: true),
                      onTap: () {
                        final e = g.hireCrew(t);
                        if (e != null) toast(context, e, error: true);
                      })),
              ListBlock([
                  if (g.crewCount(t) == 0)
                    const Padding(padding: EdgeInsets.all(14), child: Text('Sin cuadrillas.', style: TextStyle(color: Hc.mut))),
                  for (final c in g.crews.where((c) => c.trade == t)) _CrewRow(g: g, c: c, onAssign: () => _assign(context, g, c, obras)),
                ]),
            ],
            if (g.crews.isNotEmpty)
              HsButton('Despedir la última', kind: BtnKind.ghost, size: BtnSize.sm, onTap: () async {
                final t = g.crews.last.trade;
                if (await confirm(context, title: 'Despedir cuadrilla', body: 'No se recupera el coste de contratación.', danger: true)) g.fireCrew(t);
              }),
            const Note('Cada cuadrilla tiene su jornada: trabaja gastando energía y descansa para recuperarla (más nivel de oficio, más energía). '
                'Con horas extra sigue sin descanso, cobra un 50 % más y puede dejar una fase un nivel por debajo.',
                icon: Icons.info_outline),
          ]),
        ),
      ]),
    );
  }

  void _assign(BuildContext context, Game g, Crew c, List<Property> obras) {
    showHsSheet(context, builder: (ctx) {
      final valid = obras.where((p) => !(p.reno?.phaseDone(c.trade) ?? true)).toList();
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Text('Asignar cuadrilla', style: Ht.title),
        const SizedBox(height: 4),
        Text('${ti(c.trade).name} · una fase a la vez', style: Ht.small),
        const SizedBox(height: 12),
        ListBlock([
            Li(
              lead: const IconBox(Icons.autorenew_rounded, color: Hc.acc),
              title: 'Automática',
              sub: 'Va a la siguiente obra que la necesite',
              onTap: () {
                g.assignCrew(c, null);
                Navigator.pop(ctx);
              },
            ),
            for (var i = 0; i < valid.length; i++)
              Li(
                last: i == valid.length - 1,
                lead: IconBox(Icons.construction_rounded, color: c.propId == valid[i].id ? Hc.ok : Hc.mut),
                title: g.addressOf(valid[i]),
                sub: '${ti(c.trade).phase} al ${(valid[i].reno!.frac(c.trade) * 100).round()} %',
                onTap: () {
                  g.assignCrew(c, valid[i].id);
                  Navigator.pop(ctx);
                },
              ),
          ]),
      ]);
    });
  }
}

/// Cuadrilla: obra asignada, barra de jornada y horas extra.
class _CrewRow extends StatelessWidget {
  final Game g;
  final Crew c;
  final VoidCallback onAssign;
  const _CrewRow({required this.g, required this.c, required this.onAssign});
  @override
  Widget build(BuildContext context) {
    final t = c.trade;
    final p = c.propId == null ? null : g.prop(c.propId!);
    final maxE = g.crewMax(c);
    final f = (c.energy / maxE).clamp(0.0, 1.0);
    final state = p == null
        ? 'Libre · descansando'
        : (c.resting && !c.overtime ? 'Descansando' : (c.energy <= 0 && c.overtime ? 'Horas extra' : 'Trabajando'));
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          IconBox(ti(t).icon, color: p == null ? Hc.mut : (c.resting && !c.overtime ? Hc.warn : Hc.ok), size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p == null ? 'Libre' : g.addressOf(p), style: Ht.bodyB, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('$state · ${dec(Eco.crewRate(g.tradeLv[t]!) * g.meta.speedBonus, 1)} toques/s · ${c.auto ? 'automática' : 'fija'}',
                  style: Ht.small, maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
          HsButton('Asignar', size: BtnSize.xs, kind: BtnKind.sec, onTap: onAssign),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          const Cap('Jornada'),
          const SizedBox(width: 8),
          Expanded(child: Meter(f, color: f < 0.2 ? Hc.bad : (f < 0.5 ? Hc.warn : Hc.ok))),
          const SizedBox(width: 8),
          Text('${c.energy.round()}/${maxE.round()}', style: Ht.numS.copyWith(fontSize: 15)),
          const SizedBox(width: 10),
          Text('Extra', style: Ht.small.copyWith(color: c.overtime ? Hc.warn : Hc.mut, fontWeight: FontWeight.w700)),
          const SizedBox(width: 6),
          HsToggle(c.overtime, (v) => g.setOvertime(c, v)),
        ]),
      ]),
    );
  }
}

/// Lista de plantillas con aplicar a varias viviendas.
class TemplatesScreen extends ConsumerWidget {
  const TemplatesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = ref.watch(gameProvider);
    final ts = g.meta.templates;
    return Screen(
      dock: HsButton('Nueva plantilla', block: true, icon: Icons.add_rounded, onTap: () => push(context, const SelectorScreen(editTemplate: true))),
      child: Column(children: [
        BackHeader('Plantillas', sub: '${ts.length} de ${g.templateSlots} huecos'),
        Expanded(
          child: Body([
            for (var i = 0; i < ts.length; i++)
              Panel(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Expanded(child: Text(ts[i].name, style: Ht.h2)),
                    Tag(si(ts[i].sector).name, color: Hc.info),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    for (final t in Trade.values)
                      Expanded(child: Text('${tr(ti(t).code)} ${ts[i].levels[t] ?? 0}', style: Ht.cap.copyWith(fontSize: 10), textAlign: TextAlign.center)),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: HsButton('Aplicar a…', size: BtnSize.sm, block: true, onTap: () => _apply(context, g, ts[i]))),
                    const SizedBox(width: 8),
                    HsButton('Editar', size: BtnSize.sm, kind: BtnKind.sec, onTap: () => push(context, SelectorScreen(templateIndex: i))),
                    const SizedBox(width: 8),
                    SqButton(Icons.delete_outline, size: 38, tooltip: 'Borrar', onTap: () => g.deleteTemplate(i)),
                  ]),
                ]),
              ),
            const Note('Se conservan al fundar una nueva ciudad.', icon: Icons.bookmark_border_rounded),
          ]),
        ),
      ]),
    );
  }

  void _apply(BuildContext context, Game g, RenoTemplate t) {
    final cands = g.props.where((p) => p.state == PState.ruina || p.state == PState.lista).toList();
    final chosen = <int>{for (final p in cands) p.id};
    showHsSheet(context, builder: (ctx) {
      return StatefulBuilder(builder: (ctx, setS) {
        var cost = 0.0;
        for (final p in cands.where((p) => chosen.contains(p.id))) {
          cost += g.estimate(p, t.levels).cost;
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Text('Aplicar «${t.name}»', style: Ht.title),
          const SizedBox(height: 10),
          Flexible(
            child: Panel(
              padding: EdgeInsets.zero,
              child: ListView(shrinkWrap: true, children: [
                if (cands.isEmpty) const Padding(padding: EdgeInsets.all(14), child: Text('No hay viviendas libres para reformar.', style: TextStyle(color: Hc.mut))),
                for (final p in cands)
                  Li(
                    title: g.addressOf(p),
                    sub: propSub(g, p),
                    trail: HsToggle(chosen.contains(p.id), (v) => setS(() => v ? chosen.add(p.id) : chosen.remove(p.id))),
                  ),
              ]),
            ),
          ),
          const SizedBox(height: 10),
          KV('Coste total', money(cost), color: cost > g.cash ? Hc.bad : Hc.acc),
          if (!g.hasCrews) const Note('Hasta la Empresa de reformas solo puede haber una obra a la vez.', kind: NoteKind.warn),
          const SizedBox(height: 10),
          HsButton('Lanzar ${chosen.length} ${chosen.length == 1 ? 'obra' : 'obras'}', block: true, onTap: chosen.isEmpty
              ? null
              : () {
                  final n = g.applyTemplate(t, cands.where((p) => chosen.contains(p.id)).toList());
                  Navigator.pop(ctx);
                  toast(context, n == 0 ? 'No se pudo lanzar ninguna obra' : 'Lanzadas $n obras', error: n == 0);
                }),
        ]);
      });
    });
  }
}

/// Gestoría (fase 4): alquila y vende con reglas.
class GestoriaScreen extends ConsumerWidget {
  const GestoriaScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = ref.watch(gameProvider);
    final r = g.gestoria;
    return Screen(
      child: Column(children: [
        const BackHeader('Gestoría', sub: 'Alquila y vende por ti'),
        Expanded(
          child: Body([
            ListBlock([
                Li(title: 'Gestoría activa', sub: 'Aplica las reglas a lo que termines de reformar', trail: HsToggle(r.on, (v) {
                  r.on = v;
                  g.touch();
                })),
                Li(
                  last: true,
                  title: 'Destino por defecto',
                  sub: r.autoRent ? 'Alquilar' : 'Vender',
                  trail: SizedBox(
                    width: 170,
                    child: Seg3<bool>(values: const [true, false], value: r.autoRent, label: (v) => v ? 'Alquilar' : 'Vender', onChanged: (v) {
                      r.autoRent = v;
                      g.touch();
                    }),
                  ),
                ),
              ]),
            Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [const Expanded(child: Cap('Renta (× referencia)')), Text(mult(r.rentX), style: Ht.numS)]),
                HsSlider(value: r.rentX, min: 0.7, max: 1.5, mark: 1, onChanged: (v) {
                  r.rentX = (v * 100).round() / 100;
                  g.touch();
                }),
                const SizedBox(height: 10),
                Row(children: [const Expanded(child: Cap('Precio pedido (× mercado)')), Text(mult(r.askY), style: Ht.numS)]),
                HsSlider(value: r.askY, min: 0.8, max: 1.6, mark: 1, onChanged: (v) {
                  r.askY = (v * 100).round() / 100;
                  g.touch();
                }),
                const SizedBox(height: 10),
                Row(children: [const Expanded(child: Cap('Aceptar ofertas desde (× valor)')), Text(mult(r.minOffer), style: Ht.numS)]),
                HsSlider(value: r.minOffer, min: 0.8, max: 1.3, mark: 1, onChanged: (v) {
                  r.minOffer = (v * 100).round() / 100;
                  g.touch();
                }),
              ]),
            ),
            const Note('La gestoría no compra ni reforma: solo publica y acepta ofertas según estas reglas.', icon: Icons.info_outline),
          ]),
        ),
      ]),
    );
  }
}
