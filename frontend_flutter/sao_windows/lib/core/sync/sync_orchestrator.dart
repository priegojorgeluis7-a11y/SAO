import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../catalog/state/catalog_providers.dart';
import '../catalog/sync/catalog_sync_service.dart';
import 'pending_sync_services.dart';

enum SyncOrchestratorStatus { idle, syncing, success, error }

class SyncOrchestratorState {
  const SyncOrchestratorState({
    required this.status,
    this.errorMessage,
    this.updatedAt,
  });

  final SyncOrchestratorStatus status;
  final String? errorMessage;
  final DateTime? updatedAt;

  bool get isSyncing => status == SyncOrchestratorStatus.syncing;

  SyncOrchestratorState copyWith({
    SyncOrchestratorStatus? status,
    String? errorMessage,
    DateTime? updatedAt,
  }) {
    return SyncOrchestratorState(
      status: status ?? this.status,
      errorMessage: errorMessage,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

abstract class CatalogSyncRunner {
  Future<void> ensureCatalogUpToDate(String projectId);
}

class CatalogSyncRunnerImpl implements CatalogSyncRunner {
  CatalogSyncRunnerImpl(this._service);

  final CatalogSyncService _service;

  @override
  Future<void> ensureCatalogUpToDate(String projectId) {
    return _service.ensureCatalogUpToDate(projectId);
  }
}

class SyncOrchestrator extends StateNotifier<SyncOrchestratorState> {
  SyncOrchestrator({
    required CatalogSyncRunner catalogSyncRunner,
    required ActivitySyncService activitySyncService,
    required AssignmentSyncService assignmentSyncService,
    required EvidenceSyncService evidenceSyncService,
  })  : _catalogSyncRunner = catalogSyncRunner,
        _activitySyncService = activitySyncService,
        _assignmentSyncService = assignmentSyncService,
        _evidenceSyncService = evidenceSyncService,
        super(const SyncOrchestratorState(status: SyncOrchestratorStatus.idle));

  final CatalogSyncRunner _catalogSyncRunner;
  final ActivitySyncService _activitySyncService;
  final AssignmentSyncService _assignmentSyncService;
  final EvidenceSyncService _evidenceSyncService;

  bool _isSyncing = false;

  Future<void> syncAll({required String projectId}) async {
    if (_isSyncing) return;
    _isSyncing = true;
    state = const SyncOrchestratorState(status: SyncOrchestratorStatus.syncing);

    try {
      await _catalogSyncRunner.ensureCatalogUpToDate(projectId);
      await _activitySyncService.syncProject(projectId);
      await _assignmentSyncService.syncPending();
      await _evidenceSyncService.syncPending();

      state = SyncOrchestratorState(
        status: SyncOrchestratorStatus.success,
        updatedAt: DateTime.now(),
      );
    } catch (e) {
      state = SyncOrchestratorState(
        status: SyncOrchestratorStatus.error,
        errorMessage: e.toString(),
        updatedAt: DateTime.now(),
      );
    } finally {
      _isSyncing = false;
    }
  }
}

final syncOrchestratorProvider =
    StateNotifierProvider<SyncOrchestrator, SyncOrchestratorState>((ref) {
  return SyncOrchestrator(
    catalogSyncRunner: CatalogSyncRunnerImpl(ref.read(catalogSyncServiceProvider)),
    activitySyncService: ref.read(activitySyncServiceProvider),
    assignmentSyncService: ref.read(assignmentSyncServiceProvider),
    evidenceSyncService: ref.read(evidenceSyncServiceProvider),
  );
});