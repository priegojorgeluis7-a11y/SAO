import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sao_windows/data/local/app_db.dart';
import 'package:sao_windows/data/local/dao/activity_dao.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return Directory.systemTemp.createTempSync('sao_field_recovery').path;
      }
      return null;
    });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
  });

  test('getFieldsByKey recovers missing wizard fields from cached sync payload', () async {
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
            id: 'user-1',
            name: 'Usuario Uno',
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

    final now = DateTime(2026, 4, 6, 12, 0);
    await db.into(db.activities).insertOnConflictUpdate(
          ActivitiesCompanion.insert(
            id: 'act-sync-recover',
            projectId: 'TMQ',
            activityTypeId: 'CAMINAMIENTO',
            title: 'Caminamiento',
            createdAt: now,
            createdByUserId: 'user-1',
            status: const drift.Value('RECHAZADA'),
            pk: const drift.Value(145000),
          ),
        );

    await db.into(db.syncQueue).insertOnConflictUpdate(
          SyncQueueCompanion.insert(
            id: 'queue-act-sync-recover',
            entity: 'ACTIVITY',
            entityId: 'act-sync-recover',
            action: 'UPSERT',
            payloadJson: jsonEncode({
              'uuid': 'act-sync-recover',
              'project_id': 'TMQ',
              'pk_start': 145000,
              'execution_state': 'REVISION_PENDIENTE',
              'created_by_user_id': 'user-1',
              'catalog_version_id': 'version-1',
              'activity_type_code': 'CAMINAMIENTO',
              'wizard_payload': {
                'risk_level': 'alto',
                'activity': {'id': 'CAM', 'name': 'Caminamiento'},
                'subcategory': {'id': 'SUB_1', 'name': 'Recorrido'},
                'purpose': {'id': 'PUR_1', 'name': 'Verificación'},
                'topics': [
                  {'id': 'TOP_1', 'name': 'Seguridad'},
                ],
                'attendees': [
                  {
                    'id': 'ATT_1',
                    'name': 'Comunidad',
                    'representative_name': 'Ana López',
                  },
                ],
                'result': {'id': 'RES_1', 'name': 'Con incidencia'},
                'notes': 'Nota recuperada',
                'agreements': ['Acuerdo 1'],
                'location': {
                  'tipo_ubicacion': 'puntual',
                  'pk_inicio': 145000,
                  'estado': 'Guanajuato',
                  'municipio': 'San Luis de la Paz',
                  'colonia': 'Centro',
                  'front_name': 'Frente 1',
                },
              },
            }),
            status: const drift.Value('DONE'),
          ),
        );

    final fields = await ActivityDao(db).getFieldsByKey('act-sync-recover');

    expect(fields['risk_level']?.valueText, equals('alto'));
    expect(fields['activity_type']?.valueText, equals('CAM'));
    expect(fields['subcategory']?.valueText, equals('SUB_1'));
    expect(fields['purpose']?.valueText, equals('PUR_1'));
    expect(fields['result']?.valueText, equals('RES_1'));
    expect(fields['report_notes']?.valueText, equals('Nota recuperada'));
    expect(fields['topics']?.valueJson, contains('TOP_1'));
    expect(fields['attendees']?.valueJson, contains('ATT_1'));
    expect(fields['attendee_representatives']?.valueJson, contains('Ana López'));
    expect(fields['wizard_payload_snapshot']?.valueJson, contains('risk_level'));
  });
}
