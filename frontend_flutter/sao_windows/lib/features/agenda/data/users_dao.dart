import '../../../data/local/app_db.dart';
import 'package:drift/drift.dart' as drift;

class AgendaCachedUser {
  final String id;
  final String fullName;
  final int roleId;
  final bool isActive;

  const AgendaCachedUser({
    required this.id,
    required this.fullName,
    required this.roleId,
    required this.isActive,
  });
}

abstract class UsersLocalStore {
  Future<List<AgendaCachedUser>> getActiveUsersByRole(int roleId);
  Future<void> upsertUsers(List<AgendaCachedUser> users);
  Future<void> replaceUsersByRole(int roleId, List<AgendaCachedUser> users);
}

class UsersDao implements UsersLocalStore {
  UsersDao(this._db);

  final AppDb _db;

  @override
  Future<List<AgendaCachedUser>> getActiveUsersByRole(int roleId) async {
    final rows = await (_db.select(_db.users)
          ..where((t) => t.roleId.equals(roleId) & t.isActive.equals(true))
          ..orderBy([(t) => drift.OrderingTerm.asc(t.name)]))
        .get();

    return rows
        .map(
          (row) => AgendaCachedUser(
            id: row.id,
            fullName: row.name,
            roleId: row.roleId,
            isActive: row.isActive,
          ),
        )
        .toList();
  }

  @override
  Future<void> upsertUsers(List<AgendaCachedUser> users) async {
    if (users.isEmpty) return;

    await _db.batch((batch) {
      for (final user in users) {
        batch.insert(
          _db.users,
          UsersCompanion.insert(
            id: user.id,
            name: user.fullName,
            roleId: user.roleId,
            isActive: drift.Value(user.isActive),
          ),
          mode: drift.InsertMode.insertOrReplace,
        );
      }
    });
  }

  @override
  Future<void> replaceUsersByRole(int roleId, List<AgendaCachedUser> users) async {
    await _db.transaction(() async {
      // Do not hard-delete users because other tables may reference them.
      // Keep referential integrity by upserting current snapshot and
      // soft-disabling users missing from latest backend response.
      await _db.batch((batch) {
        for (final user in users) {
          batch.insert(
            _db.users,
            UsersCompanion.insert(
              id: user.id,
              name: user.fullName,
              roleId: user.roleId,
              isActive: drift.Value(user.isActive),
            ),
            mode: drift.InsertMode.insertOrReplace,
          );
        }
      });

      final keepIds = users.map((u) => u.id).toSet();

      if (keepIds.isEmpty) {
        await (_db.update(_db.users)
              ..where((t) => t.roleId.equals(roleId) & t.isActive.equals(true)))
            .write(const UsersCompanion(isActive: drift.Value(false)));
      } else {
        await (_db.update(_db.users)
              ..where((t) =>
                  t.roleId.equals(roleId) &
                  t.isActive.equals(true) &
                  t.id.isNotIn(keepIds)))
            .write(const UsersCompanion(isActive: drift.Value(false)));
      }
    });
  }
}
