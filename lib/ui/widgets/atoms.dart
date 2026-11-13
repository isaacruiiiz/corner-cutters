import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../../core/gfx.dart';
import '../../core/theme.dart';

import '../../core/texto.dart';
import '../../core/i18n.dart';
// =====================================================================
// Superficies
// =====================================================================
enum PanelKind { normal, inset, hi, glass, pop, paper }

/// Filo interior superior de 1 px (rgba(255,236,190,.08)) que lleva toda superficie.
/// Se pinta por encima sin alterar el tamaño ni la alineación del contenido.
class HilitePainter extends CustomPainter {
  final double radius;
  const HilitePainter([this.radius = Hr.tile]);
  @override
  void paint(Canvas canvas, Size size) {
    final inset = radius * 0.6;
    if (size.width <= inset * 2) return;
    canvas.drawRect(Rect.fromLTWH(inset, 0, size.width - inset * 2, 1), Paint()..color = Hg.hilite);
  }

  @override
  bool shouldRepaint(HilitePainter o) => o.radius != radius;
}

/// Compatibilidad: filo como widget posicionado dentro de un Stack.
class Hilite extends StatelessWidget {
  final double radius;
  const Hilite({super.key, this.radius = Hr.tile});
  @override
  Widget build(BuildContext context) => Positioned(
        top: 0,
        left: radius * 0.6,
        right: radius * 0.6,
        height: 1,
        child: const IgnorePointer(child: ColoredBox(color: Hg.hilite)),
      );
}

/// Cristal: fondo translúcido + desenfoque + borde de 2 px + sombra dura (HUD, raíl, píldoras, paneles).
class GlassBox extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color color;
  final double blur;
  final double? width, height;
  final Color borderColor;
  final List<BoxShadow> shadow;
  const GlassBox({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.radius = Hr.hud,
    this.color = Hg.hud,
    this.blur = Hg.blur,
    this.width,
    this.height,
    this.borderColor = Hc.line,
    this.shadow = He.e1,
  });
  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(borderRadius: r, boxShadow: shadow),
      child: ClipRRect(
        borderRadius: r,
        child: ValueListenableBuilder<GfxLevel>(
          valueListenable: Gfx.level,
          builder: (context, lv, _) {
            final body = Container(
              // Sin desenfoque en vivo (calidad media o baja), el cristal es casi opaco.
              decoration: BoxDecoration(
                  color: Gfx.liveBlur ? color : Color.alphaBlend(color.withValues(alpha: 0.93), Hc.bgDeep),
                  borderRadius: r,
                  border: Border.all(color: borderColor, width: 2)),
              child: CustomPaint(
                foregroundPainter: HilitePainter(radius),
                child: Padding(
                  padding: padding,
                  // Con alto fijo, el contenido queda centrado en vertical.
                  child: height != null ? Align(alignment: Alignment.centerLeft, widthFactor: 1, child: child) : child,
                ),
              ),
            );
            if (!Gfx.liveBlur) return body;
            return BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur), child: body);
          },
        ),
      ),
    );
  }
}


/// Superficie con contorno de 2 px, sombra dura y filo interior.
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final PanelKind kind;
  final double radius;
  final VoidCallback? onTap;
  final bool frame;
  final Color? color;
  final Color? borderColor;
  final double? width;
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.kind = PanelKind.normal,
    this.radius = Hr.tile,
    this.onTap,
    this.frame = false,
    this.color,
    this.borderColor,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    if (kind == PanelKind.glass) {
      final g = GlassBox(padding: padding, radius: radius, width: width, borderColor: borderColor ?? Hc.line, child: child);
      return onTap != null ? Pressable(onTap: onTap!, depth: 2, child: g) : g;
    }
    Color bg;
    List<BoxShadow> sh = He.e1;
    Gradient? grad;
    var fg = Hc.ink;
    switch (kind) {
      case PanelKind.normal:
      case PanelKind.glass:
        bg = Hc.panelIn;
      case PanelKind.inset:
        bg = Hc.bgDeep;
        sh = const [];
      case PanelKind.hi:
        bg = Hc.panel;
      case PanelKind.pop:
        bg = Hc.accHi;
        grad = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Hc.accHi, Hc.acc]);
        sh = He.pop;
        fg = Hc.onAcc;
      case PanelKind.paper:
        bg = Hc.paper;
        fg = Hc.onAcc;
    }
    Widget box = Container(
      width: width,
      decoration: BoxDecoration(
        color: color ?? bg,
        gradient: color == null ? grad : null,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? (frame ? Hc.acc : Hc.line), width: 2),
        boxShadow: sh,
      ),
      child: CustomPaint(
        foregroundPainter: kind != PanelKind.inset ? HilitePainter(radius) : null,
        child: Padding(
          padding: padding,
          child: DefaultTextStyle.merge(style: TextStyle(color: fg), child: child),
        ),
      ),
    );
    if (onTap != null) return Pressable(onTap: onTap!, depth: 2, child: box);
    return box;
  }
}


/// Envoltorio que hunde 3 px al pulsar.
/// Preferencia global de movimiento (se sincroniza con Ajustes > Reducir movimiento).
class Motion {
  static bool reduced = false;
  static bool off(BuildContext c) => reduced || MediaQuery.maybeOf(c)?.disableAnimations == true;
}

/// Aparece con un pequeño rebote de escala (pins, insignias). Una vez por clave.
class PopIn extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final Alignment alignment;
  const PopIn({super.key, required this.child, this.duration = const Duration(milliseconds: 420), this.alignment = Alignment.bottomCenter});
  @override
  Widget build(BuildContext context) {
    if (Motion.off(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: Curves.elasticOut,
      builder: (_, v, c) => Transform.scale(scale: 0.4 + 0.6 * v, alignment: alignment, child: c),
      child: child,
    );
  }
}

/// Sacudida horizontal que se dispara cada vez que cambia [trigger].
class Shake extends StatelessWidget {
  final Object? trigger;
  final Widget child;
  final double amount;
  const Shake({super.key, required this.trigger, required this.child, this.amount = 7});
  @override
  Widget build(BuildContext context) {
    if (Motion.off(context) || trigger == null) return child;
    return TweenAnimationBuilder<double>(
      key: ValueKey(trigger),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      builder: (_, v, c) => Transform.translate(offset: Offset(math.sin(v * math.pi * 6) * amount * (1 - v), 0), child: c),
      child: child,
    );
  }
}

class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double depth;
  final bool haptic;
  const Pressable({super.key, required this.child, this.onTap, this.onLongPress, this.depth = 3, this.haptic = true});
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      onTapUp: enabled ? (_) => setState(() => _down = false) : null,
      onTap: enabled
          ? () {
              if (widget.haptic) HapticFeedback.selectionClick();
              widget.onTap!();
            }
          : null,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _down && !Motion.off(context) ? 0.97 : 1,
        duration: Duration(milliseconds: _down ? 70 : 160),
        curve: _down ? Curves.easeOut : Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          transform: Matrix4.translationValues(0, _down ? widget.depth : 0, 0),
          child: widget.child,
        ),
      ),
    );
  }
}

// =====================================================================
// Botones
// =====================================================================
enum BtnKind { primary, sec, info, bad, ok, ghost }

enum BtnSize { lg, md, sm, xs }

class HsButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final BtnKind kind;
  final BtnSize size;
  final IconData? icon;
  final String? price;
  final bool block;
  final bool loading;
  const HsButton(
    this.label, {
    super.key,
    this.onTap,
    this.kind = BtnKind.primary,
    this.size = BtnSize.md,
    this.icon,
    this.price,
    this.block = false,
    this.loading = false,
  });
  @override
  State<HsButton> createState() => _HsButtonState();
}

class _HsButtonState extends State<HsButton> {
  bool _down = false;
  int _shakes = 0;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onTap == null;
    // Alto 40 (compacto 34); padding horizontal 18 (compacto 14).
    final compact = widget.size == BtnSize.sm || widget.size == BtnSize.xs;
    final h = switch (widget.size) { BtnSize.lg => 44.0, BtnSize.md => 40.0, BtnSize.sm => 34.0, BtnSize.xs => 30.0 };
    final padH = compact ? 14.0 : 18.0;
    final fs = widget.size == BtnSize.xs ? 11.0 : 12.0;
    Color fg;
    Gradient? grad;
    Color? bg;
    Color border = Hc.line;
    Color? shadow;
    var dashed = false;
    var shine = false;
    switch (widget.kind) {
      case BtnKind.primary:
        grad = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Hc.accHi, Hc.acc]);
        fg = Hc.onAcc;
        shadow = Hc.accLo;
        shine = true;
      case BtnKind.ok:
        grad = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Hc.okHi, Hc.ok]);
        fg = const Color(0xFF07271A);
        shadow = Hc.okLo;
        shine = true;
      case BtnKind.bad:
        grad = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFF0857A), Hc.bad]);
        fg = const Color(0xFF1A0705);
        shadow = const Color(0xFF6C2018);
        shine = true;
      case BtnKind.info:
        bg = Hc.panel;
        fg = Hc.info;
        shadow = Hc.line;
      case BtnKind.sec:
        bg = Hc.panel;
        fg = Hc.ink;
        shadow = Hc.line;
      case BtnKind.ghost:
        bg = Colors.transparent;
        fg = Hc.mut;
        border = Colors.transparent;
    }
    if (disabled) {
      grad = null;
      bg = Hc.panelIn;
      fg = Hc.dim;
      border = Hc.lineSoft;
      shadow = null;
      dashed = true;
      shine = false;
    }
    final down = _down && !disabled;
    final content = Row(
      mainAxisSize: widget.block ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.loading)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2.5, color: fg)),
          )
        else if (widget.icon != null)
          Padding(padding: const EdgeInsets.only(right: 7), child: Icon(widget.icon, size: fs + 4, color: fg)),
        Flexible(
          child: Text(
            widget.label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Ht.btn.copyWith(fontSize: fs, color: fg, height: 1.1),
          ),
        ),
        if (widget.price != null) ...[
          const SizedBox(width: 8),
          Text(widget.price!, style: TextStyle(fontFamily: Hf.display, fontSize: compact ? 19 : 22, color: fg, height: 1,
              fontFeatures: const [FontFeature.tabularFigures()])),
        ],
      ],
    );
    final r = BorderRadius.circular(Hr.btn);
    Widget box = AnimatedContainer(
      duration: const Duration(milliseconds: 80),
      height: h,
      transform: Matrix4.translationValues(0, down ? 2 : 0, 0),
      padding: EdgeInsets.symmetric(horizontal: padH),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        gradient: grad,
        borderRadius: r,
        border: dashed ? null : Border.all(color: border, width: 2),
        boxShadow: shadow == null ? null : [BoxShadow(color: shadow, offset: Offset(0, down ? 1 : 3))],
      ),
      foregroundDecoration: shine
          ? BoxDecoration(
              borderRadius: r,
              gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0, 0.07, 0.08],
                  colors: [Color(0x66FFFFFF), Color(0x66FFFFFF), Color(0x00FFFFFF)]),
            )
          : null,
      child: content,
    );
    if (dashed) box = DashedBorder(radius: Hr.btn, color: Hc.lineSoft, child: box);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: disabled ? null : (_) => setState(() => _down = true),
      onTapUp: disabled ? null : (_) => setState(() => _down = false),
      onTapCancel: disabled ? null : () => setState(() => _down = false),
      onTap: widget.loading
          ? null
          : disabled
              // Botón deshabilitado: sacudida corta para indicar que ahora no se puede.
              ? () => setState(() => _shakes++)
              : () {
                  HapticFeedback.lightImpact();
                  widget.onTap!();
                },
      child: Semantics(
        button: true,
        enabled: !disabled,
        label: tr(widget.label),
        child: Shake(
          trigger: _shakes == 0 ? null : _shakes,
          amount: 5,
          child: AnimatedScale(
            scale: down && !Motion.off(context) ? 0.965 : 1,
            duration: Duration(milliseconds: down ? 70 : 180),
            curve: down ? Curves.easeOut : Curves.easeOutBack,
            child: box,
          ),
        ),
      ),
    );
  }
}




/// Botón cuadrado de icono (sq). Con [glass] es un botón del raíl del mapa (40 × 40 de cristal).
class SqButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool on;
  final double size;
  final String? tooltip;
  final int badge;
  final bool glass;
  final bool dot;
  const SqButton(this.icon,
      {super.key, this.onTap, this.on = false, this.size = 40, this.tooltip, this.badge = 0, this.glass = false, this.dot = false});
  @override
  Widget build(BuildContext context) {
    final iconW = Icon(icon, size: size * 0.5, color: on ? (glass ? Hc.acc : Hc.onAcc) : Hc.ink);
    final Widget box = glass
        ? GlassBox(
            width: size,
            height: size,
            radius: Hr.hud,
            borderColor: on ? Hc.acc : Hc.line,
            child: Center(child: iconW),
          )
        : Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              gradient: on
                  ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Hc.accHi, Hc.acc])
                  : null,
              color: on ? null : Hc.panel,
              borderRadius: BorderRadius.circular(Hr.btn),
              border: Border.all(color: Hc.line, width: 2),
              boxShadow: He.e1,
            ),
            child: iconW,
          );
    return Pressable(
      onTap: onTap,
      depth: 2,
      child: Semantics(
        button: true,
        label: tooltip == null ? null : tr(tooltip!),
        child: Stack(clipBehavior: Clip.none, children: [
          box,
          if (badge > 0 && !dot) Positioned(right: -6, top: -6, child: CountBadge(badge)),
          if (dot)
            Positioned(
              right: 5,
              top: 5,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: Hc.bad, shape: BoxShape.circle, border: Border.all(color: Hc.line, width: 1.5)),
              ),
            ),
        ]),
      ),
    );
  }
}


// =====================================================================
// Texto
// =====================================================================
class Cap extends StatelessWidget {
  final String text;
  final Color? color;
  final TextAlign? align;
  const Cap(this.text, {super.key, this.color, this.align});
  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), textAlign: align, style: Ht.cap.copyWith(color: color), maxLines: 1, overflow: TextOverflow.ellipsis);
}

/// Cifra con brillo (glow).
class GlowText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final Color color;
  final TextAlign? align;
  const GlowText(this.text, {super.key, required this.style, this.color = Hc.acc, this.align});
  @override
  Widget build(BuildContext context) => Text(
        text,
        textAlign: align,
        style: style.copyWith(color: color, shadows: [
          const Shadow(color: Hc.line, offset: Offset(0, 3)),
          Shadow(color: color.withValues(alpha: 0.6), blurRadius: 18),
        ]),
      );
}

class Quote extends StatelessWidget {
  final String text;
  final TextAlign align;
  const Quote(this.text, {super.key, this.align = TextAlign.center});
  @override
  Widget build(BuildContext context) => Text(text, textAlign: align, style: Ht.quote);
}

// =====================================================================
// Etiquetas, contadores y chips
// =====================================================================
/// Tag de estado: Manrope w800 9,5, borde 1,5 del color del texto, fondo panelIn, radio 7.
class Tag extends StatelessWidget {
  final String text;
  final Color color;
  final bool fill;
  final IconData? icon;
  const Tag(this.text, {super.key, this.color = Hc.mut, this.fill = false, this.icon});
  @override
  Widget build(BuildContext context) {
    final fg = fill ? Hc.onAcc : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: fill ? color : Hc.panelIn,
        borderRadius: BorderRadius.circular(Hr.tag),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 11, color: fg), const SizedBox(width: 4)],
        Text(text.toUpperCase(),
            style: TextStyle(fontFamily: Hf.body, fontWeight: FontWeight.w800, fontSize: 9.5, letterSpacing: 1, color: fg, height: 1.3)),
      ]),
    );
  }
}


class CountBadge extends StatelessWidget {
  final int n;
  const CountBadge(this.n, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minWidth: 20),
        height: 20,
        padding: const EdgeInsets.symmetric(horizontal: 5),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Hc.bad,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Hc.line, width: 2),
        ),
        child: Text('$n', style: const TextStyle(fontFamily: Hf.display, fontSize: 14, color: Color(0xFF2A0B07), height: 1)),
      );
}

class Dot extends StatelessWidget {
  final Color color;
  final double size;
  const Dot(this.color, {super.key, this.size = 8});
  @override
  Widget build(BuildContext context) =>
      Container(width: size, height: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

/// Chip de filtro: Manrope w700 11, padding 6 × 10, borde 2, radio 10; activo en dorado.
class FChip extends StatelessWidget {
  final String label;
  final bool on;
  final VoidCallback? onTap;
  final int? count;
  final IconData? icon;
  const FChip(this.label, {super.key, this.on = false, this.onTap, this.count, this.icon});
  @override
  Widget build(BuildContext context) {
    final fg = on ? Hc.onAcc : Hc.ink;
    return Pressable(
      onTap: onTap,
      depth: 2,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: on ? Hc.acc : Hc.panelIn,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Hc.line, width: 2),
          boxShadow: [BoxShadow(color: on ? Hc.accLo : const Color(0x80000000), offset: const Offset(0, 2))],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 13, color: fg), const SizedBox(width: 5)],
          Text(label, style: TextStyle(fontFamily: Hf.body, fontWeight: FontWeight.w700, fontSize: 11, color: fg, height: 1.2)),
          if (count != null) ...[
            const SizedBox(width: 5),
            Text('$count', style: TextStyle(fontFamily: Hf.display, fontSize: 15, color: on ? Hc.onAcc : Hc.mut, height: 1)),
          ],
        ]),
      ),
    );
  }
}


/// Dato pequeño con etiqueta (chip vertical).
class DataChip extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  const DataChip(this.label, this.value, {super.key, this.valueColor = Hc.ink});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(10, 5, 10, 6),
        decoration: BoxDecoration(
          color: Hc.panelIn,
          borderRadius: BorderRadius.circular(Hr.btn),
          border: Border.all(color: Hc.line, width: 2),
          boxShadow: He.chip,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Cap(label),
          const SizedBox(height: 2),
          Text(value, style: Ht.numS.copyWith(color: valueColor)),
        ]),
      );
}


// =====================================================================
// Medidores
// =====================================================================
/// Barra de progreso: alto 9, borde 2, fondo bgDeep, radio 5.
class Meter extends StatelessWidget {
  final double value;
  final Color color;
  final bool large;
  final double? marker;
  const Meter(this.value, {super.key, this.color = Hc.acc, this.large = false, this.marker});
  @override
  Widget build(BuildContext context) {
    final h = large ? 14.0 : 9.0;
    final v = value.isNaN ? 0.0 : value.clamp(0.0, 1.0).toDouble();
    // Sin LayoutBuilder: así funciona dentro de IntrinsicHeight (StatGrid).
    return Container(
      height: h,
      decoration: BoxDecoration(
        color: Hc.bgDeep,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Hc.line, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Stack(fit: StackFit.expand, children: [
          TweenAnimationBuilder<double>(
            tween: Tween(end: v),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            builder: (context, f, _) => FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: f.clamp(0.0, 1.0),
              heightFactor: 1,
              child: ColoredBox(color: color),
            ),
          ),
          if (marker != null)
            Align(
              alignment: Alignment(-1 + 2 * marker!.clamp(0.0, 1.0), 0),
              child: Container(width: 2, color: Hc.ink),
            ),
        ]),
      ),
    );
  }
}


/// Barra segmentada: una casilla por paso (alto 7, separación 3).
class SegMeter extends StatelessWidget {
  final int total;
  final int ok;
  final int warn;
  final int current;
  final int? mark;
  final double height;
  const SegMeter({super.key, required this.total, this.ok = 0, this.warn = 0, this.current = -1, this.mark, this.height = 7});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      for (var i = 0; i < total; i++) ...[
        if (i > 0) const SizedBox(width: 3),
        Expanded(
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: i < ok
                  ? Hc.ok
                  : i < ok + warn
                      ? Hc.warn
                      : i == current
                          ? Hc.acc
                          : Hc.bgDeep,
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: Hc.line, width: 1.5),
              boxShadow: mark == i ? const [BoxShadow(color: Hc.acc, offset: Offset(0, -3))] : null,
            ),
          ),
        ),
      ],
    ]);
  }
}

/// Barra de fases de obra: hecho = dorado, actual = dorado al 55 % con aro dorado.
class PhaseBar extends StatelessWidget {
  final int total;
  final int done;
  final double height;
  const PhaseBar({super.key, required this.total, required this.done, this.height = 7});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      for (var i = 0; i < total; i++) ...[
        if (i > 0) const SizedBox(width: 3),
        Expanded(
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: i < done ? Hc.acc : (i == done ? Hc.acc.withValues(alpha: 0.55) : Hc.bgDeep),
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: i == done ? Hc.acc : Hc.line, width: 1.5),
            ),
          ),
        ),
      ],
    ]);
  }
}


/// Anillo de progreso.
class Ring extends StatelessWidget {
  final double value;
  final double size;
  final Color color;
  final Widget? child;
  final double stroke;
  const Ring(this.value, {super.key, this.size = 56, this.color = Hc.acc, this.child, this.stroke = 6});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(value.clamp(0.0, 1.0), color, stroke),
          child: Center(child: child),
        ),
      );
}

class _RingPainter extends CustomPainter {
  final double v;
  final Color c;
  final double s;
  _RingPainter(this.v, this.c, this.s);
  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(s / 2, s / 2, size.width - s, size.height - s);
    canvas.drawArc(r, 0, math.pi * 2, false, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s + 3
      ..color = Hc.line);
    canvas.drawArc(r, 0, math.pi * 2, false, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s
      ..color = Hc.panelIn);
    canvas.drawArc(r, -math.pi / 2, math.pi * 2 * v, false, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s
      ..strokeCap = StrokeCap.round
      ..color = c);
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.v != v || o.c != c;
}

// =====================================================================
// Controles
// =====================================================================
class Seg3<T> extends StatelessWidget {
  final List<T> values;
  final T value;
  final String Function(T) label;
  final ValueChanged<T> onChanged;
  final bool Function(T)? enabled;
  const Seg3({super.key, required this.values, required this.value, required this.label, required this.onChanged, this.enabled});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Hc.bgDeep,
        borderRadius: BorderRadius.circular(Hr.btn + 2),
        border: Border.all(color: Hc.line, width: 2),
      ),
      child: Row(children: [
        for (final v in values)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: (enabled?.call(v) ?? true)
                  ? () {
                      HapticFeedback.selectionClick();
                      onChanged(v);
                    }
                  : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
                decoration: BoxDecoration(
                  color: v == value ? Hc.acc : null,
                  borderRadius: BorderRadius.circular(Hr.btn - 2),
                  border: v == value ? Border.all(color: Hc.line, width: 2) : null,
                  boxShadow: v == value ? const [BoxShadow(color: Hc.accLo, offset: Offset(0, 2))] : null,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label(v),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: TextStyle(
                      fontFamily: Hf.body,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      color: v == value
                          ? Hc.onAcc
                          : (enabled?.call(v) ?? true)
                              ? Hc.mut
                              : Hc.dim,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}


class HsToggle extends StatelessWidget {
  final bool on;
  final ValueChanged<bool> onChanged;
  const HsToggle(this.on, this.onChanged, {super.key});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onChanged(!on);
        },
        child: Semantics(
          toggled: on,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 46,
            height: 28,
            decoration: BoxDecoration(
              color: on ? Hc.ok : Hc.panelIn,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Hc.line, width: 2),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              alignment: on ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.all(2),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: on ? Hc.ink : Hc.mut,
                  shape: BoxShape.circle,
                  border: Border.all(color: Hc.line, width: 2),
                ),
              ),
            ),
          ),
        ),
      );
}

class HsStepper extends StatelessWidget {
  final String value;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;
  const HsStepper({super.key, required this.value, this.onMinus, this.onPlus});
  @override
  Widget build(BuildContext context) {
    Widget b(String t, VoidCallback? f) => GestureDetector(
          onTap: f == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  f();
                },
          child: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            color: Hc.panel,
            child: Text(t, style: Ht.numS.copyWith(color: f == null ? Hc.dim : Hc.ink, fontSize: 24)),
          ),
        );
    return Container(
      decoration: BoxDecoration(
        color: Hc.panelIn,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Hc.line, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          b('−', onMinus),
          SizedBox(width: 56, child: Text(value, textAlign: TextAlign.center, style: Ht.numS)),
          b('+', onPlus),
        ]),
      ),
    );
  }
}

/// Deslizador del sistema (sld): pista, relleno, pulgar dorado y marca.
class HsSlider extends StatelessWidget {
  final double value, min, max;
  final ValueChanged<double> onChanged;
  final double? mark;
  final int? divisions;
  const HsSlider({super.key, required this.value, required this.min, required this.max, required this.onChanged, this.mark, this.divisions});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth - 26;
        double toX(double v) => 13 + (v - min) / (max - min) * w;
        void upd(Offset p) {
          var v = min + ((p.dx - 13) / w).clamp(0.0, 1.0) * (max - min);
          if (divisions != null) {
            final step = (max - min) / divisions!;
            v = (v / step).round() * step;
          }
          onChanged(v.clamp(min, max));
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => upd(d.localPosition),
          onHorizontalDragUpdate: (d) => upd(d.localPosition),
          child: Stack(clipBehavior: Clip.none, alignment: Alignment.centerLeft, children: [
            Positioned(
              left: 0,
              right: 0,
              child: Container(
                height: 10,
                decoration: BoxDecoration(
                  color: Hc.panelIn,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: Hc.line, width: 2),
                ),
              ),
            ),
            Positioned(
              left: 2,
              width: math.max(0, toX(value) - 2),
              child: Container(height: 6, decoration: BoxDecoration(color: Hc.acc, borderRadius: BorderRadius.circular(3))),
            ),
            if (mark != null)
              Positioned(left: toX(mark!) - 1, top: 6, child: Container(width: 2, height: 22, color: Hc.ink.withValues(alpha: 0.8))),
            Positioned(
              left: toX(value) - 13,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Hc.accHi, Hc.acc]),
                  border: Border.all(color: Hc.line, width: 2),
                  boxShadow: const [
                    BoxShadow(color: Hc.accLo, offset: Offset(0, 3)),
                    BoxShadow(color: Color(0x66000000), offset: Offset(0, 6), blurRadius: 8),
                  ],
                ),
              ),
            ),
          ]),
        );
      }),
    );
  }
}

// =====================================================================
// Moléculas
// =====================================================================
/// Contenido de un stat tile: etiqueta "cap" y cifra Jersey 26.
class Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final TextStyle? style;
  final Widget? extra;
  const Stat(this.label, this.value, {super.key, this.color = Hc.ink, this.style, this.extra});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        // Las etiquetas largas (alemán) se encogen en vez de cortarse.
        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Cap(label)),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: (style ?? Ht.numM).copyWith(color: color)),
        ),
        if (extra != null) ...[const SizedBox(height: 5), extra!],
      ]);
}

/// Stat tile: fondo panelIn, borde 2, radio 12, padding 7 × 10.
class StatTile extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? border;
  const StatTile({super.key, required this.child, this.onTap, this.border});
  @override
  Widget build(BuildContext context) {
    final box = Container(
      decoration: BoxDecoration(
        color: Hc.panelIn,
        borderRadius: BorderRadius.circular(Hr.tile),
        border: Border.all(color: border ?? Hc.line, width: 2),
        boxShadow: He.e1,
      ),
      child: CustomPaint(
        foregroundPainter: const HilitePainter(),
        child: Padding(padding: const EdgeInsets.fromLTRB(10, 7, 10, 8), child: child),
      ),
    );
    return onTap == null ? box : Pressable(onTap: onTap, depth: 2, child: box);
  }
}


/// Rejilla de stat tiles (separación 8).
class StatGrid extends StatelessWidget {
  final List<Widget> cells;
  final int columns;
  const StatGrid(this.cells, {super.key, this.columns = 2});
  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < cells.length; i += columns) {
      final row = <Widget>[];
      for (var j = 0; j < columns; j++) {
        if (j > 0) row.add(const SizedBox(width: 8));
        row.add(Expanded(child: i + j < cells.length ? StatTile(child: cells[i + j]) : const SizedBox()));
      }
      if (i > 0) rows.add(const SizedBox(height: 8));
      rows.add(IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: row)));
    }
    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }
}


/// Fila de lista: fondo panelIn, borde 2, radio 12, padding 8 × 10, separación 10.
/// Las filas se apilan con 8 de hueco (sin hueco tras la última).
class Li extends StatelessWidget {
  final Widget? lead;
  final String title;
  final String? sub;
  final Widget? trail;
  final VoidCallback? onTap;
  final bool last;
  final Color? titleColor;
  /// Título en Jersey (filas de vivienda) en lugar de Manrope.
  final bool display;
  /// Tag junto al título (estado).
  final Widget? titleTag;
  const Li({super.key, this.lead, required this.title, this.sub, this.trail, this.onTap, this.last = false, this.titleColor, this.display = false, this.titleTag});
  @override
  Widget build(BuildContext context) {
    final row = Container(
      margin: EdgeInsets.only(bottom: last ? 0 : 8),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: Hc.panelIn,
        borderRadius: BorderRadius.circular(Hr.tile),
        border: Border.all(color: Hc.line, width: 2),
        boxShadow: He.e1,
      ),
      child: Row(children: [
        if (lead != null) ...[lead!, const SizedBox(width: 10)],
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            // Wrap: si no cabe, la etiqueta baja de línea en vez de cortar la dirección.
            Wrap(spacing: 6, runSpacing: 3, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: display ? Ht.numS.copyWith(color: titleColor ?? Hc.ink) : Ht.bodyB.copyWith(color: titleColor, fontSize: 13.5)),
              if (titleTag != null) titleTag!,
            ]),
            if (sub != null) ...[
              const SizedBox(height: 1),
              Text(sub!, style: Ht.mini, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ]),
        ),
        if (trail != null) ...[const SizedBox(width: 10), trail!],
      ]),
    );
    if (onTap == null) return row;
    return Pressable(onTap: onTap, depth: 2, child: row);
  }
}

/// Columna de filas [Li] sin superficie propia (las filas ya son tiles).
class ListBlock extends StatelessWidget {
  final List<Widget> children;
  const ListBlock(this.children, {super.key});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: children);
}


/// Icono en cuadro. Con [solid] es el cuadro de color de eventos y avisos.
class IconBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final bool solid;
  const IconBox(this.icon, {super.key, this.color = Hc.ink, this.size = 38, this.solid = false});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: solid ? color : Hc.bgDeep,
          gradient: solid
              ? LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color.lerp(color, Colors.white, 0.18)!, color])
              : null,
          borderRadius: BorderRadius.circular(size >= 44 ? 12 : 10),
          border: Border.all(color: Hc.line, width: 2),
          boxShadow: solid ? He.chip : null,
        ),
        child: Icon(icon, size: size * 0.52, color: solid ? Hc.line : color),
      );
}


class Avatar extends StatelessWidget {
  final String name;
  final Color color;
  final double size;
  const Avatar(this.name, {super.key, this.color = Hc.info, this.size = 40});
  @override
  Widget build(BuildContext context) {
    final parts = name.split(' ');
    final ini = parts.map((p) => p.isEmpty ? '' : p[0]).take(2).join();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Hc.line, width: 2),
        boxShadow: He.chip,
      ),
      child: Text(ini, style: TextStyle(fontFamily: Hf.display, fontSize: size * 0.45, color: Hc.onAcc, height: 1)),
    );
  }
}

/// Nota con borde discontinuo.
enum NoteKind { plain, warn, bad, ok }

class Note extends StatelessWidget {
  final String text;
  final String? bold;
  final IconData icon;
  final NoteKind kind;
  const Note(this.text, {super.key, this.bold, this.icon = Icons.info_outline, this.kind = NoteKind.plain});
  @override
  Widget build(BuildContext context) {
    final (border, bg, fg) = switch (kind) {
      NoteKind.plain => (Hc.lineSoft, Colors.transparent, Hc.mut),
      NoteKind.warn => (const Color(0x80E3A93B), const Color(0x14E3A93B), Hc.ink),
      NoteKind.bad => (const Color(0x80E2675B), const Color(0x14E2675B), Hc.ink),
      NoteKind.ok => (const Color(0x804FC08D), const Color(0x144FC08D), Hc.ink),
    };
    return DashedBorder(
      radius: 10,
      color: border,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 16, color: kind == NoteKind.plain ? Hc.mut : border.withValues(alpha: 1)),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                if (bold != null) TextSpan(text: '$bold ', style: const TextStyle(fontWeight: FontWeight.w800)),
                TextSpan(text: text),
              ]),
              style: TextStyle(fontFamily: Hf.body, fontSize: 12, height: 1.4, fontWeight: FontWeight.w500, color: fg),
            ),
          ),
        ]),
      ),
    );
  }
}

class DashedBorder extends StatelessWidget {
  final Widget child;
  final double radius;
  final Color color;
  const DashedBorder({super.key, required this.child, this.radius = 10, this.color = Hc.lineSoft});
  @override
  Widget build(BuildContext context) =>
      CustomPaint(foregroundPainter: _DashPainter(radius, color), child: child);
}

class _DashPainter extends CustomPainter {
  final double r;
  final Color c;
  _DashPainter(this.r, this.c);
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(r)).deflate(0.75));
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = c;
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, math.min(d + 5, m.length)), p);
        d += 9;
      }
    }
  }

  @override
  bool shouldRepaint(_DashPainter o) => o.c != c || o.r != r;
}

/// Cabecera de sección: etiqueta "cap" (p. ej. «EVENTOS · 2»).
class SectionHead extends StatelessWidget {
  final String title;
  final String? trail;
  final Widget? trailWidget;
  const SectionHead(this.title, {super.key, this.trail, this.trailWidget});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(child: Cap(trail == null ? title : '$title · $trail')),
          if (trailWidget != null) trailWidget!,
        ]),
      );
}


/// Cabecera de panel con botón atrás: título H1 y subtítulo "cap".
class BackHeader extends StatelessWidget {
  final String title;
  final String? sub;
  final Widget? trail;
  final VoidCallback? onBack;
  const BackHeader(this.title, {super.key, this.sub, this.trail, this.onBack});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Row(children: [
          SqButton(Icons.chevron_left_rounded, size: 36, tooltip: 'Atrás', onTap: onBack ?? () => Navigator.of(context).maybePop()),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(title, style: Ht.title.copyWith(fontSize: sub == null ? 34 : 30), maxLines: 1, overflow: TextOverflow.ellipsis),
              if (sub != null) Cap(sub!),
            ]),
          ),
          if (trail != null) ...[const SizedBox(width: 8), trail!],
        ]),
      );
}


/// Cabecera de panel de pestaña: título H1 y, a la derecha, un tag.
class TabHeader extends StatelessWidget {
  final String title;
  final List<Widget> trail;
  const TabHeader(this.title, {super.key, this.trail = const []});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Row(children: [
          Expanded(child: Text(title, style: Ht.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
          for (final w in trail) Padding(padding: const EdgeInsets.only(left: 8), child: w),
        ]),
      );
}


/// Tag de cabecera (ej. «3 ACTIVAS», «CRISIS»).
class HeadPill extends StatelessWidget {
  final String text;
  final Color color;
  final Color border;
  const HeadPill(this.text, {super.key, this.color = Hc.acc, this.border = Hc.acc});
  @override
  Widget build(BuildContext context) => Tag(text, color: color == Hc.ink ? Hc.acc : color);
}


/// Fila de evento: cuadro de icono de color + texto.
class EventStrip extends StatelessWidget {
  final String cap;
  final String text;
  final Color color;
  final VoidCallback? onTap;
  final Widget? trail;
  final PanelKind kind;
  final IconData? icon;
  const EventStrip({super.key, required this.cap, required this.text, this.color = Hc.bad, this.onTap, this.trail, this.kind = PanelKind.normal, this.icon});
  @override
  Widget build(BuildContext context) {
    final body = Row(children: [
      IconBox(icon ?? (color == Hc.bad ? Icons.warning_amber_rounded : Icons.notifications_none_rounded), color: color, solid: true, size: 38),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(cap, style: Ht.numS.copyWith(fontSize: 19), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(text, style: Ht.mini, maxLines: 2, overflow: TextOverflow.ellipsis),
        ]),
      ),
      if (trail != null) ...[const SizedBox(width: 8), trail!],
    ]);
    return Panel(kind: kind, onTap: onTap, padding: const EdgeInsets.fromLTRB(10, 8, 10, 8), child: body);
  }
}


/// Pin del mapa: círculo de 26 (34 si está seleccionado, con aro de 3 px y etiqueta).
class MapPin extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool selected;
  final String? label;
  const MapPin(this.icon, {super.key, required this.color, this.selected = false, this.label});
  static const double size = 26, selSize = 34;
  @override
  Widget build(BuildContext context) {
    final d = selected ? selSize : size;
    final circle = Container(
      width: d,
      height: d,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color.lerp(color, Colors.white, 0.2)!, color]),
        border: Border.all(color: Hc.line, width: 2),
        boxShadow: [
          if (selected) const BoxShadow(color: Hc.ink, spreadRadius: 3),
          if (selected) const BoxShadow(color: Hc.line, spreadRadius: 5),
          const BoxShadow(color: Color(0x80000000), offset: Offset(0, 3)),
        ],
      ),
      child: Icon(icon, size: d * 0.55, color: Hc.line),
    );
    final pin = Column(mainAxisSize: MainAxisSize.min, children: [
      circle,
      Transform.translate(offset: const Offset(0, -1), child: CustomPaint(size: const Size(10, 6), painter: _PinTip(Hc.line))),
    ]);
    if (!selected || label == null) return pin;
    return Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: d + 8, child: pin),
      Transform.translate(
        offset: Offset(-2, d / 2 - 11),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: Hg.hud.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(Hr.tag),
            border: Border.all(color: Hc.line, width: 2),
            boxShadow: He.chip,
          ),
          child: Text(label!.toUpperCase(),
              style: const TextStyle(fontFamily: Hf.body, fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 0.8, color: Hc.ink, height: 1.2)),
        ),
      ),
    ]);
  }
}


class _PinTip extends CustomPainter {
  final Color c;
  _PinTip(this.c);
  @override
  void paint(Canvas canvas, Size s) {
    canvas.drawPath(Path()
      ..moveTo(0, 0)
      ..lineTo(s.width, 0)
      ..lineTo(s.width / 2, s.height)
      ..close(), Paint()..color = c);
  }

  @override
  bool shouldRepaint(_PinTip o) => false;
}

/// Tecla/código pequeño.
class Kbd extends StatelessWidget {
  final String t;
  const Kbd(this.t, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: Hc.lineSoft, width: 1.5)),
        child: Text(t, style: Ht.numS.copyWith(fontSize: 14, color: Hc.mut)),
      );
}

/// Texto flotante "+30" que aparece girado y se desvanece.
class PopNum extends StatefulWidget {
  final String text;
  final Color color;
  final double size;
  final VoidCallback? onDone;
  const PopNum(this.text, {super.key, this.color = Hc.acc, this.size = 30, this.onDone});
  @override
  State<PopNum> createState() => _PopNumState();
}

class _PopNumState extends State<PopNum> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 750))
    ..forward().whenComplete(() => widget.onDone?.call());
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        final s = t < 0.3 ? 0.5 + t / 0.3 * 0.7 : 1.2 - (t - 0.3) * 0.3;
        return Opacity(
          opacity: (t > 0.7 ? (1 - (t - 0.7) / 0.3) : 1.0).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, -30 * t),
            child: Transform.rotate(
              angle: -7 * math.pi / 180,
              child: Transform.scale(
                scale: s,
                child: GlowText(widget.text, style: Ht.numL.copyWith(fontSize: widget.size), color: widget.color),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Postura 3D estática (pose-up / pose-paper / pose-plane). Pocas y sin reaccionar al toque.
class Pose extends StatelessWidget {
  final Widget child;
  final double rx, rz, scale, dy;
  const Pose({super.key, required this.child, this.rx = 0, this.rz = 0, this.scale = 1, this.dy = 0});
  const Pose.up({super.key, required this.child})
      : rx = 8,
        rz = -3,
        scale = 1.08,
        dy = -4;
  const Pose.paper({super.key, required this.child})
      : rx = 0,
        rz = -1.4,
        scale = 1,
        dy = 0;
  const Pose.plane({super.key, required this.child})
      : rx = 13,
        rz = 0,
        scale = 1,
        dy = 0;
  @override
  Widget build(BuildContext context) {
    final m = Matrix4.identity()
      ..setEntry(3, 2, 1 / 600)
      ..multiply(Matrix4.translationValues(0, dy, 0))
      ..rotateX(rx * math.pi / 180)
      ..rotateZ(rz * math.pi / 180)
      ..multiply(Matrix4.diagonal3Values(scale, scale, 1));
    return Transform(alignment: Alignment.bottomCenter, transform: m, child: child);
  }
}
