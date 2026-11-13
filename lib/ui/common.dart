import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../game/data.dart';
import '../game/engine.dart';
import '../game/model.dart';
import 'chrome.dart';
import 'map/map_view.dart';
import 'map/sprites.dart';
import 'widgets/atoms.dart';

import '../core/texto.dart';
import '../core/i18n.dart';
/// Ruta transparente: la pantalla se apila sobre el mapa con un fundido corto.
PageRouteBuilder<T> glassRoute<T>(Widget page) => PageRouteBuilder<T>(
      // El nombre (tipo de pantalla) sirve para no apilar la misma pantalla dos veces seguidas.
      settings: RouteSettings(name: page.runtimeType.toString()),
      opaque: false,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (ctx, a, __, child) {
        final c = CurvedAnimation(parent: a, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
        if (Motion.off(ctx)) return FadeTransition(opacity: c, child: child);
        return FadeTransition(
          opacity: c,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.05), end: Offset.zero).animate(c),
            child: ScaleTransition(scale: Tween(begin: 0.97, end: 1.0).animate(c), child: child),
          ),
        );
      },
    );

/// Navegación: las pantallas se apilan sobre el mapa. Si la pantalla de arriba ya es de ese
/// tipo (toques repetidos en la barra, doble toque), no se abre otra encima.
Future<T?> push<T>(BuildContext context, Widget page) {
  final nav = Navigator.of(context);
  String? top;
  nav.popUntil((r) {
    top = r.settings.name;
    return true; // solo mira la de arriba, no cierra nada
  });
  if (top == page.runtimeType.toString()) return Future<T?>.value();
  return nav.push<T>(glassRoute<T>(page));
}

/// Marca que el contenido vive dentro de una pestaña del Shell (el Shell pone velo, panel, HUD y barra).
class ShellTab extends InheritedWidget {
  const ShellTab({super.key, required super.child});
  static bool of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<ShellTab>() != null;
  @override
  bool updateShouldNotify(ShellTab old) => false;
}

/// ¿Hay partida en el Shell (para mostrar HUD y barra en pantallas apiladas)?
class ShellPresence {
  static bool alive = false;
}

enum ScreenKind {
  /// Panel de cristal con el mapa velado detrás (por defecto).
  panel,
  /// Hoja flotante sobre el mapa nítido, con el edificio a la vista.
  sheet,
  /// Pantalla completa opaca (minijuegos).
  full,
}


/// Superficie de una pantalla. Por defecto es un panel de cristal sobre el mapa velado,
/// con el HUD arriba y la barra abajo; [ScreenKind.sheet] es una hoja sobre el mapa nítido.
class Screen extends ConsumerWidget {
  final Widget child;
  final Widget? dock;
  final bool safeBottom;
  final ScreenKind kind;
  /// Parcela que la cámara deja a la vista (hojas).
  final int? lotId;
  const Screen({super.key, required this.child, this.dock, this.safeBottom = true, this.kind = ScreenKind.panel, this.lotId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dockW = dock == null ? null : Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 12), child: dock);
    // Dentro de una pestaña: el Shell ya pone el panel.
    if (ShellTab.of(context)) {
      return Column(children: [Expanded(child: child), if (dockW != null) dockW]);
    }
    if (kind == ScreenKind.full) {
      return Scaffold(
        backgroundColor: Hc.bg,
        body: SafeArea(
          bottom: safeBottom,
          child: Column(children: [Expanded(child: child), if (dockW != null) dockW]),
        ),
      );
    }
    final g = ref.watch(gameProvider);
    final chrome = ShellPresence.alive && g.loaded;
    final mq = MediaQuery.of(context);
    if (kind == ScreenKind.sheet) {
      final top = chrome ? Lay.panelTop(context) : mq.padding.top + 12;
      final bottom = chrome ? Lay.sheetBottom(context) : mq.padding.bottom + 12;
      // En horizontal no hay sitio para dejar el edificio a la vista encima: la hoja ocupa el alto.
      final maxH = mq.size.height - bottom - top - (Lay.landscape(context) ? 0 : 150);
      return Material(
        type: MaterialType.transparency,
        child: Stack(children: [
          Positioned.fill(child: lotId != null ? MapBackdrop(lotId: lotId!, focusY: 0.30) : const ColoredBox(color: Color(0x33061010))),
          Positioned(
            left: Lay.hInsets(context, 520, alignRight: Lay.wide(context)).$1,
            right: Lay.hInsets(context, 520, alignRight: Lay.wide(context)).$2,
            bottom: bottom,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: math.max(220, maxH)),
              child: GlassSheet(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Flexible(child: child),
                  if (dock != null) Padding(padding: const EdgeInsets.only(top: 10), child: dock),
                ]),
              ),
            ),
          ),
          if (chrome) const Positioned.fill(child: Chrome()),
        ]),
      );
    }
    final top = chrome ? Lay.panelTop(context) : mq.padding.top + 12;
    final bottom = chrome ? Lay.panelBottom(context) : mq.padding.bottom + 12;
    return Material(
      type: MaterialType.transparency,
      child: Stack(children: [
        const Positioned.fill(child: Veil()),
        Positioned(
          left: Lay.hInsets(context, 640).$1,
          right: Lay.hInsets(context, 640).$2,
          top: top,
          bottom: bottom,
          child: GlassPanel(child: Column(children: [Expanded(child: child), if (dockW != null) dockW])),
        ),
        if (chrome) const Positioned.fill(child: Chrome()),
      ]),
    );
  }
}


/// Lista con separación estándar (10) dentro de un panel.
class Body extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsets padding;
  const Body(this.children, {super.key, this.padding = const EdgeInsets.fromLTRB(12, 2, 12, 14)});
  @override
  Widget build(BuildContext context) => ListView(
        padding: padding,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            children[i],
          ],
        ],
      );
}

/// Contenido de hoja: columna que se ajusta a su alto y hace scroll si no cabe.
class SheetBody extends StatelessWidget {
  final List<Widget> children;
  const SheetBody(this.children, {super.key});
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            children[i],
          ],
        ]),
      );
}


/// Estado de vivienda → color: ruina = bad · obra = warn · sin reformar = mut ·
/// reformada = info · alquilada = ok · en venta = info.
Color stateColor(PState s) => switch (s) {
      PState.ruina => Hc.bad,
      PState.obra => Hc.warn,
      PState.lista => Hc.info,
      PState.buscando => Hc.info,
      PState.alquilada => Hc.ok,
      PState.venta => Hc.info,
    };


IconData stateIcon(PState s) => switch (s) {
      PState.ruina => Icons.warning_amber_rounded,
      PState.obra => Icons.construction_rounded,
      PState.lista => Icons.check_circle_outline,
      PState.buscando => Icons.key_outlined,
      PState.alquilada => Icons.key_rounded,
      PState.venta => Icons.sell_outlined,
    };

String stateLabel(Game g, Property p) {
  if (p.isClient && p.reno != null) return 'ENCARGO ${(p.reno!.totalFrac * 100).round()} %';
  if (p.state == PState.obra && p.reno != null) return 'OBRA ${(p.reno!.totalFrac * 100).round()} %';
  if (p.state == PState.ruina && p.origin == Origin.usada) return 'SIN REFORMAR';
  return pstateLabel[p.state]!;
}

Tag stateTag(Game g, Property p) =>
    Tag(stateLabel(g, p), color: stateColor(p.state), icon: p.state == PState.ruina ? Icons.warning_amber_rounded : null);

String propSub(Game g, Property p) {
  final z = zi(g.zoneOf(p)).name;
  final parts = <String>[z, '${p.m2} m²'];
  if (p.isClient) {
    parts.add('encargo de ${p.clientName}');
  } else if (p.sector != null && p.everRenovated) {
    parts.add('encaja con ${si(p.sector!).name.toLowerCase()}');
  }
  return parts.join(' · ');
}

/// Fila de vivienda: miniatura 54 × 54, dirección (Jersey 20) con tag, subtítulo y valor a la derecha.
class PropRow extends StatelessWidget {
  final Game g;
  final Property p;
  final VoidCallback? onTap;
  final bool last;
  final Widget? trail;
  /// Título alternativo (p. ej. solo planta y puerta dentro de un edificio).
  final String? title;
  const PropRow(this.g, this.p, {super.key, this.onTap, this.last = false, this.trail, this.title});
  @override
  Widget build(BuildContext context) {
    String right;
    String? right2;
    Color rc = Hc.ink;
    switch (p.state) {
      case PState.alquilada:
        right = money(g.valueOf(p));
        right2 = '+${money(g.rentOf(p))}';
      case PState.venta:
        right = money(g.valueOf(p) * p.askY);
        rc = Hc.info;
      case PState.obra:
        right = '${(p.reno!.totalFrac * 100).round()} %';
        rc = Hc.acc;
      default:
        right = money(g.valueOf(p));
    }
    final lot = g.lotOf(p);
    return Li(
      onTap: onTap,
      last: last,
      display: true,
      lead: LotThumb(lot: lot, state: spriteStateOf(p.state), size: title != null ? 44 : 54),
      title: title ?? g.addressOf(p),
      titleTag: p.tenant != null && p.tenant!.arrears > 0
          ? const Tag('Impago', color: Hc.bad, icon: Icons.warning_amber_rounded)
          : Tag(shortStateLabel(p.state), color: stateColor(p.state)),
      sub: propSub(g, p),
      trail: trail ??
          Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
            Text(right, style: Ht.numS.copyWith(color: rc)),
            if (right2 != null) Text(right2, style: Ht.mini.copyWith(color: Hc.mut)),
          ]),
    );
  }
}

/// Agrupa viviendas por parcela conservando el orden de aparición.
List<List<Property>> groupByLot(Iterable<Property> ps) {
  final m = <int, List<Property>>{};
  for (final p in ps) {
    (m[p.lotId] ??= []).add(p);
  }
  for (final l in m.values) {
    l.sort((a, b) => a.unit.compareTo(b.unit));
  }
  return m.values.toList();
}

/// Planta y puerta de una vivienda dentro de su edificio.
String unitLabel(Property p) {
  if (p.unit <= 0) return 'Bajo';
  return '${(p.unit + 1) ~/ 2}º ${p.unit.isOdd ? '1ª' : '2ª'}';
}

/// Edificio de la cartera: una fila compacta que se despliega en sus viviendas.
class BuildingRow extends StatefulWidget {
  final Game g;
  final List<Property> units;
  final bool last;
  final void Function(Property) onUnit;
  /// Reformar varias viviendas con la misma configuración.
  final void Function(List<Property>)? onRenoAll;
  const BuildingRow(this.g, this.units, {super.key, required this.onUnit, this.onRenoAll, this.last = false});
  @override
  State<BuildingRow> createState() => _BuildingRowState();
}

class _BuildingRowState extends State<BuildingRow> {
  bool _open = false;
  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final us = widget.units;
    final lot = g.lotOf(us.first);
    final counts = <PState, int>{};
    for (final p in us) {
      counts[p.state] = (counts[p.state] ?? 0) + 1;
    }
    final arrears = us.where((p) => p.tenant != null && p.tenant!.arrears > 0).length;
    final rent = us.where((p) => p.state == PState.alquilada).fold<double>(0, (a, p) => a + g.rentOf(p));
    final value = us.fold<double>(0, (a, p) => a + g.valueOf(p));
    final reformable = us.where((p) => p.state != PState.obra).toList();
    final obra = us.where((p) => p.state == PState.obra).toList();
    final sub = [
      for (final e in counts.entries) '${e.value} ${_etiquetaCorta(e.key)}',
    ].join(' · ');
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Li(
        last: !_open && widget.last,
        display: true,
        onTap: () => setState(() => _open = !_open),
        lead: LotThumb(lot: lot, state: obra.isNotEmpty ? 'obra' : spriteStateOf(us.any((p) => p.state == PState.alquilada) ? PState.alquilada : us.first.state)),
        title: g.addressOfLot(lot),
        titleTag: arrears > 0
            ? Tag('Impago · $arrears', color: Hc.bad, icon: Icons.warning_amber_rounded)
            : Tag('Edificio · ${us.length}', color: Hc.info),
        sub: '${zi(g.zoneOf(us.first)).name} · $sub',
        trail: Row(mainAxisSize: MainAxisSize.min, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
            Text(money(value, compact: value >= 1e6), style: Ht.numS),
            if (rent > 0) Text('+${money(rent)}', style: Ht.mini.copyWith(color: Hc.mut)),
          ]),
          const SizedBox(width: 4),
          AnimatedRotation(
            turns: _open ? 0.5 : 0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(Icons.expand_more_rounded, color: Hc.mut),
          ),
        ]),
      ),
      AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: !_open
            ? const SizedBox(width: double.infinity)
            : Padding(
                padding: EdgeInsets.only(left: 14, top: 0, bottom: widget.last ? 0 : 8),
                child: Container(
                  padding: const EdgeInsets.only(left: 10),
                  decoration: const BoxDecoration(border: Border(left: BorderSide(color: Hc.lineSoft, width: 2))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                    if (widget.onRenoAll != null && reformable.length > 1) ...[
                      HsButton('Reformar ${reformable.length} viviendas igual',
                          size: BtnSize.sm, kind: BtnKind.sec, icon: Icons.handyman_outlined, block: true, onTap: () => widget.onRenoAll!(reformable)),
                      const SizedBox(height: 8),
                    ],
                    for (var i = 0; i < us.length; i++)
                      PropRow(g, us[i], title: unitLabel(us[i]), last: i == us.length - 1, onTap: () => widget.onUnit(us[i])),
                  ]),
                ),
              ),
      ),
    ]);
  }
}

/// Etiqueta corta de estado para tags en filas.
/// Estado en minúscula para contar («2 llog. · 1 ruïna»); en alemán los sustantivos van con mayúscula.
String _etiquetaCorta(PState s) {
  final t = tr(shortStateLabel(s));
  return I18n.codigo == 'de' ? t : t.toLowerCase();
}

String shortStateLabel(PState s) => switch (s) {
      PState.ruina => 'Ruina',
      PState.obra => 'Obra',
      PState.lista => 'Lista',
      PState.buscando => 'Se alquila',
      PState.alquilada => 'Alq.',
      PState.venta => 'Venta',
    };


/// Fila clave-valor (kv).
class KV extends StatelessWidget {
  final String k;
  final String v;
  final Color? color;
  final bool big;
  const KV(this.k, this.v, {super.key, this.color, this.big = false});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(child: Text(k, style: Ht.body.copyWith(color: Hc.mut, fontSize: 13.5))),
          Text(v, style: (big ? Ht.numM : Ht.numS).copyWith(color: color ?? Hc.ink, fontSize: big ? 26 : 19)),
        ]),
      );
}

/// Cabecera de diálogo: icono de color 46 × 46, etiqueta "cap" y título Jersey 25.
class DialogHead extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String cap;
  final String title;
  const DialogHead({super.key, required this.icon, required this.color, required this.cap, required this.title});
  @override
  Widget build(BuildContext context) => Row(children: [
        IconBox(icon, color: color, solid: true, size: 46),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Cap(cap),
            const SizedBox(height: 2),
            Text(title, style: Ht.h2),
          ]),
        ),
      ]);
}

/// Cita en cursiva con borde izquierdo (titulares, anuncios, eventos).
class SideQuote extends StatelessWidget {
  final String text;
  const SideQuote(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.only(left: 10, top: 2, bottom: 2),
        decoration: const BoxDecoration(border: Border(left: BorderSide(color: Hc.lineSoft, width: 3))),
        child: Text(text, style: Ht.quote.copyWith(color: Hc.ink.withValues(alpha: 0.8))),
      );
}


String plural(int n, String one, String many) => '${intg(n)} ${tr(n == 1 ? one : many)}';

/// Historial de pagos de los últimos 12 meses en una sola línea (estilo gráfico de contribuciones):
/// verde = pagó, rojo = no pagó, apagado = sin datos (antes de entrar el inquilino).
class PayHistory extends StatelessWidget {
  final Tenant t;
  const PayHistory(this.t, {super.key});
  @override
  Widget build(BuildContext context) {
    final h = t.history;
    final cells = List<bool?>.filled(12 - h.length.clamp(0, 12), null) + h.cast<bool?>();
    final paid = h.where((b) => b).length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        const Expanded(child: Cap('Pagos · últimos 12 meses')),
        Text(h.isEmpty ? 'Sin cobros aún' : '$paid de ${h.length} pagados', style: Ht.mini),
      ]),
      const SizedBox(height: 6),
      Row(children: [
        for (var i = 0; i < 12; i++) ...[
          if (i > 0) const SizedBox(width: 3),
          Expanded(
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: cells[i] == null ? Hc.bgDeep : (cells[i]! ? Hc.ok : Hc.bad),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: Hc.line, width: 1.5),
                ),
              ),
            ),
          ),
        ],
      ]),
    ]);
  }
}
