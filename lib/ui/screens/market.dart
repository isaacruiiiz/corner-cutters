import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;
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
import '../widgets/overlays.dart';
import 'buy.dart';
import 'property.dart';

import '../../core/texto.dart';
/// Mercado: resumen, ciclo de cinco fases, gráfica, multiplicadores y titular.
class MarketScreen extends ConsumerWidget {
  const MarketScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = ref.watch(gameProvider);
    final ph = mph(g.phase);
    final hist = g.mHistory;
    final delta = hist.isEmpty ? 0.0 : g.m - hist.first;
    final head = g.news.isNotEmpty ? g.news.first : null;
    final next = mph(g.nextPhase);
    return Screen(
      safeBottom: false,
      dock: Row(children: [
        Expanded(child: HsButton('Hipotecas', kind: BtnKind.sec, block: true, size: BtnSize.sm, onTap: () => push(context, const MortgagesScreen()))),
        const SizedBox(width: 8),
        Expanded(
          child: HsButton('Ver anuncios',
              block: true,
              size: BtnSize.sm,
              onTap: g.canBuy ? () => push(context, const BuyScreen()) : () => toast(context, 'Comprar llega con la fase Casero', error: true)),
        ),
      ]),
      child: Column(children: [
        TabHeader('Mercado', trail: [Tag(ph.name, color: ph.color)]),
        Expanded(
          child: Body([
            StatGrid([
              Stat('Mult.', mult(g.m), color: Hc.warn),
              Stat('Fase', ph.name, color: ph.color),
              Stat('Termina en', dur(g.phaseLeft)),
            ], columns: 3),
            // Ciclo: la fase actual se eleva 4 px en su color.
            Row(children: [
              for (final p in MarketPhase.values) ...[
                if (p != MarketPhase.crisis) const SizedBox(width: 5),
                Expanded(child: _PhaseChip(p: p, current: p == g.phase)),
              ],
            ]),
            StatTile(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  const Expanded(child: Cap('Multiplicador de precios · 12 h')),
                  Text('${delta >= 0 ? '+' : '−'}${dec(delta.abs() * 100, 0)} %',
                      style: Ht.small.copyWith(color: delta >= 0 ? Hc.ok : Hc.bad, fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 6),
                SizedBox(height: 110, child: CustomPaint(painter: _MarketChart(hist, nextM: next.m))),
                const SizedBox(height: 4),
                Row(children: const [Expanded(child: Cap('Hace 12 h')), Cap('Ahora', color: Hc.acc)]),
              ]),
            ),
            StatGrid([
              Stat('Alquileres', mult(ph.ma), color: ph.ma >= 1 ? Hc.ok : Hc.bad),
              Stat('Ventas', mult(ph.m), color: ph.m >= 1 ? Hc.ok : Hc.bad),
              Stat('Siguiente · ${next.name}', mult(next.m), color: next.color),
            ], columns: 3),
            if (head != null)
              SideQuote('«${head.title}» ${head.body} · Tus ${g.props.length} viviendas valen ${money(g.assets)}.'),
            Row(children: [
              const Cap('Jugada típica'),
              const SizedBox(width: 8),
              Expanded(child: Text(ph.play, style: Ht.small.copyWith(color: Hc.ok, fontWeight: FontWeight.w700), textAlign: TextAlign.right)),
            ]),
            if (g.phase == MarketPhase.crisis || g.phase == MarketPhase.estanc) _CrisisPanel(g: g),
            ListBlock([
              Li(
                lead: const IconBox(Icons.add_home_outlined, color: Hc.acc),
                title: 'En venta',
                sub: '${g.listings.where((l) => !l.auction).length} ruinas · ${g.listings.where((l) => l.auction).length} subastas habitables',
                trail: const Icon(Icons.chevron_right_rounded, color: Hc.mut),
                onTap: g.canBuy ? () => push(context, const BuyScreen()) : () => toast(context, 'Comprar llega con la fase Casero', error: true),
              ),
              Li(
                lead: const IconBox(Icons.groups_2_outlined, color: Hc.bad),
                title: 'Inversores',
                sub: g.rivals.isEmpty ? 'Todavía no compite nadie contigo' : '${plural(g.rivals.length, 'rival', 'rivales')} · ${g.rivals.fold<int>(0, (a, r) => a + r.lots.length)} viviendas suyas',
                trail: const Icon(Icons.chevron_right_rounded, color: Hc.mut),
                onTap: () => push(context, const RivalsScreen()),
              ),
              Li(
                last: true,
                lead: const IconBox(Icons.account_balance_outlined, color: Hc.info),
                title: 'Hipotecas',
                sub: g.hasMortgage
                    ? 'Deuda total ${money(g.totalDebt)} · ${money(g.monthlyInterest)}/mes'
                    : (g.eraCfg != null ? g.mortgageLock : 'Desde la Empresa de reformas'),
                trail: const Icon(Icons.chevron_right_rounded, color: Hc.mut),
                onTap: () => push(context, const MortgagesScreen()),
              ),
            ]),
            if (g.news.length > 1) ...[
              const SectionHead('Hemeroteca'),
              ListBlock([
                for (var i = 1; i < math.min(6, g.news.length); i++) Li(last: i == math.min(6, g.news.length) - 1, title: g.news[i].title, sub: g.news[i].body),
              ]),
            ],
            Text('Cada fase dura entre 1 y 3 horas reales. Hipoteca: hasta 70 % del valor, 0,5 % mensual.', style: Ht.mini, textAlign: TextAlign.center),
          ]),
        ),
      ]),
    );
  }
}


/// Qué se puede hacer mientras dura una crisis (o un estancamiento).
class _CrisisPanel extends StatelessWidget {
  final Game g;
  const _CrisisPanel({required this.g});
  @override
  Widget build(BuildContext context) {
    final crisis = g.phase == MarketPhase.crisis;
    final reno = ((1 - Eco.renoCostMult(g.phase)) * 100).round();
    final list = ((1 - Eco.listingMult(g.phase)) * 100).round();
    final embargos = g.listings.where((l) => l.origin == Origin.embargo).length;
    final missions = g.missions.where((m) => m.id.startsWith('crisis_') && !m.claimed).length;
    return Panel(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
          child: Row(children: [
            Icon(Icons.trending_down_rounded, color: crisis ? Hc.bad : Hc.warn),
            const SizedBox(width: 8),
            Expanded(child: Text(crisis ? 'Crisis: momento de comprar y reformar' : 'Estancamiento: precios flojos', style: Ht.card)),
          ]),
        ),
        Li(lead: const IconBox(Icons.handyman_outlined, color: Hc.ok), title: 'Reformas −$reno %', sub: 'Materiales y mano de obra más baratos'),
        Li(lead: const IconBox(Icons.sell_outlined, color: Hc.ok), title: 'Anuncios −$list %', sub: embargos > 0 ? '$embargos ${embargos == 1 ? 'embargo' : 'embargos'} del banco a precio de saldo' : 'Vigila los embargos del banco'),
        if (crisis) ...[
          const Li(lead: IconBox(Icons.school_outlined, color: Hc.ok), title: 'Empresa a mitad de precio', sub: 'Formación, cuadrillas y herramientas'),
          const Li(lead: IconBox(Icons.groups_2_outlined, color: Hc.acc), title: 'Inversores en apuros', sub: 'Malvenden viviendas habitables: aparecen en anuncios'),
        ],
        Li(
          last: true,
          lead: const IconBox(Icons.flag_outlined, color: Hc.acc),
          title: missions > 0 ? '$missions ${missions == 1 ? 'misión' : 'misiones'} de crisis' : 'Encargos de clientes',
          sub: missions > 0 ? 'Con recompensa extra mientras dure' : 'Cobran aunque el mercado esté hundido',
        ),
      ]),
    );
  }
}

/// Inversores rivales: quiénes son, qué buscan y qué tienen.
class RivalsScreen extends ConsumerWidget {
  const RivalsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = ref.watch(gameProvider);
    final names = g.rivals.map((r) => r.name).toList();
    final moves = g.news.where((n) => names.any(n.title.startsWith)).take(6).toList();
    return Screen(
      child: Column(children: [
        const BackHeader('Inversores', sub: 'Compiten por las mismas viviendas e inquilinos'),
        Expanded(
          child: Body([
            if (g.rivals.isEmpty)
              const Note('Aparecen poco a poco según creces: primero un casero, luego empresas y promotoras. Nunca más de cuatro.', icon: Icons.hourglass_empty_rounded),
            for (final r in g.rivals)
              Panel(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Container(width: 14, height: 14, decoration: BoxDecoration(color: Color(r.color), shape: BoxShape.circle, border: Border.all(color: Hc.line, width: 2))),
                    const SizedBox(width: 8),
                    Expanded(child: Text(r.name, style: Ht.card)),
                    Tag(plural(r.lots.length, 'vivienda', 'viviendas'), color: Hc.acc),
                  ]),
                  const SizedBox(height: 6),
                  Text(rivalStyleInfo[r.style]!.desc, style: Ht.small),
                  const SizedBox(height: 8),
                  StatGrid([
                    Stat('Compradas', '${r.bought}'),
                    Stat('Vendidas', '${r.sold}'),
                    Stat('Caja', money(r.cash, compact: true)),
                  ], columns: 3),
                ]),
              ),
            const Note('Reserva un anuncio (3 %) para que nadie te lo quite durante 10 minutos. Si un rival intenta llevarse a un inquilino, puedes bajar la renta o mejorar la vivienda.',
                icon: Icons.lightbulb_outline),
            if (moves.isNotEmpty) ...[
              const SectionHead('Últimos movimientos'),
              ListBlock([
                for (var i = 0; i < moves.length; i++) Li(last: i == moves.length - 1, title: moves[i].title, sub: moves[i].body),
              ]),
            ],
          ]),
        ),
      ]),
    );
  }
}

/// Segmento del ciclo: la fase actual se eleva 4 px con fondo de su color.
class _PhaseChip extends StatelessWidget {
  final MarketPhase p;
  final bool current;
  const _PhaseChip({required this.p, required this.current});
  @override
  Widget build(BuildContext context) {
    final info = mph(p);
    return Transform.translate(
      offset: Offset(0, current ? -4 : 0),
      child: Container(
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: current ? info.color : Hc.panelIn,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Hc.line, width: 2),
          boxShadow: current ? [BoxShadow(color: Color.lerp(info.color, Colors.black, 0.55)!, offset: const Offset(0, 3))] : He.e1,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Text(info.short, style: Ht.cap.copyWith(fontSize: 8.5, color: current ? Hc.line : Hc.mut, letterSpacing: 0.6)),
          ),
        ),
      ),
    );
  }
}


class _MarketChart extends CustomPainter {
  final List<double> h;
  final double nextM;
  _MarketChart(this.h, {required this.nextM});
  @override
  void paint(Canvas canvas, Size size) {
    const lo = 0.6, hi = 1.45;
    double y(double v) => size.height - (v - lo) / (hi - lo) * size.height;
    final grid = Paint()
      ..color = Hc.lineSoft
      ..strokeWidth = 1;
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (final g in [0.8, 1.0, 1.2]) {
      canvas.drawLine(Offset(28, y(g)), Offset(size.width, y(g)), grid);
      tp.text = TextSpan(text: dec(g, 1), style: const TextStyle(fontFamily: Hf.body, fontSize: 10, color: Hc.mut));
      tp.layout();
      tp.paint(canvas, Offset(0, y(g) - tp.height / 2));
    }
    if (h.isEmpty) return;
    final w = size.width - 28 - 40;
    final step = h.length > 1 ? w / (h.length - 1) : w;
    final path = Path()..moveTo(28, y(h.first));
    final fill = Path()..moveTo(28, size.height);
    for (var i = 0; i < h.length; i++) {
      final x = 28 + i * step;
      if (i > 0) path.lineTo(x, y(h[i - 1]));
      path.lineTo(x, y(h[i]));
      fill.lineTo(x, y(h[i]));
    }
    fill
      ..lineTo(28 + (h.length - 1) * step, size.height)
      ..close();
    canvas.drawPath(fill, Paint()..color = const Color(0x24E3A93B));
    canvas.drawPath(path, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = Hc.acc);
    final last = Offset(28 + (h.length - 1) * step, y(h.last));
    // proyección punteada a la siguiente fase
    final nx = Offset(size.width - 4, y(nextM));
    final dash = Paint()
      ..color = Hc.acc
      ..strokeWidth = 2;
    const n = 8;
    for (var i = 0; i < n; i += 2) {
      canvas.drawLine(Offset.lerp(last, nx, i / n)!, Offset.lerp(last, nx, (i + 1) / n)!, dash);
    }
    canvas.drawCircle(last, 7, Paint()..color = Hc.line);
    canvas.drawCircle(last, 5, Paint()..color = Hc.ink);
    canvas.drawCircle(last, 5, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Hc.acc);
  }

  @override
  bool shouldRepaint(_MarketChart o) => true;
}

/// Hipotecas: deuda por vivienda y riesgo si el mercado cae.
class MortgagesScreen extends ConsumerWidget {
  const MortgagesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = ref.watch(gameProvider);
    final withDebt = g.props.where((p) => p.debt > 0).toList();
    final crisisValue = g.props.fold<double>(0, (a, p) => a + g.valueOf(p, mOverride: 0.70));
    final ltvNow = g.assets <= 0 ? 0.0 : g.totalDebt / g.assets;
    return Screen(
      child: Column(children: [
        const BackHeader('Hipotecas', sub: 'Hasta 70 % del valor · 0,5 % mensual'),
        Expanded(
          child: Body([
            if (!g.hasMortgage && g.eraCfg == null)
              const Note('Las hipotecas llegan con la Empresa de reformas (tres reformas terminadas).', icon: Icons.lock_outline),
            if (!g.hasMortgage && g.eraCfg != null) Note('${g.mortgageLock}: en esta época los bancos no prestan.', icon: Icons.lock_outline),
            StatGrid([
              Stat('Deuda total', money(g.totalDebt), color: g.totalDebt > 0 ? Hc.bad : Hc.ink),
              Stat('Interés', '${money(g.monthlyInterest)}/mes'),
              Stat('Deuda / valor', pct(ltvNow), extra: Meter(ltvNow, color: ltvNow > 0.6 ? Hc.bad : Hc.info, marker: 0.7)),
              Stat('Si llega la crisis', money(crisisValue), color: crisisValue < g.totalDebt ? Hc.bad : Hc.mut),
            ]),
            if (withDebt.isEmpty)
              const Note('Sin deuda. Apalancarse acelera el crecimiento: la renta (≈0,8 % mensual) cubre el interés (0,5 %).')
            else
              ListBlock([
                  for (var i = 0; i < withDebt.length; i++)
                    Li(
                      last: i == withDebt.length - 1,
                      onTap: () => push(context, PropertyScreen(propId: withDebt[i].id)),
                      lead: IconBox(Icons.account_balance_outlined, color: withDebt[i].debt > g.valueOf(withDebt[i]) ? Hc.bad : Hc.info),
                      title: g.addressOf(withDebt[i]),
                      sub: 'Valor ${money(g.valueOf(withDebt[i]))} · ${pct(withDebt[i].debt / g.valueOf(withDebt[i]))}',
                      trail: Text(money(withDebt[i].debt), style: Ht.numS.copyWith(color: Hc.bad)),
                    ),
                ]),
            if (g.hasMortgage) ...[
              const SectionHead('Pedir sobre vivienda'),
              ListBlock([
                  for (final p in g.props.where((p) => g.maxLoan(p) > 1000))
                    Li(
                      title: g.addressOf(p),
                      sub: 'Margen ${money(g.maxLoan(p))}',
                      trail: HsButton('Pedir', size: BtnSize.xs, kind: BtnKind.info, onTap: () {
                        final e = g.borrow(p, g.maxLoan(p));
                        if (e != null) toast(context, e, error: true);
                      }),
                    ),
                ]),
            ],
            Note('Si una crisis baja el valor por debajo de la deuda, el banco avisa. Si no amortizas en 30 minutos, ejecuta la hipoteca. En crisis los precios caen a ${mult(mph(MarketPhase.crisis).m)}.',
                icon: Icons.warning_amber_rounded, kind: NoteKind.warn),
          ]),
        ),
      ]),
    );
  }
}
