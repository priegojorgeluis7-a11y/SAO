import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sao_windows/data/local/app_db.dart';
import 'package:sao_windows/data/local/dao/activity_dao.dart';
import 'package:sao_windows/features/sync/data/sync_api_repository.dart';
import 'package:sao_windows/features/sync/models/sync_dto.dart';
import 'package:sao_windows/features/sync/services/sync_service.dart';

class _FakeSyncApiRepository implements SyncApiRepository {
  _FakeSyncApiRepository(this._activities);

  final List<ActivityDTO> _activities;

  @override
  Future<SyncPullResponse> pullActivities({
    required String projectId,
    int sinceVersion = 0,
    String? afterUuid,
    int limit = 200,
    int? untilVersion,
  }) async {
    return SyncPullResponse(
      currentVersion: 7,
      hasMore: false,
      nextSinceVersion: 7,
      nextAfterUuid: null,
      activities: _activities,
    );
  }

  @override
  Future<SyncPushResponse> pushActivities({
    required String projectId,
    required List<ActivityDTO> activities,
    bool forceOverride = false,
  }) async {
    return const SyncPushResponse(results: []);
  }

  @override
  Future<String?> resolveCatalogVersionUuid({required String projectId}) async => null;

  @override
  Future<SyncStatus> getSyncStatus(String projectId) async {
    return const SyncStatus(
      lastSyncVersion: 0,
      lastSyncAt: null,
      pendingPullCount: 0,
      pendingPushCount: 0,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return Directory.systemTemp.createTempSync('sao_sync_test').path;
      }
      return null;
    });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
  });

  test('pull sync persists wizard payload fields so they survive across views', () async {
    final db = AppDb();
    addTearDown(() => db.close());

    final now = DateTime.now().toUtc();

    await db.into(db.roles).insertOnConflictUpdate(
          const RolesCompanion(
            id: drift.Value(4),
            name: drift.Value('Operativo'),
          ),
        );
    await db.into(db.users).insertOnConflictUpdate(
          UsersCompanion.insert(
            id: '550e8400-e29b-41d4-a716-446655440010',
            name: 'Usuario Creador',
            roleId: 4,
          ),
        );
    await db.into(db.users).insertOnConflictUpdate(
          UsersCompanion.insert(
            id: '550e8400-e29b-41d4-a716-446655440011',
            name: 'Usuario Asignado',
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
    await db.into(db.catalogVersions).insertOnConflictUpdate(
          CatalogVersionsCompanion.insert(
            id: '550e8400-e29b-41d4-a716-446655440012',
            projectId: const drift.Value('TMQ'),
            versionNumber: 1,
            publishedAt: drift.Value(now),
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

    final service = SyncService(
      apiRepository: _FakeSyncApiRepository([
        ActivityDTO(
          uuid: 'act-wizard-001',
          projectId: 'TMQ',
          pkStart: 145000,
          executionState: 'COMPLETADA',
          createdByUserId: '550e8400-e29b-41d4-a716-446655440010',
          assignedToUserId: '550e8400-e29b-41d4-a716-446655440011',
          catalogVersionId: '550e8400-e29b-41d4-a716-446655440012',
          activityTypeCode: 'CAMINAMIENTO',
          title: 'Caminamiento',
          description: 'Actividad: Caminamiento | Resultado: Con incidencia',
          wizardPayload: {
            'risk_level': 'alto',
            'activity': {'id': 'CAM', 'name': 'Caminamiento'},
            'subcategory': {
              'id': 'SUB_CAM',
              'name': 'Recorrido en vía',
              'other_text': 'Otro detalle',
            },
            'purpose': {'id': 'PURP_1', 'name': 'Verificación'},
            'topics': [
              {'id': 'T1', 'name': 'Seguridad'},
              {'id': 'T2', 'name': 'Operación'},
            ],
            'topic_other_text': 'Tema adicional',
            'attendees': [
              {
                'id': 'A1',
                'name': 'Comunidad',
                'representative_name': 'Juan Pérez',
              },
            ],
            'result': {'id': 'R1', 'name': 'Con incidencia'},
            'notes': 'Se detectó un riesgo alto en el recorrido.',
            'agreements': ['Levantar señalización', 'Notificar al frente'],
            'location': {
              'tipo_ubicacion': 'puntual',
              'pk_inicio': 145000,
              'estado': 'Guanajuato',
              'municipio': 'San Luis de la Paz',
              'colonia': 'Centro',
              'front_id': 'front-1',
              'front_name': 'Frente 1',
            },
          },
          createdAt: now,
          updatedAt: now,
          syncVersion: 7,
        ),
      ]),
      db: db,
    );

    await service.pullChanges(projectId: 'TMQ', resetActivityCursor: true);

    final fields = await ActivityDao(db).getFieldsByKey('act-wizard-001');

    expect(fields['risk_level']?.valueText, equals('alto'));
    expect(fields['activity_type']?.valueText, equals('CAM'));
    expect(fields['subcategory']?.valueText, equals('SUB_CAM'));
    expect(fields['purpose']?.valueText, equals('PURP_1'));
    expect(fields['result']?.valueText, equals('R1'));
    expect(fields['topic_other_text']?.valueText, equals('Tema adicional'));
    expect(fields['report_notes']?.valueText, equals('Se detectó un riesgo alto en el recorrido.'));
    expect(fields['front_name']?.valueText, equals('Frente 1'));
    expect(fields['draft_tipo_ubicacion']?.valueText, equals('puntual'));
    expect(fields['draft_pk_inicio']?.valueText, equals('145000'));
    expect(fields['topics']?.valueJson, contains('T1'));
    expect(fields['attendees']?.valueJson, contains('A1'));
    expect(
      fields['attendee_representatives']?.valueJson,
      contains('Juan Pérez'),
    );
    expect(fields['report_agreements']?.valueJson, contains('Levantar señalización'));
  });
}
