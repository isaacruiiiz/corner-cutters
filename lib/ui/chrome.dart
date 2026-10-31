import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../core/format.dart';
import '../core/gfx.dart';
import '../core/theme.dart';
import '../game/data.dart';
import '../game/engine.dart';
import '../services/audio.dart';
import 'common.dart';
import 'screens/portfolio.dart';
import 'widgets/atoms.dart';

import '../core/texto.dart';
import '../core/i18n.dart';
/// Medidas de las capas fijas (referencia 390 × 844, respetando SafeArea).
/// En horizontal (móvil tumbado) la barra pasa a ser un raíl vertical a la izquierda; en pantallas
/// anchas (tablet) los paneles se centran con un ancho máximo y las hojas van a la derecha.
class Lay {
  static const tickerH = 36.0;
  static const navH = 58.0;
  static const railW = 66.0;

  /// Móvil en horizontal: poca altura, barra lateral.
  static bool landscape(BuildContext c) {
    final s = MediaQuery.of(c).size;
    return s.width > s.height && s.height < 600;
  }

  static bool wide(BuildContext c) => MediaQuery.of(c).size.width >= 600;

  /// Margen izquierdo de todo lo que no es la barra.
  static double left(BuildContext c) {
    final mq = MediaQuery.of(c);
    return landscape(c) ? mq.padding.left + 12 + railW + 10 : 12 + mq.padding.left;
  }

  static double right(BuildContext c) => 12 + MediaQuery.of(c).padding.right;

  /// Ancho máximo del HUD (ticker y fecha) para que no quede estirado en tablet.
  static double hudW(BuildContext c) {
    final w = MediaQuery.of(c).size.width - left(c) - right(c);
    return math.min(w, landscape(c) ? 560 : 640);
  }

  /// Márgenes horizontales de un panel o una hoja con ancho máximo [max], centrado (o a la derecha).
  static (double, double) hInsets(BuildContext c, double max, {bool alignRight = false}) {
    final w = MediaQuery.of(c).size.width;
    final l = left(c), r = right(c);
    final avail = w - l - r;
    if (avail <= max) return (l, r);
    if (alignRight) return (w - r - max, r);
    final extra = (avail - max) / 2;
    return (l + extra, r + extra);
  }

  static double tickerTop(BuildContext c) => MediaQuery.of(c).padding.top + 6;
  static double panelTop(BuildContext c) => tickerTop(c) + tickerH + 10;
  static double dateTop(BuildContext c) => tickerTop(c) + tickerH + 6;
  static double railTop(BuildContext c) => dateTop(c) + 28 + 12;
  static double navBottom(BuildContext c) {
    final b = MediaQuery.of(c).padding.bottom;
    return b > 0 ? math.max(20, b - 2) : 26;
  }

  static double panelBottom(BuildContext c) => landscape(c) ? MediaQuery.of(c).padding.bottom + 12 : navBottom(c) + navH + 12;
  static double sheetBottom(BuildContext c) => landscape(c) ? MediaQuery.of(c).padding.bottom + 10 : navBottom(c) + navH + 10;
  static double pillBottom(BuildContext c) => landscape(c) ? MediaQuery.of(c).padding.bottom + 10 : navBottom(c) + navH + 8;
}

/// Velo tras paneles y diálogos: mapa oscurecido y desenfocado.
class Veil extends StatelessWidget {
  const Veil({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<GfxLevel>(
        valueListenable: Gfx.level,
        builder: (context, lv, _) => Gfx.liveBlur
            ? ClipRect(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: Hg.veilBlur, sigmaY: Hg.veilBlur),
                  child: const ColoredBox(color: Hg.veil, child: SizedBox.expand()),
                ),
              )
            : const ColoredBox(color: Color(0xB8061010), child: SizedBox.expand()),
      );
}

/// Panel de pestaña (izq./der. 12, radio 18, fondo .94).
class GlassPanel extends StatelessWidget {
  final Widget child;
  const GlassPanel({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(Hr.panel);
    return Container(
      decoration: BoxDecoration(
        color: Hg.panel,
        borderRadius: r,
        border: Border.all(color: Hc.line, width: 2),
        boxShadow: He.e1,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Hr.panel - 2),
        child: CustomPaint(
          foregroundPainter: const HilitePainter(Hr.panel),
          child: Material(type: MaterialType.transparency, child: child),
        ),
      ),
    );
  }
}

/// Hoja flotante (izq./der. 12, radio 20, asa de 38 × 4).
class GlassSheet extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const GlassSheet({super.key, required this.child, this.padding = const EdgeInsets.fromLTRB(14, 18, 14, 14)});
  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(Hr.sheet);
    return Container(
      decoration: BoxDecoration(
        color: Hg.sheet,
        borderRadius: r,
        border: Border.all(color: Hc.line, width: 2),
        boxShadow: He.e1,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Hr.sheet - 2),
        child: Stack(fit: StackFit.passthrough, children: [
          Padding(padding: padding, child: Material(type: MaterialType.transparency, child: child)),
          Positioned(
            top: 6,
            left: 0,
            right: 0,
            child: Center(
              child: Container(width: 38, height: 4, decoration: BoxDecoration(color: Hc.lineSoft, borderRadius: BorderRadius.circular(2))),
            ),
          ),
          const Hilite(radius: Hr.sheet),
        ]),
      ),
    );
  }
}

/// Ticker superior: efectivo · patrimonio · multiplicador · cuenta atrás de fase.
class TickerHud extends ConsumerWidget {
  const TickerHud({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = ref.watch(gameProvider);
    if (!g.loaded) return const SizedBox();
    final ph = mph(g.phase);
    Widget item(IconData i, Color ic, Widget t) => Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(i, size: 15, color: ic),
          const SizedBox(width: 4),
          t,
        ]);
    final num = Ht.numS;
    // Con letra grande o pantalla estrecha se ocultan primero «Patr.» y el multiplicador
    // (siguen en Mercado) y lo que quede se encoge antes de cortarse.
    final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
    final narrow = Lay.hudW(context) < 360 || scale > 1.15;
    return Pressable(
      depth: 2,
      onTap: () => push(context, const PortfolioScreen()),
      child: GlassBox(
        height: Lay.tickerH,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: LayoutBuilder(
          builder: (context, cons) => FittedBox(
            fit: BoxFit.scaleDown,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: cons.maxWidth),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                item(Icons.monetization_on_outlined, Hc.acc,
                    CountUp(g.cash, (v) => Text(money(v, compact: narrow && v.abs() >= 1e6), style: num.copyWith(color: v < 0 ? Hc.bad : Hc.acc)))),
                const SizedBox(width: 10),
                if (!narrow)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('Patr. ', style: Ht.small.copyWith(fontSize: 11.5, fontWeight: FontWeight.w700)),
                    CountUp(g.netWorth, (v) => Text(money(v, compact: v >= 1e7), style: num)),
                  ]),
                if (!narrow) const SizedBox(width: 10),
                if (!narrow) item(Icons.show_chart_rounded, Hc.warn, Text(mult(g.m), style: num.copyWith(color: Hc.warn))),
                if (!narrow) const SizedBox(width: 10),
                item(g.inCrisis ? Icons.trending_down_rounded : Icons.schedule_rounded, ph.color, Text(dur(g.phaseLeft), style: num.copyWith(color: ph.color))),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Cifra que se anima hasta su nuevo valor (y da un pequeño salto al subir).
class CountUp extends StatefulWidget {
  final double value;
  final Widget Function(double) builder;
  const CountUp(this.value, this.builder, {super.key});
  @override
  State<CountUp> createState() => _CountUpState();
}

class _CountUpState extends State<CountUp> {
  late double _from = widget.value;
  int _bumps = 0;
  @override
  void didUpdateWidget(CountUp old) {
    super.didUpdateWidget(old);
    // Saltos grandes (cobros, ventas) se animan; el goteo continuo no.
    if ((widget.value - old.value).abs() >= 1000) {
      _from = old.value;
      if (widget.value > old.value) _bumps++;
    } else {
      _from = widget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (Motion.off(context)) return widget.builder(widget.value);
    return TweenAnimationBuilder<double>(
      key: ValueKey(_bumps),
      tween: Tween(begin: _from, end: widget.value),
      duration: Duration(milliseconds: _from == widget.value ? 1 : 650),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) {
        final t = _from == widget.value ? 1.0 : ((v - _from) / (widget.value - _from)).clamp(0.0, 1.0);
        final s = 1 + 0.12 * math.sin(t * math.pi);
        return Transform.scale(scale: s, child: widget.builder(v));
      },
    );
  }
}

/// Fila de calendario (fecha + avance del mes hasta el cobro) y selector de velocidad.
class DateSpeedRow extends ConsumerWidget {
  const DateSpeedRow({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = ref.watch(gameProvider);
    return Row(children: [
      Flexible(
        child: GlassBox(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(g.dateLabel, style: Ht.small.copyWith(fontSize: 11, fontWeight: FontWeight.w700, height: 1)),
          const SizedBox(width: 8),
          SizedBox(
            width: 44,
            height: 6,
            child: DecoratedBox(
              decoration: BoxDecoration(color: Hc.bgDeep, borderRadius: BorderRadius.circular(3), border: Border.all(color: Hc.line, width: 1)),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: g.monthProgress,
                child: const ColoredBox(color: Hc.acc),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('cobro ${dur(g.nextRentIn)}', style: Ht.small.copyWith(fontSize: 11, fontWeight: FontWeight.w700, color: Hc.ok, height: 1)),
        ])),
      ),
      ),
      const SizedBox(width: 8),
      GlassBox(
        height: 28,
        padding: const EdgeInsets.all(2),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (final v in const [1.0, 2.0, 4.0])
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.selectionClick();
                g.setSpeed(v);
              },
              child: Container(
                width: 30,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: g.speed == v ? Hc.acc : null, borderRadius: BorderRadius.circular(8)),
                child: Text('×${v.round()}', style: Ht.numS.copyWith(fontSize: 19, height: 1, color: g.speed == v ? Hc.onAcc : Hc.mut)),
              ),
            ),
        ]),
      ),
    ]);
  }
}

/// Barra de navegación de cristal (5 pestañas). En horizontal, raíl vertical a la izquierda.
class GlassNav extends ConsumerWidget {
  const GlassNav({super.key});

  static const items = [
    (Icons.place_outlined, 'Mapa'),
    (Icons.construction_outlined, 'Obras'),
    (Icons.apartment_outlined, 'Empresa'),
    (Icons.show_chart_rounded, 'Mercado'),
    (Icons.more_horiz_rounded, 'Más'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = ref.watch(gameProvider);
    final index = ref.watch(tabProvider);
    if (!g.loaded) return const SizedBox();
    final claim = g.missions.where((m) => m.done && !m.claimed).length;
    final badges = [g.events.length + g.offers.length, g.activeRenos, 0, 0, claim];
    final vertical = Lay.landscape(context);
    Widget item(int i) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.selectionClick();
            Sfx.play('pestana');
            final nav = Navigator.of(context);
            if (nav.canPop()) nav.popUntil((r) => r.isFirst);
            ref.read(tabProvider.notifier).state = i;
          },
          child: Semantics(
            button: true,
            selected: i == index,
            label: tr(items[i].$2),
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Icono con el multiplicador (Mercado) o el contador pegados a su esquina.
                Stack(clipBehavior: Clip.none, children: [
                  Icon(items[i].$1, size: 22, color: i == index ? Hc.acc : Hc.mut),
                  if (i == 3)
                    Positioned(
                      left: 17,
                      top: -7,
                      child: Text(mult(g.m), style: Ht.numS.copyWith(fontSize: 14, color: Hc.warn, height: 1)),
                    ),
                  if (badges[i] > 0)
                    Positioned(
                      left: 16,
                      top: -7,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 15),
                        height: 15,
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Hc.bad,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Hc.line, width: 1.5),
                        ),
                        child: Text('${badges[i]}', style: const TextStyle(fontFamily: Hf.display, fontSize: 12, color: Color(0xFF2A0B07), height: 1)),
                      ),
                    ),
                ]),
                const SizedBox(height: 4),
                // Siempre en una línea: si no cabe, se encoge (nunca «MERCAD/O»).
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(items[i].$2.toUpperCase(),
                        maxLines: 1,
                        softWrap: false,
                        textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.2),
                        style: TextStyle(
                            fontFamily: Hf.body,
                            fontWeight: FontWeight.w700,
                            fontSize: 9.5,
                            letterSpacing: 0.8,
                            height: 1.1,
                            color: i == index ? Hc.acc : Hc.mut)),
                  ),
                ),
              ]),
            ),
          ),
        );
    if (vertical) {
      return GlassBox(
        width: Lay.railW,
        child: Column(children: [for (var i = 0; i < items.length; i++) Expanded(child: item(i))]),
      );
    }
    return GlassBox(
      height: Lay.navH,
      child: Row(children: [for (var i = 0; i < items.length; i++) Expanded(child: item(i))]),
    );
  }
}

/// HUD + barra fijos, colocados sobre cualquier contenido.
class Chrome extends StatelessWidget {
  const Chrome({super.key});
  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final land = Lay.landscape(context);
    return Stack(children: [
      Positioned(left: Lay.left(context), top: Lay.tickerTop(context), width: Lay.hudW(context), child: const TickerHud()),
      if (land)
        Positioned(left: mq.padding.left + 12, top: Lay.tickerTop(context), bottom: mq.padding.bottom + 12, child: const GlassNav())
      else
        Positioned(
          left: Lay.hInsets(context, 640).$1,
          right: Lay.hInsets(context, 640).$2,
          bottom: Lay.navBottom(context),
          child: const GlassNav(),
        ),
    ]);
  }
}

/// Formato del tiempo que falta para algo medido en reloj de juego.
String gameLeft(Game g, int atClock) => dur(Duration(milliseconds: ((atClock - g.clock) / g.speed).round()));
