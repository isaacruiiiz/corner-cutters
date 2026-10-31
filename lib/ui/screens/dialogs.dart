import 'package:flutter/material.dart' hide Text;

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../game/data.dart';
import '../../game/economy.dart';
import '../../game/engine.dart';
import '../../game/model.dart';
import '../../game/texts.dart';
import '../common.dart';
import '../widgets/atoms.dart';
import '../widgets/overlays.dart';
import 'property.dart';

import '../../core/texto.dart';
/// Fase desbloqueada.
Future<void> showStageDialog(BuildContext context, Stage s) {
  final info = stageInfo[s]!;
  return showHsDialog(context, builder: (ctx) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Center(
        child: Pose.up(
          child: Panel(
            kind: PanelKind.pop,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Text('FASE ${s.index + 1}', style: Ht.numM.copyWith(color: Hc.onAcc)),
          ),
        ),
      ),
      const SizedBox(height: 16),
      Center(child: Text(info.name, style: Ht.display.copyWith(fontSize: 38), textAlign: TextAlign.center)),
      const SizedBox(height: 6),
      Text(info.adds, style: Ht.body.copyWith(color: Hc.mut), textAlign: TextAlign.center),
      const SizedBox(height: 14),
      Panel(
        kind: PanelKind.inset,
        padding: EdgeInsets.zero,
        child: Column(children: [
          for (var i = 0; i < info.novelties.length; i++)
            Li(
              last: i == info.novelties.length - 1,
              lead: const Icon(Icons.auto_awesome_rounded, color: Hc.acc, size: 18),
              title: info.novelties[i],
            ),
        ]),
      ),
      const SizedBox(height: 16),
      HsButton('Entendido', block: true, onTap: () => Navigator.pop(ctx)),
    ]);
  });
}

/// Inquilino nuevo: perfil sorteado.
Future<void> showTenantDialog(BuildContext context, Game g, Property p) {
  final t = p.tenant!;
  return showHsDialog(context, builder: (ctx) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      const Center(child: Cap('Inquilino nuevo', color: Hc.ok)),
      const SizedBox(height: 14),
      Center(child: Avatar(t.name, size: 72, color: tenantColor(t.type))),
      const SizedBox(height: 10),
      Center(child: Text(t.name, style: Ht.title)),
      const SizedBox(height: 6),
      Center(child: Tag(tenantNames[t.type]!, color: tenantColor(t.type))),
      const SizedBox(height: 8),
      Text(tenantDesc[t.type]!, style: Ht.small, textAlign: TextAlign.center),
      const SizedBox(height: 14),
      Panel(
        kind: PanelKind.inset,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(children: [
          KV('Vivienda', g.addressOf(p)),
          KV('Renta', '${money(g.rentOf(p))}/mes', color: Hc.ok),
          KV('Satisfacción', '${t.sat.round()}'),
        ]),
      ),
      const SizedBox(height: 16),
      HsButton('Firmar', kind: BtnKind.ok, block: true, onTap: () => Navigator.pop(ctx)),
    ]);
  });
}

Future<void> showDefectsDialog(BuildContext context, String text) {
  return showHsDialog(context, builder: (ctx) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      const DialogHead(icon: Icons.visibility_outlined, color: Hc.warn, cap: 'Al abrir paredes', title: 'Sorpresa'),
      const SizedBox(height: 14),
      Text(text, style: Ht.body),
      const SizedBox(height: 10),
      const Quote('«El vendedor no mintió. Simplemente no preguntaste»'),
      const SizedBox(height: 16),
      HsButton('Seguir', block: true, onTap: () => Navigator.pop(ctx)),
    ]);
  });
}

/// Diálogo de cada tipo de evento. La cifra va siempre a la vista.
Future<void> showEventDialog(BuildContext context, Game g, GameEvent e) {
  final p = e.propId == null ? null : g.prop(e.propId!);
  final (icon, color, quote) = switch (e.kind) {
    EvKind.averia => (Icons.plumbing_rounded, Hc.bad, Tx.averia),
    EvKind.impago => (Icons.money_off_rounded, Hc.bad, Tx.impago),
    EvKind.inspeccion => (Icons.assignment_outlined, Hc.warn, Tx.inspeccion),
    EvKind.temporal => (Icons.thunderstorm_outlined, Hc.bad, Tx.temporal),
    EvKind.ofertaInesperada => (Icons.local_offer_outlined, Hc.ok, Tx.ofertaInesperada),
    EvKind.inquilinoModelo => (Icons.sentiment_satisfied_alt_rounded, Hc.ok, Tx.inquilinoModelo),
    EvKind.subvencion => (Icons.eco_outlined, Hc.ok, Tx.subvencion),
    EvKind.hallazgo => (Icons.diamond_outlined, Hc.ok, Tx.hallazgo),
    EvKind.banco => (Icons.account_balance_outlined, Hc.bad, Tx.banco),
    EvKind.subasta => (Icons.gavel_rounded, Hc.info, Tx.subasta),
    EvKind.mejora => (Icons.handyman_outlined, Hc.warn, Tx.mejora),
    EvKind.rival => (Icons.groups_outlined, Hc.warn, Tx.rival),
  };
  return showHsDialog(context, builder: (ctx) {
    void act(String a) {
      final err = g.resolveEvent(e.id, a);
      if (err != null) {
        toast(ctx, err, error: true);
        return;
      }
      Navigator.pop(ctx);
    }

    final rows = <KV>[];
    final actions = <HsButton>[];
    switch (e.kind) {
      case EvKind.averia:
        rows.add(KV('Reparación', money(e.amount), color: Hc.bad));
        actions.add(HsButton('Reparar', price: money(e.amount), block: true, onTap: () => act('pagar')));
        actions.add(HsButton('Ignorar (−10 satisfacción)', kind: BtnKind.sec, block: true, onTap: () => act('ignorar')));
      case EvKind.impago:
        rows.add(KV('Renta perdida', money(-e.amount), color: Hc.bad));
        if (p?.tenant != null) rows.add(KV('Inquilino', '${p!.tenant!.name} · ${tenantNames[p.tenant!.type]}'));
        actions.add(HsButton('Esperar', block: true, onTap: () => act('esperar')));
        actions.add(HsButton('Rescindir contrato', kind: BtnKind.bad, block: true, onTap: () => act('rescindir')));
      case EvKind.mejora:
        rows.add(KV('Coste de la mejora', money(e.amount)));
        rows.add(const KV('Satisfacción', '+18', color: Hc.ok));
        actions.add(HsButton('Aceptar', price: money(e.amount), block: true, onTap: () => act('pagar')));
        actions.add(HsButton('Rechazar (−8)', kind: BtnKind.sec, block: true, onTap: () => act('rechazar')));
      case EvKind.inspeccion:
        rows.add(KV('Multa', e.amount > 0 ? money(-e.amount) : 'Sin multa', color: e.amount > 0 ? Hc.bad : Hc.ok));
        actions.add(HsButton(e.amount > 0 ? 'Pagar multa' : 'Perfecto', block: true, onTap: () => act('pagar')));
      case EvKind.temporal:
        for (final id in e.props) {
          final o = g.prop(id);
          if (o != null) rows.add(KV(g.addressOf(o), money(g.valueOf(o) * 0.02), color: Hc.bad));
        }
        rows.add(KV('Total', money(e.amount), color: Hc.bad, big: true));
        actions.add(HsButton('Reparar todo', price: money(e.amount), block: true, onTap: () => act('pagar')));
        actions.add(HsButton('No reparar (−4 % de valor)', kind: BtnKind.sec, block: true, onTap: () => act('ignorar')));
      case EvKind.ofertaInesperada:
        if (p != null) rows.add(KV('Valor de mercado', money(g.valueOf(p))));
        rows.add(KV('Oferta', money(e.amount), color: Hc.acc, big: true));
        actions.add(HsButton('Vender', kind: BtnKind.ok, block: true, onTap: () => act('aceptar')));
        actions.add(HsButton('Rechazar', kind: BtnKind.sec, block: true, onTap: () => act('rechazar')));
      case EvKind.subvencion:
        rows.add(KV('Pago único', money(e.amount), color: Hc.ok, big: true));
        actions.add(HsButton('Cobrar', kind: BtnKind.ok, block: true, onTap: () => act('cobrar')));
      case EvKind.hallazgo:
        rows.add(KV('Valor de la vivienda', '+${dec(e.amount * 100, 0)} %', color: Hc.ok, big: true));
        actions.add(HsButton('Estupendo', kind: BtnKind.ok, block: true, onTap: () => act('ok')));
      case EvKind.inquilinoModelo:
        actions.add(HsButton('Estupendo', kind: BtnKind.ok, block: true, onTap: () => act('ok')));
      case EvKind.banco:
        if (p != null) {
          final need = (p.debt - g.valueOf(p) * Eco.mortgageLtv).clamp(0.0, double.infinity);
          rows.add(KV('Valor actual', money(g.valueOf(p))));
          rows.add(KV('Deuda', money(p.debt), color: Hc.bad));
          rows.add(KV('Para volver al 70 %', money(need), color: Hc.acc, big: true));
          final dl = g.bankDeadline[p.id];
          if (dl != null) rows.add(KV('Plazo', dur(Duration(milliseconds: ((dl - g.clock) / g.speed).round())), color: Hc.warn));
          actions.add(HsButton('Amortizar', price: money(need), block: true, onTap: () => act('amortizar')));
          actions.add(HsButton('Esperar a que suba', kind: BtnKind.sec, block: true, onTap: () => Navigator.pop(ctx)));
        }
      case EvKind.subasta:
        actions.add(HsButton('Cerrar', block: true, onTap: () => act('ok')));
      case EvKind.rival:
        if (p != null) {
          rows.add(KV('Renta actual', '${money(g.rentOf(p))}/mes'));
          rows.add(KV('Con −10 %', '${money(g.rentRef(p) * (p.rentX - 0.1).clamp(0.7, 1.5))}/mes', color: Hc.warn));
        }
        actions.add(HsButton('Bajar la renta un 10 %', block: true, onTap: () => act('bajar')));
        actions.add(HsButton('Pagar una mejora', price: money(e.amount), kind: BtnKind.sec, block: true, onTap: () => act('mejorar')));
        actions.add(HsButton('Dejarle ir', kind: BtnKind.bad, block: true, onTap: () => act('dejar')));
    }
    // Cifras clave en stat tiles (de dos en dos) y botones secundario + primario.
    final tiles = <Widget>[for (final r in rows) Stat(r.k, r.v, color: r.color ?? Hc.ink)];
    final primary = actions.isEmpty ? null : actions.first;
    final secondary = actions.length > 1 ? actions[1] : null;
    final short = actions.length == 2 && secondary != null && primary!.label.length + (primary.price?.length ?? 0) <= 18 && secondary.label.length <= 16;
    Widget restyle(HsButton b, {required bool main}) => HsButton(b.label,
        kind: main ? (b.kind == BtnKind.bad ? BtnKind.bad : BtnKind.primary) : BtnKind.sec, price: b.price, block: true, onTap: b.onTap);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      DialogHead(icon: icon, color: color, cap: e.isProblem ? 'Evento · problema' : 'Evento · golpe de suerte', title: e.title),
      const SizedBox(height: 12),
      SideQuote(quote),
      const SizedBox(height: 10),
      Text(e.text, style: Ht.small),
      if (tiles.isNotEmpty) ...[const SizedBox(height: 12), StatGrid(tiles)],
      const SizedBox(height: 14),
      if (primary != null && short)
        Row(children: [
          Expanded(child: restyle(secondary, main: false)),
          const SizedBox(width: 8),
          Expanded(child: restyle(primary, main: true)),
        ])
      else ...[
        for (var i = 0; i < actions.length; i++) ...[if (i > 0) const SizedBox(height: 8), restyle(actions[i], main: i == 0)],
      ],
      if (p != null) ...[
        const SizedBox(height: 4),
        HsButton('Ver vivienda', kind: BtnKind.ghost, size: BtnSize.sm, onTap: () {
          Navigator.pop(ctx);
          push(context, PropertyScreen(propId: p.id));
        }),
      ],
    ]);
  });
}
