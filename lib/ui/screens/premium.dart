import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme.dart';
import '../../game/era.dart';
import '../../services/entitlements.dart';
import '../../services/tienda.dart';
import '../widgets/atoms.dart';
import '../widgets/overlays.dart';
import 'admin.dart';

/// Compra con aviso de resultado.
Future<void> buyProduct(BuildContext context, String product) async {
  final err = await Tienda.comprar(product);
  if (!context.mounted) return;
  if (err == null) {
    toast(context, product == Productos.epocas ? 'Pack de épocas desbloqueado' : 'Ya eres Pro: sin anuncios');
  } else {
    toast(context, err, error: true);
  }
}

Future<void> restorePurchases(BuildContext context) async {
  final err = await Tienda.restaurar();
  if (!context.mounted) return;
  toast(context, err ?? 'Compras restauradas', error: err != null);
}

/// Hoja del pack de épocas (desde la hemeroteca o la tienda).
Future<void> showPackSheet(BuildContext context) {
  return showHsSheet(context, scroll: true, builder: (ctx) => const _PackSheet());
}

class _PackSheet extends ConsumerWidget {
  const _PackSheet();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ent = ref.watch(entitlementsProvider);
    final price = Tienda.precios[Productos.epocas];
    final eras = EraConfig.all.where((e) => !e.free).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        const IconBox(Icons.newspaper_rounded, color: Hc.acc, size: 46),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Cap('DLC'),
            Text('Pack de épocas', style: Ht.title),
          ]),
        ),
        if (ent.hasEras) Tag(ent.erasOrigen, color: Hc.ok, icon: Icons.check_rounded),
      ]),
      const SizedBox(height: 8),
      Text('Cinco partidas cerradas más en Alba Nova, cada una con sus reglas, su prensa y sus edificios. 1929 sigue siendo gratis.',
          style: Ht.small),
      const SizedBox(height: 12),
      ListBlock([
        for (var i = 0; i < eras.length; i++)
          Li(
            last: i == eras.length - 1,
            lead: Container(
              width: 46,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: Hc.bgDeep, borderRadius: BorderRadius.circular(9), border: Border.all(color: Hc.line, width: 2)),
              child: Text(eras[i].id, style: Ht.numS.copyWith(fontSize: 18, color: Hc.acc)),
            ),
            title: eras[i].name,
            sub: eras[i].sub,
          ),
      ]),
      const SizedBox(height: 14),
      if (ent.hasEras)
        HsButton('Abrir la hemeroteca', block: true, onTap: () => Navigator.pop(context))
      else ...[
        HsButton(price == null ? 'Comprar el pack' : 'Comprar el pack · $price', block: true, size: BtnSize.lg,
            onTap: () => buyProduct(context, Productos.epocas)),
        const SizedBox(height: 8),
        HsButton('Restaurar compras', kind: BtnKind.ghost, size: BtnSize.sm, block: true, onTap: () => restorePurchases(context)),
        const SizedBox(height: 6),
        Text('Si te lo han regalado, aparece al entrar con tu cuenta.', textAlign: TextAlign.center, style: Ht.mini),
      ],
    ]);
  }
}

/// Bloque de la tienda: Pro (sin anuncios) y pack de épocas.
class PremiumBlock extends ConsumerWidget {
  const PremiumBlock({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ent = ref.watch(entitlementsProvider);
    final pPro = Tienda.precios[Productos.pro];
    final pEras = Tienda.precios[Productos.epocas];
    return ListBlock([
      Li(
        lead: const IconBox(Icons.block_rounded, color: Hc.info),
        title: 'Corner Cutters Pro',
        sub: ent.isPro ? 'Sin anuncios: los impulsos se activan al momento' : 'Sin anuncios y los impulsos al momento',
        trail: ent.isPro
            ? Tag(ent.rolNombre, color: Hc.ok, icon: Icons.check_rounded)
            : HsButton(pPro ?? 'Comprar', size: BtnSize.xs, onTap: () => buyProduct(context, Productos.pro)),
      ),
      Li(
        last: true,
        lead: const IconBox(Icons.newspaper_rounded, color: Hc.acc),
        title: 'Pack de épocas',
        sub: ent.hasEras ? 'Las seis épocas desbloqueadas' : '1888, 1980, 2005, 2020 y 2050',
        trail: ent.hasEras
            ? Tag(ent.erasOrigen, color: Hc.ok, icon: Icons.check_rounded)
            : HsButton(pEras ?? 'Ver', size: BtnSize.xs, onTap: () => showPackSheet(context)),
        onTap: () => showPackSheet(context),
      ),
    ]);
  }
}

/// Resumen de la cuenta: tipo de usuario, pack y acceso al panel admin.
class AccountRights extends ConsumerWidget {
  const AccountRights({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ent = ref.watch(entitlementsProvider);
    return ListBlock([
      Li(
        lead: IconBox(ent.isAdmin ? Icons.admin_panel_settings_outlined : Icons.person_outline_rounded, color: ent.isPro ? Hc.acc : Hc.ink),
        title: 'Tipo de usuario',
        sub: ent.isAdmin
            ? 'Admin: sin anuncios, todo desbloqueado y panel'
            : ent.isPro
                ? 'Pro: sin anuncios'
                : 'Normal: con anuncios opcionales',
        trail: Tag(ent.rolNombre, color: ent.isPro ? Hc.acc : Hc.mut),
      ),
      Li(
        last: !ent.isAdmin,
        lead: const IconBox(Icons.newspaper_rounded, color: Hc.acc),
        title: 'Pack de épocas',
        sub: ent.hasEras ? 'Desbloqueado' : 'Solo 1929 (gratis)',
        trail: Tag(ent.erasOrigen, color: ent.hasEras ? Hc.ok : Hc.mut),
        onTap: ent.hasEras ? null : () => showPackSheet(context),
      ),
      if (ent.isAdmin)
        Li(
          last: true,
          lead: const IconBox(Icons.dashboard_customize_outlined, color: Hc.info),
          title: 'Panel admin',
          sub: 'Usuarios, roles y regalos del pack',
          trail: const Icon(Icons.chevron_right_rounded, color: Hc.mut),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminScreen())),
        ),
    ]);
  }
}
