import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:sao_windows/data/local/app_db.dart';
import 'package:sao_windows/features/activities/wizard/activity_detail_page.dart';
import 'package:sao_windows/features/home/models/today_activity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  final getIt = GetIt.I;

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return Directory.systemTemp.createTempSync('sao_windows_test').path;
      }
      return null;
    });
  });

  tearDown(() async {
    if (getIt.isRegistered<AppDb>()) {
      final db = getIt<AppDb>();
      getIt.unregister<AppDb>();
      await db.close();
    }
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
  });

  testWidgets('activity detail shows rejection reason and correction comment', (
    tester,
  ) async {
    final db = AppDb();
    getIt.registerSingleton<AppDb>(db);
    final now = DateTime.now();

    await db.into(db.roles).insertOnConflictUpdate(
          const RolesCompanion(
            id: drift.Value(4),
            name: drift.Value('Operativo'),
          ),
        );
    await db.into(db.users).insertOnConflictUpdate(
          UsersCompanion.insert(
            id: 'user-1',
            name: 'Usuario Operativo',
            roleId: 4,
          ),
        );
    await db.into(db.projects).insertOnConflictUpdate(
          ProjectsCompanion.insert(
            id: 'TMQ',
            code: 'TMQ',
            name: 'Tren Mexico Queretaro',
            isActive: const drift.Value(true),
          ),
        );
    await db.into(db.catalogActivityTypes).insertOnConflictUpdate(
          CatalogActivityTypesCompanion.insert(
            id: 'unknown_activity_type',
            code: 'UNKNOWN_ACTIVITY_TYPE',
            name: 'Caminamiento',
            requiresPk: const drift.Value(false),
            requiresGeo: const drift.Value(false),
            requiresMinuta: const drift.Value(false),
            requiresEvidence: const drift.Value(false),
            isActive: const drift.Value(true),
            catalogVersion: const drift.Value(1),
          ),
        );

    await db.into(db.activities).insertOnConflictUpdate(
          ActivitiesCompanion.insert(
            id: 'act-rejected-detail',
            projectId: 'TMQ',
            activityTypeId: 'unknown_activity_type',
            title: 'Caminamiento',
            createdAt: now,
            createdByUserId: 'user-1',
            assignedToUserId: const drift.Value('user-1'),
            status: const drift.Value('RECHAZADA'),
            pk: const drift.Value(20),
          ),
        );

    await db.into(db.activityFields).insertOnConflictUpdate(
          ActivityFieldsCompanion.insert(
            id: 'act-rejected-detail:review_state',
            activityId: 'act-rejected-detail',
            fieldKey: 'review_state',
            valueText: const drift.Value('CHANGES_REQUIRED'),
          ),
        );
    await db.into(db.activityFields).insertOnConflictUpdate(
          ActivityFieldsCompanion.insert(
            id: 'act-rejected-detail:next_action',
            activityId: 'act-rejected-detail',
            fieldKey: 'next_action',
            valueText: const drift.Value('CORREGIR_Y_REENVIAR'),
          ),
        );
    await db.into(db.activityFields).insertOnConflictUpdate(
          ActivityFieldsCompanion.insert(
            id: 'act-rejected-detail:review_reject_reason_code',
            activityId: 'act-rejected-detail',
            fieldKey: 'review_reject_reason_code',
            valueText: const drift.Value('MISSING_INFO'),
          ),
        );
    await db.into(db.activityFields).insertOnConflictUpdate(
          ActivityFieldsCompanion.insert(
            id: 'act-rejected-detail:review_comment',
            activityId: 'act-rejected-detail',
            fieldKey: 'review_comment',
            valueText: const drift.Value('Informacion obligatoria ausente'),
          ),
        );

    await tester.pumpWidget(
      MaterialApp(
        home: ActivityDetailPage(
          projectCode: 'TMQ',
          activity: TodayActivity(
            id: 'act-rejected-detail',
            title: 'Caminamiento',
            frente: 'F3',
            municipio: 'Doctor Mora',
            estado: 'Guanajuato',
            pk: 20,
            status: ActivityStatus.programada,
            createdAt: now,
            isRejected: true,
            reviewState: 'CHANGES_REQUIRED',
            nextAction: 'CORREGIR_Y_REENVIAR',
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Que debes corregir'), findsOneWidget);
    expect(find.text('Falta informacion obligatoria'), findsOneWidget);
    expect(find.text('Informacion obligatoria ausente'), findsOneWidget);
  });

  testWidgets('completed activity detail hides shared summary preview text', (
    tester,
  ) async {
    final db = AppDb();
    getIt.registerSingleton<AppDb>(db);
    final now = DateTime.now();

    await tester.pumpWidget(
      MaterialApp(
        home: ActivityDetailPage(
          projectCode: 'TMQ',
          activity: TodayActivity(
            id: 'act-share-summary',
            title: 'Caminamiento finalizado',
            frente: 'F7',
            municipio: 'San Luis de la Paz',
            estado: 'Guanajuato',
            pk: 142900,
            status: ActivityStatus.hoy,
            createdAt: now,
            executionState: ExecutionState.terminada,
            horaInicio: now.subtract(const Duration(hours: 2)),
            horaFin: now,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Compartir resumen'), findsOneWidget);
    expect(find.text('Copiar resumen'), findsOneWidget);
    expect(find.textContaining('*Proyecto:*'), findsNothing);
  });
}
