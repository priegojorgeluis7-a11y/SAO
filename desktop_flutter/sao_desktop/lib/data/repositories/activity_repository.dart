import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/data_mode.dart';
import '../database/app_database.dart';
import '../models/activity_model.dart';
import '../catalog/activity_status.dart';
import 'backend_api_client.dart';
import 'review_decision_outbox.dart';

final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return ActivityRepository(db);
});

class ActivityRepository {
  final AppDatabase _db;
  final BackendApiClient _apiClient = const BackendApiClient();
  final ReviewDecisionOutbox _reviewOutbox = ReviewDecisionOutbox.shared;

  ActivityRepository(this._db);

  Future<List<RejectionPlaybookItem>> getRejectPlaybook({String? projectId}) async {
    final baseUrl = AppDataMode.backendBaseUrl.trim();
    if (baseUrl.isEmpty) {
      return const [
        RejectionPlaybookItem(
          reasonCode: 'PHOTO_BLUR',
          label: 'Foto borrosa',
          severity: 'MED',
          requiresComment: false,
        ),
        RejectionPlaybookItem(
          reasonCode: 'GPS_MISMATCH',
          label: 'GPS no coincide',
          severity: 'HIGH',
          requiresComment: true,
        ),
        RejectionPlaybookItem(
          reasonCode: 'MISSING_INFO',
          label: 'Falta información',
          severity: 'MED',
          requiresComment: true,
        ),
      ];
    }

    final query = (projectId != null && projectId.trim().isNotEmpty)
        ? '?project_id=${Uri.encodeQueryComponent(projectId.trim())}'
        : '';
    final decoded = await _apiClient.getJson('/api/v1/review/reject-playbook$query');
    if (decoded is! Map<String, dynamic>) {
      return const [];
    }

    final items = decoded['items'];
    if (items is! List) {
      return const [];
    }

    return items
        .whereType<Map<String, dynamic>>()
        .map((item) => RejectionPlaybookItem(
              reasonCode: (item['reason_code'] ?? '').toString(),
              label: (item['label'] ?? '').toString(),
              severity: (item['severity'] ?? 'MED').toString(),
              requiresComment: (item['requires_comment'] as bool?) ?? false,
            ))
        .where((item) => item.reasonCode.isNotEmpty)
        .toList();
  }

  Future<void> updateEvidenceCaption(String evidenceId, String caption) async {
    final baseUrl = AppDataMode.backendBaseUrl.trim();
    if (baseUrl.isEmpty) {
      return;
    }
    await _apiClient.patchJson('/api/v1/review/evidence/$evidenceId', {
      'description': caption,
    });
  }

  Future<List<ActivityTimelineEntry>> getActivityTimeline(String activityId) async {
    final baseUrl = AppDataMode.backendBaseUrl.trim();
    if (baseUrl.isEmpty) {
      return const [];
    }

    final decoded = await _apiClient.getJson('/api/v1/activities/$activityId/timeline');
    if (decoded is! List) {
      return const [];
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map((item) {
          final atRaw = item['at']?.toString();
          final at = DateTime.tryParse(atRaw ?? '') ?? DateTime.now();
          final detailsRaw = item['details'];
          final details = detailsRaw is Map<String, dynamic>
              ? detailsRaw
              : detailsRaw is Map
                  ? detailsRaw.cast<String, dynamic>()
                  : null;

          return ActivityTimelineEntry(
            at: at,
            actor: item['actor']?.toString(),
            action: (item['action'] ?? '').toString(),
            details: details,
          );
        })
        .toList(growable: false);
  }

  // Obtener actividades pendientes de revisión
  Stream<List<ActivityWithDetails>> watchPendingReview() {
    return _watchPendingReviewFromBackendOrDb();
  }

  Stream<List<ActivityWithDetails>> _watchPendingReviewFromBackendOrDb() {
    return Stream.fromFuture(_fetchPendingReviewFromBackend()).asyncExpand((backendData) {
      if (backendData != null && backendData.isNotEmpty) {
        return Stream.value(backendData);
      }
      return _watchPendingReviewFromDb();
    });
  }

  Stream<List<ActivityWithDetails>> _watchPendingReviewFromDb() {
    return (_db.select(_db.activities)
          ..where((a) => a.status.equals(ActivityStatus.pendingReview))
          ..orderBy([(a) => OrderingTerm.desc(a.executedAt)]))
        .watch()
        .asyncMap((activities) async {
      final results = <ActivityWithDetails>[];
      for (final activity in activities) {
        final details = await _getActivityDetails(activity);
        results.add(details);
      }
      return results;
    });
  }

  Future<List<ActivityWithDetails>?> _fetchPendingReviewFromBackend() async {
    final baseUrl = AppDataMode.backendBaseUrl.trim();
    if (baseUrl.isEmpty) return null;

    try {
      final decoded = await _apiClient.getJson('/api/v1/review/queue');
      if (decoded is! Map<String, dynamic>) return null;
      final items = decoded['items'];
      if (items is! List) return null;

      final now = DateTime.now();
      final result = <ActivityWithDetails>[];

      for (final item in items) {
        if (item is! Map<String, dynamic>) continue;
        final activityId = item['id']?.toString() ?? '';
        if (activityId.isEmpty) continue;

        final activityTypeCode = (item['activity_type'] ?? 'ACT').toString().toUpperCase();
        final activityTypeName = activityTypeCode;
        final rawStatus = (item['status'] ?? 'PENDIENTE_REVISION').toString();
        final status = switch (rawStatus) {
          'APROBADO' => ActivityStatus.approved,
          'RECHAZADO' => ActivityStatus.rejected,
          _ => ActivityStatus.pendingReview,
        };
        final pkLabel = (item['pk'] ?? '').toString();
        final frontName = (item['front'] ?? 'Sin frente').toString();
        final municipalityName = (item['municipality'] ?? 'Sin municipio').toString();
        final gpsMismatch = (item['gps_critical'] as bool?) ?? false;
        final catalogChanged = (item['catalog_change_pending'] as bool?) ?? false;
        final checklistIncomplete = (item['checklist_incomplete'] as bool?) ?? false;

        final activity = Activity(
          id: activityId,
          projectId: (item['project_id'] ?? 'proj-backend').toString(),
          activityTypeId: 'act-type-$activityTypeCode',
          assignedTo: (item['assignedTo'] ?? 'usr-backend').toString(),
          frontId: null,
          municipalityId: null,
          title: activityTypeName,
          description: pkLabel,
          status: status,
          executedAt: DateTime.tryParse((item['created_at'] ?? '').toString()),
          reviewedAt: DateTime.tryParse((item['reviewedAt'] ?? '').toString()),
          reviewedBy: item['reviewedBy']?.toString(),
          reviewComments: item['reviewComments']?.toString(),
          latitude: null,
          longitude: null,
          createdAt: DateTime.tryParse((item['created_at'] ?? '').toString()) ?? now,
        );

        final type = ActivityType(
          id: activity.activityTypeId,
          name: activityTypeName,
          code: activityTypeCode,
          projectId: activity.projectId,
        );

        final user = User(
          id: activity.assignedTo,
          email: (item['assignedEmail'] ?? 'backend@sao.local').toString(),
          fullName: (item['assignedName'] ?? 'Sin responsable').toString(),
          role: (item['assignedRole'] ?? 'ENGINEER').toString(),
          status: 'ACTIVE',
          createdAt: now,
        );

        final municipality = Municipality(
          id: municipalityName.toLowerCase().replaceAll(' ', '-'),
          name: municipalityName,
          state: (item['state'] ?? 'N/A').toString(),
        );

        final evidences = <Evidence>[];
        final evidenceCount = (item['evidence_count'] as num?)?.toInt() ?? 0;
        for (var index = 0; index < evidenceCount; index++) {
          evidences.add(Evidence(
            id: 'ev-$activityId-$index',
            activityId: activityId,
            filePath: 'backend://evidence/$activityId/$index',
            fileType: 'IMAGE',
            capturedAt: now,
          ));
        }

        result.add(ActivityWithDetails(
          activity: activity,
          activityType: type,
          assignedUser: user,
          front: Front(
            id: frontName.toLowerCase().replaceAll(' ', '-'),
            name: frontName,
            projectId: activity.projectId,
          ),
          municipality: municipality,
          evidences: evidences,
          flags: ActivityFlags(
            gpsMismatch: gpsMismatch,
            catalogChanged: catalogChanged,
            checklistIncomplete: checklistIncomplete,
          ),
        ));
      }

      return result;
    } catch (_) {
      return null;
    }
  }

  // Obtener detalles de una actividad
  Future<ActivityWithDetails> _getActivityDetails(Activity activity) async {
    final actType = await (_db.select(_db.activityTypes)
          ..where((t) => t.id.equals(activity.activityTypeId)))
        .getSingleOrNull();

    final user = await (_db.select(_db.users)
          ..where((u) => u.id.equals(activity.assignedTo)))
        .getSingleOrNull();

    Front? front;
    if (activity.frontId != null) {
      front = await (_db.select(_db.fronts)
            ..where((f) => f.id.equals(activity.frontId!)))
          .getSingleOrNull();
    }

    Municipality? muni;
    if (activity.municipalityId != null) {
      muni = await (_db.select(_db.municipalities)
            ..where((m) => m.id.equals(activity.municipalityId!)))
          .getSingleOrNull();
    }

    final evidences = await (_db.select(_db.evidences)
          ..where((e) => e.activityId.equals(activity.id))
          ..orderBy([(e) => OrderingTerm.asc(e.capturedAt)]))
        .get();

    return ActivityWithDetails(
      activity: activity,
      activityType: actType,
      assignedUser: user,
      front: front,
      municipality: muni,
      evidences: evidences,
      flags: const ActivityFlags(),
    );
  }

  // Obtener actividad por ID con detalles
  Future<ActivityWithDetails?> getActivityById(String id) async {
    final activity = await (_db.select(_db.activities)
          ..where((a) => a.id.equals(id)))
        .getSingleOrNull();

    if (activity == null) return null;

    return _getActivityDetails(activity);
  }

  // Aprobar actividad
  Future<void> approveActivity(String activityId, String reviewerId) async {
    final baseUrl = AppDataMode.backendBaseUrl.trim();
    final path = '/api/v1/review/activity/$activityId/decision';
    final payload = {
      'decision': 'APPROVE',
      'comment': '',
      'field_resolutions': <Map<String, dynamic>>[],
      'apply_to_similar': false,
    };
    if (baseUrl.isNotEmpty) {
      try {
        await _apiClient.postJson(path, payload);
        unawaited(_reviewOutbox.flush());
        return;
      } catch (_) {
        _reviewOutbox.enqueue(path: path, payload: payload);
      }
    }

    await (_db.update(_db.activities)..where((a) => a.id.equals(activityId)))
        .write(ActivitiesCompanion(
      status: const Value(ActivityStatus.approved),
      reviewedAt: Value(DateTime.now()),
      reviewedBy: Value(reviewerId),
    ));

    // Agregar a sync queue
    await _db.into(_db.syncQueue).insert(SyncQueueCompanion.insert(
          id: 'sync-${DateTime.now().millisecondsSinceEpoch}',
          entity: 'ACTIVITY',
          entityId: activityId,
          action: 'UPDATE',
          payloadJson: '{"status":"${ActivityStatus.approved}"}',
          status: 'PENDING',
          createdAt: DateTime.now(),
        ));
  }

  // Rechazar actividad
  Future<void> rejectActivity(
    String activityId,
    String reviewerId,
    String comments,
    [String? rejectReasonCode]
  ) async {
    final baseUrl = AppDataMode.backendBaseUrl.trim();
    final path = '/api/v1/review/activity/$activityId/decision';
    final payload = {
      'decision': 'REJECT',
      'reject_reason_code': (rejectReasonCode ?? 'MISSING_INFO'),
      'comment': comments,
      'field_resolutions': <Map<String, dynamic>>[],
      'apply_to_similar': false,
    };
    if (baseUrl.isNotEmpty) {
      try {
        await _apiClient.postJson(path, payload);
        unawaited(_reviewOutbox.flush());
        return;
      } catch (_) {
        _reviewOutbox.enqueue(path: path, payload: payload);
      }
    }

    await (_db.update(_db.activities)..where((a) => a.id.equals(activityId)))
        .write(ActivitiesCompanion(
      status: const Value(ActivityStatus.rejected),
      reviewedAt: Value(DateTime.now()),
      reviewedBy: Value(reviewerId),
      reviewComments: Value(comments),
    ));

    await _db.into(_db.syncQueue).insert(SyncQueueCompanion.insert(
          id: 'sync-${DateTime.now().millisecondsSinceEpoch}',
          entity: 'ACTIVITY',
          entityId: activityId,
          action: 'UPDATE',
          payloadJson: '{"status":"${ActivityStatus.rejected}","comments":"$comments"}',
          status: 'PENDING',
          createdAt: DateTime.now(),
        ));
  }

  // Marcar como necesita corrección
  Future<void> markNeedsFix(
    String activityId,
    String reviewerId,
    String comments,
  ) async {
    final baseUrl = AppDataMode.backendBaseUrl.trim();
    final path = '/api/v1/review/activity/$activityId/decision';
    final payload = {
      'decision': 'REJECT',
      'reject_reason_code': 'MISSING_INFO',
      'comment': comments,
      'field_resolutions': <Map<String, dynamic>>[],
      'apply_to_similar': false,
    };
    if (baseUrl.isNotEmpty) {
      try {
        await _apiClient.postJson(path, payload);
        unawaited(_reviewOutbox.flush());
        return;
      } catch (_) {
        _reviewOutbox.enqueue(path: path, payload: payload);
      }
    }

    await (_db.update(_db.activities)..where((a) => a.id.equals(activityId)))
        .write(ActivitiesCompanion(
      status: const Value(ActivityStatus.needsFix),
      reviewedAt: Value(DateTime.now()),
      reviewedBy: Value(reviewerId),
      reviewComments: Value(comments),
    ));

    await _db.into(_db.syncQueue).insert(SyncQueueCompanion.insert(
          id: 'sync-${DateTime.now().millisecondsSinceEpoch}',
          entity: 'ACTIVITY',
          entityId: activityId,
          action: 'UPDATE',
          payloadJson: '{"status":"${ActivityStatus.needsFix}","comments":"$comments"}',
          status: 'PENDING',
          createdAt: DateTime.now(),
        ));
  }

  // Obtener motivos de rechazo
  Future<List<RejectionReason>> getRejectionReasons() async {
    return (_db.select(_db.rejectionReasons)
          ..where((r) => r.isActive.equals(true)))
        .get();
  }
}

class RejectionPlaybookItem {
  final String reasonCode;
  final String label;
  final String severity;
  final bool requiresComment;

  const RejectionPlaybookItem({
    required this.reasonCode,
    required this.label,
    required this.severity,
    required this.requiresComment,
  });
}
