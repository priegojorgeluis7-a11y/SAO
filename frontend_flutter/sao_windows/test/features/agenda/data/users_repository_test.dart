import 'package:flutter_test/flutter_test.dart';
import 'package:sao_windows/features/agenda/data/users_dao.dart';
import 'package:sao_windows/features/agenda/data/users_repository.dart';

class _FakeUsersLocalStore implements UsersLocalStore {
  _FakeUsersLocalStore({List<AgendaCachedUser>? seed})
      : _users = List<AgendaCachedUser>.from(seed ?? const []);

  List<AgendaCachedUser> _users;
  int upsertCalls = 0;

  @override
  Future<List<AgendaCachedUser>> getActiveUsersByRole(int roleId) async {
    return _users.where((user) => user.roleId == roleId && user.isActive).toList();
  }

  @override
  Future<List<AgendaCachedUser>> getAllActiveUsers() async {
    return _users.where((user) => user.isActive).toList();
  }

  @override
  Future<void> upsertUsers(List<AgendaCachedUser> users) async {
    upsertCalls++;
    _users = users;
  }

  @override
  Future<void> replaceUsersByRole(int roleId, List<AgendaCachedUser> users) async {
    upsertCalls++;
    _users = [
      ..._users.where((user) => user.roleId != roleId),
      ...users,
    ];
  }
}

void main() {
  group('AgendaUsersRepository cache-first', () {
    test('offline: retorna cache y no llama remoto', () async {
      var remoteCalls = 0;
      final local = _FakeUsersLocalStore(
        seed: const [
          AgendaCachedUser(id: 'u1', fullName: 'Juan Perez', roleId: 4, isActive: true),
        ],
      );

      final repository = AgendaUsersRepository(
        usersDao: local,
        fetchUsers: ({String? projectId, required String role}) async {
          remoteCalls++;
          return <dynamic>[];
        },
      );

      final result = await repository.getOperationalUsers(
        projectId: 'TMQ',
        isOffline: true,
      );

      expect(result.length, 1);
      expect(result.first.id, 'u1');
      expect(remoteCalls, 0);
      expect(local.upsertCalls, 0);
    });

    test('online: llama remoto y actualiza cache', () async {
      var remoteCalls = 0;
      final local = _FakeUsersLocalStore();

      final repository = AgendaUsersRepository(
        usersDao: local,
        fetchUsers: ({String? projectId, required String role}) async {
          remoteCalls++;
          return [
            {
              'id': 'u2',
              'full_name': 'Maria Lopez',
              'role_name': 'OPERATIVO',
              'is_active': true,
            }
          ];
        },
      );

      final result = await repository.getOperationalUsers(
        projectId: 'TMQ',
        isOffline: false,
      );

      expect(remoteCalls, 1);
      expect(local.upsertCalls, 1);
      expect(result.length, 1);
      expect(result.first.id, 'u2');
    });

    test('transfer candidates include all active project members', () async {
      final local = _FakeUsersLocalStore();

      final repository = AgendaUsersRepository(
        usersDao: local,
        fetchUsers: ({String? projectId, required String role}) async {
          expect(projectId, 'TMQ');
          expect(role, '');
          return [
            {
              'id': 'admin-1',
              'full_name': 'Admin Uno',
              'role_name': 'ADMIN',
              'is_active': true,
            },
            {
              'id': 'coord-1',
              'full_name': 'Coord Uno',
              'role_name': 'COORD',
              'is_active': true,
            },
            {
              'id': 'op-1',
              'full_name': 'Operativo Uno',
              'role_name': 'OPERATIVO',
              'is_active': true,
            },
          ];
        },
      );

      final result = await repository.getTransferCandidates(
        projectId: 'TMQ',
        isOffline: false,
      );

      expect(result.map((item) => item.id), ['admin-1', 'coord-1', 'op-1']);
    });
  });
}
