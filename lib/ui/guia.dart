import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/app.dart';
import '../app/providers.dart';
import '../core/i18n.dart';
import '../core/texto.dart';
import '../core/theme.dart';
import '../game/engine.dart';
import '../game/model.dart';
import '../services/telemetria.dart';
import 'widgets/atoms.dart';
import 'widgets/overlays.dart';

// =====================================================================
// Primera sesión guiada: «Paco, capataz» (propuesta A).
//
// La guía no lleva la cuenta de los pasos: los deduce del estado de la partida
// (¿hay obra?, ¿se ha terminado?, ¿está alquilada?) y señala el botón que toca en la
// pantalla que está delante. Así no se rompe si el jugador va por otro camino,
// cierra la app a medias o vuelve atrás.
// =====================================================================

/// Momento de la primera sesión.
enum GuiaFase { primeraObra, enObra, decidir, fin }

/// Botones y zonas que la guía puede señalar.
enum GuiaPunto {
  /// La pantalla del mapa (para el último paso, que no señala nada).
  mapa,
  reformar,
  lanzarObra,
  tablero,
  seguirObra,
  decidir,
  alquilarFin,
  decidirFicha,
  publicarAlquiler,
  publicarVenta,
}

/// Pantallas en las que el jugador tiene que tocar más cosas que el botón (la obra, el precio):
/// no se vela nada, se rodea el botón y el bocadillo se cierra con «Vale».
const _libres = {GuiaPunto.tablero, GuiaPunto.publicarAlquiler, GuiaPunto.publicarVenta};

/// Puntos que viven en el mapa: solo cuentan con la pestaña del mapa delante.
const _enMapa = {GuiaPunto.mapa, GuiaPunto.reformar, GuiaPunto.seguirObra, GuiaPunto.decidir};

GuiaFase? faseGuia(Game g) {
  if (!g.loaded || g.meta.guideDone || g.eraCfg != null) return null;
  final propias = g.props.where((p) => !p.isClient);
  if (g.renosDone == 0) {
    return propias.any((p) => p.state == PState.obra) ? GuiaFase.enObra : GuiaFase.primeraObra;
  }
  final decidido = g.stat('sales') > 0 ||
      propias.any((p) => p.state == PState.alquilada || p.state == PState.buscando || p.state == PState.venta);
  return decidido ? GuiaFase.fin : GuiaFase.decidir;
}

/// Vivienda de la que habla la guía en cada fase (para «Llévame»).
Property? _protagonista(Game g, GuiaFase f) {
  final estado = switch (f) {
    GuiaFase.primeraObra => PState.ruina,
    GuiaFase.enObra => PState.obra,
    GuiaFase.decidir => PState.lista,
    GuiaFase.fin => null,
  };
  if (estado == null) return null;
  for (final p in g.props) {
    if (!p.isClient && p.state == estado) return p;
  }
  return null;
}

class _Paso {
  final int n;
  final String titulo;
  final String texto;
  /// Botón propio del bocadillo (cuando no hay que tocar nada del juego).
  final String? boton;
  const _Paso(this.n, this.titulo, this.texto, {this.boton});
}

const _total = 5;

const _textos = <GuiaPunto, _Paso>{
  GuiaPunto.reformar: _Paso(1, 'Tu primera obra', 'Has heredado dos ruinas. Empieza por esta: toca Reformar.'),
  GuiaPunto.lanzarObra: _Paso(2, 'Lanzar la obra',
      'Te he dejado los niveles que pide la zona. La electricidad es obligatoria: sin luz no se alquila ni se vende. Con luz, a veces tampoco. Lanza la obra.'),
  GuiaPunto.tablero: _Paso(3, 'Manos a la obra', 'Ahora te toca a ti: toca la obra para avanzar. Cada oficio tiene su gesto y la energía se recupera sola.',
      boton: '¡A trabajar!'),
  GuiaPunto.seguirObra: _Paso(3, 'Manos a la obra', 'Tu obra te espera. Sin ti no avanza: entra y sigue.'),
  GuiaPunto.alquilarFin: _Paso(4, 'Alquilar o vender',
      'Obra terminada. Alquilar da renta cada mes; vender da dinero de golpe. Para empezar, alquila: es lo más seguro.'),
  GuiaPunto.decidir: _Paso(4, 'Alquilar o vender', 'Tu piso está listo. Toca Decidir y elige qué hacer con él.'),
  GuiaPunto.decidirFicha: _Paso(4, 'Alquilar o vender', 'Alquilar da renta cada mes; vender, dinero de golpe. Te marco lo que más conviene con este mercado.'),
  GuiaPunto.publicarAlquiler: _Paso(4, 'Alquilar o vender', 'Ajusta la renta y publica. Si pides demasiado, nadie llama.', boton: 'Vale'),
  GuiaPunto.publicarVenta: _Paso(4, 'Alquilar o vender', 'Ajusta el precio y publica. Pedir menos atrae compradores; pedir más, mejores ofertas.',
      boton: 'Vale'),
  GuiaPunto.mapa: _Paso(5, 'Y ahora, a esperar',
      'Hecho. El juego sigue aunque cierres la app y te aviso cuando haya novedades. Con lo que ganes, compra otra ruina en Mercado. Yo me voy a tomar un café.',
      boton: 'Entendido'),
};

/// Qué puntos buscar en cada fase, del más concreto al más general.
const _orden = <GuiaFase, List<GuiaPunto>>{
  GuiaFase.primeraObra: [GuiaPunto.lanzarObra, GuiaPunto.reformar],
  GuiaFase.enObra: [GuiaPunto.tablero, GuiaPunto.seguirObra],
  GuiaFase.decidir: [GuiaPunto.publicarAlquiler, GuiaPunto.publicarVenta, GuiaPunto.alquilarFin, GuiaPunto.decidirFicha, GuiaPunto.decidir],
  GuiaFase.fin: [GuiaPunto.mapa],
};

/// Paso del bocadillo cuando el jugador está en el mapa pero mirando otro edificio.
const _perdido = <GuiaFase, _Paso>{
  GuiaFase.primeraObra: _Paso(1, 'Tu primera obra', 'Tu primera ruina está en otra calle. Te llevo.', boton: 'Llévame'),
  GuiaFase.enObra: _Paso(3, 'Manos a la obra', 'Tienes una obra a medias. Te llevo.', boton: 'Llévame'),
  GuiaFase.decidir: _Paso(4, 'Alquilar o vender', 'Tu piso reformado espera una decisión. Te llevo.', boton: 'Llévame'),
};

class Guia {
  static final Map<GuiaPunto, Set<_GuiaMarcaState>> _vivos = {};

  /// Bocadillos que el jugador ya ha cerrado en esta sesión («¡A trabajar!», «Vale»).
  static final Set<GuiaPunto> _vistos = {};

  /// El mapa se registra aquí para poder centrar una vivienda («Llévame»).
  static void Function(int lotId)? alEnfocar;

  /// Vuelve a mostrar la guía desde el paso en que esté la ciudad.
  static void repetir(Game g) {
    g.meta.guideDone = false;
    _vistos.clear();
    g.touch();
  }
}

/// Marca un widget como punto que la guía puede señalar. Puede haber varios a la vez:
/// la guía elige el que esté en la pantalla de delante.
class GuiaMarca extends StatefulWidget {
  final GuiaPunto punto;
  final Widget child;
  const GuiaMarca(this.punto, {super.key, required this.child});
  @override
  State<GuiaMarca> createState() => _GuiaMarcaState();
}

class _GuiaMarcaState extends State<GuiaMarca> {
  ModalRoute<dynamic>? _ruta;

  @override
  void initState() {
    super.initState();
    Guia._vivos.putIfAbsent(widget.punto, () => {}).add(this);
  }

  @override
  void didUpdateWidget(GuiaMarca old) {
    super.didUpdateWidget(old);
    if (old.punto != widget.punto) {
      Guia._vivos[old.punto]?.remove(this);
      Guia._vivos.putIfAbsent(widget.punto, () => {}).add(this);
    }
  }

  @override
  void dispose() {
    Guia._vivos[widget.punto]?.remove(this);
    super.dispose();
  }

  /// Rectángulo en pantalla si está delante y visible.
  Rect? get _rect {
    if (!mounted || !(_ruta?.isCurrent ?? true)) return null;
    final ro = context.findRenderObject();
    if (ro is! RenderBox || !ro.attached || !ro.hasSize || ro.size.isEmpty) return null;
    return ro.localToGlobal(Offset.zero) & ro.size;
  }

  @override
  Widget build(BuildContext context) {
    // Depender de la ruta hace que esto se reconstruya cuando otra pantalla o un diálogo la tapa.
    _ruta = ModalRoute.of(context);
    return widget.child;
  }
}

/// Capa del capataz: por encima de todas las pantallas (va en MaterialApp.builder).
class GuiaCapa extends ConsumerStatefulWidget {
  const GuiaCapa({super.key});
  @override
  ConsumerState<GuiaCapa> createState() => _GuiaCapaState();
}

class _GuiaCapaState extends ConsumerState<GuiaCapa> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  GuiaPunto? _punto;
  Rect? _hueco;
  _Paso? _paso;
  int _ultimoContado = 0;

  @override
  void initState() {
    super.initState();
    // Cada fotograma se vuelve a medir: los botones se mueven con las transiciones y el scroll.
    _ticker = createTicker((_) => _medir());
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _medir() {
    final g = ref.read(gameProvider);
    final fase = faseGuia(g);
    GuiaPunto? punto;
    Rect? hueco;
    _Paso? paso;
    if (fase != null) {
      final tab = ref.read(tabProvider);
      for (final p in _orden[fase]!) {
        if (_enMapa.contains(p) && tab != 0) continue;
        if (Guia._vistos.contains(p) || (p == GuiaPunto.tablero && _obraEmpezada(g))) continue;
        Rect? r;
        for (final s in Guia._vivos[p] ?? const <_GuiaMarcaState>{}) {
          r = s._rect;
          if (r != null) break;
        }
        if (r == null) continue;
        punto = p;
        hueco = p == GuiaPunto.mapa ? null : r;
        paso = _textos[p];
        break;
      }
      // En el mapa, mirando otro edificio: ofrecer «Llévame».
      if (punto == null && fase != GuiaFase.fin && tab == 0 && _mapaDelante() && _protagonista(g, fase) != null) {
        punto = GuiaPunto.mapa;
        paso = _perdido[fase];
      }
    }
    if (punto != _punto || paso != _paso || !_igual(hueco, _hueco)) {
      setState(() {
        _punto = punto;
        _hueco = hueco;
        _paso = paso;
      });
      if (paso != null && paso.n > _ultimoContado) {
        _ultimoContado = paso.n;
        Telemetria.evento('guia', {'paso': paso.n});
      }
    }
  }

  bool _mapaDelante() {
    for (final s in Guia._vivos[GuiaPunto.mapa] ?? const <_GuiaMarcaState>{}) {
      if (s._rect != null) return true;
    }
    return false;
  }

  static bool _obraEmpezada(Game g) {
    for (final p in g.props) {
      final r = p.reno;
      if (!p.isClient && r != null && r.done.values.any((v) => v > 0)) return true;
    }
    return false;
  }

  static bool _igual(Rect? a, Rect? b) {
    if (a == null || b == null) return a == b;
    return (a.left - b.left).abs() < 0.5 && (a.top - b.top).abs() < 0.5 && (a.width - b.width).abs() < 0.5 && (a.height - b.height).abs() < 0.5;
  }

  void _saltar(Game g) {
    Telemetria.evento('guia_saltar', {'paso': _paso?.n ?? 0});
    g.meta.guideDone = true;
    g.touch();
    final c = navKey.currentContext;
    if (c != null) toast(c, 'Puedes repetir la guía en Más → Ajustes');
  }

  void _boton(Game g, GuiaFase? fase) {
    switch (_punto) {
      case GuiaPunto.tablero || GuiaPunto.publicarAlquiler || GuiaPunto.publicarVenta:
        Guia._vistos.add(_punto!);
        _medir();
      case GuiaPunto.mapa when fase == GuiaFase.fin:
        Telemetria.evento('guia_fin');
        g.meta.guideDone = true;
        g.touch();
      case GuiaPunto.mapa:
        final p = fase == null ? null : _protagonista(g, fase);
        if (p != null) Guia.alEnfocar?.call(p.lotId);
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = ref.watch(gameProvider);
    final fase = faseGuia(g);
    if (fase == null) {
      if (_ticker.isActive) _ticker.stop();
      if (_punto != null) {
        _punto = null;
        _hueco = null;
        _paso = null;
      }
      return const SizedBox.shrink();
    }
    if (!_ticker.isActive) _ticker.start();
    final paso = _paso;
    if (paso == null) return const SizedBox.shrink();

    final mq = MediaQuery.of(context);
    final hueco = _hueco?.inflate(6);
    // Con hueco, todo lo demás queda velado y no responde: solo se puede tocar lo señalado.
    // Sin hueco: el último paso vela la pantalla; «Llévame» solo flota.
    final libre = _libres.contains(_punto);
    final velo = (hueco != null && !libre) || fase == GuiaFase.fin;
    final arriba = hueco == null ? fase != GuiaFase.fin : hueco.center.dy > mq.size.height * 0.5;

    final tarjeta = _Bocadillo(
      paso: paso,
      onBoton: paso.boton == null ? null : () => _boton(g, fase),
      onSaltar: fase == GuiaFase.fin ? null : () => _saltar(g),
    );

    final ancho = math.min(mq.size.width - 36, 420.0);
    final izq = (mq.size.width - ancho) / 2;
    Widget colocada;
    if (hueco == null) {
      colocada = fase == GuiaFase.fin
          ? Center(child: SizedBox(width: ancho, child: tarjeta))
          : Positioned(left: izq, width: ancho, top: mq.padding.top + 120, child: tarjeta);
    } else if (arriba) {
      colocada = Positioned(left: izq, width: ancho, bottom: mq.size.height - hueco.top + 22, child: tarjeta);
    } else {
      colocada = Positioned(left: izq, width: ancho, top: hueco.bottom + 22, child: tarjeta);
    }

    return Material(
      type: MaterialType.transparency,
      child: Stack(children: [
        if (velo)
          Positioned.fill(child: CustomPaint(painter: _Velo(hueco: hueco)))
        else if (hueco != null)
          // Sin velo: solo el borde dorado, y todo sigue respondiendo.
          Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _Velo(hueco: hueco, soloBorde: true)))),
        if (hueco != null)
          Positioned(
            left: (hueco.center.dx - 11).clamp(izq + 16, izq + ancho - 38),
            top: arriba ? hueco.top - 22 : hueco.bottom + 8,
            child: IgnorePointer(child: CustomPaint(size: const Size(22, 14), painter: _Flecha(abajo: arriba))),
          ),
        colocada,
      ]),
    );
  }
}

/// Velo oscuro con un hueco redondeado y borde dorado alrededor de lo señalado.
/// Fuera del hueco, los toques se quedan aquí; dentro, pasan al juego.
class _Velo extends CustomPainter {
  final Rect? hueco;
  final bool soloBorde;
  _Velo({required this.hueco, this.soloBorde = false});

  RRect? get _r => hueco == null ? null : RRect.fromRectAndRadius(hueco!, const Radius.circular(14));

  @override
  void paint(Canvas canvas, Size size) {
    final todo = Path()..addRect(Offset.zero & size);
    final r = _r;
    if (!soloBorde) {
      final velo = r == null ? todo : Path.combine(PathOperation.difference, todo, Path()..addRRect(r));
      canvas.drawPath(velo, Paint()..color = const Color(0xC2050B0B));
    }
    if (r != null) {
      canvas.drawRRect(
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = Hc.acc);
    }
  }

  @override
  bool? hitTest(Offset position) => !(_r?.contains(position) ?? false);

  @override
  bool shouldRepaint(_Velo old) => old.hueco != hueco || old.soloBorde != soloBorde;
}

class _Flecha extends CustomPainter {
  final bool abajo;
  const _Flecha({required this.abajo});
  @override
  void paint(Canvas canvas, Size size) {
    final p = Path();
    if (abajo) {
      p
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height);
    } else {
      p
        ..moveTo(0, size.height)
        ..lineTo(size.width, size.height)
        ..lineTo(size.width / 2, 0);
    }
    p.close();
    canvas.drawPath(p, Paint()..color = Hc.acc);
  }

  @override
  bool shouldRepaint(_Flecha old) => old.abajo != abajo;
}

/// Bocadillo de Paco: icono, nombre, paso, texto, puntos de progreso y «Saltar guía».
class _Bocadillo extends StatelessWidget {
  final _Paso paso;
  final VoidCallback? onBoton;
  final VoidCallback? onSaltar;
  const _Bocadillo({required this.paso, this.onBoton, this.onSaltar});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        color: Hc.panel,
        borderRadius: BorderRadius.circular(Hr.lg),
        border: Border.all(color: Hc.line, width: 2),
        boxShadow: He.e2,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          const IconBox(Icons.engineering_outlined, color: Hc.acc, size: 40, solid: true),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('Paco, capataz', style: Ht.h2.copyWith(height: 1)),
              const SizedBox(height: 2),
              Text(tr('Paso ${paso.n} de $_total · ${paso.titulo}').toUpperCase(), style: Ht.cap),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        Semantics(liveRegion: true, child: Text(paso.texto, style: Ht.body.copyWith(height: 1.45))),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: Semantics(
              label: tr('Paso ${paso.n} de $_total'),
              child: Row(children: [
                for (var i = 1; i <= _total; i++) ...[
                  Container(
                    width: i == paso.n ? 22 : 6,
                    height: 6,
                    decoration: BoxDecoration(color: i <= paso.n ? Hc.acc : Hc.lineSoft, borderRadius: BorderRadius.circular(3)),
                  ),
                  if (i < _total) const SizedBox(width: 6),
                ],
              ]),
            ),
          ),
          if (onSaltar != null)
            TextButton(
              onPressed: onSaltar,
              style: TextButton.styleFrom(minimumSize: const Size(44, 44), foregroundColor: Hc.mut),
              child: Text('SALTAR GUÍA', style: Ht.cap.copyWith(fontSize: 11, letterSpacing: 1)),
            ),
          if (onBoton != null) ...[
            const SizedBox(width: 6),
            HsButton(paso.boton!, size: BtnSize.sm, onTap: onBoton),
          ],
        ]),
      ]),
    );
  }
}
