import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../game/city.dart';
import '../../game/data.dart';
import '../../game/engine.dart';
import '../../game/model.dart';
import '../common.dart';
import 'atoms.dart';

/// Etiqueta del origen de un anuncio o vivienda.
Widget originTag(Origin o) => switch (o) {
      Origin.ruina => const Tag('Ruina', color: Hc.bad),
      Origin.usada => const Tag('Sin reformar', color: Hc.warn),
      Origin.subasta => const Tag('Subasta', color: Hc.info),
      Origin.edificio => const Tag('Edificio', color: Hc.acc),
      Origin.embargo => const Tag('Embargo', color: Hc.ok),
      Origin.rival => const Tag('De un inversor', color: Color(0xFFB98AD6)),
      Origin.encargo => const Tag('Encargo', color: Hc.acc),
    };

/// Estado del sprite para un anuncio.
String listingSprite(Listing l) => switch (l.origin) {
      Origin.subasta || Origin.embargo || Origin.rival => 'reformada',
      _ => 'ruina',
    };

/// Nivel de partida por oficio (o rango, en subastas).
class LevelsStrip extends StatelessWidget {
  final Map<Trade, (int, int)> ranges;
  final String? caption;
  const LevelsStrip(this.ranges, {super.key, this.caption});

  factory LevelsStrip.levels(Map<Trade, int> lv, {String? caption}) =>
      LevelsStrip({for (final t in Trade.values) t: (lv[t] ?? 0, lv[t] ?? 0)}, caption: caption);

  @override
  Widget build(BuildContext context) {
    return Panel(
      kind: PanelKind.inset,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (caption != null) ...[Cap(caption!), const SizedBox(height: 6)],
        Row(children: [
          for (final t in Trade.values)
            Expanded(
              child: Column(children: [
                Icon(ti(t).icon, size: 16, color: ranges[t]!.$2 == 0 ? Hc.dim : Hc.mut),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    ranges[t]!.$1 == ranges[t]!.$2 ? (ranges[t]!.$1 == 0 ? '—' : '${ranges[t]!.$1}') : '${ranges[t]!.$1}–${ranges[t]!.$2}',
                    style: Ht.numS.copyWith(fontSize: 18, color: _c(ranges[t]!.$2)),
                  ),
                ),
                Text(ti(t).code, style: Ht.cap.copyWith(fontSize: 8.5)),
              ]),
            ),
        ]),
      ]),
    );
  }

  static Color _c(int v) => v == 0 ? Hc.bad : (v < 4 ? Hc.warn : (v < 10 ? Hc.ink : Hc.ok));
}

/// Rasgos fijos de la vivienda.
class TraitChips extends StatelessWidget {
  final List<Trait> traits;
  const TraitChips(this.traits, {super.key});
  @override
  Widget build(BuildContext context) {
    if (traits.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 6, runSpacing: 6, children: [
      for (final t in traits) Tag(traitInfo[t]!.name, color: traitInfo[t]!.good ? Hc.ok : Hc.warn, icon: traitInfo[t]!.icon),
    ]);
  }
}

/// «Quién la compraría»: una fila por perfil con su cuota, lo que paga y si llega al precio.
class BuyersPanel extends StatelessWidget {
  final List<BuyerRow> rows;
  final double ask;
  final String title;
  final bool rent;
  const BuyersPanel(this.rows, {super.key, required this.ask, this.title = 'Quién la compraría', this.rent = false});
  @override
  Widget build(BuildContext context) {
    final sorted = List<BuyerRow>.of(rows)..sort((a, b) => b.share.compareTo(a.share));
    return Panel(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Cap(title)),
          Text(rent ? 'Paga/mes' : 'Pagaría', style: Ht.cap),
        ]),
        const SizedBox(height: 6),
        for (final r in sorted)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              Icon(si(r.sector).icon, size: 16, color: r.prob >= 0.4 ? Hc.ok : (r.prob >= 0.15 ? Hc.warn : Hc.dim)),
              const SizedBox(width: 8),
              Expanded(
                child: Text('${si(r.sector).name} · ${pct(r.share)} de las visitas',
                    style: Ht.small.copyWith(color: Hc.ink.withValues(alpha: 0.85)), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 6),
              Text(money(r.pay, compact: r.pay >= 1e6), style: Ht.numS.copyWith(fontSize: 17, color: r.pay >= ask ? Hc.ok : Hc.mut)),
            ]),
          ),
        const SizedBox(height: 2),
        Text(
            sorted.any((r) => r.pay >= ask)
                ? 'En verde, quien llega a ${money(ask)}. Pidiendo menos, entran más perfiles.'
                : 'Nadie llega a ${money(ask)}: baja el precio o reforma hacia el perfil de la zona.',
            style: Ht.mini),
      ]),
    );
  }
}

/// Mapa de la ciudad: barrios dominados, rivales y monumentos cercanos de una parcela.
List<Widget> lotFacts(Game g, Lot l) {
  final out = <Widget>[];
  final r = g.rivalOwner(l.id);
  if (r != null) out.add(Tag('De ${r.name}', color: Color(r.color)));
  if (g.city.nearLandmark(l)) out.add(const Tag('Junto a un monumento +5 %', color: Hc.acc, icon: Icons.account_balance_outlined));
  if (g.dominates(l.district)) out.add(const Tag('Barrio dominado', color: Hc.ok, icon: Icons.flag_outlined));
  return out;
}

/// Kv con el resumen de la demanda del barrio.
class ShareBar extends StatelessWidget {
  final Map<Sector, double> shares;
  const ShareBar(this.shares, {super.key});
  static const colors = {Sector.est: Hc.info, Sector.fam: Hc.ok, Sector.may: Color(0xFFB98AD6), Sector.eje: Hc.acc};
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          height: 10,
          child: Row(children: [
            for (final s in Sector.values)
              Expanded(flex: (shares[s]! * 1000).round().clamp(1, 1000), child: ColoredBox(color: colors[s]!)),
          ]),
        ),
      ),
      const SizedBox(height: 6),
      Wrap(spacing: 10, runSpacing: 4, children: [
        for (final s in Sector.values)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Dot(colors[s]!),
            const SizedBox(width: 4),
            Text('${si(s).name} ${pct(shares[s]!)}', style: Ht.mini),
          ]),
      ]),
    ]);
  }
}

/// Fila clave-valor compacta reutilizable.
Widget kvRow(String k, String v, {Color? color}) => KV(k, v, color: color);
