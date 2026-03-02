// lib/features/sync/data/sync_api_repository.dart
import 'package:get_it/get_it.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/exceptions.dart';
import '../../../core/utils/logger.dart';
import '../models/sync_dto.dart';

/// Repository for sync API operations (Phase 3D)
/// Handles pull/push sync with backend using ApiClient (Phase 3A)
class SyncApiRepository {
  final ApiClient _apiClient;

  SyncApiRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? GetIt.instance<ApiClient>();

  /// Pull activities from server since last sync version
  /// 
  /// [projectId] - Project ID to sync (e.g., "TMQ", "TAP")
  /// [sinceVersion] - Last sync_version client has; server returns activities > this
  /// [limit] - Maximum number of activities to return (default: 500, max: 1000)
  /// [untilVersion] - Optional upper bound for sync_version filtering
  /// 
  /// Returns [SyncPullResponse] with current_version and activities list
  /// Throws [NetworkException], [ApiTimeoutException], [ServerException]
  Future<SyncPullResponse> pullActivities({
    required String projectId,
    int sinceVersion = 0,
    int limit = 500,
    int? untilVersion,
  }) async {
    try {
      appLogger.i(
        '🔽 Sync Pull: project=$projectId, since=$sinceVersion, limit=$limit, until=$untilVersion',
      );

      final request = SyncPullRequest(
        projectId: projectId,
        sinceVersion: sinceVersion,
        limit: limit,
        untilVersion: untilVersion,
      );

      final response = await _apiClient.post<dynamic>(
        '/sync/pull',
        data: request.toJson(),
      );

      final data = Map<String, dynamic>.from(response.data as Map);

      final pullResponse = SyncPullResponse.fromJson(data);

      appLogger.i(
        '✅ Sync Pull Success: currentVersion=${pullResponse.currentVersion}, '
        'activities=${pullResponse.activities.length}',
      );

      // Log activity details
      if (pullResponse.activities.isNotEmpty) {
        appLogger.d('📋 Pulled Activities:');
        for (final activity in pullResponse.activities) {
          appLogger.d(
            '  - ${activity.uuid.substring(0, 8)}: '
            '${activity.activityTypeCode} at PK ${activity.pkStart} '
            '(v${activity.syncVersion}, state: ${activity.executionState})',
          );
        }
      } else {
        appLogger.d('📋 No activities to pull (already up-to-date)');
      }

      return pullResponse;
    } on NetworkException catch (e) {
      appLogger.e('❌ Sync Pull Network Error: ${e.message}');
      rethrow;
    } on ApiTimeoutException catch (e) {
      appLogger.e('⏱️ Sync Pull Timeout: ${e.message}');
      rethrow;
    } on ServerException catch (e) {
      appLogger.e('🔥 Sync Pull Server Error: ${e.message} (${e.statusCode})');
      rethrow;
    } catch (e, stackTrace) {
      appLogger.e('💥 Sync Pull Unknown Error', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Push a batch of activities to the server for a project.
  ///
  /// [projectId] - Project ID (must match activities[*].project_id)
  /// [activities] - List of ActivityDTOs to upsert on the server
  ///
  /// Returns [SyncPushResponse] with per-activity results.
  /// Throws [NetworkException], [ApiTimeoutException], [ServerException]
  Future<SyncPushResponse> pushActivities({
    required String projectId,
    required List<ActivityDTO> activities,
  }) async {
    try {
      appLogger.i(
        '🔼 Sync Push: project=$projectId, activities=${activities.length}',
      );

      final request = SyncPushRequest(
        projectId: projectId,
        activities: activities,
      );

      final response = await _apiClient.post<dynamic>(
        '/sync/push',
        data: request.toJson(),
      );

      final data = Map<String, dynamic>.from(response.data as Map);
      final pushResponse = SyncPushResponse.fromJson(data);

      appLogger.i(
        '✅ Sync Push: created=${pushResponse.createdCount}, '
        'updated=${pushResponse.updatedCount}, '
        'conflicts=${pushResponse.conflictCount}',
      );

      return pushResponse;
    } on NetworkException catch (e) {
      appLogger.e('❌ Sync Push Network Error: ${e.message}');
      rethrow;
    } on ApiTimeoutException catch (e) {
      appLogger.e('⏱️ Sync Push Timeout: ${e.message}');
      rethrow;
    } on ServerException catch (e) {
      appLogger.e('🔥 Sync Push Server Error: ${e.message} (${e.statusCode})');
      rethrow;
    } catch (e, stackTrace) {
      appLogger.e('💥 Sync Push Unknown Error', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Get sync status summary for a project.
  Future<SyncStatus> getSyncStatus(String projectId) async {
    // Placeholder — real implementation reads from local Drift DB
    return const SyncStatus(
      lastSyncVersion: 0,
      lastSyncAt: null,
      pendingPullCount: 0,
      pendingPushCount: 0,
    );
  }
}

/// Sync status summary (placeholder for Phase 3E)
class SyncStatus {
  final int lastSyncVersion;
  final DateTime? lastSyncAt;
  final int pendingPullCount;
  final int pendingPushCount;

  const SyncStatus({
    required this.lastSyncVersion,
    required this.lastSyncAt,
    required this.pendingPullCount,
    required this.pendingPushCount,
  });

  bool get isUpToDate => pendingPullCount == 0 && pendingPushCount == 0;
}
