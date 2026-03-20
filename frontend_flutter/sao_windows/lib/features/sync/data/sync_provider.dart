// lib/features/sync/data/sync_provider.dart
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/catalog/state/catalog_providers.dart';
import '../../../core/storage/kv_store.dart';
import '../../../data/local/app_db.dart';
import '../../../data/local/dao/activity_dao.dart';
import '../../../core/di/service_locator.dart';
import 'sync_repository.dart';
import '../models/sync_models.dart';
import '../services/sync_service.dart';
import '../../../core/utils/logger.dart';

/// Provider del repositorio de sincronización
final syncRepositoryProvider = Provider<SyncRepository>((ref) {
  final db = getIt<AppDb>();
  return SyncRepository(db);
});

/// Stream provider del estado de salud de sincronización
final syncHealthProvider = StreamProvider<SyncHealth>((ref) {
  final repo = ref.watch(syncRepositoryProvider);
  return repo.watchSyncHealth();
});

/// Stream provider de la cola de subida
final uploadQueueProvider = StreamProvider<List<UploadQueueItem>>((ref) {
  final repo = ref.watch(syncRepositoryProvider);
  return repo.watchUploadQueue();
});

final pendingEvidenceActivitiesProvider =
    FutureProvider<List<PendingEvidenceActivityRecord>>((ref) async {
  final db = getIt<AppDb>();
  final dao = ActivityDao(db);
  return dao.listPendingEvidenceActivities(limit: 100);
});

/// Future provider para última sincronización
final lastSyncTimeProvider = FutureProvider<DateTime?>((ref) {
  final repo = ref.watch(syncRepositoryProvider);
  return repo.getLastSyncTime();
});

/// Provider de configuración de sincronización (placeholder)
final syncConfigProvider = StateProvider<SyncConfig>((ref) {
  return const SyncConfig(
    wifiOnly: true,
    usedSpaceMb: 150,
    availableSpaceMb: 2048,
  );
});

/// Provider de recursos de descarga (placeholder - moverá a backend)
final downloadResourcesProvider = Provider<List<DownloadResource>>((ref) {
  return [
    DownloadResource(
      type: DownloadResourceType.catalogo,
      name: 'Catálogo de Conceptos',
      sizeMb: 12,
      status: DownloadResourceStatus.upToDate,
      lastUpdatedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];
});

// ─────────────────────────────────────────────────────────────────
// Sync Service Providers
// ─────────────────────────────────────────────────────────────────

/// Provider del servicio de sincronización
final syncServiceProvider = Provider<SyncService>((ref) => getIt<SyncService>());

/// StateNotifier que controla la ejecución del sync push.
class SyncStateNotifier extends StateNotifier<AsyncValue<SyncResult?>> {
  final SyncService _service;
  final SyncRepository _repository;
  final KvStore _kv;

  SyncStateNotifier(this._service, this._repository, this._kv)
      : super(const AsyncValue.data(null));

  /// Ejecuta el push de todos los items pendientes, seguido de un pull
  /// para el proyecto activo (si está registrado en KvStore).
  Future<void> sync() async {
    state = const AsyncValue.loading();
    try {
      final result = await _service.pushPendingChanges();
      final projectId = await _kv.getString('selected_project');
      if (projectId != null && projectId.isNotEmpty) {
        try {
          await _service.pullChanges(projectId: projectId);
        } catch (firstPullErr) {
          try {
            // Recovery path: stale/invalid local cursor can trigger 422 in /sync/pull.
            // Retry once from a clean cursor before surfacing an error.
            await _service.pullChanges(
              projectId: projectId,
              resetActivityCursor: true,
            );
          } catch (retryErr) {
            // If the pull endpoint is not yet available in this backend mode
            // (SQL disabled / Firestore migration incomplete), log a warning
            // but do not fail the whole sync cycle — push results are still valid.
            if (_isPullUnavailableError(retryErr)) {
              appLogger.w('Pull skipped — endpoint unavailable in current backend mode: $retryErr');
            } else {
              rethrow;
            }
          }
        }
      }
      state = AsyncValue.data(result);
    } catch (e) {
      state = AsyncValue.data(
        SyncResult(
          pushed: 0,
          created: 0,
          updated: 0,
          unchanged: 0,
          conflicts: 0,
          errors: 1,
          errorMessage: _formatSyncError(e),
          completedAt: DateTime.now(),
        ),
      );
    }
  }

  String _formatSyncError(Object error) {
    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      final responseData = error.response?.data;

      String? detail;
      if (responseData is Map<String, dynamic>) {
        final raw = responseData['detail'];
        if (raw is String && raw.trim().isNotEmpty) {
          detail = raw.trim();
        } else if (raw is List && raw.isNotEmpty) {
          detail = raw
              .map((it) {
                if (it is Map<String, dynamic>) {
                  final msg = (it['msg'] ?? '').toString().trim();
                  final locRaw = it['loc'];
                  final loc = locRaw is List
                      ? locRaw
                          .where((part) => part != null)
                          .map((part) => part.toString())
                          .join('.')
                      : '';
                  if (msg.isNotEmpty && loc.isNotEmpty) {
                    return '$msg ($loc)';
                  }
                  if (msg.isNotEmpty) return msg;
                }
                return it.toString();
              })
              .join('; ');
        }
      }

      if (statusCode == 422) {
        return detail ??
            'El servidor rechazo la sincronizacion (422). Verifica proyecto activo y datos pendientes.';
      }
      if (statusCode != null) {
        return detail ?? 'Error HTTP $statusCode durante la sincronizacion.';
      }
      return 'No fue posible sincronizar por un error de red.';
    }

    final text = error.toString().trim();
    if (text.isEmpty) {
      return 'No fue posible sincronizar. Intenta nuevamente.';
    }
    return text;
  }

  Future<void> resolveConflictUseLocal(String queueItemId) async {
    state = const AsyncValue.loading();
    try {
      final result = await _service.resolveConflictUseLocal(queueItemId);
      state = AsyncValue.data(result);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> resolveConflictUseServer(String queueItemId) async {
    state = const AsyncValue.loading();
    try {
      final row = await _repository.getQueueItem(queueItemId);
      if (row == null) {
        state = AsyncValue.data(SyncResult.empty());
        return;
      }

      final payload = jsonDecode(row.payloadJson) as Map<String, dynamic>;
      final projectId = (payload['project_id'] ?? '').toString();
      if (projectId.isEmpty) {
        throw StateError('project_id no disponible para resolver conflicto');
      }

      await _service.resolveConflictUseServer(
        queueItemId: queueItemId,
        projectId: projectId,
      );
      state = AsyncValue.data(SyncResult.empty());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Returns true when the pull endpoint is temporarily unavailable due to
  /// backend deployment mode constraints (SQL disabled / Firestore migration
  /// incomplete). These are expected transient failures that should not block
  /// the user from seeing push results.
  bool _isPullUnavailableError(Object error) {
    if (error is! DioException) return false;
    final data = error.response?.data;
    String detail = '';
    if (data is Map<String, dynamic>) {
      detail = (data['detail'] ?? '').toString();
    } else if (data != null) {
      detail = data.toString();
    }
    final n = detail.toLowerCase();
    return n.contains('sql database is disabled') ||
        n.contains('sql database is unavailable') ||
        n.contains('sync pull/push is still sql-backed') ||
        n.contains('catalog effective/bundle/editor flows are still sql-backed');
  }
}

/// Provider del estado del sync push (idle / loading / data / error)
final syncStateProvider =
    StateNotifierProvider<SyncStateNotifier, AsyncValue<SyncResult?>>((ref) {
  final service = ref.watch(syncServiceProvider);
  final repository = ref.watch(syncRepositoryProvider);
  final kv = ref.watch(kvStoreProvider);
  return SyncStateNotifier(service, repository, kv);
});
