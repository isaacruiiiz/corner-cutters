import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/texto.dart';
import '../../core/theme.dart';
import '../../services/config.dart';
import '../../services/social.dart';
import '../../services/telemetria.dart';
import 'atoms.dart';
import 'overlays.dart';

/// Datos de una venta cerrada para la tarjeta de compartir.
class VentaRecibo {
  final String ciudad;
  final String fecha;
  final String direccion;
  final double compra;
  final double obra;
  final double venta;
  final double beneficio;
  const VentaRecibo({
    required this.ciudad,
    required this.fecha,
    required this.direccion,
    required this.compra,
    required this.obra,
    required this.venta,
    required this.beneficio,
  });

  /// Frase al pie según lo bien que ha salido.
  String get frase {
    final pagado = compra + obra;
    final margen = pagado <= 0 ? 0.0 : beneficio / pagado;
    if (margen >= 1) return 'Comprar barato tiene estas cosas.';
    if (margen >= 0.4) return 'Sin luz no se vendía; con luz, por poco.';
    if (margen > 0) return 'Ganar es ganar. Aunque sea poco.';
    return 'Hay ventas que se cuentan y otras que se comparten.';
  }
}

/// Medida de la tarjeta en puntos (4:5). Se exporta a 1080×1350.
const _ancho = 432.0;
const _alto = 540.0;
const _escala = 1080 / _ancho;

/// Recibo de la venta: papel crema algo torcido sobre el teal del juego.
class ReciboVenta extends StatelessWidget {
  final VentaRecibo v;
  const ReciboVenta(this.v, {super.key});

  @override
  Widget build(BuildContext context) {
    final num = Ht.numS.copyWith(color: Hc.onPaper, fontSize: 20, height: 1);
    final fila = Ht.body.copyWith(color: Hc.onPaper, fontSize: 13, fontWeight: FontWeight.w600);
    final cap = Ht.cap.copyWith(color: Hc.paperMut, fontSize: 10);
    final web = Uri.tryParse(AppConfig.current.webUrl)?.host ?? '';
    Widget linea(String concepto, String cifra) => Row(children: [
          Expanded(child: Text(concepto, style: fila, maxLines: 1, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          Flexible(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerRight, child: Text(cifra, style: num))),
        ]);

    return SizedBox(
      width: _ancho,
      height: _alto,
      child: ColoredBox(
        color: Hc.bg,
        // Si algo no cabe (cifras enormes, direcciones largas), el papel entero se encoge.
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Transform.rotate(
            angle: -3 * 3.14159265 / 180,
            child: Container(
              width: 296,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              decoration: BoxDecoration(
                color: Hc.paper,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Hc.line, width: 2),
                boxShadow: const [BoxShadow(color: Color(0x8C000000), offset: Offset(0, 6))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Corner Cutters', style: Ht.title.copyWith(color: Hc.onPaper, fontSize: 30, height: 0.95)),
                      const SizedBox(height: 2),
                      Text('${v.ciudad} · ${v.fecha}'.toUpperCase(), style: cap, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ]),
                  ),
                  // 98×118 px a escala 1:1 en la imagen exportada (pixel art sin suavizar).
                  Image.asset('assets/branding/logo/emblema_1x.png',
                      width: 98 / _escala, height: 118 / _escala, filterQuality: FilterQuality.none, excludeFromSemantics: true),
                ]),
                const SizedBox(height: 10),
                const _Corte(),
                const SizedBox(height: 10),
                Text(v.direccion, style: Ht.h2.copyWith(color: Hc.onPaper, fontSize: 22, height: 1), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 10),
                linea('Compra', money(-v.compra)),
                const SizedBox(height: 4),
                linea('Obra, a mano', money(-v.obra)),
                const SizedBox(height: 4),
                linea('Precio de venta', money(v.venta)),
                const SizedBox(height: 10),
                const _Corte(),
                const SizedBox(height: 8),
                Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                  Expanded(child: Text('BENEFICIO', style: cap.copyWith(color: Hc.onPaper, fontSize: 11))),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(money(v.beneficio, sign: true), style: Ht.numXl.copyWith(color: Hc.onPaper, fontSize: 46, height: 0.9)),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                Text(v.frase, style: Ht.small.copyWith(color: Hc.paperMut)),
                const SizedBox(height: 10),
                const _Corte(),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: Text('GRACIAS POR ESPECULAR', style: cap.copyWith(color: Hc.onPaper), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  if (web.isNotEmpty) Text(web, style: Ht.mini.copyWith(color: Hc.onPaper, fontWeight: FontWeight.w700)),
                ]),
              ]),
            ),
          ),
        ),
        ),
      ),
    );
  }
}

/// Línea discontinua de ticket.
class _Corte extends StatelessWidget {
  const _Corte();
  @override
  Widget build(BuildContext context) => SizedBox(height: 2, child: CustomPaint(painter: _CortePainter()));
}

class _CortePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Hc.onPaper
      ..strokeWidth = 2;
    for (var x = 0.0; x < size.width; x += 9) {
      canvas.drawLine(Offset(x, 1), Offset((x + 5).clamp(0, size.width), 1), p);
    }
  }

  @override
  bool shouldRepaint(_CortePainter old) => false;
}

/// Vista previa del recibo y botón para compartirlo como imagen.
Future<void> compartirVenta(BuildContext context, VentaRecibo v) {
  final clave = GlobalKey();
  return showHsDialog(context, builder: (ctx) {
    final alto = MediaQuery.of(ctx).size.height * 0.5;
    var enviando = false;
    return StatefulBuilder(builder: (ctx, setState) {
      Future<void> enviar() async {
        if (enviando) return;
        setState(() => enviando = true);
        try {
          final ro = clave.currentContext?.findRenderObject();
          if (ro is! RenderRepaintBoundary) return;
          final img = await ro.toImage(pixelRatio: _escala);
          final datos = await img.toByteData(format: ui.ImageByteFormat.png);
          img.dispose();
          if (datos == null || !ctx.mounted) return;
          final texto = '${tr('He vendido ${v.direccion} por ${money(v.venta)} en Corner Cutters: ${money(v.beneficio)} de beneficio.')} '
                  '${AppConfig.current.webUrl}'
              .trim();
          final origen = origenDe(ctx);
          Telemetria.evento('compartir', {'que': 'venta'});
          await Social.compartirImagen(datos.buffer.asUint8List(), texto, origen: origen);
          if (ctx.mounted) Navigator.pop(ctx);
        } catch (e) {
          if (ctx.mounted) toast(ctx, 'No se ha podido preparar la imagen', error: true);
        } finally {
          if (ctx.mounted) setState(() => enviando = false);
        }
      }

      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Text('Compartir la venta', style: Ht.h2),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: alto),
          child: AspectRatio(
            aspectRatio: _ancho / _alto,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Hr.md),
              child: FittedBox(
                child: RepaintBoundary(key: clave, child: ReciboVenta(v)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: HsButton('Cancelar', kind: BtnKind.sec, block: true, onTap: () => Navigator.pop(ctx))),
          const SizedBox(width: 10),
          Expanded(
            child: HsButton('Compartir', block: true, icon: Icons.ios_share_rounded, loading: enviando, onTap: () {
              HapticFeedback.selectionClick();
              enviar();
            }),
          ),
        ]),
      ]);
    });
  });
}
