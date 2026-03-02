class AppDataMode {
  AppDataMode._();

  /// Global switch de datos.
  /// true  -> usa mocks operativos
  /// false -> intenta backend y, si falla, usa DB local
  static const bool useMocks = true;

  /// Base URL del backend (opcional).
  /// Ejemplo: http://127.0.0.1:8000
  static const String backendBaseUrl = '';

  /// JWT bearer token para llamadas online del desktop.
  /// Dejar vacío para modo local/mock.
  static const String backendBearerToken = '';
}
