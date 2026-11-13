import 'dart:convert';
import 'package:flutter/material.dart';
import '../repositories/repositories.dart';
import 'api_client.dart';
import 'theme.dart';

enum NotifTipo { stockBajo, sinStock, nuevoProducto }

class AppNotif {
  final String id; // único por evento
  final NotifTipo tipo;
  final String titulo, detalle;
  final DateTime fecha;
  bool leida;
  AppNotif(this.id, this.tipo, this.titulo, this.detalle, this.fecha, {this.leida = false});

  Map<String, dynamic> toJson() => {
        'id': id, 'tipo': tipo.name, 'titulo': titulo, 'detalle': detalle,
        'fecha': fecha.toIso8601String(), 'leida': leida,
      };
  factory AppNotif.fromJson(Map<String, dynamic> j) => AppNotif(
        j['id'], NotifTipo.values.firstWhere((t) => t.name == j['tipo'], orElse: () => NotifTipo.stockBajo),
        j['titulo'], j['detalle'], DateTime.parse(j['fecha']), leida: j['leida'] == true);
}

/// Centro de notificaciones interno: avisa de stock bajo / agotado y de productos nuevos.
/// Se guarda en la caché local (se borra al cerrar sesión).
class NotificationService extends ChangeNotifier {
  NotificationService._();
  static final instance = NotificationService._();

  final _api = ApiClient();
  List<AppNotif> items = [];
  Set<int> _bajos = {}; // productos que ya avisamos como "bajos"
  Set<int> _conocidos = {}; // productos ya vistos (para detectar nuevos)
  bool _seeded = false, _loaded = false;
  void Function(AppNotif)? onNueva; // para mostrar aviso emergente

  int get sinLeer => items.where((n) => !n.leida).length;

  Future<void> _load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final c = await _api.readCache('notifs');
      if (c != null) {
        final j = jsonDecode(c) as Map<String, dynamic>;
        items = (j['items'] as List).map((e) => AppNotif.fromJson(e)).toList();
        _bajos = (j['bajos'] as List).cast<int>().toSet();
        _conocidos = (j['conocidos'] as List).cast<int>().toSet();
        _seeded = j['seeded'] == true;
      }
    } catch (_) {}
  }

  Future<void> _save() => _api.saveCache(
      'notifs',
      jsonEncode({
        'items': items.take(100).map((n) => n.toJson()).toList(),
        'bajos': _bajos.toList(),
        'conocidos': _conocidos.toList(),
        'seeded': _seeded,
      }));

  /// Llamar con la lista fresca del servidor (no con la caché sin conexión).
  Future<void> sync(List<Product> products) async {
    await _load();
    final nuevas = <AppNotif>[];
    final now = DateTime.now();

    if (_seeded) {
      for (final p in products.where((p) => !_conocidos.contains(p.id))) {
        nuevas.add(AppNotif('nuevo_${p.id}', NotifTipo.nuevoProducto, 'Nuevo producto agregado',
            '${p.nombre} se agregó al inventario (${p.stock} uds).', now));
      }
    }
    for (final p in products) {
      if (p.bajo) {
        if (!_bajos.contains(p.id)) {
          nuevas.add(p.stock <= 0
              ? AppNotif('sin_${p.id}_${now.millisecondsSinceEpoch}', NotifTipo.sinStock, 'Producto agotado',
                  '${p.nombre} se quedó sin stock.', now)
              : AppNotif('bajo_${p.id}_${now.millisecondsSinceEpoch}', NotifTipo.stockBajo, 'Stock bajo',
                  '${p.nombre}: quedan ${p.stock} uds (mínimo ${p.stockMinimo}).', now));
        }
      }
    }
    _bajos = products.where((p) => p.bajo).map((p) => p.id).toSet(); // al reponer, vuelve a poder avisar
    _conocidos = products.map((p) => p.id).toSet();
    _seeded = true; // la primera vez solo se registra, sin avisar de "nuevos"

    if (nuevas.isNotEmpty) {
      items.insertAll(0, nuevas);
      for (final n in nuevas) {
        onNueva?.call(n);
      }
    }
    await _save();
    notifyListeners();
  }

  Future<void> marcarTodas() async {
    for (final n in items) {
      n.leida = true;
    }
    await _save();
    notifyListeners();
  }

  Future<void> borrarTodas() async {
    items.clear();
    await _save();
    notifyListeners();
  }

  void reset() {
    items = [];
    _bajos = {};
    _conocidos = {};
    _seeded = false;
    _loaded = false;
    notifyListeners();
  }
}

/// Campana con contador para la barra superior.
class NotifBell extends StatelessWidget {
  const NotifBell({super.key});
  @override
  Widget build(BuildContext context) {
    final svc = NotificationService.instance;
    return ListenableBuilder(
      listenable: svc,
      builder: (_, __) => Tooltip(
        message: 'Notificaciones',
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => showNotifSheet(context),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Badge(
              isLabelVisible: svc.sinLeer > 0,
              label: Text('${svc.sinLeer > 9 ? '9+' : svc.sinLeer}'),
              backgroundColor: AppColors.red,
              child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 28),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showNotifSheet(BuildContext context) {
  final svc = NotificationService.instance;
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, scroll) => ListenableBuilder(
        listenable: svc,
        builder: (_, __) => Column(children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.blueGrey.shade100, borderRadius: BorderRadius.circular(4))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 8, 4),
            child: Row(children: [
              const Expanded(
                  child: Text('Notificaciones',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.navy))),
              if (svc.sinLeer > 0) TextButton(onPressed: svc.marcarTodas, child: const Text('Marcar leídas')),
              if (svc.items.isNotEmpty) TextButton(onPressed: svc.borrarTodas, child: const Text('Borrar')),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: svc.items.isEmpty
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.notifications_none, size: 56, color: Colors.blueGrey.shade200),
                      const SizedBox(height: 8),
                      Text('Sin notificaciones', style: TextStyle(color: Colors.blueGrey.shade400)),
                    ]),
                  )
                : ListView.separated(
                    controller: scroll,
                    itemCount: svc.items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final n = svc.items[i];
                      final (icono, color) = switch (n.tipo) {
                        NotifTipo.sinStock => (Icons.remove_shopping_cart, AppColors.red),
                        NotifTipo.stockBajo => (Icons.warning_amber_rounded, const Color(0xFFF57C00)),
                        NotifTipo.nuevoProducto => (Icons.add_box_outlined, AppColors.green),
                      };
                      return ListTile(
                        tileColor: n.leida ? null : AppColors.blue.withValues(alpha: 0.07),
                        leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.15), child: Icon(icono, color: color)),
                        title: Text(n.titulo, style: TextStyle(fontWeight: n.leida ? FontWeight.w600 : FontWeight.w800)),
                        subtitle: Text('${n.detalle}\n${_hace(n.fecha)}'),
                        isThreeLine: true,
                      );
                    },
                  ),
          ),
        ]),
      ),
    ),
  ).whenComplete(svc.marcarTodas);
}

String _hace(DateTime d) {
  final m = DateTime.now().difference(d).inMinutes;
  if (m < 1) return 'Ahora';
  if (m < 60) return 'Hace $m min';
  if (m < 1440) return 'Hace ${m ~/ 60} h';
  return 'Hace ${m ~/ 1440} d';
}
