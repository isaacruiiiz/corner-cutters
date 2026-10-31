import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/gfx.dart';
import '../../core/rng.dart';
import '../../core/theme.dart';
import '../../game/city.dart';
import '../../game/data.dart';
import '../../game/engine.dart';
import '../../game/model.dart';
import '../widgets/atoms.dart';
import 'ambient.dart';
import 'city_render.dart';
import 'sprites.dart';

import '../../core/texto.dart';
/// Escala base: un píxel del arte = 1 punto; la cámara arranca a ×2 (escala entera).
const kMapScale = 1.0;
const kMapStartZoom = 2.0;
const kMapMinZoom = 0.45;
const kMapMaxZoom = 4.0;

/// Imagen de la ciudad, re-renderizada cuando cambia el estado visible.
class CityImage extends ChangeNotifier {
  ui.Image? image;
  Iso? iso;
  Map<int, String> states = const {};
  String _sig = '';
  bool _busy = false;
  String? _pending;

  void sync(Game g) {
    if (!g.loaded) return;
    final b = StringBuffer('${g.seed}|${g.meta.mapTheme}|${g.eraCfg?.id ?? ''}|');
    for (final e in _states(g).entries) {
      b.write('${e.key}:${e.value};');
    }
    for (final e in _flags(g).entries) {
      b.write('f${e.key}:${e.value};');
    }
    final sig = b.toString();
    if (sig == _sig || sig == _pending) return;
    _pending = sig;
    if (_busy) return;
    _render(g, sig);
  }

  /// Estado de sprite de cada parcela propia o en venta.
  static Map<int, String> _states(Game g) {
    final m = <int, String>{};
    for (final p in g.props) {
      m[p.lotId] = lotSpriteState(g, p.lotId);
    }
    for (final l in g.listings) {
      m.putIfAbsent(l.lotId, () => lotSpriteState(g, l.lotId));
    }
    return m;
  }

  /// Detalles visibles por nivel (bit 1 placas solares, 2 plantas, 4 toldos).
  static Map<int, int> _flags(Game g) {
    final m = <int, int>{};
    // En una época los edificios llevan su propio arte: sin placas solares ni toldos de hoy.
    if (g.eraCfg != null) return m;
    for (final p in g.props) {
      if (p.isClient || p.reno != null) continue;
      var f = 0;
      if (p.lv(Trade.ele) >= 18) f |= 1;
      if (p.lv(Trade.dec) >= 14) f |= 2;
      if (p.lv(Trade.car) >= 14) f |= 4;
      if (f != 0) m[p.lotId] = f;
    }
    return m;
  }

  Future<void> _render(Game g, String sig) async {
    _busy = true;
    final st = _states(g);
    await SpriteAtlas.instance.useEra(g.eraCfg?.id);
    final img = await CityRenderer.render(g.city, states: st, flags: _flags(g), theme: g.meta.mapTheme);
    image?.dispose();
    image = img;
    iso = Iso(g.city);
    states = st;
    _sig = sig;
    _busy = false;
    notifyListeners();
    if (_pending != null && _pending != sig) {
      final p = _pending!;
      _pending = null;
      scheduleMicrotask(() => _render(g, p));
    } else {
      _pending = null;
    }
  }
}

final cityImageProvider = ChangeNotifierProvider<CityImage>((ref) => CityImage());

/// Capas visibles sobre el mapa.
class MapLayers {
  final bool mine, market, districts, streets, rivals;
  const MapLayers({this.mine = true, this.market = true, this.districts = false, this.streets = false, this.rivals = false});
  MapLayers copyWith({bool? mine, bool? market, bool? districts, bool? streets, bool? rivals}) => MapLayers(
        mine: mine ?? this.mine,
        market: market ?? this.market,
        districts: districts ?? this.districts,
        streets: streets ?? this.streets,
        rivals: rivals ?? this.rivals,
      );
  bool get isDefault => mine && market && !districts && !streets && !rivals;
}

final mapLayersProvider = StateProvider<MapLayers>((ref) => const MapLayers());

/// Calle seleccionada en el mapa (id) o null.
final selectedStreetProvider = StateProvider<int?>((ref) => null);

/// Pin de una parcela: icono y color según su estado (solo ruina, obra y en venta).
(IconData, Color)? pinFor(Game g, int lotId, {bool any = false}) {
  final ps = g.propsOnLot(lotId);
  if (ps.isEmpty) {
    for (final l in g.listings) {
      if (l.lotId == lotId) {
        return switch (l.origin) {
          Origin.subasta => (Icons.gavel_rounded, Hc.info),
          Origin.embargo => (Icons.account_balance_outlined, Hc.ok),
          Origin.rival => (Icons.sell_outlined, const Color(0xFFB98AD6)),
          Origin.usada => (Icons.home_repair_service_outlined, Hc.warn),
          _ => (Icons.warning_amber_rounded, Hc.bad),
        };
      }
    }
    return any ? (Icons.location_on_outlined, Hc.mut) : null;
  }
  if (ps.first.isClient) return (Icons.handshake_outlined, Hc.acc);
  PState s = ps.first.state;
  for (final p in ps) {
    if (p.state == PState.obra) s = PState.obra;
  }
  return switch (s) {
    PState.ruina => (Icons.warning_amber_rounded, Hc.bad),
    PState.obra => (Icons.construction_rounded, Hc.warn),
    PState.venta => (Icons.sell_outlined, Hc.info),
    PState.alquilada => any ? (Icons.key_rounded, Hc.ok) : null,
    PState.buscando => any ? (Icons.key_outlined, Hc.info) : null,
    PState.lista => any ? (Icons.auto_awesome_rounded, Hc.info) : null,
  };
}

/// Etiqueta del pin seleccionado.
String pinLabel(Game g, int lotId) {
  final ps = g.propsOnLot(lotId);
  if (ps.isEmpty) {
    for (final l in g.listings) {
      if (l.lotId == lotId) return originLabel[l.origin]!;
    }
    return 'Libre';
  }
  if (ps.length > 1) return '${ps.length} viviendas';
  final p = ps.first;
  return switch (p.state) {
    PState.lista => 'Reformada',
    _ => pstateLabel[p.state]!,
  };
}

/// Mapa isométrico interactivo: arrastrar, ampliar y tocar calles o edificios.
class MapView extends ConsumerStatefulWidget {
  final TransformationController controller;
  final void Function(Lot lot) onLot;
  final void Function(int street) onStreet;
  final VoidCallback onEmpty;
  /// Parcela en la que se centra la cámara al abrir (si no, la seleccionada).
  final int? focusLot;
  /// Altura relativa de la pantalla donde queda el edificio enfocado.
  final double focusY;
  final bool showPins;
  const MapView({
    super.key,
    required this.controller,
    required this.onLot,
    required this.onStreet,
    required this.onEmpty,
    this.focusLot,
    this.focusY = 0.45,
    this.showPins = true,
  });
  @override
  ConsumerState<MapView> createState() => MapViewState();
}

class MapViewState extends ConsumerState<MapView> with TickerProviderStateMixin {
  bool _centered = false;
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
  ui.Image? _outline;
  String? _outlineKey;
  double _zoom = kMapStartZoom;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onZoom);
  }

  void _onZoom() {
    final z = widget.controller.value.getMaxScaleOnAxis();
    // Solo se reconstruye al cruzar el umbral de los pins.
    if ((z < 0.8) != (_zoom < 0.8)) setState(() => _zoom = z);
    _zoom = z;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onZoom);
    _pulse.dispose();
    super.dispose();
  }

  void centerOn(Offset worldPx, {double? scale, bool animate = true, double? y}) {
    final size = context.size;
    if (size == null) return;
    final s = scale ?? widget.controller.value.getMaxScaleOnAxis();
    final fy = y ?? widget.focusY;
    final target = Matrix4.identity()
      ..multiply(Matrix4.translationValues(size.width / 2 - worldPx.dx * kMapScale * s, size.height * fy - worldPx.dy * kMapScale * s, 0))
      ..multiply(Matrix4.diagonal3Values(s, s, 1));
    if (!animate) {
      widget.controller.value = target;
      return;
    }
    final from = widget.controller.value.clone();
    final ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
    final anim = CurvedAnimation(parent: ctrl, curve: Curves.easeOutCubic);
    anim.addListener(() {
      widget.controller.value = Matrix4Tween(begin: from, end: target).evaluate(anim);
    });
    ctrl.forward().whenComplete(ctrl.dispose);
  }

  void zoom(double f) {
    final size = context.size;
    if (size == null) return;
    final cur = widget.controller.value.getMaxScaleOnAxis();
    final ns = (cur * f).clamp(kMapMinZoom, kMapMaxZoom);
    final center = Offset(size.width / 2, size.height / 2);
    final scene = widget.controller.toScene(center);
    final target = Matrix4.identity()
      ..multiply(Matrix4.translationValues(center.dx - scene.dx * ns, center.dy - scene.dy * ns, 0))
      ..multiply(Matrix4.diagonal3Values(ns, ns, 1));
    final from = widget.controller.value.clone();
    final ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
    final anim = CurvedAnimation(parent: ctrl, curve: Curves.easeOutCubic);
    anim.addListener(() => widget.controller.value = Matrix4Tween(begin: from, end: target).evaluate(anim));
    ctrl.forward().whenComplete(ctrl.dispose);
  }

  /// Prepara el contorno del edificio seleccionado.
  void _syncOutline(Game g, Iso iso, int? lotId, bool reduce) {
    final key = lotId == null ? null : '$lotId:${lotSpriteState(g, lotId)}';
    if (key == _outlineKey) return;
    _outlineKey = key;
    _outline = null;
    if (lotId == null) {
      _pulse.stop();
      return;
    }
    final sp = iso.sprite(g.city.lots[lotId], lotSpriteState(g, lotId));
    if (sp == null) return;
    SpriteAtlas.instance.outline(sp.$1).then((img) {
      if (!mounted || _outlineKey != key) return;
      setState(() => _outline = img);
      if (reduce || !Gfx.pulse) {
        _pulse.value = 0;
      } else {
        _pulse.repeat(reverse: true);
        // En calidad media el pulso se para a los pocos segundos (no mantiene el mapa repintando).
        if (!Gfx.pulseForever) {
          Future.delayed(const Duration(milliseconds: 4200), () {
            if (mounted && _outlineKey == key) _pulse.animateTo(0, duration: const Duration(milliseconds: 300));
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final g = ref.watch(gameProvider);
    final ci = ref.watch(cityImageProvider);
    final layers = ref.watch(mapLayersProvider);
    final street = ref.watch(selectedStreetProvider);
    final reduce = g.settings.reduceMotion || MediaQuery.of(context).disableAnimations;
    final focus = widget.focusLot ?? g.selectedLot;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ci.sync(g);
      if (!_centered && ci.iso != null && mounted) {
        _centered = true;
        final lot = focus != null ? g.city.lots[focus] : null;
        final at = lot != null ? ci.iso!.top(lot, lotSpriteState(g, lot.id)) + const Offset(0, 24) : Offset(ci.iso!.width / 2, ci.iso!.height / 2);
        centerOn(at, scale: kMapStartZoom, animate: false);
      }
    });
    final img = ci.image;
    final iso = ci.iso;
    if (img == null || iso == null) {
      return const ColoredBox(
        color: Hc.bgDeep,
        child: Center(child: SizedBox(width: 26, height: 26, child: CircularProgressIndicator(color: Hc.acc, strokeWidth: 3))),
      );
    }
    final selLot = widget.focusLot ?? g.selectedLot;
    _syncOutline(g, iso, selLot, reduce);
    final w = iso.width * kMapScale;
    final h = iso.height * kMapScale;
    final showSmallPins = _zoom >= 0.8;

    // Pins: ruina, obra y en venta (más el seleccionado, siempre).
    final pins = <Widget>[];
    if (widget.showPins) {
      final ids = <int>{
        if (layers.mine) ...g.props.map((p) => p.lotId),
        if (layers.market) ...g.listings.map((l) => l.lotId),
      };
      final owned = layers.mine ? {for (final p in g.props) p.lotId} : const <int>{};
      for (final id in ids) {
        if (id == selLot) continue;
        // Con «Mis viviendas» activo, cada vivienda propia lleva su pin de estado.
        final pin = pinFor(g, id, any: owned.contains(id));
        // Las propias se ven a cualquier zoom; el resto, solo de cerca.
        if (pin == null || (!showSmallPins && !owned.contains(id))) continue;
        final lot = g.city.lots[id];
        pins.add(_ScaledAt(
          key: ValueKey('pin$id'),
          controller: widget.controller,
          at: iso.top(lot, lotSpriteState(g, id)) * kMapScale,
          anchorBottom: true,
          onTap: () => widget.onLot(lot),
          child: PopIn(key: ValueKey('pin$id${pin.$1.codePoint}'), child: MapPin(pin.$1, color: pin.$2)),
        ));
      }
      // Capa de propietarios: viviendas de los inversores rivales, cada uno con su color.
      if (layers.rivals) {
        for (final r in g.rivals) {
          for (final id in r.lots) {
            if (id == selLot || !showSmallPins) continue;
            final lot = g.city.lots[id];
            pins.add(_ScaledAt(
              key: ValueKey('rv$id'),
              controller: widget.controller,
              at: iso.top(lot, lotSpriteState(g, id)) * kMapScale,
              anchorBottom: true,
              onTap: () => widget.onLot(lot),
              child: MapPin(Icons.business_center_outlined, color: Color(r.color)),
            ));
          }
        }
      }
      if (selLot != null) {
        final lot = g.city.lots[selLot];
        final pin = pinFor(g, selLot, any: true)!;
        pins.add(_ScaledAt(
          key: const ValueKey('pinSel'),
          controller: widget.controller,
          at: iso.top(lot, lotSpriteState(g, selLot)) * kMapScale,
          anchorBottom: true,
          leftAnchor: MapPin.selSize / 2,
          onTap: () => widget.onLot(lot),
          child: PopIn(key: ValueKey('sel$selLot'), child: MapPin(pin.$1, color: pin.$2, selected: true, label: pinLabel(g, selLot))),
        ));
      }
    }

    return ColoredBox(
      color: const Color(0xFF0B1B1A),
      child: InteractiveViewer(
        transformationController: widget.controller,
        constrained: false,
        minScale: kMapMinZoom,
        maxScale: kMapMaxZoom,
        boundaryMargin: const EdgeInsets.all(240),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) => _tap(g, iso, d.localPosition / kMapScale),
          child: SizedBox(
            width: w,
            height: h,
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: RawImage(image: img, width: w, height: h, fit: BoxFit.fill, filterQuality: FilterQuality.none),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _SelectionPainter(
                        iso: iso,
                        city: g.city,
                        lot: selLot,
                        state: selLot == null ? 'normal' : lotSpriteState(g, selLot),
                        street: street,
                        outline: _outline,
                        pulse: _pulse,
                      ),
                    ),
                  ),
                ),
              ),
              if (g.settings.ambient && !reduce)
                Positioned.fill(
                  child: ValueListenableBuilder<GfxLevel>(
                    valueListenable: Gfx.level,
                    builder: (context, lv, _) => Gfx.ambient
                        ? AmbientLayer(
                            size: Size(w, h),
                            trees: _treePoints(g, iso),
                            roads: _roads(g, iso),
                            boats: _boats(g, iso),
                            rail: _rail(g, iso),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              if (layers.districts)
                for (final d in g.city.districts)
                  _ScaledAt(
                    controller: widget.controller,
                    at: iso.p(d.cx, d.cy) * kMapScale,
                    child: Stack(children: [
                      Text(d.name.toUpperCase(),
                          style: Ht.cap.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                              foreground: Paint()
                                ..style = PaintingStyle.stroke
                                ..strokeWidth = 4
                                ..strokeJoin = StrokeJoin.round
                                ..color = Hc.line,
                              shadows: const [Shadow(color: Color(0x99000000), offset: Offset(0, 2), blurRadius: 4)])),
                      Text(d.name.toUpperCase(),
                          style: Ht.cap.copyWith(color: Hc.ink, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                    ]),
                  ),
              ...pins,
            ]),
          ),
        ),
      ),
    );
  }

  List<(Offset, Offset)>? _roadsC;
  Object? _roadsCity;
  List<(Offset, Offset)> _roads(Game g, Iso iso) {
    if (_roadsC != null && identical(_roadsCity, g.city)) return _roadsC!;
    _roadsCity = g.city;
    final c = g.city;
    return _roadsC = [
      for (final s in c.streets)
        s.horizontal
            ? (iso.p(0, s.coord + 0.5) * kMapScale, iso.p(c.w.toDouble(), s.coord + 0.5) * kMapScale)
            : (iso.p(s.coord + 0.5, 0) * kMapScale, iso.p(s.coord + 0.5, c.h.toDouble()) * kMapScale),
    ];
  }

  List<Offset> _boats(Game g, Iso iso) {
    final c = g.city;
    final out = <Offset>[];
    for (var i = 0; i < 400 && out.length < 3; i++) {
      final x = hash2(i, c.seed) % c.w, y = hash2(c.seed, i) % c.h;
      // Mar abierto: agua sin tierra cerca.
      var open = c.t(x, y) == Tile.water;
      for (var d = 1; d <= 2 && open; d++) {
        if (c.t(x - d, y) != Tile.water || c.t(x, y - d) != Tile.water) open = false;
      }
      if (open && x < c.w && y < c.h) out.add(iso.p(x + 0.5, y + 0.5) * kMapScale);
    }
    return out;
  }

  (Offset, Offset)? _rail(Game g, Iso iso) {
    final c = g.city;
    for (var y = 0; y < c.h; y++) {
      var n = 0;
      for (var x = 0; x < c.w; x++) {
        if (c.t(x, y) == Tile.rail) n++;
      }
      if (n > c.w / 3) return (iso.p(0, y + 0.5) * kMapScale, iso.p(c.w.toDouble(), y + 0.5) * kMapScale);
    }
    return null;
  }

  List<Offset>? _trees;
  Object? _treesCity;
  List<Offset> _treePoints(Game g, Iso iso) {
    if (_trees != null && identical(_treesCity, g.city)) return _trees!;
    _treesCity = g.city;
    final ts = g.city.trees;
    final step = math.max(1, ts.length ~/ 40);
    return _trees = [for (var i = 0; i < ts.length; i += step) iso.p(ts[i].x, ts[i].y) * kMapScale];
  }

  void _tap(Game g, Iso iso, Offset q) {
    // Primero edificios (del más cercano al fondo), por píxel visible del sprite.
    final lots = List<Lot>.from(g.city.lots)..sort((a, b) => iso.depth(b).compareTo(iso.depth(a)));
    final st = ref.read(cityImageProvider).states;
    for (final l in lots) {
      final sp = iso.sprite(l, st[l.id] ?? 'normal');
      final hit = sp != null ? spriteHit(sp.$1, sp.$3, q, mirror: sp.$2) : iso.silhouette(l).contains(q);
      if (hit) {
        HapticFeedback.selectionClick();
        widget.onLot(l);
        return;
      }
    }
    final (tx, ty) = iso.tileAt(q);
    final t = g.city.t(tx, ty);
    if (Tile.isRoad(t)) {
      for (final s in g.city.streets) {
        if ((s.horizontal && s.coord == ty) || (!s.horizontal && s.coord == tx)) {
          HapticFeedback.selectionClick();
          widget.onStreet(s.id);
          return;
        }
      }
    }
    widget.onEmpty();
  }
}

/// Coloca un widget en coordenadas del mapa sin que crezca con el zoom.
class _ScaledAt extends StatelessWidget {
  final TransformationController controller;
  final Offset at;
  final Widget child;
  final bool anchorBottom;
  final VoidCallback? onTap;
  /// Si se da, el punto queda a esta distancia del borde izquierdo (pins con etiqueta).
  final double? leftAnchor;
  const _ScaledAt({super.key, required this.controller, required this.at, required this.child, this.anchorBottom = false, this.onTap, this.leftAnchor});
  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: at.dx,
      top: at.dy,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, c) {
          final s = controller.value.getMaxScaleOnAxis();
          final inv = (1 / s).clamp(0.3, 1.6);
          return Transform.scale(
            scale: inv,
            alignment: Alignment.topLeft,
            child: leftAnchor != null
                ? Transform.translate(
                    offset: Offset(-leftAnchor! - 4, 0),
                    child: FractionalTranslation(translation: Offset(0, anchorBottom ? -1.0 : -0.5), child: c),
                  )
                : FractionalTranslation(translation: Offset(-0.5, anchorBottom ? -1.0 : -0.5), child: c),
          );
        },
        child: GestureDetector(onTap: onTap, child: child),
      ),
    );
  }
}

class _SelectionPainter extends CustomPainter {
  final Iso iso;
  final CityMap city;
  final int? lot;
  final String state;
  final int? street;
  final ui.Image? outline;
  final Animation<double> pulse;
  _SelectionPainter({required this.iso, required this.city, this.lot, required this.state, this.street, this.outline, required this.pulse})
      : super(repaint: pulse);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(kMapScale);
    if (street != null) {
      final s = city.streets[street!];
      final p = Paint()..color = const Color(0x66E3A93B);
      final n = s.horizontal ? city.w : city.h;
      for (var i = 0; i < n; i++) {
        final x = s.horizontal ? i : s.coord;
        final y = s.horizontal ? s.coord : i;
        final t = city.t(x, y);
        if (t != Tile.road && t != Tile.avenue) continue;
        final a = iso.p(x.toDouble(), y.toDouble()), b = iso.p(x + 1.0, y.toDouble());
        final c = iso.p(x + 1.0, y + 1.0), d = iso.p(x.toDouble(), y + 1.0);
        canvas.drawPath(Path()..moveTo(a.dx, a.dy)..lineTo(b.dx, b.dy)..lineTo(c.dx, c.dy)..lineTo(d.dx, d.dy)..close(), p);
      }
    }
    if (lot != null && outline != null) {
      final sp = iso.sprite(city.lots[lot!], state);
      if (sp == null) return;
      // Opacidad 1 → 0,55 en 1,4 s (ida y vuelta).
      final op = 1 - 0.45 * pulse.value;
      final r = spriteRect(sp.$1, sp.$3, mirror: sp.$2);
      final p = Paint()
        ..filterQuality = FilterQuality.none
        ..color = Color.fromRGBO(255, 255, 255, op);
      canvas.save();
      if (sp.$2) {
        canvas.translate(r.right + 1, r.top - 1);
        canvas.scale(-1, 1);
        canvas.drawImage(outline!, Offset.zero, p);
      } else {
        canvas.drawImage(outline!, Offset(r.left - 1, r.top - 1), p);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_SelectionPainter o) => o.lot != lot || o.street != street || o.outline != outline || o.state != state;
}

/// Mapa de fondo para las hojas: la cámara deja el edificio a la vista por encima de la hoja.
class MapBackdrop extends StatefulWidget {
  final int lotId;
  final double focusY;
  const MapBackdrop({super.key, required this.lotId, this.focusY = 0.3});
  @override
  State<MapBackdrop> createState() => _MapBackdropState();
}

class _MapBackdropState extends State<MapBackdrop> {
  final _ctrl = TransformationController();
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MapView(
        controller: _ctrl,
        focusLot: widget.lotId,
        focusY: widget.focusY,
        onLot: (_) {},
        onStreet: (_) {},
        onEmpty: () {},
      );
}

/// Recorte del mapa alrededor de una parcela.
class MapCrop extends ConsumerWidget {
  final int lotId;
  final double height;
  final double zoom;
  const MapCrop({super.key, required this.lotId, this.height = 260, this.zoom = 2});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = ref.watch(gameProvider);
    final ci = ref.watch(cityImageProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) => ci.sync(g));
    final img = ci.image;
    final iso = ci.iso;
    if (img == null || iso == null) return SizedBox(height: height);
    final lot = g.city.lots[lotId];
    final b = iso.bounds(lot, lotSpriteState(g, lotId));
    final z = zoom.roundToDouble().clamp(1.0, 4.0);
    final c = b.center;
    return SizedBox(
      height: height,
      child: LayoutBuilder(builder: (context, cons) {
        final w = cons.maxWidth;
        return ClipRect(
          child: Stack(children: [
            Positioned(
              left: w / 2 - c.dx * z,
              top: height * 0.5 - c.dy * z,
              child: CustomPaint(
                size: Size(iso.width * z, iso.height * z),
                painter: _ImgPainter(img, z),
              ),
            ),
          ]),
        );
      }),
    );
  }
}

class _ImgPainter extends CustomPainter {
  final ui.Image img;
  final double zoom;
  _ImgPainter(this.img, this.zoom);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(zoom);
    canvas.drawImage(img, Offset.zero, Paint()..filterQuality = FilterQuality.none);
  }

  @override
  bool shouldRepaint(_ImgPainter o) => o.img != img || o.zoom != zoom;
}
