import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/exceptions.dart';
import '../../../core/utils/logger.dart';
import '../models/resource.dart';
import 'users_dao.dart';

typedef FetchAgendaUsers = Future<dynamic> Function({
  String? projectId,
  required String role,
});

class AgendaUsersRepository {
  AgendaUsersRepository({
    ApiClient? apiClient,
    required UsersLocalStore usersDao,
    FetchAgendaUsers? fetchUsers,
  })  : assert(apiClient != null || fetchUsers != null,
            'apiClient or fetchUsers must be provided'),
          _apiClient = apiClient,
          _usersDao = usersDao,
        _fetchUsers = fetchUsers ?? _defaultFetchUsers(apiClient!);

        final ApiClient? _apiClient;
  final UsersLocalStore _usersDao;
  final FetchAgendaUsers _fetchUsers;

  static const int _operativoRoleId = 4;

  static FetchAgendaUsers _defaultFetchUsers(ApiClient apiClient) {
    return ({String? projectId, required String role}) async {
      final trimmedRole = role.trim();
      final response = await apiClient.get<dynamic>(
        '/users',
        queryParameters: {
          if (trimmedRole.isNotEmpty) 'role': trimmedRole,
          if (projectId != null && projectId.trim().isNotEmpty)
            'project_id': projectId.trim(),
        },
      );
      return response.data;
    };
  }

  Future<List<Resource>> getOperationalUsers({
    String? projectId,
    required bool isOffline,
  }) async {
    final cached = await _usersDao.getActiveUsersByRole(_operativoRoleId);

    if (isOffline) {
      return _mapResources(cached);
    }

    try {
      dynamic responseData = await _fetchUsers(
        projectId: projectId,
        role: 'OPERATIVO',
      );

      final firstCount = _countRawItems(responseData);
      appLogger.i('Agenda users /users role=OPERATIVO raw_count=$firstCount project=$projectId');

      var remoteUsers = _parseOperationalUsers(responseData);
      appLogger.i('Agenda users parsed_count=${remoteUsers.length} source=/users_operativo');
      for (final user in remoteUsers.take(5)) {
        appLogger.i('  User: id=${user.id} name=${user.fullName} roleId=${user.roleId}');
      }

      // Fallback: if project-scoped query returns empty, retry without project filter.
      if (remoteUsers.isEmpty && projectId != null && projectId.trim().isNotEmpty) {
        responseData = await _fetchUsers(
          projectId: null,
          role: 'OPERATIVO',
        );
        final globalCount = _countRawItems(responseData);
        appLogger.i('Agenda users /users role=OPERATIVO project=<none> raw_count=$globalCount');
        remoteUsers = _parseOperationalUsers(responseData);
        appLogger.i('Agenda users parsed_count=${remoteUsers.length} source=/users_operativo_global');
      }

      // Fallback: some deployments may not expose OPERATIVO users in /users
      // even though assignees exist for agenda endpoint.
      if (remoteUsers.isEmpty) {
        try {
          responseData = await _fetchAssignees(projectId: projectId);
          final fallbackCount = _countRawItems(responseData);
          appLogger.i('Agenda users /assignments/assignees raw_count=$fallbackCount project=$projectId');
          remoteUsers = _parseOperationalUsers(responseData);
          appLogger.i('Agenda users parsed_count=${remoteUsers.length} source=/assignments_assignees');
        } catch (_) {
          // Endpoint may require elevated role; continue with next fallback.
        }
      }

      // Final fallback: fetch active users without role filter.
      if (remoteUsers.isEmpty) {
        responseData = await _fetchUsers(
          projectId: projectId,
          role: '',
        );
        final allCount = _countRawItems(responseData);
        appLogger.i('Agenda users /users role=<none> raw_count=$allCount project=$projectId');
        remoteUsers = _parseOperationalUsers(responseData);
        appLogger.i('Agenda users parsed_count=${remoteUsers.length} source=/users_all');
      }

      // Avoid wiping a valid local cache when backend temporarily returns empty.
      if (remoteUsers.isNotEmpty) {
        try {
          await _usersDao.replaceUsersByRole(_operativoRoleId, remoteUsers);
        } catch (e) {
          appLogger.w('Agenda users local cache update failed: $e');
        }
      }

      if (remoteUsers.isEmpty && cached.isNotEmpty) {
        return _mapResources(cached);
      }

      return _mapResources(remoteUsers);
    } on DioException catch (e) {
      appLogger.w('Agenda users fetch failed: $e');
      throw NetworkException('No se pudieron cargar usuarios para agenda.');
    } catch (e) {
      appLogger.w('Agenda users unexpected error, using cache when possible: $e');
      if (cached.isNotEmpty) {
        return _mapResources(cached);
      }
      rethrow;
    }
  }

  Future<dynamic> _fetchAssignees({String? projectId}) async {
    final client = _apiClient;
    if (client == null) {
      return const <dynamic>[];
    }

    final effectiveProject = (projectId != null && projectId.trim().isNotEmpty)
        ? projectId.trim()
        : 'TMQ';

    final response = await client.get<dynamic>(
      '/assignments/assignees',
      queryParameters: {'project_id': effectiveProject},
    );
    return response.data;
  }

  List<Resource> _mapResources(List<AgendaCachedUser> users) {
    return users
        .map(
          (user) => Resource(
            id: user.id,
            name: user.fullName,
            role: _resourceRoleFromRoleId(user.roleId),
            isActive: user.isActive,
          ),
        )
        .toList();
  }

  List<AgendaCachedUser> _parseOperationalUsers(dynamic data) {
    final List<dynamic> rawList;
    if (data is List<dynamic>) {
      rawList = data;
    } else if (data is Map<dynamic, dynamic> && data['items'] is List<dynamic>) {
      rawList = data['items'] as List<dynamic>;
    } else {
      rawList = <dynamic>[];
    }

    return rawList
        .whereType<Map<dynamic, dynamic>>()
        .map((raw) {
          final map = Map<String, dynamic>.from(raw);
          final int roleId = _roleIdFromPayload(map);
          final bool isActive =
              (map['is_active'] as bool?) ??
              (map['isActive'] as bool?) ??
              true;

          return AgendaCachedUser(
            id: (map['id'] ?? map['user_id'] ?? map['userId'] ?? '').toString(),
            fullName: (map['full_name'] ?? map['fullName'] ?? map['name'] ?? '').toString(),
            roleId: roleId,
            isActive: isActive,
          );
        })
        .where((user) => user.isActive)
        .where((user) => user.id.isNotEmpty && user.fullName.isNotEmpty)
        .toList();
  }

  int _roleIdFromPayload(Map<String, dynamic> map) {
    final roleIdRaw = map['role_id'];
    if (roleIdRaw is num) {
      return roleIdRaw.toInt();
    }
    if (roleIdRaw != null) {
      final parsed = int.tryParse(roleIdRaw.toString());
      if (parsed != null) {
        return parsed;
      }
    }

    // Some payloads may expose role as nested object: { role: { id, name } }
    final roleRaw = map['role'];
    if (roleRaw is Map) {
      final roleMap = Map<String, dynamic>.from(roleRaw);
      final nestedId = roleMap['id'];
      if (nestedId is num) {
        return nestedId.toInt();
      }
      if (nestedId != null) {
        final parsed = int.tryParse(nestedId.toString());
        if (parsed != null) {
          return parsed;
        }
      }
      final nestedName = (roleMap['name'] ?? '').toString().toUpperCase();
      if (nestedName.isNotEmpty) {
        return _roleIdFromRoleName(nestedName);
      }
    }

    final roleName =
        (map['role_name'] ?? map['roleName'] ?? map['role'] ?? '')
            .toString()
            .toUpperCase();
    return _roleIdFromRoleName(roleName);
  }

  int _countRawItems(dynamic data) {
    if (data is List<dynamic>) return data.length;
    if (data is Map<dynamic, dynamic> && data['items'] is List<dynamic>) {
      return (data['items'] as List<dynamic>).length;
    }
    return 0;
  }

  int _roleIdFromRoleName(String roleName) {
    switch (roleName.trim()) {
      case 'ADMIN':
        return 1;
      case 'COORD':
        return 2;
      case 'SUPERVISOR':
        return 3;
      case 'OPERATIVO':
      case 'OPERARIO':
      case 'TECNICO':
      case 'TÉCNICO':
        return 4;
      case 'LECTOR':
        return 5;
      default:
        // Endpoint is already filtered by role=OPERATIVO; keep user visible
        // even when role metadata is missing or renamed.
        return _operativoRoleId;
    }
  }

  ResourceRole _resourceRoleFromRoleId(int roleId) {
    switch (roleId) {
      case 3:
        return ResourceRole.supervisor;
      case 4:
        return ResourceRole.tecnico;
      default:
        return ResourceRole.ingeniero;
    }
  }
}
