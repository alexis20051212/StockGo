import 'dart:convert';
import '../core/api_client.dart';

/// REPOSITORY PATTERN: las pantallas nunca hablan HTTP directamente.
class Product {
  final int id;
  final String nombre;
  final String? marca, categoria, codigoBarras, imagenUrl;
  final int stock;
  Product.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        nombre = j['nombre'],
        marca = j['marca'],
        categoria = j['categoria'],
        codigoBarras = j['codigo_barras'],
        imagenUrl = j['imagen_url'],
        stock = j['stock'];
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
  Future<void> updateProfile(String nombre) => _api.request('PUT', '/me', body: {'nombre': nombre});
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

  /// Consulta Open Food Facts a través del backend.
  Future<Map<String, dynamic>> lookupBarcode(String code) async =>
      await _api.request('GET', '/barcode/$code');
}

class MovementRepository {
  final _api = ApiClient();

  Future<void> register(int productId, String tipo, int cantidad) => _api.request('POST', '/movements',
      body: {'product_id': productId, 'tipo': tipo, 'cantidad': cantidad});

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
