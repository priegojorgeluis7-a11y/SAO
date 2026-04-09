import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../di/service_locator.dart';
import '../../features/sync/services/sync_service.dart';
import '../../features/evidence/data/evidence_upload_retry_worker.dart';
import '../../features/agenda/data/assignments_repository.dart' as agenda;
import '../../features/agenda/data/assignments_dao.dart';
import '../../core/network/api_client.dart';
import '../../data/local/app_db.dart';

abstract class ActivitySyncService {
  Future<void> syncProject(String projectId);
}

abstract class AssignmentSyncService {
  Future<void> syncPending();
}

abstract class EvidenceSyncService {
  Future<void> syncPending();
}

typedef CursorGapRecoveryDecider = Future<bool> Function({
  required String projectId,
  required int currentVersion,
  required int pulled,
});

abstract class ActivitySyncRunner {
  Future<SyncResult> pushPendingChanges({
    bool forceOverride = false,
    Set<String>? queueItemIds,
  });

  Future<PullSyncResult> pullChanges({
    required String projectId,
    int pageSize = 200,
    bool resetActivityCursor = false,
  });
}

class SyncServiceActivitySyncRunner implements ActivitySyncRunner {
  SyncServiceActivitySyncRunner(this._syncService);

  final SyncService _syncService;

  @override
  Future<SyncResult> pushPendingChanges({
    bool forceOverride = false,
    Set<String>? queueItemIds,
  }) {
    return _syncService.pushPendingChanges(
      forceOverride: forceOverride,
      queueItemIds: queueItemIds,
    );
  }

  @override
  Future<PullSyncResult> pullChanges({
    required String projectId,
    int pageSize = 200,
    bool resetActivityCursor = false,
  }) {
    return _syncService.pullChanges(
      projectId: projectId,
      pageSize: pageSize,
      resetActivityCursor: resetActivityCursor,
    );
  }
}

class ActivitySyncServiceImpl implements ActivitySyncService {
  ActivitySyncServiceImpl(
    this._syncRunner, {
    AppDb? db,
    CursorGapRecoveryDecider? shouldRecoverCursorGap,
  })  : _db = db,
        _shouldRecoverCursorGapOverride = shouldRecoverCursorGap;

  final ActivitySyncRunner _syncRunner;
  final AppDb? _db;
  final CursorGapRecoveryDecider? _shouldRecoverCursorGapOverride;

  @override
  Future<void> syncProject(String projectId) async {
    try {
      await _syncRunner.pushPendingChanges();
    } on DioException {
      // Pull must still run so Home/Historial can receive remote review-state
      // changes even when the upload queue fails or the profile is read-only.
    } catch (_) {
      // Keep background refresh resilient to transient push-side failures.
    }

    PullSyncResult pullResult;
    try {
      pullResult = await _syncRunner.pullChanges(projectId: projectId);
    } on DioException catch (e) {
      if (e.response?.statusCode == 422) {
        await _syncRunner.pullChanges(
          projectId: projectId,
          resetActivityCursor: true,
        );
        return;
      }
      rethrow;
    }

    if (await _shouldRecoverCursorGap(
      projectId: projectId,
      currentVersion: pullResult.currentVersion,
      pulled: pullResult.pulled,
    )) {
      await _syncRunner.pullChanges(
        projectId: projectId,
        resetActivityCursor: true,
      );
    }
  }

  Future<bool> _shouldRecoverCursorGap({
    required String projectId,
    required int currentVersion,
    required int pulled,
  }) async {
    if (_shouldRecoverCursorGapOverride != null) {
      return _shouldRecoverCursorGapOverride!(
        projectId: projectId,
        currentVersion: currentVersion,
        pulled: pulled,
      );
    }

    if (_db == null || pulled > 0 || currentVersion <= 0) {
      return false;
    }

    final minServerRevision = currentVersion - 1;
    final existing = await ((_db!.select(_db!.activities)
          ..where(
            (a) =>
                a.projectId.equals(projectId.trim().toUpperCase()) &
                a.serverRevision.isBiggerThanValue(minServerRevision),
          )
          ..limit(1))
        .getSingleOrNull());

    return existing == null;
  }
}

class AssignmentSyncServiceNoOp implements AssignmentSyncService {
  @override
  Future<void> syncPending() async {
    // TODO: Integrar sync de assignments cuando exista API/queue dedicada.
  }
}

class AssignmentSyncServiceImpl implements AssignmentSyncService {
  AssignmentSyncServiceImpl(this._repository);

  final agenda.AssignmentsRepository _repository;

  @override
  Future<void> syncPending() async {
    try {
      await _repository.syncPending();
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      if (statusCode == 404 || statusCode == 403) {
        // Some deployments/roles do not expose assignments sync endpoints.
        // Keep sync orchestration healthy instead of surfacing a hard failure.
        return;
      }
      rethrow;
    }
  }
}

class EvidenceSyncServiceImpl implements EvidenceSyncService {
  EvidenceSyncServiceImpl(this._worker);

  final EvidenceUploadRetryWorker _worker;

  @override
  Future<void> syncPending() async {
    await _worker.processDueUploads(ignoreRetrySchedule: true);
  }
}

final activitySyncServiceProvider = Provider<ActivitySyncService>((ref) {
  return ActivitySyncServiceImpl(
    SyncServiceActivitySyncRunner(getIt<SyncService>()),
    db: getIt<AppDb>(),
  );
});

final assignmentSyncServiceProvider = Provider<AssignmentSyncService>((ref) {
  final repository = agenda.AssignmentsRepository(
    apiClient: getIt<ApiClient>(),
    localStore: AssignmentsDao(getIt<AppDb>()),
    database: getIt<AppDb>(),
  );
  return AssignmentSyncServiceImpl(repository);
});

final evidenceSyncServiceProvider = Provider<EvidenceSyncService>((ref) {
  return EvidenceSyncServiceImpl(getIt<EvidenceUploadRetryWorker>());
});
