// lib/data/local/dao/activity_dao.dart
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants.dart';
import '../app_db.dart';
import '../tables.dart';

part 'activity_dao.g.dart';

const _uuid = Uuid();

class AdminActivityRecord {
  final Activity activity;
  final String? projectCode;
  final String? projectName;
  final String? activityTypeName;
  final String? frente;
  final String? municipio;
  final String? estado;
  final String? assignedToName;
  final int evidenceCount;

  const AdminActivityRecord({
    required this.activity,
    this.projectCode,
    this.projectName,
    this.activityTypeName,
    this.frente,
    this.municipio,
    this.estado,
    this.assignedToName,
    this.evidenceCount = 0,
  });
}

class PendingEvidenceActivityRecord {
  final String activityId;
  final String title;
  final String status;
  final String? projectCode;
  final DateTime createdAt;

  const PendingEvidenceActivityRecord({
    required this.activityId,
    required this.title,
    required this.status,
    required this.createdAt,
    this.projectCode,
  });
}

class ActivityStats {
  final int total;
  final int synced;
  final int readyToSync;
  final int draft;
  final int revisionPendiente;
  final int error;
  final Map<String, int> byProject;
  final Map<String, int> byFrente;
  final Map<String, int> byRisk;
  final Map<String, int> byActivityType;
  final Map<String, int> byTopic;
  final List<ProjectCompletionStat> completionByProject;
  /// Key: 'yyyy-MM-dd', últimos 14 días
  final Map<String, int> byDay;

  const ActivityStats({
    required this.total,
    required this.synced,
    required this.readyToSync,
    required this.draft,
    required this.revisionPendiente,
    required this.error,
    required this.byProject,
    required this.byFrente,
    required this.byRisk,
    required this.byActivityType,
    required this.byTopic,
    required this.completionByProject,
    required this.byDay,
  });

  factory ActivityStats.empty() => const ActivityStats(
        total: 0, synced: 0, readyToSync: 0, draft: 0,
        revisionPendiente: 0, error: 0,
        byProject: {}, byFrente: {}, byRisk: {}, byActivityType: {}, byTopic: {}, completionByProject: [], byDay: {},
      );

  int get completed => synced + readyToSync;
  double get completionRate => total == 0 ? 0 : completed / total;
}

class ProjectCompletionStat {
  final String projectCode;
  final int total;
  final int completed;

  const ProjectCompletionStat({
    required this.projectCode,
    required this.total,
    required this.completed,
  });

  double get completionRate => total == 0 ? 0 : completed / total;
}

class ActivityStatsQuery {
  final String? projectCode;
  final DateTime? fromDate;
  final DateTime? toDate;

  const ActivityStatsQuery({
    this.projectCode,
    this.fromDate,
    this.toDate,
  });
}

class HomeActivityRecord {
  final Activity activity;
  final String? activityTypeName;
  final String? segmentName;
  final String? frontName;
  final String? municipio;
  final String? estado;
  final String? assignedToUserId;
  final String? assignedToName;
  final String? operationalState;
  final String? reviewState;
  final String? nextAction;
  final String? syncState;
  final String? reviewComment;
  final String? reviewRejectReasonCode;
  final bool isUnplanned;

  const HomeActivityRecord({
    required this.activity,
    this.activityTypeName,
    this.segmentName,
    this.frontName,
    this.municipio,
    this.estado,
    this.assignedToUserId,
    this.assignedToName,
    this.operationalState,
    this.reviewState,
    this.nextAction,
    this.syncState,
    this.reviewComment,
    this.reviewRejectReasonCode,
    required this.isUnplanned,
  });
}

@DriftAccessor(tables: [Activities, ActivityFields, ActivityLog, Evidences, SyncQueue])
class ActivityDao extends DatabaseAccessor<AppDb> with _$ActivityDaoMixin {
  ActivityDao(super.db);

  Future<List<Project>> listActiveProjects() {
    return (select(projects)
          ..where((t) => t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.code)]))
        .get();
  }

  Future<List<ProjectSegment>> listActiveSegmentsByProject(String projectCodeOrId) async {
    final projectId = await resolveProjectId(projectCodeOrId);
    return (select(projectSegments)
          ..where((t) => t.projectId.equals(projectId) & t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.segmentName)]))
        .get();
  }

  Future<Activity?> getActivityById(String activityId) {
    return (select(activities)..where((t) => t.id.equals(activityId))).getSingleOrNull();
  }

  Future<String> resolveProjectId(String projectCodeOrId) async {
    final normalized = projectCodeOrId.trim();
    if (normalized.isEmpty) return projectCodeOrId;

    final byId = await (select(projects)..where((t) => t.id.equals(normalized))).getSingleOrNull();
    if (byId != null) return byId.id;

    final byCode = await (select(projects)..where((t) => t.code.equals(normalized))).getSingleOrNull();
    if (byCode != null) return byCode.id;

    return normalized;
  }

  Future<String> resolveActivityTypeId(String activityTypeCodeOrId) async {
    final normalized = activityTypeCodeOrId.trim();
    if (normalized.isEmpty) return activityTypeCodeOrId;

    final byId = await (select(catalogActivityTypes)..where((t) => t.id.equals(normalized))).getSingleOrNull();
    if (byId != null) return byId.id;

    final byCode = await (select(catalogActivityTypes)..where((t) => t.code.equals(normalized))).getSingleOrNull();
    if (byCode != null) return byCode.id;

    return normalized;
  }

  Future<bool> activityExists(String activityId) async {
    final row = await (select(activities)..where((t) => t.id.equals(activityId))).getSingleOrNull();
    return row != null;
  }

  /// Deletes an activity and all its associated fields, log entries, evidences,
  /// and sync queue rows from the local database.
  /// Does NOT communicate with the server.
  Future<void> deleteActivity(String activityId) async {
    await transaction(() async {
      // Delete evidences first (FK → activities.id)
      await (delete(evidences)..where((t) => t.activityId.equals(activityId))).go();
      await (delete(activityFields)..where((t) => t.activityId.equals(activityId))).go();
      await (delete(activityLog)..where((t) => t.activityId.equals(activityId))).go();
      await (delete(syncQueue)..where((t) => t.entityId.equals(activityId))).go();
      await (delete(activities)..where((t) => t.id.equals(activityId))).go();
    });
  }

  Future<Map<String, ActivityField>> getFieldsByKey(String activityId) async {
    var rows = await (select(activityFields)..where((t) => t.activityId.equals(activityId))).get();
    var byKey = {
      for (final row in rows) row.fieldKey: row,
    };

    if (_needsWizardFieldRecovery(byKey)) {
      final recovered = await _recoverMissingWizardFields(
        activityId,
        existingKeys: byKey.keys.toSet(),
        snapshotJson: byKey['wizard_payload_snapshot']?.valueJson,
      );
      if (recovered.isNotEmpty) {
        for (final field in recovered) {
          await into(activityFields).insertOnConflictUpdate(field);
        }
        rows = await (select(activityFields)..where((t) => t.activityId.equals(activityId))).get();
        byKey = {
          for (final row in rows) row.fieldKey: row,
        };
      }
    }

    return byKey;
  }

  bool _needsWizardFieldRecovery(Map<String, ActivityField> fieldsByKey) {
    if (fieldsByKey.isEmpty) return true;

    const criticalKeys = {
      'risk_level',
      'activity_type',
      'result',
      'report_notes',
      'report_agreements',
      'topics',
      'attendees',
      'wizard_payload_snapshot',
    };

    final present = criticalKeys.where(fieldsByKey.containsKey).length;
    return present <= 1;
  }

  Future<List<ActivityFieldsCompanion>> _recoverMissingWizardFields(
    String activityId, {
    required Set<String> existingKeys,
    String? snapshotJson,
  }) async {
    Map<String, dynamic>? wizardPayload = _parseWizardPayload(snapshotJson);
    wizardPayload ??= await _loadWizardPayloadFromSyncQueue(activityId);
    if (wizardPayload == null || wizardPayload.isEmpty) {
      return const [];
    }

    final recovered = <ActivityFieldsCompanion>[];

    void addText(String key, dynamic raw) {
      if (existingKeys.contains(key)) return;
      final value = _normalizePayloadText(raw);
      if (value == null) return;
      recovered.add(ActivityFieldsCompanion.insert(
        id: '$activityId:$key',
        activityId: activityId,
        fieldKey: key,
        valueText: Value(value),
      ));
    }

    void addJson(String key, Object? raw) {
      if (existingKeys.contains(key) || raw == null) return;
      final encoded = jsonEncode(raw);
      if (encoded.trim().isEmpty) return;
      recovered.add(ActivityFieldsCompanion.insert(
        id: '$activityId:$key',
        activityId: activityId,
        fieldKey: key,
        valueJson: Value(encoded),
      ));
    }

    addJson('wizard_payload_snapshot', wizardPayload);
    addText('risk_level', wizardPayload['risk_level']);
    addText('topic_other_text', wizardPayload['topic_other_text']);
    addText('report_notes', wizardPayload['notes']);

    final activityRaw = wizardPayload['activity'];
    if (activityRaw is Map) {
      final activityMap = Map<String, dynamic>.from(activityRaw);
      addText('activity_type', activityMap['id']);
    }

    final subcategoryRaw = wizardPayload['subcategory'];
    if (subcategoryRaw is Map) {
      final subcategoryMap = Map<String, dynamic>.from(subcategoryRaw);
      addText('subcategory', subcategoryMap['id']);
      addText('subcategory_other_text', subcategoryMap['other_text']);
    }

    final purposeRaw = wizardPayload['purpose'];
    if (purposeRaw is Map) {
      final purposeMap = Map<String, dynamic>.from(purposeRaw);
      addText('purpose', purposeMap['id']);
    }

    final resultRaw = wizardPayload['result'];
    if (resultRaw is Map) {
      final resultMap = Map<String, dynamic>.from(resultRaw);
      addText('result', resultMap['id']);
    }

    final topicsRaw = wizardPayload['topics'];
    if (topicsRaw is List) {
      final topicIds = topicsRaw
          .map((item) {
            if (item is Map) {
              final topicMap = Map<String, dynamic>.from(item);
              return _normalizePayloadText(topicMap['id']) ??
                  _normalizePayloadText(topicMap['name']);
            }
            return _normalizePayloadText(item);
          })
          .whereType<String>()
          .toList(growable: false);
      if (topicIds.isNotEmpty) {
        addJson('topics', topicIds);
      }
    }

    final attendeesRaw = wizardPayload['attendees'];
    if (attendeesRaw is List) {
      final attendeeIds = <String>[];
      final representatives = <String, String>{};
      for (final item in attendeesRaw) {
        if (item is Map) {
          final attendeeMap = Map<String, dynamic>.from(item);
          final attendeeId = _normalizePayloadText(attendeeMap['id']) ??
              _normalizePayloadText(attendeeMap['name']);
          if (attendeeId == null) continue;
          attendeeIds.add(attendeeId);
          final representative = _normalizePayloadText(
            attendeeMap['representative_name'],
          );
          if (representative != null) {
            representatives[attendeeId] = representative;
          }
        } else {
          final attendeeId = _normalizePayloadText(item);
          if (attendeeId != null) {
            attendeeIds.add(attendeeId);
          }
        }
      }
      if (attendeeIds.isNotEmpty) {
        addJson('attendees', attendeeIds);
      }
      if (representatives.isNotEmpty) {
        addJson('attendee_representatives', representatives);
      }
    }

    final agreementsRaw = wizardPayload['agreements'];
    if (agreementsRaw is List) {
      final agreements = agreementsRaw
          .map(_normalizePayloadText)
          .whereType<String>()
          .toList(growable: false);
      if (agreements.isNotEmpty) {
        addJson('report_agreements', agreements);
      }
    }

    final locationRaw = wizardPayload['location'];
    if (locationRaw is Map) {
      final locationMap = Map<String, dynamic>.from(locationRaw);
      addText('draft_tipo_ubicacion', locationMap['tipo_ubicacion']);
      addText('draft_pk_inicio', locationMap['pk_inicio']);
      addText('draft_pk_fin', locationMap['pk_fin']);
      addText('front_id', locationMap['front_id']);
      addText('front_name', locationMap['front_name']);
      addText('estado', locationMap['estado']);
      addText('municipio', locationMap['municipio']);
      addText('colonia', locationMap['colonia']);
    }

    final unplannedRaw = wizardPayload['unplanned'];
    if (unplannedRaw is Map) {
      final unplannedMap = Map<String, dynamic>.from(unplannedRaw);
      if (unplannedMap['is_unplanned'] == true) {
        addText('origin', 'unplanned');
      }
      addText('unplanned_reason', unplannedMap['reason']);
      addText('unplanned_reason_other_text', unplannedMap['reason_other_text']);
      addText('unplanned_reference', unplannedMap['reference']);
    }

    return recovered;
  }

  Map<String, dynamic>? _parseWizardPayload(String? rawJson) {
    final raw = rawJson?.trim();
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> _loadWizardPayloadFromSyncQueue(
    String activityId,
  ) async {
    final queueRows = await (select(syncQueue)
          ..where(
            (t) => t.entity.equals('ACTIVITY') & t.entityId.equals(activityId),
          )
          ..orderBy([
            (t) => OrderingTerm.desc(t.lastAttemptAt),
            (t) => OrderingTerm.desc(t.priority),
            (t) => OrderingTerm.desc(t.attempts),
          ]))
        .get();

    for (final row in queueRows) {
      try {
        final decoded = jsonDecode(row.payloadJson);
        if (decoded is! Map) continue;
        final payload = Map<String, dynamic>.from(decoded);
        final rawWizardPayload = payload['wizard_payload'] ?? payload['wizardPayload'];
        if (rawWizardPayload is Map) {
          return Map<String, dynamic>.from(rawWizardPayload);
        }
      } catch (_) {
        // Ignore malformed cached payloads.
      }
    }

    return null;
  }

  String? _normalizePayloadText(dynamic raw) {
    final value = raw?.toString().trim();
    if (value == null || value.isEmpty || value.toLowerCase() == 'null') {
      return null;
    }
    return value;
  }

  Future<List<HomeActivityRecord>> listHomeActivitiesByProject(String projectCodeOrId) async {
    final normalizedProject = projectCodeOrId.trim().toUpperCase();
    late final List<Activity> rows;
    if (normalizedProject == kAllProjects) {
      rows = await (select(activities)
            ..where((t) => t.status.isNotValue('CANCELED'))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();
    } else {
      final projectId = await resolveProjectId(projectCodeOrId);
      rows = await (select(activities)
            ..where((t) => t.projectId.equals(projectId) & t.status.isNotValue('CANCELED'))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();
    }

    if (rows.isEmpty) {
      return const [];
    }

    final segmentIds = rows
        .map((row) => row.segmentId)
        .whereType<String>()
        .where((id) => id.trim().isNotEmpty)
        .toSet()
        .toList();

    final activityTypeIds = rows
        .map((row) => row.activityTypeId)
        .where((id) => id.trim().isNotEmpty)
        .toSet()
        .toList();

    final activityIds = rows.map((row) => row.id).toList();
    final projectIds = rows.map((row) => row.projectId).toSet().toList();

    final assignmentRows = await (select(attachedDatabase.agendaAssignments)
          ..where((t) => t.activityId.isIn(activityIds) | t.id.isIn(activityIds)))
        .get();
    final assignmentByActivityId = <String, AgendaAssignment>{};
    for (final assignment in assignmentRows) {
      final directIds = <String>{
        if (assignment.activityId?.trim().isNotEmpty ?? false) assignment.activityId!.trim(),
        if (assignment.id.trim().isNotEmpty) assignment.id.trim(),
      };
      for (final activityId in directIds) {
        final existing = assignmentByActivityId[activityId];
        if (existing == null || assignment.updatedAt.isAfter(existing.updatedAt)) {
          assignmentByActivityId[activityId] = assignment;
        }
      }
    }

    final assignmentFallbackRows = projectIds.isEmpty
        ? <AgendaAssignment>[]
        : await (select(attachedDatabase.agendaAssignments)
              ..where((t) => t.projectId.isIn(projectIds)))
            .get();
    final assignmentByFingerprint = <String, AgendaAssignment>{};
    final assignmentByPkAndTitle = <String, AgendaAssignment>{};
    for (final assignment in assignmentFallbackRows) {
      final fingerprint = _assignmentFingerprint(
        projectId: assignment.projectId,
        title: assignment.title,
        pk: assignment.pk,
        at: assignment.startAt,
      );
      final existing = assignmentByFingerprint[fingerprint];
      if (existing == null || assignment.updatedAt.isAfter(existing.updatedAt)) {
        assignmentByFingerprint[fingerprint] = assignment;
      }

      final keyByPkAndTitle = _assignmentPkTitleKey(
        projectId: assignment.projectId,
        pk: assignment.pk,
        title: assignment.title,
      );
      if (keyByPkAndTitle != null) {
        final existingByPkAndTitle = assignmentByPkAndTitle[keyByPkAndTitle];
        if (existingByPkAndTitle == null || assignment.updatedAt.isAfter(existingByPkAndTitle.updatedAt)) {
          assignmentByPkAndTitle[keyByPkAndTitle] = assignment;
        }
      }
    }

    final assignedUserIds = <String>{
      ...assignmentByActivityId.values
          .map((row) => _normalizeAssigneeId(row.resourceId))
          .whereType<String>(),
      ...assignmentByFingerprint.values
          .map((row) => _normalizeAssigneeId(row.resourceId))
          .whereType<String>(),
      ...assignmentByPkAndTitle.values
          .map((row) => _normalizeAssigneeId(row.resourceId))
          .whereType<String>(),
    }
        .toSet()
        .toList();

    final segments = segmentIds.isEmpty
        ? <ProjectSegment>[]
        : await (select(projectSegments)..where((t) => t.id.isIn(segmentIds))).get();
    final segmentById = {for (final segment in segments) segment.id: segment};

    final types = activityTypeIds.isEmpty
        ? <CatalogActivityType>[]
        : await (select(catalogActivityTypes)..where((t) => t.id.isIn(activityTypeIds))).get();
    final typeById = {for (final type in types) type.id: type};

    final fieldRows = await (select(activityFields)
          ..where((t) =>
              t.activityId.isIn(activityIds) &
              t.fieldKey.isIn(const [
                'front_name',
                'origin',
                'assignee_user_id',
                'operational_state',
                'review_state',
                'next_action',
                'sync_state',
                'review_comment',
                'review_reject_reason_code',
                'estado',
                'municipio',
              ])))
        .get();

    final frontNameByActivityId = <String, String>{};
    final isUnplannedByActivityId = <String, bool>{};
    final assigneeUserIdByActivityId = <String, String>{};
    final operationalStateByActivityId = <String, String>{};
    final reviewStateByActivityId = <String, String>{};
    final nextActionByActivityId = <String, String>{};
    final syncStateByActivityId = <String, String>{};
    final reviewCommentByActivityId = <String, String>{};
    final reviewRejectReasonCodeByActivityId = <String, String>{};
    final estadoByActivityId = <String, String>{};
    final municipioByActivityId = <String, String>{};

    for (final field in fieldRows) {
      if (field.fieldKey == 'front_name' && (field.valueText?.trim().isNotEmpty ?? false)) {
        frontNameByActivityId[field.activityId] = field.valueText!.trim();
      }
      if (field.fieldKey == 'origin' && field.valueText == 'unplanned') {
        isUnplannedByActivityId[field.activityId] = true;
      }
      if (field.fieldKey == 'assignee_user_id' && (field.valueText?.trim().isNotEmpty ?? false)) {
        assigneeUserIdByActivityId[field.activityId] = field.valueText!.trim();
      }
      if (field.fieldKey == 'operational_state' && (field.valueText?.trim().isNotEmpty ?? false)) {
        operationalStateByActivityId[field.activityId] = field.valueText!.trim().toUpperCase();
      }
      if (field.fieldKey == 'review_state' && (field.valueText?.trim().isNotEmpty ?? false)) {
        reviewStateByActivityId[field.activityId] = field.valueText!.trim().toUpperCase();
      }
      if (field.fieldKey == 'next_action' && (field.valueText?.trim().isNotEmpty ?? false)) {
        nextActionByActivityId[field.activityId] = field.valueText!.trim().toUpperCase();
      }
      if (field.fieldKey == 'sync_state' && (field.valueText?.trim().isNotEmpty ?? false)) {
        syncStateByActivityId[field.activityId] = field.valueText!.trim().toUpperCase();
      }
      if (field.fieldKey == 'review_comment' && (field.valueText?.trim().isNotEmpty ?? false)) {
        reviewCommentByActivityId[field.activityId] = field.valueText!.trim();
      }
      if (field.fieldKey == 'review_reject_reason_code' && (field.valueText?.trim().isNotEmpty ?? false)) {
        reviewRejectReasonCodeByActivityId[field.activityId] = field.valueText!.trim().toUpperCase();
      }
      if (field.fieldKey == 'estado' && (field.valueText?.trim().isNotEmpty ?? false)) {
        estadoByActivityId[field.activityId] = field.valueText!.trim();
      }
      if (field.fieldKey == 'municipio' && (field.valueText?.trim().isNotEmpty ?? false)) {
        municipioByActivityId[field.activityId] = field.valueText!.trim();
      }
    }

    final allAssignedUserIds = <String>{
      ...assignedUserIds,
      ...assigneeUserIdByActivityId.values,
    }.toList();
    final allAssignedUsers = allAssignedUserIds.isEmpty
        ? <User>[]
        : await (select(users)..where((t) => t.id.isIn(allAssignedUserIds))).get();
    final allAssignedUserById = {for (final user in allAssignedUsers) user.id: user};

    return rows
        .map(
          (row) {
            final assignment = assignmentByActivityId[row.id];
            final inferredByFingerprint =
                assignmentByFingerprint[_assignmentFingerprint(
                  projectId: row.projectId,
                  title: row.title,
                  pk: row.pk,
                  at: row.createdAt,
                )];
            final typeNameForMatch = typeById[row.activityTypeId]?.name ?? row.title;
            final inferredByPkAndTitle = assignmentByPkAndTitle[_assignmentPkTitleKey(
              projectId: row.projectId,
              pk: row.pk,
              title: typeNameForMatch,
            )];
            final inferredAssignment = assignment ?? inferredByFingerprint ?? inferredByPkAndTitle;

            final assignedToUserId =
              _normalizeAssigneeId(row.assignedToUserId) ??
              _normalizeAssigneeId(assigneeUserIdByActivityId[row.id]) ??
              _normalizeAssigneeId(inferredAssignment?.resourceId);
            final assignedToName =
                assignedToUserId == null || assignedToUserId.isEmpty
                    ? null
                : allAssignedUserById[assignedToUserId]?.name;

            return HomeActivityRecord(
              activity: row,
              activityTypeName: typeById[row.activityTypeId]?.name,
              segmentName:
                  row.segmentId == null ? null : segmentById[row.segmentId!]?.segmentName,
              frontName: (frontNameByActivityId[row.id]?.trim().isNotEmpty ?? false)
                ? frontNameByActivityId[row.id]!.trim()
                : (inferredAssignment?.frente.trim().isNotEmpty ?? false)
                  ? inferredAssignment!.frente.trim()
                  : null,
              municipio: (inferredAssignment?.municipio.trim().isNotEmpty ?? false)
                ? inferredAssignment!.municipio.trim()
                : municipioByActivityId[row.id],
              estado: (inferredAssignment?.estado.trim().isNotEmpty ?? false)
                ? inferredAssignment!.estado.trim()
                : estadoByActivityId[row.id],
              assignedToUserId: assignedToUserId,
              assignedToName: assignedToName,
              operationalState: operationalStateByActivityId[row.id],
              reviewState: reviewStateByActivityId[row.id],
              nextAction: nextActionByActivityId[row.id],
              syncState: syncStateByActivityId[row.id],
              reviewComment: reviewCommentByActivityId[row.id],
              reviewRejectReasonCode: reviewRejectReasonCodeByActivityId[row.id],
              isUnplanned: isUnplannedByActivityId[row.id] ?? false,
            );
          },
        )
        .toList();
  }

  String _assignmentFingerprint({
    required String projectId,
    required String title,
    required int? pk,
    required DateTime at,
  }) {
    final day = DateTime(at.year, at.month, at.day);
    final normalizedTitle = title.trim().toLowerCase();
    final normalizedPk = pk?.toString() ?? 'none';
    return '${projectId.trim()}|$normalizedTitle|$normalizedPk|${day.toIso8601String()}';
  }

  String? _assignmentPkTitleKey({
    required String projectId,
    required int? pk,
    required String title,
  }) {
    if (pk == null) {
      return null;
    }
    final normalizedTitle = _normalizeActivityTitleForMatch(title);
    if (normalizedTitle.isEmpty) {
      return null;
    }
    return '${projectId.trim()}|$pk|$normalizedTitle';
  }

  String _normalizeActivityTitleForMatch(String rawTitle) {
    final normalized = rawTitle.trim().toUpperCase();
    if (normalized.isEmpty) {
      return '';
    }

    const aliases = <String, String>{
      'CAM': 'CAMINAMIENTO',
      'REU': 'REUNION',
      'INS': 'INSPECCION',
      'SUP': 'SUPERVISION',
    };

    final expanded = aliases[normalized] ?? normalized;
    return expanded
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String? _normalizeAssigneeId(String? rawUserId) {
    final value = rawUserId?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }

    final lowered = value.toLowerCase();
    if (lowered == 'unassigned' || lowered == 'null') {
      return null;
    }

    return value;
  }

  Future<void> upsertDraft({
    required ActivitiesCompanion activity,
    required List<ActivityFieldsCompanion> fields,
  }) async {
    await transaction(() async {
      await into(activities).insertOnConflictUpdate(activity);

      final actId = activity.id.value;
      await (delete(activityFields)..where((t) => t.activityId.equals(actId))).go();
      await batch((b) => b.insertAll(activityFields, fields));

      await into(activityLog).insert(
        ActivityLogCompanion.insert(
          id: _uuid.v4(),
          activityId: actId,
          eventType: 'EDITED',
          at: DateTime.now(),
          userId: activity.createdByUserId.value,
          note: const Value('draft_saved'),
        ),
      );
    });
  }

  Future<void> markReadyToSync({
    required String activityId,
    required String userId,
    required Map<String, dynamic> payload,
    int priority = 50,
  }) async {
    await transaction(() async {
      await (update(activities)..where((t) => t.id.equals(activityId)))
          .write(const ActivitiesCompanion(status: Value('READY_TO_SYNC')));

      await into(activityLog).insert(
        ActivityLogCompanion.insert(
          id: _uuid.v4(),
          activityId: activityId,
          eventType: 'SUBMITTED',
          at: DateTime.now(),
          userId: userId,
          note: const Value('queued_for_sync'),
        ),
      );

      await into(syncQueue).insert(
        SyncQueueCompanion.insert(
          id: _uuid.v4(),
          entity: 'ACTIVITY',
          entityId: activityId,
          action: 'UPSERT',
          payloadJson: jsonEncode(payload),
          priority: Value(priority),
        ),
      );
    });
  }

  Future<void> markActivityStarted({
    required String activityId,
    required DateTime startedAt,
  }) async {
    await (update(activities)..where((t) => t.id.equals(activityId))).write(
      ActivitiesCompanion(
        status: const Value('DRAFT'),
        startedAt: Value(startedAt),
        finishedAt: const Value(null),
      ),
    );
  }

  Future<void> markActivityFinished({
    required String activityId,
    required DateTime finishedAt,
  }) async {
    await (update(activities)..where((t) => t.id.equals(activityId))).write(
      ActivitiesCompanion(
        finishedAt: Value(finishedAt),
      ),
    );
  }

  Future<void> markActivityRevisionPendiente({
    required String activityId,
    required DateTime finishedAt,
  }) async {
    await (update(activities)..where((t) => t.id.equals(activityId))).write(
      ActivitiesCompanion(
        status: const Value('REVISION_PENDIENTE'),
        finishedAt: Value(finishedAt),
      ),
    );
  }

  Future<void> markActivityCaptureIncomplete({
    required String activityId,
    required DateTime startedAt,
  }) async {
    await (update(activities)..where((t) => t.id.equals(activityId))).write(
      ActivitiesCompanion(
        startedAt: Value(startedAt),
      ),
    );
  }

  Future<List<Evidence>> getEvidencesForActivity(String activityId) {
    return (select(evidences)
          ..where((t) => t.activityId.equals(activityId))
          ..orderBy([(t) => OrderingTerm.asc(t.takenAt)]))
        .get();
  }

  // ── Admin Stats ───────────────────────────────────────────────

  Future<ActivityStats> loadActivityStats({ActivityStatsQuery? query}) async {
    final normalizedProject = (query?.projectCode ?? '').trim().toUpperCase();
    final fromDate = query?.fromDate;
    final toDate = query?.toDate;

    final allRows = await (select(activities)
          ..where((t) => t.status.isNotValue('CANCELED')))
        .get();

    if (allRows.isEmpty) {
      return ActivityStats.empty();
    }

    final projectIds = allRows.map((r) => r.projectId).toSet().toList();
    final projectList = projectIds.isEmpty
        ? <Project>[]
        : await (select(projects)..where((t) => t.id.isIn(projectIds))).get();
    final projectCodeById = {for (final p in projectList) p.id: p.code};

    final rows = allRows.where((row) {
      if (normalizedProject.isNotEmpty && normalizedProject != kAllProjects) {
        final code = (projectCodeById[row.projectId] ?? '').trim().toUpperCase();
        if (code != normalizedProject) return false;
      }
      if (fromDate != null && row.createdAt.isBefore(fromDate)) return false;
      if (toDate != null && row.createdAt.isAfter(toDate)) return false;
      return true;
    }).toList();

    if (rows.isEmpty) {
      return ActivityStats.empty();
    }

    final activityIds = rows.map((r) => r.id).toList();
    final activityTypeIds = rows.map((r) => r.activityTypeId).toSet().toList();

    // Activity types
    final typeList = activityTypeIds.isEmpty
        ? <CatalogActivityType>[]
        : await (select(catalogActivityTypes)..where((t) => t.id.isIn(activityTypeIds))).get();
    final typeNameById = {for (final t in typeList) t.id: t.name};

    // Topics
    final relTopicRows = activityIds.isEmpty
        ? <CatRelActivityTopic>[]
        : await (select(attachedDatabase.catRelActivityTopics)
              ..where((t) => t.activityId.isIn(activityIds) & t.isEnabled.equals(true)))
            .get();
    final topicIds = relTopicRows.map((r) => r.topicId).toSet().toList();
    final topicRows = topicIds.isEmpty
        ? <CatTopic>[]
        : await (select(attachedDatabase.catTopics)
              ..where((t) => t.id.isIn(topicIds) & t.isEnabled.equals(true)))
            .get();
    final topicNameById = {for (final t in topicRows) t.id: t.name};

    // Assignments (frente)
    final assignmentRows = await (select(attachedDatabase.agendaAssignments)
          ..where((t) => t.activityId.isIn(activityIds)))
        .get();
    final frenteByActivityId = <String, String>{};
    for (final asgn in assignmentRows) {
      final aid = asgn.activityId?.trim();
      if (aid == null || aid.isEmpty) continue;
      if (!frenteByActivityId.containsKey(aid) && asgn.frente.trim().isNotEmpty) {
        frenteByActivityId[aid] = asgn.frente.trim();
      }
    }

    // Risk from activity_fields
    final riskRows = await (select(activityFields)
          ..where((t) =>
              t.activityId.isIn(activityIds) &
              t.fieldKey.equals('risk_level')))
        .get();
    final riskByActivityId = {
      for (final f in riskRows)
        if (f.valueText?.trim().isNotEmpty ?? false) f.activityId: f.valueText!.trim().toLowerCase(),
    };

    // Aggregate
    int total = 0, synced = 0, readyToSync = 0, draft = 0, revisionPendiente = 0, error = 0;
    final byProject = <String, int>{};
    final byFrente = <String, int>{};
    final byRisk = <String, int>{};
    final byActivityType = <String, int>{};
    final byTopic = <String, int>{};
    final completedByProject = <String, int>{};
    final byDay = <String, int>{};

    final today = DateTime.now();
    final cutoff = DateTime(today.year, today.month, today.day)
        .subtract(const Duration(days: 13)); // últimos 14 días

    for (final row in rows) {
      total++;
      switch (row.status) {
        case 'SYNCED': synced++; break;
        case 'READY_TO_SYNC': readyToSync++; break;
        case 'DRAFT': draft++; break;
        case 'REVISION_PENDIENTE': revisionPendiente++; break;
        case 'ERROR': error++; break;
      }

      final projectCode = projectCodeById[row.projectId] ?? 'Otro';
      byProject[projectCode] = (byProject[projectCode] ?? 0) + 1;
      if (row.status == 'SYNCED' || row.status == 'READY_TO_SYNC') {
        completedByProject[projectCode] = (completedByProject[projectCode] ?? 0) + 1;
      }

      final frente = frenteByActivityId[row.id];
      if (frente != null) {
        byFrente[frente] = (byFrente[frente] ?? 0) + 1;
      }

      final risk = riskByActivityId[row.id];
      if (risk != null) {
        byRisk[risk] = (byRisk[risk] ?? 0) + 1;
      }

      final typeName = typeNameById[row.activityTypeId] ?? 'Otro';
      byActivityType[typeName] = (byActivityType[typeName] ?? 0) + 1;

      final created = DateTime(row.createdAt.year, row.createdAt.month, row.createdAt.day);
      if (!created.isBefore(cutoff)) {
        final key =
            '${created.year.toString().padLeft(4, '0')}-${created.month.toString().padLeft(2, '0')}-${created.day.toString().padLeft(2, '0')}';
        byDay[key] = (byDay[key] ?? 0) + 1;
      }
    }

    for (final rel in relTopicRows) {
      final topicName = (topicNameById[rel.topicId] ?? rel.topicId).trim();
      if (topicName.isEmpty) continue;
      byTopic[topicName] = (byTopic[topicName] ?? 0) + 1;
    }

    final completionByProject = byProject.entries
        .map(
          (entry) => ProjectCompletionStat(
            projectCode: entry.key,
            total: entry.value,
            completed: completedByProject[entry.key] ?? 0,
          ),
        )
        .toList()
      ..sort((a, b) {
        final rateCompare = b.completionRate.compareTo(a.completionRate);
        if (rateCompare != 0) return rateCompare;
        return b.total.compareTo(a.total);
      });

    return ActivityStats(
      total: total,
      synced: synced,
      readyToSync: readyToSync,
      draft: draft,
      revisionPendiente: revisionPendiente,
      error: error,
      byProject: byProject,
      byFrente: byFrente,
      byRisk: byRisk,
      byActivityType: byActivityType,
      byTopic: byTopic,
      completionByProject: completionByProject,
      byDay: byDay,
    );
  }

  Future<List<PendingEvidenceActivityRecord>> listPendingEvidenceActivities({
    int limit = 50,
  }) async {
    final pendingFields = await (select(activityFields)
          ..where((t) =>
              t.fieldKey.equals('evidence_pending') &
              t.valueText.equals('true')))
        .get();

    if (pendingFields.isEmpty) {
      return const [];
    }

    final activityIds = pendingFields
        .map((row) => row.activityId)
        .toSet()
        .toList();

    final activitiesRows = await (select(activities)
          ..where((t) =>
              t.id.isIn(activityIds) &
              t.status.isIn(const ['DRAFT', 'REVISION_PENDIENTE']))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(limit))
        .get();

    if (activitiesRows.isEmpty) {
      return const [];
    }

    final projectIds = activitiesRows.map((row) => row.projectId).toSet().toList();
    final projectsRows = projectIds.isEmpty
        ? <Project>[]
        : await (select(projects)..where((t) => t.id.isIn(projectIds))).get();
    final projectCodeById = {for (final row in projectsRows) row.id: row.code};

    return activitiesRows
        .map(
          (row) => PendingEvidenceActivityRecord(
            activityId: row.id,
            title: row.title,
            status: row.status,
            createdAt: row.createdAt,
            projectCode: projectCodeById[row.projectId],
          ),
        )
        .toList(growable: false);
  }

  // ── Admin History ─────────────────────────────────────────────

  Future<List<AdminActivityRecord>> listAllActivitiesForAdmin() async {
    final rows = await (select(activities)
          ..where((t) => t.status.isNotValue('CANCELED'))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();

    if (rows.isEmpty) return const [];

    final projectIds = rows.map((r) => r.projectId).toSet().toList();
    final activityTypeIds = rows.map((r) => r.activityTypeId).toSet().toList();
    final activityIds = rows.map((r) => r.id).toList();

    final projectList = await (select(projects)..where((t) => t.id.isIn(projectIds))).get();
    final projectById = {for (final p in projectList) p.id: p};

    final typeList = activityTypeIds.isEmpty
        ? <CatalogActivityType>[]
        : await (select(catalogActivityTypes)..where((t) => t.id.isIn(activityTypeIds))).get();
    final typeById = {for (final t in typeList) t.id: t};

    final assignmentRows = await (select(attachedDatabase.agendaAssignments)
          ..where((t) => t.activityId.isIn(activityIds)))
        .get();
    final assignmentByActivityId = <String, AgendaAssignment>{};
    for (final asgn in assignmentRows) {
      final aid = asgn.activityId?.trim();
      if (aid == null || aid.isEmpty) continue;
      final existing = assignmentByActivityId[aid];
      if (existing == null || asgn.updatedAt.isAfter(existing.updatedAt)) {
        assignmentByActivityId[aid] = asgn;
      }
    }

    final fieldRows = await (select(activityFields)
          ..where((t) =>
              t.activityId.isIn(activityIds) &
              t.fieldKey.isIn(const ['front_name', 'assignee_user_id'])))
        .get();
    final frontNameByActivityId = <String, String>{};
    final assigneeUserIdByActivityId = <String, String>{};
    for (final f in fieldRows) {
      if (f.fieldKey == 'front_name' && (f.valueText?.trim().isNotEmpty ?? false)) {
        frontNameByActivityId[f.activityId] = f.valueText!.trim();
      }
      if (f.fieldKey == 'assignee_user_id' && (f.valueText?.trim().isNotEmpty ?? false)) {
        assigneeUserIdByActivityId[f.activityId] = f.valueText!.trim();
      }
    }

    final allUserIds = <String>{
      ...assignmentByActivityId.values.map((a) => a.resourceId.trim()).where((s) => s.isNotEmpty),
      ...assigneeUserIdByActivityId.values,
    }.toList();
    final userList = allUserIds.isEmpty
        ? <User>[]
        : await (select(users)..where((t) => t.id.isIn(allUserIds))).get();
    final userById = {for (final u in userList) u.id: u};

    final evidenceCounts = <String, int>{};
    if (activityIds.isNotEmpty) {
      final evRows = await (select(evidences)
            ..where((t) => t.activityId.isIn(activityIds)))
          .get();
      for (final ev in evRows) {
        evidenceCounts[ev.activityId] = (evidenceCounts[ev.activityId] ?? 0) + 1;
      }
    }

    return rows.map((row) {
      final project = projectById[row.projectId];
      final assignment = assignmentByActivityId[row.id];
      final frente = frontNameByActivityId[row.id] ?? assignment?.frente;
      final municipio = assignment?.municipio;
      final estado = assignment?.estado;
      final assignedToUserId = assigneeUserIdByActivityId[row.id] ?? assignment?.resourceId.trim();
      final assignedToName = (assignedToUserId != null && assignedToUserId.isNotEmpty)
          ? userById[assignedToUserId]?.name
          : null;

      return AdminActivityRecord(
        activity: row,
        projectCode: project?.code,
        projectName: project?.name,
        activityTypeName: typeById[row.activityTypeId]?.name,
        frente: (frente?.trim().isNotEmpty ?? false) ? frente : null,
        municipio: (municipio?.trim().isNotEmpty ?? false) ? municipio : null,
        estado: (estado?.trim().isNotEmpty ?? false) ? estado : null,
        assignedToName: assignedToName,
        evidenceCount: evidenceCounts[row.id] ?? 0,
      );
    }).toList();
  }

  Future<AdminActivityRecord?> getAdminActivityById(String activityId) async {
    final normalized = activityId.trim();
    if (normalized.isEmpty) return null;

    final activity =
        await (select(activities)..where((t) => t.id.equals(normalized))).getSingleOrNull();
    if (activity == null || activity.status == 'CANCELED') return null;

    final project = await (select(projects)
          ..where((t) => t.id.equals(activity.projectId)))
        .getSingleOrNull();
    final type = await (select(catalogActivityTypes)
          ..where((t) => t.id.equals(activity.activityTypeId)))
        .getSingleOrNull();

    final assignment = await (select(attachedDatabase.agendaAssignments)
          ..where((t) => t.activityId.equals(activity.id))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
          ..limit(1))
        .getSingleOrNull();

    final fields = await (select(activityFields)
          ..where((t) =>
              t.activityId.equals(activity.id) &
              t.fieldKey.isIn(const ['front_name', 'assignee_user_id'])))
        .get();

    String? frontName;
    String? assigneeUserId;
    for (final f in fields) {
      if (f.fieldKey == 'front_name' && (f.valueText?.trim().isNotEmpty ?? false)) {
        frontName = f.valueText!.trim();
      }
      if (f.fieldKey == 'assignee_user_id' && (f.valueText?.trim().isNotEmpty ?? false)) {
        assigneeUserId = f.valueText!.trim();
      }
    }

    assigneeUserId ??= assignment?.resourceId.trim();
    User? assignedUser;
    if (assigneeUserId != null && assigneeUserId.isNotEmpty) {
      assignedUser = await (select(users)..where((t) => t.id.equals(assigneeUserId!))).getSingleOrNull();
    }

    final evidenceCount = await (select(evidences)
          ..where((t) => t.activityId.equals(activity.id)))
        .get()
        .then((rows) => rows.length);

    return AdminActivityRecord(
      activity: activity,
      projectCode: project?.code,
      projectName: project?.name,
      activityTypeName: type?.name,
      frente: (frontName?.trim().isNotEmpty ?? false) ? frontName : assignment?.frente,
      municipio: ((assignment?.municipio ?? '').trim().isNotEmpty)
          ? assignment!.municipio.trim()
          : null,
      estado: ((assignment?.estado ?? '').trim().isNotEmpty)
          ? assignment!.estado.trim()
          : null,
      assignedToName: assignedUser?.name,
      evidenceCount: evidenceCount,
    );
  }

  /// Upserts only the activity row without touching activity_fields.
  Future<void> upsertActivityRow(ActivitiesCompanion companion) async {
    await into(activities).insertOnConflictUpdate(companion);
  }

  /// Replaces all activity_fields for an activity (delete then re-insert).
  Future<void> replaceActivityFields(
    String activityId,
    List<ActivityFieldsCompanion> fields,
  ) async {
    await transaction(() async {
      await (delete(activityFields)..where((t) => t.activityId.equals(activityId))).go();
      if (fields.isNotEmpty) {
        await batch((b) => b.insertAll(activityFields, fields));
      }
    });
  }
}
