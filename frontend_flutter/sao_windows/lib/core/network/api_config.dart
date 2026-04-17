/// API networking configuration
/// Defines base URLs, timeouts, and other HTTP settings
class ApiConfig {
  static const String _deployedBackendRoot =
      'https://sao-api-fjzra25vya-uc.a.run.app';
  static const String _definedSaoBackendUrl = String.fromEnvironment(
    'SAO_BACKEND_URL',
    defaultValue: '',
  );
  static const String _legacyDefinedBaseUrl = String.fromEnvironment(
    'SAO_API_BASE',
    defaultValue: '',
  );

  static String normalizeBaseUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) {
      return '$_deployedBackendRoot/api/v1';
    }

    final sanitized = trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;

    if (sanitized.endsWith('/api/v1')) {
      return sanitized;
    }
    if (sanitized.endsWith('/api')) {
      return '$sanitized/v1';
    }
    return '$sanitized/api/v1';
  }

  static String get defaultBaseUrl {
    if (_definedSaoBackendUrl.trim().isNotEmpty) {
      return normalizeBaseUrl(_definedSaoBackendUrl);
    }
    if (_legacyDefinedBaseUrl.trim().isNotEmpty) {
      return normalizeBaseUrl(_legacyDefinedBaseUrl);
    }
    return normalizeBaseUrl(_deployedBackendRoot);
  }

  // Singleton instance
  static final ApiConfig _instance = ApiConfig._internal();
  factory ApiConfig() => _instance;
  ApiConfig._internal();

  /// Base URL for the API.
  ///
  /// By default mobile now points to the same deployed SAO backend as desktop.
  /// If needed, it can still be overridden with SAO_BACKEND_URL or SAO_API_BASE.
  String get baseUrl {
    // TODO: Use flavor-based configuration for prod/dev/staging
    return _baseUrl ?? defaultBaseUrl;
  }

  String? _baseUrl;

  /// Override base URL (useful for testing or environment switching)
  void setBaseUrl(String url) {
    _baseUrl = normalizeBaseUrl(url);
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
