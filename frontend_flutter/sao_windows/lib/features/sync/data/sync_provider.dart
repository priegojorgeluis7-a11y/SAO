// lib/features/sync/data/sync_provider.dart
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/local/app_db.dart';
import '../../../core/di/service_locator.dart';
import 'sync_repository.dart';
import '../models/sync_models.dart';
import '../services/sync_service.dart';

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

/// Future provider para última sincronización
final lastSyncTimeProvider = FutureProvider<DateTime?>((ref) {
  final repo = ref.watch(syncRepositoryProvider);
  return repo.getLastSyncTime();
});

/// Provider de configuración de sincronización (placeholder)
final syncConfigProvider = StateProvider<SyncConfig>((ref) {
  return const SyncConfig(
    wifiOnly: true,
    downloadPlanos: false,
    usedSpaceMb: 150,
    availableSpaceMb: 2048,
  );
});

/// Provider de recursos de descarga (placeholder - moverá a backend)
final downloadResourcesProvider = Provider<List<DownloadResource>>((ref) {
  return [
    DownloadResource(
      type: DownloadResourceType.planos,
      name: 'Planos Constructivos',
      sizeMb: 45,
      status: DownloadResourceStatus.upToDate,
      lastUpdatedAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
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

  SyncStateNotifier(this._service, this._repository)
      : super(const AsyncValue.data(null));

  /// Ejecuta el push de todos los items pendientes.
  Future<void> sync() async {
    state = const AsyncValue.loading();
    try {
      final result = await _service.pushPendingChanges();
      state = AsyncValue.data(result);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
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
}

/// Provider del estado del sync push (idle / loading / data / error)
final syncStateProvider =
    StateNotifierProvider<SyncStateNotifier, AsyncValue<SyncResult?>>((ref) {
  final service = ref.watch(syncServiceProvider);
  final repository = ref.watch(syncRepositoryProvider);
  return SyncStateNotifier(service, repository);
});
