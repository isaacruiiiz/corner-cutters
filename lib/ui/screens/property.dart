import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../game/data.dart';
import '../../game/engine.dart';
import '../../game/model.dart';
import '../../game/texts.dart';
import '../common.dart';
import '../../game/city.dart';
import '../map/sprites.dart';
import '../widgets/atoms.dart';
import '../widgets/boosts.dart';
import '../widgets/econ.dart';
import '../widgets/overlays.dart';
import 'obra.dart';
import 'sale.dart';
import 'selector.dart';

import '../../core/texto.dart';
import '../../core/i18n.dart';
/// Ficha de vivienda: hoja flotante sobre el mapa con el edificio a la vista. Cambia según su estado.
class PropertyScreen extends ConsumerWidget {
  final int propId;
  const PropertyScreen({super.key, required this.propId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = ref.watch(gameProvider);
    final p = g.prop(propId);
    if (p == null) {
      return Screen(
        child: Column(children: [
          const BackHeader('Vivienda'),
          const Expanded(child: Center(child: Text('Esta vivienda ya no es tuya.', style: TextStyle(color: Hc.mut)))),
        ]),
      );
    }
    final lot = g.lotOf(p);
    return Screen(
      kind: ScreenKind.sheet,
      lotId: p.lotId,
      dock: _dock(context, g, p),
      child: SheetBody([
        SheetHead(
          lot: lot,
          state: spriteStateOf(p.state),
          title: g.addressOf(p),
          sub: '${propSub(g, p)} · ${g.districtOf(p).name}',
          tag: stateTag(g, p),
        ),
        StatGrid(_tiles(g, p), columns: 3),
        if (p.state == PState.ruina) SideQuote('«${Tx.ruinAds[p.id % Tx.ruinAds.length]}»'),
        if (g.traitsOf(lot).isNotEmpty || lotFacts(g, lot).isNotEmpty)
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final t in g.traitsOf(lot)) Tag(traitInfo[t]!.name, color: traitInfo[t]!.good ? Hc.ok : Hc.warn, icon: traitInfo[t]!.icon),
            ...lotFacts(g, lot),
          ]),
        ..._stateSection(context, g, p),
        if (g.hasMortgage) _MortgageCard(p: p),
        if (p.everRenovated) _LevelsCard(p: p),
        Panel(
          kind: PanelKind.inset,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Column(children: [
            KV('Pagaste', money(p.paid)),
            KV(p.everRenovated ? 'Valor de mercado' : 'Valor sin reformar', money(g.valueOf(p))),
            KV('Reformada al óptimo de la zona', money(g.refValue(p) * g.m)),
            if (p.spent > 0) KV('Invertido en obras', money(p.spent)),
            if (p.bonus != 0) KV('Hallazgos y daños', '${p.bonus >= 0 ? '+' : ''}${dec(p.bonus * 100, 0)} %'),
          ]),
        ),
      ]),
    );
  }

  /// Fila de tres stat tiles según el estado.
  List<Widget> _tiles(Game g, Property p) {
    final value = p.everRenovated ? g.valueOf(p) : g.refValue(p) * g.m;
    switch (p.state) {
      case PState.ruina:
        return [
          Stat('Superficie', '${p.m2} m²'),
          Stat('Vale así', money(g.valueOf(p), compact: g.valueOf(p) >= 1e6)),
          Stat('Reformada', '~${money(value, compact: value >= 1e6)}', color: Hc.acc),
        ];
      case PState.obra:
        return [
          Stat('Avance', '${(p.reno!.totalFrac * 100).round()} %', color: Hc.acc),
          Stat('Valor ref.', money(value, compact: value >= 1e6)),
          Stat('Obra', money(p.reno!.cost, compact: true)),
        ];
      case PState.lista:
        final profit = g.valueOf(p) - p.paid - p.spent;
        return [
          Stat('Valor', money(g.valueOf(p), compact: g.valueOf(p) >= 1e6), color: Hc.acc),
          Stat('Calidad', dec(p.quality, 2)),
          Stat('Beneficio', money(profit, sign: true, compact: profit.abs() >= 1e6), color: profit >= 0 ? Hc.ok : Hc.bad),
        ];
      case PState.buscando:
        return [
          Stat('Renta', money(g.rentOf(p)), color: Hc.ok),
          Stat('Valor', money(g.valueOf(p), compact: g.valueOf(p) >= 1e6)),
          Stat('Calidad', dec(p.quality, 2)),
        ];
      case PState.alquilada:
        return [
          Stat('Renta', '${money(g.rentOf(p))}/mes', color: Hc.ok),
          Stat('Valor', money(g.valueOf(p), compact: g.valueOf(p) >= 1e6)),
          Stat('Satisf.', '${p.tenant?.sat.round() ?? 0}', color: (p.tenant?.sat ?? 0) < 40 ? Hc.bad : Hc.ok),
        ];
      case PState.venta:
        final prob = g.saleProb(p, p.askY);
        return [
          Stat('Precio', money(g.valueOf(p) * p.askY, compact: g.valueOf(p) * p.askY >= 1e6), color: Hc.acc),
          Stat('Por visita', pct(prob, d: prob < 0.1 ? 1 : 0)),
          Stat('Ofertas', '${g.offers.where((o) => o.propId == p.id).length}', color: Hc.info),
        ];
    }
  }

  List<Widget> _stateSection(BuildContext context, Game g, Property p) {
    switch (p.state) {
      case PState.ruina:
        return [
          LevelsStrip.levels(p.effLevels, caption: 'Nivel que ya tiene cada oficio'),
          const Note('Pagas y trabajas solo lo que falta hasta el nivel que elijas. Los defectos ocultos se descubren al reformar.',
              bold: 'Hay que reformarla.', icon: Icons.visibility_outlined),
        ];
      case PState.obra:
        final r = p.reno!;
        return [
          PhaseBar(total: r.phasesTotal, done: r.phasesDone),
          const Note('Vivienda en obra: no se puede alquilar ni vender.', icon: Icons.construction_rounded, kind: NoteKind.warn),
          ListBlock([
            for (final t in Trade.values)
              if (r.has(t))
                Li(
                  lead: IconBox(ti(t).icon, color: r.frac(t) >= 1 ? Hc.ok : Hc.ink, size: 34),
                  title: '${ti(t).phase} · nv. ${r.base[t] ?? 0} → ${r.levels[t]}',
                  sub: '${intg(r.done[t] ?? 0)} / ${intg(r.work[t] ?? 0)} toques',
                  trail: SizedBox(width: 90, child: Meter(r.frac(t), color: r.frac(t) >= 1 ? Hc.ok : Hc.acc)),
                  last: t == Trade.values.lastWhere(r.has),
                ),
          ]),
        ];
      case PState.lista:
        final rent = g.rentRef(p);
        final profit = g.valueOf(p) - p.paid - p.spent;
        // Recomendación de presentación: en mercado alto conviene vender; si no, alquilar.
        final sellBetter = g.m >= 1.05;
        return [
          const Cap('¿Qué haces con ella?'),
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(
                child: ChoiceCard(
                  title: 'Alquilar',
                  value: '${money(rent)}/mes',
                  sub: 'Renta de referencia · inquilino sorteado',
                  color: Hc.ok,
                  recommended: !sellBetter,
                  onTap: g.canBuy ? () => push(context, RentScreen(propId: p.id)) : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceCard(
                  title: 'Vender',
                  value: money(g.valueOf(p), compact: g.valueOf(p) >= 1e6),
                  sub: 'Dinero ahora · beneficio ${money(profit, sign: true)}',
                  color: Hc.acc,
                  recommended: sellBetter,
                  onTap: g.canBuy ? () => push(context, SellScreen(propId: p.id)) : null,
                ),
              ),
            ]),
          ),
          const Note('Ingreso mensual o dinero inmediato. El mercado decide cuánto vale cada opción hoy.', icon: Icons.balance_outlined),
        ];
      case PState.buscando:
        return [
          EventStrip(
            cap: 'Buscando inquilino',
            text: 'Renta ${money(g.rentOf(p))}/mes (${mult(p.rentX)}). Llegada estimada en ${dur(Duration(seconds: math.max(5, p.vacancyLeft.round())))}.',
            color: Hc.info,
            icon: Icons.key_outlined,
          ),
        ];
      case PState.alquilada:
        final t = p.tenant!;
        return [
          Panel(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Avatar(t.name, color: _tenantColor(t.type), size: 34),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t.name, style: Ht.card.copyWith(fontSize: 20)),
                    Text('${tenantNames[t.type]} · desde hace ${dur(Duration(milliseconds: g.clock - t.since))}', style: Ht.mini),
                  ]),
                ),
                Tag(tenantNames[t.type]!, color: _tenantColor(t.type)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                const Cap('Satisfacción'),
                const SizedBox(width: 10),
                Expanded(child: Meter(t.sat / 100, color: t.sat < 40 ? Hc.bad : (t.sat < 60 ? Hc.warn : Hc.ok), marker: 0.3)),
                const SizedBox(width: 10),
                Text('${t.sat.round()}', style: Ht.numS),
              ]),
              const SizedBox(height: 10),
              PayHistory(t),
              if (t.arrears > 0) ...[
                const SizedBox(height: 8),
                Note('Lleva ${plural(t.arrears, 'mes', 'meses')} sin pagar. Puedes esperar o rescindir el contrato.',
                    bold: 'Impago.', icon: Icons.warning_amber_rounded, kind: NoteKind.bad),
              ],
              if (p.breakdown) const KV('Avería', 'Sin atender', color: Hc.bad),
            ]),
          ),
          const Note('Reformar obliga a rescindir: no se cobra renta durante la obra. Con menos de 30 de satisfacción el inquilino se marcha.',
              icon: Icons.info_outline),
        ];
      case PState.venta:
        final offers = g.offers.where((o) => o.propId == p.id).toList();
        return [
          Row(children: [
            const Expanded(child: Cap('Espera media')),
            Text(durMin(g.saleWaitMin(p, p.askY)), style: Ht.numS),
            const SizedBox(width: 10),
            BoostOffer(g, Boost.ventas),
          ]),
          for (final o in offers) OfferCard(offer: o),
        ];
    }
  }

  Widget _dock(BuildContext context, Game g, Property p) {
    Widget two(Widget a, Widget b) => Row(children: [Expanded(child: a), const SizedBox(width: 8), Expanded(child: b)]);
    switch (p.state) {
      case PState.ruina:
        return Row(children: [
          Expanded(child: HsButton('Alquilar', icon: Icons.lock_outline, block: true, size: BtnSize.sm)),
          const SizedBox(width: 8),
          Expanded(child: HsButton('Vender', icon: Icons.lock_outline, block: true, size: BtnSize.sm)),
          const SizedBox(width: 8),
          Expanded(
              child: HsButton('Reformar', block: true, size: BtnSize.sm, onTap: () => push(context, SelectorScreen(propId: p.id)))),
        ]);
      case PState.obra:
        return two(
          HsButton('Cerrar a medias', kind: BtnKind.sec, block: true, size: BtnSize.sm, onTap: () => showClosePartial(context, g, p)),
          HsButton('Seguir obra', block: true, size: BtnSize.sm, onTap: () => push(context, ObraScreen(propId: p.id))),
        );
      case PState.lista:
        final sellBetter = g.m >= 1.05;
        return two(
          HsButton('Reformar más', kind: BtnKind.sec, block: true, size: BtnSize.sm, onTap: () => push(context, SelectorScreen(propId: p.id))),
          sellBetter
              ? HsButton('Vender', block: true, size: BtnSize.sm, onTap: g.canBuy ? () => push(context, SellScreen(propId: p.id)) : null)
              : HsButton('Alquilar', block: true, size: BtnSize.sm, onTap: g.canBuy ? () => push(context, RentScreen(propId: p.id)) : null),
        );
      case PState.buscando:
        return two(
          HsButton('Retirar', kind: BtnKind.sec, block: true, size: BtnSize.sm, onTap: () => g.withdraw(p)),
          HsButton('Renta', block: true, size: BtnSize.sm, onTap: () => push(context, RentScreen(propId: p.id))),
        );
      case PState.alquilada:
        return Row(children: [
          Expanded(
            child: HsButton('Rescindir', kind: BtnKind.sec, block: true, size: BtnSize.sm, onTap: () async {
              if (await confirm(context, title: 'Rescindir contrato', body: 'Dejas de cobrar la renta hasta el próximo inquilino.', danger: true)) {
                g.rescind(p);
              }
            }),
          ),
          const SizedBox(width: 8),
          Expanded(
              child: HsButton('Reformar', kind: BtnKind.sec, block: true, size: BtnSize.sm, onTap: () => push(context, SelectorScreen(propId: p.id)))),
          const SizedBox(width: 8),
          Expanded(child: HsButton('Renta', block: true, size: BtnSize.sm, onTap: () => push(context, RentScreen(propId: p.id)))),
        ]);
      case PState.venta:
        return two(
          HsButton('Retirar', kind: BtnKind.sec, block: true, size: BtnSize.sm, onTap: () => g.withdraw(p)),
          HsButton('Precio', block: true, size: BtnSize.sm, onTap: () => push(context, SellScreen(propId: p.id))),
        );
    }
  }
}

/// Cabecera de hoja: miniatura, dirección (Jersey) con tag y subtítulo; botón de cerrar.
class SheetHead extends StatelessWidget {
  final Lot lot;
  final String state;
  final String title;
  final String sub;
  final Widget? tag;
  const SheetHead({super.key, required this.lot, required this.state, required this.title, required this.sub, this.tag});
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        LotThumb(lot: lot, state: state, size: 46),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Flexible(child: Text(title, style: Ht.h2, maxLines: 1, overflow: TextOverflow.ellipsis)),
              if (tag != null) ...[const SizedBox(width: 8), tag!],
            ]),
            Text(sub, style: Ht.mini, maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
        const SizedBox(width: 6),
        SqButton(Icons.close_rounded, size: 32, tooltip: 'Cerrar', onTap: () => Navigator.of(context).maybePop()),
      ]);
}

/// Tarjeta de opción (alquilar / vender). La recomendada se eleva 4 px con borde dorado y etiqueta.
class ChoiceCard extends StatelessWidget {
  final String title;
  final String value;
  final String sub;
  final Color color;
  final bool recommended;
  final VoidCallback? onTap;
  const ChoiceCard({super.key, required this.title, required this.value, required this.sub, required this.color, this.recommended = false, this.onTap});
  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: Hc.panelIn,
        borderRadius: BorderRadius.circular(Hr.tile),
        border: Border.all(color: recommended ? Hc.acc : Hc.line, width: 2),
        boxShadow: recommended ? const [BoxShadow(color: Hc.accLo, offset: Offset(0, 4))] : He.e1,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        if (recommended) ...[const Tag('Recomendada', color: Hc.acc, fill: true), const SizedBox(height: 4)],
        Text(title, style: Ht.card),
        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: Ht.numL.copyWith(color: color))),
        const SizedBox(height: 2),
        Text(sub, style: Ht.mini),
      ]),
    );
    return Transform.translate(
      offset: Offset(0, recommended ? -4 : 0),
      child: onTap == null ? Opacity(opacity: 0.6, child: card) : Pressable(onTap: onTap, depth: 2, child: card),
    );
  }
}

Color _tenantColor(TenantType t) => switch (t) {
      TenantType.puntual => Hc.info,
      TenantType.despistado => Hc.warn,
      TenantType.problematico => Hc.bad,
      TenantType.ejemplar => Hc.ok,
    };

Color tenantColor(TenantType t) => _tenantColor(t);

class _LevelsCard extends StatelessWidget {
  final Property p;
  const _LevelsCard({required this.p});
  @override
  Widget build(BuildContext context) {
    final s = p.sector;
    return Panel(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Expanded(child: Cap('Última reforma')),
          Cap('Calidad Q ${dec(p.quality, 2)}${s != null ? ' · ${si(s).name}' : ''}'),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          for (final t in Trade.values)
            Expanded(
              child: Column(children: [
                Icon(ti(t).icon, size: 18, color: (p.levels[t] ?? 0) == 0 ? Hc.dim : Hc.ink),
                const SizedBox(height: 4),
                Text((p.levels[t] ?? 0) == 0 ? '—' : '${p.levels[t]}', style: Ht.numS),
                Text(ti(t).code, style: Ht.cap.copyWith(fontSize: 9)),
                if ((p.doneFrac[t] ?? 0) > 0 && (p.doneFrac[t] ?? 0) < 1)
                  Text('${((p.doneFrac[t] ?? 0) * 100).round()} %', style: Ht.cap.copyWith(color: Hc.warn, fontSize: 9)),
              ]),
            ),
        ]),
      ]),
    );
  }
}

class _MortgageCard extends ConsumerWidget {
  final Property p;
  const _MortgageCard({required this.p});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = ref.watch(gameProvider);
    final v = g.valueOf(p);
    final ltv = v <= 0 ? 0.0 : p.debt / v;
    return Panel(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Expanded(child: Cap('Hipoteca')),
          Text(p.debt <= 0 ? 'Sin deuda' : '${money(p.debt * g.mortgageRate)}/mes de interés', style: Ht.small),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Text(money(p.debt), style: Ht.numM.copyWith(color: p.debt > 0 ? Hc.bad : Hc.mut)),
          const SizedBox(width: 12),
          Expanded(child: Meter(ltv / 1.0, color: ltv > 0.9 ? Hc.bad : Hc.info, marker: 0.7, large: true)),
        ]),
        const SizedBox(height: 4),
        Text('Deuda sobre valor ${pct(ltv)} · máximo 70 %', style: Ht.small),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: HsButton('Pedir', size: BtnSize.sm, kind: BtnKind.info, block: true,
                price: g.maxLoan(p) > 0 ? money(g.maxLoan(p), compact: true) : null,
                onTap: g.maxLoan(p) < 100
                    ? null
                    : () {
                        final e = g.borrow(p, g.maxLoan(p));
                        if (e != null) toast(context, e, error: true);
                      }),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: HsButton('Amortizar', size: BtnSize.sm, kind: BtnKind.sec, block: true,
                onTap: p.debt <= 0
                    ? null
                    : () {
                        final e = g.repay(p, math.min(p.debt, g.cash));
                        if (e != null) toast(context, e, error: true);
                      }),
          ),
        ]),
      ]),
    );
  }
}

/// Diálogo de cierre a medias.
Future<void> showClosePartial(BuildContext context, Game g, Property p) async {
  final r = p.reno!;
  final loss = g.partialLoss(p);
  final eleOk = r.frac(Trade.ele) >= 1;
  await showHsDialog(context, builder: (ctx) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      const DialogHead(icon: Icons.content_cut_rounded, color: Hc.warn, cap: 'Estado de obra', title: 'Cerrar a medias'),
      const SizedBox(height: 14),
      Panel(
        kind: PanelKind.inset,
        padding: EdgeInsets.zero,
        child: Column(children: [
          for (final t in Trade.values)
            if (r.has(t))
              Li(
                lead: Icon(ti(t).icon, size: 18, color: Hc.mut),
                title: ti(t).phase,
                trail: SizedBox(
                  width: 110,
                  child: Row(children: [
                    Expanded(child: Meter(r.frac(t), color: r.frac(t) >= 1 ? Hc.ok : Hc.acc)),
                    const SizedBox(width: 8),
                    SizedBox(width: 40, child: Text('${(r.frac(t) * 100).round()} %', style: Ht.numS.copyWith(fontSize: 15), textAlign: TextAlign.right)),
                  ]),
                ),
              ),
        ]),
      ),
      const SizedBox(height: 12),
      KV('Valor que se pierde', money(-loss), color: Hc.bad, big: true),
      const SizedBox(height: 6),
      Text('Las fases interrumpidas cuentan en proporción. Se reembolsan las fases sin empezar.', style: Ht.small),
      const SizedBox(height: 6),
      Quote(Tx.finishedQuote(0.5, {...r.levels, for (final t in Trade.values) if (r.frac(t) < 1) t: 0}, r.sector)),
      const SizedBox(height: 14),
      if (!eleOk) const Note('La electricidad no admite cierre parcial: una instalación a medias es un riesgo de incendio.', kind: NoteKind.bad),
      if (!eleOk) const SizedBox(height: 12),
      HsButton('Cerrar obra', kind: BtnKind.bad, block: true,
          onTap: eleOk
              ? () {
                  final e = g.closePartial(p);
                  Navigator.pop(ctx);
                  if (e != null) toast(context, e, error: true);
                }
              : null),
      const SizedBox(height: 8),
      HsButton('Seguir con la obra', kind: BtnKind.sec, block: true, onTap: () => Navigator.pop(ctx)),
    ]);
  });
}

// =====================================================================
// Alquilar · fijar renta
// =====================================================================
class RentScreen extends ConsumerStatefulWidget {
  final int propId;
  const RentScreen({super.key, required this.propId});
  @override
  ConsumerState<RentScreen> createState() => _RentScreenState();
}

class _RentScreenState extends ConsumerState<RentScreen> {
  double? _x;
  @override
  Widget build(BuildContext context) {
    final g = ref.watch(gameProvider);
    final p = g.prop(widget.propId);
    if (p == null) return const Screen(child: BackHeader('Alquilar'));
    final x = _x ??= p.rentX;
    final ref0 = g.rentRef(p);
    final accept = g.rentAcceptProb(p, x);
    final sat = (45 + 50 * p.quality - 40 * math.max(0, x - 1) + (x < 1 ? 10 : 0)).clamp(30, 95);
    final wait = g.vacancyMean(p, x);
    void upd(double v) => setState(() => _x = (v * 100).round() / 100);
    return Screen(
      dock: HsButton(p.state == PState.alquilada ? 'Actualizar renta' : 'Publicar alquiler',
          block: true, size: BtnSize.lg, kind: BtnKind.ok, icon: Icons.key_outlined, onTap: () {
        final e = g.listForRent(p, x);
        if (e != null) {
          toast(context, e, error: true);
        } else {
          Navigator.pop(context);
          toast(context, p.state == PState.alquilada ? 'Renta actualizada' : 'Publicado: ${money(ref0 * x)}/mes');
        }
      }),
      child: Column(children: [
        BackHeader('Alquilar', sub: g.addressOf(p)),
        Expanded(
          child: Body([
            Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Cap('Renta (× referencia)'),
                const SizedBox(height: 6),
                Row(children: [
                  GlowText(mult(x), style: Ht.display),
                  const Spacer(),
                  HsStepper(
                    value: dec(x, 2),
                    onMinus: x > 0.7 ? () => upd(x - 0.05) : null,
                    onPlus: x < 1.5 ? () => upd(x + 0.05) : null,
                  ),
                ]),
                const SizedBox(height: 8),
                HsSlider(value: x, min: 0.7, max: 1.5, mark: 1.0, onChanged: upd),
                const SizedBox(height: 10),
                SizedBox(height: 120, child: CustomPaint(painter: CurvePainter(
                  f: (v) => g.rentAcceptProb(p, v),
                  min: 0.7,
                  max: 1.5,
                  x: x,
                  fill: true,
                  labels: const ['0,7', '1,0', '1,5'],
                ))),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: Stat('Aceptan', pct(accept))),
                  Expanded(child: Stat('Espera', dur(Duration(seconds: wait.round())))),
                  Expanded(child: Stat('Renta', money(ref0 * x), color: Hc.acc)),
                ]),
              ]),
            ),
            BuyersPanel(g.rentersOf(p, x), ask: ref0 * x, title: 'Quién la alquilaría', rent: true),
            Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                KV('Renta de referencia', '${money(ref0)}/mes'),
                if (g.inCrisis) const KV('Crisis', 'el alquiler aguanta: +12 %', color: Hc.ok),
                const SizedBox(height: 6),
                Row(children: [
                  const Cap('Satisfacción inicial'),
                  const SizedBox(width: 10),
                  Expanded(child: Meter(sat / 100, color: sat < 40 ? Hc.bad : Hc.ok, marker: 0.3)),
                  const SizedBox(width: 10),
                  Text('${sat.round()}', style: Ht.numS),
                ]),
              ]),
            ),
            const Note('Cada perfil se comporta distinto: los estudiantes se van en junio, las familias se quedan años, '
                'los mayores son los más fieles y los ejecutivos pagan más pero exigen calidad y se mudan antes.',
                icon: Icons.info_outline),
          ]),
        ),
      ]),
    );
  }
}

// =====================================================================
// Vender · fijar precio
// =====================================================================
class SellScreen extends ConsumerStatefulWidget {
  final int propId;
  const SellScreen({super.key, required this.propId});
  @override
  ConsumerState<SellScreen> createState() => _SellScreenState();
}

class _SellScreenState extends ConsumerState<SellScreen> {
  double? _y;
  @override
  Widget build(BuildContext context) {
    final g = ref.watch(gameProvider);
    final p = g.prop(widget.propId);
    if (p == null) return const Screen(child: BackHeader('Vender'));
    final y = _y ??= p.askY;
    final v = g.valueOf(p);
    final prob = g.saleProb(p, y);
    final offer = g.saleOfferProb(p, y);
    void upd(double n) => setState(() => _y = (n * 100).round() / 100);
    return Screen(
      dock: HsButton(p.state == PState.venta ? 'Actualizar precio' : 'Publicar venta',
          block: true, size: BtnSize.lg, icon: Icons.sell_outlined, onTap: () {
        final e = g.listForSale(p, y);
        if (e != null) {
          toast(context, e, error: true);
        } else {
          Navigator.pop(context);
          toast(context, 'En venta por ${money(v * y)}');
        }
      }),
      child: Column(children: [
        BackHeader('Vender', sub: g.addressOf(p)),
        Expanded(
          child: Body([
            Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Cap('Precio pedido (× mercado)'),
                const SizedBox(height: 6),
                Row(children: [
                  GlowText(mult(y), style: Ht.display),
                  const Spacer(),
                  HsStepper(
                    value: dec(y, 2),
                    onMinus: y > 0.7 ? () => upd(y - 0.05) : null,
                    onPlus: y < 2.0 ? () => upd(y + 0.05) : null,
                  ),
                ]),
                const SizedBox(height: 8),
                HsSlider(value: y, min: 0.7, max: 2.0, mark: 1.0, onChanged: upd),
                const SizedBox(height: 10),
                SizedBox(
                  height: 110,
                  child: CustomPaint(
                    painter: CurvePainter(f: (q) => g.saleProb(p, q), min: 0.7, max: 2.0, x: y, fill: true, labels: const ['0,7', '1,0', '2,0']),
                  ),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: Stat('Por visita', pct(prob, d: prob < 0.1 ? 1 : 0))),
                  Expanded(child: Stat('Espera', durMin(g.saleWaitMin(p, y)))),
                  Expanded(child: Stat('Pedido', money(v * y), color: Hc.acc)),
                ]),
              ]),
            ),
            BuyersPanel(g.buyersOf(p, v * y), ask: v * y),
            Panel(
              padding: EdgeInsets.zero,
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                  child: Row(children: const [
                    Expanded(child: Cap('Pedido')),
                    Expanded(child: Cap('Por visita')),
                    Expanded(child: Cap('Espera')),
                  ]),
                ),
                for (final q in const [0.9, 1.0, 1.1, 1.2, 1.3, 1.5])
                  Container(
                    color: (q - y).abs() < 0.051 ? const Color(0x1FE3A93B) : null,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    child: Row(children: [
                      Expanded(child: Text(mult(q), style: Ht.numS.copyWith(fontSize: 17))),
                      Expanded(child: Text(pct(g.saleProb(p, q), d: g.saleProb(p, q) < 0.1 ? 1 : 0), style: Ht.body)),
                      Expanded(child: Text(durMin(g.saleWaitMin(p, q)), style: Ht.body)),
                    ]),
                  ),
              ]),
            ),
            Note('Los compradores que valoran entre el 80 % y el 100 % de lo pedido lanzan una oferta (${pct(offer)} por visita). Caducan a las 24 h.',
                icon: Icons.info_outline),
          ]),
        ),
      ]),
    );
  }
}

/// Curva O(x) o P(compra) con punto actual.
class CurvePainter extends CustomPainter {
  final double Function(double) f;
  final double min, max, x;
  final bool fill;
  final List<String> labels;
  CurvePainter({required this.f, required this.min, required this.max, required this.x, this.fill = false, this.labels = const []});
  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height - 16;
    final w = size.width;
    Offset pt(double v) => Offset((v - min) / (max - min) * w, h - f(v).clamp(0.0, 1.0) * (h - 6) - 2);
    final path = Path()..moveTo(0, pt(min).dy);
    for (var i = 0; i <= 80; i++) {
      final v = min + (max - min) * i / 80;
      final q = pt(v);
      path.lineTo(q.dx, q.dy);
    }
    if (fill) {
      final fp = Path.from(path)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
      canvas.drawPath(fp, Paint()..color = const Color(0x33E3A93B));
    }
    canvas.drawLine(Offset(0, h), Offset(w, h), Paint()..color = Hc.lineSoft..strokeWidth = 1.5);
    canvas.drawPath(path, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = Hc.acc);
    final cx = pt(x);
    final dash = Paint()
      ..color = Hc.mut
      ..strokeWidth = 1;
    for (var yy = 0.0; yy < h; yy += 6) {
      canvas.drawLine(Offset(cx.dx, yy), Offset(cx.dx, yy + 3), dash);
    }
    canvas.drawCircle(cx, 7, Paint()..color = Hc.line);
    canvas.drawCircle(cx, 5.5, Paint()..color = Hc.ink);
    canvas.drawCircle(cx, 5.5, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Hc.bg);
    if (labels.length == 3) {
      final tp = TextPainter(textDirection: TextDirection.ltr);
      final pos = [0.0, (1.0 - min) / (max - min) * w, w];
      for (var i = 0; i < 3; i++) {
        tp.text = TextSpan(text: tr(labels[i]), style: const TextStyle(fontFamily: Hf.body, fontSize: 10, color: Hc.mut, fontWeight: FontWeight.w600));
        tp.layout();
        final dx = (pos[i] - (i == 0 ? 0 : (i == 2 ? tp.width : tp.width / 2))).clamp(0.0, w - tp.width);
        tp.paint(canvas, Offset(dx, h + 3));
      }
    }
  }

  @override
  bool shouldRepaint(CurvePainter o) => o.x != x || o.min != min || o.max != max;
}
