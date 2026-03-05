import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../network/exceptions.dart';
import 'catalog_providers.dart';
import 'catalog_sync_status.dart';

class CatalogSyncController extends AutoDisposeNotifier<CatalogSyncStatus> {
  bool _isSyncing = false;

  @override
  CatalogSyncStatus build() => const CatalogSyncIdle();

  Future<void> sync(String projectId) async {
    if (_isSyncing) return;
    _isSyncing = true;
    state = const CatalogSyncing();

    try {
      final svc = ref.read(catalogSyncServiceProvider);
      await svc.ensureCatalogUpToDate(projectId);

      final kv = ref.read(kvStoreProvider);
      final versionId = await kv.getString('catalog_version:$projectId') ?? 'unknown';
      state = CatalogReady(versionId);
    } catch (e) {
      // Auth errors (expired session, missing token) must surface as a special
      // state so CatalogBootstrapScreen can call logout() and send the user to
      // the login page cleanly, instead of showing a generic catalog error.
      if (_isAuthError(e)) {
        state = const CatalogSyncError(
          'Tu sesión ha expirado.\nVuelve a iniciar sesión.',
          canRetry: false,
          canUseLocal: false,
          isAuthError: true,
        );
        return;
      }

      final kv = ref.read(kvStoreProvider);
      final existing = await kv.getString('catalog_version:$projectId');
      final msg = _friendlyError(e);
      final canFallbackToLocal = _canUseLocalFallback(e);

      if (existing != null) {
        state = CatalogSyncError(
          '$msg\nUsando catálogo local: $existing',
          canUseLocal: true,
        );
      } else {
        state = CatalogSyncError(
          canFallbackToLocal
              ? '$msg\nPuedes continuar con el catálogo local incluido en la app.'
              : '$msg\nNo hay catálogo local.',
          canRetry: true,
          canUseLocal: canFallbackToLocal,
        );
      }
    } finally {
      _isSyncing = false;
    }
  }

  /// Returns true when the exception indicates a missing or expired session,
  /// as opposed to a network/server/catalog error.
  bool _isAuthError(Object e) {
    if (e is AuthExpiredException) return true;
    if (e is DioException) {
      if (e.error is AuthExpiredException) return true;
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) return true;
    }
    return false;
  }

  bool _canUseLocalFallback(Object e) {
    if (e is DioException) {
      final status = e.response?.statusCode;
      if (status != null && status >= 500) return true;
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return true;
      }
    }

    if (e is ServerException && (e.statusCode == null || e.statusCode! >= 500)) {
      return true;
    }

    return e is NetworkException;
  }

  String _friendlyError(Object e) {
    if (e is DioException) {
      final status = e.response?.statusCode;
      if (status == 404) {
        return 'El catálogo no está configurado en el servidor.\n'
            'Contacta al administrador para publicar el catálogo.';
      }
      if (status == 503) {
        return 'El servicio de catálogo no está disponible (migraciones pendientes).\n'
            'Contacta al administrador.';
      }
      if (status == 500) {
        return 'El servidor devolvió error interno al cargar catálogos.';
      }
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return 'Sin conexión al servidor. Verifica tu red.';
      }
    }
    if (e is ServerException) {
      if (e.statusCode == 404) {
        return 'El catálogo no está configurado en el servidor.\n'
            'Contacta al administrador para publicar el catálogo.';
      }
      if (e.statusCode == 503) {
        return 'El servicio de catálogo no está disponible (migraciones pendientes).\n'
            'Contacta al administrador.';
      }
      if (e.statusCode == 500) {
        return 'El servidor devolvió error interno al cargar catálogos.';
      }
    }
    if (e is NetworkException) {
      return 'Sin conexión al servidor. Verifica tu red.';
    }
    return 'No se pudo sincronizar el catálogo.';
  }
}

final catalogSyncControllerProvider = AutoDisposeNotifierProvider<
    CatalogSyncController, CatalogSyncStatus>(
  CatalogSyncController.new,
);
