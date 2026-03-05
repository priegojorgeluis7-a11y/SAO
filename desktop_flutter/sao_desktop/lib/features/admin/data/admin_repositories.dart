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
  Future<dynamic> get(String path, {Map<String, String>? queryParams, String? token});
  Future<dynamic> post(String path, {Object? body, String? token});
  Future<dynamic> put(String path, {Object? body, String? token});
  Future<dynamic> patch(String path, {Object? body, String? token});
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
        _ => throw StateError('Unsupported method: $method'),
      };

      request.headers.contentType = ContentType.json;
      if (token != null && token.isNotEmpty) {
        request.headers
            .set(HttpHeaders.authorizationHeader, 'Bearer $token');
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
}

class SessionUser {
  final String id;
  final String email;
  final String fullName;

  const SessionUser({required this.id, required this.email, required this.fullName});

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

  const AdminProject({
    required this.id,
    required this.name,
    required this.status,
    required this.startDate,
    required this.endDate,
  });

  factory AdminProject.fromJson(Map<String, dynamic> json) {
    return AdminProject(
      id: json['id'] as String,
      name: json['name'] as String,
      status: json['status'] as String,
      startDate: json['start_date'] as String,
      endDate: json['end_date'] as String?,
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
  final String? actorEmail;
  final String action;
  final String entity;
  final String entityId;

  const AuditItem({
    required this.id,
    required this.createdAt,
    required this.actorEmail,
    required this.action,
    required this.entity,
    required this.entityId,
  });

  factory AuditItem.fromJson(Map<String, dynamic> json) {
    return AuditItem(
      id: json['id'].toString(),
      createdAt: json['created_at'] as String,
      actorEmail: json['actor_email'] as String?,
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

  Future<List<AdminProject>> list(String token) async {
    final response = await transport.get('/api/v1/projects', token: token) as List<dynamic>;
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
    List<Map<String, dynamic>>? fronts,
    List<Map<String, dynamic>>? locationScope,
  }) async {
    final response = await transport.post(
      '/api/v1/projects',
      token: token,
      body: {
        'id': id,
        'name': name,
        'status': status,
        'start_date': startDate,
        'end_date': endDate,
        'fronts': fronts ?? const [],
        'location_scope': locationScope ?? const [],
      },
    );
    return AdminProject.fromJson(response as Map<String, dynamic>);
  }

  Future<AdminProject> update(
    String token,
    String projectId, {
    required String name,
    required String status,
    required String startDate,
    String? endDate,
  }) async {
    final response = await transport.put(
      '/api/v1/projects/$projectId',
      token: token,
      body: {
        'name': name,
        'status': status,
        'start_date': startDate,
        'end_date': endDate,
      },
    );
    return AdminProject.fromJson(response as Map<String, dynamic>);
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
