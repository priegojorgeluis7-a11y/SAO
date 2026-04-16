import 'dart:convert';
import 'dart:io';

class AdminApiException implements Exception {
  final int statusCode;
  final String message;

  AdminApiException(this.statusCode, this.message);

  @override
  String toString() => 'AdminApiException($statusCode): $message';
}

abstract class AdminApiTransport {
  Future<dynamic> get(String path,
      {Map<String, String>? queryParams, String? token});
  Future<dynamic> post(String path, {Object? body, String? token});
  Future<dynamic> put(String path, {Object? body, String? token});
  Future<dynamic> patch(String path, {Object? body, String? token});
  Future<void> delete(String path, {String? token});
}

class HttpAdminApiTransport implements AdminApiTransport {
  HttpAdminApiTransport({required this.baseUrl});

  final String baseUrl;

  Uri _buildUri(String path, Map<String, String>? queryParams) {
    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final uri = Uri.parse('$normalizedBase$path');
    if (queryParams == null || queryParams.isEmpty) {
      return uri;
    }
    return uri.replace(queryParameters: queryParams);
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? queryParams,
    String? token,
  }) async {
    final uri = _buildUri(path, queryParams);
    final client = HttpClient();
    try {
      final request = switch (method) {
        'GET' => await client.getUrl(uri),
        'POST' => await client.postUrl(uri),
        'PUT' => await client.putUrl(uri),
        'PATCH' => await client.patchUrl(uri),
        'DELETE' => await client.deleteUrl(uri),
        _ => throw StateError('Unsupported method: $method'),
      };

      request.headers.contentType = ContentType.json;
      if (token != null && token.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }

      if (body != null) {
        request.write(jsonEncode(body));
      }

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AdminApiException(response.statusCode, responseBody);
      }

      if (responseBody.isEmpty) {
        return null;
      }
      return jsonDecode(responseBody);
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<dynamic> get(
    String path, {
    Map<String, String>? queryParams,
    String? token,
  }) {
    return _send('GET', path, queryParams: queryParams, token: token);
  }

  @override
  Future<dynamic> post(String path, {Object? body, String? token}) {
    return _send('POST', path, body: body, token: token);
  }

  @override
  Future<dynamic> put(String path, {Object? body, String? token}) {
    return _send('PUT', path, body: body, token: token);
  }

  @override
  Future<dynamic> patch(String path, {Object? body, String? token}) {
    return _send('PATCH', path, body: body, token: token);
  }

  @override
  Future<void> delete(String path, {String? token}) async {
    await _send('DELETE', path, token: token);
  }
}

class SessionUser {
  final String id;
  final String email;
  final String fullName;

  const SessionUser(
      {required this.id, required this.email, required this.fullName});

  factory SessionUser.fromJson(Map<String, dynamic> json) {
    return SessionUser(
      id: json['id'].toString(),
      email: json['email'] as String,
      fullName: json['full_name'] as String? ?? '',
    );
  }
}

class LoginResult {
  final String accessToken;
  final String refreshToken;
  final int expiresIn;

  const LoginResult({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
  });

  factory LoginResult.fromJson(Map<String, dynamic> json) {
    return LoginResult(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String? ?? '',
      expiresIn: json['expires_in'] as int? ?? 0,
    );
  }
}

class AdminProject {
  final String id;
  final String name;
  final String status;
  final String startDate;
  final String? endDate;
  final int frontsCount;
  final int municipalitiesCount;
  final int statesCount;
  final List<AdminProjectFront> fronts;
  final List<AdminProjectLocation> locationScope;
  final List<AdminProjectFrontLocation> frontLocationScope;
  final List<AdminProjectState> states;

  const AdminProject({
    required this.id,
    required this.name,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.frontsCount,
    required this.municipalitiesCount,
    required this.statesCount,
    required this.fronts,
    required this.locationScope,
    required this.frontLocationScope,
    required this.states,
  });

  factory AdminProject.fromJson(Map<String, dynamic> json) {
    final frontsRaw =
      json['fronts'] ?? json['frentes'] ?? json['project_fronts'] ?? const [];
    final locationScopeRaw = json['location_scope'] ??
      json['locationScope'] ??
      json['locations'] ??
      json['coverage'] ??
      json['location_scopes'] ??
      const [];
    final frontLocationScopeRaw = json['front_location_scope'] ??
      json['frontLocationScope'] ??
      json['front_location_scopes'] ??
      json['fronts_location_scope'] ??
      const [];
    final statesRaw = json['states'] ?? json['estados'] ?? const [];
    final frontsList = frontsRaw is List ? frontsRaw : const [];
    final locationScopeList = locationScopeRaw is List ? locationScopeRaw : const [];
    final frontLocationScopeList =
        frontLocationScopeRaw is List ? frontLocationScopeRaw : const [];
    final statesList = statesRaw is List ? statesRaw : const [];

    int toIntValue(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse('$value') ?? 0;
    }

    return AdminProject(
      id: (json['id'] ?? json['project_id'] ?? json['code'] ?? '').toString(),
      name: (json['name'] ?? json['nombre'] ?? '').toString(),
      status: (json['status'] ?? json['estado'] ?? 'active').toString(),
      startDate: (json['start_date'] ?? json['startDate'] ?? '').toString(),
      endDate: (json['end_date'] ?? json['endDate'])?.toString(),
      frontsCount: toIntValue(
      json['fronts_count'] ?? json['frontsCount'] ?? json['frentes_count'],
      ),
      municipalitiesCount: toIntValue(
      json['municipalities_count'] ??
        json['municipalitiesCount'] ??
        json['municipios_count'],
      ),
      statesCount:
        toIntValue(json['states_count'] ?? json['statesCount'] ?? json['estados_count']),
        fronts: frontsList
          .map((item) =>
              AdminProjectFront.fromJson(item as Map<String, dynamic>))
          .toList(),
        locationScope: locationScopeList
          .map((item) =>
              AdminProjectLocation.fromJson(item as Map<String, dynamic>))
          .toList(),
        frontLocationScope: frontLocationScopeList
          .map((item) =>
              AdminProjectFrontLocation.fromJson(item as Map<String, dynamic>))
          .toList(),
        states: statesList
          .map((item) =>
              AdminProjectState.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class AdminProjectFront {
  final String code;
  final String name;
  final int? pkStart;
  final int? pkEnd;

  const AdminProjectFront({
    required this.code,
    required this.name,
    required this.pkStart,
    required this.pkEnd,
  });

  factory AdminProjectFront.fromJson(Map<String, dynamic> json) {
    return AdminProjectFront(
      code: (json['code'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      pkStart: json['pk_start'] as int?,
      pkEnd: json['pk_end'] as int?,
    );
  }
}

class AdminProjectLocation {
  final String estado;
  final String municipio;

  const AdminProjectLocation({
    required this.estado,
    required this.municipio,
  });

  factory AdminProjectLocation.fromJson(Map<String, dynamic> json) {
    return AdminProjectLocation(
      estado: (json['estado'] ?? '').toString(),
      municipio: (json['municipio'] ?? '').toString(),
    );
  }
}

class AdminProjectState {
  final String estado;
  final int municipiosCount;

  const AdminProjectState({
    required this.estado,
    required this.municipiosCount,
  });

  factory AdminProjectState.fromJson(Map<String, dynamic> json) {
    return AdminProjectState(
      estado: (json['estado'] ?? '').toString(),
      municipiosCount: json['municipios_count'] as int? ?? 0,
    );
  }
}

class AdminProjectFrontLocation {
  final String frontCode;
  final String? frontName;
  final String estado;
  final String municipio;

  const AdminProjectFrontLocation({
    required this.frontCode,
    required this.frontName,
    required this.estado,
    required this.municipio,
  });

  factory AdminProjectFrontLocation.fromJson(Map<String, dynamic> json) {
    return AdminProjectFrontLocation(
      frontCode: (json['front_code'] ?? json['code'] ?? '').toString(),
      frontName: (json['front_name'] ?? json['name'])?.toString(),
      estado: (json['estado'] ?? '').toString(),
      municipio: (json['municipio'] ?? '').toString(),
    );
  }
}

class AdminUserItem {
  final String id;
  final String email;
  final String fullName;
  final String status;
  final String roleName;
  final String? projectId;

  const AdminUserItem({
    required this.id,
    required this.email,
    required this.fullName,
    required this.status,
    required this.roleName,
    required this.projectId,
  });

  factory AdminUserItem.fromJson(Map<String, dynamic> json) {
    return AdminUserItem(
      id: json['id'].toString(),
      email: json['email'] as String,
      fullName: json['full_name'] as String,
      status: json['status'] as String,
      roleName: json['role_name'] as String,
      projectId: json['project_id'] as String?,
    );
  }
}

class AuditItem {
  final String id;
  final String createdAt;
  final String? actorName;
  final String? actorEmail;
  final String? actorRole;
  final String action;
  final String entity;
  final String entityId;

  const AuditItem({
    required this.id,
    required this.createdAt,
    required this.actorName,
    required this.actorEmail,
    required this.actorRole,
    required this.action,
    required this.entity,
    required this.entityId,
  });

  String get actorDisplay {
    String? normalizeRole(String? rawRole) {
      final normalized = (rawRole ?? '').trim().toUpperCase();
      if (normalized.isEmpty) return null;
      if (normalized.contains('ADMIN')) return 'ADMIN';
      if (normalized.contains('COORD')) return 'COORDINADOR';
      if (normalized.contains('SUPERVISOR')) return 'SUPERVISOR';
      if (normalized.contains('LECTOR') || normalized.contains('VIEW')) return 'LECTOR';
      if (normalized.contains('OPERAT') || normalized.contains('OPERAR') || normalized.contains('TECN') || normalized.contains('ING') || normalized.contains('TOP')) {
        return 'OPERATIVO';
      }
      return normalized;
    }

    final name = actorName?.trim();
    final role = normalizeRole(actorRole?.trim());
    final email = actorEmail?.trim();

    final header = [
      if (name != null && name.isNotEmpty) name,
      if (role != null && role.isNotEmpty) role,
    ].join(' • ');

    if (header.isNotEmpty && email != null && email.isNotEmpty) {
      return '$header\n$email';
    }
    if (header.isNotEmpty) {
      return header;
    }
    if (email != null && email.isNotEmpty) {
      return email;
    }
    return '-';
  }

  factory AuditItem.fromJson(Map<String, dynamic> json) {
    return AuditItem(
      id: json['id'].toString(),
      createdAt: json['created_at'] as String,
      actorName: json['actor_name'] as String?,
      actorEmail: json['actor_email'] as String?,
      actorRole: json['actor_role'] as String?,
      action: json['action'] as String,
      entity: json['entity'] as String,
      entityId: json['entity_id'] as String,
    );
  }
}

class AuthRepository {
  final AdminApiTransport transport;

  AuthRepository(this.transport);

  Future<LoginResult> login(String email, String password) async {
    final response = await transport.post(
      '/api/v1/auth/login',
      body: {'email': email, 'password': password},
    );
    return LoginResult.fromJson(response as Map<String, dynamic>);
  }

  Future<SessionUser> me(String token) async {
    final response = await transport.get('/api/v1/auth/me', token: token);
    return SessionUser.fromJson(response as Map<String, dynamic>);
  }

  Future<void> logout(String token) async {
    await transport.post('/api/v1/auth/logout', token: token);
  }
}

class ProjectsRepository {
  final AdminApiTransport transport;

  ProjectsRepository(this.transport);

  bool _matchesLocationScope(
    AdminProject project,
    List<Map<String, dynamic>> expectedScope,
  ) {
    final expected = {
      for (final item in expectedScope)
        '${(item['estado'] ?? '').toString().trim().toLowerCase()}|${(item['municipio'] ?? '').toString().trim().toLowerCase()}',
    };
    final actual = {
      for (final item in project.locationScope)
        '${item.estado.trim().toLowerCase()}|${item.municipio.trim().toLowerCase()}',
    };
    return expected.difference(actual).isEmpty;
  }

  Future<AdminProject?> _fetchProjectById(String token, String projectId) async {
    final response =
        await transport.get('/api/v1/projects', token: token) as List<dynamic>;
    final wanted = projectId.trim().toLowerCase();
    for (final item in response) {
      if (item is! Map<String, dynamic>) continue;
      final parsed = AdminProject.fromJson(item);
      if (parsed.id.trim().toLowerCase() == wanted) {
        return parsed;
      }
    }
    return null;
  }

  Future<List<AdminProject>> list(String token) async {
    final response =
        await transport.get('/api/v1/projects', token: token) as List<dynamic>;
    return response
        .map((e) => AdminProject.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AdminProject> create(
    String token, {
    required String id,
    required String name,
    required String startDate,
    String status = 'active',
    String? endDate,
    bool bootstrapFromTmq = false,
    String? baseCatalogVersion,
    List<Map<String, dynamic>>? fronts,
    List<Map<String, dynamic>>? locationScope,
    List<Map<String, dynamic>>? frontLocationScope,
  }) async {
    final resolvedFronts = fronts ?? const [];
    final resolvedLocationScope = locationScope ?? const [];
    final response = await transport.post(
      '/api/v1/projects',
      token: token,
      body: {
        'id': id,
        'name': name,
        'status': status,
        'start_date': startDate,
        'startDate': startDate,
        'end_date': endDate,
        'endDate': endDate,
        'bootstrap_from_tmq': bootstrapFromTmq,
        'bootstrapFromTmq': bootstrapFromTmq,
        'base_catalog_version': baseCatalogVersion,
        'baseCatalogVersion': baseCatalogVersion,
        'fronts': resolvedFronts,
        'frentes': resolvedFronts,
        'project_fronts': resolvedFronts,
        'location_scope': resolvedLocationScope,
        'locationScope': resolvedLocationScope,
        'location_scopes': resolvedLocationScope,
        'locations': resolvedLocationScope,
        'coverage': resolvedLocationScope,
        'front_location_scope': frontLocationScope ?? const [],
        'frontLocationScope': frontLocationScope ?? const [],
        'front_location_scopes': frontLocationScope ?? const [],
      },
    );

    var parsed = AdminProject.fromJson(response as Map<String, dynamic>);
    if (resolvedLocationScope.isNotEmpty && !_matchesLocationScope(parsed, resolvedLocationScope)) {
      try {
        await transport.post(
          '/api/v1/projects/$id/locations',
          token: token,
          body: resolvedLocationScope,
        );
      } catch (_) {
        // Continue to explicit verification below.
      }

      final latest = await _fetchProjectById(token, id);
      if (latest != null) {
        parsed = latest;
      }
      if (!_matchesLocationScope(parsed, resolvedLocationScope)) {
        throw AdminApiException(
          422,
          'El backend no persistio la cobertura de estados/municipios para este proyecto. Actualiza/reinicia API para aplicar el fix de /projects/{id}/locations.',
        );
      }
    }
    return parsed;
  }

  Future<AdminProject> update(
    String token,
    String projectId, {
    required String name,
    required String status,
    required String startDate,
    String? endDate,
    List<Map<String, dynamic>>? fronts,
    List<Map<String, dynamic>>? locationScope,
    List<Map<String, dynamic>>? frontLocationScope,
  }) async {
    final resolvedFronts = fronts ?? const [];
    final resolvedLocationScope = locationScope ?? const [];
    final response = await transport.put(
      '/api/v1/projects/$projectId',
      token: token,
      body: {
        'name': name,
        'status': status,
        'start_date': startDate,
        'startDate': startDate,
        'end_date': endDate,
        'endDate': endDate,
        'fronts': resolvedFronts,
        'frentes': resolvedFronts,
        'project_fronts': resolvedFronts,
        'location_scope': resolvedLocationScope,
        'locationScope': resolvedLocationScope,
        'location_scopes': resolvedLocationScope,
        'locations': resolvedLocationScope,
        'coverage': resolvedLocationScope,
        'front_location_scope': frontLocationScope ?? const [],
        'frontLocationScope': frontLocationScope ?? const [],
        'front_location_scopes': frontLocationScope ?? const [],
      },
    );

    // Compatibility fallback for deployments that still require dedicated
    // project locations endpoint.
    var parsed = AdminProject.fromJson(response as Map<String, dynamic>);
    if (resolvedLocationScope.isNotEmpty && !_matchesLocationScope(parsed, resolvedLocationScope)) {
      try {
        await transport.post(
          '/api/v1/projects/$projectId/locations',
          token: token,
          body: resolvedLocationScope,
        );
      } catch (_) {
        // Continue to explicit verification below.
      }

      final latest = await _fetchProjectById(token, projectId);
      if (latest != null) {
        parsed = latest;
      }
      if (!_matchesLocationScope(parsed, resolvedLocationScope)) {
        throw AdminApiException(
          422,
          'El backend no persistio la cobertura de estados/municipios para este proyecto. Actualiza/reinicia API para aplicar el fix de /projects/{id}/locations.',
        );
      }
    }
    return parsed;
  }

  Future<void> delete(String token, String projectId) async {
    await transport.delete('/api/v1/projects/$projectId', token: token);
  }
}

class UsersRepository {
  final AdminApiTransport transport;

  UsersRepository(this.transport);

  Future<List<AdminUserItem>> list(String token, {String? role}) async {
    final query = <String, String>{};
    if (role != null && role.isNotEmpty) {
      query['role'] = role;
    }

    final response = await transport.get(
      '/api/v1/users/admin',
      token: token,
      queryParams: query.isEmpty ? null : query,
    ) as List<dynamic>;

    return response
        .map((e) => AdminUserItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AdminUserItem> create(
    String token, {
    required String email,
    required String fullName,
    required String password,
    required String role,
    String? projectId,
  }) async {
    final response = await transport.post(
      '/api/v1/users/admin',
      token: token,
      body: {
        'email': email,
        'full_name': fullName,
        'password': password,
        'role': role,
        'project_id': projectId,
      },
    );
    return AdminUserItem.fromJson(response as Map<String, dynamic>);
  }

  Future<AdminUserItem> update(
    String token,
    String userId, {
    String? fullName,
    String? role,
    String? projectId,
    String? status,
  }) async {
    final body = <String, dynamic>{};
    if (fullName != null) body['full_name'] = fullName;
    if (role != null) body['role'] = role;
    if (projectId != null) body['project_id'] = projectId;
    if (status != null) body['status'] = status;

    final response = await transport.patch(
      '/api/v1/users/admin/$userId',
      token: token,
      body: body,
    );
    return AdminUserItem.fromJson(response as Map<String, dynamic>);
  }
}

// ─── Invitation model + repository ────────────────────────────────────────────

class AdminInvitation {
  final String inviteId;
  final String role;
  final String createdBy;
  final String? targetEmail;
  final DateTime expiresAt;
  final bool used;
  final String? usedBy;
  final DateTime? usedAt;
  final DateTime createdAt;

  const AdminInvitation({
    required this.inviteId,
    required this.role,
    required this.createdBy,
    required this.targetEmail,
    required this.expiresAt,
    required this.used,
    required this.usedBy,
    required this.usedAt,
    required this.createdAt,
  });

  factory AdminInvitation.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is DateTime) return v;
      return DateTime.tryParse(v.toString()) ?? DateTime.now();
    }

    return AdminInvitation(
      inviteId: json['invite_id']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      createdBy: json['created_by']?.toString() ?? '',
      targetEmail: json['target_email']?.toString(),
      expiresAt: parseDate(json['expires_at']),
      used: json['used'] as bool? ?? false,
      usedBy: json['used_by']?.toString(),
      usedAt: json['used_at'] != null ? parseDate(json['used_at']) : null,
      createdAt: parseDate(json['created_at']),
    );
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class InvitationsRepository {
  final AdminApiTransport transport;

  InvitationsRepository(this.transport);

  Future<List<AdminInvitation>> list(String token) async {
    final response =
        await transport.get('/api/v1/invitations', token: token) as List<dynamic>;
    return response
        .map((e) => AdminInvitation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AdminInvitation> create(
    String token, {
    required String role,
    String? targetEmail,
    int expireDays = 7,
  }) async {
    final body = <String, dynamic>{
      'role': role,
      'expire_days': expireDays,
    };
    if (targetEmail != null && targetEmail.trim().isNotEmpty) {
      body['target_email'] = targetEmail.trim();
    }
    final response = await transport.post(
      '/api/v1/invitations',
      token: token,
      body: body,
    );
    return AdminInvitation.fromJson(response as Map<String, dynamic>);
  }
}

class AuditRepository {
  final AdminApiTransport transport;

  AuditRepository(this.transport);

  Future<List<AuditItem>> list(
    String token, {
    String? actorEmail,
    String? entity,
    String? action,
  }) async {
    final query = <String, String>{};
    if (actorEmail != null && actorEmail.isNotEmpty) {
      query['actor_email'] = actorEmail;
    }
    if (entity != null && entity.isNotEmpty) {
      query['entity'] = entity;
    }
    if (action != null && action.isNotEmpty) {
      query['action'] = action;
    }

    final response = await transport.get(
      '/api/v1/audit',
      token: token,
      queryParams: query.isEmpty ? null : query,
    ) as List<dynamic>;

    return response
        .map((e) => AuditItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

// ─── Assignments ─────────────────────────────────────────────────────────────

class AdminAssignmentItem {
  final String id;
  final String projectId;
  final String assigneeUserId;
  final String title;
  final String status;
  final String? frente;
  final DateTime startAt;
  final DateTime endAt;

  const AdminAssignmentItem({
    required this.id,
    required this.projectId,
    required this.assigneeUserId,
    required this.title,
    required this.status,
    required this.frente,
    required this.startAt,
    required this.endAt,
  });

  factory AdminAssignmentItem.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(String? raw) =>
        DateTime.tryParse(raw ?? '')?.toLocal() ?? DateTime.now();
    return AdminAssignmentItem(
      id: (json['id'] ?? '').toString(),
      projectId: (json['project_id'] ?? '').toString(),
      assigneeUserId: (json['assignee_user_id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      frente: json['frente']?.toString(),
      startAt: parseDate(json['start_at']?.toString()),
      endAt: parseDate(json['end_at']?.toString()),
    );
  }
}

class AssignmentsAdminRepository {
  final AdminApiTransport transport;

  AssignmentsAdminRepository(this.transport);

  /// Returns all assignments for [projectId] within the given range.
  /// Pass [include_all]=true so privileged callers see every assignee.
  Future<List<AdminAssignmentItem>> list(
    String token, {
    required String projectId,
    required DateTime from,
    required DateTime to,
  }) async {
    final response = await transport.get(
      '/api/v1/assignments',
      token: token,
      queryParams: {
        'project_id': projectId,
        'from': from.toUtc().toIso8601String(),
        'to': to.toUtc().toIso8601String(),
        'include_all': 'true',
      },
    ) as List<dynamic>;

    return response
        .map((e) => AdminAssignmentItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
