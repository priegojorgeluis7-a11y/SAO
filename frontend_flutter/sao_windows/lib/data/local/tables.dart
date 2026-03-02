// lib/data/local/tables.dart
import 'package:drift/drift.dart';

// ---------- Seguridad / Control ----------
class Roles extends Table {
  IntColumn get id => integer()(); // 1..n
  TextColumn get name => text().withLength(min: 1, max: 40)();
  TextColumn get permissionsJson => text().withDefault(const Constant('{}'))();

  @override
  Set<Column> get primaryKey => {id};
}

class Users extends Table {
  TextColumn get id => text()(); // uuid
  TextColumn get name => text().withLength(min: 1, max: 120)();
  IntColumn get roleId => integer().references(Roles, #id)();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get lastLoginAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// ---------- Proyectos / Segmentos ----------
class Projects extends Table {
  TextColumn get id => text()(); // uuid
  TextColumn get code => text().withLength(min: 2, max: 10)(); // TMQ, TAP...
  TextColumn get name => text().withLength(min: 1, max: 120)();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

class ProjectSegments extends Table {
  TextColumn get id => text()(); // uuid
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get segmentName => text().withLength(min: 1, max: 120)();

  // PK numeric: 12+340 => 12340
  IntColumn get pkStart => integer().nullable()();
  IntColumn get pkEnd => integer().nullable()();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

// ---------- Catálogos versionados ----------
class CatalogVersions extends Table {
  TextColumn get id => text()(); // uuid
  TextColumn get projectId => text().nullable().references(Projects, #id)(); // null=global
  IntColumn get versionNumber => integer()(); // 1..n
  DateTimeColumn get publishedAt => dateTime().nullable()();
  TextColumn get checksum => text().nullable()();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class CatalogActivityTypes extends Table {
  TextColumn get id => text()(); // uuid
  TextColumn get code => text().withLength(min: 2, max: 40)(); // CAMINAMIENTO...
  TextColumn get name => text().withLength(min: 1, max: 120)();

  BoolColumn get requiresPk => boolean().withDefault(const Constant(false))();
  BoolColumn get requiresGeo => boolean().withDefault(const Constant(false))();
  BoolColumn get requiresMinuta => boolean().withDefault(const Constant(false))();
  BoolColumn get requiresEvidence => boolean().withDefault(const Constant(false))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  // Control de versiones de catálogo (simple)
  IntColumn get catalogVersion => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

class CatalogFields extends Table {
  TextColumn get id => text()(); // uuid
  TextColumn get activityTypeId => text().references(CatalogActivityTypes, #id)();

  TextColumn get fieldKey => text().withLength(min: 1, max: 60)(); // "asistentes"
  TextColumn get fieldLabel => text().withLength(min: 1, max: 120)(); // "Asistentes"
  TextColumn get fieldType => text().withLength(min: 1, max: 20)(); // text|number|date|select|...
  TextColumn get optionsJson => text().nullable()(); // select options
  BoolColumn get requiredField => boolean().withDefault(const Constant(false))();
  IntColumn get orderIndex => integer().withDefault(const Constant(0))();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get catalogVersion => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

// ---------- Effective catalog (materialized from backend) ----------
class CatActivities extends Table {
  TextColumn get id => text()(); // activity_id
  TextColumn get name => text().withLength(min: 1, max: 200)(); // name_effective
  TextColumn get description => text().nullable()();

  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  TextColumn get versionId => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class CatSubcategories extends Table {
  TextColumn get id => text()(); // subcategory_id
  TextColumn get activityId => text()();
  TextColumn get name => text().withLength(min: 1, max: 200)(); // name_effective
  TextColumn get description => text().nullable()();

  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  TextColumn get versionId => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class CatPurposes extends Table {
  TextColumn get id => text()(); // purpose_id
  TextColumn get activityId => text()();
  TextColumn get subcategoryId => text().nullable()();
  TextColumn get name => text().withLength(min: 1, max: 200)(); // name_effective

  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  TextColumn get versionId => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class CatTopics extends Table {
  TextColumn get id => text()(); // topic_id
  TextColumn get type => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get name => text().withLength(min: 1, max: 200)(); // name_effective

  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  TextColumn get versionId => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class CatRelActivityTopics extends Table {
  TextColumn get activityId => text()();
  TextColumn get topicId => text()();

  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();
  TextColumn get versionId => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {activityId, topicId};
}

class CatResults extends Table {
  TextColumn get id => text()(); // result_id
  TextColumn get name => text().withLength(min: 1, max: 200)(); // name_effective
  TextColumn get category => text().nullable()();
  TextColumn get severity => text().nullable()(); // severity_effective

  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  TextColumn get versionId => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class CatAttendees extends Table {
  TextColumn get id => text()(); // attendee_id
  TextColumn get type => text().withLength(min: 1, max: 80)();
  TextColumn get description => text().nullable()();
  TextColumn get name => text().withLength(min: 1, max: 200)(); // name_effective

  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  TextColumn get versionId => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

// ---------- Núcleo operativo ----------
class Activities extends Table {
  TextColumn get id => text()(); // uuid
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get segmentId => text().nullable().references(ProjectSegments, #id)();
  TextColumn get activityTypeId => text().references(CatalogActivityTypes, #id)();

  TextColumn get title => text().withLength(min: 1, max: 140)();
  TextColumn get description => text().nullable()();

  // PK numeric: 12+340 => 12340
  IntColumn get pk => integer().nullable()();

  // EJE | IZQ | DER (opcional)
  TextColumn get pkRefType => text().nullable().withLength(min: 2, max: 10)();

  DateTimeColumn get createdAt => dateTime()(); // local
  DateTimeColumn get startedAt => dateTime().nullable()();
  DateTimeColumn get finishedAt => dateTime().nullable()();

  TextColumn get createdByUserId => text().references(Users, #id)();

  // DRAFT | READY_TO_SYNC | SYNCED | ERROR | CANCELED
  TextColumn get status => text().withDefault(const Constant('DRAFT'))();

  RealColumn get geoLat => real().nullable()();
  RealColumn get geoLon => real().nullable()();
  RealColumn get geoAccuracy => real().nullable()();

  TextColumn get deviceId => text().nullable()();
  IntColumn get localRevision => integer().withDefault(const Constant(1))();
  IntColumn get serverRevision => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class ActivityFields extends Table {
  TextColumn get id => text()(); // uuid
  TextColumn get activityId => text().references(Activities, #id)();

  TextColumn get fieldKey => text().withLength(min: 1, max: 60)();

  // Guardamos un solo "valor" (normalizado por tipo):
  TextColumn get valueText => text().nullable()();
  RealColumn get valueNumber => real().nullable()();
  DateTimeColumn get valueDate => dateTime().nullable()();
  TextColumn get valueJson => text().nullable()(); // multiselect, etc.

  @override
  Set<Column> get primaryKey => {id};
}

class ActivityLog extends Table {
  TextColumn get id => text()(); // uuid
  TextColumn get activityId => text().references(Activities, #id)();

  // CREATED | EDITED | EVIDENCE_ADDED | SUBMITTED | SYNC_OK | SYNC_FAIL
  TextColumn get eventType => text().withLength(min: 3, max: 30)();

  DateTimeColumn get at => dateTime()();
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get note => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// ---------- Evidencias ----------
class Evidences extends Table {
  TextColumn get id => text()(); // uuid
  TextColumn get activityId => text().references(Activities, #id)();

  // PHOTO | VIDEO | PDF | AUDIO
  TextColumn get type => text().withLength(min: 3, max: 10)();

  TextColumn get filePathLocal => text()();
  TextColumn get fileHash => text().nullable()(); // sha256
  DateTimeColumn get takenAt => dateTime().nullable()();

  RealColumn get geoLat => real().nullable()();
  RealColumn get geoLon => real().nullable()();

  TextColumn get caption => text().nullable()();

  // LOCAL_ONLY | QUEUED | UPLOADED | ERROR
  TextColumn get status => text().withDefault(const Constant('LOCAL_ONLY'))();

  @override
  Set<Column> get primaryKey => {id};
}

class PendingUploads extends Table {
  TextColumn get id => text()(); // uuid
  TextColumn get activityId => text()();
  TextColumn get localPath => text()();
  TextColumn get fileName => text()();
  TextColumn get mimeType => text()();
  IntColumn get sizeBytes => integer()();

  TextColumn get evidenceId => text().nullable()();
  TextColumn get objectPath => text().nullable()();
  TextColumn get signedUrl => text().nullable()();

  // PENDING_INIT | PENDING_UPLOAD | PENDING_COMPLETE | DONE | ERROR
  TextColumn get status => text().withDefault(const Constant('PENDING_INIT'))();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextRetryAt => dateTime().nullable()();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// ---------- Sync ----------
class SyncQueue extends Table {
  TextColumn get id => text()(); // uuid

  // ACTIVITY | EVIDENCE | CATALOG
  TextColumn get entity => text().withLength(min: 3, max: 20)();
  TextColumn get entityId => text()();

  // UPSERT | DELETE
  TextColumn get action => text().withLength(min: 3, max: 10)();

  TextColumn get payloadJson => text()();

  IntColumn get priority => integer().withDefault(const Constant(50))();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();
  TextColumn get lastError => text().nullable()();

  // PENDING | IN_PROGRESS | DONE | ERROR
  TextColumn get status => text().withDefault(const Constant('PENDING'))();

  @override
  Set<Column> get primaryKey => {id};
}

class SyncState extends Table {
  IntColumn get id => integer()(); // siempre 1
  DateTimeColumn get lastSyncAt => dateTime().nullable()();
  TextColumn get lastServerCursor => text().nullable()();

  // {"TMQ":3,"TAP":2} etc
  TextColumn get lastCatalogVersionByProjectJson =>
      text().withDefault(const Constant('{}'))();

  @override
  Set<Column> get primaryKey => {id};
}

// ---------- Eventos (Field Incident Reporting) ----------
class LocalEvents extends Table {
  TextColumn get id => text()(); // uuid generado en móvil
  TextColumn get projectId => text()();
  TextColumn get eventTypeCode => text()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get description => text().nullable()();

  // LOW | MEDIUM | HIGH | CRITICAL
  TextColumn get severity => text().withDefault(const Constant('MEDIUM'))();
  IntColumn get locationPkMeters => integer().nullable()();

  DateTimeColumn get occurredAt => dateTime()();
  DateTimeColumn get resolvedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  TextColumn get reportedByUserId => text()();
  TextColumn get formFieldsJson => text().nullable()(); // JSON string

  // Sync state
  IntColumn get syncVersion => integer().withDefault(const Constant(0))();
  IntColumn get serverId => integer().nullable()(); // assigned by backend after sync

  // LOCAL_PENDING | SYNCED | ERROR
  TextColumn get syncStatus => text().withDefault(const Constant('LOCAL_PENDING'))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
