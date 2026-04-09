// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'assignments_sync_dao.dart';

// ignore_for_file: type=lint
mixin _$AssignmentsSyncDaoMixin on DatabaseAccessor<AppDb> {
  $ProjectsTable get projects => attachedDatabase.projects;
  $RolesTable get roles => attachedDatabase.roles;
  $UsersTable get users => attachedDatabase.users;
  $ProjectSegmentsTable get projectSegments => attachedDatabase.projectSegments;
  $LocalAssignmentsTable get localAssignments =>
      attachedDatabase.localAssignments;
  AssignmentsSyncDaoManager get managers => AssignmentsSyncDaoManager(this);
}

class AssignmentsSyncDaoManager {
  final _$AssignmentsSyncDaoMixin _db;
  AssignmentsSyncDaoManager(this._db);
  $$ProjectsTableTableManager get projects =>
      $$ProjectsTableTableManager(_db.attachedDatabase, _db.projects);
  $$RolesTableTableManager get roles =>
      $$RolesTableTableManager(_db.attachedDatabase, _db.roles);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db.attachedDatabase, _db.users);
  $$ProjectSegmentsTableTableManager get projectSegments =>
      $$ProjectSegmentsTableTableManager(
        _db.attachedDatabase,
        _db.projectSegments,
      );
  $$LocalAssignmentsTableTableManager get localAssignments =>
      $$LocalAssignmentsTableTableManager(
        _db.attachedDatabase,
        _db.localAssignments,
      );
}
