import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../core/auth/token_store.dart';
import '../../core/config/data_mode.dart';

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

  Future<_ApiRawResponse> _sendRaw(
    String method,
    String path, {
    Map<String, dynamic>? payload,
    String? token,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15)
      ..idleTimeout = const Duration(seconds: 15);
    try {
      final request = switch (method) {
        'GET' => await client.getUrl(uri),
        'POST' => await client.postUrl(uri),
        'PUT' => await client.putUrl(uri),
        'PATCH' => await client.patchUrl(uri),
        'DELETE' => await client.deleteUrl(uri),
        _ => throw StateError('Unsupported method: $method'),
      };

      request.headers.contentType = ContentType.json;
      final authToken = (token ?? '').trim();
      if (authToken.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $authToken');
      }
      if (payload != null) {
        request.write(jsonEncode(payload));
      }

      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      return _ApiRawResponse(
        statusCode: response.statusCode,
        body: body,
        uri: uri,
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<dynamic> _sendJson(
    String method,
    String path, {
    Map<String, dynamic>? payload,
  }) async {
    var token = _resolveAccessToken();
    var result = await _sendRaw(method, path, payload: payload, token: token);

    if (result.statusCode == HttpStatus.unauthorized &&
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
    if (result.statusCode == HttpStatus.unauthorized) {
      unawaited(TokenStore.clear());
      onSessionExpired?.call();
    }

    if (result.statusCode < 200 || result.statusCode >= 300) {
      throw HttpException(
        'Backend $method failed (${result.statusCode}) for $path: ${result.body}',
        uri: result.uri,
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
    final client = HttpClient();
    try {
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode({'refresh_token': TokenStore.currentRefreshToken}),
      );
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return false;
      }

      final decoded = jsonDecode(body) as Map<String, dynamic>;
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
    } finally {
      client.close(force: true);
    }
  }
}
