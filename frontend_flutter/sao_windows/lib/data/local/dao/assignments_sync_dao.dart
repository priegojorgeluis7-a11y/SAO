// lib/data/local/dao/assignments_sync_dao.dart
import 'package:drift/drift.dart';

import '../app_db.dart';
import '../tables.dart';

part 'assignments_sync_dao.g.dart';

@DriftAccessor(tables: [LocalAssignments])
class AssignmentsSyncDao extends DatabaseAccessor<AppDb> with _$AssignmentsSyncDaoMixin {
  AssignmentsSyncDao(super.db);

  /// Get all assignments ready to sync
  Future<List<LocalAssignment>> getPendingSync() {
    return (select(localAssignments)
          ..where((t) => t.syncStatus.isIn(const ['DRAFT', 'READY_TO_SYNC', 'ERROR']))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  /// Insert or update local assignment
  Future<void> upsertAssignment(LocalAssignmentsCompanion assignment) {
    return into(localAssignments).insertOnConflictUpdate(assignment);
  }

  /// Mark assignment as synced
  Future<void> markAsSynced(String assignmentId, String backendActivityId) {
    return (update(localAssignments)
          ..where((t) => t.id.equals(assignmentId)))
        .write(
      LocalAssignmentsCompanion(
        syncStatus: const Value('SYNCED'),
        backendActivityId: Value(backendActivityId),
        syncedAt: Value(DateTime.now()),
        syncRetryCount: const Value(0),
      ),
    );
  }

  /// Mark assignment as syncing error
  Future<void> markAsError(String assignmentId, String error) {
    return transaction(() async {
      final existing = await getById(assignmentId);
      final nextRetryCount = (existing?.syncRetryCount ?? 0) + 1;

      await (update(localAssignments)
            ..where((t) => t.id.equals(assignmentId)))
          .write(
        LocalAssignmentsCompanion(
          syncStatus: const Value('ERROR'),
          syncError: Value(error),
          syncRetryCount: Value(nextRetryCount),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  /// Get assignment by ID
  Future<LocalAssignment?> getById(String id) {
    return (select(localAssignments)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Get all synced assignments (for reference)
  Future<List<LocalAssignment>> getSyncedAssignments() {
    return (select(localAssignments)
          ..where((t) => t.syncStatus.equals('SYNCED'))
          ..orderBy([(t) => OrderingTerm.desc(t.syncedAt)]))
        .get();
  }

  /// Delete assignment
  Future<void> deleteAssignment(String assignmentId) {
    return (delete(localAssignments)..where((t) => t.id.equals(assignmentId))).go();
  }
}
