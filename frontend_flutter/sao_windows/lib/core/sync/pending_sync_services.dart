import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../di/service_locator.dart';
import '../../features/sync/services/sync_service.dart';
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

class ActivitySyncServiceImpl implements ActivitySyncService {
  ActivitySyncServiceImpl(this._syncService);

  final SyncService _syncService;

  @override
  Future<void> syncProject(String projectId) async {
    try {
      await _syncService.pushPendingChanges();
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      if (statusCode != 403) {
        rethrow;
      }
      // Read-only profiles can fail push with 403 (activity.edit) but still
      // should be able to refresh Home data with pull (activity.view).
    }
    await _syncService.pullChanges(projectId: projectId);
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

class EvidenceSyncServiceNoOp implements EvidenceSyncService {
  @override
  Future<void> syncPending() async {
    // TODO: Integrar sync de evidencias cuando exista coordinator dedicado.
  }
}

final activitySyncServiceProvider = Provider<ActivitySyncService>((ref) {
  return ActivitySyncServiceImpl(getIt<SyncService>());
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
  return EvidenceSyncServiceNoOp();
});