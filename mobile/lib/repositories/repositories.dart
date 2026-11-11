import 'dart:convert';
import '../core/api_client.dart';

/// REPOSITORY PATTERN: las pantallas nunca hablan HTTP directamente.
class Product {
  final int id;
  final String nombre;
  final String? marca, categoria, codigoBarras, imagenUrl;
  final int stock, stockMinimo;
  Product.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        nombre = j['nombre'],
        marca = j['marca'],
        categoria = j['categoria'],
        codigoBarras = j['codigo_barras'],
        imagenUrl = j['imagen_url'],
        stock = j['stock'],
        stockMinimo = (j['stock_minimo'] ?? 5) as int;
  bool get bajo => stock <= stockMinimo;
}

class AuthRepository {
  final _api = ApiClient();

  Future<bool> isLogged() async => (await _api.token) != null;
  Future<String?> role() => _api.rol;
  Future<String?> name() => _api.nombre;
  Future<bool> hasUsers() async => (await _api.request('GET', '/auth/has-users'))['has_users'];

  Future<void> login(String email, String password) async {
    final r = await _api.request('POST', '/auth/login', body: {'email': email, 'password': password});
    await _api.saveSession(r['token'], r['rol'], r['nombre']);
  }

  Future<void> registerFirstAdmin(String nombre, String email, String password) =>
      _api.request('POST', '/auth/register', body: {'nombre': nombre, 'email': email, 'password': password});

  Future<Map<String, dynamic>> profile() async => await _api.request('GET', '/me');
  Future<void> updateProfile(String nombre) async {
    await _api.request('PUT', '/me', body: {'nombre': nombre});
    final t = await _api.token, r = await _api.rol;
    if (t != null && r != null) await _api.saveSession(t, r, nombre);
  }

  Future<void> changePassword(String actual, String nueva) =>
      _api.request('PUT', '/me/password', body: {'actual': actual, 'nueva': nueva});
  Future<void> logout() => _api.clearSession();
}

class ProductRepository {
  final _api = ApiClient();

  /// true si la última lista salió de la caché local (sin conexión).
  bool fromCache = false;

  Future<List<Product>> list() async {
    try {
      final raw = await _api.request('GET', '/products') as List;
      await _api.saveCache('products', jsonEncode(raw));
      fromCache = false;
      return raw.map((j) => Product.fromJson(j)).toList();
    } on ApiException catch (e) {
      if (e.tipo == ApiError.sinConexion || e.tipo == ApiError.tiempoAgotado) {
        final c = await _api.readCache('products');
        if (c != null) {
          fromCache = true;
          return (jsonDecode(c) as List).map((j) => Product.fromJson(j)).toList();
        }
      }
      rethrow;
    }
  }

  Future<void> create(Map<String, dynamic> data) => _api.request('POST', '/products', body: data);
  Future<void> update(int id, Map<String, dynamic> data) => _api.request('PUT', '/products/$id', body: data);
  Future<void> delete(int id) => _api.request('DELETE', '/products/$id');

  /// Inventario en CSV (solo administrador).
  Future<String> exportCsv() async => await _api.request('GET', '/products/export.csv', raw: true) as String;

  /// Consulta Open Food Facts a través del backend.
  Future<Map<String, dynamic>> lookupBarcode(String code) async =>
      await _api.request('GET', '/barcode/$code');
}

class MovementRepository {
  final _api = ApiClient();
  static const _queueKey = 'queue_movements';

  /// Movimientos guardados sin conexión, pendientes de enviar.
  Future<List<dynamic>> pending() async {
    final c = await _api.readCache(_queueKey);
    return c == null ? [] : jsonDecode(c) as List;
  }

  /// Devuelve true si se envió; false si se guardó en la cola por falta de internet.
  Future<bool> register(int productId, String tipo, int cantidad) async {
    final body = {'product_id': productId, 'tipo': tipo, 'cantidad': cantidad};
    try {
      await _api.request('POST', '/movements', body: body);
      return true;
    } on ApiException catch (e) {
      // Solo se encola cuando seguro NO llegó al servidor (evita duplicados por tiempo agotado)
      if (e.tipo == ApiError.sinConexion) {
        final q = await pending();
        q.add(body);
        await _api.saveCache(_queueKey, jsonEncode(q));
        return false;
      }
      rethrow;
    }
  }

  /// Envía la cola. Devuelve cuántos se enviaron y cuántos rechazó el servidor.
  Future<Map<String, int>> flushPending() async {
    final q = await pending();
    var sent = 0, failed = 0;
    final left = <dynamic>[];
    for (var i = 0; i < q.length; i++) {
      try {
        await _api.request('POST', '/movements', body: Map<String, dynamic>.from(q[i]));
        sent++;
      } on ApiException catch (e) {
        if (e.tipo == ApiError.sinConexion || e.tipo == ApiError.tiempoAgotado) {
          left.addAll(q.sublist(i)); // sigue sin red: conservar lo que falta
          break;
        }
        failed++; // rechazado (stock insuficiente, producto eliminado...): se descarta
      }
    }
    await _api.saveCache(_queueKey, jsonEncode(left));
    return {'sent': sent, 'failed': failed};
  }

  Future<List<dynamic>> list() async {
    try {
      final raw = await _api.request('GET', '/movements') as List;
      await _api.saveCache('movements', jsonEncode(raw));
      return raw;
    } on ApiException catch (e) {
      if (e.tipo == ApiError.sinConexion || e.tipo == ApiError.tiempoAgotado) {
        final c = await _api.readCache('movements');
        if (c != null) return jsonDecode(c) as List;
      }
      rethrow;
    }
  }

  /// Entradas y salidas de los últimos 7 días.
  Future<List<dynamic>> weekly() async => await _api.request('GET', '/stats/weekly') as List;
}

class AuditRepository {
  final _api = ApiClient();
  Future<List<dynamic>> list() async => await _api.request('GET', '/audit') as List;
}

class UserItem {
  final int id;
  final String nombre, email, rol;
  final bool activo;
  UserItem.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        nombre = j['nombre'],
        email = j['email'],
        rol = j['rol'],
        activo = j['activo'] == 1 || j['activo'] == true;
}

class UserRepository {
  final _api = ApiClient();

  Future<List<UserItem>> list() async =>
      (await _api.request('GET', '/users') as List).map((j) => UserItem.fromJson(j)).toList();

  Future<void> create(Map<String, dynamic> data) => _api.request('POST', '/users', body: data);
  Future<void> update(int id, Map<String, dynamic> data) => _api.request('PUT', '/users/$id', body: data);
}
