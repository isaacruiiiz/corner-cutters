import 'dart:ui' as ui show TextHeightBehavior;

import 'package:flutter/widgets.dart' as w;
import 'package:flutter/widgets.dart' hide Text;

import 'i18n.dart';

/// `Text` del juego: igual que el de Flutter, pero traduce el texto al idioma elegido.
/// Las pantallas importan `material.dart hide Text` y este archivo, así que todos los textos
/// (también los `const`) pasan por aquí y se repintan al cambiar de idioma.
class Text extends StatelessWidget {
  final String? data;
  final InlineSpan? textSpan;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final ui.TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;

  const Text(
    String this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  }) : textSpan = null;

  const Text.rich(
    InlineSpan this.textSpan, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  }) : data = null;

  static InlineSpan _span(InlineSpan s) {
    if (s is! TextSpan) return s;
    return TextSpan(
      text: s.text == null ? null : I18n.t(s.text!),
      children: s.children?.map(_span).toList(),
      style: s.style,
      recognizer: s.recognizer,
      mouseCursor: s.mouseCursor,
      onEnter: s.onEnter,
      onExit: s.onExit,
      semanticsLabel: s.semanticsLabel == null ? null : I18n.t(s.semanticsLabel!),
      locale: s.locale,
      spellOut: s.spellOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    I18nScope.escuchar(context);
    final sl = semanticsLabel == null ? null : I18n.t(semanticsLabel!);
    if (textSpan != null) {
      return w.Text.rich(_span(textSpan!),
          style: style, strutStyle: strutStyle, textAlign: textAlign, textDirection: textDirection, locale: locale,
          softWrap: softWrap, overflow: overflow, textScaler: textScaler, maxLines: maxLines, semanticsLabel: sl,
          textWidthBasis: textWidthBasis, textHeightBehavior: textHeightBehavior, selectionColor: selectionColor);
    }
    return w.Text(I18n.t(data!),
        style: style, strutStyle: strutStyle, textAlign: textAlign, textDirection: textDirection, locale: locale,
        softWrap: softWrap, overflow: overflow, textScaler: textScaler, maxLines: maxLines, semanticsLabel: sl,
        textWidthBasis: textWidthBasis, textHeightBehavior: textHeightBehavior, selectionColor: selectionColor);
  }
}
