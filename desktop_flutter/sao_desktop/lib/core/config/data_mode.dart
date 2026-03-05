class AppDataMode {
  AppDataMode._();

  /// Base URL del backend.
  /// Debe establecerse via --dart-define=SAO_BACKEND_URL=https://...
    /// Si no se establece, usa fallback al backend productivo.
  static const String backendBaseUrl =
            String.fromEnvironment(
                'SAO_BACKEND_URL',
                defaultValue: 'https://sao-api-fjzra25vya-uc.a.run.app',
            );

  /// JWT bearer token para llamadas online del desktop.
  /// En producción se usa el token dinámico de TokenStore (login).
  static const String backendBearerToken =
      String.fromEnvironment('SAO_BACKEND_TOKEN', defaultValue: '');
}
