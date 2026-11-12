import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthChangeEvent;

import '../../app/app.dart';
import '../../app/providers.dart';
import '../../core/theme.dart';
import '../../services/backend.dart';
import '../../services/anuncios.dart';
import '../../services/config.dart';
import '../../services/entitlements.dart';
import '../../services/storage.dart';
import '../common.dart';
import '../shell.dart';
import '../widgets/atoms.dart';
import '../widgets/overlays.dart';
import 'title_screen.dart';
import 'premium.dart' show AccountRights;

import '../../core/texto.dart';
import '../../core/i18n.dart';
enum AuthMode { entrar, crear, enlace }

// =====================================================================
// Flujo común: qué partida se queda al entrar y cómo se sale.
// =====================================================================

/// Después de entrar en una cuenta: decide qué partida se usa y abre el juego.
///  - La cuenta tiene partida en la nube → se carga (si venías de invitado con partida, eliges cuál).
///  - La cuenta no tiene partida → guardas en ella la de este móvil o empiezas de cero.
Future<void> afterLogin(BuildContext context, WidgetRef ref, {required bool wasGuest}) async {
  Backend.hold = true;
  final g = ref.read(gameProvider);
  String choice;
  try {
    final email = Backend.email;
    if (email != null) await Storage.rememberAccount(email);
    final cloud = await Backend.pullSave();
    if (!context.mounted) return;
    if (cloud != null) {
      choice = 'nube';
      if (wasGuest && g.loaded) {
        final city = cloud['cityName'] as String? ?? 'otra ciudad';
        final useCloud = await confirm(context,
            title: 'Esta cuenta ya tiene partida',
            body: 'La de la cuenta está en $city. La de este móvil (invitado, ${g.city.name}) se perderá si cargas la de la cuenta.',
            ok: 'Cargar la de la cuenta',
            cancel: 'Quedarme la del móvil');
        choice = useCloud ? 'nube' : 'local';
      }
    } else if (wasGuest && g.loaded) {
      final keep = await confirm(context,
          title: 'Cuenta sin partida',
          body: 'Esta cuenta todavía no tiene partida guardada. ¿Guardas en ella la que estás jugando en este móvil?',
          ok: 'Guardar mi partida',
          cancel: 'Empezar de cero');
      choice = keep ? 'local' : 'nueva';
    } else {
      choice = 'nueva';
    }
    switch (choice) {
      case 'nube':
        g.loadJson(cloud!);
        g.catchUp();
        await Storage.save(g.toJson());
      case 'local':
        await Storage.save(g.toJson());
      default:
        await Storage.clear();
        g.loaded = false;
    }
    // Medallas y partidas de época de la cuenta (móvil nuevo o reinstalación).
    await pullErasFromCloud();
  } finally {
    Backend.hold = false;
  }
  if (choice != 'nueva') await cloudSave(ref);
  if (!context.mounted) return;
  toast(context, 'Has entrado como ${Backend.email ?? 'tu cuenta'}');
  ref.read(tabProvider.notifier).state = 0;
  navKey.currentState?.pushAndRemoveUntil(
    PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (c, a, b) => choice == 'nueva' ? const NewGameScreen() : const Shell(),
      transitionsBuilder: (c, a, b, child) => FadeTransition(opacity: a, child: child),
    ),
    (_) => false,
  );
}

/// Cerrar sesión: sube la partida a la nube, sale de la cuenta y vuelve a la portada sin partida.
Future<void> logOut(BuildContext context, WidgetRef ref) async {
  final email = Backend.email ?? 'tu cuenta';
  if (!await confirm(context,
      title: 'Cerrar sesión',
      body: 'Tu partida se guarda en la nube con $email. En este móvil volverás a la portada; para seguir jugándola, entra otra vez.',
      ok: 'Cerrar sesión')) {
    return;
  }
  await saveGame(ref);
  final ok = await cloudSave(ref);
  if (!context.mounted) return;
  if (!ok) {
    final force = await confirm(context,
        title: 'No se ha podido guardar en la nube',
        body: 'Sin conexión no se sube la partida. Si cierras sesión ahora perderás lo jugado desde la última vez que se guardó en la nube.',
        ok: 'Cerrar igualmente',
        cancel: 'Esperar',
        danger: true);
    if (!force) return;
  }
  Backend.hold = true;
  await Backend.signOut();
  await Storage.clear();
  ref.read(gameProvider).loaded = false;
  Backend.hold = false;
  navKey.currentState?.pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => TitleScreen(hasSave: false, onContinue: () {})),
    (_) => false,
  );
}

/// Abre una página de la web del juego (política de privacidad, borrar cuenta…).
Future<void> openWeb(BuildContext context, String path) async {
  final base = AppConfig.current.webUrl.isEmpty ? 'https://corner-cutters.pages.dev' : AppConfig.current.webUrl;
  final uri = Uri.parse('${base.replaceFirst(RegExp(r'/$'), '')}/$path');
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
  if (!ok && context.mounted) toast(context, 'No se ha podido abrir ${uri.host}', error: true);
}

/// Borrar cuenta: pide confirmación dos veces, borra todo en el servidor y vuelve a la portada.
Future<void> deleteAccount(BuildContext context, WidgetRef ref) async {
  final email = Backend.email ?? 'esta cuenta';
  if (!await confirm(context,
      title: 'Borrar cuenta',
      body: 'Se borrarán $email, la partida guardada en la nube, tu puesto en el ranking y el pack regalado. Las compras de Google Play siguen siendo tuyas: se recuperan con «Restaurar compras».',
      ok: 'Continuar',
      danger: true)) {
    return;
  }
  if (!context.mounted) return;
  if (!await confirm(context,
      title: '¿Seguro?',
      body: 'No se puede deshacer.',
      ok: 'Borrar para siempre',
      danger: true)) {
    return;
  }
  Backend.hold = true;
  final e = await Backend.borrarCuenta();
  if (e != null) {
    Backend.hold = false;
    if (context.mounted) toast(context, e, error: true);
    return;
  }
  Entitlements.instance.resetServer();
  await Storage.clear();
  ref.read(gameProvider).loaded = false;
  Backend.hold = false;
  navKey.currentState?.pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => TitleScreen(hasSave: false, onContinue: () {})),
    (_) => false,
  );
}

// =====================================================================
// Entrar / crear cuenta / enlace sin contraseña.
// =====================================================================
class AuthScreen extends ConsumerStatefulWidget {
  final AuthMode mode;
  const AuthScreen({super.key, this.mode = AuthMode.entrar});
  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  late AuthMode _mode = widget.mode;
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _show = false;
  bool _busy = false;
  String? _error;
  String? _info;
  bool _linkSent = false;
  List<String> _known = [];
  StreamSubscription? _sub;
  late final bool _wasGuest = Backend.isAnonymous;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    Storage.knownAccounts().then((l) {
      if (!mounted) return;
      setState(() {
        _known = l.where((e) => e != Backend.email).toList();
        if (_email.text.isEmpty && _known.isNotEmpty && _mode == AuthMode.entrar) _email.text = _known.first;
      });
    });
    // Al volver del enlace del correo (confirmación de cuenta o acceso sin contraseña).
    _sub = Backend.authChanges?.listen((st) {
      final u = st.session?.user;
      if (st.event == AuthChangeEvent.signedIn && u != null && !u.isAnonymous) _finish();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_done || !mounted) return;
    _done = true;
    await afterLogin(context, ref, wasGuest: _wasGuest);
  }

  bool _valid() {
    final e = _email.text.trim();
    if (!e.contains('@') || !e.contains('.')) {
      setState(() => _error = 'Escribe un correo válido');
      return false;
    }
    if (_mode != AuthMode.enlace && _pass.text.length < 6) {
      setState(() => _error = 'La contraseña necesita al menos 6 caracteres');
      return false;
    }
    return true;
  }

  Future<void> _submit() async {
    if (_busy || !_valid()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    final email = _email.text.trim();
    switch (_mode) {
      case AuthMode.entrar:
        // Antes de cambiar de una cuenta a otra, lo de la actual se sube a la nube.
        if (!Backend.isAnonymous) await cloudSave(ref);
        final err = await Backend.signInPassword(email, _pass.text);
        if (!mounted) return;
        if (err != null) {
          setState(() {
            _busy = false;
            _error = err;
          });
          return;
        }
        await _finish();
      case AuthMode.crear:
        if (!Backend.isAnonymous) await cloudSave(ref);
        final (err, confirmNeeded) = await Backend.signUp(email, _pass.text);
        if (!mounted) return;
        if (err != null) {
          setState(() {
            _busy = false;
            _error = err;
          });
          return;
        }
        await Storage.rememberAccount(email);
        if (!confirmNeeded) {
          await _finish();
          return;
        }
        setState(() {
          _busy = false;
          _mode = AuthMode.entrar;
          _info = 'Cuenta creada. Abre el correo que te hemos enviado a $email y pulsa el enlace para confirmarla; '
              'después entra aquí con tu contraseña. Mientras tanto sigues jugando como invitado.';
        });
      case AuthMode.enlace:
        final err = await Backend.sendLoginLink(email);
        if (!mounted) return;
        setState(() {
          _busy = false;
          _linkSent = err == null;
          _error = err;
        });
    }
  }

  InputDecoration _dec(String hint, {Widget? suffix}) => InputDecoration(
        hintText: tr(hint),
        hintStyle: Ht.body.copyWith(color: Hc.dim),
        filled: true,
        fillColor: Hc.bgDeep,
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Hr.btn), borderSide: const BorderSide(color: Hc.line, width: 2)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Hr.btn), borderSide: const BorderSide(color: Hc.acc, width: 2)),
      );

  @override
  Widget build(BuildContext context) {
    final title = switch (_mode) {
      AuthMode.entrar => 'Entrar',
      AuthMode.crear => 'Crear cuenta',
      AuthMode.enlace => 'Entrar sin contraseña',
    };
    final current = Backend.isAnonymous ? 'Ahora juegas como invitado' : 'Ahora: ${Backend.email}';
    return Screen(
      child: Column(children: [
        BackHeader(title, sub: current),
        Expanded(
          child: Body([
            if (_mode != AuthMode.enlace)
              Seg3<AuthMode>(
                values: const [AuthMode.entrar, AuthMode.crear],
                value: _mode,
                label: (m) => m == AuthMode.entrar ? 'Tengo cuenta' : 'Cuenta nueva',
                onChanged: (m) => setState(() {
                  _mode = m;
                  _error = null;
                }),
              ),
            if (_info != null) Note(_info!, icon: Icons.mark_email_read_outlined, kind: NoteKind.ok),
            if (_known.isNotEmpty && _mode != AuthMode.crear) ...[
              const Cap('Cuentas usadas en este dispositivo'),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final e in _known)
                  GestureDetector(
                    onTap: () => setState(() {
                      _email.text = e;
                      _error = null;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: _email.text.trim() == e ? Hc.acc.withValues(alpha: 0.18) : Hc.panelIn,
                        borderRadius: BorderRadius.circular(Hr.btn),
                        border: Border.all(color: _email.text.trim() == e ? Hc.acc : Hc.line, width: 2),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.person_outline, size: 15, color: Hc.mut),
                        const SizedBox(width: 6),
                        Text(e, style: Ht.small.copyWith(color: Hc.ink, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
              ]),
            ],
            if (_mode == AuthMode.enlace && _linkSent) ...[
              const Note('Abre el correo en este móvil y pulsa el enlace. Volverás aquí con tu partida.',
                  bold: 'Enlace enviado.', icon: Icons.mark_email_read_outlined, kind: NoteKind.ok),
              const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2.5, color: Hc.acc)),
                SizedBox(width: 10),
                Text('Esperando a que abras el enlace…', style: TextStyle(color: Hc.mut, fontSize: 12.5)),
              ]),
              HsButton('Reenviar', kind: BtnKind.sec, block: true, onTap: _busy ? null : _submit),
            ] else ...[
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                autofillHints: const [AutofillHints.email],
                textInputAction: _mode == AuthMode.enlace ? TextInputAction.go : TextInputAction.next,
                style: Ht.bodyB,
                decoration: _dec('tu@email.com'),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _mode == AuthMode.enlace ? _submit() : null,
              ),
              if (_mode != AuthMode.enlace)
                TextField(
                  controller: _pass,
                  obscureText: !_show,
                  autocorrect: false,
                  enableSuggestions: false,
                  autofillHints: [_mode == AuthMode.crear ? AutofillHints.newPassword : AutofillHints.password],
                  textInputAction: TextInputAction.go,
                  style: Ht.bodyB,
                  decoration: _dec(_mode == AuthMode.crear ? 'Contraseña (mín. 6)' : 'Contraseña',
                      suffix: IconButton(
                        tooltip: _show ? 'Ocultar' : 'Mostrar',
                        icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Hc.mut),
                        onPressed: () => setState(() => _show = !_show),
                      )),
                  onSubmitted: (_) => _submit(),
                ),
              HsButton(
                switch (_mode) {
                  AuthMode.entrar => 'Entrar',
                  AuthMode.crear => 'Crear cuenta',
                  AuthMode.enlace => 'Enviarme el enlace',
                },
                block: true,
                loading: _busy,
                icon: _mode == AuthMode.enlace ? Icons.send_rounded : Icons.login_rounded,
                onTap: _submit,
              ),
            ],
            if (_error != null) Note(_error!, icon: Icons.error_outline, kind: NoteKind.bad),
            if (_mode == AuthMode.crear && Backend.isAnonymous)
              const Note('Tu partida de invitado se guarda en la cuenta nueva en cuanto entres.', icon: Icons.cloud_upload_outlined),
            if (_mode == AuthMode.entrar)
              Center(
                child: HsButton('Entrar sin contraseña', kind: BtnKind.ghost, size: BtnSize.sm, onTap: () => setState(() {
                      _mode = AuthMode.enlace;
                      _error = null;
                    })),
              ),
            if (_mode == AuthMode.enlace)
              Center(
                child: HsButton('Usar contraseña', kind: BtnKind.ghost, size: BtnSize.sm, onTap: () => setState(() {
                      _mode = AuthMode.entrar;
                      _linkSent = false;
                      _error = null;
                    })),
              ),
            if (_mode == AuthMode.enlace)
              Text('Si tu cuenta es de antes y no tiene contraseña, entra con el enlace y ponle una en Más → Cuenta.',
                  style: Ht.mini, textAlign: TextAlign.center),
          ]),
        ),
      ]),
    );
  }
}

// =====================================================================
// Cuenta: quién eres, nube, cambiar de cuenta y cerrar sesión.
// =====================================================================
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});
  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  final _alias = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _alias.text = ref.read(aliasProvider);
  }

  @override
  void dispose() {
    _alias.dispose();
    _pass.dispose();
    super.dispose();
  }

  InputDecoration _dec(String h) => InputDecoration(
        hintText: tr(h),
        hintStyle: Ht.body.copyWith(color: Hc.dim),
        filled: true,
        fillColor: Hc.panelIn,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Hr.md), borderSide: const BorderSide(color: Hc.line, width: 2)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Hr.md), borderSide: const BorderSide(color: Hc.acc, width: 2)),
      );

  String _ago(DateTime? t) {
    if (t == null) return 'todavía no en esta sesión';
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'hace un momento';
    if (d.inHours < 1) return 'hace ${d.inMinutes} min';
    return 'hace ${d.inHours} h';
  }

  @override
  Widget build(BuildContext context) {
    final guest = Backend.isAnonymous;
    return Screen(
      child: Column(children: [
        const BackHeader('Cuenta'),
        Expanded(
          child: Body([
            // Quién eres.
            Panel(
              child: Row(children: [
                Avatar(guest ? '?' : (Backend.email ?? '?'), color: guest ? Hc.mut : Hc.acc, size: 42),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(guest ? 'Invitado' : Backend.email!, style: Ht.card, maxLines: 2, overflow: TextOverflow.ellipsis),
                    Text(
                      !Backend.ready
                          ? 'Sin conexión: se guarda solo en este móvil'
                          : guest
                              ? 'Tu partida solo está en este móvil'
                              : 'En la nube · ${_ago(Backend.lastPush)}',
                      style: Ht.mini,
                    ),
                  ]),
                ),
              ]),
            ),
            // Tipo de usuario, pack de épocas y panel admin.
            const AccountRights(),
            if (!Backend.ready) ...[
              Note('Motivo: ${Backend.status}', bold: 'Sin conexión con el servidor.', icon: Icons.cloud_off_outlined, kind: NoteKind.warn),
              HsButton('Reintentar conexión', kind: BtnKind.sec, block: true, loading: _busy, onTap: () async {
                setState(() => _busy = true);
                await Backend.init();
                if (Backend.ready) await cloudSave(ref);
                if (!mounted) return;
                setState(() => _busy = false);
                if (context.mounted) toast(context, Backend.ready ? 'Conectado' : Backend.status, error: !Backend.ready);
              }),
            ] else if (guest) ...[
              const Note('Crea una cuenta para no perder la partida si cambias de móvil o lo borras. Tu partida actual se guarda en ella.', icon: Icons.shield_outlined, kind: NoteKind.warn),
              HsButton('Crear cuenta', block: true, icon: Icons.person_add_alt_1_rounded,
                  onTap: () => push(context, const AuthScreen(mode: AuthMode.crear))),
              HsButton('Ya tengo cuenta', kind: BtnKind.sec, block: true, icon: Icons.login_rounded,
                  onTap: () => push(context, const AuthScreen())),
            ] else ...[
              ListBlock([
                Li(
                  lead: const IconBox(Icons.cloud_upload_outlined, color: Hc.info),
                  title: 'Guardar ahora en la nube',
                  sub: 'Se hace solo cada 2 minutos y al salir',
                  onTap: () async {
                    await saveGame(ref);
                    final ok = await cloudSave(ref);
                    if (!context.mounted) return;
                    setState(() {});
                    toast(context, ok ? 'Guardada en la nube' : 'No se ha podido subir', error: !ok);
                  },
                ),
                Li(
                  lead: const IconBox(Icons.swap_horiz_rounded, color: Hc.acc),
                  title: 'Cambiar de cuenta',
                  sub: 'Guarda esta partida y entra con otra',
                  trail: const Icon(Icons.chevron_right_rounded, color: Hc.mut),
                  onTap: () => push(context, const AuthScreen()),
                ),
                Li(
                  lead: const IconBox(Icons.logout_rounded, color: Hc.bad),
                  title: 'Cerrar sesión',
                  titleColor: Hc.bad,
                  sub: 'La partida queda en la nube',
                  onTap: () => logOut(context, ref),
                ),
                Li(
                  last: true,
                  lead: const IconBox(Icons.delete_forever_outlined, color: Hc.bad),
                  title: 'Borrar cuenta',
                  titleColor: Hc.bad,
                  sub: 'Borra la cuenta y la partida de la nube',
                  onTap: () => deleteAccount(context, ref),
                ),
              ]),
              const Cap('Contraseña'),
              TextField(controller: _pass, obscureText: true, style: Ht.bodyB, decoration: _dec('Nueva contraseña (mín. 6)')),
              HsButton('Poner o cambiar contraseña', kind: BtnKind.sec, block: true, loading: _busy, onTap: () async {
                if (_pass.text.length < 6) {
                  toast(context, 'La contraseña necesita al menos 6 caracteres', error: true);
                  return;
                }
                setState(() => _busy = true);
                final e = await Backend.setPassword(_pass.text);
                if (!mounted) return;
                setState(() => _busy = false);
                if (e == null) _pass.clear();
                if (context.mounted) toast(context, e ?? 'Contraseña guardada', error: e != null);
              }),
            ],
            const Cap('Alias en el ranking'),
            TextField(controller: _alias, style: Ht.bodyB, maxLength: 24, decoration: _dec('Promotor anónimo')),
            HsButton('Guardar alias', kind: BtnKind.sec, block: true, onTap: () async {
              final a = _alias.text.trim();
              if (a.length < 2) return;
              ref.read(aliasProvider.notifier).state = a;
              await Storage.setString('alias', a);
              await cloudSave(ref);
              if (context.mounted) toast(context, 'Alias guardado');
            }),
            const Cap('Privacidad'),
            ListBlock([
              Li(
                lead: const IconBox(Icons.policy_outlined, color: Hc.info),
                title: 'Política de privacidad',
                sub: 'Qué datos se guardan y para qué',
                trail: const Icon(Icons.open_in_new_rounded, color: Hc.mut),
                last: !Anuncios.puedePrivacidad,
                onTap: () => openWeb(context, 'privacidad/'),
              ),
              if (Anuncios.puedePrivacidad)
                Li(
                  last: true,
                  lead: const IconBox(Icons.tune_rounded, color: Hc.info),
                  title: 'Preferencias de anuncios',
                  sub: 'Cambia tu consentimiento',
                  onTap: () => Anuncios.privacidad(),
                ),
            ]),
          ]),
        ),
      ]),
    );
  }
}
