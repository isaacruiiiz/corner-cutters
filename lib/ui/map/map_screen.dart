import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../game/city.dart';
import '../../game/data.dart';
import '../../game/engine.dart';
import '../../game/model.dart';
import '../chrome.dart';
import '../common.dart';
import '../screens/buy.dart';
import '../screens/district.dart';
import '../screens/eras.dart';
import '../screens/obra.dart';
import '../screens/pending.dart';
import '../screens/portfolio.dart';
import '../screens/property.dart';
import '../screens/selector.dart';
import '../widgets/atoms.dart';
import '../widgets/boosts.dart';
import '../widgets/econ.dart';
import '../widgets/overlays.dart';
import 'map_view.dart';
import 'sprites.dart';

/// Pantalla del mapa: el mapa ocupa todo; encima, fecha/velocidad, raíl y la píldora de la selección.
/// El ticker y la barra los pone el Shell.
class MapScreen extends ConsumerStatefulWidget {
  /// Pestaña del mapa activa (si no, el mapa queda velado detrás de un panel).
  final bool active;
  const MapScreen({super.key, this.active = true});
  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _ctrl = TransformationController();
  final _mapKey = GlobalKey<MapViewState>();
  bool _drawer = true;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _focusLot(Lot l) {
    final g = ref.read(gameProvider);
    g.selectedLot = l.id;
    ref.read(selectedStreetProvider.notifier).state = null;
    setState(() => _drawer = true);
    g.touch();
    final iso = ref.read(cityImageProvider).iso;
    if (iso != null) _mapKey.currentState?.centerOn(iso.top(l) + const Offset(0, 30), y: 0.45);
  }

  void _street(int id) {
    ref.read(selectedStreetProvider.notifier).state = id;
    final g = ref.read(gameProvider);
    showHsSheet(context, builder: (ctx) => _StreetSheet(streetId: id, onLot: (l) {
          Navigator.pop(ctx);
          _focusLot(l);
        })).whenComplete(() {
      if (mounted) ref.read(selectedStreetProvider.notifier).state = null;
    });
    g.touch();
  }

  @override
  Widget build(BuildContext context) {
    final g = ref.watch(gameProvider);
    final layers = ref.watch(mapLayersProvider);
    final sel = g.selectedLot;
    return Stack(children: [
      Positioned.fill(
        child: MapView(
          key: _mapKey,
          controller: _ctrl,
          onLot: _focusLot,
          onStreet: _street,
          onEmpty: () => setState(() => _drawer = false),
        ),
      ),
      if (widget.active) ...[
        // Fecha y velocidad.
        Positioned(
          left: Lay.left(context),
          top: Lay.dateTop(context),
          width: Lay.hudW(context) - 56,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const DateSpeedRow(),
            if (g.eraCfg != null) ...[const SizedBox(height: 6), EraBanner(g)],
            const SizedBox(height: 6),
            BoostChips(g),
          ]),
        ),
        // Raíl lateral: filtro y pendientes.
        Positioned(
          right: Lay.right(context),
          top: Lay.dateTop(context),
          child: Column(children: [
            SqButton(Icons.filter_alt_outlined,
                glass: true,
                on: !layers.isDefault,
                tooltip: 'Filtro del mapa',
                onTap: () => showHsSheet(context, builder: (_) => const _LayersSheet())),
            const SizedBox(height: 8),
            SqButton(Icons.format_list_bulleted_rounded,
                glass: true, dot: g.pendingCount > 0, tooltip: 'Pendiente hoy', onTap: () => push(context, const PendingScreen())),
            const SizedBox(height: 8),
            SqButton(Icons.bolt_rounded,
                glass: true, dot: usefulBoosts(g) > 0, tooltip: 'Impulsos', onTap: () => showHsSheet(context, builder: (_) => BoostsSheet(g: g))),
          ]),
        ),
        // Píldora de la propiedad seleccionada.
        Positioned(
          left: Lay.hInsets(context, 520).$1,
          right: Lay.hInsets(context, 520).$2,
          bottom: Lay.pillBottom(context),
          child: sel != null && _drawer ? _Pill(lotId: sel) : _EmptyPill(g: g),
        ),
      ],
    ]);
  }
}

/// Sin selección: «Toca un edificio» (y el acceso a comprar).
class _EmptyPill extends StatelessWidget {
  final Game g;
  const _EmptyPill({required this.g});
  @override
  Widget build(BuildContext context) => GlassBox(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Row(children: [
          Expanded(child: Text('Toca un edificio', style: Ht.small.copyWith(fontWeight: FontWeight.w700))),
          HsButton('Comprar',
              size: BtnSize.sm,
              icon: Icons.add_home_outlined,
              onTap: g.canBuy ? () => push(context, const BuyScreen()) : () => toast(context, 'Comprar llega con la fase Casero', error: true)),
        ]),
      );
}

/// Píldora de la selección: dirección + tag, barrio · m² · sector, dato del estado y botón compacto.
class _Pill extends ConsumerWidget {
  final int lotId;
  const _Pill({required this.lotId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = ref.watch(gameProvider);
    final lot = g.city.lots[lotId];
    final owned = g.propsOnLot(lotId);
    Listing? listing;
    for (final l in g.listings) {
      if (l.lotId == lotId) listing = l;
    }
    if (owned.isNotEmpty) {
      if (owned.length > 1) return _building(context, g, lot, owned);
      return _owned(context, g, owned.first);
    }
    return _lot(context, g, lot, listing);
  }

  Widget _frame({required String title, Widget? tag, required String sub, String? info, required Widget action, VoidCallback? onTap, Widget? extra}) {
    return Panel(
      kind: PanelKind.glass,
      padding: const EdgeInsets.fromLTRB(12, 8, 10, 9),
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Flexible(child: Text(title, style: Ht.card, maxLines: 1, overflow: TextOverflow.ellipsis)),
                if (tag != null) ...[const SizedBox(width: 8), tag],
              ]),
              const SizedBox(height: 1),
              Text(sub, style: Ht.small, maxLines: 1, overflow: TextOverflow.ellipsis),
              if (info != null)
                Text(info, style: Ht.small.copyWith(color: Hc.ink.withValues(alpha: 0.85)), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
          const SizedBox(width: 10),
          action,
        ]),
        if (extra != null) ...[const SizedBox(height: 8), extra],
      ]),
    );
  }

  Widget _owned(BuildContext context, Game g, Property p) {
    final r = p.reno;
    String info;
    Widget action;
    switch (p.state) {
      case PState.obra:
        final cur = r!.current;
        info = cur == null ? 'Lista para cerrar' : 'Fase ${r.phasesDone + 1}/${r.phasesTotal} · ${ti(cur).phase}';
        action = HsButton('Seguir obra', size: BtnSize.sm, onTap: () => push(context, ObraScreen(propId: p.id)));
      case PState.ruina:
        info = Tx2.ruin(p.id);
        action = HsButton('Reformar', size: BtnSize.sm, onTap: () => push(context, SelectorScreen(propId: p.id)));
      case PState.lista:
        info = 'Calidad ${dec(p.quality, 2)} · ${money(g.valueOf(p))}';
        action = HsButton('Decidir', size: BtnSize.sm, onTap: () => push(context, PropertyScreen(propId: p.id)));
      case PState.alquilada:
        info = '${p.tenant?.name ?? ''} · satisf. ${(p.tenant?.sat ?? 0).round()} · ${money(g.rentOf(p))}/mes';
        action = HsButton('Ficha', size: BtnSize.sm, onTap: () => push(context, PropertyScreen(propId: p.id)));
      case PState.buscando:
        info = 'Buscando inquilino · ${mult(p.rentX)}';
        action = HsButton('Ficha', size: BtnSize.sm, onTap: () => push(context, PropertyScreen(propId: p.id)));
      case PState.venta:
        final n = g.offers.where((o) => o.propId == p.id).length;
        info = 'En venta ${mult(p.askY)} · ${plural(n, 'oferta', 'ofertas')}';
        action = HsButton('Ficha', size: BtnSize.sm, onTap: () => push(context, PropertyScreen(propId: p.id)));
    }
    return _frame(
      title: g.addressOf(p),
      tag: stateTag(g, p),
      sub: propSub(g, p),
      info: info,
      action: action,
      onTap: () => push(context, PropertyScreen(propId: p.id)),
      extra: (!g.tutorialDone && p.state != PState.obra && g.renosDone == 0)
          ? const Note('Empieza por reformar. La electricidad es obligatoria para vender o alquilar.',
              bold: 'Primera obra.', icon: Icons.lightbulb_outline, kind: NoteKind.warn)
          : null,
    );
  }

  Widget _building(BuildContext context, Game g, Lot lot, List<Property> owned) {
    final obras = owned.where((p) => p.state == PState.obra).length;
    final alq = owned.where((p) => p.state == PState.alquilada).length;
    return _frame(
      title: g.addressOfLot(lot),
      tag: Tag('${owned.length} viviendas', color: Hc.acc),
      sub: '${zi(lot.zone).name} · ${g.city.districts[lot.district].name}',
      info: '$alq alquiladas · $obras en obra',
      action: HsButton('Ver edificio', size: BtnSize.sm, onTap: () => push(context, PortfolioScreen(lotId: lot.id))),
    );
  }

  Widget _lot(BuildContext context, Game g, Lot lot, Listing? l) {
    final d = g.city.districts[lot.district];
    final m2 = kindInfo[lot.kind]!.m2;
    if (lot.landmark != null) {
      return _frame(
        title: landmarkName(lot.landmark!),
        tag: Tag(kCivicLandmarks.contains(lot.landmark) ? 'Equipamiento' : 'Monumento', color: Hc.acc),
        sub: '${zi(lot.zone).name} · ${d.name}',
        info: kCivicLandmarks.contains(lot.landmark) ? 'Equipamiento público: no se vende.' : 'No se vende. Las viviendas cercanas valen un 5 % más.',
        action: HsButton('Barrio', size: BtnSize.sm, kind: BtnKind.sec, onTap: () => push(context, DistrictScreen(districtId: d.id))),
      );
    }
    final rival = g.rivalOwner(lot.id);
    return _frame(
      title: g.addressOfLot(lot),
      tag: l != null ? originTag(l.origin) : (rival != null ? Tag(rival.name, color: Color(rival.color)) : null),
      sub: '${zi(lot.zone).name} · $m2 m² · ${d.name}',
      info: l != null
          ? '${l.building ? '${l.units} viviendas · ' : ''}${originLabel[l.origin]} · ${money(l.price)}'
          : (rival != null ? 'Es de ${rival.name}: puede salir a la venta en una burbuja o una crisis' : 'No está en venta · referencia ${money(m2 * g.refPrice(lot))}'),
      action: l != null
          ? HsButton('Ver anuncio',
              size: BtnSize.sm,
              onTap: g.canBuy
                  ? () => push(context, BuyConfirmScreen(listing: l))
                  : () => toast(context, 'Comprar llega con la fase Casero', error: true))
          : HsButton('Barrio', size: BtnSize.sm, kind: BtnKind.sec, onTap: () => push(context, DistrictScreen(districtId: d.id))),
    );
  }
}

/// Nombre visible de un monumento.
String landmarkName(String id) => switch (id) {
      'catedral' => 'Catedral',
      'ayuntamiento' => 'Ayuntamiento',
      'estadio' => 'Estadio municipal',
      'mercado' => 'Mercado central',
      'faro' => 'Faro del puerto',
      'torre_tv' => 'Torre de televisión',
      'estacion' => 'Estación de tren',
      'hospital' => 'Hospital',
      'museo' => 'Museo de arte',
      'colegio' => 'Colegio público',
      'plaza_fuente' => 'Plaza de la fuente',
      _ => 'Monumento',
    };

/// Textos de ruina estables por vivienda.
class Tx2 {
  static const _ads = [
    'Luminoso, con mucho potencial',
    'Ideal inversores. Y valientes',
    'Encanto original, incluida la instalación',
    'Muchas posibilidades, pocas paredes rectas',
  ];
  static String ruin(int id) => _ads[id % _ads.length];
}

/// Hoja de calle seleccionada (mapa-calle).
class _StreetSheet extends ConsumerStatefulWidget {
  final int streetId;
  final void Function(Lot) onLot;
  const _StreetSheet({required this.streetId, required this.onLot});
  @override
  ConsumerState<_StreetSheet> createState() => _StreetSheetState();
}

class _StreetSheetState extends ConsumerState<_StreetSheet> {
  String _filter = 'todas';
  @override
  Widget build(BuildContext context) {
    final g = ref.watch(gameProvider);
    final s = g.city.streets[widget.streetId];
    final mine = g.props.where((p) => g.lotOf(p).street == s.id).toList();
    final market = g.listings.where((l) => g.city.lots[l.lotId].street == s.id).toList();
    final lots = g.city.lots.where((l) => l.street == s.id).length;
    final filtered = mine.where((p) {
      switch (_filter) {
        case 'obra':
          return p.state == PState.obra;
        case 'alquiladas':
          return p.state == PState.alquilada;
        case 'venta':
          return p.state == PState.venta;
        default:
          return true;
      }
    }).toList();
    final bonus = mine.isEmpty ? 0.0 : g.streetBonus(mine.first);
    final groups = groupByLot(filtered);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        Expanded(child: Text(s.name, style: Ht.h2)),
        Tag(s.avenue ? 'Avenida' : 'Calle', color: Hc.mut),
      ]),
      const SizedBox(height: 4),
      Text('$lots edificios · ${mine.length} tuyos · ${market.length} en venta', style: Ht.small),
      if (g.isPromoter) ...[
        const SizedBox(height: 10),
        Row(children: [
          const Cap('Efecto barrio'),
          const SizedBox(width: 10),
          Expanded(child: Meter(bonus / 0.10, color: Hc.acc)),
          const SizedBox(width: 10),
          Text('+${(bonus * 100).round()} %', style: Ht.numS.copyWith(color: Hc.acc)),
        ]),
      ],
      const SizedBox(height: 12),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final f in const [('todas', 'Todas'), ('obra', 'En obra'), ('alquiladas', 'Alquiladas'), ('venta', 'En venta')]) ...[
            FChip(f.$2, on: _filter == f.$1, onTap: () => setState(() => _filter = f.$1)),
            const SizedBox(width: 8),
          ],
        ]),
      ),
      const SizedBox(height: 12),
      Flexible(
        child: ListView(shrinkWrap: true, padding: EdgeInsets.zero, children: [
            for (final (i, grp) in groups.indexed)
              grp.length == 1
                  ? PropRow(g, grp.first, last: i == groups.length - 1 && market.isEmpty, onTap: () => widget.onLot(g.lotOf(grp.first)))
                  : BuildingRow(g, grp,
                      key: ValueKey('b${grp.first.lotId}'),
                      last: i == groups.length - 1 && market.isEmpty,
                      onUnit: (p) => push(context, PropertyScreen(propId: p.id))),
            for (var i = 0; i < market.length; i++)
              Li(
                last: i == market.length - 1,
                display: true,
                lead: LotThumb(lot: g.city.lots[market[i].lotId], state: market[i].auction && !market[i].building ? 'reformada' : 'ruina'),
                title: g.addressOfLot(g.city.lots[market[i].lotId]),
                sub: market[i].auction ? 'Subasta · habitable' : (market[i].building ? '${market[i].units} viviendas' : 'Ruina en venta'),
                trail: Text(money(market[i].price), style: Ht.numS.copyWith(color: Hc.acc)),
                onTap: () => widget.onLot(g.city.lots[market[i].lotId]),
              ),
            if (filtered.isEmpty && market.isEmpty)
              const Padding(padding: EdgeInsets.all(16), child: Text('Nada tuyo en esta calle. Todavía.', style: TextStyle(color: Hc.mut))),
        ]),
      ),
    ]);
  }
}

class _LayersSheet extends ConsumerWidget {
  const _LayersSheet();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(mapLayersProvider);
    final g = ref.watch(gameProvider);
    void upd(MapLayers n) => ref.read(mapLayersProvider.notifier).state = n;
    Widget row(String t, String s, bool v, ValueChanged<bool> f, IconData i, {bool last = false}) =>
        Li(lead: IconBox(i), title: t, sub: s, trail: HsToggle(v, f), last: last);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Text('Capas del mapa', style: Ht.h2),
      const SizedBox(height: 12),
      ListBlock([
          row('Mis viviendas', 'Estado de cada una', l.mine, (v) => upd(l.copyWith(mine: v)), Icons.home_outlined),
          row('En venta', 'Ruinas y subastas del mercado', l.market, (v) => upd(l.copyWith(market: v)), Icons.sell_outlined),
          row('Barrios', 'Nombres de los barrios', l.districts, (v) => upd(l.copyWith(districts: v)), Icons.map_outlined, last: g.rivals.isEmpty),
          if (g.rivals.isNotEmpty)
            row('Inversores', g.rivals.map((r) => r.name).join(' · '), l.rivals, (v) => upd(l.copyWith(rivals: v)), Icons.business_center_outlined, last: true),
      ]),
      const SizedBox(height: 12),
      const Cap('Tema del mapa'),
      const SizedBox(height: 8),
      Seg3<String>(
        values: const ['dia', 'atardecer', 'noche'],
        value: g.meta.mapTheme,
        label: (v) => switch (v) { 'atardecer' => 'Atardecer', 'noche' => 'Noche', _ => 'Día' },
        enabled: (v) => g.meta.cosmetics.contains(v),
        onChanged: (v) {
          g.meta.mapTheme = v;
          g.touch();
        },
      ),
      const SizedBox(height: 8),
      Text('Los temas se desbloquean con logros y con el pase.', style: Ht.small, textAlign: TextAlign.center),
      SizedBox(height: math.max(0, MediaQuery.of(context).padding.bottom - 10)),
    ]);
  }
}
