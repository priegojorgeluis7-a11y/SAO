class AppDataMode {
  AppDataMode._();

  /// Base URL del backend.
  /// Debe establecerse via --dart-define=SAO_BACKEND_URL=https://...
    /// Si no se establece, usa fallback al backend productivo.
  static const String backendBaseUrl = String.fromEnvironment(
    'SAO_BACKEND_URL',
    defaultValue: 'https://sao-api-97150883570.us-central1.run.app',
  );

  static bool get isLocalBackendDisallowed {
    final normalized = backendBaseUrl.trim().toLowerCase();
    return normalized.contains('localhost') ||
        normalized.contains('127.0.0.1');
  }

  static String requireRealBackendUrl() {
    final normalized = backendBaseUrl.trim();
    if (normalized.isEmpty) {
      throw StateError(
        'SAO_BACKEND_URL es obligatorio y debe apuntar al backend real.',
      );
    }
    if (isLocalBackendDisallowed) {
      throw StateError(
        'SAO_BACKEND_URL no puede usar localhost/127.0.0.1 en escritorio.',
      );
    }
    return normalized;
  }

  /// JWT bearer token para llamadas online del desktop.
  /// En producción se usa el token dinámico de TokenStore (login).
  static const String backendBearerToken =
      String.fromEnvironment('SAO_BACKEND_TOKEN', defaultValue: '');
}
