import 'package:dio/dio.dart';
import 'package:drift/drift.dart' as drift;

import '../../../core/network/api_client.dart';
import '../../../core/utils/logger.dart';
import '../../../data/local/app_db.dart';
import '../models/agenda_item.dart';
import 'assignments_dao.dart';

typedef FetchAssignments = Future<dynamic> Function({
  required String projectId,
  required DateTime from,
  required DateTime to,
});

class AssignmentsRepository {
  AssignmentsRepository({
    ApiClient? apiClient,
    required AssignmentsLocalStore localStore,
    required AppDb database,
    FetchAssignments? fetchAssignments,
  })  : assert(apiClient != null || fetchAssignments != null,
            'apiClient or fetchAssignments must be provided'),
      _apiClient = apiClient,
        _localStore = localStore,
        _database = database,
        _fetchAssignments =
            fetchAssignments ?? _defaultFetchAssignments(apiClient!);

    final ApiClient? _apiClient;
  final AssignmentsLocalStore _localStore;
  final AppDb _database;
  final FetchAssignments _fetchAssignments;

  Future<void> saveLocal(AgendaItem item) async {
    final record = AgendaAssignmentRecord(
      id: item.id,
      projectId: item.projectCode.trim(),
      resourceId: item.resourceId,
      resourceName: null,
      activityId: item.activityId,
      title: item.title,
      frente: item.frente,
      municipio: item.municipio,
      estado: item.estado,
      pk: item.pk,
      startAt: item.start,
      endAt: item.end,
      risk: item.risk,
      syncStatus: SyncStatus.pending,
    );
    await _localStore.upsertAssignments([record]);
    await _upsertActivitiesFromAssignments([record]);
  }

  /// Elimina una asignación del almacenamiento local por id.
  Future<void> deleteLocal(String id) async {
    await _localStore.deleteById(id);
  }

  Future<void> syncPending({String? projectId}) async {
    final pending = await _localStore.listPending(projectId: projectId);
    for (final item in pending) {
      await pushOne(item);
    }
  }

  Future<bool> pushOne(AgendaItem item) async {
    await _localStore.updateSyncStatus(item.id, SyncStatus.uploading);

    try {
      final response = await _defaultCreateAssignment(item);
      final remote = _parseRemoteRecords(response, projectId: item.projectCode);

      if (remote.isNotEmpty) {
        final serverRecord = remote.first;
        await _localStore.deleteById(item.id);
        await _localStore.upsertAssignments([
          AgendaAssignmentRecord(
            id: serverRecord.id,
            projectId: serverRecord.projectId,
            resourceId: serverRecord.resourceId,
            resourceName: serverRecord.resourceName,
            activityId: serverRecord.activityId,
            title: serverRecord.title,
            frente: serverRecord.frente,
            municipio: serverRecord.municipio,
            estado: serverRecord.estado,
            pk: serverRecord.pk,
            startAt: serverRecord.startAt,
            endAt: serverRecord.endAt,
            risk: serverRecord.risk,
            syncStatus: SyncStatus.synced,
          ),
        ]);
      } else {
        await _localStore.updateSyncStatus(item.id, SyncStatus.synced);
      }

      return true;
    } on DioException catch (e) {
      appLogger.w('Assignment push failed: $e');
      await _localStore.updateSyncStatus(item.id, SyncStatus.error);
      return false;
    } catch (e) {
      appLogger.w('Assignment push parse failed: $e');
      await _localStore.updateSyncStatus(item.id, SyncStatus.error);
      return false;
    }
  }

  Future<AgendaAssignmentRecord> transferAssignment({
    required String assignmentId,
    required String projectId,
    required String assigneeUserId,
    String? assigneeName,
    String? reason,
  }) async {
    final response = await _apiClientOrThrow.post<dynamic>(
      '/assignments/$assignmentId/transfer',
      data: {
        'assignee_user_id': assigneeUserId,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );

    final rawData = response.data;
    final remote = _parseRemoteRecords(rawData, projectId: projectId);
    if (remote.isEmpty) {
      throw StateError('Transfer response did not return a valid assignment payload');
    }

    final serverRecord = remote.first;
    final resolvedAssigneeName = _extractAssigneeName(rawData) ?? assigneeName;
    final localRecord = AgendaAssignmentRecord(
      id: serverRecord.id,
      projectId: serverRecord.projectId,
      resourceId: serverRecord.resourceId,
      resourceName: resolvedAssigneeName ?? serverRecord.resourceName,
      activityId: serverRecord.activityId,
      title: serverRecord.title,
      frente: serverRecord.frente,
      municipio: serverRecord.municipio,
      estado: serverRecord.estado,
      pk: serverRecord.pk,
      startAt: serverRecord.startAt,
      endAt: serverRecord.endAt,
      risk: serverRecord.risk,
      syncStatus: SyncStatus.synced,
    );

    await _upsertUserSnapshot(localRecord.resourceId, displayName: localRecord.resourceName);
    await _localStore.upsertAssignments([localRecord]);
    await _upsertActivitiesFromAssignments([localRecord]);
    return localRecord;
  }

  Future<List<AgendaItem>> loadRange({
    required String projectId,
    required DateTime from,
    required DateTime to,
    required bool isOffline,
  }) async {
    final local = await _localStore.queryRange(
      projectId: projectId,
      from: from,
      to: to,
    );

    if (isOffline) return local;

    try {
      final raw = await _fetchAssignments(
        projectId: projectId,
        from: from,
        to: to,
      );
      final remote = _parseRemoteRecords(raw, projectId: projectId);
      await _localStore.replaceSyncedInRange(
        projectId: projectId,
        from: from,
        to: to,
        records: remote,
      );
      await _upsertActivitiesFromAssignments(remote);
      return _localStore.queryRange(projectId: projectId, from: from, to: to);
    } on DioException catch (e) {
      appLogger.w('Assignments fetch failed: $e');
      return local;
    } catch (e) {
      appLogger.w('Assignments parse/upsert failed: $e');
      return local;
    }
  }

  static FetchAssignments _defaultFetchAssignments(ApiClient apiClient) {
    return ({
      required String projectId,
      required DateTime from,
      required DateTime to,
    }) async {
      final response = await apiClient.get<dynamic>(
        '/assignments',
        queryParameters: {
          'project_id': projectId,
          'from': from.toIso8601String(),
          'to': to.toIso8601String(),
        },
      );
      return response.data;
    };
  }

  Future<dynamic> _defaultCreateAssignment(AgendaItem item) async {
    final response = await _apiClientOrThrow.post<dynamic>(
      '/assignments',
      data: {
        'project_id': item.projectCode,
        'assignee_user_id': item.resourceId,
        'activity_type_code': (item.activityId ?? item.activityTypeId ?? item.title)
            .trim()
            .toUpperCase(),
        'title': item.title,
        'pk': item.pk ?? 0,
        'start_at': item.start.toUtc().toIso8601String(),
        'end_at': item.end.toUtc().toIso8601String(),
        'risk': _riskToApi(item.risk),
      },
    );
    return response.data;
  }

  ApiClient get _apiClientOrThrow {
    final client = _apiClient;
    if (client == null) {
      throw StateError('AssignmentsRepository create/sync requires ApiClient injection');
    }
    return client;
  }

  List<AgendaAssignmentRecord> _parseRemoteRecords(
    dynamic raw, {
    required String projectId,
  }) {
    final list = raw is List<dynamic>
      ? raw
      : (raw is Map<String, dynamic> && raw.containsKey('id'))
        ? <dynamic>[raw]
        : (raw is Map<String, dynamic> && raw['items'] is List<dynamic>)
            ? raw['items'] as List<dynamic>
            : <dynamic>[];

    final out = <AgendaAssignmentRecord>[];

    for (final item in list) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);

      final id = (map['id'] ?? map['uuid'] ?? '').toString();
      final resourceId = (map['resource_id'] ??
              map['assignee_user_id'] ??
              map['created_by_user_id'] ??
              map['created_by'] ??
              '')
          .toString();
      final title = (map['activity_name'] ?? map['title'] ?? map['activity_type_code'] ?? '').toString();
      final startRaw = map['start_at'] ?? map['start'] ?? map['scheduled_start'];
      final endRaw = map['end_at'] ?? map['end'] ?? map['scheduled_end'];

      if (id.isEmpty || title.isEmpty || startRaw == null || endRaw == null) {
        continue;
      }

      final startAt = DateTime.tryParse(startRaw.toString());
      final endAt = DateTime.tryParse(endRaw.toString());
      if (startAt == null || endAt == null) continue;

      out.add(
        AgendaAssignmentRecord(
          id: id,
          projectId: (map['project_id'] ?? projectId).toString(),
          resourceId: resourceId.isEmpty ? 'unassigned' : resourceId,
          resourceName: _extractAssigneeName(map),
          activityId: map['activity_id']?.toString(),
          title: title,
          frente: (map['frente'] ?? '').toString(),
          municipio: (map['municipio'] ?? '').toString(),
          estado: (map['estado'] ?? '').toString(),
          pk: map['pk'] is int ? map['pk'] as int : int.tryParse('${map['pk'] ?? ''}'),
          latitude: _parseNullableDouble(
            map['latitude'] ?? map['lat'] ?? map['geo_lat'] ?? map['gps_lat'],
          ),
          longitude: _parseNullableDouble(
            map['longitude'] ?? map['lon'] ?? map['lng'] ?? map['geo_lon'] ?? map['gps_lon'],
          ),
          startAt: startAt,
          endAt: endAt,
          risk: _riskFromString((map['risk'] ?? 'bajo').toString()),
          syncStatus: SyncStatus.synced,
        ),
      );
    }

    return out;
  }

  RiskLevel _riskFromString(String value) {
    switch (value.toLowerCase()) {
      case 'medio':
        return RiskLevel.medio;
      case 'alto':
        return RiskLevel.alto;
      case 'prioritario':
      case 'critical':
        return RiskLevel.prioritario;
      default:
        return RiskLevel.bajo;
    }
  }

  String _riskToApi(RiskLevel risk) {
    switch (risk) {
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

  double? _parseNullableDouble(dynamic raw) {
    if (raw == null) return null;
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw.toString().trim());
  }

  Future<void> _upsertActivitiesFromAssignments(
    List<AgendaAssignmentRecord> records,
  ) async {
    if (records.isEmpty) return;

    final now = DateTime.now();
    for (final record in records) {
      final activityId = await _resolveTargetActivityId(record);
      if (activityId.isEmpty) {
        continue;
      }

      final projectId = record.projectId.trim();
      if (projectId.isEmpty) {
        continue;
      }

      final userId = _normalizeUserId(record.resourceId) ?? 'unassigned';
      await _upsertUserSnapshot(userId, displayName: record.resourceName);
      final activityTypeId = await _resolveActivityTypeId(record);

      final existing = await (_database.select(_database.activities)
            ..where((t) => t.id.equals(activityId)))
          .getSingleOrNull();

      await _database.into(_database.activities).insertOnConflictUpdate(
            ActivitiesCompanion.insert(
              id: activityId,
              projectId: projectId,
              activityTypeId: activityTypeId,
              title: record.title.trim().isNotEmpty ? record.title.trim() : 'Actividad',
              pk: drift.Value(record.pk),
              createdAt: existing?.createdAt ?? record.startAt,
              createdByUserId: userId,
              startedAt: drift.Value(existing?.startedAt),
              finishedAt: drift.Value(existing?.finishedAt),
              status: drift.Value(existing?.status ?? 'SYNCED'),
            ),
          );

      final assignmentsAssigneeFieldId = '$activityId:assignee_user_id';
      final frontNameFieldId = '$activityId:front_name';
      final assignmentLatitudeFieldId = '$activityId:assignment_latitude';
      final assignmentLongitudeFieldId = '$activityId:assignment_longitude';

      final assignee = _normalizeUserId(record.resourceId);
      if (assignee != null) {
        await _database.into(_database.activityFields).insertOnConflictUpdate(
              ActivityFieldsCompanion.insert(
                id: assignmentsAssigneeFieldId,
                activityId: activityId,
                fieldKey: 'assignee_user_id',
                valueText: drift.Value(assignee),
              ),
            );
      }

      if (record.frente.trim().isNotEmpty) {
        await _database.into(_database.activityFields).insertOnConflictUpdate(
              ActivityFieldsCompanion.insert(
                id: frontNameFieldId,
                activityId: activityId,
                fieldKey: 'front_name',
                valueText: drift.Value(record.frente.trim()),
              ),
            );
      }

      if (record.latitude != null) {
        await _database.into(_database.activityFields).insertOnConflictUpdate(
              ActivityFieldsCompanion.insert(
                id: assignmentLatitudeFieldId,
                activityId: activityId,
                fieldKey: 'assignment_latitude',
                valueNumber: drift.Value(record.latitude),
              ),
            );
      }

      if (record.longitude != null) {
        await _database.into(_database.activityFields).insertOnConflictUpdate(
              ActivityFieldsCompanion.insert(
                id: assignmentLongitudeFieldId,
                activityId: activityId,
                fieldKey: 'assignment_longitude',
                valueNumber: drift.Value(record.longitude),
              ),
            );
      }

      final hasGeoContext = record.municipio.trim().isNotEmpty || record.estado.trim().isNotEmpty;
      if (hasGeoContext) {
        await (_database.update(_database.activities)
              ..where((t) => t.id.equals(activityId)))
            .write(
          ActivitiesCompanion(
            description: drift.Value(
              _buildLegacyLocationDescription(
                title: record.title,
                frente: record.frente,
                estado: record.estado,
                municipio: record.municipio,
              ),
            ),
            localRevision: drift.Value((existing?.localRevision ?? 1)),
            serverRevision: drift.Value(existing?.serverRevision),
            deviceId: drift.Value(existing?.deviceId),
            geoLat: drift.Value(existing?.geoLat),
            geoLon: drift.Value(existing?.geoLon),
            geoAccuracy: drift.Value(existing?.geoAccuracy),
          ),
        );
      }
    }
  }

  String _deriveLocalActivityId(AgendaAssignmentRecord record) {
    final fromActivityId = record.activityId?.trim();
    if (fromActivityId != null && fromActivityId.isNotEmpty && _looksLikeUuid(fromActivityId)) {
      return fromActivityId;
    }
    return record.id.trim();
  }

  Future<String> _resolveTargetActivityId(AgendaAssignmentRecord record) async {
    final preferred = _deriveLocalActivityId(record);
    if (preferred.isNotEmpty) {
      final existingPreferred = await (_database.select(_database.activities)
            ..where((t) => t.id.equals(preferred)))
          .getSingleOrNull();
      if (existingPreferred != null) {
        return preferred;
      }
    }

    final fromActivityId = record.activityId?.trim();
    if (fromActivityId != null && fromActivityId.isNotEmpty) {
      final existingByActivityId = await (_database.select(_database.activities)
            ..where((t) => t.id.equals(fromActivityId)))
          .getSingleOrNull();
      if (existingByActivityId != null) {
        return fromActivityId;
      }
    }

    final projectId = record.projectId.trim();
    if (projectId.isNotEmpty && record.pk != null) {
      final candidates = await (_database.select(_database.activities)
            ..where((t) => t.projectId.equals(projectId) & t.pk.equals(record.pk!))
            ..orderBy([(t) => drift.OrderingTerm.desc(t.createdAt)]))
          .get();
      if (candidates.isNotEmpty) {
        final targetTitle = _normalizeActivityTitleForMatch(record.title);
        if (targetTitle.isNotEmpty) {
          for (final candidate in candidates) {
            final candidateTitle = _normalizeActivityTitleForMatch(candidate.title);
            if (candidateTitle == targetTitle) {
              return candidate.id;
            }

            final type = await (_database.select(_database.catalogActivityTypes)
                  ..where((t) => t.id.equals(candidate.activityTypeId)))
                .getSingleOrNull();
            final typeName = _normalizeActivityTitleForMatch(type?.name ?? '');
            final typeCode = _normalizeActivityTitleForMatch(type?.code ?? '');
            if (typeName == targetTitle || typeCode == targetTitle) {
              return candidate.id;
            }
          }
        }
        return candidates.first.id;
      }
    }

    return preferred;
  }

  bool _looksLikeUuid(String value) {
    final normalized = value.trim();
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    ).hasMatch(normalized);
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

  String? _normalizeUserId(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    final lowered = value.toLowerCase();
    if (lowered == 'unassigned' || lowered == 'null') return null;
    return value;
  }

  String? _extractAssigneeName(dynamic data) {
    if (data is! Map) {
      return null;
    }

    final map = Map<String, dynamic>.from(data);
    final rawValue = (map['assignee_name'] ?? map['resource_name'] ?? map['full_name'] ?? '').toString().trim();
    return rawValue.isEmpty ? null : rawValue;
  }

  Future<void> _upsertUserSnapshot(String userId, {String? displayName}) async {
    final effectiveName = (displayName != null && displayName.trim().isNotEmpty)
        ? displayName.trim()
        : (userId == 'unassigned' ? 'Sin asignar' : 'Operativo');
    await _database.into(_database.users).insertOnConflictUpdate(
          UsersCompanion.insert(
            id: userId,
            name: effectiveName,
            roleId: 4,
          ),
        );
  }

  Future<String> _resolveActivityTypeId(AgendaAssignmentRecord record) async {
    final candidates = <String?>[
      record.activityId,
      record.title,
    ];

    for (final candidate in candidates) {
      final value = candidate?.trim();
      if (value == null || value.isEmpty) continue;

      final byId = await (_database.select(_database.catalogActivityTypes)
            ..where((t) => t.id.equals(value)))
          .getSingleOrNull();
      if (byId != null) return byId.id;

      final byCode = await (_database.select(_database.catalogActivityTypes)
            ..where((t) => t.code.equals(value.toUpperCase())))
          .getSingleOrNull();
      if (byCode != null) return byCode.id;

      final byName = await (_database.select(_database.catalogActivityTypes)
            ..where((t) => t.name.equals(value)))
          .getSingleOrNull();
      if (byName != null) return byName.id;
    }

    final fallback = await (_database.select(_database.catalogActivityTypes)
          ..limit(1))
        .getSingleOrNull();
    if (fallback != null) return fallback.id;

    return 'unknown_activity_type';
  }

  String _buildLegacyLocationDescription({
    required String title,
    required String frente,
    required String estado,
    required String municipio,
  }) {
    final safeTitle = title.trim().isNotEmpty ? title.trim() : 'Actividad';
    final safeFrente = frente.trim().isNotEmpty ? frente.trim() : 'Sin frente';
    final safeEstado = estado.trim().isNotEmpty ? estado.trim() : 'Sin estado';
    final safeMunicipio = municipio.trim().isNotEmpty ? municipio.trim() : 'Sin municipio';
    return '$safeTitle • Frente: $safeFrente • Estado: $safeEstado • Municipio: $safeMunicipio';
  }
}
