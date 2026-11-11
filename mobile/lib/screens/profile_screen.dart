import 'package:flutter/material.dart';
import '../core/password_rules.dart';
import '../core/theme.dart';
import '../repositories/repositories.dart';

/// Perfil del usuario: cambiar nombre y contraseña.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _repo = AuthRepository();
  final _nombre = TextEditingController(),
      _actual = TextEditingController(),
      _nueva = TextEditingController();
  String _email = '', _rol = '';
  bool _loading = true, _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await _repo.profile();
      _nombre.text = p['nombre'] ?? '';
      _email = p['email'] ?? '';
      _rol = p['rol'] ?? '';
    } catch (e) {
      _error = '$e';
    }
    if (mounted) setState(() => _loading = false);
  }

  void _snack(String m, {bool error = true}) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(m), behavior: SnackBarBehavior.floating, backgroundColor: error ? AppColors.red : AppColors.green));

  Future<void> _saveName() async {
    if (_nombre.text.trim().isEmpty) {
      _snack('El nombre es obligatorio');
      return;
    }
    setState(() => _saving = true);
    try {
      await _repo.updateProfile(_nombre.text.trim());
      _snack('Nombre actualizado', error: false);
    } catch (e) {
      _snack('$e');
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _savePassword() async {
    final err = PasswordRules.error(_nueva.text);
    if (err != null) {
      _snack(err);
      return;
    }
    setState(() => _saving = true);
    try {
      await _repo.changePassword(_actual.text, _nueva.text);
      _actual.clear();
      _nueva.clear();
      _snack('Contraseña actualizada', error: false);
    } catch (e) {
      _snack('$e');
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Mi perfil')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)))
                : ListView(padding: const EdgeInsets.all(20), children: [
                    Center(
                      child: CircleAvatar(
                        radius: 38,
                        backgroundColor: AppColors.blue.withValues(alpha: 0.12),
                        child: Icon(_rol == 'admin' ? Icons.admin_panel_settings : Icons.badge, size: 38, color: AppColors.blue),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(child: Text(_email, style: TextStyle(color: Colors.blueGrey.shade600))),
                    Center(
                        child: Text(_rol == 'admin' ? 'Administrador' : 'Empleado',
                            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.navy))),
                    const SizedBox(height: 24),
                    TextField(controller: _nombre, decoration: const InputDecoration(labelText: 'Nombre', prefixIcon: Icon(Icons.person_outline))),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _saving ? null : _saveName, child: const Text('Guardar nombre')),
                    const SizedBox(height: 28),
                    const Text('Cambiar contraseña',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.navy)),
                    const SizedBox(height: 12),
                    TextField(
                        controller: _actual,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Contraseña actual', prefixIcon: Icon(Icons.lock_outline))),
                    const SizedBox(height: 12),
                    TextField(
                        controller: _nueva,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Contraseña nueva', prefixIcon: Icon(Icons.lock_reset))),
                    Padding(padding: const EdgeInsets.only(top: 8), child: PasswordChecklist(_nueva)),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _saving ? null : _savePassword, child: const Text('Cambiar contraseña')),
                  ]),
      );
}
