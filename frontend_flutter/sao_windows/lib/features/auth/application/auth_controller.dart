import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/exceptions.dart';
import '../../../core/auth/pin_storage.dart';
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

  /// true → mostrar pantalla de PIN (sin red, tokens existen, PIN configurado).
  final bool requiresPinUnlock;

  /// true → redirigir a /auth/pin-setup después del login online.
  final bool needsPinSetup;

  /// true → sesión restaurada offline con PIN (sin validar contra servidor).
  final bool isOfflineSession;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
    this.isAuthenticated = false,
    this.tutorialMode = false,
    this.requiresPinUnlock = false,
    this.needsPinSetup = false,
    this.isOfflineSession = false,
  });

  const AuthState.initial()
      : user = null,
        isLoading = false,
        error = null,
        isAuthenticated = false,
        tutorialMode = false,
        requiresPinUnlock = false,
        needsPinSetup = false,
        isOfflineSession = false;

  const AuthState.loading()
      : user = null,
        isLoading = true,
        error = null,
        isAuthenticated = false,
        tutorialMode = false,
        requiresPinUnlock = false,
        needsPinSetup = false,
        isOfflineSession = false;

  const AuthState.authenticated(this.user, {this.tutorialMode = false, this.needsPinSetup = false})
      : isLoading = false,
        error = null,
        isAuthenticated = true,
        requiresPinUnlock = false,
        isOfflineSession = false;

  const AuthState.unauthenticated([this.error])
      : user = null,
        isLoading = false,
        isAuthenticated = false,
        tutorialMode = false,
        requiresPinUnlock = false,
        needsPinSetup = false,
        isOfflineSession = false;

  /// Estado de PIN bloqueado: tokens existen pero sin red.
  const AuthState.pinLocked(this.user)
      : isLoading = false,
        error = null,
        isAuthenticated = false,
        tutorialMode = false,
        requiresPinUnlock = true,
        needsPinSetup = false,
        isOfflineSession = false;

  /// Sesión offline restaurada exitosamente con PIN correcto.
  const AuthState.offlineAuthenticated(this.user)
      : isLoading = false,
        error = null,
        isAuthenticated = true,
        tutorialMode = false,
        requiresPinUnlock = false,
        needsPinSetup = false,
        isOfflineSession = true;

  AuthState copyWith({
    User? user,
    bool? isLoading,
    String? error,
    bool? isAuthenticated,
    bool? tutorialMode,
    bool? requiresPinUnlock,
    bool? needsPinSetup,
    bool? isOfflineSession,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      tutorialMode: tutorialMode ?? this.tutorialMode,
      requiresPinUnlock: requiresPinUnlock ?? this.requiresPinUnlock,
      needsPinSetup: needsPinSetup ?? this.needsPinSetup,
      isOfflineSession: isOfflineSession ?? this.isOfflineSession,
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
          tutorialMode == other.tutorialMode &&
          requiresPinUnlock == other.requiresPinUnlock &&
          needsPinSetup == other.needsPinSetup &&
          isOfflineSession == other.isOfflineSession;

  @override
  int get hashCode =>
      user.hashCode ^
      isLoading.hashCode ^
      error.hashCode ^
      isAuthenticated.hashCode ^
      tutorialMode.hashCode ^
      requiresPinUnlock.hashCode ^
      needsPinSetup.hashCode ^
      isOfflineSession.hashCode;
}

/// Auth controller - manages authentication state
class AuthController extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  final PinStorage? _pinStorage;

  AuthController(this._repository, {PinStorage? pinStorage})
      : _pinStorage = pinStorage,
        super(const AuthState.initial()) {
    bootstrap();
  }

  /// Bootstrap authentication - check if user is already authenticated
  /// Called automatically on controller initialization
  Future<void> bootstrap() async {
    state = const AuthState.loading();

    try {
      appLogger.d('Bootstrapping authentication');

      final result = await _repository.bootstrap();

      switch (result) {
        case BootstrapResult.authenticated:
          final user = await _repository.getCurrentUser();
          state = AuthState.authenticated(user);
          appLogger.i('Bootstrap complete - user authenticated: ${user.email}');

        case BootstrapResult.pinLocked:
          final cachedJson = await _repository.getCachedUserJson();
          final cachedUser =
              cachedJson != null ? User.fromJson(cachedJson) : null;
          state = AuthState.pinLocked(cachedUser);
          appLogger.i('Bootstrap complete - PIN unlock required');

        case BootstrapResult.unauthenticated:
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

      // If no PIN is configured yet, prompt setup
      final pinConfigured = await _repository.isPinConfigured();
      state = AuthState.authenticated(
        user,
        tutorialMode: tutorialMode,
        needsPinSetup: !pinConfigured,
      );
      appLogger.i('Login successful: ${user.email} (needsPinSetup=${!pinConfigured})');
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

  /// Logout - clear authentication state, tokens and PIN data
  Future<void> logout() async {
    try {
      appLogger.i('Logout initiated');

      await _repository.logout();
      await _pinStorage?.clearAll();

      state = const AuthState.unauthenticated();
      appLogger.i('Logout complete');
    } catch (e) {
      appLogger.e('Error during logout: $e');
      state = const AuthState.unauthenticated();
    }
  }

  /// Intenta desbloquear la sesión offline con el PIN ingresado.
  Future<void> loginWithPin(String pin) async {
    if (_pinStorage == null) {
      state = const AuthState.unauthenticated('PIN no configurado');
      return;
    }

    state = const AuthState.loading();

    try {
      final isValid = await _pinStorage.verifyPin(pin);
      if (!isValid) {
        final cachedJson = await _repository.getCachedUserJson();
        final cachedUser =
            cachedJson != null ? User.fromJson(cachedJson) : null;
        state = AuthState.pinLocked(cachedUser)
            .copyWith(error: 'PIN incorrecto. Intenta de nuevo.');
        return;
      }

      final cachedJson = await _repository.getCachedUserJson();
      if (cachedJson == null) {
        state = const AuthState.unauthenticated('Sesión expirada. Inicia sesión en línea.');
        return;
      }

      final user = User.fromJson(cachedJson);
      state = AuthState.offlineAuthenticated(user);
      appLogger.i('PIN correcto — sesión offline restaurada: ${user.email}');
    } catch (e) {
      appLogger.e('loginWithPin error: $e');
      state = const AuthState.unauthenticated('Error al verificar PIN');
    }
  }

  /// Guarda un nuevo PIN tras login online exitoso.
  Future<void> setupPin(String pin) async {
    try {
      if (_pinStorage != null) {
        await _pinStorage.savePin(pin);
        appLogger.i('PIN configurado exitosamente');
      }
      // Quitar el flag needsPinSetup sin cambiar el resto del estado
      if (state.isAuthenticated) {
        state = state.copyWith(needsPinSetup: false);
      }
    } catch (e) {
      appLogger.e('setupPin error: $e');
    }
  }

  /// Descarta la configuración de PIN sin guardarlo.
  void skipPinSetup() {
    if (state.isAuthenticated) {
      state = state.copyWith(needsPinSetup: false);
    }
  }

  /// Elimina el PIN actual (para reconfigurar).
  Future<void> clearPin() async {
    await _pinStorage?.clearAll();
    appLogger.i('PIN eliminado');
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
