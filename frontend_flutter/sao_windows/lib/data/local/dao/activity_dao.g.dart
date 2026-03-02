// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'activity_dao.dart';

// ignore_for_file: type=lint
mixin _$ActivityDaoMixin on DatabaseAccessor<AppDb> {
  $ProjectsTable get projects => attachedDatabase.projects;
  $ProjectSegmentsTable get projectSegments => attachedDatabase.projectSegments;
  $CatalogActivityTypesTable get catalogActivityTypes =>
      attachedDatabase.catalogActivityTypes;
  $RolesTable get roles => attachedDatabase.roles;
  $UsersTable get users => attachedDatabase.users;
  $ActivitiesTable get activities => attachedDatabase.activities;
  $ActivityFieldsTable get activityFields => attachedDatabase.activityFields;
  $ActivityLogTable get activityLog => attachedDatabase.activityLog;
  $EvidencesTable get evidences => attachedDatabase.evidences;
  $SyncQueueTable get syncQueue => attachedDatabase.syncQueue;
  ActivityDaoManager get managers => ActivityDaoManager(this);
}

class ActivityDaoManager {
  final _$ActivityDaoMixin _db;
  ActivityDaoManager(this._db);
  $$ProjectsTableTableManager get projects =>
      $$ProjectsTableTableManager(_db.attachedDatabase, _db.projects);
  $$ProjectSegmentsTableTableManager get projectSegments =>
      $$ProjectSegmentsTableTableManager(
        _db.attachedDatabase,
        _db.projectSegments,
      );
  $$CatalogActivityTypesTableTableManager get catalogActivityTypes =>
      $$CatalogActivityTypesTableTableManager(
        _db.attachedDatabase,
        _db.catalogActivityTypes,
      );
  $$RolesTableTableManager get roles =>
      $$RolesTableTableManager(_db.attachedDatabase, _db.roles);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db.attachedDatabase, _db.users);
  $$ActivitiesTableTableManager get activities =>
      $$ActivitiesTableTableManager(_db.attachedDatabase, _db.activities);
  $$ActivityFieldsTableTableManager get activityFields =>
      $$ActivityFieldsTableTableManager(
        _db.attachedDatabase,
        _db.activityFields,
      );
  $$ActivityLogTableTableManager get activityLog =>
      $$ActivityLogTableTableManager(_db.attachedDatabase, _db.activityLog);
  $$EvidencesTableTableManager get evidences =>
      $$EvidencesTableTableManager(_db.attachedDatabase, _db.evidences);
  $$SyncQueueTableTableManager get syncQueue =>
      $$SyncQueueTableTableManager(_db.attachedDatabase, _db.syncQueue);
}
