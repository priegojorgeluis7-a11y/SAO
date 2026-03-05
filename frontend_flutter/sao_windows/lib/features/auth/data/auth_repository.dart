import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/exceptions.dart';
import '../../../core/auth/token_storage.dart';
import '../../../core/auth/pin_storage.dart';
import '../../../core/storage/kv_store.dart';
import '../../../core/utils/logger.dart';
import 'models/login_request.dart';
import 'models/signup_request.dart';
import 'models/signup_response.dart';
import 'models/token_response.dart';
import 'models/user.dart';

/// Resultado del proceso de bootstrap de autenticación.
enum BootstrapResult {
  /// Tokens válidos; sesión online restaurada.
  authenticated,

  /// Tokens existen, sin red, PIN configurado → mostrar pantalla de PIN.
  pinLocked,

  /// Sin tokens válidos; ir a login.
  unauthenticated,
}

/// Repository for authentication operations
/// Uses ApiClient from Phase 3A with automatic JWT refresh
class AuthRepository {
  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;
  final KvStore _kvStore;
  final PinStorage? _pinStorage;

  AuthRepository({
    required ApiClient apiClient,
    required TokenStorage tokenStorage,
    required KvStore kvStore,
    PinStorage? pinStorage,
  })  : _apiClient = apiClient,
        _tokenStorage = tokenStorage,
        _kvStore = kvStore,
        _pinStorage = pinStorage;

  /// Login with email and password
  /// Returns TokenResponse on success
  /// Throws AuthException on failure
  Future<TokenResponse> login(LoginRequest request) async {
    try {
      appLogger.i('Attempting login for: ${request.email}');

      final response = await _apiClient.post<dynamic>(
        '/auth/login',
        data: request.toJson(),
      );

      final data = Map<String, dynamic>.from(response.data as Map);

      final tokenResponse = TokenResponse.fromJson(data);

      // Parse expires_in if provided (default 3600 seconds = 1 hour)
      final expiresIn = data['expires_in'] as int? ?? 3600;

      // Save tokens to secure storage
      await _tokenStorage.saveTokens(
        accessToken: tokenResponse.accessToken,
        refreshToken: tokenResponse.refreshToken,
        expiresIn: expiresIn,
      );

      appLogger.i('Login successful for: ${request.email}');

      // Cachear perfil para sesión offline con PIN
      if (_pinStorage != null) {
        try {
          final user = await getCurrentUser();
          await _pinStorage.saveCachedUser(user.toJson());
        } catch (_) {
          // No es crítico; el cache se intentará en el bootstrap siguiente.
        }
      }

      return tokenResponse;
    } on DioException catch (e) {
      appLogger.e('Login failed: ${e.message}');

      if (e.response?.statusCode == 401) {
        throw InvalidCredentialsException(
          'Invalid email or password',
          e.stackTrace,
        );
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw ApiTimeoutException(
          'Connection timeout. Please check your internet connection.',
          e.stackTrace,
        );
      } else if (e.type == DioExceptionType.connectionError) {
        throw NetworkException(
          'No internet connection',
          e.stackTrace,
        );
      }

      throw AuthException(
        'Login failed: ${e.message}',
        e.stackTrace,
      );
    } catch (e, stackTrace) {
      appLogger.e('Unexpected login error: $e');
      throw AuthException('Unexpected error during login: $e', stackTrace);
    }
  }

  Future<SignupResponse> signup(SignupRequest request) async {
    try {
      appLogger.i('Attempting signup for: ${request.email} (${request.role})');

      final response = await _apiClient.post<dynamic>(
        '/auth/signup',
        data: request.toJson(),
      );

      final data = Map<String, dynamic>.from(response.data as Map);
      final signupResponse = SignupResponse.fromJson(data);

      appLogger.i('Signup successful for: ${request.email}');
      return signupResponse;
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final responseData = e.response?.data;
      final detail = responseData is Map<String, dynamic>
          ? (responseData['detail']?.toString() ?? e.message)
          : e.message;

      if (statusCode == 403) {
        throw AuthException(detail ?? 'Invite code invalid or forbidden', e.stackTrace);
      }
      if (statusCode == 409) {
        throw AuthException(detail ?? 'Email already registered', e.stackTrace);
      }
      if (statusCode == 422) {
        throw AuthException('Validation error in signup request', e.stackTrace);
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw ApiTimeoutException(
          'Connection timeout. Please check your internet connection.',
          e.stackTrace,
        );
      }
      if (e.type == DioExceptionType.connectionError) {
        throw NetworkException(
          'No internet connection',
          e.stackTrace,
        );
      }

      throw AuthException(
        detail ?? 'Signup failed',
        e.stackTrace,
      );
    } catch (e, stackTrace) {
      throw AuthException('Unexpected error during signup: $e', stackTrace);
    }
  }

  Future<List<String>> fetchSignupRoles() async {
    try {
      final response = await _apiClient.get<dynamic>('/auth/roles');
      final data = response.data;

      if (data is! List) {
        throw AuthException('Invalid roles response format', StackTrace.current);
      }

      return data
          .whereType<Object?>()
          .map((item) => item?.toString() ?? '')
          .where((role) => role.isNotEmpty)
          .toList(growable: false);
    } on DioException catch (e) {
      throw AuthException('Failed to fetch roles: ${e.message}', e.stackTrace);
    } catch (e, stackTrace) {
      throw AuthException('Unexpected error fetching roles: $e', stackTrace);
    }
  }

  /// Get current user profile from /api/v1/auth/me
  /// Requires valid authentication token
  /// Throws AuthException if not authenticated or request fails
  Future<User> getCurrentUser() async {
    try {
      appLogger.d('Fetching current user profile');

      final response = await _apiClient.get<dynamic>('/auth/me');

      final data = Map<String, dynamic>.from(response.data as Map);

      final user = User.fromJson(data);

      appLogger.i('Current user: ${user.email}');
      return user;
    } on DioException catch (e) {
      appLogger.e('Failed to get current user: ${e.message}');

      if (e.error is AuthExpiredException) {
        throw AuthExpiredException('Session expired. Please login again.');
      }

      if (e.response?.statusCode == 401) {
        throw AuthExpiredException('Authentication required');
      }

      throw AuthException(
        'Failed to get user profile: ${e.message}',
        e.stackTrace,
      );
    } catch (e, stackTrace) {
      appLogger.e('Unexpected error getting user: $e');
      throw AuthException('Unexpected error: $e', stackTrace);
    }
  }

  /// Logout local-first.
  /// Always clears local session, then best-effort revokes remote token.
  Future<void> logout() async {
    final refreshToken = await _tokenStorage.getRefreshToken();

    try {
      appLogger.i('Logging out');
      await clearLocalSession();

      try {
        await _apiClient.post<dynamic>(
          '/auth/logout',
          data: refreshToken == null
              ? null
              : <String, dynamic>{'refresh_token': refreshToken},
        );
      } catch (e) {
        appLogger.w('Remote token revocation failed during logout: $e');
      }

      appLogger.i('Logout successful - local session cleared');
    } catch (e) {
      appLogger.e('Error during logout: $e');
      await clearLocalSession();
    }
  }

  Future<void> clearLocalSession() async {
    await _tokenStorage.clear();
    await _kvStore.remove('current_user');
    await _kvStore.remove('selected_project');
  }

  /// Check if user has valid authentication tokens
  Future<bool> hasValidTokens() async {
    try {
      return await _tokenStorage.hasValidToken();
    } catch (e) {
      appLogger.e('Error checking token validity: $e');
      return false;
    }
  }

  /// Check if any tokens exist (even if expired)
  Future<bool> hasTokens() async {
    try {
      return await _tokenStorage.hasTokens();
    } catch (e) {
      appLogger.e('Error checking token existence: $e');
      return false;
    }
  }

  /// Bootstrap authentication - validate existing tokens.
  /// Returns [BootstrapResult] to indicate the correct auth flow to follow.
  Future<BootstrapResult> bootstrap() async {
    try {
      appLogger.d('Bootstrapping authentication');

      final hasTokens = await this.hasTokens();
      if (!hasTokens) {
        appLogger.d('No tokens found');
        return BootstrapResult.unauthenticated;
      }

      try {
        await getCurrentUser();
        appLogger.i('Bootstrap successful - user authenticated');
        return BootstrapResult.authenticated;
      } on AuthExpiredException catch (e) {
        // Server explicitly rejected the token (401). Safe to clear.
        appLogger.w('Bootstrap: token rejected by server, clearing: $e');
        await logout();
        return BootstrapResult.unauthenticated;
      } catch (e) {
        // Network error, timeout, 5xx — token may still be valid.
        // Check if offline PIN unlock is possible.
        appLogger.w('Bootstrap: network error, checking offline PIN: $e');
        if (_pinStorage != null && await _pinStorage.hasPin()) {
          appLogger.i('Bootstrap: offline PIN available → pinLocked');
          return BootstrapResult.pinLocked;
        }
        appLogger.w('Bootstrap: no PIN configured, staying unauthenticated');
        return BootstrapResult.unauthenticated;
      }
    } catch (e) {
      appLogger.e('Unexpected error during bootstrap: $e');
      return BootstrapResult.unauthenticated;
    }
  }

  /// Returns true if a PIN is configured for offline unlock.
  Future<bool> isPinConfigured() async {
    return _pinStorage != null && await _pinStorage.hasPin();
  }

  /// Returns cached user profile for offline PIN sessions.
  Future<Map<String, dynamic>?> getCachedUserJson() async {
    return _pinStorage?.getCachedUser();
  }
}
