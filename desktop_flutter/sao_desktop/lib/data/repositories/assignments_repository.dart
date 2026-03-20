import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'backend_api_client.dart';

class AssignmentItem {
  final String id;
  final String title;
  final String activityTypeName;
  final String pk;
  final String frontId;
  final String frontName;
  final String estado;
  final String municipio;
  final String assigneeUserId;
  final String assigneeName;
  final String assigneeEmail;
  final String scheduledDate;
  final String scheduledTime;
  final String? startAt;
  final String? endAt;
  final String status;
  final String? colonia;
  final double? latitude;
  final double? longitude;

  const AssignmentItem({
    required this.id,
    required this.title,
    required this.activityTypeName,
    required this.pk,
    required this.frontId,
    required this.frontName,
    required this.estado,
    required this.municipio,
    required this.assigneeUserId,
    required this.assigneeName,
    required this.assigneeEmail,
    required this.scheduledDate,
    required this.scheduledTime,
    this.startAt,
    this.endAt,
    required this.status,
    this.colonia,
    this.latitude,
    this.longitude,
  });

  factory AssignmentItem.fromJson(Map<String, dynamic> json) {
    final startAtRaw = json['start_at']?.toString();
    final scheduledDateRaw =
        (json['scheduled_date'] ?? json['date'] ?? startAtRaw ?? '').toString();
    final scheduledTimeRaw =
        (json['scheduled_time'] ?? json['time'] ?? startAtRaw ?? scheduledDateRaw)
            .toString();
    final titleRaw = (json['title'] ?? json['activity_id'] ?? 'Actividad').toString();
    final activityTypeRaw = (
      json['activity_type_name'] ??
      json['activity_name'] ??
      json['activity_type'] ??
      json['activity_id'] ??
      ''
    ).toString().trim();

    return AssignmentItem(
      id: (json['id'] ?? '').toString(),
      title: titleRaw,
        activityTypeName: activityTypeRaw.isNotEmpty ? activityTypeRaw : titleRaw,
      pk: (json['pk'] ?? '—').toString(),
      frontId: (json['front_id'] ??
              json['frontId'] ??
              json['frente_id'] ??
              json['frenteId'] ??
              json['front_uuid'] ??
              json['frontUuid'] ??
              '')
          .toString(),
      frontName: (json['front_name'] ??
          json['frontName'] ??
          json['frente_nombre'] ??
          json['frenteNombre'] ??
          json['front'] ??
          json['frente'] ??
          'Sin frente')
        .toString(),
      estado: (json['estado'] ?? '').toString(),
      municipio: (json['municipio'] ?? '').toString(),
      assigneeUserId: (json['assignee_user_id'] ?? json['resource_id'] ?? '').toString(),
      assigneeName: (json['assignee_name'] ?? json['full_name'] ?? 'Sin responsable').toString(),
      assigneeEmail: (json['assignee_email'] ?? json['email'] ?? '').toString(),
      scheduledDate: scheduledDateRaw,
      scheduledTime: scheduledTimeRaw,
      startAt: startAtRaw,
      endAt: json['end_at']?.toString(),
      status: (json['status'] ?? 'PROGRAMADA').toString(),
      colonia: json['colonia']?.toString(),
      latitude: double.tryParse((json['latitude'] ?? json['lat'] ?? '').toString()),
      longitude: double.tryParse((json['longitude'] ?? json['lon'] ?? '').toString()),
    );
  }
}

class AssignmentAssigneeOption {
  final String userId;
  final String fullName;
  final String email;
  final String roleName;

  const AssignmentAssigneeOption({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.roleName,
  });

  factory AssignmentAssigneeOption.fromJson(Map<String, dynamic> json) {
    return AssignmentAssigneeOption(
      userId: (json['user_id'] ?? '').toString(),
      fullName: (json['full_name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      roleName: (json['role_name'] ?? '').toString(),
    );
  }
}

class AssignmentFrontOption {
  final String id;
  final String code;
  final String name;
  final int? pkStart;
  final int? pkEnd;

  const AssignmentFrontOption({
    required this.id,
    required this.code,
    required this.name,
    required this.pkStart,
    required this.pkEnd,
  });

  static int? _parsePkValue(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    return int.tryParse(text);
  }

  factory AssignmentFrontOption.fromJson(Map<String, dynamic> json) {
    final rawCode = (
      json['code'] ??
      json['front_code'] ??
      ''
    ).toString().trim();
    final rawName = (
      json['name'] ??
      json['front_name'] ??
      json['label'] ??
      ''
    ).toString().trim();
    final fallbackId = rawCode.isNotEmpty ? rawCode : rawName;
    final rawId = (
      json['id'] ??
      json['front_id'] ??
      fallbackId
    ).toString().trim();

    return AssignmentFrontOption(
      id: rawId,
      code: rawCode,
      name: rawName,
      pkStart: _parsePkValue(
        json['pk_start'] ?? json['pkStart'] ?? json['pk_inicio'] ?? json['pkInicio'],
      ),
      pkEnd: _parsePkValue(
        json['pk_end'] ?? json['pkEnd'] ?? json['pk_fin'] ?? json['pkFin'],
      ),
    );
  }

  String get label => code.isEmpty ? name : '$code · $name';
}

class AssignmentFrontCoverageOption {
  final String estado;
  final String municipio;

  const AssignmentFrontCoverageOption({
    required this.estado,
    required this.municipio,
  });
}

class AssignmentActivityTypeOption {
  final String code;
  final String name;

  const AssignmentActivityTypeOption({
    required this.code,
    required this.name,
  });

  factory AssignmentActivityTypeOption.fromJson(Map<String, dynamic> json) {
    final rawCode = (
      json['code'] ??
      json['activity_type_code'] ??
      json['activity_code'] ??
      json['id'] ??
      ''
    ).toString().trim();
    final rawName = (
      json['name_effective'] ??
      json['name'] ??
      json['label'] ??
      json['title'] ??
      rawCode
    ).toString().trim();

    return AssignmentActivityTypeOption(
      code: rawCode,
      name: rawName,
    );
  }

  String get label => '$code · $name';
}

class AssignmentsRepository {
  final BackendApiClient _client;

  const AssignmentsRepository(this._client);

  bool _isUuid(String value) {
    final input = value.trim();
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(input);
  }

  String _normalizeKey(String value) => value.trim().toLowerCase();

  String _toQueryDateTimeUtc(DateTime value) {
    return Uri.encodeQueryComponent(value.toUtc().toIso8601String());
  }

  Future<List<AssignmentItem>> _requestAssignmentsWithFallback(
    String projectId,
    List<String> queryVariants,
  ) async {
    for (final query in queryVariants) {
      try {
        final decoded = await _client.getJson(
          '/api/v1/assignments?project_id=${Uri.encodeQueryComponent(projectId)}$query',
        );
        if (decoded is! List) {
          continue;
        }
        return decoded
            .whereType<Map<String, dynamic>>()
            .map((e) => AssignmentItem.fromJson(e))
            .toList();
      } catch (_) {
        // Try next query flavor.
      }
    }
    return const [];
  }

  List<AssignmentFrontOption> _parseFrontOptionsFromProjectMap(
    Map<String, dynamic> project,
  ) {
    final resultById = <String, AssignmentFrontOption>{};

    // 1) Seed from explicit fronts list if present.
    final fromFronts = _parseFrontOptions(
      project['fronts'] ?? project['frentes'] ?? project['project_fronts'],
    );
    for (final item in fromFronts) {
      resultById[item.id] = item;
    }

    // 2) Merge/override using front_location_scope (source of truth in edited projects).
    final rawScope =
      project['front_location_scope'] ??
      project['front_location_scopes'] ??
      project['frontLocationScope'] ??
      project['frontLocationScopes'];
    if (rawScope is List) {
      for (final raw in rawScope.whereType<Map<String, dynamic>>()) {
        final code =
          (raw['front_code'] ?? raw['frontCode'] ?? raw['code'] ?? '')
            .toString()
            .trim();
        final name =
          (raw['front_name'] ?? raw['frontName'] ?? raw['name'] ?? '')
            .toString()
            .trim();
        if (code.isEmpty && name.isEmpty) continue;

        final rawId = (
          raw['front_id'] ??
          raw['frontId'] ??
          raw['frente_id'] ??
          raw['frenteId'] ??
          ''
        )
          .toString()
          .trim();
        final scopeId = rawId.isNotEmpty ? rawId : null;

        AssignmentFrontOption? existing;
        if (scopeId != null) {
          existing = resultById[scopeId];
        }

        existing ??= resultById.values.firstWhere(
          (item) =>
              (code.isNotEmpty && item.code.toUpperCase() == code.toUpperCase()) ||
              (name.isNotEmpty && item.name.toUpperCase() == name.toUpperCase()),
          orElse: () => const AssignmentFrontOption(
            id: '',
            code: '',
            name: '',
            pkStart: null,
            pkEnd: null,
          ),
        );
        if (existing.id.isEmpty) {
          existing = null;
        }

        final mergedId = existing?.id ?? scopeId;
        if (mergedId == null || mergedId.isEmpty) {
          continue;
        }

        if (existing == null) {
          resultById[mergedId] = AssignmentFrontOption(
            id: mergedId,
            code: code,
            name: name.isNotEmpty ? name : (code.isNotEmpty ? code : mergedId),
            pkStart: null,
            pkEnd: null,
          );
          continue;
        }

        // Prefer scope name when available because it reflects current project edit mappings.
        final mergedName = name.isNotEmpty ? name : existing.name;
        final mergedCode = code.isNotEmpty ? code : existing.code;
        resultById[existing.id] = AssignmentFrontOption(
          id: existing.id,
          code: mergedCode,
          name: mergedName,
          pkStart: existing.pkStart,
          pkEnd: existing.pkEnd,
        );
      }
    }

    return resultById.values
        .where((item) => item.id.isNotEmpty && item.name.isNotEmpty)
        .toList();
  }

  Future<List<AssignmentFrontOption>> _loadFrontsFromProjectPayload(
    String projectId,
  ) async {
    try {
      final projectDecoded = await _client.getJson(
        '/api/v1/projects/${Uri.encodeQueryComponent(projectId)}',
      );
      if (projectDecoded is Map<String, dynamic>) {
        final nested = _parseFrontOptionsFromProjectMap(projectDecoded);
        if (nested.isNotEmpty) {
          return nested;
        }
      }
    } catch (_) {
      // Continue with list fallback.
    }

    try {
      final listDecoded = await _client.getJson('/api/v1/projects');
      if (listDecoded is List) {
        final target = listDecoded
            .whereType<Map<String, dynamic>>()
            .firstWhere(
              (item) =>
                  (item['id'] ?? '').toString().toUpperCase() ==
                  projectId.toUpperCase(),
              orElse: () => const <String, dynamic>{},
            );
        final nested = _parseFrontOptionsFromProjectMap(target);
        if (nested.isNotEmpty) {
          return nested;
        }
      }
    } catch (_) {
      // Keep empty list as fallback.
    }

    return const [];
  }

  List<AssignmentFrontOption> _parseFrontOptions(dynamic decoded) {
    final list = decoded is List
        ? decoded
        : (decoded is Map<String, dynamic>
            ? (decoded['items'] ?? decoded['fronts'] ?? decoded['data'])
            : null);

    if (list is! List) {
      return const [];
    }

    final options = list
        .whereType<Map<String, dynamic>>()
        .map(AssignmentFrontOption.fromJson)
        .where((item) => item.id.isNotEmpty && item.name.isNotEmpty)
        .toList();

    final seen = <String>{};
    return options.where((item) => seen.add(item.id)).toList();
  }

  Future<List<AssignmentItem>> getForDate({
    required String projectId,
    required DateTime date,
  }) async {
    final startLocal = DateTime(date.year, date.month, date.day);
    final endLocal = startLocal.add(const Duration(days: 1));
    final fromStr = _toQueryDateTimeUtc(startLocal);
    final toStr = _toQueryDateTimeUtc(endLocal);
    final day = date.toIso8601String().split('T').first;

    return _requestAssignmentsWithFallback(
      projectId,
      [
        '&from=$fromStr&to=$toStr&include_all=true',
        '&from=$fromStr&to=$toStr',
        '&from=$day&to=$day&include_all=true',
        '&from=$day&to=$day',
      ],
    );
  }

  Future<List<AssignmentItem>> getForRange({
    required String projectId,
    required DateTime from,
    required DateTime to,
  }) async {
    final rangeStartLocal = DateTime(from.year, from.month, from.day);
    final rangeEndLocal = DateTime(to.year, to.month, to.day).add(
      const Duration(days: 1),
    );
    final fromStr = _toQueryDateTimeUtc(rangeStartLocal);
    final toStr = _toQueryDateTimeUtc(rangeEndLocal);
    final fromDay = from.toIso8601String().split('T').first;
    final toPlusOneDay = DateTime(to.year, to.month, to.day)
        .add(const Duration(days: 1))
        .toIso8601String()
        .split('T')
        .first;

    return _requestAssignmentsWithFallback(
      projectId,
      [
        '&from=$fromStr&to=$toStr&include_all=true',
        '&from=$fromStr&to=$toStr',
        '&from=$fromDay&to=$toPlusOneDay&include_all=true',
        '&from=$fromDay&to=$toPlusOneDay',
      ],
    );
  }

  Future<List<AssignmentAssigneeOption>> getAssignees(String projectId) async {
    final decoded = await _client.getJson(
      '/api/v1/assignments/assignees?project_id=${Uri.encodeQueryComponent(projectId)}',
    );
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(AssignmentAssigneeOption.fromJson)
        .toList();
  }

  Future<List<AssignmentFrontOption>> getFronts(String projectId) async {
    // Project payload is the source of truth for edited front names.
    final projectFronts = await _loadFrontsFromProjectPayload(projectId);
    if (projectFronts.isNotEmpty) {
      return projectFronts;
    }

    try {
      final decoded = await _client.getJson(
        '/api/v1/fronts?project_id=${Uri.encodeQueryComponent(projectId)}',
      );
      final direct = _parseFrontOptions(decoded);
      if (direct.isNotEmpty) {
        return direct;
      }
    } catch (_) {
      // Some roles cannot access /fronts directly. Keep graceful empty fallback.
    }

    return const [];
  }

  Future<Map<String, List<AssignmentFrontCoverageOption>>> getFrontCoverageByFront(
    String projectId,
  ) async {
    final result = <String, List<AssignmentFrontCoverageOption>>{};

    void addCoverage(String key, AssignmentFrontCoverageOption item) {
      final normalized = _normalizeKey(key);
      if (normalized.isEmpty) return;
      final bucket = result.putIfAbsent(normalized, () => <AssignmentFrontCoverageOption>[]);
      final exists = bucket.any(
        (current) =>
            current.estado.toLowerCase() == item.estado.toLowerCase() &&
            current.municipio.toLowerCase() == item.municipio.toLowerCase(),
      );
      if (!exists) {
        bucket.add(item);
      }
    }

    void collectFromProjectMap(Map<String, dynamic> projectMap) {
      final rawScope =
          projectMap['front_location_scope'] ??
          projectMap['front_location_scopes'] ??
          projectMap['frontLocationScope'] ??
          projectMap['frontLocationScopes'];
      if (rawScope is List) {
        for (final raw in rawScope.whereType<Map<String, dynamic>>()) {
          final estado = (raw['estado'] ?? raw['state'] ?? '').toString().trim();
          final municipio =
              (raw['municipio'] ?? raw['municipality'] ?? '').toString().trim();
          if (estado.isEmpty || municipio.isEmpty) continue;

          final coverage = AssignmentFrontCoverageOption(
            estado: estado,
            municipio: municipio,
          );

          final frontId =
              (raw['front_id'] ?? raw['frontId'] ?? '').toString().trim();
          final frontCode =
              (raw['front_code'] ?? raw['frontCode'] ?? raw['code'] ?? '')
                  .toString()
                  .trim();
          final frontName =
              (raw['front_name'] ?? raw['frontName'] ?? raw['name'] ?? '')
                  .toString()
                  .trim();

          if (frontId.isNotEmpty) addCoverage(frontId, coverage);
          if (frontCode.isNotEmpty) addCoverage(frontCode, coverage);
          if (frontName.isNotEmpty) addCoverage(frontName, coverage);
        }
      }

      // Fallback for projects that only keep global location scope.
      if (result.isEmpty) {
        final fronts = _parseFrontOptionsFromProjectMap(projectMap);
        final rawLocationScope =
            projectMap['location_scope'] ??
            projectMap['location_scopes'] ??
            projectMap['locationScope'];

        if (fronts.isNotEmpty && rawLocationScope is List) {
          final locations = rawLocationScope.whereType<Map<String, dynamic>>();
          for (final location in locations) {
            final estado =
                (location['estado'] ?? location['state'] ?? '').toString().trim();
            final municipio =
                (location['municipio'] ?? location['municipality'] ?? '')
                    .toString()
                    .trim();
            if (estado.isEmpty || municipio.isEmpty) continue;

            final coverage = AssignmentFrontCoverageOption(
              estado: estado,
              municipio: municipio,
            );

            for (final front in fronts) {
              addCoverage(front.id, coverage);
              if (front.code.trim().isNotEmpty) {
                addCoverage(front.code, coverage);
              }
              if (front.name.trim().isNotEmpty) {
                addCoverage(front.name, coverage);
              }
            }
          }
        }
      }
    }

    try {
      final decoded = await _client.getJson(
        '/api/v1/projects/${Uri.encodeQueryComponent(projectId)}',
      );
      if (decoded is Map<String, dynamic>) {
        collectFromProjectMap(decoded);
      }
    } catch (_) {
      // Fallback below.
    }

    if (result.isEmpty) {
      try {
        final listDecoded = await _client.getJson('/api/v1/projects');
        if (listDecoded is List) {
          final projectMap = listDecoded
              .whereType<Map<String, dynamic>>()
              .firstWhere(
                (item) =>
                    (item['id'] ?? '').toString().toUpperCase() ==
                    projectId.toUpperCase(),
                orElse: () => const <String, dynamic>{},
              );
          if (projectMap.isNotEmpty) {
            collectFromProjectMap(projectMap);
          }
        }
      } catch (_) {
        return const {};
      }
    }

    return result;
  }

  Future<List<AssignmentActivityTypeOption>> getActivityTypes(String projectId) async {
    final decoded = await _client.getJson(
      '/api/v1/catalog/effective?project_id=${Uri.encodeQueryComponent(projectId)}',
    );
    if (decoded is! Map<String, dynamic>) return const [];
    final activities = decoded['activities'] ??
      (decoded['data'] is Map<String, dynamic>
        ? (decoded['data'] as Map<String, dynamic>)['activities']
        : null) ??
      (decoded['catalog'] is Map<String, dynamic>
        ? (decoded['catalog'] as Map<String, dynamic>)['activities']
        : null);
    if (activities is! List) return const [];
    return activities
        .whereType<Map<String, dynamic>>()
        .map(AssignmentActivityTypeOption.fromJson)
        .where((item) => item.code.isNotEmpty && item.name.isNotEmpty)
        .toList();
  }

  Future<AssignmentItem> createAssignment({
    required String projectId,
    required String assigneeUserId,
    required String activityTypeCode,
    required DateTime startAt,
    required DateTime endAt,
    String? title,
    String? frontId,
    String? estado,
    String? municipio,
    String? colonia,
    int pk = 0,
    String risk = 'bajo',
    double? latitude,
    double? longitude,
  }) async {
    final normalizedFrontId =
        frontId != null && _isUuid(frontId) ? frontId : null;
    final frontRef = normalizedFrontId == null ? frontId?.trim() : null;
    final decoded = await _client.postJson('/api/v1/assignments', {
      'project_id': projectId,
      'assignee_user_id': assigneeUserId,
      'activity_type_code': activityTypeCode,
      'title': title,
      'front_id': normalizedFrontId,
      'front_ref': frontRef,
      'estado': estado,
      'municipio': municipio,
      'colonia': colonia,
      'pk': pk,
      'start_at': startAt.toUtc().toIso8601String(),
      'end_at': endAt.toUtc().toIso8601String(),
      'risk': risk,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    });
    return AssignmentItem.fromJson((decoded as Map).cast<String, dynamic>());
  }

  Future<void> cancelAssignment(String assignmentId, {String? reason}) async {
    await _client.postJson(
      '/api/v1/assignments/$assignmentId/cancel',
      {'reason': reason ?? ''},
    );
  }
}

final assignmentsRepositoryProvider = Provider<AssignmentsRepository>((ref) {
  return const AssignmentsRepository(BackendApiClient());
});
