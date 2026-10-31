import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../game/engine.dart';
import '../../services/audio.dart';
import '../../services/entitlements.dart';
import '../screens/obra.dart';
import 'atoms.dart';

/// Impulsos opcionales (con anuncio o, el café, gratis con la versión premium).
enum Boost { obra, rentas, ventas, cafe, energia }

class BoostInfo {
  final String title;
  final String short;
  final String desc;
  final IconData icon;
  final Color color;
  const BoostInfo(this.title, this.short, this.desc, this.icon, this.color);
}

const boostInfo = <Boost, BoostInfo>{
  Boost.obra: BoostInfo('Obra ×2 durante 15 min', 'Obra ×2', 'Toques y cuadrillas', Icons.speed_rounded, Hc.acc),
  Boost.rentas: BoostInfo('Rentas +50 % durante 30 min', 'Rentas +50 %', 'Todas las viviendas alquiladas', Icons.payments_outlined, Hc.ok),
  Boost.ventas: BoostInfo('Atraer compradores 20 min', 'Visitas ×2', 'El doble de visitas en lo que tengas en venta', Icons.campaign_outlined, Hc.info),
  Boost.cafe: BoostInfo('Café para todos', 'Café', 'Todas las cuadrillas recuperan su jornada', Icons.coffee_outlined, Color(0xFFB98A5A)),
  Boost.energia: BoostInfo('Energía al máximo', 'Energía', 'Tu energía de obra, llena', Icons.bolt_rounded, Hc.warn),
};

/// Fin del impulso (reloj real) o 0 si es instantáneo.
int boostUntil(Game g, Boost b) => switch (b) {
      Boost.obra => g.boostWorkUntil,
      Boost.rentas => g.boostRentUntil,
      Boost.ventas => g.boostSaleUntil,
      _ => 0,
    };

bool boostActive(Game g, Boost b) => boostUntil(g, b) > nowMs();

/// ¿Tiene sentido ofrecerlo ahora?
bool boostUseful(Game g, Boost b) => switch (b) {
      Boost.obra => g.activeRenos > 0,
      Boost.rentas => g.props.any((p) => p.tenant != null),
      Boost.ventas => g.props.any((p) => p.state.name == 'venta'),
      Boost.cafe => g.crews.isNotEmpty && g.crews.any((c) => c.energy < g.crewMax(c) * 0.6),
      Boost.energia => g.energy < Game.maxEnergy * 0.5,
    };

/// Activa un impulso: anuncio (o gratis si es café con premium).
Future<void> runBoost(BuildContext context, Game g, Boost b) async {
  if (boostActive(g, b)) return;
  final free = b == Boost.cafe && g.cafeFree;
  if (!free && !await showAdPlaceholder(context)) return;
  switch (b) {
    case Boost.obra:
      g.boostWork();
    case Boost.rentas:
      g.boostRent();
    case Boost.ventas:
      g.boostSale();
    case Boost.cafe:
      g.cafe(premium: free);
    case Boost.energia:
      g.refillEnergy();
  }
  Sfx.play('impulso');
  HapticFeedback.mediumImpact();
}

/// Oferta contextual compacta: aparece justo donde el impulso sirve.
class BoostOffer extends StatelessWidget {
  final Game g;
  final Boost b;
  const BoostOffer(this.g, this.b, {super.key});
  @override
  Widget build(BuildContext context) {
    final i = boostInfo[b]!;
    if (boostActive(g, b)) {
      return Tag('${i.short} · ${dur(Duration(milliseconds: boostUntil(g, b) - nowMs()))}', color: i.color, icon: i.icon);
    }
    final free = b == Boost.cafe && g.cafeFree;
    return HsButton(i.short, kind: BtnKind.sec, size: BtnSize.xs, icon: free || Entitlements.instance.sinAnuncios ? i.icon : Icons.play_circle_outline_rounded,
        price: free ? 'gratis' : null, onTap: () => runBoost(context, g, b));
  }
}

/// Chips con los impulsos activos y su cuenta atrás (bajo la fila de fecha).
class BoostChips extends StatefulWidget {
  final Game g;
  const BoostChips(this.g, {super.key});
  @override
  State<BoostChips> createState() => _BoostChipsState();
}

class _BoostChipsState extends State<BoostChips> {
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && Boost.values.any((b) => boostActive(widget.g, b))) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = Boost.values.where((b) => boostActive(widget.g, b)).toList();
    if (active.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 6, runSpacing: 6, children: [
      for (final b in active)
        GlassBox(
          height: 26,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(boostInfo[b]!.icon, size: 14, color: boostInfo[b]!.color),
            const SizedBox(width: 4),
            Text('${boostInfo[b]!.short} · ${dur(Duration(milliseconds: boostUntil(widget.g, b) - nowMs()))}',
                style: Ht.small.copyWith(fontSize: 11, fontWeight: FontWeight.w700, color: Hc.ink, height: 1)),
          ]),
        ),
    ]);
  }
}

/// Hoja con todos los impulsos (se abre desde el raíl del mapa).
class BoostsSheet extends StatelessWidget {
  final Game g;
  const BoostsSheet({super.key, required this.g});
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: g,
      builder: (context, _) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Text('Impulsos', style: Ht.title),
        const SizedBox(height: 4),
        Text(
            Entitlements.instance.sinAnuncios
                ? 'Eres Pro: se activan al momento, sin anuncio.'
                : g.meta.passPremium
                    ? 'Con anuncio opcional. El café es gratis cada 30 min con premium.'
                    : 'Con anuncio opcional. Nunca obligatorio.',
            style: Ht.small),
        const SizedBox(height: 12),
        ListBlock([
          for (final b in Boost.values)
            if (b != Boost.cafe || g.hasCrews)
              _row(context, b, last: b == Boost.values.last),
        ]),
      ]),
    );
  }

  Widget _row(BuildContext context, Boost b, {bool last = false}) {
    final i = boostInfo[b]!;
    final on = boostActive(g, b);
    final free = b == Boost.cafe && g.cafeFree;
    final useful = boostUseful(g, b);
    return Li(
      last: last,
      lead: IconBox(i.icon, color: i.color),
      title: i.title,
      sub: on ? 'Activo · quedan ${dur(Duration(milliseconds: boostUntil(g, b) - nowMs()))}' : (useful ? i.desc : '${i.desc} · ahora no hace falta'),
      trail: HsButton(free ? 'Gratis' : 'Ver', size: BtnSize.xs, kind: useful ? BtnKind.primary : BtnKind.sec, onTap: on ? null : () => runBoost(context, g, b)),
    );
  }
}

/// Número de impulsos útiles ahora (para el punto del raíl).
int usefulBoosts(Game g) => Boost.values.where((b) => !boostActive(g, b) && boostUseful(g, b)).length;
