import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../repositories/repositories.dart';
import '../widgets/peeking_dialog.dart';

void _msg(BuildContext c, String m, {bool error = true}) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(
        content: Row(children: [
          Image.asset(error ? 'assets/mascota/sorprendido.png' : 'assets/mascota/emocionado.png', height: 36),
          const SizedBox(width: 12),
          Expanded(child: Text(m)),
        ]),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? AppColors.red : AppColors.green));

/// Pestaña exclusiva del Administrador: crear empleados y administrar cuentas.
class UsersView extends StatefulWidget {
  const UsersView({super.key});
  @override
  State<UsersView> createState() => _UsersViewState();
}

class _UsersViewState extends State<UsersView> {
  final _repo = UserRepository();
  List<UserItem> _users = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _users = await _repo.list();
    } catch (e) {
      _error = '$e';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _update(UserItem u, Map<String, dynamic> data, String okMsg) async {
    try {
      await _repo.update(u.id, data);
      if (mounted) _msg(context, okMsg, error: false);
      _load();
    } catch (e) {
      if (mounted) _msg(context, '$e');
    }
  }

  Future<void> _resetPassword(UserItem u) async {
    final pass = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Nueva contraseña para ${u.nombre}'),
        content: TextField(
            controller: pass,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Contraseña (mínimo 6)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Guardar')),
        ],
      ),
    );
    if (ok == true) _update(u, {'password': pass.text}, 'Contraseña actualizada');
  }

  Future<void> _create() async {
    final nombre = TextEditingController(), email = TextEditingController(), pass = TextEditingController();
    String rol = 'empleado';
    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, set) => PeekingDialog(
          title: const Text('Nuevo usuario'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: nombre, decoration: const InputDecoration(labelText: 'Nombre')),
              const SizedBox(height: 10),
              TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Correo')),
              const SizedBox(height: 10),
              TextField(
                  controller: pass,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Contraseña (mínimo 6)')),
              const SizedBox(height: 14),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'empleado', label: Text('Empleado'), icon: Icon(Icons.badge_outlined)),
                  ButtonSegment(value: 'admin', label: Text('Admin'), icon: Icon(Icons.admin_panel_settings_outlined)),
                ],
                selected: {rol},
                onSelectionChanged: (s) => set(() => rol = s.first),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
              onPressed: () async {
                try {
                  await _repo.create({
                    'nombre': nombre.text.trim(), 'email': email.text.trim(),
                    'password': pass.text, 'rol': rol,
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) _msg(context, 'Usuario creado', error: false);
                  _load();
                } catch (e) {
                  if (mounted) _msg(context, '$e');
                }
              },
              child: const Text('Crear'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppColors.blue,
          foregroundColor: Colors.white,
          onPressed: _create,
          icon: const Icon(Icons.person_add),
          label: const Text('Usuario'),
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? ListView(children: [
                      const SizedBox(height: 60),
                      Image.asset('assets/mascota/sorprendido.png', height: 160),
                      Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)),
                    ])
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                      itemCount: _users.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final u = _users[i];
                        final admin = u.rol == 'admin';
                        final color = admin ? AppColors.navy : AppColors.blue;
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: color.withValues(alpha: 0.12),
                              child: Icon(admin ? Icons.admin_panel_settings : Icons.badge, color: color),
                            ),
                            title: Text(u.nombre,
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: u.activo ? AppColors.navy : Colors.blueGrey.shade300,
                                    decoration: u.activo ? null : TextDecoration.lineThrough)),
                            subtitle: Text(
                                '${u.email}\n${admin ? 'Administrador' : 'Empleado'}${u.activo ? '' : ' · Desactivado'}'),
                            isThreeLine: true,
                            trailing: PopupMenuButton<String>(
                              onSelected: (v) {
                                switch (v) {
                                  case 'rol':
                                    _update(u, {'rol': admin ? 'empleado' : 'admin'}, 'Rol actualizado');
                                    break;
                                  case 'activo':
                                    _update(u, {'activo': u.activo ? 0 : 1},
                                        u.activo ? 'Cuenta desactivada' : 'Cuenta activada');
                                    break;
                                  case 'pass':
                                    _resetPassword(u);
                                    break;
                                }
                              },
                              itemBuilder: (_) => [
                                PopupMenuItem(value: 'rol', child: Text(admin ? 'Cambiar a Empleado' : 'Cambiar a Administrador')),
                                PopupMenuItem(value: 'activo', child: Text(u.activo ? 'Desactivar cuenta' : 'Activar cuenta')),
                                const PopupMenuItem(value: 'pass', child: Text('Restablecer contraseña')),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      );
}
