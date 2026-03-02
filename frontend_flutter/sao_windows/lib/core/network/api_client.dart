import 'dart:async';
import 'package:dio/dio.dart';
import '../auth/token_storage.dart';
import '../utils/logger.dart';
import 'api_config.dart';
import 'exceptions.dart';

// Header interno que marca un request como reintento.
// Evita bucles infinitos si el token nuevo también devuelve 401.
const _kRetryHeader = 'x-sao-retry';

/// HTTP API client con rotación automática de JWT.
///
/// Bugs corregidos vs versión anterior:
/// 1. [_noAuthDio] — instancia separada SIN interceptores para /auth/refresh.
///    La versión anterior usaba _dio para el refresh desde dentro de onError,
///    causando deadlock en el pipeline de interceptores de Dio.
/// 2. [_retryRequest] usa _dio.fetch() en vez de _dio.request().
///    fetch() no re-entra a onRequest, eliminando el doble attach de token.
/// 3. Guard [_kRetryHeader] — si el retry también devuelve 401, onError
///    no lanza otro ciclo de refresh (bucle infinito).
/// 4. [_pendingCompleters] resuelven a String? (el nuevo token) en vez de void.
///    Requests concurrentes reciben el token directamente sin releer storage.
/// 5. Refresh proactivo en onRequest si el token expira en < 5 min.
class ApiClient {
  late final Dio _dio;

  /// Instancia limpia sin interceptores, SOLO para POST /auth/refresh.
  /// CRÍTICO: no usar _dio para el refresh — causa deadlock en Dio.
  late final Dio _noAuthDio;

  final TokenStorage _tokenStorage;
  final ApiConfig _config;

  /// true mientras hay un refresh en curso.
  bool _isRefreshing = false;

  /// Requests en cola esperando el resultado del refresh en curso.
  /// Se completan con el nuevo access token (String) o null si falló.
  final List<Completer<String?>> _pendingCompleters = [];

  ApiClient({
    required TokenStorage tokenStorage,
    ApiConfig? config,
  })  : _tokenStorage = tokenStorage,
        _config = config ?? ApiConfig() {
    final baseOptions = BaseOptions(
      baseUrl: _config.baseUrl,
      connectTimeout: _config.connectTimeout,
      receiveTimeout: _config.receiveTimeout,
      sendTimeout: _config.sendTimeout,
      headers: _config.defaultHeaders,
    );

    _dio = Dio(baseOptions);
    _dio.interceptors.add(_createAuthInterceptor());
    if (_config.enableLogging) {
      _dio.interceptors.add(_createLoggingInterceptor());
    }

    // _noAuthDio: misma configuración de red, CERO interceptores.
    _noAuthDio = Dio(baseOptions);
  }

  Dio get dio => _dio;

  // ─────────────────────────────────────────────
  // Interceptor de autenticación
  // ─────────────────────────────────────────────

  Interceptor _createAuthInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) async {
        if (_shouldSkipAuth(options.path)) return handler.next(options);

        // Refresh proactivo: renovar antes de enviar si el token expira en < 5 min.
        // Evita el round-trip innecesario 401 → refresh → retry.
        if (await _tokenStorage.shouldRefreshToken()) {
          appLogger.i('⏰ Proactive token refresh before: ${options.path}');
          await _refreshAccessToken();
        }

        final accessToken = await _tokenStorage.getAccessToken();
        if (accessToken == null) {
          // Sin token: rechazar con error tipado en vez de enviar sin auth.
          appLogger.w('⚠️ No access token for ${options.path}');
          return handler.reject(
            DioException(
              requestOptions: options,
              error: NoTokenException(),
              type: DioExceptionType.cancel,
            ),
          );
        }

        options.headers['Authorization'] = 'Bearer $accessToken';
        return handler.next(options);
      },

      onError: (error, handler) async {
        if (error.response?.statusCode != 401) return handler.next(error);

        // El propio endpoint de auth falló → no reintentar.
        if (_shouldSkipAuth(error.requestOptions.path)) {
          return handler.next(error);
        }

        // Guard de re-entrada: este request ya fue reintentado una vez.
        // Si el nuevo token también produce 401 → sesión definitivamente expirada.
        if (error.requestOptions.headers[_kRetryHeader] == 'true') {
          appLogger.w('🔒 Retry also returned 401 — session expired');
          return handler.reject(
            DioException(
              requestOptions: error.requestOptions,
              error: AuthExpiredException(),
              type: DioExceptionType.badResponse,
            ),
          );
        }

        appLogger.i('🔑 401 on ${error.requestOptions.path} — attempting refresh');

        final newToken = await _refreshAccessToken();

        if (newToken == null) {
          appLogger.w('❌ Refresh failed — authentication expired');
          return handler.reject(
            DioException(
              requestOptions: error.requestOptions,
              error: AuthExpiredException(),
              type: DioExceptionType.badResponse,
            ),
          );
        }

        // Reintentar con el token nuevo y el guard activado.
        try {
          final response = await _retryRequest(
            error.requestOptions,
            newToken: newToken,
          );
          return handler.resolve(response);
        } on DioException catch (e) {
          return handler.next(e);
        }
      },
    );
  }

  // ─────────────────────────────────────────────
  // Refresh de token
  // ─────────────────────────────────────────────

  /// Refresca el access token usando el refresh token almacenado.
  ///
  /// Retorna el nuevo access token si tuvo éxito, null si falló.
  /// Si ya hay un refresh en curso, los callers concurrentes se encolan
  /// y reciben el mismo resultado sin disparar otro refresh.
  Future<String?> _refreshAccessToken() async {
    if (_isRefreshing) {
      // Encolar y esperar el resultado del refresh en curso.
      final completer = Completer<String?>();
      _pendingCompleters.add(completer);
      appLogger.d('Queued behind in-progress refresh (${_pendingCompleters.length})');
      return completer.future;
    }

    _isRefreshing = true;
    String? newToken;

    try {
      final refreshToken = await _tokenStorage.getRefreshToken();
      if (refreshToken == null) {
        appLogger.w('No refresh token in storage');
        return null;
      }

      appLogger.i('🔄 Calling POST /auth/refresh via _noAuthDio');

      // FIX CRÍTICO: usar _noAuthDio (sin interceptores).
      // Llamar a _dio.post() desde onError produce deadlock porque Dio
      // necesita procesar la request interna por el mismo pipeline que
      // ya está esperando que onError termine.
      final response = await _noAuthDio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      final data = response.data ?? <String, dynamic>{};
      final accessToken = data['access_token'] as String;
      final newRefreshToken = data['refresh_token'] as String?;
      // expires_in en segundos (backend debe incluirlo — ver fix en auth.py)
      final expiresIn = data['expires_in'] as int?;

      if (newRefreshToken != null) {
        await _tokenStorage.saveTokens(
          accessToken: accessToken,
          refreshToken: newRefreshToken,
          expiresIn: expiresIn,
        );
      } else {
        await _tokenStorage.updateAccessToken(
          accessToken: accessToken,
          expiresIn: expiresIn,
        );
      }

      newToken = accessToken;
      appLogger.i('✅ Token refresh successful');
      return newToken;
    } catch (e) {
      appLogger.e('❌ Token refresh failed: $e');
      // Only wipe tokens when the refresh endpoint explicitly rejects them (401/403).
      // For network errors, timeouts or 5xx the existing tokens are still valid;
      // clearing them here would force the user back to the login page the next time
      // the app restarts, even though their session is fine.
      if (e is DioException && (e.response?.statusCode == 401 || e.response?.statusCode == 403)) {
        await _tokenStorage.clear();
      }
      return null;
    } finally {
      _isRefreshing = false;
      // Resolver todos los requests en cola con el mismo resultado.
      // Reciben String? directamente — sin releer storage.
      for (final c in _pendingCompleters) {
        c.complete(newToken);
      }
      _pendingCompleters.clear();
    }
  }

  // ─────────────────────────────────────────────
  // Retry interno
  // ─────────────────────────────────────────────

  /// Reintenta el request original con el token nuevo.
  ///
  /// Usa _dio.fetch() en vez de _dio.request() para NO re-entrar
  /// al interceptor onRequest. Activa [_kRetryHeader] para que un
  /// segundo 401 no dispare otro ciclo de refresh.
  Future<Response<dynamic>> _retryRequest(
    RequestOptions original, {
    required String newToken,
  }) async {
    original.headers['Authorization'] = 'Bearer $newToken';
    original.headers[_kRetryHeader] = 'true';
    // fetch() usa el RequestOptions existente y pasa por onResponse/onError
    // pero NO por onRequest — evita doble attach de token.
    return _dio.fetch(original);
  }

  // ─────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────

  bool _shouldSkipAuth(String path) {
    return path.contains('/auth/login') ||
        path.contains('/auth/refresh') ||
        path.contains('/auth/register');
  }

  Interceptor _createLoggingInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        appLogger.d('→ ${options.method} ${options.path}');
        if (options.data != null) appLogger.d('  Body: ${options.data}');
        return handler.next(options);
      },
      onResponse: (response, handler) {
        appLogger.d('← ${response.statusCode} ${response.requestOptions.path}');
        return handler.next(response);
      },
      onError: (error, handler) {
        appLogger.e(
          '✗ ${error.response?.statusCode ?? "net"} ${error.requestOptions.path}',
        );
        if (error.response?.data != null) {
          appLogger.e('  Body: ${error.response?.data}');
        }
        return handler.next(error);
      },
    );
  }

  // ─────────────────────────────────────────────
  // HTTP helpers
  // ─────────────────────────────────────────────

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) =>
      _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) =>
      _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) =>
      _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) =>
      _dio.patch<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) =>
      _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
}
