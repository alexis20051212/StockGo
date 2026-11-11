import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../repositories/repositories.dart';

/// Registro de acciones del administrador (crear, editar, eliminar, exportar).
class AuditScreen extends StatelessWidget {
  const AuditScreen({super.key});

  IconData _icon(String a) {
    switch (a) {
      case 'crear':
        return Icons.add_circle_outline;
      case 'editar':
        return Icons.edit_outlined;
      case 'eliminar':
        return Icons.delete_outline;
      default:
        return Icons.download_outlined;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Registro de acciones')),
        body: FutureBuilder<List<dynamic>>(
          future: AuditRepository().list(),
          builder: (_, s) {
            if (s.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('${s.error}', textAlign: TextAlign.center)));
            if (!s.hasData) return const Center(child: CircularProgressIndicator());
            if (s.data!.isEmpty) return const Center(child: Text('Aún no hay acciones registradas'));
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: s.data!.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final a = s.data![i];
                final fecha = a['fecha'].toString().replaceFirst('T', ' ').substring(0, 16);
                return Card(
                  child: ListTile(
                    leading: Icon(_icon('${a['accion']}'), color: AppColors.blue),
                    title: Text('${a['usuario']} · ${a['accion']} ${a['entidad']}',
                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.navy)),
                    subtitle: Text('${a['detalle'] ?? ''}\n$fecha'),
                    isThreeLine: true,
                  ),
                );
              },
            );
          },
        ),
      );
}
