import 'package:drift/drift.dart' as drift;

import '../../../data/local/app_db.dart';
import '../models/agenda_item.dart';

class AgendaAssignmentRecord {
  const AgendaAssignmentRecord({
    required this.id,
    required this.projectId,
    required this.resourceId,
    this.activityId,
    required this.title,
    required this.frente,
    required this.municipio,
    required this.estado,
    this.pk,
    required this.startAt,
    required this.endAt,
    required this.risk,
    required this.syncStatus,
  });

  final String id;
  final String projectId;
  final String resourceId;
  final String? activityId;
  final String title;
  final String frente;
  final String municipio;
  final String estado;
  final int? pk;
  final DateTime startAt;
  final DateTime endAt;
  final RiskLevel risk;
  final SyncStatus syncStatus;
}

abstract class AssignmentsLocalStore {
  Future<List<AgendaItem>> queryRange({
    required String projectId,
    required DateTime from,
    required DateTime to,
  });

  Future<void> upsertAssignments(List<AgendaAssignmentRecord> records);

  Future<List<AgendaItem>> listPending({String? projectId});

  Future<void> updateSyncStatus(String id, SyncStatus status);

  Future<void> deleteById(String id);
}

class AssignmentsDao implements AssignmentsLocalStore {
  AssignmentsDao(this._db);

  final AppDb _db;

  @override
  Future<List<AgendaItem>> queryRange({
    required String projectId,
    required DateTime from,
    required DateTime to,
  }) async {
    final rows = await (_db.select(_db.agendaAssignments)
          ..where(
            (t) =>
                t.projectId.equals(projectId) &
                t.startAt.isSmallerThanValue(to) &
                t.endAt.isBiggerThanValue(from),
          )
          ..orderBy([(t) => drift.OrderingTerm.asc(t.startAt)]))
        .get();

    return rows
        .map(
          (row) => AgendaItem(
            id: row.id,
            resourceId: row.resourceId,
            title: row.title,
            activityId: row.activityId,
            projectCode: row.projectId,
            frente: row.frente,
            municipio: row.municipio,
            estado: row.estado,
            pk: row.pk,
            start: row.startAt,
            end: row.endAt,
            risk: _riskFromString(row.risk),
            syncStatus: _syncStatusFromString(row.syncStatus),
          ),
        )
        .toList();
  }

  @override
  Future<void> upsertAssignments(List<AgendaAssignmentRecord> records) async {
    if (records.isEmpty) return;

    await _db.batch((batch) {
      for (final record in records) {
        batch.insert(
          _db.agendaAssignments,
          AgendaAssignmentsCompanion.insert(
            id: record.id,
            projectId: record.projectId,
            resourceId: record.resourceId,
            activityId: drift.Value(record.activityId),
            title: record.title,
            frente: drift.Value(record.frente),
            municipio: drift.Value(record.municipio),
            estado: drift.Value(record.estado),
            pk: drift.Value(record.pk),
            startAt: record.startAt,
            endAt: record.endAt,
            risk: drift.Value(_riskToString(record.risk)),
            syncStatus: drift.Value(_syncStatusToString(record.syncStatus)),
            updatedAt: drift.Value(DateTime.now()),
          ),
          mode: drift.InsertMode.insertOrReplace,
        );
      }
    });
  }

  @override
  Future<List<AgendaItem>> listPending({String? projectId}) async {
    final query = _db.select(_db.agendaAssignments)
      ..where(
        (t) => t.syncStatus.equals('pending') | t.syncStatus.equals('error'),
      )
      ..orderBy([(t) => drift.OrderingTerm.asc(t.startAt)]);

    if (projectId != null && projectId.trim().isNotEmpty) {
      query.where((t) => t.projectId.equals(projectId.trim()));
    }

    final rows = await query.get();
    return rows
        .map(
          (row) => AgendaItem(
            id: row.id,
            resourceId: row.resourceId,
            title: row.title,
            activityId: row.activityId,
            projectCode: row.projectId,
            frente: row.frente,
            municipio: row.municipio,
            estado: row.estado,
            pk: row.pk,
            start: row.startAt,
            end: row.endAt,
            risk: _riskFromString(row.risk),
            syncStatus: _syncStatusFromString(row.syncStatus),
          ),
        )
        .toList();
  }

  @override
  Future<void> updateSyncStatus(String id, SyncStatus status) async {
    await (_db.update(_db.agendaAssignments)..where((t) => t.id.equals(id))).write(
      AgendaAssignmentsCompanion(
        syncStatus: drift.Value(_syncStatusToString(status)),
        updatedAt: drift.Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> deleteById(String id) async {
    await (_db.delete(_db.agendaAssignments)..where((t) => t.id.equals(id))).go();
  }

  static RiskLevel _riskFromString(String value) {
    switch (value.toLowerCase()) {
      case 'medio':
        return RiskLevel.medio;
      case 'alto':
        return RiskLevel.alto;
      case 'prioritario':
        return RiskLevel.prioritario;
      default:
        return RiskLevel.bajo;
    }
  }

  static SyncStatus _syncStatusFromString(String value) {
    switch (value.toLowerCase()) {
      case 'uploading':
        return SyncStatus.uploading;
      case 'synced':
        return SyncStatus.synced;
      case 'error':
        return SyncStatus.error;
      default:
        return SyncStatus.pending;
    }
  }

  static String _riskToString(RiskLevel value) {
    switch (value) {
      case RiskLevel.medio:
        return 'medio';
      case RiskLevel.alto:
        return 'alto';
      case RiskLevel.prioritario:
        return 'prioritario';
      case RiskLevel.bajo:
        return 'bajo';
    }
  }

  static String _syncStatusToString(SyncStatus value) {
    switch (value) {
      case SyncStatus.uploading:
        return 'uploading';
      case SyncStatus.synced:
        return 'synced';
      case SyncStatus.error:
        return 'error';
      case SyncStatus.pending:
        return 'pending';
    }
  }
}
