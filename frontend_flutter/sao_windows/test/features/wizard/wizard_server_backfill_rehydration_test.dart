import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:sao_windows/data/local/app_db.dart';
import 'package:sao_windows/data/local/dao/activity_dao.dart';
import 'package:sao_windows/features/activities/wizard/wizard_controller.dart';
import 'package:sao_windows/features/catalog/catalog_repository.dart';
import 'package:sao_windows/features/evidence/pending_evidence_store.dart';
import 'package:sao_windows/features/home/models/today_activity.dart';
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
      currentVersion: 16,
      hasMore: false,
      nextSinceVersion: 16,
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
  final getIt = GetIt.I;

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return Directory.systemTemp.createTempSync('sao_wizard_server_backfill').path;
      }
      return null;
    });
  });

  tearDown(() async {
    if (getIt.isRegistered<SyncService>()) {
      getIt.unregister<SyncService>();
    }
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
  });

  test('wizard init backfills missing rejected fields from backend sync payload', () async {
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

    final now = DateTime.now();
    await db.into(db.activities).insertOnConflictUpdate(
          ActivitiesCompanion.insert(
            id: 'act-rejected-backfill',
            projectId: 'TMQ',
            activityTypeId: 'CAMINAMIENTO',
            title: 'Caminamiento',
            createdAt: now,
            createdByUserId: 'user-1',
            status: const drift.Value('RECHAZADA'),
            pk: const drift.Value(145000),
            serverRevision: const drift.Value(16),
          ),
        );

    Future<void> insertField(String key, String text) {
      return db.into(db.activityFields).insertOnConflictUpdate(
            ActivityFieldsCompanion.insert(
              id: 'act-rejected-backfill:$key',
              activityId: 'act-rejected-backfill',
              fieldKey: key,
              valueText: drift.Value(text),
            ),
          );
    }

    await insertField('review_state', 'CHANGES_REQUIRED');
    await insertField('next_action', 'CORREGIR_Y_REENVIAR');

    getIt.registerSingleton<SyncService>(
      SyncService(
        apiRepository: _FakeSyncApiRepository([
          ActivityDTO(
            uuid: 'act-rejected-backfill',
            projectId: 'TMQ',
            pkStart: 145000,
            executionState: 'REVISION_PENDIENTE',
            reviewDecision: 'CHANGES_REQUIRED',
            reviewRejectReasonCode: 'MISSING_INFO',
            reviewComment: 'Informacion obligatoria ausente',
            createdByUserId: 'user-1',
            assignedToUserId: 'user-1',
            catalogVersionId: 'version-1',
            activityTypeCode: 'CAMINAMIENTO',
            title: 'Caminamiento',
            description: 'Actividad: Caminamiento',
            wizardPayload: {
              'risk_level': 'medio',
              'activity': {'id': 'CAM', 'name': 'Caminamiento'},
              'subcategory': {'id': 'CAM_MAR', 'name': 'Marcaje de afectaciones'},
              'purpose': {'id': 'PRO_1', 'name': 'Verificación'},
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
              'result': {
                'id': 'R03',
                'name': 'Sin quórum / segunda convocatoria programada',
              },
              'notes': 'Dato recuperado desde backend',
              'agreements': ['Acuerdo recuperado'],
              'location': {
                'tipo_ubicacion': 'puntual',
                'pk_inicio': 145000,
                'estado': 'Guanajuato',
                'municipio': 'San Luis de la Paz',
                'colonia': 'Centro',
                'front_name': 'Frente 1',
              },
            },
            createdAt: now.toUtc(),
            updatedAt: now.toUtc(),
            syncVersion: 16,
          ),
        ]),
        db: db,
      ),
    );

    final controller = WizardController(
      activity: TodayActivity(
        id: 'act-rejected-backfill',
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
      currentUserId: 'user-1',
    );

    await controller.init();

    expect(controller.risk, equals(RiskLevel.medio));
    expect(controller.reportNotes, equals('Dato recuperado desde backend'));

    final fields = await ActivityDao(db).getFieldsByKey('act-rejected-backfill');
    expect(fields['risk_level']?.valueText, equals('medio'));
    expect(fields['wizard_payload_snapshot']?.valueJson, contains('risk_level'));
  });
}
