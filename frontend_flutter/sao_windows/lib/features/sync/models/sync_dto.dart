// lib/features/sync/models/sync_dto.dart

/// DTOs for sync pull/push operations
library;


/// Request schema for sync pull operation
class SyncPullRequest {
  final String projectId;
  final int sinceVersion;
  final String? afterUuid;
  final int? untilVersion;
  final int limit;

  const SyncPullRequest({
    required this.projectId,
    this.sinceVersion = 0,
    this.afterUuid,
    this.untilVersion,
    this.limit = 500,
  });

  Map<String, dynamic> toJson() {
    return {
      'project_id': projectId,
      'since_version': sinceVersion,
      if (afterUuid != null) 'after_uuid': afterUuid,
      if (untilVersion != null) 'until_version': untilVersion,
      'limit': limit,
    };
  }
}

/// Response schema for sync pull operation
class SyncPullResponse {
  final int currentVersion;
  final bool hasMore;
  final int? nextSinceVersion;
  final String? nextAfterUuid;
  final List<ActivityDTO> activities;

  const SyncPullResponse({
    required this.currentVersion,
    required this.hasMore,
    required this.nextSinceVersion,
    required this.nextAfterUuid,
    required this.activities,
  });

  factory SyncPullResponse.fromJson(Map<String, dynamic> json) {
    return SyncPullResponse(
      currentVersion: json['current_version'] as int,
      hasMore: (json['has_more'] as bool?) ?? false,
      nextSinceVersion: json['next_since_version'] as int?,
      nextAfterUuid: json['next_after_uuid'] as String?,
      activities: (json['activities'] as List<dynamic>)
          .map((a) => ActivityDTO.fromJson(a as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Activity DTO for sync operations (matches backend ActivityDTO)
class ActivityDTO {
  final String uuid;
  final int? serverId;
  final String projectId;
  final String? frontId;
  final int pkStart;
  final int? pkEnd;
  final String executionState;
  final String? assignedToUserId;
  final String createdByUserId;
  final String catalogVersionId;
  final String activityTypeCode;
  final String? latitude;
  final String? longitude;
  final String? title;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int syncVersion;

  const ActivityDTO({
    required this.uuid,
    this.serverId,
    required this.projectId,
    this.frontId,
    required this.pkStart,
    this.pkEnd,
    required this.executionState,
    this.assignedToUserId,
    required this.createdByUserId,
    required this.catalogVersionId,
    required this.activityTypeCode,
    this.latitude,
    this.longitude,
    this.title,
    this.description,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.syncVersion,
  });

  factory ActivityDTO.fromJson(Map<String, dynamic> json) {
    return ActivityDTO(
      uuid: json['uuid'] as String,
      serverId: json['server_id'] as int?,
      projectId: json['project_id'] as String,
      frontId: json['front_id'] as String?,
      pkStart: json['pk_start'] as int,
      pkEnd: json['pk_end'] as int?,
      executionState: json['execution_state'] as String,
      assignedToUserId: json['assigned_to_user_id'] as String?,
      createdByUserId: json['created_by_user_id'] as String,
      catalogVersionId: json['catalog_version_id'] as String,
      activityTypeCode: json['activity_type_code'] as String,
      latitude: json['latitude'] as String?,
      longitude: json['longitude'] as String?,
      title: json['title'] as String?,
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'] as String)
          : null,
      syncVersion: json['sync_version'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'server_id': serverId,
      'project_id': projectId,
      'front_id': frontId,
      'pk_start': pkStart,
      'pk_end': pkEnd,
      'execution_state': executionState,
      'assigned_to_user_id': assignedToUserId,
      'created_by_user_id': createdByUserId,
      'catalog_version_id': catalogVersionId,
      'activity_type_code': activityTypeCode,
      'latitude': latitude,
      'longitude': longitude,
      'title': title,
      'description': description,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
      'sync_version': syncVersion,
    };
  }
}

// ─────────────────────────────────────────────────────────────────
// Sync Push DTOs
// ─────────────────────────────────────────────────────────────────

/// Request schema for sync push operation.
/// [project_id] must match all activities in the batch.
class SyncPushRequest {
  final String projectId;
  final bool forceOverride;
  final List<ActivityDTO> activities;

  const SyncPushRequest({
    required this.projectId,
    this.forceOverride = false,
    required this.activities,
  });

  Map<String, dynamic> toJson() => {
        'project_id': projectId,
        'force_override': forceOverride,
        'activities': activities.map((a) => a.toJson()).toList(),
      };
}

/// Result for a single pushed activity.
class SyncPushResultItem {
  /// UUID of the activity (echoed back by server).
  final String uuid;

  /// CREATED | UPDATED | UNCHANGED | CONFLICT
  final String status;

  /// Server-assigned integer ID.
  final int serverId;

  /// sync_version after the operation.
  final int syncVersion;

  const SyncPushResultItem({
    required this.uuid,
    required this.status,
    required this.serverId,
    required this.syncVersion,
  });

  factory SyncPushResultItem.fromJson(Map<String, dynamic> json) =>
      SyncPushResultItem(
        uuid: json['uuid'] as String,
        status: json['status'] as String,
        serverId: json['server_id'] as int,
        syncVersion: json['sync_version'] as int,
      );

  bool get isSuccess =>
      status == 'CREATED' || status == 'UPDATED' || status == 'UNCHANGED';
  bool get isConflict => status == 'CONFLICT';
}

/// Response schema for sync push operation.
class SyncPushResponse {
  final List<SyncPushResultItem> results;

  const SyncPushResponse({required this.results});

  factory SyncPushResponse.fromJson(Map<String, dynamic> json) =>
      SyncPushResponse(
        results: (json['results'] as List<dynamic>)
            .map((r) => SyncPushResultItem.fromJson(r as Map<String, dynamic>))
            .toList(),
      );

  int get createdCount => results.where((r) => r.status == 'CREATED').length;
  int get updatedCount => results.where((r) => r.status == 'UPDATED').length;
  int get conflictCount => results.where((r) => r.isConflict).length;
}
