import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final String message;
  final int? status;
  ApiException(this.message, [this.status]);
  @override
  String toString() => message;
}

/// SINGLETON: una única instancia para todas las peticiones al backend.
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  // En release usar HTTPS: flutter build apk --release --dart-define=API_URL=https://tu-backend
  static const baseUrl =
      String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:5000');
  final _storage = const FlutterSecureStorage();

  Future<void> saveSession(String token, String rol, String nombre) async {
    await _storage.write(key: 'token', value: token);
    await _storage.write(key: 'rol', value: rol);
    await _storage.write(key: 'nombre', value: nombre);
  }

  Future<String?> get token => _storage.read(key: 'token');
  Future<String?> get rol => _storage.read(key: 'rol');
  Future<String?> get nombre => _storage.read(key: 'nombre');
  Future<void> clearSession() => _storage.deleteAll();

  Future<dynamic> request(String method, String path, {Map<String, dynamic>? body}) async {
    final headers = {'Content-Type': 'application/json'};
    final t = await token;
    if (t != null) headers['Authorization'] = 'Bearer $t';
    final req = http.Request(method, Uri.parse('$baseUrl$path'))..headers.addAll(headers);
    if (body != null) req.body = jsonEncode(body);
    try {
      final res = await http.Response.fromStream(
          await req.send().timeout(const Duration(seconds: 15)));
      final data = res.body.isEmpty ? null : jsonDecode(res.body);
      if (res.statusCode >= 400) {
        throw ApiException((data is Map ? data['error'] : null) ?? 'Error del servidor', res.statusCode);
      }
      return data;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException('Sin conexión con el servidor. Revisa tu internet.');
    }
  }
}
