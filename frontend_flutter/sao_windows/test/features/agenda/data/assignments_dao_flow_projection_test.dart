import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sao_windows/data/local/app_db.dart';
import 'package:sao_windows/features/agenda/data/assignments_dao.dart';
import 'package:sao_windows/features/agenda/models/agenda_item.dart';

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

  group('AssignmentsDao canonical flow projection', () {
    Future<void> seedActivityParents(AppDb db) async {
      await db.into(db.projects).insert(
            ProjectsCompanion.insert(
              id: 'TMQ',
              code: 'TMQ',
              name: 'Tren Mexico Queretaro',
              isActive: const drift.Value(true),
            ),
          );
      await db.into(db.catalogActivityTypes).insert(
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
      await db.into(db.users).insert(
            UsersCompanion.insert(
              id: 'user-1',
              name: 'Usuario 1',
              roleId: 4,
            ),
          );
      await db.into(db.users).insert(
            UsersCompanion.insert(
              id: 'user-2',
              name: 'Usuario 2',
              roleId: 4,
            ),
          );
    }

    test('queryRange prefers canonical flow fields over local inference', () async {
      final db = AppDb();
      addTearDown(db.close);
      final dao = AssignmentsDao(db);
      final now = DateTime.now();
      await seedActivityParents(db);

      await db.into(db.agendaAssignments).insert(
            AgendaAssignmentsCompanion.insert(
              id: 'asg-1',
              projectId: 'TMQ',
              resourceId: 'user-1',
              activityId: const drift.Value('act-1'),
              title: 'Actividad de prueba',
              frente: const drift.Value('Frente A'),
              municipio: const drift.Value('Toluca'),
              estado: const drift.Value('EDOMEX'),
              pk: const drift.Value(142000),
              startAt: now,
              endAt: now.add(const Duration(hours: 1)),
              syncStatus: const drift.Value('pending'),
            ),
          );

      await db.into(db.activities).insert(
            ActivitiesCompanion.insert(
              id: 'act-1',
              projectId: 'TMQ',
              activityTypeId: 'unknown_activity_type',
              title: 'Actividad de prueba',
              createdAt: now,
              createdByUserId: 'user-1',
              status: const drift.Value('SYNCED'),
            ),
          );

      await db.batch((b) {
        b.insertAll(
          db.activityFields,
          [
            ActivityFieldsCompanion.insert(
              id: 'act-1:operational_state',
              activityId: 'act-1',
              fieldKey: 'operational_state',
              valueText: const drift.Value('EN_CURSO'),
            ),
            ActivityFieldsCompanion.insert(
              id: 'act-1:review_state',
              activityId: 'act-1',
              fieldKey: 'review_state',
              valueText: const drift.Value('CHANGES_REQUIRED'),
            ),
            ActivityFieldsCompanion.insert(
              id: 'act-1:next_action',
              activityId: 'act-1',
              fieldKey: 'next_action',
              valueText: const drift.Value('CORREGIR_Y_REENVIAR'),
            ),
          ],
        );
      });

      final result = await dao.queryRange(
        projectId: 'TMQ',
        from: now.subtract(const Duration(days: 1)),
        to: now.add(const Duration(days: 1)),
      );

      expect(result, hasLength(1));
      expect(result.first.operationalState, 'EN_CURSO');
      expect(result.first.reviewState, 'CHANGES_REQUIRED');
      expect(result.first.nextAction, 'CORREGIR_Y_REENVIAR');
    });

    test('queryRange falls back to local flow inference when canonical fields are absent', () async {
      final db = AppDb();
      addTearDown(db.close);
      final dao = AssignmentsDao(db);
      final now = DateTime.now();
      await seedActivityParents(db);

      await db.into(db.agendaAssignments).insert(
            AgendaAssignmentsCompanion.insert(
              id: 'asg-2',
              projectId: 'TMQ',
              resourceId: 'user-2',
              activityId: const drift.Value('act-2'),
              title: 'Actividad sin canonicos',
              frente: const drift.Value('Frente B'),
              municipio: const drift.Value('Toluca'),
              estado: const drift.Value('EDOMEX'),
              pk: const drift.Value(142500),
              startAt: now,
              endAt: now.add(const Duration(hours: 1)),
              syncStatus: const drift.Value('pending'),
            ),
          );

      await db.into(db.activities).insert(
            ActivitiesCompanion.insert(
              id: 'act-2',
              projectId: 'TMQ',
              activityTypeId: 'unknown_activity_type',
              title: 'Actividad sin canonicos',
              createdAt: now,
              createdByUserId: 'user-2',
              status: const drift.Value('READY_TO_SYNC'),
            ),
          );

      final result = await dao.queryRange(
        projectId: 'TMQ',
        from: now.subtract(const Duration(days: 1)),
        to: now.add(const Duration(days: 1)),
      );

      expect(result, hasLength(1));
      expect(result.first.operationalState, 'PENDIENTE');
      expect(result.first.reviewState, 'NOT_APPLICABLE');
      expect(result.first.nextAction, 'INICIAR_ACTIVIDAD');
      expect(result.first.syncStatus, SyncStatus.pending);
    });

    test('queryRange links assignment activityId to persisted local activity with different id', () async {
      final db = AppDb();
      addTearDown(db.close);
      final dao = AssignmentsDao(db);
      final now = DateTime.now();
      await seedActivityParents(db);

      await db.into(db.agendaAssignments).insert(
            AgendaAssignmentsCompanion.insert(
              id: 'asg-3',
              projectId: 'TMQ',
              resourceId: 'user-1',
              activityId: const drift.Value('remote-act-3'),
              title: 'Actividad enlazada',
              frente: const drift.Value('Frente C'),
              municipio: const drift.Value('Toluca'),
              estado: const drift.Value('EDOMEX'),
              pk: const drift.Value(143000),
              startAt: now,
              endAt: now.add(const Duration(hours: 1)),
              syncStatus: const drift.Value('synced'),
            ),
          );

      await db.into(db.activities).insert(
            ActivitiesCompanion.insert(
              id: 'local-act-3',
              projectId: 'TMQ',
              activityTypeId: 'unknown_activity_type',
              title: 'Actividad enlazada',
              createdAt: now,
              createdByUserId: 'user-1',
              pk: const drift.Value(143000),
              status: const drift.Value('DRAFT'),
              startedAt: drift.Value(now),
            ),
          );

      final result = await dao.queryRange(
        projectId: 'TMQ',
        from: now.subtract(const Duration(days: 1)),
        to: now.add(const Duration(days: 1)),
      );

      expect(result, hasLength(1));
      expect(result.first.activityId, 'remote-act-3');
      expect(result.first.nextAction, 'TERMINAR_ACTIVIDAD');
      expect(result.first.operationalState, 'EN_CURSO');
    });

    test('replaceSyncedInRange preserves started and finished agenda items while removing untouched ones', () async {
      final db = AppDb();
      addTearDown(db.close);
      final dao = AssignmentsDao(db);
      final now = DateTime.now();
      await seedActivityParents(db);

      await db.batch((batch) {
        batch.insertAll(
          db.agendaAssignments,
          [
            AgendaAssignmentsCompanion.insert(
              id: 'asg-started',
              projectId: 'TMQ',
              resourceId: 'user-1',
              activityId: const drift.Value('act-started'),
              title: 'Actividad iniciada',
              frente: const drift.Value('Frente A'),
              municipio: const drift.Value('Toluca'),
              estado: const drift.Value('EDOMEX'),
              pk: const drift.Value(144000),
              startAt: now,
              endAt: now.add(const Duration(hours: 1)),
              syncStatus: const drift.Value('synced'),
            ),
            AgendaAssignmentsCompanion.insert(
              id: 'asg-finished',
              projectId: 'TMQ',
              resourceId: 'user-2',
              activityId: const drift.Value('act-finished'),
              title: 'Actividad terminada',
              frente: const drift.Value('Frente B'),
              municipio: const drift.Value('Toluca'),
              estado: const drift.Value('EDOMEX'),
              pk: const drift.Value(144500),
              startAt: now,
              endAt: now.add(const Duration(hours: 1)),
              syncStatus: const drift.Value('synced'),
            ),
            AgendaAssignmentsCompanion.insert(
              id: 'asg-untouched',
              projectId: 'TMQ',
              resourceId: 'user-2',
              activityId: const drift.Value('act-untouched'),
              title: 'Actividad intacta',
              frente: const drift.Value('Frente C'),
              municipio: const drift.Value('Toluca'),
              estado: const drift.Value('EDOMEX'),
              pk: const drift.Value(145000),
              startAt: now,
              endAt: now.add(const Duration(hours: 1)),
              syncStatus: const drift.Value('synced'),
            ),
          ],
        );

        batch.insertAll(
          db.activities,
          [
            ActivitiesCompanion.insert(
              id: 'act-started',
              projectId: 'TMQ',
              activityTypeId: 'unknown_activity_type',
              title: 'Actividad iniciada',
              createdAt: now,
              createdByUserId: 'user-1',
              status: const drift.Value('DRAFT'),
              startedAt: drift.Value(now),
            ),
            ActivitiesCompanion.insert(
              id: 'act-finished',
              projectId: 'TMQ',
              activityTypeId: 'unknown_activity_type',
              title: 'Actividad terminada',
              createdAt: now,
              createdByUserId: 'user-2',
              status: const drift.Value('REVISION_PENDIENTE'),
              startedAt: drift.Value(now.subtract(const Duration(minutes: 30))),
              finishedAt: drift.Value(now),
            ),
            ActivitiesCompanion.insert(
              id: 'act-untouched',
              projectId: 'TMQ',
              activityTypeId: 'unknown_activity_type',
              title: 'Actividad intacta',
              createdAt: now,
              createdByUserId: 'user-2',
              status: const drift.Value('SYNCED'),
            ),
          ],
        );
      });

      await dao.replaceSyncedInRange(
        projectId: 'TMQ',
        from: now.subtract(const Duration(days: 1)),
        to: now.add(const Duration(days: 1)),
        records: const [],
      );

      final result = await dao.queryRange(
        projectId: 'TMQ',
        from: now.subtract(const Duration(days: 1)),
        to: now.add(const Duration(days: 1)),
      );

      expect(result.map((item) => item.id), containsAll(<String>['asg-started', 'asg-finished']));
      expect(result.map((item) => item.id), isNot(contains('asg-untouched')));
      expect(
        result.firstWhere((item) => item.id == 'asg-started').nextAction,
        'TERMINAR_ACTIVIDAD',
      );
      expect(
        result.firstWhere((item) => item.id == 'asg-finished').nextAction,
        'COMPLETAR_WIZARD',
      );
    });

    test('replaceSyncedInRange preserves approved finished items even when omitted remotely', () async {
      final db = AppDb();
      addTearDown(db.close);
      final dao = AssignmentsDao(db);
      final now = DateTime.now();
      await seedActivityParents(db);

      await db.batch((batch) {
        batch.insert(
          db.agendaAssignments,
          AgendaAssignmentsCompanion.insert(
            id: 'asg-approved-deleted',
            projectId: 'TMQ',
            resourceId: 'user-1',
            activityId: const drift.Value('act-approved-deleted'),
            title: 'Actividad aprobada y borrada',
            frente: const drift.Value('Frente Z'),
            municipio: const drift.Value('Toluca'),
            estado: const drift.Value('EDOMEX'),
            pk: const drift.Value(146000),
            startAt: now,
            endAt: now.add(const Duration(hours: 1)),
            syncStatus: const drift.Value('synced'),
          ),
        );

        batch.insert(
          db.activities,
          ActivitiesCompanion.insert(
            id: 'act-approved-deleted',
            projectId: 'TMQ',
            activityTypeId: 'unknown_activity_type',
            title: 'Actividad aprobada y borrada',
            createdAt: now,
            createdByUserId: 'user-1',
            status: const drift.Value('SYNCED'),
            startedAt: drift.Value(now.subtract(const Duration(minutes: 45))),
            finishedAt: drift.Value(now.subtract(const Duration(minutes: 5))),
          ),
        );
      });

      await db.batch((batch) {
        batch.insert(
          db.activityFields,
          ActivityFieldsCompanion.insert(
            id: 'act-approved-deleted:review_state',
            activityId: 'act-approved-deleted',
            fieldKey: 'review_state',
            valueText: const drift.Value('APPROVED'),
          ),
        );
        batch.insert(
          db.activityFields,
          ActivityFieldsCompanion.insert(
            id: 'act-approved-deleted:next_action',
            activityId: 'act-approved-deleted',
            fieldKey: 'next_action',
            valueText: const drift.Value('CERRADA_APROBADA'),
          ),
        );
      });

      await dao.replaceSyncedInRange(
        projectId: 'TMQ',
        from: now.subtract(const Duration(days: 1)),
        to: now.add(const Duration(days: 1)),
        records: const [],
      );

      final result = await dao.queryRange(
        projectId: 'TMQ',
        from: now.subtract(const Duration(days: 1)),
        to: now.add(const Duration(days: 1)),
      );

      expect(result.map((item) => item.id), contains('asg-approved-deleted'));
      expect(
        result.firstWhere((item) => item.id == 'asg-approved-deleted').nextAction,
        'CERRADA_APROBADA',
      );
    });

    test('queryRange falls back to persisted assignee when assignment resource is unassigned', () async {
      final db = AppDb();
      addTearDown(db.close);
      final dao = AssignmentsDao(db);
      final now = DateTime.now();
      await seedActivityParents(db);

      await db.into(db.agendaAssignments).insert(
            AgendaAssignmentsCompanion.insert(
              id: 'asg-unassigned',
              projectId: 'TMQ',
              resourceId: 'unassigned',
              activityId: const drift.Value('act-unassigned'),
              title: 'Actividad visible para user-1',
              frente: const drift.Value('Frente D'),
              municipio: const drift.Value('Toluca'),
              estado: const drift.Value('EDOMEX'),
              pk: const drift.Value(145500),
              startAt: now,
              endAt: now.add(const Duration(hours: 1)),
              syncStatus: const drift.Value('synced'),
            ),
          );

      await db.into(db.activities).insert(
            ActivitiesCompanion.insert(
              id: 'act-unassigned',
              projectId: 'TMQ',
              activityTypeId: 'unknown_activity_type',
              title: 'Actividad visible para user-1',
              createdAt: now,
              createdByUserId: 'user-1',
              assignedToUserId: const drift.Value('user-1'),
              status: const drift.Value('SYNCED'),
            ),
          );

      final result = await dao.queryRange(
        projectId: 'TMQ',
        from: now.subtract(const Duration(days: 1)),
        to: now.add(const Duration(days: 1)),
      );

      expect(result, hasLength(1));
      expect(result.first.resourceId, 'user-1');
    });
  });
}
