import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sao_windows/data/local/app_db.dart';
import 'package:sao_windows/features/activities/wizard/wizard_controller.dart';
import 'package:sao_windows/features/catalog/catalog_repository.dart';
import 'package:sao_windows/features/evidence/pending_evidence_store.dart';
import 'package:sao_windows/features/home/models/today_activity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return Directory.systemTemp.createTempSync('sao_wizard_guard').path;
      }
      return null;
    });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
  });

  test('saveDraftSilently does not erase existing wizard fields while controller is still loading', () async {
    final db = AppDb();
    addTearDown(() => db.close());

    await db.into(db.roles).insertOnConflictUpdate(
          const RolesCompanion(
            id: drift.Value(4),
            name: drift.Value('Operativo'),
          ),
        );
    await db.into(db.users).insertOnConflictUpdate(
          UsersCompanion.insert(
            id: 'test-user',
            name: 'Usuario Test',
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
            id: 'CAMINAMIENTO',
            code: 'CAMINAMIENTO',
            name: 'Caminamiento',
            requiresPk: const drift.Value(false),
            requiresGeo: const drift.Value(false),
            requiresMinuta: const drift.Value(false),
            requiresEvidence: const drift.Value(false),
            isActive: const drift.Value(true),
            catalogVersion: const drift.Value(1),
          ),
        );

    final now = DateTime(2026, 4, 6, 10, 30);
    await db.into(db.activities).insertOnConflictUpdate(
          ActivitiesCompanion.insert(
            id: 'act-rejected-guard',
            projectId: 'TMQ',
            activityTypeId: 'CAMINAMIENTO',
            title: 'Caminamiento',
            createdAt: now,
            createdByUserId: 'test-user',
            status: const drift.Value('RECHAZADA'),
            pk: const drift.Value(145000),
          ),
        );

    Future<void> insertField(String key, {String? text, String? json}) {
      return db.into(db.activityFields).insertOnConflictUpdate(
            ActivityFieldsCompanion.insert(
              id: 'act-rejected-guard:$key',
              activityId: 'act-rejected-guard',
              fieldKey: key,
              valueText: drift.Value(text),
              valueJson: drift.Value(json),
            ),
          );
    }

    await insertField('risk_level', text: 'alto');
    await insertField('report_notes', text: 'Nota importante');
    await insertField('review_state', text: 'CHANGES_REQUIRED');

    final controller = WizardController(
      activity: TodayActivity(
        id: 'act-rejected-guard',
        title: 'Caminamiento',
        frente: 'Frente 1',
        municipio: 'San Luis de la Paz',
        estado: 'Guanajuato',
        status: ActivityStatus.hoy,
        createdAt: now,
        isRejected: true,
        reviewState: 'CHANGES_REQUIRED',
        nextAction: 'CORREGIR_Y_REENVIAR',
      ),
      projectCode: 'TMQ',
      catalogRepo: CatalogRepository(),
      pendingStore: PendingEvidenceStore(),
      database: db,
      currentUserId: 'test-user',
    );

    expect(controller.loading, isTrue);

    await controller.saveDraftSilently();

    final fields = await controller.database
        .select(controller.database.activityFields)
        .get();
    final byKey = {for (final field in fields) field.fieldKey: field};

    expect(byKey['risk_level']?.valueText, equals('alto'));
    expect(byKey['report_notes']?.valueText, equals('Nota importante'));
    expect(byKey['review_state']?.valueText, equals('CHANGES_REQUIRED'));
  });
}
