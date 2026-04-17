import '../network/api_config.dart';

/// Configuración de la aplicación
class AppConfig {
  /// URL del backend API.
  ///
  /// Usa el mismo backend desplegado que SAO desktop por defecto.
  /// También acepta SAO_BACKEND_URL o SAO_API_BASE como override.
  static String get baseApiUrl => ApiConfig.defaultBaseUrl;
  
  /// Timeout para conexiones HTTP
  static const Duration connectionTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);
  
  /// Versión de la aplicación
  static const String appVersion = 'v1.0.0';
  
  /// Nombre completo del sistema
  static const String appFullName = 'Sistema de Administración Operativa';
  
  /// Duración del token de sesión (para UI)
  static const Duration tokenRefreshThreshold = Duration(minutes: 5);
  
  /// Tiempo máximo que un usuario puede trabajar offline
  static const Duration maxOfflineTime = Duration(days: 30);
}
