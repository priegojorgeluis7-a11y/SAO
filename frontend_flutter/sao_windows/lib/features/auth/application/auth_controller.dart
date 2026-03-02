import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/exceptions.dart';
import '../../../core/utils/logger.dart';
import '../data/auth_repository.dart';
import '../data/models/login_request.dart';
import '../data/models/user.dart';

/// Authentication state
class AuthState {
  final User? user;
  final bool isLoading;
  final String? error;
  final bool isAuthenticated;
  final bool tutorialMode;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
    this.isAuthenticated = false,
    this.tutorialMode = false,
  });

  const AuthState.initial()
      : user = null,
        isLoading = false,
        error = null,
        isAuthenticated = false,
        tutorialMode = false;

  const AuthState.loading()
      : user = null,
        isLoading = true,
        error = null,
      isAuthenticated = false,
      tutorialMode = false;

    const AuthState.authenticated(this.user, {this.tutorialMode = false})
      : isLoading = false,
        error = null,
        isAuthenticated = true;

  const AuthState.unauthenticated([this.error])
      : user = null,
        isLoading = false,
      isAuthenticated = false,
      tutorialMode = false;

  AuthState copyWith({
    User? user,
    bool? isLoading,
    String? error,
    bool? isAuthenticated,
    bool? tutorialMode,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      tutorialMode: tutorialMode ?? this.tutorialMode,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthState &&
          runtimeType == other.runtimeType &&
          user == other.user &&
          isLoading == other.isLoading &&
          error == other.error &&
          isAuthenticated == other.isAuthenticated &&
          tutorialMode == other.tutorialMode;

  @override
  int get hashCode =>
      user.hashCode ^
      isLoading.hashCode ^
      error.hashCode ^
      isAuthenticated.hashCode ^
      tutorialMode.hashCode;
}

/// Auth controller - manages authentication state
class AuthController extends StateNotifier<AuthState> {
  final AuthRepository _repository;

  AuthController(this._repository) : super(const AuthState.initial()) {
    // Bootstrap authentication on initialization
    bootstrap();
  }

  /// Bootstrap authentication - check if user is already authenticated
  /// Called automatically on controller initialization
  Future<void> bootstrap() async {
    state = const AuthState.loading();

    try {
      appLogger.d('Bootstrapping authentication');

      final isAuthenticated = await _repository.bootstrap();

      if (isAuthenticated) {
        // Fetch current user
        final user = await _repository.getCurrentUser();
        state = AuthState.authenticated(user);
        appLogger.i('Bootstrap complete - user authenticated: ${user.email}');
      } else {
        state = const AuthState.unauthenticated();
        appLogger.d('Bootstrap complete - no authentication');
      }
    } catch (e) {
      appLogger.e('Bootstrap error: $e');
      state = const AuthState.unauthenticated('Failed to restore session');
    }
  }

  /// Login with email and password
  Future<void> login(String email, String password, {bool tutorialMode = false}) async {
    state = const AuthState.loading();

    try {
      appLogger.i('Login attempt: $email');

      // Call repository to login
      await _repository.login(LoginRequest(
        email: email,
        password: password,
      ));

      // Fetch current user after successful login
      final user = await _repository.getCurrentUser();

      state = AuthState.authenticated(user, tutorialMode: tutorialMode);
      appLogger.i('Login successful: ${user.email}');
    } on InvalidCredentialsException catch (e) {
      appLogger.w('Invalid credentials: $e');
      state = const AuthState.unauthenticated('Invalid email or password');
    } on NetworkException catch (e) {
      appLogger.w('Network error during login: $e');
      state = const AuthState.unauthenticated('No internet connection');
    } on ApiTimeoutException catch (e) {
      appLogger.w('Timeout during login: $e');
      state = const AuthState.unauthenticated('Connection timeout');
    } on AuthException catch (e) {
      appLogger.e('Auth error during login: $e');
      state = AuthState.unauthenticated(e.message);
    } catch (e) {
      appLogger.e('Unexpected login error: $e');
      state = AuthState.unauthenticated('Unexpected error: $e');
    }
  }

  /// Enable/disable tutorial mode for current authenticated session
  void setTutorialMode(bool enabled) {
    if (!state.isAuthenticated) return;
    state = state.copyWith(tutorialMode: enabled);
  }

  /// Logout - clear authentication state and tokens
  Future<void> logout() async {
    try {
      appLogger.i('Logout initiated');

      await _repository.logout();

      state = const AuthState.unauthenticated();
      appLogger.i('Logout complete');
    } catch (e) {
      appLogger.e('Error during logout: $e');
      // Still set state to unauthenticated even if there's an error
      state = const AuthState.unauthenticated();
    }
  }

  /// Refresh current user data
  Future<void> refreshUser() async {
    if (!state.isAuthenticated) {
      appLogger.w('Cannot refresh user - not authenticated');
      return;
    }

    try {
      final user = await _repository.getCurrentUser();
      state = AuthState.authenticated(user);
      appLogger.d('User data refreshed');
    } on AuthExpiredException {
      appLogger.w('Session expired during refresh');
      state = const AuthState.unauthenticated('Session expired');
    } catch (e) {
      appLogger.e('Error refreshing user: $e');
      // Keep current state if refresh fails
    }
  }

  /// Clear error state
  void clearError() {
    if (state.error != null) {
      state = state.copyWith(error: null);
    }
  }

}
