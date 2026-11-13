import 'dart:async';
import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../core/password_rules.dart';
import '../core/theme.dart';
import '../repositories/repositories.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _repo = AuthRepository();
  final _nombre = TextEditingController(), _email = TextEditingController(), _pass = TextEditingController();
  bool _loading = false, _firstRun = false, _hide = true;
  int _cooldown = 0; // segundos que faltan para poder intentar de nuevo
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _repo.hasUsers().then((h) => setState(() => _firstRun = !h)).catchError((_) {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Bloquea el botón y cuenta hacia atrás los segundos indicados por el servidor.
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(err), behavior: SnackBarBehavior.floating, backgroundColor: AppColors.red));
        return;
      }
    }
    setState(() => _loading = true);
    try {
      if (_firstRun) await _repo.registerFirstAdmin(_nombre.text.trim(), _email.text.trim(), _pass.text);
      await _repo.login(_email.text.trim(), _pass.text);
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    } catch (e) {
      if (!mounted) return;
      if (e is ApiException && e.tipo == ApiError.limiteExcedido) {
        final m = RegExp(r'(\d+)\s*segundos').firstMatch(e.message);
        _startCooldown(m != null ? int.parse(m.group(1)!) : 60);
        _showTooManyAttempts(e.message);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('$e'), behavior: SnackBarBehavior.floating, backgroundColor: AppColors.red));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Aviso de bloqueo por demasiados intentos, con la mascota "Duda".
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

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFDCEBFF), Colors.white],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(children: [
                    // Recorte del logo para quitar el marco blanco de la imagen
                    ClipRect(
                      child: Align(
                        alignment: Alignment.center,
                        widthFactor: 0.78,
                        heightFactor: 0.42,
                        child: Image.asset('assets/logo.jpg', width: 400),
                      ),
                    ),
                    Image.asset('assets/mascota/principal.png', height: 200),
                    const SizedBox(height: 6),
                    const Text('¡Juntos hacemos que tu inventario avance!',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 15, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600, color: AppColors.navy)),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 4,
                      shadowColor: AppColors.blue.withValues(alpha: 0.2),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(_firstRun ? 'Bienvenido' : 'Iniciar sesión',
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.navy)),
                          const SizedBox(height: 4),
                          Text(
                              _firstRun
                                  ? 'Crea la cuenta del Administrador para empezar'
                                  : 'Ingresa con tu cuenta de StockGo',
                              style: TextStyle(color: Colors.blueGrey.shade500)),
                          const SizedBox(height: 20),
                          if (_firstRun) ...[
                            TextField(
                                controller: _nombre,
                                decoration: const InputDecoration(labelText: 'Nombre', prefixIcon: Icon(Icons.person_outline))),
                            const SizedBox(height: 14),
                          ],
                          TextField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(labelText: 'Correo', prefixIcon: Icon(Icons.mail_outline))),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _pass,
                            obscureText: _hide,
                            decoration: InputDecoration(
                              labelText: 'Contraseña',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                  icon: Icon(_hide ? Icons.visibility_off : Icons.visibility),
                                  onPressed: () => setState(() => _hide = !_hide)),
                            ),
                          ),
                          if (_firstRun)
                            Padding(padding: const EdgeInsets.only(top: 8), child: PasswordChecklist(_pass)),
                          const SizedBox(height: 22),
                          FilledButton(
                            onPressed: (_loading || _cooldown > 0) ? null : _submit,
                            child: _loading
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : Text(_cooldown > 0
                                    ? 'Reintenta en ${_cooldown ~/ 60}:${(_cooldown % 60).toString().padLeft(2, '0')}'
                                    : (_firstRun ? 'Registrar y entrar' : 'Entrar')),
                          ),
                        ]),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
}
