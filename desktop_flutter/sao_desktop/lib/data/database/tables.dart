import 'package:drift/drift.dart';

class Users extends Table {
  TextColumn get id => text()();
  TextColumn get email => text().unique()();
  TextColumn get fullName => text()();
  TextColumn get role => text()(); // ADMIN, COORDINATOR, ENGINEER, VIEWER
  TextColumn get status => text()(); // ACTIVE, INACTIVE
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Projects extends Table {
  TextColumn get id => text()();
  TextColumn get code => text().unique()();
  TextColumn get name => text()();
  TextColumn get status => text()(); // ACTIVE, INACTIVE
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class ActivityTypes extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get code => text()();
  TextColumn get projectId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Activities extends Table {
  TextColumn get id => text()();
  TextColumn get projectId => text()();
  TextColumn get activityTypeId => text()();
  TextColumn get assignedTo => text()();
  TextColumn get frontId => text().nullable()();
  TextColumn get municipalityId => text().nullable()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get status => text()(); // PENDING_REVIEW, APPROVED, REJECTED, NEEDS_FIX
  DateTimeColumn get executedAt => dateTime().nullable()();
  DateTimeColumn get reviewedAt => dateTime().nullable()();
  TextColumn get reviewedBy => text().nullable()();
  TextColumn get reviewComments => text().nullable()();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Evidences extends Table {
  TextColumn get id => text()();
  TextColumn get activityId => text()();
  TextColumn get filePath => text()();
  TextColumn get fileType => text()(); // IMAGE, VIDEO, AUDIO, DOCUMENT
  TextColumn get caption => text().nullable()();
  DateTimeColumn get capturedAt => dateTime()();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Assignments extends Table {
  TextColumn get id => text()();
  TextColumn get projectId => text()();
  TextColumn get userId => text()();
  TextColumn get activityTypeId => text()();
  TextColumn get frontId => text().nullable()();
  DateTimeColumn get scheduledFor => dateTime()();
  TextColumn get status => text()(); // PENDING, IN_PROGRESS, COMPLETED, CANCELLED
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Fronts extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get projectId => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class Municipalities extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get state => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class RejectionReasons extends Table {
  TextColumn get id => text()();
  TextColumn get reason => text()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

class SyncQueue extends Table {
  TextColumn get id => text()();
  TextColumn get entity => text()(); // ACTIVITY, EVIDENCE, ASSIGNMENT
  TextColumn get entityId => text()();
  TextColumn get action => text()(); // CREATE, UPDATE, DELETE
  TextColumn get payloadJson => text()();
  TextColumn get status => text()(); // PENDING, SYNCING, SYNCED, ERROR
  IntColumn get retries => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
