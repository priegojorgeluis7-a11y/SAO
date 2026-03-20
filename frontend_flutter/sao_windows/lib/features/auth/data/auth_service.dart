import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../../../core/network/api_config.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/utils/logger.dart';
import 'models/login_request.dart';
import 'models/token_response.dart';
import 'models/user.dart';

/// Servicio de autenticación con el backend FastAPI
/// Soporta autenticación online y offline
class AuthService {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _lastUserKey = 'last_user';
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _offlinePinHashKey = 'offline_pin_hash';

  late final Dio _dio;
  final ApiConfig _apiConfig;
  final FlutterSecureStorage _secureStorage;
  final SharedPreferences _prefs;
  final ConnectivityService _connectivityService;

  AuthService(
    this._secureStorage,
    this._prefs,
    this._connectivityService,
    this._apiConfig,
  ) {
    final baseUrl = _apiConfig.baseUrl;
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    appLogger.i('AuthService backend URL: $baseUrl');

    // Interceptor para agregar token automáticamente
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await getAccessToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        // Si recibimos 401, intentar refrescar token
        if (error.response?.statusCode == 401) {
          final refreshed = await _refreshToken();
          if (refreshed) {
            // Reintentar la petición original
            final opts = error.requestOptions;
            final token = await getAccessToken();
            opts.headers['Authorization'] = 'Bearer $token';
            try {
              final response = await _dio.fetch<dynamic>(opts);
              return handler.resolve(response);
            } catch (e) {
              return handler.next(error);
            }
          }
        }
        return handler.next(error);
      },
    ));
  }

  /// Updates authentication client base URL at runtime.
  void updateBaseUrl(String baseUrl) {
    final normalized = baseUrl.trim();
    if (normalized.isEmpty) return;
    _apiConfig.setBaseUrl(normalized);
    _dio.options.baseUrl = normalized;
    appLogger.i('AuthService base URL updated to: $normalized');
  }

  /// Verifica si hay conexión a internet
  Future<bool> get isOnline => _connectivityService.hasConnection();

  /// Realiza login con email y password
  Future<TokenResponse> login(LoginRequest request) async {
    // Verificar conectividad
    final online = await isOnline;
    if (!online) {
      throw Exception('Sin conexión a internet. Conéctate para iniciar sesión');
    }

    try {
      final response = await _dio.post<dynamic>(
        '/auth/login',
        data: request.toJson(),
      );

      final data = Map<String, dynamic>.from(response.data as Map);

      final tokenResponse = TokenResponse.fromJson(data);

      // Guardar tokens de forma segura
      await _saveTokens(tokenResponse);
      
      // Guardar email del último usuario
      await _saveLastUser(request.email);

      appLogger.i('Login exitoso para ${request.email}');
      return tokenResponse;
    } on DioException catch (e) {
      appLogger.e('Error en login: ${e.message}');
      if (e.response?.statusCode == 401) {
        throw Exception('Credenciales incorrectas');
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception('Tiempo de espera agotado. Verifica tu conexión');
      } else if (e.type == DioExceptionType.connectionError) {
        throw Exception('Error de conexión: No se pudo conectar al servidor');
      }
      throw Exception('Error de conexión: ${e.message}');
    } catch (e) {
      appLogger.e('Error inesperado en login: $e');
      throw Exception('Error inesperado: $e');
    }
  }

  /// Obtiene información del usuario actual
  Future<User> getCurrentUser() async {
    try {
      final response = await _dio.get<dynamic>('/auth/me');
      final data = Map<String, dynamic>.from(response.data as Map);
      final user = User.fromJson(data);
      
      // Guardar información del usuario para uso offline
      await _saveLastUser(user.email);
      
      return user;
    } on DioException catch (e) {
      appLogger.e('Error obteniendo usuario: ${e.message}');
      throw Exception('Error obteniendo usuario: ${e.message}');
    }
  }

  /// Refresca el access token usando el refresh token
  Future<bool> _refreshToken() async {
    try {
      final refreshToken = await getRefreshToken();
      if (refreshToken == null) return false;

      final response = await _dio.post<dynamic>(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      final data = Map<String, dynamic>.from(response.data as Map);
      final tokenResponse = TokenResponse.fromJson(data);
      await _saveTokens(tokenResponse);

      appLogger.i('Token refrescado exitosamente');
      return true;
    } catch (e) {
      appLogger.e('Error refrescando token: $e');
      await clearTokens();
      return false;
    }
  }

  /// Guarda los tokens de forma segura
  Future<void> _saveTokens(TokenResponse tokens) async {
    await _secureStorage.write(key: _accessTokenKey, value: tokens.accessToken);
    await _secureStorage.write(
        key: _refreshTokenKey, value: tokens.refreshToken);
  }

  /// Guarda el email del último usuario
  Future<void> _saveLastUser(String email) async {
    await _prefs.setString(_lastUserKey, email);
  }

  /// Obtiene el email del último usuario
  Future<String?> getLastUser() async {
    return _prefs.getString(_lastUserKey);
  }

  /// Obtiene el access token guardado
  Future<String?> getAccessToken() async {
    return await _secureStorage.read(key: _accessTokenKey);
  }

  /// Obtiene el refresh token guardado
  Future<String?> getRefreshToken() async {
    return await _secureStorage.read(key: _refreshTokenKey);
  }

  /// Verifica si hay tokens guardados
  Future<bool> hasTokens() async {
    final accessToken = await getAccessToken();
    return accessToken != null && accessToken.isNotEmpty;
  }

  /// Verifica si tiene biometría habilitada
  Future<bool> isBiometricEnabled() async {
    return _prefs.getBool(_biometricEnabledKey) ?? false;
  }

  /// Habilita o deshabilita biometría
  Future<void> setBiometricEnabled(bool enabled) async {
    await _prefs.setBool(_biometricEnabledKey, enabled);
  }

  /// Cierra sesión limpiando los tokens
  Future<void> logout() async {
    await clearTokens();
    // No limpiar el último usuario para poder mostrar "Hola de nuevo, X"
    appLogger.i('Sesión cerrada');
  }

  /// Limpia todos los tokens
  Future<void> clearTokens() async {
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
  }

  String _hashPin(String pin, String email) {
    final payload = '$email:$pin';
    return sha256.convert(utf8.encode(payload)).toString();
  }

  Future<bool> hasOfflinePinConfigured() async {
    final hash = await _secureStorage.read(key: _offlinePinHashKey);
    return hash != null && hash.isNotEmpty;
  }

  Future<void> setupOfflinePin(String pin) async {
    final online = await isOnline;
    if (!online) {
      throw Exception('Se requiere conexión para registrar PIN');
    }

    if (!RegExp(r'^\d{4,6}$').hasMatch(pin)) {
      throw Exception('El PIN debe tener 4 a 6 dígitos numéricos');
    }

    await _dio.put<dynamic>('/auth/me/pin', data: {'pin': pin});

    final email = (await getLastUser())?.trim();
    if (email == null || email.isEmpty) {
      throw Exception('No se pudo asociar el PIN al usuario actual');
    }

    final hashed = _hashPin(pin, email);
    await _secureStorage.write(key: _offlinePinHashKey, value: hashed);
  }

  Future<bool> loginOfflineWithPin(String pin) async {
    if (!RegExp(r'^\d{4,6}$').hasMatch(pin)) {
      return false;
    }

    final hasTokensSaved = await hasTokens();
    if (!hasTokensSaved) return false;

    final email = (await getLastUser())?.trim();
    if (email == null || email.isEmpty) return false;

    final savedHash = await _secureStorage.read(key: _offlinePinHashKey);
    if (savedHash == null || savedHash.isEmpty) return false;

    return _hashPin(pin, email) == savedHash;
  }

  /// Cambia la contraseña del usuario autenticado
  Future<void> changePassword(String currentPassword, String newPassword) async {
    final online = await isOnline;
    if (!online) {
      throw Exception('Se requiere conexión para cambiar la contraseña');
    }
    try {
      await _dio.put<dynamic>(
        '/auth/me/password',
        data: {
          'current_password': currentPassword,
          'new_password': newPassword,
        },
      );
      appLogger.i('Contraseña cambiada exitosamente');
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        throw Exception('La contraseña actual es incorrecta');
      }
      throw Exception('Error al cambiar contraseña: ${e.message}');
    }
  }

  /// Limpia todo (incluyendo último usuario)
  Future<void> clearAll() async {
    await clearTokens();
    await _secureStorage.delete(key: _offlinePinHashKey);
    await _prefs.remove(_lastUserKey);
    await _prefs.remove(_biometricEnabledKey);
  }
}

