import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/notifications.dart';
import '../core/theme.dart';
import '../repositories/repositories.dart';
import 'audit_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import '../widgets/peeking_dialog.dart';
import 'scanner_screen.dart';
import 'users_screen.dart';

void _toast(BuildContext c, String m, {bool error = true}) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(
        content: Row(children: [
          Image.asset(error ? 'assets/mascota/sorprendido.png' : 'assets/mascota/emocionado.png', height: 38),
          const SizedBox(width: 12),
          Expanded(child: Text(m)),
        ]),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? AppColors.red : AppColors.green));

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  bool _isAdmin = false;
  String _nombre = '';

  @override
  void initState() {
    super.initState();
    final auth = AuthRepository();
    auth.role().then((r) => setState(() => _isAdmin = r == 'admin'));
    auth.name().then((n) => setState(() => _nombre = n ?? ''));
    NotificationService.instance.onNueva = (n) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${n.titulo}: ${n.detalle}'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: n.tipo == NotifTipo.nuevoProducto ? AppColors.green : AppColors.red,
        action: SnackBarAction(label: 'Ver', textColor: Colors.white, onPressed: () => showNotifSheet(context)),
      ));
    };
  }

  Future<void> _logout() async {
    final pend = (await MovementRepository().pending()).length;
    if (pend > 0 && mounted) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Movimientos sin enviar'),
          content: Text('Tienes $pend movimiento(s) guardado(s) sin conexión. Si cierras sesión se perderán.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cerrar sesión')),
          ],
        ),
      );
      if (ok != true) return;
    }
    await AuthRepository().logout();
    NotificationService.instance.reset();
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  Future<void> _export() async {
    try {
      final csv = await ProductRepository().exportCsv();
      await Clipboard.setData(ClipboardData(text: csv));
      if (mounted) _toast(context, 'Inventario copiado (CSV). Pégalo en una hoja de cálculo.', error: false);
    } catch (e) {
      if (mounted) _toast(context, '$e');
    }
  }

  Future<void> _menu(String v) async {
    switch (v) {
      case 'perfil':
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
        final n = await AuthRepository().name();
        if (mounted) setState(() => _nombre = n ?? '');
        break;
      case 'audit':
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const AuditScreen()));
        break;
      case 'export':
        await _export();
        break;
      case 'logout':
        await _logout();
        break;
    }
  }

  String get _inicial => _nombre.isNotEmpty ? _nombre[0].toUpperCase() : '?';

  /// Hoja "Mi cuenta": perfil, exportar, registro de acciones y cerrar sesión.
  Future<void> _accountSheet() async {
    final op = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) {
        Widget tile(IconData icon, String title, String sub, String value, {Color? color}) {
          final c = color ?? AppColors.blue;
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: c),
            ),
            title: Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: color ?? AppColors.navy)),
            subtitle: Text(sub, style: const TextStyle(fontSize: 12)),
            trailing: Icon(Icons.chevron_right, color: Colors.blueGrey.shade300),
            onTap: () => Navigator.pop(ctx, value),
          );
        }

        return SafeArea(
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                child: Row(children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.navy,
                    child: Text(_inicial, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_nombre, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.navy)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.blue.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                        child: Text(_isAdmin ? 'Administrador' : 'Empleado',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.navy)),
                      ),
                    ]),
                  ),
                ]),
              ),
              const Divider(height: 1),
              tile(Icons.person_outline, 'Mi perfil', 'Cambiar nombre y contraseña', 'perfil'),
              if (_isAdmin) tile(Icons.download_outlined, 'Exportar inventario', 'Copiar el inventario en formato CSV', 'export'),
              if (_isAdmin) tile(Icons.history, 'Registro de acciones', 'Quién creó, editó o eliminó', 'audit'),
              const Divider(height: 1),
              tile(Icons.logout, 'Cerrar sesión', 'Salir de tu cuenta', 'logout', color: AppColors.red),
              const SizedBox(height: 12),
            ]),
          ),
        );
      },
    );
    if (op != null) await _menu(op);
  }

  @override
  Widget build(BuildContext context) {
    // Responsivo: en pantallas anchas (PC/tablet) el menú pasa a un lateral y el contenido se centra.
    final ancho = MediaQuery.of(context).size.width;
    final wide = ancho >= 900;
    final destinos = [
      (Icons.inventory_2_outlined, Icons.inventory_2, 'Inventario'),
      (Icons.swap_vert, Icons.swap_vert_circle, 'Movimientos'),
      if (_isAdmin) (Icons.group_outlined, Icons.group, 'Usuarios'),
    ];
    final pagina = _tab == 0
        ? InventoryView(isAdmin: _isAdmin)
        : _tab == 1
            ? const MovementsView()
            : const UsersView();
    return Scaffold(
        appBar: AppBar(
          toolbarHeight: 78,
          titleSpacing: 16,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0B2E6B), Color(0xFF0A62B8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          title: Row(children: [
            Image.asset('assets/mascota/pose_app.png', height: 48),
            const SizedBox(width: 10),
            Expanded(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('StockGo', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22)),
                Text('Hola, $_nombre', maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: Colors.white70)),
              ]),
            ),
          ]),
          actions: [
            const NotifBell(),
            Padding(
              padding: const EdgeInsets.only(right: 12, left: 4),
              child: Tooltip(
                message: 'Mi cuenta',
                child: InkWell(
                  borderRadius: BorderRadius.circular(30),
                  onTap: _accountSheet,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(5, 5, 10, 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      CircleAvatar(
                        radius: 17,
                        backgroundColor: Colors.white,
                        child: Text(_inicial, style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w800, fontSize: 17)),
                      ),
                      const SizedBox(width: 6),
                      const Text('Cuenta', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                      const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 20),
                    ]),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Row(children: [
          if (wide) ...[
            NavigationRail(
              selectedIndex: _tab.clamp(0, destinos.length - 1),
              onDestinationSelected: (i) => setState(() => _tab = i),
              extended: ancho >= 1200,
              backgroundColor: Colors.white,
              indicatorColor: AppColors.blue.withValues(alpha: 0.16),
              labelType: ancho >= 1200 ? NavigationRailLabelType.none : NavigationRailLabelType.all,
              destinations: [
                for (final d in destinos)
                  NavigationRailDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: Text(d.$3)),
              ],
            ),
            const VerticalDivider(width: 1),
          ],
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: _tab == 0 ? 1200 : 860),
                child: pagina,
              ),
            ),
          ),
        ]),
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: _tab,
                onDestinationSelected: (i) => setState(() => _tab = i),
                destinations: [
                  for (final d in destinos)
                    NavigationDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: d.$3),
                ],
              ),
    );
  }
}

class _Empty extends StatelessWidget {
  final String asset;
  final String text;
  const _Empty(this.asset, this.text);
  @override
  Widget build(BuildContext context) => ListView(children: [
        const SizedBox(height: 40),
        Center(child: Image.asset(asset, height: 190)),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(text,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.blueGrey.shade500, fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      ]);
}

// ---------------- INVENTARIO ----------------
class InventoryView extends StatefulWidget {
  final bool isAdmin;
  const InventoryView({super.key, required this.isAdmin});
  @override
  State<InventoryView> createState() => _InventoryViewState();
}

class _InventoryViewState extends State<InventoryView> {
  final _products = ProductRepository(), _moves = MovementRepository();
  List<Product> _all = [];
  String _q = '', _filtro = 'todos', _cat = 'Todas', _orden = 'nombre';
  int _reload = 0;
  bool _loading = true, _offline = false;
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
    _reload++;
    try {
      final r = await _moves.flushPending();
      if (mounted && r['sent']! > 0) _toast(context, '${r['sent']} movimiento(s) pendiente(s) enviado(s)', error: false);
      if (mounted && r['failed']! > 0) _toast(context, '${r['failed']} movimiento(s) pendiente(s) fueron rechazados por el servidor');
    } catch (_) {}
    try {
      _all = await _products.list();
      _offline = _products.fromCache;
      if (!_offline) await NotificationService.instance.sync(_all);
    } catch (e) {
      _error = '$e';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _move(Product p) async {
    final r = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _MoveSheet(p),
    );
    if (r == null) return;
    try {
      final enviado = await _moves.register(p.id, r['tipo'], r['qty']);
      if (mounted) {
        _toast(context, enviado ? 'Movimiento registrado' : 'Sin conexión: movimiento guardado. Se enviará al volver internet.',
            error: false);
      }
      _load();
    } catch (e) {
      if (mounted) _toast(context, '$e');
    }
  }

  Future<void> _confirmDelete(Product p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text('¿Eliminar "${p.nombre}"? El historial se conserva.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.red, minimumSize: const Size(100, 44)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _products.delete(p.id);
      _load();
    } catch (e) {
      if (mounted) _toast(context, '$e');
    }
  }

  Future<Map<String, dynamic>?> _lookup(String c) async {
    try {
      return await _products.lookupBarcode(c.trim());
    } catch (e) {
      if (mounted) _toast(context, '$e');
      return null;
    }
  }

  Future<void> _scan(TextEditingController code, void Function(Map<String, dynamic>) apply) async {
    final scanned = await Navigator.of(context, rootNavigator: true)
        .push<String>(MaterialPageRoute(builder: (_) => const ScannerScreen()));
    if (scanned == null) return;
    code.text = scanned;
    final r = await _lookup(scanned);
    if (r != null) apply(r);
  }

  Future<void> _actions(Product p) async {
    final op = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(p.nombre, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.navy)),
          ),
          ListTile(leading: const Icon(Icons.edit_outlined), title: const Text('Editar producto'), onTap: () => Navigator.pop(ctx, 'editar')),
          ListTile(leading: const Icon(Icons.delete_outline, color: AppColors.red), title: const Text('Eliminar producto'), onTap: () => Navigator.pop(ctx, 'eliminar')),
        ]),
      ),
    );
    if (op == 'editar') await _editProduct(p);
    if (op == 'eliminar') await _confirmDelete(p);
  }

  Future<void> _editProduct(Product p) async {
    final nombre = TextEditingController(text: p.nombre),
        marca = TextEditingController(text: p.marca ?? ''),
        cat = TextEditingController(text: p.categoria ?? ''),
        minimo = TextEditingController(text: '${p.stockMinimo}');
    await showDialog(
      context: context,
      builder: (ctx) => PeekingDialog(
        title: const Text('Editar producto'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nombre, decoration: const InputDecoration(labelText: 'Nombre')),
            const SizedBox(height: 10),
            TextField(controller: marca, decoration: const InputDecoration(labelText: 'Marca')),
            const SizedBox(height: 10),
            TextField(controller: cat, decoration: const InputDecoration(labelText: 'Categoría')),
            const SizedBox(height: 10),
            TextField(
                controller: minimo,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Stock mínimo (alerta)')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
            onPressed: () async {
              if (nombre.text.trim().isEmpty) {
                _toast(context, 'El nombre es obligatorio');
                return;
              }
              try {
                await _products.update(p.id, {
                  'nombre': nombre.text.trim(), 'marca': marca.text.trim(),
                  'categoria': cat.text.trim(), 'imagen_url': p.imagenUrl,
                  'stock_minimo': int.tryParse(minimo.text.trim()) ?? p.stockMinimo,
                });
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) _toast(context, 'Producto actualizado', error: false);
                _load();
              } catch (e) {
                if (mounted) _toast(context, '$e');
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _addProduct() async {
    final code = TextEditingController(), nombre = TextEditingController(),
        marca = TextEditingController(), cat = TextEditingController(),
        minimo = TextEditingController(text: '5');
    String? img;
    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, set) => PeekingDialog(
          title: const Text('Nuevo producto'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Escanear con la cámara'),
                  onPressed: () => _scan(code, (r) {
                    set(() {
                      nombre.text = r['nombre'] ?? '';
                      marca.text = r['marca'] ?? '';
                      cat.text = r['categoria'] ?? '';
                      img = r['imagen_url'];
                    });
                  }),
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: TextField(
                        controller: code,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Código de barras', prefixIcon: Icon(Icons.qr_code)))),
                IconButton.filled(
                  icon: const Icon(Icons.search),
                  tooltip: 'Buscar en Open Food Facts',
                  onPressed: () async {
                    final r = await _lookup(code.text);
                    if (r != null) {
                      set(() {
                        nombre.text = r['nombre'] ?? '';
                        marca.text = r['marca'] ?? '';
                        cat.text = r['categoria'] ?? '';
                        img = r['imagen_url'];
                      });
                    }
                  },
                ),
              ]),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: const Text('Generar código interno'),
                  onPressed: () => set(() => code.text =
                      '2${(DateTime.now().millisecondsSinceEpoch % 1000000000000).toString().padLeft(12, '0')}'),
                ),
              ),
              if (img != null && img!.isNotEmpty)
                Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(img!, height: 90, errorBuilder: (_, __, ___) => const SizedBox()))),
              const SizedBox(height: 12),
              TextField(controller: nombre, decoration: const InputDecoration(labelText: 'Nombre')),
              const SizedBox(height: 10),
              TextField(controller: marca, decoration: const InputDecoration(labelText: 'Marca')),
              const SizedBox(height: 10),
              TextField(controller: cat, decoration: const InputDecoration(labelText: 'Categoría')),
              const SizedBox(height: 10),
              TextField(
                  controller: minimo,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Stock mínimo (alerta)')),
              const SizedBox(height: 12),
              Text('Datos de producto: Open Food Facts (licencia ODbL)',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade400)),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
              onPressed: () async {
                try {
                  await _products.create({
                    'codigo_barras': code.text.trim(), 'nombre': nombre.text.trim(),
                    'marca': marca.text.trim(), 'categoria': cat.text.trim(), 'imagen_url': img,
                    'stock_minimo': int.tryParse(minimo.text.trim()) ?? 5,
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();
                } catch (e) {
                  if (mounted) _toast(context, '$e');
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catSet = _all.map((p) => p.categoria ?? '').where((c) => c.isNotEmpty).toSet().toList()..sort();
    final cats = ['Todas', ...catSet];
    if (!cats.contains(_cat)) _cat = 'Todas';
    final list = _all
        .where((p) => p.nombre.toLowerCase().contains(_q.toLowerCase()))
        .where((p) => _filtro == 'todos' || p.bajo)
        .where((p) => _cat == 'Todas' || p.categoria == _cat)
        .toList();
    if (_orden == 'stock') {
      list.sort((a, b) => a.stock.compareTo(b.stock));
    } else {
      list.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
    }
    final units = _all.fold<int>(0, (a, p) => a + p.stock);
    final low = _all.where((p) => p.bajo).length;
    return Scaffold(
      floatingActionButton: widget.isAdmin
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              onPressed: _addProduct,
              icon: const Icon(Icons.add),
              label: const Text('Producto'))
          : null,
      body: RefreshIndicator(
        onRefresh: _load,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(children: [
              _Stat('Productos', '${_all.length}', Icons.category, AppColors.blue),
              const SizedBox(width: 10),
              _Stat('Unidades', '$units', Icons.layers, AppColors.green),
              const SizedBox(width: 10),
              _Stat('Stock bajo', '$low', Icons.warning_amber, low > 0 ? AppColors.red : Colors.blueGrey),
            ]),
          ),
          if (!_offline) _WeeklyChart(key: ValueKey(_reload)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _q = v),
              decoration: const InputDecoration(hintText: 'Buscar producto...', prefixIcon: Icon(Icons.search)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                FilterChip(
                    label: const Text('Stock bajo'),
                    selected: _filtro == 'bajo',
                    onSelected: (v) => setState(() => _filtro = v ? 'bajo' : 'todos')),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _cat,
                  underline: const SizedBox.shrink(),
                  items: cats.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setState(() => _cat = v ?? 'Todas'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(label: const Text('A-Z'), selected: _orden == 'nombre', onSelected: (_) => setState(() => _orden = 'nombre')),
                const SizedBox(width: 8),
                ChoiceChip(label: const Text('Menor stock'), selected: _orden == 'stock', onSelected: (_) => setState(() => _orden = 'stock')),
              ]),
            ),
          ),
          if (_offline)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFFFF3D6), borderRadius: BorderRadius.circular(12)),
              child: const Row(children: [
                Icon(Icons.cloud_off, size: 18, color: Color(0xFF8A5A00)),
                SizedBox(width: 8),
                Expanded(
                    child: Text('Sin conexión: mostrando el último inventario guardado. Desliza para reintentar.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF8A5A00)))),
              ]),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _Empty('assets/mascota/sorprendido.png', _error!)
                    : list.isEmpty
                        ? _Empty('assets/mascota/pose_caja.png', _q.isEmpty ? 'Aún no hay productos. ¡Agrega el primero!' : 'Sin resultados')
                        : LayoutBuilder(builder: (ctx, c) {
                            Widget card(int i) => _ProductCard(
                                  list[i],
                                  onTap: () => _move(list[i]),
                                  onLong: widget.isAdmin ? () => _actions(list[i]) : null,
                                );
                            // Pantalla ancha: cuadrícula de 2 o más columnas; teléfono: lista
                            if (c.maxWidth >= 700) {
                              return GridView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 440, mainAxisExtent: 100, crossAxisSpacing: 12, mainAxisSpacing: 12),
                                itemCount: list.length,
                                itemBuilder: (_, i) => card(i),
                              );
                            }
                            return ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                              itemCount: list.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (_, i) => card(i),
                            );
                          }),
          ),
        ]),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _Stat(this.label, this.value, this.icon, this.color);
  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.18)),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: color)),
            Text(label, style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade500)),
          ]),
        ),
      );
}

class _ProductCard extends StatelessWidget {
  final Product p;
  final VoidCallback onTap;
  final VoidCallback? onLong;
  const _ProductCard(this.p, {required this.onTap, this.onLong});
  @override
  Widget build(BuildContext context) {
    final low = p.bajo;
    final color = low ? AppColors.red : AppColors.green;
    final sub = [p.marca, p.categoria].where((e) => e?.isNotEmpty ?? false).join(' · ');
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      color: low ? const Color(0xFFFFF7F7) : Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: low ? AppColors.red.withValues(alpha: 0.3) : Colors.blueGrey.shade50)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        onLongPress: onLong,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 68,
                height: 68,
                color: AppColors.bg,
                child: p.imagenUrl != null && p.imagenUrl!.isNotEmpty
                    ? Image.network(p.imagenUrl!, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.inventory_2_outlined, color: AppColors.blue))
                    : const Icon(Icons.inventory_2_outlined, color: AppColors.blue),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.nombre, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.navy)),
                if (sub.isNotEmpty)
                  Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade400)),
              ]),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
              child: Column(children: [
                Text('${p.stock}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
                Text(low ? 'Stock bajo' : 'unidades', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _MoveSheet extends StatefulWidget {
  final Product p;
  const _MoveSheet(this.p);
  @override
  State<_MoveSheet> createState() => _MoveSheetState();
}

class _MoveSheetState extends State<_MoveSheet> {
  String tipo = 'entrada';
  int qty = 1;
  @override
  Widget build(BuildContext context) {
    final entrada = tipo == 'entrada';
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(widget.p.nombre, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.navy)),
        Text('Stock actual: ${widget.p.stock}', style: TextStyle(color: Colors.blueGrey.shade500)),
        const SizedBox(height: 18),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'entrada', label: Text('Entrada'), icon: Icon(Icons.arrow_downward)),
            ButtonSegment(value: 'salida', label: Text('Salida'), icon: Icon(Icons.arrow_upward)),
          ],
          selected: {tipo},
          onSelectionChanged: (s) => setState(() => tipo = s.first),
        ),
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton.filledTonal(
              iconSize: 30, onPressed: qty > 1 ? () => setState(() => qty--) : null, icon: const Icon(Icons.remove)),
          SizedBox(
              width: 100,
              child: Text('$qty', textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800))),
          IconButton.filledTonal(iconSize: 30, onPressed: () => setState(() => qty++), icon: const Icon(Icons.add)),
        ]),
        const SizedBox(height: 20),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: entrada ? AppColors.green : AppColors.red),
          onPressed: () => Navigator.pop(context, {'tipo': tipo, 'qty': qty}),
          child: Text(entrada ? 'Registrar entrada' : 'Registrar salida'),
        ),
      ]),
    );
  }
}

// ---------------- GRÁFICA SEMANAL ----------------
class _WeeklyChart extends StatefulWidget {
  const _WeeklyChart({super.key});
  @override
  State<_WeeklyChart> createState() => _WeeklyChartState();
}

class _WeeklyChartState extends State<_WeeklyChart> {
  List<dynamic>? _d;

  @override
  void initState() {
    super.initState();
    MovementRepository().weekly().then((v) {
      if (mounted) setState(() => _d = v);
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    if (d == null || d.isEmpty) return const SizedBox.shrink();
    var max = 1;
    for (final e in d) {
      final a = e['entradas'] as int, b = e['salidas'] as int;
      if (a > max) max = a;
      if (b > max) max = b;
    }
    Widget bar(int v, Color c) => Container(
          width: 9,
          height: 4 + 44.0 * v / max,
          decoration: BoxDecoration(color: v == 0 ? c.withValues(alpha: 0.2) : c, borderRadius: BorderRadius.circular(3)),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text.rich(TextSpan(style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade500), children: const [
              TextSpan(text: 'Últimos 7 días:  '),
              TextSpan(text: '■ entradas  ', style: TextStyle(color: AppColors.green)),
              TextSpan(text: '■ salidas', style: TextStyle(color: AppColors.red)),
            ])),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: d
                  .map<Widget>((e) => Expanded(
                        child: Column(children: [
                          Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                            bar(e['entradas'] as int, AppColors.green),
                            const SizedBox(width: 2),
                            bar(e['salidas'] as int, AppColors.red),
                          ]),
                          Text('${e['fecha']}'.substring(8), style: TextStyle(fontSize: 10, color: Colors.blueGrey.shade400)),
                        ]),
                      ))
                  .toList(),
            ),
          ]),
        ),
      ),
    );
  }
}

// ---------------- MOVIMIENTOS ----------------
class MovementsView extends StatefulWidget {
  const MovementsView({super.key});
  @override
  State<MovementsView> createState() => _MovementsViewState();
}

class _MovementsViewState extends State<MovementsView> {
  final _repo = MovementRepository();
  List<dynamic> _all = [];
  bool _loading = true;
  String? _error;
  String _q = '', _tipo = 'todos';
  DateTimeRange? _rango;

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
      _all = await _repo.list();
    } catch (e) {
      _error = '$e';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
        context: context, firstDate: DateTime(now.year - 2), lastDate: now, initialDateRange: _rango);
    if (r != null) setState(() => _rango = r);
  }

  bool _match(dynamic m) {
    if (_tipo != 'todos' && m['tipo'] != _tipo) return false;
    if (!'${m['producto']} ${m['usuario']}'.toLowerCase().contains(_q.toLowerCase())) return false;
    if (_rango != null) {
      final f = DateTime.tryParse('${m['fecha']}');
      if (f == null) return false;
      final fin = DateTime(_rango!.end.year, _rango!.end.month, _rango!.end.day, 23, 59, 59);
      if (f.isBefore(_rango!.start) || f.isAfter(fin)) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _Empty('assets/mascota/sorprendido.png', _error!);
    final list = _all.where(_match).toList();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Row(children: [
          Expanded(
            child: TextField(
              onChanged: (v) => setState(() => _q = v),
              decoration: const InputDecoration(hintText: 'Buscar por producto o usuario...', prefixIcon: Icon(Icons.search)),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(icon: const Icon(Icons.date_range), tooltip: 'Filtrar por fechas', onPressed: _pickRange),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Row(children: [
          Expanded(
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'todos', label: Text('Todos')),
                ButtonSegment(value: 'entrada', label: Text('Entradas')),
                ButtonSegment(value: 'salida', label: Text('Salidas')),
              ],
              selected: {_tipo},
              onSelectionChanged: (s) => setState(() => _tipo = s.first),
            ),
          ),
          if (_rango != null)
            IconButton(icon: const Icon(Icons.close), tooltip: 'Quitar filtro de fechas', onPressed: () => setState(() => _rango = null)),
        ]),
      ),
      Expanded(
        child: RefreshIndicator(
          onRefresh: _load,
          child: list.isEmpty
              ? _Empty('assets/mascota/pose_app.png', _all.isEmpty ? 'Aún no hay movimientos' : 'Sin resultados con esos filtros')
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final m = list[i];
                    final entrada = m['tipo'] == 'entrada';
                    final color = entrada ? AppColors.green : AppColors.red;
                    final fecha = m['fecha'].toString().replaceFirst('T', ' ').substring(0, 16);
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                            backgroundColor: color.withValues(alpha: 0.12),
                            child: Icon(entrada ? Icons.arrow_downward : Icons.arrow_upward, color: color)),
                        title: Text('${m['producto']}', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.navy)),
                        subtitle: Text('${m['usuario']} · $fecha'),
                        trailing: Text('${entrada ? '+' : '-'}${m['cantidad']}',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
                      ),
                    );
                  },
                ),
        ),
      ),
    ]);
  }
}
