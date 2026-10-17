import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Tipos de error que la app distingue al consumir la API.
enum ApiError {
  sinConexion,
  tiempoAgotado,
  noAutorizado,
  noEncontrado,
  servidor,
  respuestaInvalida,
  otro,
}

class ApiException implements Exception {
  final String message;
  final int? status;
  final ApiError tipo;
  ApiException(this.message, [this.status, this.tipo = ApiError.otro]);
  @override
  String toString() => message;
}

/// SINGLETON: una única instancia para todas las peticiones al backend.
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  // Release: --dart-define=API_URL=https://stockgo-px32.onrender.com
  static const baseUrl =
      String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:5000');
  static const timeoutSeconds =
      int.fromEnvironment('API_TIMEOUT', defaultValue: 20);

  /// Se ejecuta cuando el servidor responde 401 (sesión vencida o cuenta
  /// desactivada): la app cierra la sesión y vuelve al inicio de sesión.
  static void Function()? onUnauthorized;

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

  Future<dynamic> request(String method, String path,
      {Map<String, dynamic>? body}) async {
    // 3. Crear la solicitud (método, URL, encabezados y cuerpo)
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final t = await token;
    if (t != null) headers['Authorization'] = 'Bearer $t';
    final req = http.Request(method, Uri.parse('$baseUrl$path'))
      ..headers.addAll(headers);
    if (body != null) req.body = jsonEncode(body);

    // 4-5. Enviar la solicitud y recibir la respuesta
    http.Response res;
    try {
      final streamed =
          await req.send().timeout(const Duration(seconds: timeoutSeconds));
      res = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw ApiException(
          'El servidor tardó demasiado en responder. Intenta de nuevo.',
          null,
          ApiError.tiempoAgotado);
    } on IOException {
      throw ApiException(
          'Sin conexión a Internet. Revisa tu red e intenta de nuevo.',
          null,
          ApiError.sinConexion);
    } on http.ClientException {
      throw ApiException('Sin conexión con el servidor. Revisa tu red.',
          null, ApiError.sinConexion);
    }

    // 6. Procesar el JSON
    dynamic data;
    var jsonValido = true;
    if (res.bodyBytes.isNotEmpty) {
      try {
        data = jsonDecode(utf8.decode(res.bodyBytes, allowMalformed: true));
      } on FormatException {
        jsonValido = false;
      }
    }
    final msg = data is Map ? data['error'] as String? : null;

    // Errores según el código HTTP
    if (res.statusCode == 401) {
      if (path != '/auth/login') {
        await clearSession();
        onUnauthorized?.call();
      }
      throw ApiException(msg ?? 'Tu sesión expiró. Inicia sesión de nuevo.',
          401, ApiError.noAutorizado);
    }
    if (res.statusCode == 404) {
      throw ApiException(
          msg ?? 'Recurso no encontrado.', 404, ApiError.noEncontrado);
    }
    if (res.statusCode >= 500) {
      throw ApiException(
          msg ?? 'Error del servidor (${res.statusCode}). Intenta más tarde.',
          res.statusCode,
          ApiError.servidor);
    }
    if (res.statusCode >= 400) {
      throw ApiException(msg ?? 'No se pudo completar la solicitud.',
          res.statusCode);
    }
    if (!jsonValido) {
      throw ApiException('El servidor envió una respuesta inválida.',
          res.statusCode, ApiError.respuestaInvalida);
    }
    return data;
  }
}
