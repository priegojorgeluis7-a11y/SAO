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
    this.limit = 200,
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
  final String? reviewDecision;
  final String? assignedToUserId;
  final String? assignedToUserName;
  final String createdByUserId;
  final String? catalogVersionId;
  final String activityTypeCode;
  final String? latitude;
  final String? longitude;
  final String? title;
  final String? description;
  final Map<String, dynamic>? wizardPayload;
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
    this.reviewDecision,
    this.assignedToUserId,
    this.assignedToUserName,
    required this.createdByUserId,
    required this.catalogVersionId,
    required this.activityTypeCode,
    this.latitude,
    this.longitude,
    this.title,
    this.description,
    this.wizardPayload,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.syncVersion,
  });

  factory ActivityDTO.fromJson(Map<String, dynamic> json) {
    String? asStringOrNull(String key) {
      final v = json[key];
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }

    int asInt(String key, {int fallback = 0}) {
      final v = json[key];
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? fallback;
    }

    DateTime parseDate(String key) {
      final raw = asStringOrNull(key);
      if (raw == null) return DateTime.now().toUtc();
      return DateTime.tryParse(raw)?.toUtc() ?? DateTime.now().toUtc();
    }

    return ActivityDTO(
      uuid: asStringOrNull('uuid') ?? '',
      serverId: json['server_id'] as int?,
      projectId: asStringOrNull('project_id') ?? '',
      frontId: asStringOrNull('front_id'),
      pkStart: asInt('pk_start'),
      pkEnd: json['pk_end'] as int?,
      executionState: asStringOrNull('execution_state') ?? 'PENDIENTE',
      reviewDecision: asStringOrNull('review_decision'),
      assignedToUserId: asStringOrNull('assigned_to_user_id'),
      assignedToUserName: asStringOrNull('assigned_to_user_name'),
      createdByUserId: asStringOrNull('created_by_user_id') ?? '',
      catalogVersionId: asStringOrNull('catalog_version_id'),
      activityTypeCode: asStringOrNull('activity_type_code') ?? 'UNKNOWN',
      latitude: asStringOrNull('latitude'),
      longitude: asStringOrNull('longitude'),
      title: asStringOrNull('title'),
      description: asStringOrNull('description'),
        wizardPayload: json['wizard_payload'] is Map
          ? Map<String, dynamic>.from(json['wizard_payload'] as Map)
          : null,
      createdAt: parseDate('created_at'),
      updatedAt: parseDate('updated_at'),
      deletedAt: asStringOrNull('deleted_at') != null
          ? DateTime.tryParse(asStringOrNull('deleted_at')!)?.toUtc()
          : null,
      syncVersion: asInt('sync_version'),
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
      'review_decision': reviewDecision,
      'assigned_to_user_id': assignedToUserId,
      'created_by_user_id': createdByUserId,
      'catalog_version_id': catalogVersionId,
      'activity_type_code': activityTypeCode,
      'latitude': latitude,
      'longitude': longitude,
      'title': title,
      'description': description,
      if (wizardPayload != null) 'wizard_payload': wizardPayload,
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
  final int? serverId;

  /// sync_version after the operation.
  final int syncVersion;

  const SyncPushResultItem({
    required this.uuid,
    required this.status,
    this.serverId,
    required this.syncVersion,
  });

  factory SyncPushResultItem.fromJson(Map<String, dynamic> json) =>
      SyncPushResultItem(
        uuid: json['uuid'] as String,
        status: json['status'] as String,
        serverId: json['server_id'] as int?,
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
