import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../game/city.dart';
import '../../game/model.dart';
import '../common.dart';
import '../map/city_render.dart';
import '../widgets/atoms.dart';
import '../widgets/overlays.dart';

/// Ciudades fundadas antes: siguen ahí, con sus viviendas, y la gestoría pasa el 15 % de las rentas.
class LegacyCitiesScreen extends ConsumerWidget {
  const LegacyCitiesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = ref.watch(gameProvider);
    final list = g.meta.legacy.reversed.toList();
    return Screen(
      child: Column(children: [
        const BackHeader('Mis ciudades', sub: 'Las anteriores siguen en pie'),
        Expanded(
          child: Body([
            StatGrid([
              Stat('Ciudades', '${list.length + 1}', color: Hc.acc),
              Stat('Renta legado', '${money(g.legacyRent, compact: true)}/mes', color: Hc.ok),
            ]),
            ListBlock([
              Li(
                lead: const IconBox(Icons.location_city_rounded, color: Hc.acc),
                title: g.city.name,
                sub: 'Ciudad actual · ${plural(g.props.length, 'vivienda', 'viviendas')}',
                trail: const Tag('Aquí', color: Hc.acc),
              ),
              for (var i = 0; i < list.length; i++)
                Li(
                  last: i == list.length - 1,
                  lead: const IconBox(Icons.history_edu_outlined, color: Hc.info),
                  title: list[i].name,
                  sub: '${plural(list[i].props.length, 'vivienda', 'viviendas')} · vale ${money(list[i].value, compact: true)} · ${money(list[i].rent * 0.15, compact: true)}/mes',
                  trail: const Icon(Icons.chevron_right_rounded, color: Hc.mut),
                  onTap: () => push(context, LegacyCityScreen(city: list[i])),
                ),
            ]),
            if (list.isEmpty)
              const Note('Cuando fundes una ciudad nueva, esta se quedará aquí para visitarla.', icon: Icons.info_outline),
            const Note('La gestoría administra tus viviendas de otras ciudades: cobra los alquileres y te pasa el 15 %. Puedes venderlas cuando quieras (comisión del 10 %).',
                icon: Icons.account_balance_outlined),
          ]),
        ),
      ]),
    );
  }
}

/// Visita a una ciudad anterior: el mapa tal como quedó y sus viviendas.
class LegacyCityScreen extends ConsumerStatefulWidget {
  final LegacyCity city;
  const LegacyCityScreen({super.key, required this.city});
  @override
  ConsumerState<LegacyCityScreen> createState() => _LegacyCityScreenState();
}

class _LegacyCityScreenState extends ConsumerState<LegacyCityScreen> {
  ui.Image? _img;

  @override
  void initState() {
    super.initState();
    _render();
  }

  Future<void> _render() async {
    final c = widget.city;
    final g = ref.read(gameProvider);
    final map = CityGen.generate(c.seed, name: c.name, version: c.version);
    final img = await CityRenderer.render(map, states: Map.of(c.states), theme: g.meta.mapTheme);
    if (!mounted) {
      img.dispose();
      return;
    }
    setState(() {
      _img?.dispose();
      _img = img;
    });
  }

  @override
  void dispose() {
    _img?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = ref.watch(gameProvider);
    final c = widget.city;
    final props = c.props.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Screen(
      child: Column(children: [
        BackHeader(c.name, sub: 'Dejaste ${money(c.netWorth, compact: true)}'),
        Expanded(
          child: Body([
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 260,
                decoration: BoxDecoration(color: Hc.panelIn, border: Border.all(color: Hc.line, width: 2), borderRadius: BorderRadius.circular(12)),
                child: _img == null
                    ? const Center(child: CircularProgressIndicator(color: Hc.acc))
                    : InteractiveViewer(
                        minScale: 1,
                        maxScale: 8,
                        child: SizedBox.expand(child: RawImage(image: _img, fit: BoxFit.contain, filterQuality: FilterQuality.none)),
                      ),
              ),
            ),
            StatGrid([
              Stat('Viviendas', '${props.length}'),
              Stat('Valor', money(c.value, compact: true), color: Hc.acc),
              Stat('Te llega', '${money(c.rent * 0.15, compact: true)}/mes', color: Hc.ok),
            ], columns: 3),
            if (props.isEmpty) const Note('Ya no te queda ninguna vivienda aquí.', icon: Icons.info_outline),
            if (props.isNotEmpty)
              ListBlock([
                for (var i = 0; i < props.length; i++)
                  Li(
                    last: i == props.length - 1,
                    lead: IconBox(props[i].rented ? Icons.key_rounded : Icons.home_outlined, color: props[i].rented ? Hc.ok : Hc.mut),
                    title: props[i].address,
                    sub: '${props[i].m2} m² · ${money(props[i].value, compact: true)}${props[i].rented ? ' · alquilada ${money(props[i].rent, compact: true)}/mes' : ''}',
                    trail: HsButton('Vender', size: BtnSize.xs, kind: BtnKind.sec, onTap: () async {
                      final p = props[i];
                      if (await confirm(context,
                          title: 'Vender en ${c.name}',
                          body: '${p.address}: recibes ${money(p.value * 0.9)} (la gestoría se queda el 10 %).',
                          ok: 'Vender')) {
                        g.sellLegacy(c, p);
                        await saveGame(ref);
                        if (mounted) _render();
                      }
                    }),
                  ),
              ]),
          ]),
        ),
      ]),
    );
  }
}
