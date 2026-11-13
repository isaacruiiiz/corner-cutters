import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../guia.dart';
import '../../app/providers.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../game/data.dart';
import '../../game/economy.dart';
import '../../game/engine.dart';
import '../../game/model.dart';
import '../../game/texts.dart';
import '../common.dart';
import '../widgets/atoms.dart';
import '../widgets/econ.dart';
import '../widgets/overlays.dart';
import 'company.dart';
import 'obra.dart';

import '../../core/texto.dart';
import '../../core/i18n.dart';
/// Perfil cuyo óptimo se parece más a unos niveles (para plantillas sin vivienda).
Sector nearestSector(Map<Trade, int> lv) {
  Sector best = Sector.fam;
  var bd = double.infinity;
  for (final s in Sector.values) {
    var d = 0.0;
    for (final t in Trade.values) {
      d += math.pow((lv[t] ?? 0) - si(s).optimal[t]!, 2);
    }
    if (d < bd) {
      bd = d;
      best = s;
    }
  }
  return best;
}

/// Selector de reforma: una barra por oficio con el nivel que ya tiene, el objetivo y las marcas
/// del óptimo de cada perfil. No se elige sector: la vivienda sale a la venta para todos y la zona,
/// el precio y la calidad deciden quién la compra.
/// Con [templateIndex] o [editTemplate] funciona como editor de plantillas.
class SelectorScreen extends ConsumerStatefulWidget {
  final int? propId;
  final bool editTemplate;
  final int? templateIndex;
  /// Varias viviendas (mismo edificio) que se reforman con la misma configuración.
  final List<int>? propIds;
  const SelectorScreen({super.key, this.propId, this.editTemplate = false, this.templateIndex, this.propIds});
  @override
  ConsumerState<SelectorScreen> createState() => _SelectorScreenState();
}

class _SelectorScreenState extends ConsumerState<SelectorScreen> {
  final Map<Trade, int> _lv = {};
  final _name = TextEditingController();
  bool _init = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  int _base(Property? p, Trade t) => p?.lv(t) ?? 0;

  void _suggest(Game g, Property? p) {
    if (p == null) {
      final s = Sector.est;
      for (final t in Trade.values) {
        _lv[t] = math.max(1, math.min(si(s).optimal[t]!, g.tradeLv[t]!));
      }
      return;
    }
    _lv
      ..clear()
      ..addAll(g.suggestedLevels(p));
  }

  @override
  Widget build(BuildContext context) {
    final g = ref.watch(gameProvider);
    final p = widget.propId == null ? null : g.prop(widget.propId!);
    if (!_init) {
      _init = true;
      if (widget.templateIndex != null && widget.templateIndex! < g.meta.templates.length) {
        final t = g.meta.templates[widget.templateIndex!];
        _lv.addAll(t.levels);
        _name.text = t.name;
      } else {
        _suggest(g, p);
        if (widget.editTemplate) _name.text = 'Plantilla ${g.meta.templates.length + 1}';
      }
      if (p != null) {
        for (final t in Trade.values) {
          _lv[t] = math.max(_lv[t] ?? 0, _base(p, t));
        }
      }
    }
    final editing = widget.editTemplate || widget.templateIndex != null;
    final est = p == null ? null : g.estimate(p, _lv);
    final multi = [
      if (widget.propIds != null)
        for (final id in widget.propIds!)
          if (g.prop(id) case final q? when q.state != PState.obra) q
    ];
    final n = multi.length > 1 ? multi.length : 1;
    final multiCost = multi.length > 1 ? multi.fold<double>(0, (a, q) => a + g.estimate(q, _lv).cost) : 0.0;
    var err = p == null ? null : g.canStartReno(p, _lv);
    if (err == null && n > 1) {
      if (g.activeRenos + n > g.maxRenos) {
        err = 'Varias obras a la vez llegan con la Empresa de reformas';
      } else if (g.cash < multiCost) {
        err = 'Te faltan ${money(multiCost - g.cash)} para las $n obras';
      }
    }
    final tapsMin = est == null ? 0 : (est.taps / 70).ceil();
    final sector = est?.sector ?? nearestSector(_lv);
    return Screen(
      dock: editing
          ? Column(mainAxisSize: MainAxisSize.min, children: [
              HsButton('Guardar plantilla', block: true, size: BtnSize.lg, icon: Icons.bookmark_add_outlined, onTap: () {
                final name = _name.text.trim().isEmpty ? 'Plantilla ${g.meta.templates.length + 1}' : _name.text.trim();
                final e = g.saveTemplate(RenoTemplate(name: name, sector: nearestSector(_lv), levels: Map.of(_lv)), index: widget.templateIndex);
                if (e != null) {
                  toast(context, e, error: true);
                } else {
                  Navigator.pop(context);
                  toast(context, 'Plantilla guardada');
                }
              }),
            ])
          : Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Flexible(
                  child: Text(n > 1 ? '$n viviendas · ${money(multiCost)}' : '≈ ${intg(est?.taps ?? 0)} toques · ${tapsMin < 1 ? 1 : tapsMin} min',
                      style: Ht.small, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                Text('Energía ${g.energy.floor()}/${Game.maxEnergy.round()}', style: Ht.small),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: GuiaMarca(GuiaPunto.lanzarObra, child: HsButton(n > 1 ? 'Lanzar $n obras' : 'Lanzar obra', size: BtnSize.lg, block: true, onTap: err != null || p == null
                      ? null
                      : () async {
                          if (n > 1) {
                            final rented = multi.where((q) => q.state == PState.alquilada).length;
                            if (rented > 0 &&
                                !await confirm(context,
                                    title: 'Rescindir y reformar',
                                    body: 'Hay ${plural(rented, 'vivienda alquilada', 'viviendas alquiladas')}: reformar obliga a rescindir los contratos.',
                                    danger: true)) {
                              return;
                            }
                            var ok = 0;
                            String? last;
                            for (final q in multi) {
                              last = g.startReno(q, Map.of(_lv));
                              if (last != null) break;
                              ok++;
                            }
                            HapticFeedback.mediumImpact();
                            if (!context.mounted) return;
                            Navigator.pop(context);
                            toast(context, last == null ? '$ok obras en marcha' : '$ok obras en marcha · $last', error: last != null);
                            return;
                          }
                          if (p.state == PState.alquilada &&
                              !await confirm(context, title: 'Rescindir y reformar', body: 'Reformar una vivienda alquilada obliga a rescindir el contrato.', danger: true)) {
                            return;
                          }
                          final e = g.startReno(p, Map.of(_lv));
                          if (e != null) {
                            toast(context, e, error: true);
                            return;
                          }
                          g.tutorialDone = true;
                          HapticFeedback.mediumImpact();
                          if (!context.mounted) return;
                          Navigator.of(context).pushReplacement(glassRoute(ObraScreen(propId: p.id)));
                        })),
                ),
                const SizedBox(width: 10),
                SqButton(Icons.bookmarks_outlined, size: 56, tooltip: 'Plantillas', onTap: () => _templates(context, g, p)),
              ]),
              if (err != null) ...[
                const SizedBox(height: 8),
                Text(err, style: Ht.small.copyWith(color: Hc.bad), textAlign: TextAlign.center),
              ],
            ]),
      child: Column(children: [
        BackHeader(editing ? 'Plantilla' : (p?.isClient == true ? 'Encargo' : 'Reformar'),
            sub: p == null ? 'Niveles por oficio' : (n > 1 ? '${g.addressOfLot(g.lotOf(p))} · $n viviendas iguales' : '${g.addressOf(p)} · ${p.m2} m²')),
        Expanded(
          child: Body([
            if (editing)
              TextField(
                controller: _name,
                style: Ht.bodyB,
                decoration: InputDecoration(
                  hintText: tr('Nombre de la plantilla'),
                  hintStyle: Ht.body.copyWith(color: Hc.dim),
                  filled: true,
                  fillColor: Hc.panelIn,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Hr.md), borderSide: const BorderSide(color: Hc.line, width: 2)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Hr.md), borderSide: const BorderSide(color: Hc.acc, width: 2)),
                ),
              ),
            if (p != null && !p.isClient) ...[
              Panel(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Expanded(child: Cap('Público en ${zi(g.zoneOf(p)).name.toLowerCase()}')),
                    Text('Encaja con ${si(sector).name.toLowerCase()}', style: Ht.small.copyWith(color: Hc.acc, fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 8),
                  ShareBar(g.sharesOf(g.lotOf(p))),
                  if (g.traitsOf(g.lotOf(p)).isNotEmpty) ...[
                    const SizedBox(height: 8),
                    TraitChips(g.traitsOf(g.lotOf(p))),
                  ],
                ]),
              ),
            ],
            Row(children: [
              const Expanded(child: Cap('Nivel por oficio')),
              if (p != null && !p.isClient)
                HsButton('Sugerido para esta zona', size: BtnSize.xs, kind: BtnKind.sec, icon: Icons.auto_fix_high_rounded, onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _suggest(g, p));
                }),
            ]),
            Panel(
              padding: EdgeInsets.zero,
              child: Column(children: [
                for (final t in Trade.values)
                  _TradeRow(
                    trade: t,
                    level: _lv[t] ?? 0,
                    base: _base(p, t),
                    available: g.tradeLv[t]!,
                    cap: g.levelCap,
                    weight: p == null ? null : zi(g.zoneOf(p)).weights[t]!,
                    shares: p == null ? null : g.sharesOf(g.lotOf(p)),
                    locked: p?.isClient ?? false,
                    last: t == Trade.dec,
                    onChanged: (v) => setState(() => _lv[t] = math.max(v, _base(p, t))),
                    onLocked: (v) => _locked(context, g, t, v),
                  ),
              ]),
            ),
            const _MarkerLegend(),
            if (est != null && p != null && !p.isClient) ...[
              BuyersPanel(g.buyersOf(p, est.value, levels: g.clampTargets(p, _lv)), ask: est.value, title: 'Quién la compraría al terminar'),
              _Pnl(g: g, p: p, est: est),
            ],
            if (p != null && p.isClient)
              Note('Encargo de ${p.clientName}: los niveles los pide el cliente. Cobras ${money(p.clientFee)} al terminar; los materiales los paga él.',
                  icon: Icons.handshake_outlined, kind: NoteKind.ok),
            Quote(Tx.selectorQuote(_lv, sector)),
            if (p != null && (p.humidity || p.badWiring) && !p.everRenovated)
              const Note('Los defectos ocultos pueden añadir toques a albañilería o electricidad.', icon: Icons.visibility_outlined),
            if (!editing)
              Note(
                  'En gris, lo que ya tiene la vivienda: solo pagas y trabajas la diferencia.${g.inCrisis ? ' En crisis la obra sale un 25 % más barata.' : ''} '
                  'Por encima del nivel formado de cada oficio, primero hay que formarlo en Empresa.',
                  icon: Icons.school_outlined),
          ]),
        ),
      ]),
    );
  }

  /// Nivel por encima del formado: avisa y ofrece formar el oficio o ir a Empresa.
  Future<void> _locked(BuildContext context, Game g, Trade t, int target) async {
    final from = g.tradeLv[t]!;
    if (target > g.levelCap) return;
    var cost = 0.0;
    for (var n = from + 1; n <= target; n++) {
      cost += g.trainCost(n);
    }
    final extraWork = Eco.phaseWork(t, 50, target) / Eco.phaseWork(t, 50, 1);
    await showHsDialog(context, builder: (ctx) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        DialogHead(icon: ti(t).icon, color: Hc.acc, cap: 'Formación en Empresa', title: '${ti(t).name}: nv. $target'),
        const SizedBox(height: 12),
        Text('Tu ${ti(t).name.toLowerCase()} está a nivel $from. Para reformar a nivel $target primero hay que formarlo. Se paga una sola vez y queda para todas las obras.',
            style: Ht.body.copyWith(color: Hc.mut)),
        const SizedBox(height: 12),
        Panel(
          kind: PanelKind.inset,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Column(children: [
            KV('Formación $from → $target', money(cost), color: Hc.acc),
            KV('Efectivo', money(g.cash), color: g.cash < cost ? Hc.bad : Hc.ink),
            KV('Duración de la fase', '×${dec(extraWork, 1)} toques'),
            KV('Coste por m²', '${money(ti(t).costPerM2 * Eco.k(target))}/m²'),
          ]),
        ),
        const SizedBox(height: 14),
        HsButton('Formar hasta nv. $target', block: true, price: money(cost, compact: true), onTap: g.cash < cost
            ? null
            : () {
                String? err;
                while (g.tradeLv[t]! < target && err == null) {
                  err = g.train(t);
                }
                Navigator.pop(ctx);
                if (err != null) {
                  toast(context, err, error: true);
                } else {
                  setState(() => _lv[t] = target);
                  toast(context, '${ti(t).name} formado a nivel $target');
                }
              }),
        const SizedBox(height: 8),
        HsButton('Ir a Empresa', kind: BtnKind.sec, block: true, icon: Icons.apartment_outlined, onTap: () {
          Navigator.pop(ctx);
          ref.read(companyTradeSel.notifier).state = t;
          ref.read(tabProvider.notifier).state = 2;
          Navigator.of(context).popUntil((r) => r.isFirst);
        }),
        const SizedBox(height: 4),
        HsButton('Cancelar', kind: BtnKind.ghost, size: BtnSize.sm, onTap: () => Navigator.pop(ctx)),
      ]);
    });
  }

  void _templates(BuildContext context, Game g, Property? p) {
    showHsSheet(context, builder: (ctx) {
      return StatefulBuilder(builder: (ctx, setS) {
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Expanded(child: Text('Plantillas', style: Ht.title)),
            Cap('${g.meta.templates.length} de ${g.templateSlots}'),
          ]),
          const SizedBox(height: 12),
          ListBlock([
            if (g.meta.templates.isEmpty)
              const Padding(padding: EdgeInsets.all(16), child: Text('Aún no hay plantillas. Guarda esta combinación.', style: TextStyle(color: Hc.mut))),
            for (var i = 0; i < g.meta.templates.length; i++)
              Li(
                last: i == g.meta.templates.length - 1,
                lead: IconBox(si(nearestSector(g.meta.templates[i].levels)).icon),
                title: g.meta.templates[i].name,
                sub: Trade.values.map((t) => '${tr(ti(t).code)} ${g.meta.templates[i].levels[t] ?? 0}').join(' · '),
                trail: HsButton('Aplicar', size: BtnSize.xs, onTap: () {
                  final t = g.meta.templates[i];
                  setState(() {
                    for (final k in Trade.values) {
                      _lv[k] = math.max(_base(p, k), math.min(t.levels[k] ?? 0, g.tradeLv[k]!));
                    }
                    if ((_lv[Trade.ele] ?? 0) < 1) _lv[Trade.ele] = 1;
                  });
                  Navigator.pop(ctx);
                }),
              ),
          ]),
          const SizedBox(height: 12),
          HsButton('Guardar la actual', kind: BtnKind.sec, block: true, icon: Icons.bookmark_add_outlined, onTap: () {
            final e = g.saveTemplate(RenoTemplate(
                name: '${si(nearestSector(_lv)).name} ${g.meta.templates.length + 1}', sector: nearestSector(_lv), levels: Map.of(_lv)));
            if (e != null) {
              toast(context, e, error: true);
            } else {
              setS(() {});
            }
          }),
        ]);
      });
    });
  }
}

const _markerColors = ShareBar.colors;

class _MarkerLegend extends StatelessWidget {
  const _MarkerLegend();
  @override
  Widget build(BuildContext context) => Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 4, children: [
        for (final s in Sector.values)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.arrow_drop_up_rounded, size: 18, color: _markerColors[s]),
            Text('óptimo ${si(s).name.toLowerCase()}', style: Ht.mini),
          ]),
      ]);
}

class _TradeRow extends StatelessWidget {
  final Trade trade;
  final int level, base, available, cap;
  final double? weight;
  final Map<Sector, double>? shares;
  final bool locked;
  final bool last;
  final ValueChanged<int> onChanged;
  final ValueChanged<int> onLocked;
  const _TradeRow({
    required this.trade,
    required this.level,
    required this.base,
    required this.available,
    required this.cap,
    required this.weight,
    required this.shares,
    required this.locked,
    required this.last,
    required this.onChanged,
    required this.onLocked,
  });

  @override
  Widget build(BuildContext context) {
    final minL = math.max(base, trade == Trade.ele ? 1 : 0);
    final total = math.min(cap, 20);
    // Estado frente a los perfiles con presencia en la zona.
    String status;
    Color sc;
    if (level <= base) {
      status = base == 0 ? 'SIN HACER' : 'SE QUEDA EN $base';
      sc = base == 0 ? Hc.bad : Hc.mut;
    } else {
      status = 'SUBE $base→$level';
      sc = Hc.acc;
    }
    final ownMax = math.max(available, base);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 12, 8),
      decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: Hc.lineSoft, width: 1.5))),
      child: Row(children: [
        Icon(ti(trade).icon, size: 18, color: Hc.mut),
        const SizedBox(width: 10),
        SizedBox(
          width: 92,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ti(trade).phase, style: Ht.bodyB.copyWith(fontSize: 13.5), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(status, style: Ht.cap.copyWith(color: sc, fontSize: 9.5, letterSpacing: 0.8), maxLines: 1, overflow: TextOverflow.ellipsis),
            if (weight != null) Text('peso ${(weight! * 100).round()} %', style: Ht.small.copyWith(fontSize: 10.5, color: Hc.dim)),
            Text('formado: nv. $available', style: Ht.small.copyWith(fontSize: 10.5, color: Hc.dim)),
          ]),
        ),
        Expanded(
          child: LayoutBuilder(builder: (context, c) {
            int at(Offset q) => ((q.dx / c.maxWidth) * total).ceil().clamp(minL, total).toInt();
            void upd(int v, {bool ask = false}) {
              if (locked) return;
              if (v > ownMax) {
                if (level != ownMax) onChanged(ownMax);
                if (ask) onLocked(v);
                return;
              }
              if (v != level) {
                HapticFeedback.selectionClick();
                onChanged(v);
              }
            }

            var wanted = level;
            final segW = c.maxWidth / total;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (d) => upd(at(d.localPosition), ask: true),
              onHorizontalDragUpdate: (d) {
                wanted = at(d.localPosition);
                upd(wanted);
              },
              onHorizontalDragEnd: (_) {
                if (!locked && wanted > ownMax) onLocked(wanted);
              },
              child: SizedBox(
                height: 40,
                child: Stack(clipBehavior: Clip.none, children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 4,
                    height: 12,
                    child: Row(children: [
                      for (var i = 1; i <= total; i++) ...[
                        if (i > 1) const SizedBox(width: 2),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: i <= base
                                  ? Hc.mut.withValues(alpha: 0.55)
                                  : (i <= level ? Hc.acc : (i > ownMax ? const Color(0xFF0A1716) : Hc.panelIn)),
                              borderRadius: BorderRadius.circular(2),
                              border: Border.all(color: Hc.line, width: 1),
                            ),
                          ),
                        ),
                      ],
                    ]),
                  ),
                  // Marcas del óptimo de cada perfil (las de poca cuota, más tenues).
                  for (final s in Sector.values)
                    if (si(s).optimal[trade]! <= total)
                      Positioned(
                        left: (si(s).optimal[trade]! - 0.5) * segW - 9 + (s.index - 1.5) * 2,
                        top: 16,
                        child: Opacity(
                          opacity: shares == null ? 1 : (shares![s]! >= 0.15 ? 1 : 0.35),
                          child: Icon(Icons.arrow_drop_up_rounded, size: 18, color: _markerColors[s]),
                        ),
                      ),
                ]),
              ),
            );
          }),
        ),
        const SizedBox(width: 8),
        Column(mainAxisSize: MainAxisSize.min, children: [
          GestureDetector(
            onTap: locked || level >= total ? null : () => level + 1 > ownMax ? onLocked(level + 1) : onChanged(level + 1),
            child: Icon(level >= ownMax && level < total ? Icons.lock_outline_rounded : Icons.keyboard_arrow_up_rounded,
                size: level >= ownMax && level < total ? 14 : 18, color: level < total && !locked ? Hc.mut : Hc.dim),
          ),
          SizedBox(
            width: 26,
            child: Text(level == 0 ? '—' : '$level', textAlign: TextAlign.center, style: Ht.numS.copyWith(fontSize: 21)),
          ),
          GestureDetector(
            onTap: !locked && level > minL ? () => onChanged(level - 1) : null,
            child: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: !locked && level > minL ? Hc.mut : Hc.dim),
          ),
        ]),
      ]),
    );
  }
}

class _Pnl extends StatelessWidget {
  final Game g;
  final Property p;
  final RenoEstimate est;
  const _Pnl({required this.g, required this.p, required this.est});
  @override
  Widget build(BuildContext context) {
    final diff = est.profit - est.profitOpt;
    return Panel(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(
          child: Column(children: [
            KV('Valor de venta', money(est.value)),
            KV('Compra y obras previas', money(-(p.paid + p.spent))),
            KV('Esta obra', money(-est.cost)),
            KV('Calidad (${si(est.sector).name.toLowerCase()})', dec(est.quality, 2), color: est.quality >= 0.999 ? Hc.ok : Hc.warn),
            KV('Renta ref.', '${money(est.rent, compact: true)}/mes', color: Hc.mut),
          ]),
        ),
        const SizedBox(width: 12),
        Pose.paper(
          child: Panel(
            kind: PanelKind.pop,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('BENEFICIO', style: Ht.cap.copyWith(color: const Color(0xB81A1304))),
              const SizedBox(height: 4),
              FittedBox(fit: BoxFit.scaleDown, child: Text(money(est.profit), style: Ht.numL.copyWith(color: Hc.onAcc))),
              const SizedBox(height: 2),
              if (diff.abs() >= 1)
                Text('${diff < 0 ? '▼' : '▲'} ${money(diff.abs())} vs. sugerido',
                    style: TextStyle(fontFamily: Hf.body, fontWeight: FontWeight.w700, fontSize: 10.5, color: diff < 0 ? const Color(0xFF7A2A22) : const Color(0xFF1D6B4A)))
              else
                const Text('Igual que el sugerido',
                    style: TextStyle(fontFamily: Hf.body, fontWeight: FontWeight.w700, fontSize: 10.5, color: Color(0xFF1D6B4A))),
            ]),
          ),
        ),
      ]),
    );
  }
}
