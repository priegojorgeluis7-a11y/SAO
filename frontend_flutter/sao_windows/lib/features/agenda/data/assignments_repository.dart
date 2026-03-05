import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/logger.dart';
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
    FetchAssignments? fetchAssignments,
  })  : assert(apiClient != null || fetchAssignments != null,
            'apiClient or fetchAssignments must be provided'),
      _apiClient = apiClient,
        _localStore = localStore,
        _fetchAssignments =
            fetchAssignments ?? _defaultFetchAssignments(apiClient!);

    final ApiClient? _apiClient;
  final AssignmentsLocalStore _localStore;
  final FetchAssignments _fetchAssignments;

  Future<void> saveLocal(AgendaItem item) async {
    final record = AgendaAssignmentRecord(
      id: item.id,
      projectId: item.projectCode.trim(),
      resourceId: item.resourceId,
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
      if (remote.isNotEmpty) {
        await _localStore.upsertAssignments(remote);
      }
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
      final resourceId = (map['resource_id'] ?? map['assignee_user_id'] ?? '').toString();
      final title = (map['title'] ?? map['activity_name'] ?? map['activity_type_code'] ?? '').toString();
      final startRaw = map['start_at'] ?? map['start'] ?? map['scheduled_start'];
      final endRaw = map['end_at'] ?? map['end'] ?? map['scheduled_end'];

      if (id.isEmpty || resourceId.isEmpty || title.isEmpty || startRaw == null || endRaw == null) {
        continue;
      }

      final startAt = DateTime.tryParse(startRaw.toString());
      final endAt = DateTime.tryParse(endRaw.toString());
      if (startAt == null || endAt == null) continue;

      out.add(
        AgendaAssignmentRecord(
          id: id,
          projectId: (map['project_id'] ?? projectId).toString(),
          resourceId: resourceId,
          activityId: map['activity_id']?.toString(),
          title: title,
          frente: (map['frente'] ?? '').toString(),
          municipio: (map['municipio'] ?? '').toString(),
          estado: (map['estado'] ?? '').toString(),
          pk: map['pk'] is int ? map['pk'] as int : int.tryParse('${map['pk'] ?? ''}'),
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
}
