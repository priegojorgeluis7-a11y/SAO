// lib/data/repositories/assignments_sync_repository.dart
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/network/api_client.dart';
import '../../core/utils/logger.dart';
import '../local/app_db.dart';
import '../local/dao/assignments_sync_dao.dart';

class AssignmentsSyncRepository {
  final ApiClient _apiClient;
  late final AssignmentsSyncDao _dao;

  AssignmentsSyncRepository({
    required AppDb db,
    required ApiClient apiClient,
  }) : _apiClient = apiClient {
    _dao = AssignmentsSyncDao(db);
  }

  /// Create local assignment (COORDINATOR/SUPERVISOR action from mobile)
  Future<String> createLocalAssignment({
    required String projectId,
    required String assigneeUserId,
    required String activityTypeCode,
    required String? title,
    required String? description,
    required String? frontId,
    required String? frontRef,
    required String? estado,
    required String? municipio,
    required String? colonia,
    required int pk,
    required DateTime startAt,
    required DateTime endAt,
    required String risk,
    required double? latitude,
    required double? longitude,
  }) async {
    final id = const Uuid().v4();

    final companion = LocalAssignmentsCompanion(
      id: Value(id),
      projectId: Value(projectId),
      assigneeUserId: Value(assigneeUserId),
      activityTypeCode: Value(activityTypeCode),
      title: Value(title),
      description: Value(description),
      frontId: Value(frontId),
      frontRef: Value(frontRef),
      estado: Value(estado),
      municipio: Value(municipio),
      colonia: Value(colonia),
      pk: Value(pk),
      startAt: Value(startAt),
      endAt: Value(endAt),
      risk: Value(risk),
      latitude: Value(latitude),
      longitude: Value(longitude),
      syncStatus: const Value('READY_TO_SYNC'),
      createdAt: Value(DateTime.now()),
      updatedAt: Value(DateTime.now()),
    );

    await _dao.upsertAssignment(companion);
    appLogger.i('Created local assignment: $id (status=READY_TO_SYNC)');

    return id;
  }

  /// Sync pending assignments to backend
  Future<Map<String, dynamic>> syncPendingAssignments() async {
    final pending = await _dao.getPendingSync();

    if (pending.isEmpty) {
      return {
        'synced': 0,
        'errors': 0,
        'skipped': 0,
      };
    }

    int synced = 0;
    int errors = 0;
    int skipped = 0;

    for (final assignment in pending) {
      try {
        if (assignment.syncRetryCount >= 3) {
          appLogger.w('Skipping assignment ${assignment.id}: retry limit exceeded');
          skipped++;
          continue;
        }

        // Call backend POST /assignments
        final backendResponse = await _apiClient.post<Map<String, dynamic>>(
          '/assignments',
          data: {
            'project_id': assignment.projectId,
            'assignee_user_id': assignment.assigneeUserId,
            'activity_type_code': assignment.activityTypeCode,
            'title': assignment.title,
            'front_id': assignment.frontId,
            'front_ref': assignment.frontRef,
            'estado': assignment.estado,
            'municipio': assignment.municipio,
            'colonia': assignment.colonia,
            'pk': assignment.pk,
            'start_at': assignment.startAt.toIso8601String(),
            'end_at': assignment.endAt.toIso8601String(),
            'risk': assignment.risk,
            'latitude': assignment.latitude,
            'longitude': assignment.longitude,
          },
        );

        final payload = backendResponse.data ?? const <String, dynamic>{};
        final backendActivityId = payload['id'] as String?;
        if (backendActivityId != null && backendActivityId.isNotEmpty) {
          await _dao.markAsSynced(assignment.id, backendActivityId);
          appLogger.i('Synced assignment ${assignment.id} → activity $backendActivityId');
          synced++;
        } else {
          throw Exception('No activity ID in backend response');
        }
      } catch (e) {
        appLogger.e('Error syncing assignment ${assignment.id}: $e');
        await _dao.markAsError(assignment.id, e.toString());
        errors++;
      }
    }

    appLogger.i('Assignment sync complete: synced=$synced, errors=$errors, skipped=$skipped');

    return {
      'synced': synced,
      'errors': errors,
      'skipped': skipped,
    };
  }

  /// Get pending assignments for UI
  Future<List<LocalAssignment>> getPendingAssignments() async {
    return await _dao.getPendingSync();
  }

  /// Get synced assignments for reference
  Future<List<LocalAssignment>> getSyncedAssignments() async {
    return await _dao.getSyncedAssignments();
  }

  /// Cancel assignment (mark as CANCELED)
  Future<void> cancelAssignment(String assignmentId) async {
    final assignment = await _dao.getById(assignmentId);
    if (assignment == null) {
      throw Exception('Assignment not found: $assignmentId');
    }

    if (assignment.syncStatus == 'SYNCED' && assignment.backendActivityId != null) {
      // If already synced to backend, call cancel endpoint
      // (requires POST /activities/{uuid}/cancel on backend)
      try {
        await _apiClient.post<Map<String, dynamic>>(
          '/activities/${assignment.backendActivityId}/cancel',
          data: {'reason': 'Canceled from mobile'},
        );
        appLogger.i('Canceled assignment ${assignment.id} on backend (activity=${assignment.backendActivityId})');
      } catch (e) {
        appLogger.e('Error canceling assignment on backend: $e');
      }
    }

    // Delete locally
    await _dao.deleteAssignment(assignmentId);
    appLogger.i('Deleted assignment: $assignmentId');
  }
}
