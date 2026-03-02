import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/exceptions.dart';
import '../../../core/auth/token_storage.dart';
import '../../../core/utils/logger.dart';
import 'models/login_request.dart';
import 'models/token_response.dart';
import 'models/user.dart';

/// Repository for authentication operations
/// Uses ApiClient from Phase 3A with automatic JWT refresh
class AuthRepository {
  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  AuthRepository({
    required ApiClient apiClient,
    required TokenStorage tokenStorage,
  })  : _apiClient = apiClient,
        _tokenStorage = tokenStorage;

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

  /// Logout - clears all stored tokens
  Future<void> logout() async {
    try {
      appLogger.i('Logging out');
      await _tokenStorage.clear();
      appLogger.i('Logout successful - tokens cleared');
    } catch (e) {
      appLogger.e('Error during logout: $e');
      // Still clear tokens even if there's an error
      await _tokenStorage.clear();
    }
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

  /// Bootstrap authentication - validate existing tokens
  /// Returns true if user is authenticated, false otherwise
  /// Automatically clears invalid tokens
  Future<bool> bootstrap() async {
    try {
      appLogger.d('Bootstrapping authentication');

      // Check if tokens exist
      final hasTokens = await this.hasTokens();
      if (!hasTokens) {
        appLogger.d('No tokens found');
        return false;
      }

      // Try to validate tokens by fetching current user
      try {
        await getCurrentUser();
        appLogger.i('Bootstrap successful - user authenticated');
        return true;
      } on AuthExpiredException catch (e) {
        // Server explicitly rejected the token (401). Safe to clear.
        appLogger.w('Bootstrap: token rejected by server, clearing: $e');
        await logout();
        return false;
      } catch (e) {
        // Network error, timeout, 5xx — token may still be valid.
        // Don't wipe it: a future restart will retry. Treat as unauthenticated
        // for this session only (user will need to re-login this time).
        appLogger.w('Bootstrap failed (non-auth error, keeping tokens): $e');
        return false;
      }
    } catch (e) {
      appLogger.e('Unexpected error during bootstrap: $e');
      return false;
    }
  }
}
