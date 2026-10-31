import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../services/backend.dart';
import '../common.dart';
import '../widgets/atoms.dart';
import '../widgets/overlays.dart';

import '../../core/texto.dart';
import '../../core/i18n.dart';
/// Panel admin dentro de la app: resumen, usuarios, roles y regalos del pack de épocas.
/// El servidor comprueba el rol en cada llamada (no basta con ver esta pantalla).
class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});
  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  final _q = TextEditingController();
  Map<String, dynamic>? _resumen;
  final List<AdminUser> _users = [];
  bool _soloCorreo = true, _loading = false, _more = true;
  String? _error;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _q.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
      _users.clear();
      _more = true;
    });
    try {
      final r = await Backend.adminResumen();
      final u = await Backend.adminUsuarios(buscar: _q.text.trim(), soloCorreo: _soloCorreo);
      if (!mounted) return;
      setState(() {
        _resumen = r;
        _users.addAll(u);
        _more = u.length >= 50;
      });
    } catch (e) {
      if (mounted) setState(() => _error = Backend.adminError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loading = true);
    try {
      final u = await Backend.adminUsuarios(buscar: _q.text.trim(), soloCorreo: _soloCorreo, desde: _users.length);
      if (mounted) {
        setState(() {
          _users.addAll(u);
          _more = u.length >= 50;
        });
      }
    } catch (e) {
      if (mounted) toast(context, Backend.adminError(e), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ent = ref.watch(entitlementsProvider);
    final r = _resumen;
    String n(String k) => r == null ? '—' : intg((r[k] as num?)?.toDouble() ?? 0);
    return Screen(
      kind: ScreenKind.full,
      child: Column(children: [
        BackHeader('Panel admin', sub: ent.email ?? 'Admin', trail: SqButton(Icons.refresh_rounded, tooltip: 'Actualizar', onTap: _reload)),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _reload,
            color: Hc.acc,
            child: ListView(padding: const EdgeInsets.fromLTRB(14, 0, 14, 20), children: [
              if (!ent.isAdmin) const Note('Tu cuenta no es admin: el servidor rechazará los cambios.', kind: NoteKind.bad),
              if (_error != null) ...[Note(_error!, kind: NoteKind.bad, icon: Icons.error_outline), const SizedBox(height: 10)],
              Panel(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: StatGrid([
                  Stat('Usuarios', n('usuarios')),
                  Stat('Con correo', n('con_correo')),
                  Stat('Activos 7 días', n('activos_7d'), color: Hc.ok),
                  Stat('Nuevos 7 días', n('nuevos_7d')),
                  Stat('Pro', n('pro'), color: Hc.info),
                  Stat('Admin', n('admin'), color: Hc.acc),
                  Stat('Pack regalado', n('dlc_regalado'), color: Hc.acc),
                  Stat('Compras pack / Pro', '${n('compras_epocas')} / ${n('compras_pro')}', color: Hc.ok),
                ], columns: 2),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _q,
                style: Ht.bodyB,
                decoration: InputDecoration(
                  hintText: tr('Buscar correo, alias o id'),
                  hintStyle: Ht.body.copyWith(color: Hc.dim),
                  prefixIcon: const Icon(Icons.search_rounded, color: Hc.mut),
                  filled: true,
                  fillColor: Hc.bgDeep,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Hr.btn), borderSide: const BorderSide(color: Hc.line, width: 2)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Hr.btn), borderSide: const BorderSide(color: Hc.acc, width: 2)),
                ),
                onChanged: (_) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 400), _reload);
                },
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: Text('Solo cuentas con correo', style: Ht.small)),
                HsToggle(_soloCorreo, (v) {
                  setState(() => _soloCorreo = v);
                  _reload();
                }),
              ]),
              const SizedBox(height: 10),
              ListBlock([
                for (var i = 0; i < _users.length; i++) _row(_users[i], last: i == _users.length - 1),
              ]),
              if (_users.isEmpty && !_loading && _error == null) Padding(padding: const EdgeInsets.all(20), child: Text('Nadie con ese filtro', textAlign: TextAlign.center, style: Ht.small)),
              if (_loading) const Padding(padding: EdgeInsets.all(16), child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Hc.acc, strokeWidth: 3)))),
              if (_more && !_loading && _users.isNotEmpty) ...[
                const SizedBox(height: 10),
                HsButton('Cargar más', kind: BtnKind.sec, block: true, onTap: _loadMore),
              ],
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _row(AdminUser u, {bool last = false}) {
    final color = switch (u.rol) {
      'admin' => Hc.acc,
      'pro' => Hc.info,
      _ => Hc.mut,
    };
    return Li(
      last: last,
      lead: IconBox(u.rol == 'admin' ? Icons.admin_panel_settings_outlined : Icons.person_outline_rounded, color: color),
      title: u.email ?? 'Invitado · ${u.id.substring(0, 8)}',
      titleTag: Tag(_rolName(u.rol), color: color),
      sub: [
        if (u.alias != null) u.alias!,
        if (u.dlc) 'Pack regalado',
        if (u.comproEpocas) 'Compró el pack',
        if (u.comproPro) 'Compró Pro',
        if (u.visto != null) 'visto ${_ago(u.visto!)}',
      ].join(' · '),
      trail: const Icon(Icons.chevron_right_rounded, color: Hc.mut),
      onTap: () async {
        await showHsSheet(context, scroll: true, builder: (ctx) => _UserSheet(u));
        _reload();
      },
    );
  }
}

String _rolName(String r) => switch (r) {
      'admin' => 'Admin',
      'pro' => 'Pro',
      _ => 'Normal',
    };

String _ago(DateTime t) {
  final d = DateTime.now().difference(t.toLocal());
  if (d.inMinutes < 2) return 'ahora';
  if (d.inHours < 1) return 'hace ${d.inMinutes} min';
  if (d.inDays < 1) return 'hace ${d.inHours} h';
  return 'hace ${d.inDays} d';
}

class _UserSheet extends StatefulWidget {
  final AdminUser u;
  const _UserSheet(this.u);
  @override
  State<_UserSheet> createState() => _UserSheetState();
}

class _UserSheetState extends State<_UserSheet> {
  late String _rol = widget.u.rol;
  late bool _dlc = widget.u.dlc;
  late final _nota = TextEditingController(text: widget.u.nota ?? '');
  bool _busy = false;

  @override
  void dispose() {
    _nota.dispose();
    super.dispose();
  }

  Future<bool> _run(Future<void> Function() f, String ok) async {
    setState(() => _busy = true);
    try {
      await f();
      if (mounted) toast(context, ok);
      return true;
    } catch (e) {
      if (mounted) toast(context, Backend.adminError(e), error: true);
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.u;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      const Cap('Usuario'),
      Text(u.email ?? 'Invitado', style: Ht.h2, maxLines: 1, overflow: TextOverflow.ellipsis),
      Text([
        if (u.alias != null) u.alias!,
        u.id,
      ].join(' · '), style: Ht.mini, maxLines: 2),
      const SizedBox(height: 10),
      StatGrid([
        Stat('Registro', u.creado == null ? '—' : _ago(u.creado!)),
        Stat('Visto', u.visto == null ? '—' : _ago(u.visto!)),
        Stat('Patrimonio', money(u.patrimonio, compact: true), color: Hc.acc),
        Stat('Compras', [if (u.comproEpocas) 'Pack', if (u.comproPro) 'Pro'].join(' + ').ifEmpty('Ninguna')),
      ], columns: 2),
      const SizedBox(height: 14),
      const Cap('Tipo de usuario'),
      const SizedBox(height: 6),
      Seg3<String>(
        values: const ['usuario', 'pro', 'admin'],
        value: _rol,
        label: _rolName,
        onChanged: _busy
            ? (_) {}
            : (v) {
                if (v == _rol) return;
                final old = _rol;
                setState(() => _rol = v);
                _run(() => Backend.adminSetRol(u.id, v), 'Ahora es ${_rolName(v)}').then((ok) {
                  if (!ok && mounted) setState(() => _rol = old);
                });
              },
      ),
      const SizedBox(height: 14),
      Li(
        lead: const IconBox(Icons.card_giftcard_rounded, color: Hc.acc),
        title: 'Regalar el pack de épocas',
        sub: _dlc ? 'Lo tiene regalado' : (u.comproEpocas ? 'Ya lo compró en la tienda' : 'No lo tiene'),
        trail: HsToggle(_dlc, (v) {
          if (_busy) return;
          setState(() => _dlc = v);
          _run(() => Backend.adminRegalarDlc(u.id, v), v ? 'Pack regalado' : 'Regalo retirado').then((ok) {
            if (!ok && mounted) setState(() => _dlc = !v);
          });
        }),
        last: true,
      ),
      const SizedBox(height: 14),
      const Cap('Nota interna'),
      const SizedBox(height: 6),
      TextField(
        controller: _nota,
        maxLines: 2,
        maxLength: 500,
        style: Ht.body,
        decoration: InputDecoration(
          hintText: tr('Solo la ves tú'),
          hintStyle: Ht.body.copyWith(color: Hc.dim),
          filled: true,
          fillColor: Hc.bgDeep,
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Hr.btn), borderSide: const BorderSide(color: Hc.line, width: 2)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Hr.btn), borderSide: const BorderSide(color: Hc.acc, width: 2)),
        ),
      ),
      HsButton('Guardar nota', kind: BtnKind.sec, block: true, loading: _busy, onTap: () => _run(() => Backend.adminNota(u.id, _nota.text), 'Nota guardada')),
    ]);
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}
