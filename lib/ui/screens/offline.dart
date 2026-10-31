import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../game/economy.dart';
import '../../game/engine.dart';
import '../../game/texts.dart';
import '../common.dart';
import '../widgets/atoms.dart';

import '../../core/texto.dart';
/// Bienvenido de nuevo: progreso sin conexión (tope de 8 h, solo cuadrillas).
class OfflineScreen extends ConsumerWidget {
  final OfflineReport report;
  const OfflineScreen({super.key, required this.report});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = ref.watch(gameProvider);
    final r = report;
    final net = r.rent + r.salesAmount - r.salaries - r.interest;
    final capped = r.away > r.counted;
    return Screen(
      dock: HsButton('Recoger', block: true, size: BtnSize.lg, onTap: () => Navigator.pop(context)),
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 30, 16, 16), children: [
        const Center(child: Cap('Bienvenido de nuevo', color: Hc.acc)),
        const SizedBox(height: 6),
        Center(child: Text('Fuera ${dur(r.away)}', style: Ht.display.copyWith(fontSize: 38))),
        const SizedBox(height: 4),
        Center(
          child: Text('En tu ciudad han pasado ${_gameSpan(r.counted)}',
              style: Ht.small.copyWith(fontWeight: FontWeight.w700), textAlign: TextAlign.center),
        ),
        const SizedBox(height: 18),
        Center(
          child: Pose(rz: -5, child: GlowText(money(net, sign: true), style: Ht.display.copyWith(fontSize: 50), color: net >= 0 ? Hc.acc : Hc.bad)),
        ),
        const SizedBox(height: 22),
        Panel(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Column(children: [
            KV('Rentas cobradas', money(r.rent), color: Hc.ok),
            if (r.sales > 0) KV('Ventas cerradas (${r.sales})', money(r.salesAmount), color: Hc.acc),
            if (r.salaries > 0) KV('Salarios', money(-r.salaries)),
            if (r.interest > 0) KV('Intereses', money(-r.interest)),
            KV('Trabajo de cuadrillas', '${intg(r.crewWork)} toques'),
            if (r.phasesDone > 0) KV('Fases terminadas', '${r.phasesDone}'),
            if (r.renosDone > 0) KV('Obras terminadas', '${r.renosDone}', color: Hc.ok),
            if (r.offers > 0) KV('Ofertas recibidas', '${r.offers}', color: Hc.info),
            if (r.tenants > 0) KV('Inquilinos nuevos', '${r.tenants}'),
            if (r.events > 0) KV('Eventos pendientes nuevos', '${r.events}', color: Hc.warn),
            KV('Efectivo ahora', money(g.cash), big: true),
          ]),
        ),
        const SizedBox(height: 12),
        if (capped)
          Note('Las cuadrillas y las rentas cuentan hasta 8 horas; los anuncios de venta, hasta 24. El toque manual no avanza sin conexión.',
              icon: Icons.schedule_rounded),
        if (!g.hasCrews)
          const Note('Sin cuadrillas, las obras no avanzan mientras no juegas. Llegan con la Empresa de reformas.', icon: Icons.groups_outlined),
        const SizedBox(height: 12),
        const Quote(Tx.offline),
      ]),
    );
  }
}

/// Tiempo de juego equivalente al tiempo fuera (sin conexión el juego va a 1 h = 1 mes).
String _gameSpan(Duration real) {
  final months = real.inSeconds / 3600 * Eco.offlineMonthsPerHour;
  if (months < 1) {
    final days = (months * 30).round();
    return '$days ${days == 1 ? 'día' : 'días'}';
  }
  final m = months.round();
  return '$m ${m == 1 ? 'mes' : 'meses'}';
}
