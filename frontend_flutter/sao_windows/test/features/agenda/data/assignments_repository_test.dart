import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sao_windows/data/local/app_db.dart';
import 'package:sao_windows/features/agenda/data/assignments_dao.dart';
import 'package:sao_windows/features/agenda/data/assignments_repository.dart';
import 'package:sao_windows/features/agenda/models/agenda_item.dart';

class _FakeAssignmentsLocalStore implements AssignmentsLocalStore {
  final List<AgendaAssignmentRecord> _records = [];

  @override
  Future<List<AgendaItem>> queryRange({
    required String projectId,
    required DateTime from,
    required DateTime to,
  }) async {
    return _records
        .where((r) =>
            r.projectId == projectId &&
            r.startAt.isBefore(to) &&
            r.endAt.isAfter(from))
        .map(
          (r) => AgendaItem(
            id: r.id,
            resourceId: r.resourceId,
            title: r.title,
            activityId: r.activityId,
            projectCode: r.projectId,
            frente: r.frente,
            municipio: r.municipio,
            estado: r.estado,
            pk: r.pk,
            start: r.startAt,
            end: r.endAt,
            risk: r.risk,
            syncStatus: r.syncStatus,
          ),
        )
        .toList();
  }

  @override
  Future<void> upsertAssignments(List<AgendaAssignmentRecord> records) async {
    _records.removeWhere((existing) => records.any((incoming) => incoming.id == existing.id));
    _records.addAll(records);
  }

  @override
  Future<void> replaceSyncedInRange({
    required String projectId,
    required DateTime from,
    required DateTime to,
    required List<AgendaAssignmentRecord> records,
  }) async {
    _records.removeWhere(
      (existing) =>
          existing.projectId == projectId &&
          existing.syncStatus == SyncStatus.synced &&
          existing.startAt.isBefore(to) &&
          existing.endAt.isAfter(from),
    );
    _records.addAll(records);
  }

  @override
  Future<List<AgendaItem>> listPending({String? projectId}) async {
    return _records
        .where((r) =>
            (projectId == null || r.projectId == projectId) &&
            (r.syncStatus == SyncStatus.pending || r.syncStatus == SyncStatus.error))
        .map(
          (r) => AgendaItem(
            id: r.id,
            resourceId: r.resourceId,
            title: r.title,
            activityId: r.activityId,
            projectCode: r.projectId,
            frente: r.frente,
            municipio: r.municipio,
            estado: r.estado,
            pk: r.pk,
            start: r.startAt,
            end: r.endAt,
            risk: r.risk,
            syncStatus: r.syncStatus,
          ),
        )
        .toList();
  }

  @override
  Future<void> updateSyncStatus(String id, SyncStatus status) async {
    final index = _records.indexWhere((r) => r.id == id);
    if (index == -1) return;
    final current = _records[index];
    _records[index] = AgendaAssignmentRecord(
      id: current.id,
      projectId: current.projectId,
      resourceId: current.resourceId,
      activityId: current.activityId,
      title: current.title,
      frente: current.frente,
      municipio: current.municipio,
      estado: current.estado,
      pk: current.pk,
      startAt: current.startAt,
      endAt: current.endAt,
      risk: current.risk,
      syncStatus: status,
    );
  }

  @override
  Future<void> deleteById(String id) async {
    _records.removeWhere((r) => r.id == id);
  }

  Future<void> seed(List<AgendaAssignmentRecord> records) => upsertAssignments(records);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return Directory.systemTemp.createTempSync('sao_windows_test').path;
      }
      return null;
    });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
  });

  group('AssignmentsRepository', () {
    test('offline retorna solo local queryRange', () async {
      final local = _FakeAssignmentsLocalStore();
      final database = AppDb();
      addTearDown(database.close);
      final now = DateTime.now();
      await local.seed([
        AgendaAssignmentRecord(
          id: 'a1',
          projectId: 'TMQ',
          resourceId: 'u1',
          activityId: 'act1',
          title: 'Inspección',
          frente: 'Frente A',
          municipio: 'Celaya',
          estado: 'Guanajuato',
          pk: 12000,
          startAt: now,
          endAt: now.add(const Duration(hours: 1)),
          risk: RiskLevel.bajo,
          syncStatus: SyncStatus.synced,
        )
      ]);

      var remoteCalls = 0;
      final repo = AssignmentsRepository(
        localStore: local,
        database: database,
        fetchAssignments: ({required String projectId, required DateTime from, required DateTime to}) async {
          remoteCalls++;
          return [];
        },
      );

      final result = await repo.loadRange(
        projectId: 'TMQ',
        from: now.subtract(const Duration(days: 1)),
        to: now.add(const Duration(days: 1)),
        isOffline: true,
      );

      expect(result.length, 1);
      expect(result.first.id, 'a1');
      expect(remoteCalls, 0);
    });

    test('online refresca remoto y queda synced', () async {
      final local = _FakeAssignmentsLocalStore();
      final database = AppDb();
      addTearDown(database.close);
      final now = DateTime.now();

      await database.into(database.projects).insert(
            ProjectsCompanion.insert(
              id: 'TMQ',
              code: 'TMQ',
              name: 'Tren Mexico Queretaro',
              isActive: const drift.Value(true),
            ),
          );
      await database.into(database.catalogActivityTypes).insert(
            CatalogActivityTypesCompanion.insert(
              id: 'unknown_activity_type',
              code: 'UNKNOWN_ACTIVITY_TYPE',
              name: 'Actividad desconocida',
              requiresPk: const drift.Value(false),
              requiresGeo: const drift.Value(false),
              requiresMinuta: const drift.Value(false),
              requiresEvidence: const drift.Value(false),
              isActive: const drift.Value(true),
              catalogVersion: const drift.Value(1),
            ),
          );

      final repo = AssignmentsRepository(
        localStore: local,
        database: database,
        fetchAssignments: ({required String projectId, required DateTime from, required DateTime to}) async {
          return [
            {
              'id': 'a2',
              'project_id': 'TMQ',
              'assignee_user_id': 'u2',
              'activity_id': 'act2',
              'title': 'Asamblea',
              'frente': 'Frente B',
              'municipio': 'Apaseo',
              'estado': 'Guanajuato',
              'pk': 34000,
              'start_at': now.toIso8601String(),
              'end_at': now.add(const Duration(hours: 2)).toIso8601String(),
              'risk': 'medio',
            }
          ];
        },
      );

      final result = await repo.loadRange(
        projectId: 'TMQ',
        from: now.subtract(const Duration(days: 1)),
        to: now.add(const Duration(days: 1)),
        isOffline: false,
      );

      expect(result.length, 1);
      expect(result.first.id, 'a2');
      expect(result.first.syncStatus, SyncStatus.synced);
    });
  });
}
