/// Configuración de la aplicación
class AppConfig {
  /// URL del backend API
  /// 
  /// Para desarrollo local:
  /// - Windows: 'http://localhost:8000/api/v1'
  /// - Android (dispositivo): 'http://192.168.1.100:8000/api/v1' (IP de tu PC en la red)
  /// - Android (emulador): 'http://10.0.2.2:8000/api/v1' (apunta al localhost de la PC)
  /// - iOS (simulador): 'http://localhost:8000/api/v1'
  static const String baseApiUrl = 'https://sao-api-fjzra25vya-uc.a.run.app/api/v1';
  
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
