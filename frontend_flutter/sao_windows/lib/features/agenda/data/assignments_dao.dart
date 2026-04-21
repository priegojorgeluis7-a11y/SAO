import 'package:drift/drift.dart' as drift;

import '../../../core/flow/activity_flow_projection.dart';
import '../../../data/local/app_db.dart';
import '../models/agenda_item.dart';

class AgendaAssignmentRecord {
  const AgendaAssignmentRecord({
    required this.id,
    required this.projectId,
    required this.resourceId,
    this.resourceName,
    this.activityId,
    required this.title,
    required this.frente,
    required this.municipio,
    required this.estado,
    this.pk,
    this.latitude,
    this.longitude,
    required this.startAt,
    required this.endAt,
    required this.risk,
    required this.syncStatus,
  });

  final String id;
  final String projectId;
  final String resourceId;
  final String? resourceName;
  final String? activityId;
  final String title;
  final String frente;
  final String municipio;
  final String estado;
  final int? pk;
  final double? latitude;
  final double? longitude;
  final DateTime startAt;
  final DateTime endAt;
  final RiskLevel risk;
  final SyncStatus syncStatus;
}

abstract class AssignmentsLocalStore {
  Future<List<AgendaItem>> queryRange({
    required String projectId,
    required DateTime from,
    required DateTime to,
  });

  Future<void> upsertAssignments(List<AgendaAssignmentRecord> records);

  Future<void> replaceSyncedInRange({
    required String projectId,
    required DateTime from,
    required DateTime to,
    required List<AgendaAssignmentRecord> records,
  });

  Future<List<AgendaItem>> listPending({String? projectId});

  Future<void> updateSyncStatus(String id, SyncStatus status);

  Future<void> deleteById(String id);
}

class AssignmentsDao implements AssignmentsLocalStore {
  AssignmentsDao(this._db);

  final AppDb _db;

  @override
  Future<List<AgendaItem>> queryRange({
    required String projectId,
    required DateTime from,
    required DateTime to,
  }) async {
    final rows =
        await (_db.select(_db.agendaAssignments)
              ..where(
                (t) =>
                    t.projectId.equals(projectId) &
                    t.startAt.isSmallerThanValue(to) &
                    t.endAt.isBiggerThanValue(from),
              )
              ..orderBy([(t) => drift.OrderingTerm.asc(t.startAt)]))
            .get();

    final activityById = await _loadActivitiesForAssignments(rows);
    final canonicalFlowByActivityId = await _loadCanonicalFlowByActivityId(
      rows,
      activityById,
    );
    final assigneeByActivityId = await _loadAssigneeByActivityId(
      rows,
      activityById,
    );

    return rows
        .map(
          (row) => _toAgendaItem(
            row,
            activityById,
            canonicalFlowByActivityId,
            assigneeByActivityId,
          ),
        )
        .toList();
  }

  @override
  Future<void> upsertAssignments(List<AgendaAssignmentRecord> records) async {
    if (records.isEmpty) return;

    await _db.batch((batch) {
      for (final record in records) {
        batch.insert(
          _db.agendaAssignments,
          AgendaAssignmentsCompanion.insert(
            id: record.id,
            projectId: record.projectId,
            resourceId: record.resourceId,
            activityId: drift.Value(record.activityId),
            title: record.title,
            frente: drift.Value(record.frente),
            municipio: drift.Value(record.municipio),
            estado: drift.Value(record.estado),
            pk: drift.Value(record.pk),
            startAt: record.startAt,
            endAt: record.endAt,
            risk: drift.Value(_riskToString(record.risk)),
            syncStatus: drift.Value(_syncStatusToString(record.syncStatus)),
            updatedAt: drift.Value(DateTime.now()),
          ),
          mode: drift.InsertMode.insertOrReplace,
        );
      }
    });
  }

  @override
  Future<void> replaceSyncedInRange({
    required String projectId,
    required DateTime from,
    required DateTime to,
    required List<AgendaAssignmentRecord> records,
  }) async {
    await _db.transaction(() async {
      final assignmentsInRange =
          await (_db.select(_db.agendaAssignments)..where(
                (t) =>
                    t.projectId.equals(projectId) &
                    t.startAt.isSmallerThanValue(to) &
                    t.endAt.isBiggerThanValue(from) &
                    (t.syncStatus.equals('synced') |
                        t.syncStatus.equals('uploading') |
                        t.syncStatus.equals('error')),
              ))
              .get();

      final activityByLookupKey = await _loadActivitiesForAssignments(
        assignmentsInRange,
      );
      final canonicalFlowByActivityId = await _loadCanonicalFlowByActivityId(
        assignmentsInRange,
        activityByLookupKey,
      );
      final assignmentIdsToDelete = <String>{};

      for (final assignment in assignmentsInRange) {
        final lookupKey = _effectiveActivityId(assignment);
        final activity =
            activityByLookupKey[lookupKey] ??
            activityByLookupKey[assignment.id.trim()];
        final canonicalFlow =
            canonicalFlowByActivityId[lookupKey] ??
            canonicalFlowByActivityId[assignment.id.trim()] ??
            const <String, String>{};

        // Never delete assignments that were attempted but never confirmed by
        // the backend (error/uploading with no linked activity). These should
        // remain visible and be retried on the next sync cycle.
        if (activity == null) {
          final s = (assignment.syncStatus).trim().toLowerCase();
          if (s == 'error' || s == 'uploading') {
            continue;
          }
        }

        // Preserve items with real local progress or closed review outcomes
        // even if the server omits them temporarily.
        if (!_shouldPreserveLocalAgendaState(activity, canonicalFlow)) {
          assignmentIdsToDelete.add(assignment.id);
        }
      }

      if (assignmentIdsToDelete.isNotEmpty) {
        await (_db.delete(
          _db.agendaAssignments,
        )..where((t) => t.id.isIn(assignmentIdsToDelete.toList()))).go();
      }

      if (records.isNotEmpty) {
        await upsertAssignments(records);
      }
    });
  }

  @override
  Future<List<AgendaItem>> listPending({String? projectId}) async {
    final query = _db.select(_db.agendaAssignments)
      ..where(
        (t) => t.syncStatus.equals('pending') | t.syncStatus.equals('error'),
      )
      ..orderBy([(t) => drift.OrderingTerm.asc(t.startAt)]);

    if (projectId != null && projectId.trim().isNotEmpty) {
      query.where((t) => t.projectId.equals(projectId.trim()));
    }

    final rows = await query.get();
    final activityById = await _loadActivitiesForAssignments(rows);
    final canonicalFlowByActivityId = await _loadCanonicalFlowByActivityId(
      rows,
      activityById,
    );
    final assigneeByActivityId = await _loadAssigneeByActivityId(
      rows,
      activityById,
    );
    return rows
        .map(
          (row) => _toAgendaItem(
            row,
            activityById,
            canonicalFlowByActivityId,
            assigneeByActivityId,
          ),
        )
        .toList();
  }

  Future<Map<String, Map<String, String>>> _loadCanonicalFlowByActivityId(
    List<AgendaAssignment> rows,
    Map<String, Activity> activityById,
  ) async {
    final ids = activityById.values
        .map((row) => row.id)
        .where((id) => id.trim().isNotEmpty)
        .toSet()
        .toList();
    if (ids.isEmpty) {
      return const <String, Map<String, String>>{};
    }

    final flowRows =
        await (_db.select(_db.activityFields)..where(
              (t) =>
                  t.activityId.isIn(ids) &
                  t.fieldKey.isIn(const [
                    'operational_state',
                    'review_state',
                    'next_action',
                  ]),
            ))
            .get();

    final byActualActivity = <String, Map<String, String>>{};
    for (final row in flowRows) {
      final value = row.valueText?.trim().toUpperCase();
      if (value == null || value.isEmpty) continue;
      final bucket = byActualActivity.putIfAbsent(
        row.activityId,
        () => <String, String>{},
      );
      bucket[row.fieldKey] = value;
    }

    final byLookupKey = <String, Map<String, String>>{};
    for (final row in rows) {
      final lookupKeys = <String>{
        row.id.trim(),
        if (row.activityId?.trim().isNotEmpty ?? false) row.activityId!.trim(),
      };
      for (final lookupKey in lookupKeys) {
        final activity = activityById[lookupKey];
        if (activity == null) continue;
        final flow = byActualActivity[activity.id];
        if (flow == null) continue;
        byLookupKey[lookupKey] = flow;
      }
    }

    return byLookupKey;
  }

  Future<Map<String, String>> _loadAssigneeByActivityId(
    List<AgendaAssignment> rows,
    Map<String, Activity> activityById,
  ) async {
    final ids = activityById.values.map((row) => row.id).toSet().toList();
    if (ids.isEmpty) {
      return const <String, String>{};
    }

    final byActualActivity = <String, String>{};
    for (final activity in activityById.values) {
      final directAssignee =
          _normalizeAgendaResourceId(activity.assignedToUserId) ??
          _normalizeAgendaResourceId(activity.createdByUserId);
      if (directAssignee != null) {
        byActualActivity[activity.id] = directAssignee;
      }
    }

    final fieldRows =
        await (_db.select(_db.activityFields)..where(
              (t) =>
                  t.activityId.isIn(ids) &
                  t.fieldKey.equals('assignee_user_id'),
            ))
            .get();
    for (final row in fieldRows) {
      final assignee = _normalizeAgendaResourceId(row.valueText);
      if (assignee != null) {
        byActualActivity[row.activityId] = assignee;
      }
    }

    final byLookupKey = <String, String>{};
    for (final row in rows) {
      final lookupKeys = <String>{
        row.id.trim(),
        if (row.activityId?.trim().isNotEmpty ?? false) row.activityId!.trim(),
      };
      for (final lookupKey in lookupKeys) {
        final activity = activityById[lookupKey];
        if (activity == null) continue;
        final assignee = byActualActivity[activity.id];
        if (assignee == null) continue;
        byLookupKey[lookupKey] = assignee;
      }
    }

    return byLookupKey;
  }

  Future<Map<String, Activity>> _loadActivitiesForAssignments(
    List<AgendaAssignment> rows,
  ) async {
    final byLookupKey = <String, Activity>{};
    for (final row in rows) {
      final activity = await _resolveActivityForAssignment(row);
      if (activity == null) continue;

      final assignmentId = row.id.trim();
      if (assignmentId.isNotEmpty) {
        byLookupKey[assignmentId] = activity;
      }

      final activityId = row.activityId?.trim();
      if (activityId != null && activityId.isNotEmpty) {
        byLookupKey[activityId] = activity;
      }
    }
    return byLookupKey;
  }

  AgendaItem _toAgendaItem(
    AgendaAssignment row,
    Map<String, Activity> activityById,
    Map<String, Map<String, String>> canonicalFlowByActivityId,
    Map<String, String> assigneeByActivityId,
  ) {
    final activityId = _effectiveActivityId(row);
    final activity = activityById[activityId] ?? activityById[row.id.trim()];
    final canonicalFlow =
        canonicalFlowByActivityId[activityId] ??
        canonicalFlowByActivityId[row.id.trim()] ??
        const <String, String>{};
    final effectiveResourceId =
        _normalizeAgendaResourceId(row.resourceId) ??
        assigneeByActivityId[activityId] ??
        assigneeByActivityId[row.id.trim()] ??
        _normalizeAgendaResourceId(activity?.assignedToUserId) ??
        _normalizeAgendaResourceId(activity?.createdByUserId) ??
        row.resourceId.trim();
    final assignmentSyncStatus = _syncStatusFromString(row.syncStatus);
    final flow = deriveLocalActivityFlowProjection(
      localStatus: activity?.status ?? 'SYNCED',
      startedAt: activity?.startedAt,
      finishedAt: activity?.finishedAt,
      syncLifecycle: activity != null
          ? syncLifecycleFromLocalStatus(activity.status)
          : _syncLifecycleFromAssignmentStatus(assignmentSyncStatus),
    );
    final preferLocalFlow =
        activity != null &&
        activity.status.trim().toUpperCase() != 'SYNCED' &&
        !hasAuthoritativeCanonicalReviewFlow(
          reviewState: canonicalFlow['review_state'],
          nextAction: canonicalFlow['next_action'],
        );
    final operationalState = _validatedOperationalState(
      preferLocalFlow
          ? flow.operationalState
          : canonicalFlow['operational_state'] ?? flow.operationalState,
    );
    final reviewState = _validatedReviewState(
      preferLocalFlow
          ? flow.reviewState
          : canonicalFlow['review_state'] ?? flow.reviewState,
    );
    final nextAction = _validatedNextAction(
      preferLocalFlow
          ? flow.nextAction
          : canonicalFlow['next_action'] ?? flow.nextAction,
    );

    return AgendaItem(
      id: row.id,
      resourceId: effectiveResourceId,
      title: row.title,
      activityId: row.activityId,
      projectCode: row.projectId,
      frente: row.frente,
      municipio: row.municipio,
      estado: row.estado,
      pk: row.pk,
      start: row.startAt,
      end: row.endAt,
      risk: _riskFromString(row.risk),
      syncStatus: assignmentSyncStatus,
      operationalState: operationalState,
      reviewState: reviewState,
      nextAction: nextAction,
    );
  }

  String _validatedOperationalState(String state) {
    const valid = <String>{
      'PENDIENTE',
      'EN_CURSO',
      'POR_COMPLETAR',
      'BLOQUEADA',
      'CANCELADA',
    };
    return valid.contains(state) ? state : 'PENDIENTE';
  }

  String _validatedReviewState(String state) {
    const valid = <String>{
      'NOT_APPLICABLE',
      'PENDING_REVIEW',
      'CHANGES_REQUIRED',
      'APPROVED',
      'REJECTED',
    };
    return valid.contains(state) ? state : 'NOT_APPLICABLE';
  }

  String _validatedNextAction(String action) {
    const valid = <String>{
      'INICIAR_ACTIVIDAD',
      'TERMINAR_ACTIVIDAD',
      'COMPLETAR_WIZARD',
      'CORREGIR_Y_REENVIAR',
      'ESPERAR_DECISION_COORDINACION',
      'REVISAR_ERROR_SYNC',
      'SINCRONIZAR_PENDIENTE',
      'CERRADA_CANCELADA',
      'CERRADA_RECHAZADA',
      'CERRADA_APROBADA',
      'SIN_ACCION',
    };
    return valid.contains(action) ? action : 'SIN_ACCION';
  }

  String _effectiveActivityId(AgendaAssignment row) {
    final activityId = row.activityId?.trim();
    if (activityId != null && activityId.isNotEmpty) {
      return activityId;
    }
    return row.id;
  }

  String? _normalizeAgendaResourceId(String? rawValue) {
    final value = rawValue?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }

    final lowered = value.toLowerCase();
    if (lowered == 'unassigned' || lowered == 'unknown' || lowered == 'null') {
      return null;
    }
    return value;
  }

  bool _shouldPreserveLocalAgendaState(
    Activity? activity,
    Map<String, String> canonicalFlow,
  ) {
    if (activity == null) {
      return false;
    }

    final normalizedStatus = activity.status.trim().toUpperCase();
    final normalizedReviewState =
        (canonicalFlow['review_state'] ?? '').trim().toUpperCase();
    final normalizedNextAction =
        (canonicalFlow['next_action'] ?? '').trim().toUpperCase();

    if (normalizedStatus == 'CANCELED') {
      return false;
    }

    if (normalizedReviewState == 'APPROVED' ||
        normalizedNextAction == 'CERRADA_APROBADA') {
      return true;
    }

    // Preserve only actionable local work when the backend temporarily omits an
    // assignment, plus explicit closed review outcomes already decided.
    if (normalizedStatus == 'REVISION_PENDIENTE' ||
        normalizedStatus == 'READY_TO_SYNC' ||
        normalizedStatus == 'RECHAZADA' ||
        normalizedStatus == 'ERROR') {
      return true;
    }

    return activity.startedAt != null && activity.finishedAt == null;
  }

  Future<Activity?> _resolveActivityForAssignment(AgendaAssignment row) async {
    final activityId = row.activityId?.trim();
    if (activityId != null && activityId.isNotEmpty) {
      final existingByActivityId = await (_db.select(
        _db.activities,
      )..where((t) => t.id.equals(activityId))).getSingleOrNull();
      if (existingByActivityId != null) {
        return existingByActivityId;
      }
    }

    final assignmentId = row.id.trim();
    if (assignmentId.isNotEmpty) {
      final existingByAssignmentId = await (_db.select(
        _db.activities,
      )..where((t) => t.id.equals(assignmentId))).getSingleOrNull();
      if (existingByAssignmentId != null) {
        return existingByAssignmentId;
      }
    }

    final projectId = row.projectId.trim();
    if (projectId.isEmpty || row.pk == null) {
      return null;
    }

    final candidates =
        await (_db.select(_db.activities)
              ..where(
                (t) => t.projectId.equals(projectId) & t.pk.equals(row.pk!),
              )
              ..orderBy([(t) => drift.OrderingTerm.desc(t.createdAt)]))
            .get();
    if (candidates.isEmpty) {
      return null;
    }

    final targetTitle = _normalizeActivityTitleForMatch(row.title);
    if (targetTitle.isNotEmpty) {
      for (final candidate in candidates) {
        final candidateTitle = _normalizeActivityTitleForMatch(candidate.title);
        if (candidateTitle == targetTitle) {
          return candidate;
        }

        final type =
            await (_db.select(_db.catalogActivityTypes)
                  ..where((t) => t.id.equals(candidate.activityTypeId)))
                .getSingleOrNull();
        final typeName = _normalizeActivityTitleForMatch(type?.name ?? '');
        final typeCode = _normalizeActivityTitleForMatch(type?.code ?? '');
        if (typeName == targetTitle || typeCode == targetTitle) {
          return candidate;
        }
      }
    }

    return candidates.first;
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

  String _syncLifecycleFromAssignmentStatus(SyncStatus status) {
    switch (status) {
      case SyncStatus.pending:
        return 'READY_TO_SYNC';
      case SyncStatus.uploading:
        return 'SYNC_IN_PROGRESS';
      case SyncStatus.synced:
        return 'SYNCED';
      case SyncStatus.error:
        return 'SYNC_ERROR';
    }
  }

  @override
  Future<void> updateSyncStatus(String id, SyncStatus status) async {
    await (_db.update(
      _db.agendaAssignments,
    )..where((t) => t.id.equals(id))).write(
      AgendaAssignmentsCompanion(
        syncStatus: drift.Value(_syncStatusToString(status)),
        updatedAt: drift.Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> deleteById(String id) async {
    await (_db.delete(
      _db.agendaAssignments,
    )..where((t) => t.id.equals(id))).go();
  }

  static RiskLevel _riskFromString(String value) {
    switch (value.toLowerCase()) {
      case 'medio':
        return RiskLevel.medio;
      case 'alto':
        return RiskLevel.alto;
      case 'prioritario':
        return RiskLevel.prioritario;
      default:
        return RiskLevel.bajo;
    }
  }

  static SyncStatus _syncStatusFromString(String value) {
    switch (value.toLowerCase()) {
      case 'uploading':
        return SyncStatus.uploading;
      case 'synced':
        return SyncStatus.synced;
      case 'error':
        return SyncStatus.error;
      default:
        return SyncStatus.pending;
    }
  }

  static String _riskToString(RiskLevel value) {
    switch (value) {
      case RiskLevel.medio:
        return 'medio';
      case RiskLevel.alto:
        return 'alto';
      case RiskLevel.prioritario:
        return 'prioritario';
      case RiskLevel.bajo:
        return 'bajo';
    }
  }

  static String _syncStatusToString(SyncStatus value) {
    switch (value) {
      case SyncStatus.uploading:
        return 'uploading';
      case SyncStatus.synced:
        return 'synced';
      case SyncStatus.error:
        return 'error';
      case SyncStatus.pending:
        return 'pending';
    }
  }
}
