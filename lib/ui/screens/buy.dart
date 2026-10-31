import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../game/data.dart';
import '../../game/engine.dart';
import '../../game/model.dart';
import '../../game/texts.dart';
import '../chrome.dart';
import '../common.dart';
import '../map/sprites.dart';
import '../widgets/atoms.dart';
import '../widgets/overlays.dart';
import '../widgets/econ.dart';
import 'obra.dart';
import 'property.dart';


import '../../core/texto.dart';
/// Comprar: hoja con las ruinas a la venta y subastas con descuento.
class BuyScreen extends ConsumerStatefulWidget {
  const BuyScreen({super.key});
  @override
  ConsumerState<BuyScreen> createState() => _BuyScreenState();
}

class _BuyScreenState extends ConsumerState<BuyScreen> {
  String _f = 'todas';
  @override
  Widget build(BuildContext context) {
    final g = ref.watch(gameProvider);
    final ls = g.listings.where((l) {
      switch (_f) {
        case 'subastas':
          return l.auction;
        case 'ruinas':
          return l.origin == Origin.ruina || l.origin == Origin.usada;
        case 'gangas':
          return l.origin == Origin.embargo || l.origin == Origin.rival;
        case 'edificios':
          return l.building;
        case 'asequibles':
          return l.price <= g.cash;
        default:
          return true;
      }
    }).toList()
      ..sort((a, b) => a.price.compareTo(b.price));
    final next = Duration(milliseconds: ((g.marketRefreshAt - g.clock) / g.speed).round().clamp(0, 1 << 31));
    final ph = mph(g.phase);
    return Screen(
      kind: ScreenKind.sheet,
      lotId: ls.isNotEmpty ? ls.first.lotId : (g.listings.isNotEmpty ? g.listings.first.lotId : null),
      child: SheetBody([
        Row(children: [
          Expanded(child: Text('En venta', style: Ht.h2)),
          Tag('${ph.name} ${mult(g.m)}', color: ph.color),
          const SizedBox(width: 6),
          SqButton(Icons.close_rounded, size: 32, tooltip: 'Cerrar', onTap: () => Navigator.of(context).maybePop()),
        ]),
        Text('Efectivo ${money(g.cash)} · nuevos anuncios en ${dur(next)}', style: Ht.mini),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final f in [
              ('todas', 'Todas'),
              ('ruinas', 'Por reformar'),
              ('subastas', 'Subastas'),
              if (g.listings.any((l) => l.origin == Origin.embargo || l.origin == Origin.rival)) ('gangas', 'Embargos y rivales'),
              ('asequibles', 'Asequibles'),
              if (g.isPromoter) ('edificios', 'Edificios'),
            ]) ...[
              FChip(f.$2, on: _f == f.$1, onTap: () => setState(() => _f = f.$1)),
              const SizedBox(width: 6),
            ],
          ]),
        ),
        if (ls.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('Nada por aquí. El mercado repone cada pocos minutos.', style: TextStyle(color: Hc.mut))),
        if (ls.isNotEmpty) ListBlock([for (var i = 0; i < ls.length; i++) _ListingRow(g: g, l: ls[i], last: i == ls.length - 1)]),
        if (g.jobs.isNotEmpty) ...[
          const Cap('Encargos de clientes'),
          ListBlock([for (var i = 0; i < g.jobs.length; i++) JobRow(g: g, j: g.jobs[i], last: i == g.jobs.length - 1)]),
        ],
        Text('Cada vivienda trae ya un nivel por oficio: pagas lo que tiene hecho y reformas solo lo que falta. '
            'Subastas: habitables, con niveles a ciegas. En crisis hay embargos y todo sale más barato.',
            style: Ht.mini, textAlign: TextAlign.center),
      ]),
    );
  }
}

class _ListingRow extends StatelessWidget {
  final Game g;
  final Listing l;
  final bool last;
  const _ListingRow({required this.g, required this.l, required this.last});
  @override
  Widget build(BuildContext context) {
    final lot = g.city.lots[l.lotId];
    final m2 = kindInfo[lot.kind]!.m2;
    final fans = g.rivalsInterested(lot).length;
    final rivalSoon = l.rivalId != null && !l.reserved(g.clock) && l.origin != Origin.rival;
    return Li(
      last: last,
      display: true,
      onTap: () => push(context, BuyConfirmScreen(listing: l)),
      lead: LotThumb(lot: lot, state: listingSprite(l)),
      title: g.addressOfLot(lot),
      sub: '${zi(lot.zone).name} · ${l.building ? '${l.units} × ' : ''}$m2 m²'
          '${l.reserved(g.clock) ? ' · reservada' : (rivalSoon ? ' · un inversor la quiere' : (fans > 0 ? ' · $fans mirando' : ''))}',
      trail: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
        Text(money(l.price), style: Ht.numS.copyWith(color: l.price <= g.cash ? Hc.acc : Hc.mut)),
        const SizedBox(height: 3),
        originTag(l.origin),
      ]),
    );
  }
}

/// Encargo de un cliente: reformas su casa por un precio cerrado.
class JobRow extends StatelessWidget {
  final Game g;
  final ClientJob j;
  final bool last;
  const JobRow({super.key, required this.g, required this.j, required this.last});
  @override
  Widget build(BuildContext context) {
    final lot = g.city.lots[j.lotId];
    final ups = Trade.values.where((t) => j.target[t]! > j.base[t]!).map((t) => '${ti(t).code} ${j.base[t]}→${j.target[t]}').join(' · ');
    return Li(
      last: last,
      lead: const IconBox(Icons.handshake_outlined, color: Hc.acc),
      title: '${j.client} · ${g.addressOfLot(lot)}',
      sub: '$ups · plazo ${j.minutes} min',
      trail: HsButton('Aceptar', size: BtnSize.xs, price: money(j.fee, compact: true), onTap: () {
        final e = g.acceptJob(j);
        if (e != null) {
          toast(context, e, error: true);
          return;
        }
        final p = g.props.last;
        push(context, ObraScreen(propId: p.id));
        toast(context, 'Encargo aceptado: cobras ${money(j.fee)} al terminar');
      }),
    );
  }
}

/// Confirmar compra: niveles que trae, rasgos, quién compraría, señal y, desde la fase 3, hipoteca.
class BuyConfirmScreen extends ConsumerStatefulWidget {
  final Listing listing;
  const BuyConfirmScreen({super.key, required this.listing});
  @override
  ConsumerState<BuyConfirmScreen> createState() => _BuyConfirmScreenState();
}

class _BuyConfirmScreenState extends ConsumerState<BuyConfirmScreen> {
  bool _loan = false;
  double _frac = 0.7;
  @override
  Widget build(BuildContext context) {
    final g = ref.watch(gameProvider);
    final l = widget.listing;
    if (!g.listings.contains(l)) {
      return const Screen(child: Column(children: [BackHeader('Comprar'), Expanded(child: Center(child: Text('Este anuncio ya no está. Puede que otro inversor se haya adelantado.', style: TextStyle(color: Hc.mut), textAlign: TextAlign.center)))]));
    }
    final lot = g.city.lots[l.lotId];
    final m2 = kindInfo[lot.kind]!.m2;
    final loan = _loan ? l.price * _frac : 0.0;
    final need = l.price - loan;
    final habitable = l.origin == Origin.subasta || l.origin == Origin.embargo || l.origin == Origin.rival;
    final worth = g.listingValue(l);
    final rival = l.rivalId == null ? null : g.rivals.where((r) => r.id == l.rivalId).firstOrNull;
    final reserved = l.reserved(g.clock);
    final fans = g.rivalsInterested(lot);
    return Screen(
      kind: ScreenKind.sheet,
      lotId: lot.id,
      dock: Row(children: [
        if (!reserved && l.origin != Origin.rival && fans.isNotEmpty) ...[
          Expanded(
            child: HsButton('Reservar', kind: BtnKind.sec, block: true, size: BtnSize.sm, price: money(g.reserveFee(l), compact: true), onTap: () {
              final e = g.reserve(l);
              toast(context, e ?? 'Reservada 10 minutos: nadie más puede comprarla', error: e != null);
            }),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          flex: 2,
          child: HsButton('Comprar', block: true, price: money(need), onTap: need > g.cash
              ? null
              : () {
                  final e = g.buy(l, loan: loan);
                  if (e != null) {
                    toast(context, e, error: true);
                    return;
                  }
                  final p = g.props.last;
                  Navigator.of(context).pushReplacement(glassRoute(PropertyScreen(propId: p.id)));
                  toast(context, 'Comprada: ${g.addressOf(p)}');
                }),
        ),
      ]),
      child: SheetBody([
        SheetHead(
          lot: lot,
          state: listingSprite(l),
          title: g.addressOfLot(lot),
          sub: '${zi(lot.zone).name} · ${l.units > 1 ? '${l.units} × ' : ''}$m2 m² · ${g.city.districts[lot.district].name}',
          tag: originTag(l.origin),
        ),
        StatGrid([
          Stat(l.auction ? 'Puja actual' : 'Precio', money(l.price, compact: l.price >= 1e6), color: Hc.acc),
          Stat(habitable ? 'Valor hoy' : 'Vale así', '${l.hidden ? '~' : ''}${money(worth, compact: worth >= 1e6)}', color: worth >= l.price ? Hc.ok : Hc.warn),
          Stat('Superficie', l.units > 1 ? '${l.units}×$m2' : '$m2 m²'),
        ], columns: 3),
        LevelsStrip({for (final t in Trade.values) t: g.levelRange(l, t)},
            caption: l.hidden ? 'Niveles aproximados (subasta: se ven al comprar)' : 'Nivel que ya tiene cada oficio'),
        TraitChips(g.traitsOf(lot)),
        if (lotFacts(g, lot).isNotEmpty) Wrap(spacing: 6, runSpacing: 6, children: lotFacts(g, lot)),
        if (reserved)
          Note('Reservada para ti ${gameLeft(g, l.reservedUntil)} más.', icon: Icons.lock_clock_outlined, kind: NoteKind.ok)
        else if (rival != null && l.origin != Origin.rival)
          Note('${rival.name} la comprará en ${gameLeft(g, l.rivalBuysAt)} si nadie se adelanta. Paga una señal para reservarla.',
              bold: 'Hay competencia.', icon: Icons.groups_outlined, kind: NoteKind.warn)
        else if (fans.isNotEmpty && l.origin != Origin.rival)
          Note('${plural(fans.length, 'inversor mira', 'inversores miran')} esta zona.', icon: Icons.visibility_outlined),
        if (habitable)
          const Note('Puedes venderla o alquilarla nada más comprarla, o reformar lo que falte.', bold: 'Habitable.', icon: Icons.key_outlined, kind: NoteKind.ok)
        else
          SideQuote('«${Tx.ruinAds[lot.id % Tx.ruinAds.length]}»'),
        Panel(
          kind: PanelKind.inset,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Column(children: [
            KV('Efectivo', money(g.cash)),
            KV('Pagas ahora', money(-need), color: Hc.acc),
            KV('Efectivo restante', money(g.cash - need), color: g.cash - need < 0 ? Hc.bad : Hc.ink),
            if (_loan) KV('Interés hipoteca', '${money(loan * g.mortgageRate)}/mes', color: Hc.bad),
          ]),
        ),
        if (g.hasMortgage)
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                const Expanded(child: Text('Financiar con hipoteca', style: TextStyle(fontWeight: FontWeight.w700))),
                HsToggle(_loan, (v) => setState(() => _loan = v)),
              ]),
              if (_loan) ...[
                const SizedBox(height: 10),
                Row(children: [
                  Text('${(_frac * 100).round()} %', style: Ht.numM.copyWith(color: Hc.info)),
                  const SizedBox(width: 12),
                  Expanded(child: HsSlider(value: _frac, min: 0.1, max: 0.7, divisions: 12, onChanged: (v) => setState(() => _frac = v))),
                ]),
                Text('Préstamo de ${money(loan)} al 0,5 % mensual. Si una crisis baja el valor por debajo de la deuda, el banco avisa.', style: Ht.small),
              ],
            ]),
          )
        else
          const Note('Las hipotecas llegan con la Empresa de reformas.', icon: Icons.lock_outline),
        if (l.auction) const Note('Subasta judicial: los niveles reales pueden ser mejores o peores que el rango. Alguien perdió, alguien puede ganar.', icon: Icons.gavel_rounded),
        if (l.origin == Origin.embargo) const Note('Embargo bancario: solo aparecen en crisis y salen muy por debajo de su valor.', icon: Icons.account_balance_outlined),
        if (!habitable) const Note('Los defectos ocultos solo se descubren al reformar.', bold: 'Sin inspección.', icon: Icons.visibility_outlined),
      ]),
    );
  }
}
