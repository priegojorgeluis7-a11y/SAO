import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;

import '../../core/config/data_mode.dart';
import '../catalog/activity_status.dart';
import '../database/app_database.dart';
import '../models/activity_model.dart';
import 'backend_api_client.dart';

final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return ActivityRepository(db);
});

class ActivityRepository {
  final AppDatabase _db;
  final BackendApiClient _apiClient = const BackendApiClient();

  ActivityRepository(this._db);

  String _requireBackend() => AppDataMode.requireRealBackendUrl();

  Future<List<RejectionPlaybookItem>> getRejectPlaybook({String? projectId}) async {
    _requireBackend();
    final query = (projectId != null && projectId.trim().isNotEmpty)
        ? '?project_id=${Uri.encodeQueryComponent(projectId.trim())}'
        : '';
    final decoded = await _apiClient.getJson('/api/v1/review/reject-playbook$query');
    if (decoded is! Map<String, dynamic>) return const [];
    final items = decoded['items'];
    if (items is! List) return const [];

    return items
        .whereType<Map<String, dynamic>>()
        .map((item) => RejectionPlaybookItem(
              reasonCode: (item['reason_code'] ?? '').toString(),
              label: (item['label'] ?? '').toString(),
              severity: (item['severity'] ?? 'MED').toString(),
              requiresComment: (item['requires_comment'] as bool?) ?? false,
            ))
        .where((item) => item.reasonCode.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> updateEvidenceCaption(String evidenceId, String caption) async {
    _requireBackend();
    await _apiClient.patchJson('/api/v1/review/evidence/$evidenceId', {
      'description': caption,
    });
  }

  Future<List<ActivityTimelineEntry>> getActivityTimeline(String activityId) async {
    _requireBackend();
    final decoded = await _apiClient.getJson('/api/v1/activities/$activityId/timeline');
    if (decoded is! List) return const [];

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

  Future<ActivityWithDetails?> hydrateReviewActivity(ActivityWithDetails summary) async {
    _requireBackend();
    final detail = await _apiClient.getJson('/api/v1/review/activity/${summary.activity.id}');
    final evidencesJson = await _apiClient.getJson('/api/v1/review/activity/${summary.activity.id}/evidences');
    if (detail is! Map<String, dynamic>) {
      return summary;
    }

    final now = DateTime.now();
    final detailTitle = (detail['title'] ?? '').toString().trim();
    final detailDescription = detail['description']?.toString().trim();
    final detailFront = detail['front']?.toString().trim();
    final detailMunicipality = detail['municipality']?.toString().trim();
    final wizardPayloadRaw = detail['wizard_payload'];
    final wizardPayload = wizardPayloadRaw is Map<String, dynamic>
      ? wizardPayloadRaw
      : wizardPayloadRaw is Map
        ? wizardPayloadRaw.cast<String, dynamic>()
        : null;
    final activityTypeCode = (detail['activity_type'] ?? summary.activityType?.code ?? '').toString().trim();
    final qualityFlagsRaw = detail['quality_flags'];
    final qualityFlags = qualityFlagsRaw is Map<String, dynamic>
        ? qualityFlagsRaw
        : qualityFlagsRaw is Map
            ? qualityFlagsRaw.cast<String, dynamic>()
            : const <String, dynamic>{};

    final evidences = _parseReviewEvidences(
      summary.activity.id,
      evidencesJson,
      now,
    );

    return ActivityWithDetails(
      activity: summary.activity.copyWith(
        title: detailTitle.isEmpty ? summary.activity.title : detailTitle,
        description: Value(
          detailDescription?.isNotEmpty == true
              ? detailDescription
              : summary.activity.description,
        ),
      ),
      activityType: ActivityType(
        id: summary.activityType?.id ?? 'act-type-${activityTypeCode.isEmpty ? summary.activity.title : activityTypeCode}',
        name: activityTypeCode.isEmpty ? (summary.activityType?.name ?? summary.activity.title) : activityTypeCode,
        code: activityTypeCode.isEmpty ? (summary.activityType?.code ?? summary.activity.title) : activityTypeCode,
        projectId: summary.activity.projectId,
      ),
      assignedUser: summary.assignedUser,
      front: Front(
        id: summary.front?.id ?? _slugify(detailFront ?? summary.front?.name ?? 'sin-frente'),
        name: detailFront?.isNotEmpty == true ? detailFront! : (summary.front?.name ?? 'Sin frente'),
        projectId: summary.activity.projectId,
      ),
      municipality: Municipality(
        id: summary.municipality?.id ?? _slugify(detailMunicipality ?? summary.municipality?.name ?? 'sin-municipio'),
        name: detailMunicipality?.isNotEmpty == true ? detailMunicipality! : (summary.municipality?.name ?? 'Sin municipio'),
        state: summary.municipality?.state ?? '',
      ),
      evidences: evidences,
      flags: ActivityFlags(
        gpsMismatch: !(qualityFlags['gps_ok'] as bool? ?? !summary.flags.gpsMismatch),
        catalogChanged: !(qualityFlags['catalog_ok'] as bool? ?? !summary.flags.catalogChanged),
        checklistIncomplete: !(qualityFlags['required_fields_ok'] as bool? ?? !summary.flags.checklistIncomplete) ||
            !(qualityFlags['evidence_ok'] as bool? ?? evidences.isNotEmpty),
      ),
      pkLabel: (detail['pk'] as String?)?.trim().isNotEmpty == true
          ? (detail['pk'] as String).trim()
          : summary.pkLabel,
      wizardPayload: wizardPayload,
    );
  }

  Stream<List<ActivityWithDetails>> watchPendingReview({String? projectId}) {
    _requireBackend();
    return Stream.fromFuture(
      _fetchPendingReviewFromBackend(projectId: projectId),
    );
  }

  Future<List<ActivityWithDetails>> _fetchPendingReviewFromBackend({
    String? projectId,
  }) async {
    _requireBackend();
    final selectedProjectId = projectId?.trim() ?? '';
    String normalizeProject(String? value) =>
        (value ?? '').trim().toUpperCase();

    Future<List<dynamic>> fetchItemsForProject(String? pid) async {
      final query = (pid == null || pid.isEmpty)
          ? ''
          : '?project_id=${Uri.encodeQueryComponent(pid)}';
      final decoded = await _apiClient.getJson('/api/v1/review/queue$query');
      if (decoded is! Map<String, dynamic>) return const [];
      final items = decoded['items'];
      if (items is! List) return const [];
      return items;
    }

    var items = await fetchItemsForProject(
      selectedProjectId.isEmpty ? null : selectedProjectId,
    );

    // Strict by project, but tolerant to backend case-sensitive matching.
    if (items.isEmpty && selectedProjectId.isNotEmpty) {
      final lower = selectedProjectId.toLowerCase();
      final upper = selectedProjectId.toUpperCase();
      if (selectedProjectId != lower) {
        items = await fetchItemsForProject(lower);
      }
      if (items.isEmpty && selectedProjectId != upper) {
        items = await fetchItemsForProject(upper);
      }

      // Final strict fallback: fetch all and keep only the selected project.
      // This avoids mixed results while compensating for backend filtering edge cases.
      if (items.isEmpty) {
        final allItems = await fetchItemsForProject(null);
        final selectedNorm = normalizeProject(selectedProjectId);
        items = allItems.where((raw) {
          if (raw is! Map<String, dynamic>) return false;
          return normalizeProject(raw['project_id']?.toString()) == selectedNorm;
        }).toList(growable: false);
      }
    }

    final now = DateTime.now();
    final result = <ActivityWithDetails>[];

    for (final raw in items) {
      if (raw is! Map<String, dynamic>) continue;
      final activityId = (raw['id'] ?? '').toString().trim();
      if (activityId.isEmpty) continue;

      final activityTypeCode = (raw['activity_type'] ?? 'ACT').toString().toUpperCase();
      final statusRaw = (raw['status'] ?? 'PENDIENTE_REVISION').toString();
      final status = switch (statusRaw) {
        'APROBADO' => ActivityStatus.approved,
        'RECHAZADO' => ActivityStatus.rejected,
        _ => ActivityStatus.pendingReview,
      };
      final frontName = (raw['front'] ?? 'Sin frente').toString();
      final municipalityName = (raw['municipality'] ?? 'Sin municipio').toString();
      final evidenceCount = (raw['evidence_count'] as num?)?.toInt() ?? 0;

      final activity = Activity(
        id: activityId,
        projectId: (raw['project_id'] ?? '').toString(),
        activityTypeId: 'act-type-$activityTypeCode',
        assignedTo: (raw['assigned_to_user_id'] ?? 'usr-backend').toString(),
        frontId: null,
        municipalityId: null,
        title: (raw['title'] ?? activityTypeCode).toString(),
        description: (raw['pk'] ?? '').toString(),
        status: status,
        executedAt: DateTime.tryParse((raw['created_at'] ?? '').toString()),
        reviewedAt: DateTime.tryParse((raw['reviewed_at'] ?? '').toString()),
        reviewedBy: raw['reviewed_by']?.toString(),
        reviewComments: raw['review_comments']?.toString(),
        latitude: null,
        longitude: null,
        createdAt: DateTime.tryParse((raw['created_at'] ?? '').toString()) ?? now,
      );

      final evidences = List<Evidence>.generate(
        evidenceCount,
        (index) => Evidence(
          id: 'ev-$activityId-$index',
          activityId: activityId,
          filePath: 'backend://evidence/$activityId/$index',
          fileType: 'IMAGE',
          capturedAt: now,
        ),
      );

      result.add(
        ActivityWithDetails(
          activity: activity,
          activityType: ActivityType(
            id: activity.activityTypeId,
            name: activityTypeCode,
            code: activityTypeCode,
            projectId: activity.projectId,
          ),
          assignedUser: User(
            id: activity.assignedTo,
            email: (raw['assigned_to_user_email'] ?? 'backend@sao.mx').toString(),
            fullName: (raw['assigned_to_user_name'] ?? 'Sin responsable').toString(),
            role: (raw['assigned_to_user_role'] ?? 'OPERATIVO').toString(),
            status: 'ACTIVE',
            createdAt: now,
          ),
          front: Front(
            id: frontName.toLowerCase().replaceAll(' ', '-'),
            name: frontName,
            projectId: activity.projectId,
          ),
          municipality: Municipality(
            id: municipalityName.toLowerCase().replaceAll(' ', '-'),
            name: municipalityName,
            state: (raw['state'] ?? '').toString(),
          ),
          evidences: evidences,
          flags: ActivityFlags(
            gpsMismatch: (raw['gps_critical'] as bool?) ?? false,
            catalogChanged: (raw['catalog_change_pending'] as bool?) ?? false,
            checklistIncomplete: (raw['checklist_incomplete'] as bool?) ?? false,
          ),
          pkLabel: (raw['pk'] as String?)?.trim(),
        ),
      );
    }

    return result;
  }

  Future<ActivityWithDetails?> getActivityById(String id) async {
    _requireBackend();
    final items = await _fetchPendingReviewFromBackend();
    for (final item in items) {
      if (item.activity.id == id) {
        return hydrateReviewActivity(item);
      }
    }
    return null;
  }

  List<Evidence> _parseReviewEvidences(
    String activityId,
    dynamic decoded,
    DateTime fallback,
  ) {
    if (decoded is! List) return const <Evidence>[];

    return decoded
        .whereType<Map<String, dynamic>>()
        .map((raw) {
          final evidenceId = (raw['id'] ?? '').toString().trim();
          if (evidenceId.isEmpty) {
            return null;
          }
          final takenAt = DateTime.tryParse((raw['takenAt'] ?? '').toString()) ?? fallback;
          final gcsKey = (raw['gcsKey'] ?? '').toString().trim();
          final fileType = gcsKey.toLowerCase().endsWith('.pdf') ? 'DOCUMENT' : 'IMAGE';
          return Evidence(
            id: evidenceId,
            activityId: activityId,
            filePath: 'backend://evidence/$evidenceId',
            fileType: fileType,
            caption: raw['description']?.toString(),
            capturedAt: takenAt,
            latitude: (raw['lat'] as num?)?.toDouble(),
            longitude: (raw['lng'] as num?)?.toDouble(),
          );
        })
        .whereType<Evidence>()
        .toList(growable: false);
  }

  String _slugify(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'[^a-z0-9\-]'), '');
  }

  Future<void> approveActivity(String activityId, String reviewerId) async {
    _requireBackend();
    await _apiClient.postJson('/api/v1/review/activity/$activityId/decision', {
      'decision': 'APPROVE',
      'comment': '',
      'field_resolutions': <Map<String, dynamic>>[],
      'apply_to_similar': false,
    });
  }

  Future<void> rejectActivity(
    String activityId,
    String reviewerId,
    String comments,
    [String? rejectReasonCode]
  ) async {
    _requireBackend();
    await _apiClient.postJson('/api/v1/review/activity/$activityId/decision', {
      'decision': 'REJECT',
      'reject_reason_code': (rejectReasonCode ?? 'MISSING_INFO'),
      'comment': comments,
      'field_resolutions': <Map<String, dynamic>>[],
      'apply_to_similar': false,
    });
  }

  Future<void> deleteActivity(String activityId) async {
    _requireBackend();
    await _apiClient.deleteJson('/api/v1/activities/$activityId');
  }

  Future<void> updateActivityFields(
    String activityId, {
    String? title,
    String? description,
    String? activityTypeCode,
  }) async {
    _requireBackend();
    final payload = <String, dynamic>{};
    if (title != null) payload['title'] = title;
    if (description != null) payload['description'] = description;
    if (activityTypeCode != null) payload['activity_type_code'] = activityTypeCode;
    if (payload.isEmpty) return;
    await _apiClient.putJson('/api/v1/activities/$activityId', payload);
  }

  Future<void> markNeedsFixStrictBackend(
    String activityId,
    String comments,
    [String? rejectReasonCode]
  ) async {
    _requireBackend();
    await _apiClient.postJson('/api/v1/review/activity/$activityId/decision', {
      'decision': 'REJECT',
      'reject_reason_code': (rejectReasonCode ?? 'MISSING_INFO'),
      'comment': comments,
      'field_resolutions': <Map<String, dynamic>>[],
      'apply_to_similar': false,
    });
  }

  Future<void> markNeedsFix(
    String activityId,
    String reviewerId,
    String comments,
  ) async {
    await markNeedsFixStrictBackend(activityId, comments, 'MISSING_INFO');
  }

  Future<List<RejectionReason>> getRejectionReasons() async {
    final items = await getRejectPlaybook();
    return items
        .map(
          (item) => RejectionReason(
            id: item.reasonCode,
            reason: item.label,
            isActive: true,
          ),
        )
        .toList(growable: false);
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
