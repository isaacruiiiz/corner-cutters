import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../game/data.dart';
import '../../game/economy.dart';
import '../../game/engine.dart';
import '../../game/model.dart';
import '../../game/texts.dart';
import '../../services/anuncios.dart';
import '../../services/audio.dart';
import '../../services/entitlements.dart';
import '../chrome.dart';
import '../common.dart';
import '../minigames/boards.dart';
import '../minigames/obras2.dart';
import '../shell.dart';
import '../widgets/atoms.dart';
import '../widgets/overlays.dart';
import 'property.dart';

/// Pantalla de obra: pestañas por fase, tablero del minijuego, energía, combo y críticos.
class ObraScreen extends ConsumerStatefulWidget {
  final int propId;
  const ObraScreen({super.key, required this.propId});
  @override
  ConsumerState<ObraScreen> createState() => _ObraScreenState();
}

class _Pop {
  final int id;
  final Offset at;
  final String text;
  final Color color;
  _Pop(this.id, this.at, this.text, this.color);
}

class _ObraScreenState extends ConsumerState<ObraScreen> {
  Trade? _trade;
  final _pops = <_Pop>[];
  int _popId = 0;
  Offset? _crit;
  final _rng = math.Random();
  bool _energySheet = false;
  final _boardKey = GlobalKey();

  bool _work(Game g, Property p, Trade t, Offset at, {bool crit = false}) {
    final before = g.combo;
    final r = g.tap(p, t, crit: crit);
    if (!r.ok) {
      if (r.reason == 'energia') _noEnergy(context, g);
      return false;
    }
    if (before < 1.999 && g.combo >= 1.999) Sfx.play('combo');
    setState(() {
      _pops.add(_Pop(_popId++, at, '+${dec(r.power, r.power < 10 ? 1 : 0)}', crit ? Hc.crit : Hc.acc));
      if (_pops.length > 8) _pops.removeAt(0);
    });
    if (crit) {
      setState(() => _pops.add(_Pop(_popId++, at + const Offset(40, -10), 'CRÍTICO ×10', Hc.bad)));
    }
    if (g.critReady && _crit == null) {
      final box = _boardKey.currentContext?.size;
      if (box != null) {
        setState(() => _crit = Offset(30 + _rng.nextDouble() * (box.width - 100), 30 + _rng.nextDouble() * (box.height - 100)));
      }
    }
    if (r.phaseDone && !r.renoDone) {
      HapticFeedback.heavyImpact();
      final next = p.reno?.current;
      toast(context, '${ti(t).phase} terminada${next != null ? '. Siguiente: ${ti(next).phase}' : ''}');
      if (next != null) setState(() => _trade = next);
    }
    if (r.renoDone) {
      _closeLater();
      unawaited(Anuncios.intersticial());
    }
    return true;
  }

  /// Cierra ESTA pantalla aunque haya otra encima (la de «Obra terminada» se abre a la vez).
  void _close() {
    if (!mounted) return;
    final route = ModalRoute.of(context);
    final nav = Navigator.of(context);
    if (route == null) return;
    if (!nav.canPop()) {
      // La obra era la única pantalla (no debería pasar): se vuelve al juego en vez de dejarla en blanco.
      nav.pushReplacement(PageRouteBuilder(pageBuilder: (c, a, b) => const Shell(), transitionsBuilder: (c, a, b, child) => FadeTransition(opacity: a, child: child)));
      return;
    }
    if (route.isCurrent) {
      nav.pop();
    } else if (route.isActive) {
      nav.removeRoute(route);
    }
  }

  void _closeLater() => WidgetsBinding.instance.addPostFrameCallback((_) => _close());

  /// Decoración (capas) y fontanería (juntas): el tablero informa de la fracción hecha.
  bool _workTo(Game g, Property p, Trade t, double f) {
    final r = g.workTo(p, t, f);
    if (!r.ok) {
      if (r.reason == 'energia') _noEnergy(context, g);
      return false;
    }
    if (g.critReady && _crit == null) {
      final box = _boardKey.currentContext?.size;
      if (box != null) {
        setState(() => _crit = Offset(30 + _rng.nextDouble() * (box.width - 100), 30 + _rng.nextDouble() * (box.height - 100)));
      }
    }
    if (r.phaseDone && !r.renoDone) {
      HapticFeedback.heavyImpact();
      final next = p.reno?.current;
      toast(context, '${ti(t).phase} terminada${next != null ? '. Siguiente: ${ti(next).phase}' : ''}');
      if (next != null) setState(() => _trade = next);
    }
    if (r.renoDone) {
      _closeLater();
      unawaited(Anuncios.intersticial());
    }
    return true;
  }

  void _noEnergy(BuildContext context, Game g) {
    if (_energySheet) return;
    _energySheet = true;
    showHsSheet(context, builder: (ctx) => EnergySheet(g: g)).whenComplete(() => _energySheet = false);
  }

  @override
  Widget build(BuildContext context) {
    final g = ref.watch(gameProvider);
    final p = g.prop(widget.propId);
    if (p == null || p.reno == null) {
      return Screen(
        child: Column(children: [
          BackHeader('Obra', onBack: _close),
          Expanded(
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.check_circle_outline, size: 48, color: Hc.ok),
                const SizedBox(height: 10),
                Text('Obra terminada', style: Ht.title),
                const SizedBox(height: 16),
                HsButton('Volver', kind: BtnKind.sec, onTap: _close),
                if (p != null) ...[
                  const SizedBox(height: 8),
                  HsButton('Ver ficha', onTap: () {
                    final nav = Navigator.of(context);
                    _close();
                    nav.push(glassRoute(PropertyScreen(propId: p.id)));
                  }),
                ],
              ]),
            ),
          ),
        ]),
      );
    }
    final r = p.reno!;
    var t = _trade;
    if (t == null || !r.has(t)) {
      t = r.current ?? Trade.values.firstWhere(r.has);
      _trade = t;
    }
    final trade = t;
    final frac = r.frac(trade);
    final crewRate = g.crews.where((c) => c.trade == trade && c.propId == p.id).length * Eco.crewRate(g.tradeLv[trade]!) * g.meta.speedBonus;
    final power = (1 + g.toolLv[trade]!) * g.meta.speedBonus * (g.workBoost ? 2 : 1);
    final done = frac >= 1;

    Widget board;
    bool work(Offset at) => !done && _work(g, p, trade, at);
    switch (trade) {
      case Trade.alb:
        board = BrickBoard(progress: frac, onWork: work);
      case Trade.fon:
        board = PipeBoard(progress: frac, onSeal: (f) => !done && _workTo(g, p, Trade.fon, f), routes: p.m2 >= 120 ? 4 : 3, era: g.eraCfg?.id);
      case Trade.ele:
        final lv = r.levels[Trade.ele] ?? 1;
        board = WireBoard(
          progress: frac,
          onWork: work,
          pairs: 3 + (lv >= 6 ? 1 : 0) + (lv >= 12 ? 1 : 0) + (lv >= 17 ? 1 : 0),
          onMiss: g.shortCircuit,
          era: g.eraCfg?.id,
        );
      case Trade.car:
        // Un mueble al azar por obra (sin repetir hasta que salen todos los desbloqueados).
        board = AssembleBoard(progress: frac, onWork: work, item: FurnitureBag.forWork(r, r.levels[Trade.car] ?? 1), era: g.eraCfg?.id);
      case Trade.dec:
        // A suerte: empapelar o pintar, con el papel o el color también al azar.
        final pick = DecoPick.forWork(r, g.eraCfg?.id);
        board = pick.paper
            ? WallpaperBoard(progress: frac, onWork: work, pattern: pick.pattern!, strips: p.m2 >= 110 ? 8 : 6)
            : RollerBoard(progress: frac, onWork: work, paint: pick.paint!, strips: p.m2 >= 110 ? 7 : 5);
    }

    final landscape = Lay.landscape(context);
    final mq = MediaQuery.of(context);

    // Cabecera con energía (el minijuego es a pantalla completa y solo conserva el efectivo).
    final header = Padding(
      padding: EdgeInsets.fromLTRB(16 + (landscape ? mq.padding.left : 0), 6, 16, 6),
      child: Row(children: [
        SqButton(Icons.chevron_left_rounded, tooltip: 'Atrás', onTap: _close),
        const SizedBox(width: 12),
        Text('Obra', style: Ht.title),
        const SizedBox(width: 10),
        Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: Text(money(g.cash), style: Ht.numS.copyWith(color: Hc.acc)))),
        if (landscape) ...[
          const SizedBox(width: 12),
          Expanded(flex: 3, child: _tabs(r, trade)),
        ] else
          const Spacer(),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => _noEnergy(context, g),
          child: Panel(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
            radius: 10,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Cap('Energía'),
              const SizedBox(width: 8),
              SizedBox(width: 50, child: Meter(g.energy / Game.maxEnergy, color: Hc.info)),
              const SizedBox(width: 8),
              Text('${g.energy.floor()}', style: Ht.numS.copyWith(fontSize: 15, color: Hc.info)),
            ]),
          ),
        ),
      ]),
    );

    // Progreso de la fase.
    final progress = Panel(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(ti(trade).phase, style: Ht.h2),
          const Spacer(),
          Flexible(child: Cap('${g.addressOf(p)} · nv. ${r.levels[trade]}')),
        ]),
        const SizedBox(height: 10),
        Meter(frac, color: done ? Hc.ok : Hc.acc, large: true),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: Text(done ? 'Fase terminada' : ti(trade).hint, style: Ht.small.copyWith(color: Hc.ink.withValues(alpha: 0.85)))),
          Text('${intg(r.done[trade] ?? 0)} / ${intg(r.work[trade] ?? 0)}', style: Ht.numS.copyWith(fontSize: 18)),
        ]),
      ]),
    );

    // Tablero con críticos y números flotantes.
    Widget boardStack(double? height) => Stack(clipBehavior: Clip.none, children: [
          BoardFrame(height: height, child: KeyedSubtree(key: _boardKey, child: board)),
          if (done)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(color: const Color(0xB30A1A19), borderRadius: BorderRadius.circular(14)),
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.check_circle_rounded, color: Hc.ok, size: 48),
                    const SizedBox(height: 8),
                    Text('${ti(trade).phase} lista', style: Ht.h2),
                    if (r.current != null) ...[
                      const SizedBox(height: 12),
                      HsButton('Siguiente: ${ti(r.current!).phase}', size: BtnSize.sm, onTap: () => setState(() => _trade = r.current)),
                    ],
                  ]),
                ),
              ),
            ),
          if (_crit != null && !done)
            Positioned(
              left: 10 + _crit!.dx,
              top: 10 + _crit!.dy,
              child: CritSpot(
                key: ValueKey(_crit),
                onHit: () {
                  final at = _crit!;
                  g.consumeCrit();
                  setState(() => _crit = null);
                  _work(g, p, trade, at + const Offset(32, 32), crit: true);
                },
                onMiss: () {
                  g.consumeCrit();
                  if (mounted) setState(() => _crit = null);
                },
              ),
            ),
          for (final pop in _pops)
            Positioned(
              key: ValueKey(pop.id),
              left: pop.at.dx - 10,
              top: pop.at.dy - 20,
              child: IgnorePointer(
                child: PopNum(pop.text, color: pop.color, size: 26, onDone: () {
                  if (mounted) setState(() => _pops.removeWhere((x) => x.id == pop.id));
                }),
              ),
            ),
        ]);

    final hint = switch (trade) {
      Trade.ele => 'Conecta los cables en orden: primero el 1, luego el 2… cada uno con el borne de su número',
      Trade.dec => DecoPick.forWork(r, g.eraCfg?.id).paper
          ? 'Toca la tira para bajarla y luego alisa sus burbujas'
          : 'Cada toque es una pasada de rodillo. Sin prisas: tocar a lo loco suelta chorretones',
      Trade.car => 'Toca el hueco para colocar cada pieza y después sus uniones, una a una',
      _ => null,
    };

    final extras = <Widget>[
      Row(children: [
        Expanded(
          child: Panel(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                const Cap('Combo'),
                const Spacer(),
                GlowText(mult(g.combo), style: Ht.numS.copyWith(fontSize: 21), color: g.combo > 1.5 ? Hc.bad : Hc.acc),
              ]),
              const SizedBox(height: 6),
              Meter(g.combo - 1, color: Hc.bad),
              const SizedBox(height: 6),
              Text('Máx. ×2,0 · pausa máx. 1,5 s', style: Ht.small.copyWith(fontSize: 10.5)),
            ]),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Panel(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Cap('Potencia'),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text('${dec(power, power % 1 == 0 ? 0 : 1)} /toque',
                    style: Ht.numM.copyWith(color: Hc.info, fontSize: 23)),
              ),
              const SizedBox(height: 4),
              Text('Herramienta nv. ${g.toolLv[trade]}', style: Ht.small.copyWith(fontSize: 10.5)),
            ]),
          ),
        ),
      ]),
      if (crewRate > 0) ...[
        const SizedBox(height: 10),
        Note('${dec(crewRate, 1)} toques/s de cuadrillas en esta fase.', bold: 'Cuadrillas trabajando.', icon: Icons.groups_outlined, kind: NoteKind.ok),
      ],
      if (g.workBoost) ...[
        const SizedBox(height: 10),
        const Note('Velocidad de obra ×2 durante el impulso.', bold: 'Impulso activo.', icon: Icons.bolt_rounded, kind: NoteKind.warn),
      ],
      const SizedBox(height: 14),
      HsButton('Mejorar herramienta', kind: BtnKind.info, block: true, price: money(g.toolCost(g.toolLv[trade]! + 1)), onTap: () {
        final e = g.upgradeTool(trade);
        if (e != null) {
          toast(context, e, error: true);
        } else {
          toast(context, 'Herramienta nv. ${g.toolLv[trade]}: potencia ${1 + g.toolLv[trade]!}');
        }
      }),
      const SizedBox(height: 8),
      Text(
        trade == Trade.ele ? 'La electricidad no admite cierre parcial. Un cable mal puesto da chispazo: pierdes el combo y algo de energía.' : 'Cada 20-30 toques aparece un punto crítico.',
        textAlign: TextAlign.center,
        style: Ht.small,
      ),
      const SizedBox(height: 8),
      Center(
        child: HsButton('Cerrar obra a medias', kind: BtnKind.ghost, size: BtnSize.sm, onTap: () => showClosePartial(context, g, p)),
      ),
    ];

    if (landscape) {
      // Horizontal: tablero grande a la izquierda y el resto en una columna a la derecha.
      return Screen(
        kind: ScreenKind.full,
        child: Column(children: [
          header,
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16 + mq.padding.left, 4, 16 + mq.padding.right, 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(flex: 3, child: boardStack(null)),
                const SizedBox(width: 14),
                Expanded(
                  flex: 2,
                  child: ListView(padding: EdgeInsets.zero, children: [
                    progress,
                    if (hint != null && !done) ...[const SizedBox(height: 10), Note(hint, icon: Icons.touch_app_outlined)],
                    const SizedBox(height: 12),
                    ...extras,
                  ]),
                ),
              ]),
            ),
          ),
        ]),
      );
    }

    return Screen(
      kind: ScreenKind.full,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(children: [
            header,
            Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 4), child: _tabs(r, trade)),
            Expanded(
              child: LayoutBuilder(builder: (context, c) {
                final boardH = (c.maxWidth * 0.82).clamp(270.0, math.max(270.0, math.min(460.0, c.maxHeight * 0.58))).toDouble();
                return ListView(padding: const EdgeInsets.fromLTRB(16, 10, 16, 16), children: [
                  progress,
                  const SizedBox(height: 14),
                  if (hint != null && !done)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Note(hint, icon: Icons.touch_app_outlined),
                    ),
                  boardStack(boardH),
                  const SizedBox(height: 14),
                  ...extras,
                ]);
              }),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _tabs(Reno r, Trade trade) => Row(children: [
        for (final x in Trade.values) ...[
          if (x != Trade.alb) const SizedBox(width: 7),
          Expanded(
            child: _PhaseTab(
              trade: x,
              r: r,
              selected: x == trade,
              onTap: () => setState(() {
                _trade = x;
                _crit = null;
              }),
            ),
          ),
        ],
      ]);
}

class _PhaseTab extends StatelessWidget {
  final Trade trade;
  final Reno r;
  final bool selected;
  final VoidCallback onTap;
  const _PhaseTab({required this.trade, required this.r, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    // Sin trabajo en esta obra (el oficio ya estaba a ese nivel o no se sube): tachado.
    final skipped = !r.has(trade);
    final done = !skipped && r.frac(trade) >= 1;
    Color bg = Hc.panelIn;
    Color fg = Hc.dim;
    List<BoxShadow> sh = const [BoxShadow(color: Hc.line, offset: Offset(0, 4))];
    Gradient? grad;
    if (done) {
      bg = const Color(0xFF1D4B3B);
      fg = Hc.ok;
    } else if (!skipped) {
      fg = Hc.mut;
    }
    if (selected && !skipped) {
      grad = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Hc.accHi, Hc.accDeep]);
      fg = Hc.onAcc;
      sh = He.pop;
    }
    Widget pill = Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        color: bg,
        gradient: grad,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Hc.line, width: 2),
        boxShadow: sh,
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(ti(trade).code,
            style: TextStyle(
              fontFamily: Hf.body,
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 1.1,
              color: fg,
              decoration: skipped ? TextDecoration.lineThrough : null,
            )),
        if (done) ...[const SizedBox(width: 3), Icon(Icons.check_rounded, size: 12, color: fg)],
      ]),
    );
    if (selected && !skipped) pill = Pose.up(child: pill);
    return GestureDetector(onTap: skipped ? null : onTap, child: pill);
  }
}

/// Sin energía: esperar, anuncio opcional o cuadrillas.
class EnergySheet extends StatelessWidget {
  final Game g;
  const EnergySheet({super.key, required this.g});
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: g,
      builder: (context, _) {
        final left = ((Game.maxEnergy - g.energy) / Game.energyRegen / g.speed).clamp(0, 1e9).round();
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Ring(g.energy / Game.maxEnergy, size: 64, color: Hc.info, child: Text('${g.energy.floor()}', style: Ht.numS)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Sin energía', style: Ht.title),
                const SizedBox(height: 2),
                Text('Recuperas 1 punto cada 2 s de juego. Llena en ${dur(Duration(seconds: left))}.', style: Ht.small),
              ]),
            ),
          ]),
          const SizedBox(height: 6),
          const Quote(Tx.sinEnergia),
          const SizedBox(height: 12),
          ListBlock([
              Li(
                lead: const IconBox(Icons.hourglass_bottom_rounded),
                title: 'Esperar',
                sub: 'La energía vuelve sola. Sin trampa.',
                trail: HsButton('Vale', size: BtnSize.xs, kind: BtnKind.sec, onTap: () => Navigator.pop(context)),
              ),
              Li(
                lead: const IconBox(Icons.play_circle_outline, color: Hc.acc),
                title: 'Anuncio opcional',
                sub: 'Energía llena al momento.',
                trail: HsButton('Ver', size: BtnSize.xs, onTap: () async {
                  final ok = await showAdPlaceholder(context);
                  if (ok) {
                    g.refillEnergy();
                    if (context.mounted) Navigator.pop(context);
                  }
                }),
              ),
              Li(
                last: true,
                lead: const IconBox(Icons.groups_outlined, color: Hc.info),
                title: 'Cuadrillas',
                sub: g.hasCrews ? 'Trabajan sin gastar tu energía.' : 'Llegan con la Empresa de reformas (3 reformas).',
              ),
            ]),
        ]);
      },
    );
  }
}

/// Anuncio bonificado (opcional). Pro y admin reciben la recompensa sin anuncio.
/// En la web, o si la red no tiene anuncio, se usa el de prueba solo en la web.
Future<bool> showAdPlaceholder(BuildContext context) async {
  if (Entitlements.instance.sinAnuncios) return true;
  final real = await Anuncios.recompensa();
  if (real != null) return real;
  if (!kIsWeb) {
    if (context.mounted) toast(context, 'Ahora mismo no hay anuncios. Prueba en un rato.', error: true);
    return false;
  }
  if (!context.mounted) return false;
  final r = await showHsDialog<bool>(context, dismissible: false, builder: (ctx) => const _AdCountdown());
  return r ?? false;
}

class _AdCountdown extends StatefulWidget {
  const _AdCountdown();
  @override
  State<_AdCountdown> createState() => _AdCountdownState();
}

class _AdCountdownState extends State<_AdCountdown> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 5))..forward();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        const Cap('Anuncio de prueba'),
        const SizedBox(height: 10),
        Container(
          height: 160,
          decoration: BoxDecoration(color: Hc.panelIn, borderRadius: BorderRadius.circular(12), border: Border.all(color: Hc.line, width: 2)),
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.campaign_outlined, color: Hc.mut, size: 40),
              const SizedBox(height: 6),
              Text('Aquí irá el anuncio bonificado', style: Ht.small),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        Meter(_c.value, color: Hc.acc),
        const SizedBox(height: 12),
        HsButton(_c.isCompleted ? 'Recoger recompensa' : 'Espera ${(5 - _c.value * 5).ceil()} s',
            block: true, onTap: _c.isCompleted ? () => Navigator.pop(context, true) : null),
        const SizedBox(height: 8),
        HsButton('Cancelar', kind: BtnKind.ghost, block: true, onTap: () => Navigator.pop(context, false)),
      ]),
    );
  }
}
