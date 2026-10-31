import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Text;

import '../../core/gfx.dart';
import '../../core/theme.dart';
import '../../services/audio.dart';
import 'atoms.dart';

import '../../core/texto.dart';
/// Hoja flotante (izq./der. 12, radio 20, fondo .95) sobre el mapa nítido.
Future<T?> showHsSheet<T>(BuildContext context, {required WidgetBuilder builder, bool scroll = false}) {
  Sfx.play('hoja_abre');
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x40061010),
    elevation: 0,
    builder: (ctx) {
      final mq = MediaQuery.of(ctx);
      return Padding(
        padding: EdgeInsets.fromLTRB(12, 0, 12, mq.viewInsets.bottom + mq.padding.bottom + 12),
        child: Container(
          constraints: BoxConstraints(maxHeight: mq.size.height * 0.82),
          decoration: BoxDecoration(
            color: Hg.sheet,
            borderRadius: BorderRadius.circular(Hr.sheet),
            border: Border.all(color: Hc.line, width: 2),
            boxShadow: He.e1,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Hr.sheet - 2),
            child: Stack(fit: StackFit.passthrough, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Flexible(child: scroll ? SingleChildScrollView(child: builder(ctx)) : builder(ctx)),
                ]),
              ),
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
        ),
      );
    },
  ).whenComplete(() => Sfx.play('hoja_cierra'));
}


/// Diálogo (izq./der. 18, hacia el tercio superior, radio 20, fondo .97) con el mapa velado detrás.
Future<T?> showHsDialog<T>(BuildContext context, {required WidgetBuilder builder, bool dismissible = true}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: 'Cerrar',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, a, b) {
      final mq = MediaQuery.of(ctx);
      return Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: dismissible ? () => Navigator.of(ctx).maybePop() : null,
            child: Gfx.liveBlur
                ? BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: Hg.veilBlur, sigmaY: Hg.veilBlur),
                    child: const ColoredBox(color: Hg.veil),
                  )
                : const ColoredBox(color: Color(0xB8061010)),
          ),
        ),
        SafeArea(
          child: Align(
            alignment: const Alignment(0, -0.35),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Material(
                type: MaterialType.transparency,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: mq.size.height * 0.82, maxWidth: 440),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Hg.dialog,
                      borderRadius: BorderRadius.circular(Hr.sheet),
                      border: Border.all(color: Hc.line, width: 2),
                      boxShadow: He.e1,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(Hr.sheet - 2),
                      child: Stack(fit: StackFit.passthrough, children: [
                        SingleChildScrollView(padding: const EdgeInsets.fromLTRB(16, 18, 16, 16), child: builder(ctx)),
                        const Hilite(radius: Hr.sheet),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ]);
    },
    transitionBuilder: (ctx, a, b, child) {
      if (Motion.off(ctx)) return FadeTransition(opacity: a, child: child);
      final t = Curves.easeOutCubic.transform(a.value);
      final sc = a.status == AnimationStatus.reverse ? 0.96 + 0.04 * t : 0.9 + 0.1 * Curves.easeOutBack.transform(a.value);
      return Opacity(
        opacity: a.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - t)),
          child: Transform.scale(scale: sc, alignment: const Alignment(0, -0.35), child: child),
        ),
      );
    },
  );
}


/// Confirmación simple (secundario + primario).
Future<bool> confirm(BuildContext context,
    {required String title, required String body, String ok = 'Confirmar', String cancel = 'Cancelar', bool danger = false}) async {
  final r = await showHsDialog<bool>(
    context,
    builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Text(title, style: Ht.h2),
      const SizedBox(height: 8),
      Text(body, style: Ht.body.copyWith(color: Hc.mut, fontSize: 13)),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: HsButton(cancel, kind: BtnKind.sec, block: true, onTap: () => Navigator.pop(ctx, false))),
        const SizedBox(width: 10),
        Expanded(child: HsButton(ok, kind: danger ? BtnKind.bad : BtnKind.primary, block: true, onTap: () => Navigator.pop(ctx, true))),
      ]),
    ]),
  );
  return r ?? false;
}


/// Toast claro sobre la pantalla (toast).
class Toaster {
  static OverlayEntry? _e;
  static Timer? _t;

  static void show(BuildContext context, String text, {IconData icon = Icons.check_circle_outline, Color color = Hc.ok, bool shake = false}) {
    final ov = Overlay.maybeOf(context, rootOverlay: true);
    if (ov == null) return;
    _e?.remove();
    _t?.cancel();
    final shakeKey = shake ? DateTime.now().microsecondsSinceEpoch : null;
    final entry = OverlayEntry(
      builder: (ctx) => Positioned(
        left: 16,
        right: 16,
        top: MediaQuery.of(ctx).padding.top + 50,
        child: IgnorePointer(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutBack,
            builder: (c, v, child) => Transform.translate(
                offset: Offset(0, -30 * (1 - v)),
                child: Transform.scale(scale: 0.92 + 0.08 * v, child: Opacity(opacity: v.clamp(0.0, 1.0), child: child))),
            child: Material(
              type: MaterialType.transparency,
              child: Shake(
                trigger: shakeKey,
                child: GlassBox(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                color: const Color(0xEB102625),
                borderColor: color,
                child: Row(children: [
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(text,
                        style: const TextStyle(fontFamily: Hf.body, fontWeight: FontWeight.w700, fontSize: 13, color: Hc.ink, height: 1.3)),
                  ),
                ]),
              ),
              ),
            ),
          ),
        ),
      ),
    );
    _e = entry;
    ov.insert(entry);
    _t = Timer(const Duration(milliseconds: 2600), () {
      if (_e == entry) {
        entry.remove();
        _e = null;
      }
    });
  }
}

void toast(BuildContext context, String text, {bool error = false}) {
  if (error) Sfx.play('error');
  _toast(context, text, error: error);
}

void _toast(BuildContext context, String text, {bool error = false}) => Toaster.show(context, text,
    icon: error ? Icons.error_outline : Icons.check_circle_outline, color: error ? Hc.bad : Hc.ok, shake: error);
