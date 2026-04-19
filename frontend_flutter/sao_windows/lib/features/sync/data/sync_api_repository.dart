// lib/features/sync/data/sync_api_repository.dart
import 'dart:convert';

import 'package:get_it/get_it.dart';
import '../../../core/network/api_client.dart';
import '../../../data/local/app_db.dart';
import '../../../core/network/exceptions.dart';
import '../../../core/utils/logger.dart';
import '../models/sync_dto.dart';

/// Repository for sync API operations (Phase 3D)
/// Handles pull/push sync with backend using ApiClient (Phase 3A)
class SyncApiRepository {
  final ApiClient _apiClient;
  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );

  SyncApiRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? GetIt.instance<ApiClient>();

  /// Pull activities from server since last sync version
  /// 
  /// [projectId] - Project ID to sync (e.g., "TMQ", "TAP")
  /// [sinceVersion] - Last sync_version client has; server returns activities > this
  /// [limit] - Maximum number of activities to return (default/max: 200)
  /// [untilVersion] - Optional upper bound for sync_version filtering
  /// 
  /// Returns [SyncPullResponse] with current_version and activities list
  /// Throws [NetworkException], [ApiTimeoutException], [ServerException]
  Future<SyncPullResponse> pullActivities({
    required String projectId,
    int sinceVersion = 0,
    String? afterUuid,
    int limit = 200,
    int? untilVersion,
  }) async {
    try {
      final safeLimit = limit.clamp(1, 200).toInt();
      appLogger.i(
        '🔽 Sync Pull: project=$projectId, since=$sinceVersion, after=$afterUuid, limit=$safeLimit, until=$untilVersion',
      );

      final request = SyncPullRequest(
        projectId: projectId,
        sinceVersion: sinceVersion,
        afterUuid: afterUuid,
        limit: safeLimit,
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
        'activities=${pullResponse.activities.length}, hasMore=${pullResponse.hasMore}',
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
    bool forceOverride = false,
  }) async {
    try {
      appLogger.i(
        '🔼 Sync Push: project=$projectId, activities=${activities.length}, forceOverride=$forceOverride',
      );

      final request = SyncPushRequest(
        projectId: projectId,
        forceOverride: forceOverride,
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

  /// Resolve latest catalog version UUID for a project using `/catalog/versions`.
  /// Returns null when the backend does not provide a UUID-like value.
  Future<String?> resolveCatalogVersionUuid({required String projectId}) async {
    final normalized = projectId.trim().toUpperCase();
    if (normalized.isEmpty) return null;

    try {
      final response = await _apiClient.get<dynamic>(
        '/catalog/versions',
        queryParameters: {'project_ids': normalized},
      );

      final payload = response.data;
      if (payload is! Map) return null;

      final rawDigest = payload[normalized] ?? payload[projectId] ?? payload[projectId.trim()];
      if (rawDigest is! Map) return null;

      final candidate = rawDigest['version_id']?.toString().trim();
      if (candidate == null || !_uuidPattern.hasMatch(candidate)) {
        return null;
      }

      return candidate;
    } catch (e) {
      appLogger.w('Could not resolve catalog UUID for project $normalized: $e');
      return null;
    }
  }

  /// Get sync status summary for a project.
  Future<SyncStatus> getSyncStatus(String projectId) async {
    final normalizedProject = projectId.trim().toUpperCase();
    final db = GetIt.instance<AppDb>();

    final state = await (db.select(db.syncState)..where((s) => s.id.equals(1)))
        .getSingleOrNull();
    final pendingRows = await (db.select(db.syncQueue)
          ..where((s) => s.status.isNotIn(const ['DONE'])))
        .get();

    final relevantRows = normalizedProject.isEmpty
        ? pendingRows
        : pendingRows.where((row) => _matchesProject(row, normalizedProject)).toList();

    return SyncStatus(
      lastSyncVersion: _extractLastSyncVersion(state?.lastServerCursor, normalizedProject),
      lastSyncAt: state?.lastSyncAt,
      pendingPullCount: 0,
      pendingPushCount: relevantRows.length,
    );
  }

  bool _matchesProject(SyncQueueData row, String projectId) {
    try {
      final decoded = jsonDecode(row.payloadJson);
      if (decoded is Map) {
        final candidates = <String?>[
          decoded['project_id']?.toString(),
          decoded['projectId']?.toString(),
          decoded['project_code']?.toString(),
          decoded['projectCode']?.toString(),
        ];
        for (final candidate in candidates) {
          if ((candidate ?? '').trim().toUpperCase() == projectId) {
            return true;
          }
        }
      }
    } catch (_) {
      // ignore malformed payloads and fall back below
    }
    return row.entityId.toUpperCase().contains(projectId);
  }

  int _extractLastSyncVersion(String? rawCursor, String projectId) {
    final raw = (rawCursor ?? '').trim();
    if (raw.isEmpty) return 0;

    final legacy = int.tryParse(raw);
    if (legacy != null) return legacy;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return 0;
      }
      final projectCursor = decoded[projectId];
      if (projectCursor is Map<String, dynamic>) {
        return (projectCursor['since_version'] as num?)?.toInt() ?? 0;
      }
      if (projectCursor is num) {
        return projectCursor.toInt();
      }
    } catch (_) {
      return 0;
    }

    return 0;
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
