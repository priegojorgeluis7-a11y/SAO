import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/auth/token_store.dart';
import '../../core/config/data_mode.dart';

class BackendApiException implements Exception {
  final int statusCode;
  final String message;
  final Uri uri;
  BackendApiException(this.statusCode, this.message, this.uri);
  @override
  String toString() => 'BackendApiException($statusCode) for $uri: $message';
}

class BackendApiClient {
  const BackendApiClient();

  /// Callback invocado cuando se detecta un 401 irrecuperable (sesión expirada).
  /// Regístralo desde AppSessionController para redirigir al login.
  static void Function()? onSessionExpired;

  /// Returns the backend base URL from dart-define SAO_BACKEND_URL.
  /// Throws if not configured to fail fast with a clear message.
  String get _baseUrl {
    return AppDataMode.requireRealBackendUrl();
  }

  String _resolveAccessToken() {
    if (TokenStore.hasToken) {
      return TokenStore.current.trim();
    }
    return AppDataMode.backendBearerToken.trim();
  }

  Map<String, String> _buildHeaders(String token) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    final authToken = token.trim();
    if (authToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $authToken';
    }
    return headers;
  }

  Future<_ApiRawResponse> _sendRaw(
    String method,
    String path, {
    Map<String, dynamic>? payload,
    String? token,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final headers = _buildHeaders(token ?? '');
    final body = payload != null ? jsonEncode(payload) : null;
    const timeout = Duration(seconds: 15);

    final http.Response response;
    switch (method) {
      case 'GET':
        response = await http.get(uri, headers: headers).timeout(timeout);
      case 'POST':
        response = await http.post(uri, headers: headers, body: body).timeout(timeout);
      case 'PUT':
        response = await http.put(uri, headers: headers, body: body).timeout(timeout);
      case 'PATCH':
        response = await http.patch(uri, headers: headers, body: body).timeout(timeout);
      case 'DELETE':
        response = await http.delete(uri, headers: headers).timeout(timeout);
      default:
        throw StateError('Unsupported method: $method');
    }

    return _ApiRawResponse(
      statusCode: response.statusCode,
      body: response.body,
      uri: uri,
    );
  }

  Future<dynamic> _sendJson(
    String method,
    String path, {
    Map<String, dynamic>? payload,
  }) async {
    var token = _resolveAccessToken();
    var result = await _sendRaw(method, path, payload: payload, token: token);

    if (result.statusCode == 401 &&
        path != '/api/v1/auth/refresh' &&
        TokenStore.hasRefreshToken) {
      final refreshed = await _BackendAuthRefreshCoordinator.refreshIfNeeded(_baseUrl);
      if (refreshed) {
        token = _resolveAccessToken();
        result = await _sendRaw(method, path, payload: payload, token: token);
      }
    }

    // Si persiste el 401 después del intento de refresh, la sesión expiró o fue
    // invalidada en el servidor. Se limpia el TokenStore para forzar re-login.
    if (result.statusCode == 401) {
      unawaited(TokenStore.clear());
      onSessionExpired?.call();
    }

    if (result.statusCode < 200 || result.statusCode >= 300) {
      throw BackendApiException(
        result.statusCode,
        'Backend $method failed (${result.statusCode}) for $path: ${result.body}',
        result.uri,
      );
    }

    if (result.body.isEmpty) return null;
    return jsonDecode(result.body);
  }

  Future<dynamic> getJson(String path) async {
    return _sendJson('GET', path);
  }

  Future<dynamic> postJson(String path, Map<String, dynamic> payload) async {
    return _sendJson('POST', path, payload: payload);
  }

  Future<dynamic> patchJson(String path, Map<String, dynamic> payload) async {
    return _sendJson('PATCH', path, payload: payload);
  }

  Future<dynamic> putJson(String path, Map<String, dynamic> payload) async {
    return _sendJson('PUT', path, payload: payload);
  }

  Future<dynamic> deleteJson(String path) async {
    return _sendJson('DELETE', path);
  }
}

class _ApiRawResponse {
  final int statusCode;
  final String body;
  final Uri uri;

  const _ApiRawResponse({
    required this.statusCode,
    required this.body,
    required this.uri,
  });
}

class _BackendAuthRefreshCoordinator {
  static Future<bool>? _inFlight;

  static Future<bool> refreshIfNeeded(String baseUrl) async {
    final running = _inFlight;
    if (running != null) {
      return running;
    }
    final task = _refresh(baseUrl);
    _inFlight = task;
    try {
      return await task;
    } finally {
      _inFlight = null;
    }
  }

  static Future<bool> _refresh(String baseUrl) async {
    if (!TokenStore.hasRefreshToken) {
      return false;
    }

    final uri = Uri.parse('$baseUrl/api/v1/auth/refresh');
    const timeout = Duration(seconds: 15);
    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refresh_token': TokenStore.currentRefreshToken}),
          )
          .timeout(timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return false;
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final accessToken = decoded['access_token'] as String? ?? '';
      if (accessToken.isEmpty) {
        return false;
      }
      final refreshToken = decoded['refresh_token'] as String? ?? TokenStore.currentRefreshToken;
      final expiresInRaw = decoded['expires_in'];
      final expiresInSeconds = switch (expiresInRaw) {
        int value => value,
        String value => int.tryParse(value),
        _ => null,
      };

      await TokenStore.save(
        accessToken,
        refreshToken: refreshToken,
        expiresInSeconds: expiresInSeconds,
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
