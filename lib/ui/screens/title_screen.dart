import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/format.dart';
import '../../core/gfx.dart';
import '../../core/theme.dart';
import '../../services/audio.dart';
import '../../game/city.dart';
import '../../game/data.dart';
import '../../services/backend.dart';
import '../../services/storage.dart';
import '../../game/engine.dart';
import '../chrome.dart';
import '../common.dart';
import '../map/city_render.dart';
import 'auth.dart';
import 'eras.dart';
import 'more.dart';
import '../shell.dart';
import '../widgets/atoms.dart';
import '../widgets/overlays.dart';

/// Portada: continuar o empezar una partida nueva.
class TitleScreen extends ConsumerStatefulWidget {
  final bool hasSave;
  final VoidCallback onContinue;
  const TitleScreen({super.key, required this.hasSave, required this.onContinue});
  @override
  ConsumerState<TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends ConsumerState<TitleScreen> with SingleTickerProviderStateMixin {
  ui.Image? _img;
  Iso? _iso;
  late final AnimationController _pan = AnimationController(vsync: this, duration: const Duration(seconds: 40))..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    Music.play('menu');
    if (!Gfx.pulse) _pan.stop();
    _render();
  }

  Future<void> _render() async {
    final g = ref.read(gameProvider);
    final city = g.loaded ? g.city : CityGen.generate(20261022, version: 3);
    final img = await CityRenderer.render(city, theme: g.loaded ? g.meta.mapTheme : 'dia');
    if (!mounted) return;
    setState(() {
      _img = img;
      _iso = Iso(city);
    });
  }

  @override
  void dispose() {
    _pan.dispose();
    super.dispose();
  }

  Future<void> _newCity(BuildContext context, bool hasSave) async {
    if (hasSave &&
        !await confirm(context,
            title: 'Nueva ciudad',
            body: 'Se sustituye la partida actual. La reputación, logros, plantillas y cosméticos se conservan.',
            ok: 'Empezar',
            danger: true)) {
      return;
    }
    if (!context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NewGameScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final g = ref.watch(gameProvider);
    final hasSave = widget.hasSave && g.loaded && g.eraCfg == null;
    final mq = MediaQuery.of(context);
    // Horizontal (móvil tumbado): ciudad a pantalla completa y el panel en una columna a la derecha.
    final land = Lay.landscape(context);
    final panel = _panel(context, g, hasSave);
    return Scaffold(
      backgroundColor: Hc.bg,
      body: Stack(children: [
        // La ciudad ocupa toda la pantalla: sin logo, el mapa es la portada.
        if (_img != null && _iso != null)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _pan,
              builder: (context, _) => CustomPaint(painter: _CityPan(_img!, _iso!, _pan.value, land ? 0.5 : 0.42)),
            ),
          ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: land
                    ? const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        stops: [0, 0.5, 0.66],
                        colors: [Color(0x000E2221), Color(0x660E2221), Color(0xE60E2221)],
                      )
                    : const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0, 0.12, 0.56, 0.7, 0.82],
                        colors: [Color(0x73000000), Color(0x000E2221), Color(0x000E2221), Color(0xB30E2221), Hc.bg],
                      ),
              ),
            ),
          ),
        ),
        // Barra superior: cuenta y ajustes a la izquierda, fase a la derecha.
        Positioned(
          left: 12 + (land ? mq.padding.left : 0),
          right: 12,
          top: mq.padding.top + 10,
          child: Row(children: [
            SqButton(Icons.person_outline_rounded,
                glass: true, size: 44, tooltip: Backend.isAnonymous ? 'Iniciar sesión' : 'Cuenta', onTap: () => push(context, const AuthScreen())),
            const SizedBox(width: 8),
            SqButton(Icons.settings_outlined, glass: true, size: 44, tooltip: 'Ajustes', onTap: () => push(context, const SettingsScreen())),
            const Spacer(),
            if (hasSave)
              GlassBox(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.emoji_events_outlined, size: 18, color: Hc.acc),
                  const SizedBox(width: 6),
                  Text('Fase ${g.stage.index + 1}', style: Ht.numS.copyWith(color: Hc.acc)),
                ]),
              ),
          ]),
        ),
        // Panel casi abajo del todo (o a la derecha en horizontal).
        Positioned(
          left: land ? null : 12,
          right: 12 + (land ? mq.padding.right : 0),
          top: land ? mq.padding.top + 64 : null,
          bottom: (land ? 12 : 10) + mq.padding.bottom,
          width: land ? 380 : null,
          child: Align(
            alignment: land ? Alignment.centerRight : Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: SingleChildScrollView(
                reverse: true,
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  panel,
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      Backend.isAnonymous ? 'Invitado · v0.1' : '${Backend.email} · v0.1',
                      style: Ht.mini.copyWith(color: Hc.dim, fontSize: 10),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _panel(BuildContext context, Game g, bool hasSave) {
    final eras = _ChoiceTile(
      highlight: true,
      lead: const _PaperIcon(),
      title: 'Épocas',
      sub: ref.watch(entitlementsProvider).hasEras ? 'Seis épocas desbloqueadas' : '1929 gratis · 5 en el pack',
      badge: const Tag('Nuevo', color: Hc.acc),
      onTap: () => push(context, const HemerotecaScreen()),
    );
    final newCity = _ChoiceTile(
      lead: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(color: Hc.bgDeep, borderRadius: BorderRadius.circular(9), border: Border.all(color: Hc.line, width: 2)),
        child: const Icon(Icons.add_rounded, size: 20, color: Hc.ok),
      ),
      title: 'Nueva ciudad',
      sub: hasSave ? 'Otra semilla, mismo tú' : 'Semilla al azar',
      onTap: () => _newCity(context, hasSave),
    );
    return GlassPanel(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (hasSave) ...[
            Row(children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFF16322F),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Hc.line, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _img == null || _iso == null ? null : CustomPaint(painter: _CityThumb(_img!, _iso!)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Cap('Tu ciudad · fase ${g.stage.index + 1}'),
                  Text(g.city.name, style: Ht.h2, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(g.dateLabel, style: Ht.small, maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                const Cap('Patrimonio'),
                Text(money(g.netWorth, compact: true), style: Ht.numS.copyWith(color: Hc.acc)),
              ]),
            ]),
            const SizedBox(height: 10),
            HsButton('Continuar', size: BtnSize.lg, block: true, onTap: widget.onContinue),
            const SizedBox(height: 10),
            IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(flex: 100, child: newCity),
                const SizedBox(width: 8),
                Expanded(flex: 115, child: eras),
              ]),
            ),
          ] else ...[
            const Cap('Sin partida guardada'),
            const SizedBox(height: 2),
            Text('Compra ruinas. Reforma. Alquila o vende.', style: Ht.small),
            const SizedBox(height: 10),
            HsButton('Nueva ciudad', size: BtnSize.lg, block: true, onTap: () => _newCity(context, false)),
            const SizedBox(height: 10),
            eras,
          ],
        ]),
      ),
    );
  }
}

/// Botón-ficha de la portada (Nueva ciudad, Épocas).
class _ChoiceTile extends StatelessWidget {
  final Widget lead;
  final String title, sub;
  final Widget? badge;
  final bool highlight;
  final VoidCallback onTap;
  const _ChoiceTile({required this.lead, required this.title, required this.sub, required this.onTap, this.badge, this.highlight = false});
  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      child: GestureDetector(
        onTap: () {
          Sfx.play('pestana');
          onTap();
        },
        child: Stack(clipBehavior: Clip.none, children: [
          Container(
            constraints: const BoxConstraints(minHeight: 58),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: Hc.panelIn,
              borderRadius: BorderRadius.circular(Hr.tile),
              border: Border.all(color: highlight ? Hc.acc : Hc.line, width: 2),
              boxShadow: He.e1,
            ),
            child: Row(children: [
              lead,
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(title, style: Ht.numS.copyWith(height: 1), maxLines: 1)),
                  Text(sub, style: Ht.mini, maxLines: 2, overflow: TextOverflow.ellipsis),
                ]),
              ),
            ]),
          ),
          if (badge != null) Positioned(right: -6, top: -9, child: badge!),
        ]),
      ),
    );
  }
}

/// Periodiquito ladeado del botón de Épocas.
class _PaperIcon extends StatelessWidget {
  const _PaperIcon();
  @override
  Widget build(BuildContext context) => Transform.rotate(
        angle: -0.1,
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: Hc.paper, borderRadius: BorderRadius.circular(4), border: Border.all(color: Hc.line, width: 2)),
          child: const Text('El Correo\n1929',
              textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Fraktur', fontSize: 8, height: 1.05, color: Color(0xFF1E1A14))),
        ),
      );
}

/// Miniatura de la ciudad: un recorte del render del mapa.
class _CityThumb extends CustomPainter {
  final ui.Image img;
  final Iso iso;
  _CityThumb(this.img, this.iso);
  @override
  void paint(Canvas canvas, Size size) {
    const k = 0.32;
    canvas.save();
    canvas.translate(size.width / 2 - iso.width * 0.5 * k, size.height * 0.6 - iso.height * 0.5 * k);
    canvas.scale(k);
    canvas.drawImage(img, Offset.zero, Paint()..filterQuality = FilterQuality.low);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CityThumb o) => o.img != img;
}

class _CityPan extends CustomPainter {
  final ui.Image img;
  final Iso iso;
  final double t;
  /// Altura de la pantalla donde queda el centro de la ciudad.
  final double fy;
  _CityPan(this.img, this.iso, this.t, [this.fy = 0.55]);
  @override
  void paint(Canvas canvas, Size size) {
    const zoom = 1.0;
    final cx = iso.width * (0.38 + 0.24 * t);
    final cy = iso.height * 0.48;
    canvas.save();
    canvas.translate(size.width / 2 - cx * zoom, size.height * fy - cy * zoom);
    canvas.scale(zoom);
    canvas.drawImage(img, Offset.zero, Paint()..filterQuality = FilterQuality.none);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CityPan o) => o.t != t || o.img != img;
}

/// Nueva partida: se sortea la semilla.
class NewGameScreen extends ConsumerStatefulWidget {
  const NewGameScreen({super.key});
  @override
  ConsumerState<NewGameScreen> createState() => _NewGameScreenState();
}

class _NewGameScreenState extends ConsumerState<NewGameScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..forward();
  int _shown = 0;
  Timer? _t;
  late final int _seed;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _seed = (DateTime.now().microsecondsSinceEpoch ^ math.Random().nextInt(1 << 30)) & 0x7FFFFFFF;
    Future.microtask(() {
      ref.read(gameProvider).newGame(_seed);
      if (mounted) setState(() => _started = true);
    });
    _t = Timer.periodic(const Duration(milliseconds: 520), (t) {
      if (!mounted) return;
      setState(() => _shown++);
      if (_shown >= 4) t.cancel();
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = ref.watch(gameProvider);
    if (!_started) return const Scaffold(backgroundColor: Hc.bg);
    final zones = <Zone, int>{};
    for (final d in g.city.districts) {
      zones[d.zone] = (zones[d.zone] ?? 0) + 1;
    }
    final defects = g.props.where((p) => p.humidity || p.badWiring).length;
    final items = [
      (Icons.map_outlined, 'Mapa y zonas', '${g.city.name} · ${g.city.districts.length} barrios · ${g.city.lots.length} edificios'),
      (Icons.visibility_off_outlined, 'Defectos ocultos', defects == 0 ? 'Sorteados. Ya se verá.' : 'Sorteados. Alguno habrá.'),
      (Icons.show_chart_rounded, 'Mercado inicial', '${mph(g.phase).name} · precios ${mult(g.m)}'),
      (Icons.people_outline, 'Primeros compradores', 'Perfiles sorteados: nadie vive la misma partida'),
    ];
    final ready = _shown >= 4;
    return Scaffold(
      backgroundColor: Hc.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              child: ListView(children: [
            const Cap('Nueva partida', color: Hc.acc),
            const SizedBox(height: 4),
            Text('Sorteando la semilla', style: Ht.title),
            const SizedBox(height: 20),
            Center(
              child: AnimatedBuilder(
                animation: _spin,
                builder: (context, _) {
                  final v = Curves.easeOutCubic.transform(_spin.value);
                  return Transform.rotate(
                    angle: v * math.pi * 6,
                    child: Ring(v, size: 130, stroke: 12, color: Hc.acc, child: Transform.rotate(
                      angle: -v * math.pi * 6,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Cap('Semilla'),
                        Text(ready ? '$_seed'.substring(0, math.min(6, '$_seed'.length)) : '${(v * 999999).floor()}', style: Ht.numM),
                      ]),
                    )),
                  );
                },
              ),
            ),
            const SizedBox(height: 28),
            ListBlock([
                for (var i = 0; i < items.length; i++)
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: i < _shown ? 1 : 0.15,
                    child: Li(
                      last: i == items.length - 1,
                      lead: IconBox(items[i].$1, color: i < _shown ? Hc.acc : Hc.dim),
                      title: items[i].$2,
                      sub: i < _shown ? items[i].$3 : '…',
                    ),
                  ),
              ]),
            const SizedBox(height: 12),
            Text('«Dos pisos de 50 m² en ruina, en la zona universitaria, y ${money(g.cash)} de liquidez. Lo demás depende de ti y del mercado»',
                textAlign: TextAlign.center, style: Ht.quote),
              ]),
            ),
            const SizedBox(height: 12),
            HsButton('Empezar', size: BtnSize.lg, block: true, onTap: ready
                ? () async {
                    await Storage.save(g.toJson());
                    if (!context.mounted) return;
                    ref.read(tabProvider.notifier).state = 0;
                    Navigator.of(context).pushAndRemoveUntil(
                      PageRouteBuilder(
                        transitionDuration: const Duration(milliseconds: 500),
                        pageBuilder: (c, a, b) => const Shell(),
                        transitionsBuilder: (c, a, b, child) => FadeTransition(opacity: a, child: child),
                      ),
                      (_) => false,
                    );
                  }
                : null),
          ]),
        ),
      ),
    );
  }
}
