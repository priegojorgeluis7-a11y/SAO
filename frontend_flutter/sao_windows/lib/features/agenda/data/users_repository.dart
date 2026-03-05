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
        _usersDao = usersDao,
        _fetchUsers = fetchUsers ?? _defaultFetchUsers(apiClient!);

  final UsersLocalStore _usersDao;
  final FetchAgendaUsers _fetchUsers;

  static const int _operativoRoleId = 4;

  static FetchAgendaUsers _defaultFetchUsers(ApiClient apiClient) {
    return ({String? projectId, required String role}) async {
      final response = await apiClient.get<dynamic>(
        '/users',
        queryParameters: {
          'role': role,
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
      final responseData = await _fetchUsers(
        projectId: projectId,
        role: 'OPERATIVO',
      );

      final remoteUsers = _parseUsers(responseData);
      if (remoteUsers.isNotEmpty) {
        await _usersDao.upsertUsers(remoteUsers);
      }

      return _mapResources(remoteUsers);
    } on DioException catch (e) {
      appLogger.w('Agenda users fetch failed: $e');
      if (cached.isNotEmpty) {
        return _mapResources(cached);
      }
      throw NetworkException('No se pudieron cargar usuarios para agenda.');
    }
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

  List<AgendaCachedUser> _parseUsers(dynamic data) {
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
          final String roleName = (map['role_name'] ?? '').toString().toUpperCase();
          final int roleId = _roleIdFromRoleName(roleName);

          return AgendaCachedUser(
            id: (map['id'] ?? '').toString(),
            fullName: (map['full_name'] ?? map['name'] ?? '').toString(),
            roleId: roleId,
            isActive: (map['is_active'] as bool?) ?? true,
          );
        })
        .where((user) => user.id.isNotEmpty && user.fullName.isNotEmpty)
        .toList();
  }

  int _roleIdFromRoleName(String roleName) {
    switch (roleName) {
      case 'ADMIN':
        return 1;
      case 'COORD':
        return 2;
      case 'SUPERVISOR':
        return 3;
      case 'OPERATIVO':
        return 4;
      case 'LECTOR':
        return 5;
      default:
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
