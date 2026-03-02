import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/biometric_service.dart';
import '../../../core/services/connectivity_service.dart';
import 'auth_service.dart';
import 'models/login_request.dart';
import 'models/user.dart';

/// Estado de autenticación
class AuthState {
  final User? user;
  final bool isLoading;
  final String? error;
  final bool isAuthenticated;
  final bool isOffline;
  final String? lastUserEmail;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
    this.isAuthenticated = false,
    this.isOffline = false,
    this.lastUserEmail,
  });

  AuthState copyWith({
    User? user,
    bool? isLoading,
    String? error,
    bool? isAuthenticated,
    bool? isOffline,
    String? lastUserEmail,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isOffline: isOffline ?? this.isOffline,
      lastUserEmail: lastUserEmail ?? this.lastUserEmail,
    );
  }
}

/// Provider del servicio de autenticación
final authServiceProvider = Provider<AuthService>((ref) {
  throw UnimplementedError('AuthService debe ser inicializado en service_locator');
});

/// Provider del servicio de biometría
final biometricServiceProvider = Provider<BiometricService>((ref) {
  throw UnimplementedError('BiometricService debe ser inicializado en service_locator');
});

/// Provider del servicio de conectividad
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  throw UnimplementedError('ConnectivityService debe ser inicializado en service_locator');
});

/// Provider del estado de autenticación
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;
  final BiometricService _biometricService;
  final ConnectivityService _connectivityService;

  AuthNotifier(
    this._authService,
    this._biometricService,
    this._connectivityService,
  ) : super(const AuthState()) {
    _checkAuthStatus();
    _monitorConnectivity();
  }

  /// Monitorea cambios en la conectividad
  void _monitorConnectivity() {
    _connectivityService.onConnectivityChanged.listen((results) async {
      final isOffline = await _connectivityService.isOffline();
      state = state.copyWith(isOffline: isOffline);
    });
  }

  /// Verifica si hay una sesión activa al iniciar
  Future<void> _checkAuthStatus() async {
    state = state.copyWith(isLoading: true);

    try {
      // Verificar conectividad
      final isOffline = await _connectivityService.isOffline();
      
      // Cargar último usuario
      final lastUser = await _authService.getLastUser();

      final hasTokens = await _authService.hasTokens();
      
      if (hasTokens) {
        if (!isOffline) {
          // Online: validar token con servidor
          try {
            final user = await _authService.getCurrentUser();
            state = AuthState(
              user: user,
              isAuthenticated: true,
              isLoading: false,
              isOffline: false,
              lastUserEmail: lastUser,
            );
          } catch (e) {
            // Token inválido, pero mantener sesión offline si es posible
            state = AuthState(
              isAuthenticated: hasTokens,
              isLoading: false,
              isOffline: isOffline,
              lastUserEmail: lastUser,
            );
          }
        } else {
          // Offline: confiar en el token local
          state = AuthState(
            isAuthenticated: true,
            isLoading: false,
            isOffline: true,
            lastUserEmail: lastUser,
          );
        }
      } else {
        state = AuthState(
          isLoading: false,
          isOffline: isOffline,
          lastUserEmail: lastUser,
        );
      }
    } catch (e) {
      state = AuthState(
        isLoading: false,
        isOffline: await _connectivityService.isOffline(),
      );
    }
  }

  /// Realiza login con email y password (online)
  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Verificar conectividad
      final isOffline = await _connectivityService.isOffline();
      if (isOffline) {
        state = state.copyWith(
          isLoading: false,
          error: 'Sin conexión a internet. Conéctate para iniciar sesión',
        );
        return false;
      }

      final request = LoginRequest(email: email, password: password);
      await _authService.login(request);

      // Obtener información del usuario
      final user = await _authService.getCurrentUser();

      state = AuthState(
        user: user,
        isAuthenticated: true,
        isLoading: false,
        isOffline: false,
        lastUserEmail: email,
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  /// Login offline con biometría
  Future<bool> loginWithBiometrics() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Verificar si tiene tokens guardados
      final hasTokens = await _authService.hasTokens();
      if (!hasTokens) {
        state = state.copyWith(
          isLoading: false,
          error: 'No hay sesión guardada. Inicia sesión con tu contraseña',
        );
        return false;
      }

      // Verificar si tiene biometría habilitada
      final biometricEnabled = await _authService.isBiometricEnabled();
      if (!biometricEnabled) {
        state = state.copyWith(
          isLoading: false,
          error: 'Biometría no habilitada. Actívala en ajustes',
        );
        return false;
      }

      // Autenticar con biometría
      final authenticated = await _biometricService.authenticate(
        localizedReason: 'Confirma tu identidad para acceder a SAO',
      );

      if (!authenticated) {
        state = state.copyWith(
          isLoading: false,
          error: 'Autenticación biométrica cancelada',
        );
        return false;
      }

      // Verificar conectividad
      final isOffline = await _connectivityService.isOffline();
      final lastUser = await _authService.getLastUser();

      if (!isOffline) {
        // Online: obtener datos frescos del usuario
        try {
          final user = await _authService.getCurrentUser();
          state = AuthState(
            user: user,
            isAuthenticated: true,
            isLoading: false,
            isOffline: false,
            lastUserEmail: lastUser,
          );
        } catch (e) {
          // Error de red, pero token válido localmente
          state = AuthState(
            isAuthenticated: true,
            isLoading: false,
            isOffline: true,
            lastUserEmail: lastUser,
          );
        }
      } else {
        // Offline: solo validar que tenga tokens
        state = AuthState(
          isAuthenticated: true,
          isLoading: false,
          isOffline: true,
          lastUserEmail: lastUser,
        );
      }

      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Error en autenticación: ${e.toString()}',
      );
      return false;
    }
  }

  /// Habilita/deshabilita biometría
  Future<void> setBiometricEnabled(bool enabled) async {
    if (enabled) {
      // Verificar que el dispositivo soporte biometría
      final canUse = await _biometricService.hasBiometricCredentials();
      if (!canUse) {
        state = state.copyWith(
          error: 'Tu dispositivo no tiene biometría configurada',
        );
        return;
      }

      // Pedir confirmación con biometría
      final authenticated = await _biometricService.authenticate(
        localizedReason: 'Confirma para habilitar inicio rápido',
      );

      if (!authenticated) {
        state = state.copyWith(
          error: 'Autenticación cancelada',
        );
        return;
      }
    }

    await _authService.setBiometricEnabled(enabled);
  }

  /// Verifica si tiene biometría habilitada
  Future<bool> isBiometricEnabled() {
    return _authService.isBiometricEnabled();
  }

  /// Verifica si el dispositivo soporta biometría
  Future<bool> canUseBiometrics() {
    return _biometricService.hasBiometricCredentials();
  }

  /// Cierra la sesión
  Future<void> logout() async {
    await _authService.logout();
    final lastUser = state.lastUserEmail;
    state = AuthState(
      isOffline: await _connectivityService.isOffline(),
      lastUserEmail: lastUser,
    );
  }

  /// Limpia el error
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Refresca el estado de autenticación
  Future<void> refresh() async {
    await _checkAuthStatus();
  }
}

/// Provider del notifier de autenticación
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  final biometricService = ref.watch(biometricServiceProvider);
  final connectivityService = ref.watch(connectivityServiceProvider);
  return AuthNotifier(authService, biometricService, connectivityService);
});
