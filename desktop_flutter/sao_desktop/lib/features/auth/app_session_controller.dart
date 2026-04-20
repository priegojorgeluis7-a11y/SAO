import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/token_store.dart';
import '../../core/config/data_mode.dart';

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

const Map<String, Set<String>> _permissionAliases = <String, Set<String>>{
  'activity.view': <String>{'activity.view', 'ver actividades'},
  'activity.create': <String>{'activity.create', 'crear actividades'},
  'activity.edit': <String>{'activity.edit', 'editar actividades'},
  'activity.delete': <String>{'activity.delete', 'eliminar actividades'},
  'activity.approve': <String>{'activity.approve', 'aprobar actividades'},
  'activity.reject': <String>{'activity.reject', 'rechazar actividades'},
  'event.view': <String>{'event.view', 'ver eventos'},
  'event.create': <String>{'event.create', 'crear eventos'},
  'event.edit': <String>{'event.edit', 'editar eventos'},
  'catalog.view': <String>{'catalog.view', 'ver catálogo', 'ver catalogo'},
  'catalog.edit': <String>{'catalog.edit', 'editar catálogo', 'editar catalogo'},
  'catalog.publish': <String>{'catalog.publish', 'publicar catálogo', 'publicar catalogo'},
  'user.view': <String>{'user.view', 'ver usuarios'},
  'user.create': <String>{'user.create', 'crear usuarios'},
  'user.edit': <String>{'user.edit', 'editar usuarios'},
  'report.view': <String>{'report.view', 'ver reportes'},
  'report.export': <String>{'report.export', 'exportar reportes'},
  'assignment.manage': <String>{'assignment.manage', 'administrar asignaciones'},
  'project.manage': <String>{'project.manage', 'administrar proyectos'},
  'flow.approve_exception': <String>{
    'flow.approve_exception',
    'aprobar excepciones de flujo',
  },
};

String _normalizePermissionCode(String? value) {
  return (value ?? '').trim().toLowerCase();
}

String _canonicalizeRoleName(String? value) {
  final normalized = (value ?? '')
      .trim()
      .toUpperCase()
      .replaceAll('Á', 'A')
      .replaceAll('É', 'E')
      .replaceAll('Í', 'I')
      .replaceAll('Ó', 'O')
      .replaceAll('Ú', 'U');

  if (normalized == 'ADMINISTRADOR') return 'ADMIN';
  if (normalized == 'COORDINADOR' || normalized == 'COORDINATOR') {
    return 'COORD';
  }
  if (normalized == 'LECTURA' || normalized == 'VIEWER' || normalized == 'CONSULTA') {
    return 'LECTOR';
  }
  if (normalized == 'OPERARIO' ||
      normalized == 'OPERADOR' ||
      normalized == 'TECNICO' ||
      normalized == 'INGENIERO' ||
      normalized == 'ING' ||
      normalized == 'TOPOGRAFO') {
    return 'OPERATIVO';
  }
  return normalized;
}

String? _normalizeProjectId(String? value) {
  final normalized = (value ?? '').trim().toUpperCase();
  return normalized.isEmpty ? null : normalized;
}

bool _permissionMatches(String? candidate, String requested) {
  final candidateNorm = _normalizePermissionCode(candidate);
  final requestedNorm = _normalizePermissionCode(requested);
  if (candidateNorm.isEmpty || requestedNorm.isEmpty) return false;

  final aliases = _permissionAliases[requestedNorm];
  if (aliases != null) return aliases.contains(candidateNorm);

  final reverseAliases = _permissionAliases[candidateNorm];
  if (reverseAliases != null) return reverseAliases.contains(requestedNorm);

  return candidateNorm == requestedNorm;
}

class AppUserPermissionScope {
  final String permissionCode;
  final String? projectId;
  final String effect;

  const AppUserPermissionScope({
    required this.permissionCode,
    required this.projectId,
    required this.effect,
  });

  factory AppUserPermissionScope.fromJson(Map<String, dynamic> json) {
    return AppUserPermissionScope(
      permissionCode: (json['permission_code'] ?? '').toString().trim(),
      projectId: _normalizeProjectId(json['project_id']?.toString()),
      effect: (json['effect'] ?? 'allow').toString().trim().toLowerCase() == 'deny'
          ? 'deny'
          : 'allow',
    );
  }
}

class AppUser {
  final String id;
  final String email;
  final String fullName;
  final String role;
  final List<String> roles;
  final List<String> permissionCodes;
  final List<AppUserPermissionScope> permissionScopes;

  const AppUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.roles,
    this.permissionCodes = const [],
    this.permissionScopes = const [],
  });

  static List<String> _normalizedRoleList(dynamic raw) {
    if (raw is! List) return const [];
    final normalized = raw
        .map((e) => _canonicalizeRoleName(e?.toString()))
        .where((e) => e.isNotEmpty)
        .toList();
    return normalized.toSet().toList();
  }

  static List<String> _normalizedPermissionCodeList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static List<AppUserPermissionScope> _normalizedPermissionScopeList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => item.map(
              (key, value) => MapEntry(key.toString(), value),
            ))
        .map(AppUserPermissionScope.fromJson)
        .where((item) => item.permissionCode.isNotEmpty)
        .toList();
  }

  static Map<String, dynamic> _tryDecodeJwtClaims(String? accessToken) {
    if (accessToken == null || accessToken.trim().isEmpty) {
      return const {};
    }
    final parts = accessToken.split('.');
    if (parts.length < 2) return const {};
    try {
      final normalized = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final payload = jsonDecode(decoded);
      if (payload is Map<String, dynamic>) return payload;
    } catch (_) {}
    return const {};
  }

  bool hasRole(String roleName) {
    final target = _canonicalizeRoleName(roleName);
    if (target.isEmpty) return false;
    final normalizedRoles = <String>{
      _canonicalizeRoleName(role),
      ...roles.map(_canonicalizeRoleName),
    }..removeWhere((item) => item.isEmpty);
    return normalizedRoles.contains(target);
  }

  bool get isAdmin => hasRole('ADMIN');

  bool hasPermission(String permissionCode, {String? projectId}) {
    final normalizedProjectId = _normalizeProjectId(projectId);

    bool scopeApplies(String? scopeProjectId) {
      if (normalizedProjectId == null) return scopeProjectId == null;
      return scopeProjectId == null || scopeProjectId == normalizedProjectId;
    }

    for (final scope in permissionScopes) {
      if (_permissionMatches(scope.permissionCode, permissionCode) &&
          scope.effect == 'deny' &&
          scopeApplies(scope.projectId)) {
        return false;
      }
    }

    if (isAdmin) {
      return true;
    }

    if (permissionCodes.any((code) => _permissionMatches(code, permissionCode))) {
      return true;
    }

    for (final scope in permissionScopes) {
      if (_permissionMatches(scope.permissionCode, permissionCode) &&
          scope.effect == 'allow' &&
          scopeApplies(scope.projectId)) {
        return true;
      }
    }
    return false;
  }

  bool hasAnyPermission(Iterable<String> requestedCodes, {String? projectId}) {
    for (final code in requestedCodes) {
      if (hasPermission(code, projectId: projectId)) return true;
    }
    return false;
  }

  factory AppUser.fromJson(Map<String, dynamic> json, {String? accessToken}) {
    final claims = _tryDecodeJwtClaims(accessToken);

    final List<String> rolesList = [
      ..._normalizedRoleList(json['roles']),
      ..._normalizedRoleList(claims['roles']),
    ];

    final permissionCodes = <String>{
      ..._normalizedPermissionCodeList(json['permission_codes']),
      ..._normalizedPermissionCodeList(claims['permission_codes']),
    }.toList();

    final permissionScopes = [
      ..._normalizedPermissionScopeList(json['permission_scopes']),
      ..._normalizedPermissionScopeList(claims['permission_scopes']),
    ];

    final roleCandidates = <String>[
      ...rolesList,
      (json['role_name'] as String? ?? '').trim(),
      (json['role'] as String? ?? '').trim(),
      (claims['role'] as String? ?? '').trim(),
    ].where((value) => value.isNotEmpty).toList();

    final primaryRole = roleCandidates.isNotEmpty
        ? _canonicalizeRoleName(roleCandidates.first)
        : '';

    return AppUser(
      id: json['id'].toString(),
      email: json['email'] as String,
      fullName: (json['full_name'] as String?) ?? '',
      role: primaryRole,
      roles: rolesList,
      permissionCodes: permissionCodes,
      permissionScopes: permissionScopes,
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

  Future<dynamic> getAny(String path, String token);
}

class AuthApiException implements Exception {
  final int statusCode;
  final String message;
  final Uri uri;

  const AuthApiException({
    required this.statusCode,
    required this.message,
    required this.uri,
  });

  @override
  String toString() => 'AuthApiException($statusCode): $message';
}

class _AuthHttp implements AuthHttp {
  final String baseUrl;
  static const Duration _requestTimeout = Duration(seconds: 8);

  _AuthHttp(this.baseUrl);

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final client = HttpClient();
    client.connectionTimeout = _requestTimeout;
    try {
      final req = await client.postUrl(uri).timeout(_requestTimeout);
      req.headers.contentType = ContentType.json;
      if (token != null) {
        req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      req.write(jsonEncode(body));
      final res = await req.close().timeout(_requestTimeout);
      final raw = await res.transform(utf8.decoder).join().timeout(_requestTimeout);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw AuthApiException(
          statusCode: res.statusCode,
          message: raw,
          uri: uri,
        );
      }
      return jsonDecode(raw) as Map<String, dynamic>;
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<Map<String, dynamic>> get(String path, String token) async {
    final decoded = await getAny(path, token);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw const FormatException('Expected object JSON response');
  }

  @override
  Future<dynamic> getAny(String path, String token) async {
    final uri = Uri.parse('$baseUrl$path');
    final client = HttpClient();
    client.connectionTimeout = _requestTimeout;
    try {
      final req = await client.getUrl(uri).timeout(_requestTimeout);
      req.headers.contentType = ContentType.json;
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      final res = await req.close().timeout(_requestTimeout);
      final raw = await res.transform(utf8.decoder).join().timeout(_requestTimeout);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw AuthApiException(
          statusCode: res.statusCode,
          message: raw,
          uri: uri,
        );
      }
      return jsonDecode(raw);
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
  static const Duration _initializeTimeout = Duration(seconds: 12);

  AppSessionController(this._http) : super(const AppSessionState.initializing()) {
    _initialize();
  }

  static String? _asNonEmptyString(dynamic value) {
    if (value == null) return null;
    final normalized = value.toString().trim();
    if (normalized.isEmpty) return null;
    return normalized;
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static void _appendUnique(List<String> target, Iterable<String> values) {
    for (final value in values) {
      if (value.isEmpty) continue;
      if (!target.contains(value)) {
        target.add(value);
      }
    }
  }

  static String _humanizeAuthError(Object error) {
    if (error is AuthApiException) {
      String? detail;
      try {
        final decoded = jsonDecode(error.message);
        if (decoded is Map<String, dynamic>) {
          final rawDetail = decoded['detail'];
          if (rawDetail is String) {
            detail = rawDetail.trim();
          } else if (rawDetail is List && rawDetail.isNotEmpty) {
            final first = rawDetail.first;
            if (first is Map<String, dynamic>) {
              detail = (first['msg'] ?? first['detail'] ?? '').toString().trim();
            } else {
              detail = first.toString().trim();
            }
          }
        }
      } catch (_) {}

      if (detail != null && detail.isNotEmpty) {
        return 'No se pudo iniciar sesión: $detail';
      }

      return 'No se pudo iniciar sesión (${error.statusCode}).';
    }

    if (error is SocketException) {
      return 'No se pudo conectar con el backend. Verifica tu red.';
    }

    if (error is TimeoutException) {
      return 'El backend tardó demasiado en responder.';
    }

    if (error is HttpException) {
      return 'No se pudo iniciar sesión: ${error.message}';
    }

    return 'No se pudo iniciar sesión: $error';
  }

  Future<Map<String, dynamic>> _resolveMePayload(String accessToken) async {
    final me = await _http.get('/api/v1/auth/me', accessToken);
    final mergedRoles = <String>[];
    _appendUnique(mergedRoles, _stringList(me['roles']));
    final roleName = _asNonEmptyString(me['role_name']);
    final roleLegacy = _asNonEmptyString(me['role']);
    if (roleName != null) mergedRoles.add(roleName);
    if (roleLegacy != null) mergedRoles.add(roleLegacy);

    // Fallback: roles from /me/projects role_names[]
    try {
      final projectsRaw = await _http.getAny('/api/v1/me/projects', accessToken);
      if (projectsRaw is List) {
        for (final item in projectsRaw) {
          if (item is! Map<String, dynamic>) continue;
          _appendUnique(mergedRoles, _stringList(item['role_names']));
        }
      }
    } catch (_) {}

    // Admin fallback: role_name/roles from /users/admin for current user
    try {
      final adminsRaw = await _http.getAny('/api/v1/users/admin', accessToken);
      if (adminsRaw is List) {
        final meId = _asNonEmptyString(me['id']);
        final meEmail = _asNonEmptyString(me['email'])?.toLowerCase();
        for (final item in adminsRaw) {
          if (item is! Map<String, dynamic>) continue;
          final itemId = _asNonEmptyString(item['id']);
          final itemEmail = _asNonEmptyString(item['email'])?.toLowerCase();
          final idMatches = meId != null && itemId == meId;
          final emailMatches = meEmail != null && itemEmail == meEmail;
          if (!idMatches && !emailMatches) continue;
          final adminRoleName = _asNonEmptyString(item['role_name']);
          if (adminRoleName != null) mergedRoles.add(adminRoleName);
          _appendUnique(mergedRoles, _stringList(item['roles']));
          break;
        }
      }
    } catch (_) {}

    return {
      ...me,
      'roles': mergedRoles,
      'role': mergedRoles.isNotEmpty ? mergedRoles.first : (me['role'] ?? ''),
      'role_name': mergedRoles.isNotEmpty
          ? mergedRoles.first
          : (me['role_name'] ?? ''),
    };
  }

  /// On startup: restore persisted token and verify with /auth/me.
  Future<void> _initialize() async {
    try {
      final stored = await TokenStore.loadSession().timeout(_initializeTimeout);
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

        final me = await _resolveMePayload(accessToken);
        state = AppSessionState(
          initializing: false,
          loading: false,
          error: null,
          accessToken: accessToken,
          user: AppUser.fromJson(me, accessToken: accessToken),
        );
      } catch (_) {
        final refreshed = await _refreshTokens();
        if (refreshed) {
          try {
            final me = await _resolveMePayload(TokenStore.current);
            state = AppSessionState(
              initializing: false,
              loading: false,
              error: null,
              accessToken: TokenStore.current,
              user: AppUser.fromJson(me, accessToken: TokenStore.current),
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
    } catch (_) {
      // Defensive fallback: never leave the gate in initializing=true.
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

  /// Surfaces a login error in the UI without going through a network call.
  void setLoginError(String message) {
    state = state.copyWith(loading: false, error: message);
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
      final me = await _resolveMePayload(token);
      state = AppSessionState(
        initializing: false,
        loading: false,
        error: null,
        accessToken: token,
        user: AppUser.fromJson(me, accessToken: token),
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: _humanizeAuthError(e),
      );
    }
  }

  /// Returns true if invite code is required (user doesn't exist yet).
  Future<bool> loginWithGoogle(String idToken, [String? inviteCode]) async {
    final trimmedIdToken = idToken.trim();
    if (trimmedIdToken.isEmpty) {
      state = state.copyWith(
        loading: false,
        error: 'No se pudo obtener token de Google (idToken).',
      );
      return false;
    }

    state = state.copyWith(loading: true, clearError: true);
    try {
      final body = await _http.post('/api/v1/auth/google', {
        'id_token': trimmedIdToken,
        'invite_code': inviteCode?.trim() ?? '',
      });

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

      final me = await _resolveMePayload(token);
      state = AppSessionState(
        initializing: false,
        loading: false,
        error: null,
        accessToken: token,
        user: AppUser.fromJson(me, accessToken: token),
      );
      return false;
    } catch (e) {
      // Surface specific signal: backend says user needs invite code
      if (e is AuthApiException && e.statusCode == 403) {
        String detail = '';
        try {
          final decoded = jsonDecode(e.message);
          if (decoded is Map<String, dynamic>) {
            detail = (decoded['detail'] ?? '').toString().toLowerCase();
          }
        } catch (_) {}
        if (detail.contains('invite code')) {
          state = state.copyWith(loading: false, clearError: true);
          return true; // Signal: needs invite code
        }
      }
      state = state.copyWith(
        loading: false,
        error: _humanizeAuthError(e),
      );
      return false;
    }
  }

  Future<void> signup({
    required String email,
    required String password,
    required String displayName,
    required String inviteCode,
    required String role,
    String? firstName,
    String? lastName,
    String? secondLastName,
    String? birthDate,
  }) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final body = await _http.post('/api/v1/auth/signup', {
        'email': email,
        'password': password,
        'display_name': displayName,
        if (firstName != null && firstName.trim().isNotEmpty)
          'first_name': firstName.trim(),
        if (lastName != null && lastName.trim().isNotEmpty)
          'last_name': lastName.trim(),
        if (secondLastName != null && secondLastName.trim().isNotEmpty)
          'second_last_name': secondLastName.trim(),
        if (birthDate != null && birthDate.trim().isNotEmpty)
          'birth_date': birthDate.trim(),
        'role': role,
        'invite_code': inviteCode,
      });

      final token = body['access_token'] as String?;
      if (token != null && token.isNotEmpty) {
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

        final me = await _resolveMePayload(token);
        state = AppSessionState(
          initializing: false,
          loading: false,
          error: null,
          accessToken: token,
          user: AppUser.fromJson(me, accessToken: token),
        );
      } else {
        // Backend may return signup-only payload without tokens. Attempt login
        // to keep a consistent UX after successful signup.
        await login(email, password);
      }
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: _humanizeAuthError(e),
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
    final refreshToken = TokenStore.currentRefreshToken;
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
      final body = refreshToken.isNotEmpty ? {'refresh_token': refreshToken} : <String, dynamic>{};
      await _http.post('/api/v1/auth/logout', body, token: token);
    } catch (_) {
      // local-first logout — ignore server errors
    }
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _backendBaseUrlProvider = Provider<String>((ref) {
  return AppDataMode.requireRealBackendUrl();
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
