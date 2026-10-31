import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../game/data.dart';
import '../game/engine.dart';
import '../services/audio.dart';
import 'chrome.dart';
import 'common.dart';
import 'map/map_screen.dart';
import 'screens/company.dart';
import 'screens/dialogs.dart';
import 'screens/eras.dart';
import 'screens/market.dart';
import 'screens/more.dart';
import 'screens/obra_fin.dart';
import 'screens/offline.dart';
import 'screens/sale.dart';
import 'screens/works.dart';
import 'widgets/atoms.dart';
import 'widgets/overlays.dart';

class Shell extends ConsumerStatefulWidget {
  const Shell({super.key});
  @override
  ConsumerState<Shell> createState() => _ShellState();
}

class _ShellState extends ConsumerState<Shell> {
  bool _showing = false;

  @override
  void dispose() {
    ShellPresence.alive = false;
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    ShellPresence.alive = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final g = ref.read(gameProvider);
      if (g.offlineReport != null) {
        final r = g.offlineReport!;
        g.offlineReport = null;
        push(context, OfflineScreen(report: r));
      }
    });
  }

  Future<void> _drain(Game g) async {
    if (_showing || !mounted) return;
    final n = g.takeNotice();
    if (n == null) return;
    _showing = true;
    try {
      await _show(g, n);
    } finally {
      _showing = false;
    }
    if (mounted && g.notices.isNotEmpty) _drain(g);
  }

  Future<void> _show(Game g, Notice n) async {
    final ctx = context;
    switch (n.kind) {
      case NoticeKind.toast:
        Toaster.show(ctx, n.text, icon: Icons.notifications_none_rounded, color: Hc.info);
      case NoticeKind.achievement:
        HapticFeedback.mediumImpact();
        Toaster.show(ctx, 'Logro: ${n.text}', icon: Icons.emoji_events_outlined, color: Hc.acc);
      case NoticeKind.event:
        Toaster.show(ctx, 'Pendiente: ${n.text}', icon: Icons.inbox_outlined, color: Hc.warn);
      case NoticeKind.market:
        final to = MarketPhase.values[n.data['to'] as int];
        Toaster.show(ctx, 'Mercado: ${mph(to).name} · precios ${mult(mph(to).m)}', icon: Icons.show_chart_rounded, color: mph(to).color);
      case NoticeKind.defects:
        await showDefectsDialog(ctx, n.text);
      case NoticeKind.stage:
        HapticFeedback.heavyImpact();
        await showStageDialog(ctx, Stage.values[n.data['stage'] as int]);
      case NoticeKind.renoDone:
        if (n.data['silent'] == true) {
          Toaster.show(ctx, 'Obra terminada en ${n.propId == null ? '' : (g.prop(n.propId!) != null ? g.addressOf(g.prop(n.propId!)!) : '')}',
              icon: Icons.construction_rounded, color: Hc.ok);
        } else {
          HapticFeedback.heavyImpact();
          await push(ctx, ObraFinScreen(notice: n));
        }
      case NoticeKind.tenantNew:
        final p = n.propId == null ? null : g.prop(n.propId!);
        if (p != null && p.tenant != null) await showTenantDialog(ctx, g, p);
      case NoticeKind.saleClosed:
        HapticFeedback.heavyImpact();
        await push(ctx, SaleClosedScreen(notice: n));
      case NoticeKind.eraEnd:
        HapticFeedback.heavyImpact();
        await showEraEndDialog(ctx, ref);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = ref.watch(gameProvider);
    final tab = ref.watch(tabProvider);
    Motion.reduced = g.settings.reduceMotion;
    Money.scale = g.eraCfg?.priceLevel ?? 1;
    if (g.notices.isNotEmpty && !_showing) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _drain(g));
    }
    // Sonidos del motor y música según el mercado (en crisis, su versión en menor).
    if (g.sounds.isNotEmpty) {
      for (final s in g.sounds) {
        Sfx.play(s);
      }
      g.sounds.clear();
    }
    Music.play(g.inCrisis ? 'crisis' : 'mapa');
    // El mapa es siempre la pantalla; las pestañas son paneles de cristal sobre el mapa velado.
    return Scaffold(
      backgroundColor: Hc.bgDeep,
      resizeToAvoidBottomInset: false,
      body: Stack(children: [
        Positioned.fill(child: MapScreen(active: tab == 0)),
        if (tab != 0) ...[
          const Positioned.fill(child: AbsorbPointer(child: Veil())),
          Positioned(
            left: Lay.hInsets(context, 640).$1,
            right: Lay.hInsets(context, 640).$2,
            top: Lay.panelTop(context),
            bottom: Lay.panelBottom(context),
            child: GlassPanel(
              child: ShellTab(
                child: IndexedStack(index: tab - 1, children: const [
                  WorksScreen(),
                  CompanyScreen(),
                  MarketScreen(),
                  MoreScreen(),
                ]),
              ),
            ),
          ),
        ],
        const Positioned.fill(child: Chrome()),
      ]),
    );
  }
}
