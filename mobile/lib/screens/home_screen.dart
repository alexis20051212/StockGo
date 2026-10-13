import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../repositories/repositories.dart';
import 'login_screen.dart';
import 'scanner_screen.dart';

void _toast(BuildContext c, String m, {bool error = true}) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(
        content: Text(m),
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
  }

  Future<void> _logout() async {
    await AuthRepository().logout();
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          toolbarHeight: 68,
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('StockGo', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22)),
            Text('Hola, $_nombre · ${_isAdmin ? 'Administrador' : 'Empleado'}',
                style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ]),
          actions: [IconButton(icon: const Icon(Icons.logout), tooltip: 'Cerrar sesión', onPressed: _logout)],
        ),
        body: _tab == 0 ? InventoryView(isAdmin: _isAdmin) : const MovementsView(),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Inventario'),
            NavigationDestination(icon: Icon(Icons.swap_vert), selectedIcon: Icon(Icons.swap_vert_circle), label: 'Movimientos'),
          ],
        ),
      );
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Empty(this.icon, this.text);
  @override
  Widget build(BuildContext context) => ListView(children: [
        const SizedBox(height: 90),
        Icon(icon, size: 72, color: Colors.blueGrey.shade200),
        const SizedBox(height: 12),
        Center(child: Text(text, style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 16))),
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
  String _q = '';
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
      _all = await _products.list();
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
      await _moves.register(p.id, r['tipo'], r['qty']);
      if (mounted) _toast(context, 'Movimiento registrado', error: false);
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

  Future<void> _addProduct() async {
    final code = TextEditingController(), nombre = TextEditingController(),
        marca = TextEditingController(), cat = TextEditingController();
    String? img;
    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
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
    final list = _all.where((p) => p.nombre.toLowerCase().contains(_q.toLowerCase())).toList();
    final units = _all.fold<int>(0, (a, p) => a + p.stock);
    final low = _all.where((p) => p.stock <= 5).length;
    return Scaffold(
      floatingActionButton: widget.isAdmin
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.blue,
              foregroundColor: Colors.white,
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _q = v),
              decoration: const InputDecoration(hintText: 'Buscar producto...', prefixIcon: Icon(Icons.search)),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _Empty(Icons.wifi_off, _error!)
                    : list.isEmpty
                        ? _Empty(Icons.inventory_2_outlined, _q.isEmpty ? 'Aún no hay productos' : 'Sin resultados')
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                            itemCount: list.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (_, i) => _ProductCard(
                              list[i],
                              onTap: () => _move(list[i]),
                              onLong: widget.isAdmin ? () => _confirmDelete(list[i]) : null,
                            ),
                          ),
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
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 6),
              Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
              Text(label, style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade500)),
            ]),
          ),
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
    final low = p.stock <= 5;
    final color = low ? AppColors.red : AppColors.green;
    final sub = [p.marca, p.categoria].where((e) => e?.isNotEmpty ?? false).join(' · ');
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        onLongPress: onLong,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 60,
                height: 60,
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Column(children: [
                Text('${p.stock}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
                Text(low ? 'Bajo' : 'En stock', style: TextStyle(fontSize: 10, color: color)),
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

// ---------------- MOVIMIENTOS ----------------
class MovementsView extends StatelessWidget {
  const MovementsView({super.key});
  @override
  Widget build(BuildContext context) => FutureBuilder<List<dynamic>>(
        future: MovementRepository().list(),
        builder: (_, s) {
          if (s.hasError) return _Empty(Icons.wifi_off, '${s.error}');
          if (!s.hasData) return const Center(child: CircularProgressIndicator());
          if (s.data!.isEmpty) return const _Empty(Icons.history, 'Aún no hay movimientos');
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: s.data!.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final m = s.data![i];
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
          );
        },
      );
}
