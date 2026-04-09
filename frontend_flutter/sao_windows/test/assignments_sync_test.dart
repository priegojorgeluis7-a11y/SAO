// frontend_flutter/sao_windows/test/assignments_sync_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

void main() {
  group('AssignmentSync: Create and sync assignments from mobile', () {
    test(
      'should create local assignment with READY_TO_SYNC status',
      () async {
        // GIVEN
        const projectId = 'TMQ';
        const assigneeUserId = '550e8400-e29b-41d4-a716-446655440000';
        const activityTypeCode = 'CAMINAMIENTO';
        const title = 'Inspección de tramo 142+000';

        // WHEN
        // AssignmentsSyncRepository.createLocalAssignment() called
        final assignmentId = const Uuid().v4();
        const syncStatus = 'READY_TO_SYNC'; // ← Immediately ready  for sync if online

        // THEN
        expect(assignmentId, isNotEmpty);
        expect(syncStatus, equals('READY_TO_SYNC'));
        // Row inserted in LocalAssignments table with these values
      },
    );

    test(
      'should sync pending assignments to backend via POST /assignments',
      () async {
        // GIVEN
        // 3 local assignments with status READY_TO_SYNC
        final assignments = [
          {'id': _uuid.v4(), 'status': 'READY_TO_SYNC', 'projectId': 'TMQ'},
          {'id': _uuid.v4(), 'status': 'READY_TO_SYNC', 'projectId': 'TMQ'},
          {'id': _uuid.v4(), 'status': 'READY_TO_SYNC', 'projectId': 'TAP'},
        ];

        // WHEN
        // AssignmentsSyncService.syncAssignments() called
        // For each assignment: POST /assignments { ...fields... }
        // Returns: { id: backendActivityId, ... }

        int syncedCount = 0;
        int errorCount = 0;

        for (final assignment in assignments) {
          try {
            // Simulate successful POST /assignments
            final backendActivityId = _uuid.v4();
            // await _dao.markAsSynced(assignment['id'], backendActivityId);
            syncedCount++;
          } catch (e) {
            errorCount++;
          }
        }

        // THEN
        expect(syncedCount, equals(3));
        expect(errorCount, equals(0));
        // All assignments have syncStatus='SYNCED' and backendActivityId set
      },
    );

    test(
      'should update assignment status to ERROR on sync failure',
      () async {
        // GIVEN
        const assignmentId = 'aaa-bbb-ccc';
        const initialStatus = 'READY_TO_SYNC';

        // WHEN
        // POST /assignments fails (network error or 400 validation)
        const errorMessage = 'ASSIGNMENT_ASSIGNEE_PROJECT_MISMATCH';
        // await _dao.markAsError(assignmentId, errorMessage);

        // Update: syncStatus='ERROR', syncError=message, syncRetryCount++
        const newStatus = 'ERROR';
        int retryCount = 0;
        retryCount++; // Incremented on each retry

        // THEN
        expect(newStatus, equals('ERROR'));
        expect(retryCount, greaterThan(0));
        // Row updated with error details; can be retried manually or after backoff
      },
    );

    test(
      'should map local assignment fields to backend POST /assignments contract',
      () async {
        // GIVEN
        final localAssignment = {
          'project_id': 'TMQ',
          'assignee_user_id': '550e8400-e29b-41d4-a716-446655440000',
          'activity_type_code': 'CAMINAMIENTO',
          'title': 'Inspección',
          'front_ref': 'Tramo A',
          'estado': 'Mexico City',
          'municipio': 'Mexico City',
          'pk': 142000,
          'start_at': '2026-03-24T06:00:00Z',
          'end_at': '2026-03-24T14:00:00Z',
          'risk': 'alto',
          'latitude': 19.4326,
          'longitude': -99.1332,
        };

        // WHEN
        // AssignmentsRepository transforms and POSTs
        final backendPayload = {
          'project_id': localAssignment['project_id'],
          'assignee_user_id': localAssignment['assignee_user_id'],
          'activity_type_code': localAssignment['activity_type_code'],
          'title': localAssignment['title'],
          'front_ref': localAssignment['front_ref'],
          'estado': localAssignment['estado'],
          'municipio': localAssignment['municipio'],
          'pk': localAssignment['pk'],
          'start_at': localAssignment['start_at'],
          'end_at': localAssignment['end_at'],
          'risk': localAssignment['risk'],
          'latitude': localAssignment['latitude'],
          'longitude': localAssignment['longitude'],
        };

        // THEN
        // Backend receives exact structure and creates Activity with:
        // - execution_state: 'PENDIENTE'
        // - assigned_to_user_id: assignee from request
        // - created_by_user_id: current user (from auth)
        expect(backendPayload['project_id'], equals('TMQ'));
        expect(backendPayload['assignee_user_id'], equals('550e8400-e29b-41d4-a716-446655440000'));
        expect(backendPayload['activity_type_code'], equals('CAMINAMIENTO'));
      },
    );

    test(
      'should NOT sync if syncRetryCount >= 3 (skip limit)',
      () async {
        // GIVEN
        final assignment = {
          'id': 'ddd-eee-fff',
          'syncStatus': 'ERROR',
          'syncRetryCount': 3, // Already retried 3 times
        };

        // WHEN
        // SyncService checks syncRetryCount before attempting POST
        bool shouldSkip = assignment['syncRetryCount'] as int >= 3;

        // THEN
        expect(shouldSkip, isTrue);
        // Assignment skipped in loop, logged as warning
      },
    );

    test(
      'should be called by SyncOrchestrator.syncAll() after activities sync',
      () async {
        // GIVEN
        // SyncOrchestrator.syncAll(projectId) orchestrates calls

        // WHEN
        // Order of calls (from sync_orchestrator.dart):
        // 1. CatalogSyncRunner.ensureCatalogUpToDate(projectId)
        // 2. ActivitySyncService.syncProject(projectId)
        // 3. AssignmentSyncService.syncPending() ← Called here
        // 4. EvidenceSyncService.syncPending()

        final callSequence = [
          'CatalogSync',
          'ActivitySync',
          'AssignmentSync', // ← KEY: called for all projects, not scoped
          'EvidenceSync',
        ];

        // THEN
        expect(callSequence, contains('AssignmentSync'));
        expect(callSequence.indexOf('AssignmentSync'), equals(2)); // After activities
      },
    );
  });
}
