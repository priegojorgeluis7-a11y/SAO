// lib/data/services/assignment_sync_service.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/utils/logger.dart';
import '../local/app_db.dart';
import '../repositories/assignments_sync_repository.dart';

class AssignmentSyncService {
  final AssignmentsSyncRepository _repository;

  AssignmentSyncService(this._repository);

  /// Execute pending assignment sync
  Future<Map<String, dynamic>> syncAssignments() async {
    try {
      appLogger.i('Starting assignment sync...');
      final result = await _repository.syncPendingAssignments();
      appLogger.i('Assignment sync complete: $result');
      return result;
    } catch (e) {
      appLogger.e('Assignment sync error: $e');
      return {
        'synced': 0,
        'errors': 1,
        'skipped': 0,
        'error': e.toString(),
      };
    }
  }

  /// Get pending assignments
  Future<int> getPendingCount() async {
    final pending = await _repository.getPendingAssignments();
    return pending.length;
  }
}

// Riverpod provider for AssignmentSyncService
final assignmentSyncServiceProvider = Provider((ref) {
  final db = ref.watch(appDbProvider);
  final apiClient = ref.watch(apiClientProvider);
  final repository = AssignmentsSyncRepository(db: db, apiClient: apiClient);
  return AssignmentSyncService(repository);
});

// DAO provider
final assignmentsSyncRepositoryProvider = Provider((ref) {
  final db = ref.watch(appDbProvider);
  final apiClient = ref.watch(apiClientProvider);
  return AssignmentsSyncRepository(db: db, apiClient: apiClient);
});

// Pending count provider (for UI badges)
final pendingAssignmentsCountProvider = FutureProvider((ref) async {
  final service = ref.watch(assignmentSyncServiceProvider);
  return await service.getPendingCount();
});
