/// API networking configuration
/// Defines base URLs, timeouts, and other HTTP settings
class ApiConfig {
  static const String defaultBaseUrl = String.fromEnvironment(
    'SAO_API_BASE',
    defaultValue: 'https://sao-api-fjzra25vya-uc.a.run.app/api/v1',
  );

  // Singleton instance
  static final ApiConfig _instance = ApiConfig._internal();
  factory ApiConfig() => _instance;
  ApiConfig._internal();

  /// Base URL for the API
  /// 
  /// Environment-specific URLs:
  /// - Development (Windows): 'http://localhost:8000/api/v1'
  /// - Development (Android emulator): 'http://10.0.2.2:8000/api/v1'
  /// - Development (Android device): 'http://192.168.1.100:8000/api/v1'
  /// - Development (iOS simulator): 'http://localhost:8000/api/v1'
  /// - Production: 'https://sao-api-fjzra25vya-uc.a.run.app/api/v1'
  String get baseUrl {
    // TODO: Use flavor-based configuration for prod/dev/staging
    return _baseUrl ?? defaultBaseUrl;
  }

  String? _baseUrl;

  /// Override base URL (useful for testing or environment switching)
  void setBaseUrl(String url) {
    _baseUrl = url;
  }

  /// Clears runtime override and restores the default URL.
  void resetBaseUrl() {
    _baseUrl = null;
  }

  /// Connection timeout duration
  Duration get connectTimeout => const Duration(seconds: 15);

  /// Receive timeout duration
  Duration get receiveTimeout => const Duration(seconds: 15);

  /// Send timeout duration
  Duration get sendTimeout => const Duration(seconds: 15);

  /// Default headers for all requests
  Map<String, String> get defaultHeaders => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  /// Maximum number of retry attempts for failed requests
  int get maxRetries => 3;

  /// Delay between retry attempts
  Duration get retryDelay => const Duration(seconds: 2);

  /// Whether to enable request/response logging
  bool get enableLogging => true;
}
