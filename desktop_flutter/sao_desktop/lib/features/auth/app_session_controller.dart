import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/token_store.dart';
import '../../core/config/data_mode.dart';

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class AppUser {
  final String id;
  final String email;
  final String fullName;
  final String role;

  const AppUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'].toString(),
      email: json['email'] as String,
      fullName: (json['full_name'] as String?) ?? '',
      role: (json['role'] as String?) ?? '',
    );
  }
}

class AppSessionState {
  final bool initializing;
  final bool loading;
  final String? error;
  final String? accessToken;
  final AppUser? user;

  const AppSessionState({
    required this.initializing,
    required this.loading,
    required this.error,
    required this.accessToken,
    required this.user,
  });

  const AppSessionState.initializing()
      : initializing = true,
        loading = false,
        error = null,
        accessToken = null,
        user = null;

  bool get isAuthenticated => accessToken != null && user != null;

  AppSessionState copyWith({
    bool? initializing,
    bool? loading,
    String? error,
    String? accessToken,
    AppUser? user,
    bool clearError = false,
    bool clearUser = false,
    bool clearToken = false,
  }) {
    return AppSessionState(
      initializing: initializing ?? this.initializing,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      accessToken: clearToken ? null : (accessToken ?? this.accessToken),
      user: clearUser ? null : (user ?? this.user),
    );
  }
}

// ---------------------------------------------------------------------------
// HTTP helper (self-contained, no dependency on admin module)
// ---------------------------------------------------------------------------

abstract class AuthHttp {
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    String? token,
  });

  Future<Map<String, dynamic>> get(String path, String token);
}

class _AuthHttp implements AuthHttp {
  final String baseUrl;

  _AuthHttp(this.baseUrl);

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final client = HttpClient();
    try {
      final req = await client.postUrl(uri);
      req.headers.contentType = ContentType.json;
      if (token != null) {
        req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      req.write(jsonEncode(body));
      final res = await req.close();
      final raw = await res.transform(utf8.decoder).join();
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw HttpException('$path ${res.statusCode}: $raw', uri: uri);
      }
      return jsonDecode(raw) as Map<String, dynamic>;
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<Map<String, dynamic>> get(String path, String token) async {
    final uri = Uri.parse('$baseUrl$path');
    final client = HttpClient();
    try {
      final req = await client.getUrl(uri);
      req.headers.contentType = ContentType.json;
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      final res = await req.close();
      final raw = await res.transform(utf8.decoder).join();
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw HttpException('$path ${res.statusCode}: $raw', uri: uri);
      }
      return jsonDecode(raw) as Map<String, dynamic>;
    } finally {
      client.close(force: true);
    }
  }
}

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

class AppSessionController extends StateNotifier<AppSessionState> {
  final AuthHttp _http;

  AppSessionController(this._http) : super(const AppSessionState.initializing()) {
    _initialize();
  }

  /// On startup: restore persisted token and verify with /auth/me.
  Future<void> _initialize() async {
    final stored = await TokenStore.loadSession();
    if (!stored.hasAccessToken) {
      state = const AppSessionState(
        initializing: false,
        loading: false,
        error: null,
        accessToken: null,
        user: null,
      );
      return;
    }

    var accessToken = stored.accessToken;
    try {
      if (stored.hasRefreshToken && TokenStore.shouldRefreshAccessToken) {
        final refreshed = await _refreshTokens();
        if (refreshed) {
          accessToken = TokenStore.current;
        }
      }

      final me = await _http.get('/api/v1/auth/me', accessToken);
      state = AppSessionState(
        initializing: false,
        loading: false,
        error: null,
        accessToken: accessToken,
        user: AppUser.fromJson(me),
      );
    } catch (_) {
      final refreshed = await _refreshTokens();
      if (refreshed) {
        try {
          final me = await _http.get('/api/v1/auth/me', TokenStore.current);
          state = AppSessionState(
            initializing: false,
            loading: false,
            error: null,
            accessToken: TokenStore.current,
            user: AppUser.fromJson(me),
          );
          return;
        } catch (_) {}
      }

      await TokenStore.clear();
      state = const AppSessionState(
        initializing: false,
        loading: false,
        error: null,
        accessToken: null,
        user: null,
      );
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final body =
          await _http.post('/api/v1/auth/login', {'email': email, 'password': password});
      final token = body['access_token'] as String;
      final refreshToken = body['refresh_token'] as String? ?? '';
      final expiresInRaw = body['expires_in'];
      final expiresInSeconds = switch (expiresInRaw) {
        int value => value,
        String value => int.tryParse(value),
        _ => null,
      };
      await TokenStore.save(
        token,
        refreshToken: refreshToken,
        expiresInSeconds: expiresInSeconds,
      );
      final me = await _http.get('/api/v1/auth/me', token);
      state = AppSessionState(
        initializing: false,
        loading: false,
        error: null,
        accessToken: token,
        user: AppUser.fromJson(me),
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: 'No se pudo iniciar sesión. Verifica tus credenciales.',
      );
    }
  }

  Future<bool> _refreshTokens() async {
    if (!TokenStore.hasRefreshToken) {
      return false;
    }
    try {
      final body = await _http.post('/api/v1/auth/refresh', {
        'refresh_token': TokenStore.currentRefreshToken,
      });
      final newAccessToken = body['access_token'] as String? ?? '';
      if (newAccessToken.isEmpty) {
        return false;
      }
      final newRefreshToken = body['refresh_token'] as String? ?? TokenStore.currentRefreshToken;
      final expiresInRaw = body['expires_in'];
      final expiresInSeconds = switch (expiresInRaw) {
        int value => value,
        String value => int.tryParse(value),
        _ => null,
      };

      await TokenStore.save(
        newAccessToken,
        refreshToken: newRefreshToken,
        expiresInSeconds: expiresInSeconds,
      );

      state = state.copyWith(accessToken: newAccessToken, clearError: true);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> logout() async {
    final token = state.accessToken;
    await TokenStore.clear();
    state = const AppSessionState(
      initializing: false,
      loading: false,
      error: null,
      accessToken: null,
      user: null,
    );
    if (token == null) return;
    try {
      await _http.post('/api/v1/auth/logout', {}, token: token);
    } catch (_) {
      // local-first logout — ignore server errors
    }
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _backendBaseUrlProvider = Provider<String>((ref) {
  const url = AppDataMode.backendBaseUrl;
  if (url.trim().isNotEmpty) return url.trim();
  return 'http://127.0.0.1:8000';
});

final appSessionControllerProvider =
    StateNotifierProvider<AppSessionController, AppSessionState>((ref) {
  final baseUrl = ref.read(_backendBaseUrlProvider);
  return AppSessionController(_AuthHttp(baseUrl));
});

/// Convenience provider for the logged-in user (null if not authenticated).
final currentAppUserProvider = Provider<AppUser?>((ref) {
  return ref.watch(appSessionControllerProvider).user;
});
