import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import '../core/api_client.dart';
import '../core/password_rules.dart';
import '../core/theme.dart';
import '../repositories/repositories.dart';
import 'home_screen.dart';

const _appVersion = 'v1.0.0';

enum _Server { comprobando, ok, sinConexion }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _repo = AuthRepository();
  final _api = ApiClient();
  final _auth = LocalAuthentication();
  final _nombre = TextEditingController(), _email = TextEditingController(), _pass = TextEditingController();
  bool _loading = false, _firstRun = false, _hide = true;

  // Bloqueo por demasiados intentos
  int _cooldown = 0;
  Timer? _timer;

  // Mascota que se asoma
  Timer? _peekTimer;
  bool _peek = false;
  String _peekPose = 'principal', _peekText = '¿Necesitas ayuda?';

  // Estado del servidor, huella, tema y otros
  _Server _server = _Server.comprobando;
  bool _showConnecting = false;
  Timer? _connTimer;
  bool _bioSupported = false, _bioEnabled = false;
  bool _dark = false, _caps = false, _success = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _checkServer();
    _armPeek();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _peekTimer?.cancel();
    _connTimer?.cancel();
    super.dispose();
  }

  // ───────── Preferencias, huella y servidor ─────────
  Future<void> _loadPrefs() async {
    final email = await _api.readPref('pref_email');
    final dark = await _api.readPref('pref_dark');
    var supported = false;
    try {
      supported = await _auth.isDeviceSupported() && (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {}
    final bioPass = await _api.readPref('bio_pass');
    if (!mounted) return;
    setState(() {
      if (email != null && _email.text.isEmpty) _email.text = email;
      _dark = dark == '1';
      _bioSupported = supported;
      _bioEnabled = supported && bioPass != null;
    });
    if (_bioEnabled) _loginWithBio();
  }

  Future<void> _checkServer() async {
    setState(() {
      _server = _Server.comprobando;
      _showConnecting = false;
    });
    _connTimer?.cancel();
    _connTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _server == _Server.comprobando) setState(() => _showConnecting = true);
    });
    try {
      final h = await _repo.hasUsers();
      if (!mounted) return;
      setState(() {
        _firstRun = !h;
        _server = _Server.ok;
      });
    } catch (_) {
      if (mounted) setState(() => _server = _Server.sinConexion);
    }
    _connTimer?.cancel();
  }

  Future<void> _toggleDark() async {
    setState(() => _dark = !_dark);
    await _api.savePref('pref_dark', _dark ? '1' : '0');
  }

  Future<void> _loginWithBio() async {
    if (_loading || _cooldown > 0) return;
    try {
      final ok = await _auth.authenticate(
        localizedReason: 'Confirma tu identidad para entrar a StockGo',
        options: const AuthenticationOptions(biometricOnly: true),
      );
      if (!ok) return;
      final email = await _api.readPref('bio_email');
      final pass = await _api.readPref('bio_pass');
      if (email == null || pass == null) return;
      await _doLogin(email, pass, fromBio: true);
    } catch (_) {}
  }

  Future<void> _offerBio(String email, String pass) async {
    if (!_bioSupported || _bioEnabled) return;
    if (await _api.readPref('pref_bio_no') == '1') return;
    if (!mounted) return;
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: const Icon(Icons.fingerprint, size: 56, color: AppColors.blue),
        title: const Text('¿Entrar con tu huella?'),
        content: const Text('La próxima vez podrás entrar sin escribir tu contraseña. '
            'Se guarda cifrada en este dispositivo y puedes desactivarla cerrando sesión desde Cuenta.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'nunca'), child: const Text('No preguntar más')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'no'), child: const Text('Ahora no')),
          FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
              onPressed: () => Navigator.pop(ctx, 'si'),
              child: const Text('Activar')),
        ],
      ),
    );
    if (r == 'si') {
      await _api.savePref('bio_email', email);
      await _api.savePref('bio_pass', pass);
    } else if (r == 'nunca') {
      await _api.savePref('pref_bio_no', '1');
    }
  }

  // ───────── Mascota ─────────
  void _armPeek() {
    _peekTimer?.cancel();
    if (_peek && mounted) setState(() => _peek = false);
    _peekTimer = Timer(const Duration(minutes: 1), () {
      if (!mounted) return;
      setState(() {
        _peekPose = 'principal';
        _peekText = '¿Necesitas ayuda?';
        _peek = true;
      });
      _peekTimer = Timer(const Duration(seconds: 7), () {
        if (mounted) _armPeek();
      });
    });
  }

  /// Asoma la mascota unos segundos con otra pose (por ejemplo, tras un error).
  void _flash(String pose, String text) {
    _peekTimer?.cancel();
    setState(() {
      _peekPose = pose;
      _peekText = text;
      _peek = true;
    });
    _peekTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) _armPeek();
    });
  }

  // ───────── Inicio de sesión ─────────
  void _startCooldown(int seconds) {
    _timer?.cancel();
    setState(() => _cooldown = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  Future<void> _submit() async {
    if (_cooldown > 0) return;
    if (_firstRun) {
      final err = PasswordRules.error(_pass.text);
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err), behavior: SnackBarBehavior.floating, backgroundColor: AppColors.red));
        return;
      }
    }
    await _doLogin(_email.text.trim(), _pass.text);
  }

  Future<void> _doLogin(String email, String pass, {bool fromBio = false}) async {
    setState(() => _loading = true);
    try {
      if (_firstRun && !fromBio) await _repo.registerFirstAdmin(_nombre.text.trim(), email, pass);
      await _repo.login(email, pass);
      await _api.savePref('pref_email', email);
      if (!mounted) return;
      if (!fromBio) await _offerBio(email, pass);
      if (!mounted) return;
      _peekTimer?.cancel();
      setState(() {
        _peek = false;
        _success = true;
      });
      await Future.delayed(const Duration(milliseconds: 1100));
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    } catch (e) {
      if (!mounted) return;
      if (e is ApiException && e.tipo == ApiError.limiteExcedido) {
        final m = RegExp(r'(\d+)\s*segundos').firstMatch(e.message);
        _startCooldown(m != null ? int.parse(m.group(1)!) : 60);
        _showTooManyAttempts(e.message);
      } else {
        if (fromBio) {
          // La contraseña guardada ya no sirve (la cambiaron): se desactiva la huella.
          await _api.deletePref('bio_pass');
          await _api.deletePref('bio_email');
          setState(() => _bioEnabled = false);
        }
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating, backgroundColor: AppColors.red));
        _flash('sorprendido', '¡Revisa tus datos!');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showTooManyAttempts(String message) => showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Image.asset(
              'assets/mascota/Duda.png',
              height: 170,
              errorBuilder: (_, __, ___) => const Icon(Icons.lock_clock, size: 80, color: AppColors.red),
            ),
            const SizedBox(height: 12),
            const Text('Demasiados intentos',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.navy)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ]),
          actions: [
            FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido')),
          ],
        ),
      );

  // ───────── UI ─────────
  String get _saludo {
    final h = DateTime.now().hour;
    if (h < 12) return 'Buenos días';
    if (h < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  Widget _deco(IconData icon, double top, double? left, double? right, double size, double angle) => Positioned(
        top: top,
        left: left,
        right: right,
        child: Transform.rotate(
            angle: angle, child: Icon(icon, size: size, color: Colors.white.withValues(alpha: 0.07))),
      );

  Widget _chip(IconData icon, String text) => Expanded(
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 6),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _serverBanner() {
    if (_server == _Server.ok) return const SizedBox.shrink();
    if (_server == _Server.comprobando && !_showConnecting) return const SizedBox.shrink();
    final offline = _server == _Server.sinConexion;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: offline ? const Color(0xFFFFEBEE) : const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        offline
            ? const Icon(Icons.wifi_off, size: 20, color: AppColors.red)
            : const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            offline
                ? 'Sin conexión con el servidor. Revisa tu internet.'
                : 'Conectando con el servidor… puede tardar hasta 50 s la primera vez.',
            style: const TextStyle(fontSize: 13, color: Color(0xFF3B3B3B)),
          ),
        ),
        if (offline) TextButton(onPressed: _checkServer, child: const Text('Reintentar')),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final blocked = _cooldown > 0;
    final cardColor = _dark ? const Color(0xFF14233F) : Colors.white;
    final titleColor = _dark ? Colors.white : AppColors.navy;
    final subColor = _dark ? Colors.white60 : Colors.blueGrey.shade500;
    final fill = _dark ? const Color(0xFF1F3358) : const Color(0xFFF1F5FB);
    OutlineInputBorder b([Color? c, double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: c == null ? BorderSide.none : BorderSide(color: c, width: w));
    final formTheme = ThemeData(
      useMaterial3: true,
      brightness: _dark ? Brightness.dark : Brightness.light,
      colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.blue, primary: AppColors.blue, brightness: _dark ? Brightness.dark : Brightness.light),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: b(),
        enabledBorder: b(),
        focusedBorder: b(AppColors.blue, 2),
      ),
    );

    return Scaffold(
      body: Listener(
        onPointerDown: (_) => _armPeek(),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF071F4D), Color(0xFF0B2E6B), Color(0xFF0A74C9)],
            ),
          ),
          child: Stack(children: [
            Positioned(
                top: -90,
                right: -70,
                child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.06)))),
            Positioned(
                bottom: -120,
                left: -90,
                child: Container(
                    width: 320,
                    height: 320,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.blue.withValues(alpha: 0.18)))),
            _deco(Icons.inventory_2_outlined, 90, 24, null, 54, -0.3),
            _deco(Icons.qr_code_scanner, 150, null, 20, 60, 0.25),
            _deco(Icons.bar_chart_rounded, 520, 14, null, 64, 0.2),
            _deco(Icons.local_shipping_outlined, 600, null, 24, 56, -0.2),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, child) => Opacity(
                          opacity: v, child: Transform.translate(offset: Offset(0, 30 * (1 - v)), child: child)),
                      child: Column(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(26),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 10))
                            ],
                          ),
                          child: ClipRect(
                            child: Align(
                              alignment: Alignment.center,
                              widthFactor: 0.78,
                              heightFactor: 0.42,
                              child: Image.asset('assets/logo.jpg', width: 300),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text('Tu inventario, siempre bajo control',
                            style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.85), fontWeight: FontWeight.w500)),
                        const SizedBox(height: 18),
                        _serverBanner(),
                        Container(
                          padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 40, offset: const Offset(0, 18))
                            ],
                          ),
                          child: Theme(
                            data: formTheme,
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Container(
                                  width: 6,
                                  height: 44,
                                  decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [AppColors.blue, AppColors.green]),
                                      borderRadius: BorderRadius.circular(4)),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(_firstRun ? 'Bienvenido' : _saludo,
                                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: titleColor)),
                                    Text(_firstRun ? 'Crea la cuenta del Administrador' : 'Inicia sesión para continuar',
                                        style: TextStyle(fontSize: 14, color: subColor)),
                                  ]),
                                ),
                                IconButton(
                                  tooltip: _dark ? 'Modo claro' : 'Modo oscuro',
                                  onPressed: _toggleDark,
                                  icon: Icon(_dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, color: subColor),
                                ),
                              ]),
                              const SizedBox(height: 22),
                              if (_firstRun) ...[
                                TextField(
                                    controller: _nombre,
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(labelText: 'Nombre', prefixIcon: Icon(Icons.person_outline))),
                                const SizedBox(height: 14),
                              ],
                              TextField(
                                  controller: _email,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(labelText: 'Correo', prefixIcon: Icon(Icons.mail_outline))),
                              const SizedBox(height: 14),
                              TextField(
                                controller: _pass,
                                obscureText: _hide,
                                textInputAction: TextInputAction.done,
                                onChanged: (_) {
                                  final caps = HardwareKeyboard.instance.lockModesEnabled.contains(KeyboardLockMode.capsLock);
                                  if (caps != _caps) setState(() => _caps = caps);
                                },
                                onSubmitted: (_) => (_loading || blocked) ? null : _submit(),
                                decoration: InputDecoration(
                                  labelText: 'Contraseña',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                      icon: Icon(_hide ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                                      onPressed: () => setState(() => _hide = !_hide)),
                                ),
                              ),
                              if (_caps)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Row(children: const [
                                    Icon(Icons.keyboard_capslock, size: 18, color: Color(0xFFF57C00)),
                                    SizedBox(width: 6),
                                    Text('Bloq Mayús activado', style: TextStyle(fontSize: 13, color: Color(0xFFF57C00))),
                                  ]),
                                ),
                              if (_firstRun) Padding(padding: const EdgeInsets.only(top: 8), child: PasswordChecklist(_pass)),
                              const SizedBox(height: 24),
                              Opacity(
                                opacity: (_loading || blocked) ? 0.85 : 1,
                                child: Material(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                  child: Ink(
                                    height: 56,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      gradient: LinearGradient(
                                        colors: blocked
                                            ? [Colors.blueGrey.shade300, Colors.blueGrey.shade400]
                                            : const [Color(0xFF00A3E0), Color(0xFF0A5AA8)],
                                      ),
                                      boxShadow: blocked
                                          ? null
                                          : [BoxShadow(color: AppColors.blue.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 6))],
                                    ),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(16),
                                      onTap: (_loading || blocked) ? null : _submit,
                                      child: Center(
                                        child: _loading
                                            ? const SizedBox(
                                                height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                                            : Row(mainAxisSize: MainAxisSize.min, children: [
                                                if (blocked) ...[const Icon(Icons.timer_outlined, color: Colors.white), const SizedBox(width: 8)],
                                                Text(
                                                    blocked
                                                        ? 'Reintenta en ${_cooldown ~/ 60}:${(_cooldown % 60).toString().padLeft(2, '0')}'
                                                        : (_firstRun ? 'Registrar y entrar' : 'Entrar'),
                                                    style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
                                                if (!blocked) ...[const SizedBox(width: 8), const Icon(Icons.arrow_forward_rounded, color: Colors.white)],
                                              ]),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (_bioEnabled && !_firstRun) ...[
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: (_loading || blocked) ? null : _loginWithBio,
                                  icon: const Icon(Icons.fingerprint),
                                  label: const Text('Entrar con huella'),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(52),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    side: const BorderSide(color: AppColors.blue),
                                  ),
                                ),
                              ],
                              if (blocked)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Row(children: [
                                    Icon(Icons.info_outline, size: 16, color: subColor),
                                    const SizedBox(width: 6),
                                    Expanded(
                                        child: Text('Demasiados intentos fallidos. Espera para volver a intentar.',
                                            style: TextStyle(fontSize: 13, color: subColor))),
                                  ]),
                                ),
                            ]),
                          ),
                        ),
                        const SizedBox(height: 26),
                        Row(children: [
                          _chip(Icons.qr_code_scanner, 'Escanea'),
                          _chip(Icons.inventory_2_outlined, 'Controla'),
                          _chip(Icons.notifications_active_outlined, 'Recibe alertas'),
                        ]),
                        const SizedBox(height: 22),
                        Text('StockGo $_appVersion',
                            style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.55))),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
            // Mascota que se asoma (inactividad o error)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutBack,
              right: 10,
              bottom: _peek ? -8 : -230,
              child: GestureDetector(
                onTap: _armPeek,
                child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                    child: Text(_peekText,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.navy)),
                  ),
                  const SizedBox(height: 4),
                  Image.asset('assets/mascota/$_peekPose.png', height: 150),
                ]),
              ),
            ),
            // Animación de éxito
            if (_success)
              Positioned.fill(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOut,
                  builder: (_, v, child) => Opacity(opacity: v, child: child),
                  child: Container(
                    color: const Color(0xF2071F4D),
                    child: Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Image.asset('assets/mascota/emocionado.png', height: 190),
                        const SizedBox(height: 12),
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.elasticOut,
                          builder: (_, v, child) => Transform.scale(scale: v, child: child),
                          child: const Icon(Icons.check_circle, color: AppColors.green, size: 72),
                        ),
                        const SizedBox(height: 8),
                        const Text('¡Bienvenido!',
                            style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
                      ]),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
