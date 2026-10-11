import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _repo.hasUsers().then((h) => setState(() => _firstRun = !h)).catchError((_) {});
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      if (_firstRun) await _repo.registerFirstAdmin(_nombre.text.trim(), _email.text.trim(), _pass.text);
      await _repo.login(_email.text.trim(), _pass.text);
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('$e'), behavior: SnackBarBehavior.floating, backgroundColor: AppColors.red));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

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
                          const SizedBox(height: 22),
                          FilledButton(
                            onPressed: _loading ? null : _submit,
                            child: _loading
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : Text(_firstRun ? 'Registrar y entrar' : 'Entrar'),
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
