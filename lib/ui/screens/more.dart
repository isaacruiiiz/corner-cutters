import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app.dart';
import '../../app/providers.dart';
import '../../core/format.dart';
import '../../core/gfx.dart';
import '../../core/theme.dart';
import '../../services/audio.dart';
import '../widgets/boosts.dart';
import '../../game/data.dart';
import '../../game/engine.dart';
import '../../game/model.dart';
import '../../services/backend.dart';
import '../../services/storage.dart';
import '../common.dart';
import '../widgets/atoms.dart';
import '../widgets/overlays.dart';
import 'auth.dart';
import 'district.dart';
import 'admin.dart';
import 'eras.dart';
import 'premium.dart';
import 'legacy.dart';
import 'market.dart';
import 'pending.dart';
import 'portfolio.dart';
import 'title_screen.dart';

import '../../core/texto.dart';
import '../../core/i18n.dart';
/// Pestaña "Más": rejilla de accesos (progreso, metajuego, cuenta y ajustes).
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = ref.watch(gameProvider);
    final alias = ref.watch(aliasProvider);
    final claim = g.missions.where((m) => m.done && !m.claimed).length;
    Widget tile(IconData i, String t, String s, VoidCallback onTap, {int badge = 0, bool dim = false}) => _GridTile(
          icon: i,
          title: t,
          sub: s,
          badge: badge,
          dim: dim,
          onTap: onTap,
        );
    Widget pair(Widget a, Widget b) => IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(child: a), const SizedBox(width: 8), Expanded(child: b)]));
    return Screen(
      safeBottom: false,
      dock: Row(children: [
        Expanded(
            child: HsButton('Cuenta', kind: BtnKind.sec, size: BtnSize.sm, block: true, icon: Icons.person_outline, onTap: () => push(context, const AccountScreen()))),
        const SizedBox(width: 8),
        Expanded(
            child:
                HsButton('Ajustes', kind: BtnKind.sec, size: BtnSize.sm, block: true, icon: Icons.settings_outlined, onTap: () => push(context, const SettingsScreen()))),
      ]),
      child: Column(children: [
        TabHeader('Más', trail: [Tag('Fase ${g.stage.index + 1} · ${stageInfo[g.stage]!.name}', color: Hc.acc)]),
        Expanded(
          child: Body([
            StatTile(
              onTap: () => push(context, const PhasesScreen()),
              child: Row(children: [
                Avatar(alias, color: Hc.acc, size: 38),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('$alias · Fase ${g.stage.index + 1}', style: Ht.numS, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('${stageInfo[g.stage]!.name} · ${plural(g.props.length, 'propiedad', 'propiedades')}', style: Ht.mini),
                  ]),
                ),
              ]),
            ),
            if (g.eraCfg != null)
              StatTile(
                border: Hc.acc,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    const IconBox(Icons.history_edu_outlined, color: Hc.acc, size: 38),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Estás en ${g.eraCfg!.id} · ${g.eraCfg!.name}', style: Ht.card, maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(g.eraOver ? 'Época terminada' : 'Tu ciudad principal te espera tal cual', style: Ht.mini),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: HsButton(g.eraOver ? 'Resultado' : 'Hemeroteca', kind: BtnKind.sec, size: BtnSize.sm, block: true,
                          onTap: () => g.eraOver ? showEraEndDialog(context, ref, record: false) : push(context, const HemerotecaScreen())),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: HsButton('Mi ciudad', size: BtnSize.sm, block: true, icon: Icons.home_outlined, onTap: () => leaveEra(context, ref))),
                  ]),
                ]),
              )
            else
              StatTile(
                onTap: () => push(context, const HemerotecaScreen()),
                child: Row(children: [
                  const IconBox(Icons.history_edu_outlined, color: Hc.acc, size: 38),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Épocas · Hemeroteca', style: Ht.card, maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(ref.watch(entitlementsProvider).hasEras ? 'Seis épocas desbloqueadas' : 'Juega 1929 gratis · cinco épocas más en el pack', style: Ht.mini),
                    ]),
                  ),
                  const Tag('Nuevo', color: Hc.acc),
                ]),
              ),
            if (ref.watch(entitlementsProvider).isAdmin)
              StatTile(
                onTap: () => push(context, const AdminScreen()),
                child: Row(children: [
                  const IconBox(Icons.admin_panel_settings_outlined, color: Hc.info, size: 38),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Panel admin', style: Ht.card),
                      Text('Usuarios, roles y regalos del pack', style: Ht.mini),
                    ]),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Hc.mut),
                ]),
              ),
            pair(
              tile(Icons.apartment_rounded, 'Cartera', '${plural(g.props.length, 'vivienda', 'viviendas')} · ${money(g.monthlyRent, compact: true)}/mes',
                  () => push(context, const PortfolioScreen())),
              tile(Icons.track_changes_rounded, 'Objetivos', '${g.missions.where((m) => m.done).length} de ${g.missions.length} hoy',
                  () => push(context, const ObjectivesScreen()), badge: claim),
            ),
            pair(
              tile(Icons.inbox_outlined, 'Pendiente', 'Eventos y ofertas', () => push(context, const PendingScreen()), badge: g.events.length + g.offers.length),
              tile(Icons.flag_outlined, 'Fases', stageInfo[g.stage]!.name, () => push(context, const PhasesScreen())),
            ),
            pair(
              tile(Icons.shopping_bag_outlined, 'Tienda', 'Fachadas y estilos', () => push(context, const ShopScreen())),
              tile(Icons.map_outlined, 'Barrios', '${g.city.districts.length} en ${g.city.name}', () => push(context, const DistrictsScreen())),
            ),
            pair(
              tile(Icons.bolt_rounded, 'Impulsos', g.workBoost || g.rentBoost ? 'Activo' : 'Anuncio opcional',
                  () => showHsSheet(context, builder: (_) => BoostsSheet(g: g))),
              tile(Icons.workspace_premium_outlined, 'Prestigio', g.canPrestige ? '¡Funda una ciudad!' : 'Desde \$5.000.000',
                  () => push(context, const PrestigeScreen()), dim: !g.canPrestige),
            ),
            pair(
              tile(Icons.location_city_rounded, 'Mis ciudades',
                  g.meta.legacy.isEmpty ? g.city.name : '${g.meta.legacy.length + 1} ciudades · ${money(g.legacyRent, compact: true)}/mes',
                  () => push(context, const LegacyCitiesScreen())),
              tile(Icons.groups_2_outlined, 'Inversores', g.rivals.isEmpty ? 'Aún sin rivales' : plural(g.rivals.length, 'rival', 'rivales'),
                  () => push(context, const RivalsScreen())),
            ),
            pair(
              tile(Icons.leaderboard_outlined, 'Ranking', Backend.ready ? 'Promotores del mundo' : 'Sin conexión', () => push(context, const RankingScreen())),
              tile(Icons.notifications_none_rounded, 'Avisos', 'Solo los útiles', () => push(context, const NotificationsScreen())),
            ),
            StatTile(
              onTap: () => push(context, const PassScreen()),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Expanded(child: Text('Pase · temporada', style: Ht.numS)),
                  Text('Nivel ${g.passTier} de 20', style: Ht.mini),
                ]),
                const SizedBox(height: 6),
                Meter(g.passTier / 20, color: Hc.acc),
              ]),
            ),
            Text('Corner Cutters 0.1 · ${g.city.name} · semilla ${g.seed}', style: Ht.mini, textAlign: TextAlign.center),
          ]),
        ),
      ]),
    );
  }
}

/// Tile de la rejilla de "Más": icono en cuadro 38 × 38, título Jersey 22 y subtítulo.
class _GridTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;
  final int badge;
  final bool dim;
  final VoidCallback onTap;
  const _GridTile({required this.icon, required this.title, required this.sub, required this.onTap, this.badge = 0, this.dim = false});
  @override
  Widget build(BuildContext context) => Opacity(
        opacity: dim ? 0.55 : 1,
        child: StatTile(
          onTap: onTap,
          child: Stack(clipBehavior: Clip.none, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              IconBox(icon, color: Hc.acc, size: 38),
              const SizedBox(height: 8),
              Text(title, style: Ht.card, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(sub, style: Ht.mini, maxLines: 2, overflow: TextOverflow.ellipsis),
            ]),
            if (badge > 0) Positioned(right: -2, top: -2, child: CountBadge(badge)),
          ]),
        ),
      );
}


// =====================================================================
class MissionRow extends ConsumerWidget {
  final Mission m;
  final bool last;
  const MissionRow({super.key, required this.m, this.last = false});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = ref.watch(gameProvider);
    return Li(
      last: last,
      lead: IconBox(m.claimed ? Icons.check_rounded : Icons.flag_outlined, color: m.done ? Hc.ok : Hc.mut),
      title: m.text,
      sub: m.claimed ? 'Cobrado' : '${intg(m.progress)} / ${intg(m.target)} · recompensa ${money(m.reward)}',
      trail: m.claimed
          ? const Tag('Hecho', color: Hc.ok)
          : (m.done
              ? HsButton('Cobrar', size: BtnSize.xs, kind: BtnKind.ok, onTap: () => g.claimMission(m))
              : SizedBox(width: 60, child: Meter(m.progress / m.target, color: Hc.acc))),
    );
  }
}

class ObjectivesScreen extends ConsumerStatefulWidget {
  const ObjectivesScreen({super.key});
  @override
  ConsumerState<ObjectivesScreen> createState() => _ObjectivesScreenState();
}

class _ObjectivesScreenState extends ConsumerState<ObjectivesScreen> {
  int _tab = 0;
  @override
  Widget build(BuildContext context) {
    final g = ref.watch(gameProvider);
    return Screen(
      child: Column(children: [
        const BackHeader('Objetivos y logros'),
        Expanded(
          child: Body([
            Seg3<int>(values: const [0, 1], value: _tab, label: (v) => v == 0 ? 'Diarios' : 'Logros', onChanged: (v) => setState(() => _tab = v)),
            if (_tab == 0)
              ListBlock([
                  for (var i = 0; i < g.missions.length; i++) MissionRow(m: g.missions[i], last: i == g.missions.length - 1),
                ])
            else
              ListBlock([
                  for (var i = 0; i < achievementsList.length; i++)
                    Li(
                      last: i == achievementsList.length - 1,
                      lead: IconBox(Icons.emoji_events_outlined, color: g.meta.achievements.contains(achievementsList[i].id) ? Hc.acc : Hc.dim),
                      title: achievementsList[i].name,
                      titleColor: g.meta.achievements.contains(achievementsList[i].id) ? Hc.ink : Hc.mut,
                      sub: achievementsList[i].desc + (achievementsList[i].reward != null ? ' · desbloquea «${achievementsList[i].reward}»' : ''),
                      trail: g.meta.achievements.contains(achievementsList[i].id) ? const Icon(Icons.check_circle, color: Hc.ok, size: 20) : null,
                    ),
                ]),
            Text(_tab == 0 ? 'Los objetivos cambian cada día.' : 'Los logros se conservan entre ciudades.', style: Ht.small, textAlign: TextAlign.center),
          ]),
        ),
      ]),
    );
  }
}

// =====================================================================
class _Cosmetic {
  final String id, name, kind, how;
  final List<Color> sw;
  const _Cosmetic(this.id, this.name, this.kind, this.how, this.sw);
}

const _cosmetics = [
  _Cosmetic('dia', 'Día', 'tema', 'Incluido', [Color(0xFF5E9A55), Color(0xFF3C7FA0), Color(0xFFDCCB9E)]),
  _Cosmetic('atardecer', 'Atardecer', 'tema', 'Logro «Comprar en rojo» o pase nivel 3', [Color(0xFF6E8A4C), Color(0xFFE7A77B), Color(0xFF5F7FA8)]),
  _Cosmetic('noche', 'Noche', 'tema', 'Logro «Fundador» o pase nivel 19', [Color(0xFF2B4A3A), Color(0xFF183A50), Color(0xFFFFD86B)]),
  _Cosmetic('clasica', 'Clásica', 'fachada', 'Incluida', [Color(0xFFDDB896), Color(0xFF8E9BA8), Color(0xFFE9DDBA)]),
  _Cosmetic('ladrillo', 'Ladrillo visto', 'fachada', 'Logro «Ojo de halcón» o pase nivel 7', [Color(0xFFB0573F), Color(0xFFA14E39), Color(0xFFC0694D)]),
  _Cosmetic('pastel', 'Pastel', 'fachada', 'Logro «Ni un euro de más» o pase nivel 11', [Color(0xFFE9B9C4), Color(0xFFB9D7E9), Color(0xFFCDE9B9)]),
  _Cosmetic('modernista', 'Modernista', 'fachada', 'Logro «Millonario» o pase nivel 15', [Color(0xFFE2C38A), Color(0xFF9FB89A), Color(0xFFB7A6D6)]),
];

class ShopScreen extends ConsumerWidget {
  const ShopScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = ref.watch(gameProvider);
    Widget card(_Cosmetic c) {
      final owned = g.meta.cosmetics.contains(c.id);
      final active = c.kind == 'tema' ? g.meta.mapTheme == c.id : g.meta.facade == c.id;
      return Panel(
        padding: const EdgeInsets.all(10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            height: 64,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: Hc.line, width: 2)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Row(children: [for (final s in c.sw) Expanded(child: Container(color: s))]),
            ),
          ),
          const SizedBox(height: 8),
          Text(c.name, style: Ht.bodyB),
          Text(c.kind == 'tema' ? 'Tema del mapa' : 'Estilo de fachada', style: Ht.small.copyWith(fontSize: 11)),
          const SizedBox(height: 8),
          if (active)
            const Tag('En uso', color: Hc.ok)
          else if (owned)
            HsButton('Usar', size: BtnSize.xs, onTap: () {
              if (c.kind == 'tema') {
                g.meta.mapTheme = c.id;
              } else {
                g.meta.facade = c.id;
              }
              g.touch();
            })
          else
            Text(c.how, style: Ht.small.copyWith(fontSize: 10.5, color: Hc.dim)),
        ]),
      );
    }

    return Screen(
      child: Column(children: [
        const BackHeader('Tienda', sub: 'Fachadas, estilos y temas'),
        Expanded(
          child: Body([
            const SectionHead('Sin anuncios y épocas'),
            const PremiumBlock(),
            Center(child: HsButton('Restaurar compras', kind: BtnKind.ghost, size: BtnSize.sm, onTap: () => restorePurchases(context))),
            const SectionHead('Temas del mapa'),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.92,
              children: [for (final c in _cosmetics.where((c) => c.kind == 'tema')) card(c)],
            ),
            const SectionHead('Fachadas'),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.92,
              children: [for (final c in _cosmetics.where((c) => c.kind == 'fachada')) card(c)],
            ),
            const Note('Nunca se vende dinero del juego: rompería la economía de precios. Los cosméticos se ganan con logros y con el pase.',
                icon: Icons.info_outline),
          ]),
        ),
      ]),
    );
  }
}

class PassScreen extends ConsumerWidget {
  const PassScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = ref.watch(gameProvider);
    final tier = g.passTier;
    final into = (g.meta.passXp % Game.passStep) / Game.passStep;
    String reward(int t) {
      const cos = {3: 'Tema Atardecer', 7: 'Fachada Ladrillo', 11: 'Fachada Pastel', 15: 'Fachada Modernista', 19: 'Tema Noche'};
      if (cos.containsKey(t)) return cos[t]!;
      if (t == 5) return '+3 huecos de plantilla';
      if (t % 4 == 0) return money(2000.0 * t);
      return 'Insignia nivel $t';
    }

    return Screen(
      child: Column(children: [
        const BackHeader('Pase de temporada', sub: 'Recompensas cosméticas y de comodidad'),
        Expanded(
          child: Body([
            Panel(
              child: Row(children: [
                Ring(tier / 20, size: 80, stroke: 8, child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('$tier', style: Ht.numL),
                  const Cap('nivel'),
                ])),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const Cap('Progreso al siguiente'),
                    const SizedBox(height: 6),
                    Meter(tier >= 20 ? 1 : into, color: Hc.acc, large: true),
                    const SizedBox(height: 6),
                    Text('Toques, reformas y objetivos suman experiencia.', style: Ht.small),
                  ]),
                ),
              ]),
            ),
            Panel(
              padding: EdgeInsets.zero,
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                  child: Row(children: const [SizedBox(width: 40), Expanded(child: Cap('Gratis')), Expanded(child: Cap('Con pase'))]),
                ),
                for (var t = 1; t <= 20; t++)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: t == tier ? const Color(0x1FE3A93B) : null,
                      border: const Border(top: BorderSide(color: Hc.lineSoft, width: 1)),
                    ),
                    child: Row(children: [
                      SizedBox(width: 40, child: Text('$t', style: Ht.numS.copyWith(color: t <= tier ? Hc.acc : Hc.dim))),
                      Expanded(
                        child: t.isOdd || t % 4 == 0
                            ? Row(children: [
                                Expanded(child: Text(reward(t), style: Ht.small.copyWith(color: t <= tier ? Hc.ink : Hc.mut))),
                                if (g.meta.passClaimed.contains(t))
                                  const Icon(Icons.check_circle, size: 18, color: Hc.ok)
                                else if (t <= tier)
                                  HsButton('Coger', size: BtnSize.xs, onTap: () => g.claimPass(t)),
                              ])
                            : Text('—', style: Ht.small),
                      ),
                      Expanded(
                        child: Row(children: [
                          const Icon(Icons.lock_outline, size: 14, color: Hc.dim),
                          const SizedBox(width: 4),
                          Expanded(child: Text(t % 2 == 0 ? 'Fachada de temporada' : 'Marco de mapa', style: Ht.small.copyWith(color: Hc.dim, fontSize: 11))),
                        ]),
                      ),
                    ]),
                  ),
              ]),
            ),
            const Note('El pase de pago llegará con la tienda de la app. Nunca da dinero del juego.', icon: Icons.info_outline),
          ]),
        ),
      ]),
    );
  }
}

// =====================================================================
class PhasesScreen extends ConsumerWidget {
  const PhasesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = ref.watch(gameProvider);
    double progress(Stage s) => switch (s) {
          Stage.manitas => 1,
          Stage.casero => (g.renosDone / 1).clamp(0.0, 1.0),
          Stage.empresa => (g.renosDone / 3).clamp(0.0, 1.0),
          Stage.promotor => (g.netWorth / 500000).clamp(0.0, 1.0),
          Stage.prestigio => (g.netWorth / 5000000).clamp(0.0, 1.0),
        };
    return Screen(
      child: Column(children: [
        const BackHeader('Fases de progreso'),
        Expanded(
          child: Body([
            for (final s in Stage.values)
              Panel(
                kind: s == g.stage ? PanelKind.hi : PanelKind.normal,
                frame: s == g.stage,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Text('${s.index + 1}', style: Ht.numL.copyWith(color: s.index <= g.stage.index ? Hc.acc : Hc.dim)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(stageInfo[s]!.name, style: Ht.h2),
                        Text(stageInfo[s]!.unlock, style: Ht.small),
                      ]),
                    ),
                    if (s.index < g.stage.index)
                      const Tag('Hecha', color: Hc.ok)
                    else if (s == g.stage)
                      const Tag('Actual', color: Hc.acc, fill: true)
                    else
                      const Tag('Bloqueada', color: Hc.dim),
                  ]),
                  const SizedBox(height: 8),
                  Text(stageInfo[s]!.adds, style: Ht.body.copyWith(color: Hc.mut, fontSize: 13)),
                  if (s.index > g.stage.index) ...[
                    const SizedBox(height: 8),
                    Meter(progress(s), color: Hc.acc),
                  ],
                ]),
              ),
          ]),
        ),
      ]),
    );
  }
}

class DistrictsScreen extends ConsumerWidget {
  const DistrictsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = ref.watch(gameProvider);
    return Screen(
      child: Column(children: [
        BackHeader('Barrios', sub: g.city.name),
        Expanded(
          child: Body([
            ListBlock([
                for (var i = 0; i < g.city.districts.length; i++)
                  Li(
                    last: i == g.city.districts.length - 1,
                    lead: IconBox(Icons.location_city_outlined, color: zi(g.city.districts[i].zone).tint),
                    title: g.city.districts[i].name,
                    sub: '${zi(g.city.districts[i].zone).name} · ${g.props.where((p) => g.lotOf(p).district == i).length} tuyas',
                    trail: Text('${money(zi(g.city.districts[i].zone).price * g.city.districts[i].priceFactor)}/m²', style: Ht.numS.copyWith(fontSize: 16)),
                    onTap: () => push(context, DistrictScreen(districtId: i)),
                  ),
              ]),
          ]),
        ),
      ]),
    );
  }
}

// =====================================================================
class PrestigeScreen extends ConsumerWidget {
  const PrestigeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = ref.watch(gameProvider);
    final gain = g.reputationGain;
    final total = g.meta.reputation + gain;
    return Screen(
      dock: HsButton('Fundar una nueva ciudad', block: true, size: BtnSize.lg, icon: Icons.auto_awesome_rounded, onTap: g.canPrestige
          ? () async {
              if (await confirm(context,
                  title: 'Fundar una nueva ciudad',
                  body: 'Empiezas de cero en una ciudad nueva: dinero, cuadrillas, niveles, herramientas y mercado. Tus viviendas se quedan en ${g.city.name} (visitables en «Mis ciudades») y la gestoría te pasa el 15 % de sus rentas. Conservas reputación, cosméticos, logros y plantillas.',
                  ok: 'Fundar',
                  danger: true)) {
                g.foundCity();
                await saveGame(ref);
                if (context.mounted) {
                  Navigator.of(context).pushReplacement(glassRoute(NewCityScreen(gained: gain)));
                }
              }
            }
          : null),
      child: Column(children: [
        const BackHeader('Prestigio', sub: 'Nueva ciudad, reputación permanente'),
        Expanded(
          child: Body([
            StatGrid([
              Stat('Patrimonio', money(g.netWorth, compact: true), color: Hc.acc),
              Stat('Reputación', '${g.meta.reputation} → $total', color: Hc.ok),
              Stat('Obra y alquiler', '+${3 * total} %'),
              Stat('Tope de oficios', '${20 + 5 * (total ~/ 10)}'),
            ]),
            if (!g.canPrestige)
              Panel(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Cap('Hasta \$5.000.000'),
                  const SizedBox(height: 8),
                  Meter(g.netWorth / 5000000, color: Hc.acc, large: true),
                ]),
              ),
            const Note('Reputación = ⌊√(patrimonio ÷ \$250.000)⌋. Incluye el multiplicador de mercado: reiniciar en burbuja paga más.',
                icon: Icons.functions_rounded),
            Panel(
              padding: EdgeInsets.zero,
              child: Column(children: const [
                Li(lead: Icon(Icons.restart_alt_rounded, color: Hc.bad), title: 'Se reinicia', sub: 'Dinero, cuadrillas, niveles, herramientas y mercado'),
                Li(lead: Icon(Icons.location_city_rounded, color: Hc.info), title: 'Se queda en su ciudad', sub: 'Tus viviendas: visitables y con el 15 % de la renta'),
                Li(last: true, lead: Icon(Icons.inventory_2_outlined, color: Hc.ok), title: 'Se conserva', sub: 'Reputación, cosméticos, logros y plantillas'),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}

class NewCityScreen extends ConsumerWidget {
  final int gained;
  const NewCityScreen({super.key, required this.gained});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = ref.watch(gameProvider);
    return Screen(
      dock: HsButton('Empezar', block: true, size: BtnSize.lg, onTap: () => Navigator.pop(context)),
      child: Column(children: [
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Cap('Nueva ciudad', color: Hc.acc),
                const SizedBox(height: 8),
                Text(g.city.name, style: Ht.display.copyWith(fontSize: 48), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                Pose(rz: -4, child: GlowText('+$gained reputación', style: Ht.numL)),
                const SizedBox(height: 16),
                Tag(cityTraitInfo[g.city.trait]!.name, color: Hc.info),
                const SizedBox(height: 8),
                Text('${cityTraitInfo[g.city.trait]!.desc}. Mapa, barrios y monumentos nuevos; ${g.meta.legacy.isNotEmpty ? g.meta.legacy.last.name : 'la anterior'} sigue en «Mis ciudades».',
                    style: Ht.body.copyWith(color: Hc.mut), textAlign: TextAlign.center),
                const SizedBox(height: 10),
                Text('Reputación total ${g.meta.reputation} · ${g.meta.cities} ${g.meta.cities == 1 ? 'ciudad fundada' : 'ciudades fundadas'}', style: Ht.small),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

// =====================================================================
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = ref.watch(gameProvider);
    final s = g.settings;
    return Screen(
      child: Column(children: [
        const BackHeader('Ajustes'),
        Expanded(
          child: Body([
            const SectionHead('Idioma'),
            const _IdiomaPicker(),
            const SectionHead('Gráficos'),
            Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Cap('Calidad'),
                const SizedBox(height: 8),
                Seg3<String>(
                  values: const ['auto', 'baja', 'media', 'alta'],
                  value: s.quality,
                  label: (v) => switch (v) { 'alta' => 'Alta', 'media' => 'Media', 'baja' => 'Baja', _ => 'Auto' },
                  onChanged: (v) {
                    s.quality = v;
                    Gfx.apply(v);
                    g.touch();
                  },
                ),
                const SizedBox(height: 8),
                Text(
                    switch (s.quality) {
                      'alta' => 'Cristal con desenfoque, coches, barcos y tren. La que más batería gasta.',
                      'media' => 'Cristal opaco y ambiente a 15 fps. Buen equilibrio.',
                      'baja' => 'Sin ambiente ni animaciones continuas. Para jugar fresco y ahorrar batería.',
                      _ => 'Empieza en media y baja sola si el móvil va justo.',
                    },
                    style: Ht.small),
              ]),
            ),
            const SectionHead('Sonido'),
            ListBlock([
                Li(lead: const IconBox(Icons.volume_up_outlined), title: 'Sonido y música', trail: HsToggle(s.sound, (v) {
                  s.sound = v;
                  Sfx.enabled = v;
                  Music.setEnabled(v);
                  g.touch();
                })),
                Li(
                  lead: const IconBox(Icons.music_note_outlined),
                  title: 'Música',
                  sub: '${(s.music * 100).round()} %',
                  trail: SizedBox(
                    width: 130,
                    child: HsSlider(value: s.music, min: 0, max: 1, onChanged: (v) {
                      s.music = v;
                      Music.setVolume(v);
                      g.touch();
                    }),
                  ),
                ),
                Li(
                  last: true,
                  lead: const IconBox(Icons.graphic_eq_rounded),
                  title: 'Efectos',
                  sub: '${(s.sfx * 100).round()} %',
                  trail: SizedBox(
                    width: 130,
                    child: HsSlider(value: s.sfx, min: 0, max: 1, onChanged: (v) {
                      s.sfx = v;
                      Sfx.volume = v;
                      g.touch();
                    }),
                  ),
                ),
              ]),
            const SectionHead('General'),
            ListBlock([
                Li(lead: const IconBox(Icons.vibration_rounded), title: 'Vibración', trail: HsToggle(s.haptics, (v) {
                  s.haptics = v;
                  g.touch();
                })),
                Li(lead: const IconBox(Icons.cloud_outlined), title: 'Ambiente del mapa', sub: 'Nubes, pájaros, tráfico', trail: HsToggle(s.ambient, (v) {
                  s.ambient = v;
                  g.touch();
                })),
                Li(last: true, lead: const IconBox(Icons.motion_photos_off_outlined), title: 'Reducir movimiento', sub: 'Menos animaciones y sin inclinaciones', trail: HsToggle(s.reduceMotion, (v) {
                  s.reduceMotion = v;
                  Motion.reduced = v;
                  g.touch();
                })),
              ]),
            ListBlock([
                const Li(lead: IconBox(Icons.attach_money_rounded), title: 'Moneda', sub: 'Dólares estadounidenses (\$)', trail: Tag('Fija', color: Hc.mut)),
                Li(last: true, lead: const IconBox(Icons.notifications_none_rounded), title: 'Notificaciones', trail: const Icon(Icons.chevron_right_rounded, color: Hc.mut),
                    onTap: () => push(context, const NotificationsScreen())),
              ]),
            const SectionHead('Partida'),
            ListBlock([
                Li(
                  lead: const IconBox(Icons.save_outlined),
                  title: 'Guardar ahora',
                  sub: Backend.ready ? 'En el móvil y en la nube' : 'En el móvil',
                  onTap: () async {
                    await saveGame(ref);
                    await cloudSave(ref);
                    if (context.mounted) toast(context, 'Partida guardada');
                  },
                ),
                Li(
                  last: true,
                  lead: const IconBox(Icons.delete_forever_outlined, color: Hc.bad),
                  title: 'Empezar de cero',
                  titleColor: Hc.bad,
                  sub: 'Borra esta partida y la reputación',
                  onTap: () async {
                    if (await confirm(context, title: 'Empezar de cero', body: 'Se borra la partida local. No se puede deshacer.', ok: 'Borrar', danger: true)) {
                      await Storage.clear();
                      final g = ref.read(gameProvider);
                      g.loaded = false;
                      navKey.currentState?.pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => TitleScreen(hasSave: false, onContinue: () {})),
                        (_) => false,
                      );
                    }
                  },
                ),
              ]),
          ]),
        ),
      ]),
    );
  }
}

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = ref.watch(gameProvider);
    final n = g.settings.notif;
    Widget row(String k, String t, String s, IconData i, {bool last = false}) => Li(
          last: last,
          lead: IconBox(i),
          title: t,
          sub: s,
          trail: HsToggle(n[k] ?? true, (v) {
            n[k] = v;
            g.touch();
          }),
        );
    return Screen(
      child: Column(children: [
        const BackHeader('Notificaciones', sub: 'Solo avisos útiles'),
        Expanded(
          child: Body([
            Panel(
              padding: EdgeInsets.zero,
              child: Column(children: [
                row('obra', 'Reforma terminada', 'Cuando una obra se completa', Icons.construction_outlined),
                row('inquilino', 'Inquilino nuevo', 'Contrato firmado', Icons.key_outlined),
                row('venta', 'Venta cerrada y ofertas', 'Compradores y ofertas', Icons.sell_outlined),
                row('mercado', 'Cambio de fase del mercado', 'Crisis, burbuja…', Icons.show_chart_rounded),
                row('eventos', 'Eventos', 'Averías, impagos, inspecciones', Icons.inbox_outlined, last: true),
              ]),
            ),
            Panel(
              padding: EdgeInsets.zero,
              child: Column(children: [
                row('noche', 'Silencio nocturno', 'Nada entre las 23:00 y las 8:00', Icons.bedtime_outlined, last: true),
              ]),
            ),
            const Note('Por ahora los avisos se muestran dentro del juego. Las notificaciones del sistema llegarán en una próxima versión.', icon: Icons.info_outline),
          ]),
        ),
      ]),
    );
  }
}

// =====================================================================
class RankingScreen extends ConsumerStatefulWidget {
  const RankingScreen({super.key});
  @override
  ConsumerState<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends ConsumerState<RankingScreen> {
  List<RankRow>? _rows;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await cloudSave(ref);
    final r = await Backend.ranking();
    if (mounted) setState(() => _rows = r);
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    return Screen(
      child: Column(children: [
        const BackHeader('Ranking', sub: 'Por reputación y patrimonio'),
        Expanded(
          child: Body([
            if (!Backend.ready)
              const Note('El ranking necesita conexión con Supabase.', icon: Icons.cloud_off_outlined, kind: NoteKind.warn)
            else if (rows == null)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: Hc.acc)))
            else
              ListBlock([
                  if (rows.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('Aún no hay nadie. Serás el primero.', style: TextStyle(color: Hc.mut))),
                  for (var i = 0; i < rows.length; i++)
                    Container(
                      color: rows[i].me ? const Color(0x1FE3A93B) : null,
                      child: Li(
                        last: i == rows.length - 1,
                        lead: SizedBox(width: 30, child: Text('${i + 1}', style: Ht.numM.copyWith(color: i < 3 ? Hc.acc : Hc.mut))),
                        title: rows[i].name + (rows[i].me ? ' (tú)' : ''),
                        sub: '${rows[i].city} · reputación ${rows[i].reputation}',
                        trail: Text(money(rows[i].netWorth, compact: true), style: Ht.numS.copyWith(color: Hc.acc)),
                      ),
                    ),
                ]),
          ]),
        ),
      ]),
    );
  }
}

/// Selector de idioma: automático (el del móvil) o uno fijo. Los nombres de idioma van
/// siempre en su propia lengua.
class _IdiomaPicker extends StatelessWidget {
  const _IdiomaPicker();
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: I18n.actual,
      builder: (context, _, __) {
        final opciones = <(String, String)>[('', tr('Automático')), ...I18n.idiomas.entries.map((e) => (e.key, e.value))];
        return ListBlock([
          for (var i = 0; i < opciones.length; i++)
            Li(
              last: i == opciones.length - 1,
              lead: IconBox(i == 0 ? Icons.smartphone_outlined : Icons.translate_rounded, color: Hc.info),
              title: opciones[i].$2,
              sub: i == 0 ? tr('Usa el idioma del móvil') : null,
              trail: I18n.eleccion == opciones[i].$1 ? const Icon(Icons.check_rounded, color: Hc.acc) : null,
              onTap: () => I18n.elegir(opciones[i].$1),
            ),
        ]);
      },
    );
  }
}
