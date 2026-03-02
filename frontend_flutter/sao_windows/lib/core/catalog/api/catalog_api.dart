import '../../../core/network/api_client.dart';

/// Cliente HTTP para los endpoints de catálogo.
///
/// Fix: reemplaza el Dio propio + AuthService por ApiClient (GetIt singleton).
///
/// El problema original: CatalogApi creaba su propio Dio y leía el token
/// de AuthService (clave 'access_token' en FlutterSecureStorage).
/// El login moderno (AuthRepository/TokenStorage) guarda el token bajo
/// 'auth_token_data' — clave distinta. AuthService.getAccessToken()
/// siempre retornaba null → Authorization header ausente → 401.
///
/// Con ApiClient:
/// - Token correcto: lee de TokenStorage (misma clave que usa el login).
/// - Auto-refresh incluido: si el token expira, el interceptor lo renueva y
///   reintenta la request automáticamente.
/// - Un solo Dio/interceptor en toda la app — sin duplicación.
class CatalogApi {
  final ApiClient _apiClient;

  CatalogApi(this._apiClient);

  Future<String> getCurrentVersion({required String projectId}) async {
    final response = await _apiClient.get<dynamic>(
      '/catalog/version/current',
      queryParameters: {'project_id': projectId},
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    return data['version_id'] as String;
  }

  Future<Map<String, dynamic>> getDiff({
    required String projectId,
    required String fromVersionId,
    String? toVersionId,
  }) async {
    final queryParameters = <String, dynamic>{
      'project_id': projectId,
      'from_version_id': fromVersionId,
    };
    if (toVersionId != null) {
      queryParameters['to_version_id'] = toVersionId;
    }

    final response = await _apiClient.get<dynamic>(
      '/catalog/diff',
      queryParameters: queryParameters,
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> getEffective({
    required String projectId,
    String? versionId,
  }) async {
    final queryParameters = <String, dynamic>{
      'project_id': projectId,
    };
    if (versionId != null) {
      queryParameters['version_id'] = versionId;
    }

    final response = await _apiClient.get<dynamic>(
      '/catalog/effective',
      queryParameters: queryParameters,
    );
    return Map<String, dynamic>.from(response.data as Map);
  }
}
