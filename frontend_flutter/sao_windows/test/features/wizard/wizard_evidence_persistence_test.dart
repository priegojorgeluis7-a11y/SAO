import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sao_windows/core/auth/token_storage.dart';
import 'package:sao_windows/core/network/api_client.dart';
import 'package:sao_windows/data/local/app_db.dart';
import 'package:sao_windows/features/activities/wizard/wizard_controller.dart';
import 'package:sao_windows/features/catalog/catalog_repository.dart';
import 'package:sao_windows/features/evidence/data/evidence_upload_repository.dart';
import 'package:sao_windows/features/evidence/data/evidence_upload_retry_worker.dart';
import 'package:sao_windows/features/evidence/pending_evidence_store.dart';
import 'package:sao_windows/features/home/models/today_activity.dart';

class _FlakyEvidenceUploadRepository extends EvidenceUploadRepository {
  int initCalls = 0;
  int uploadCalls = 0;
  int completeCalls = 0;
  String? lastCompletedDescription;

  _FlakyEvidenceUploadRepository({required AppDb db})
    : super(
        db: db,
        apiClient: ApiClient(
          tokenStorage: TokenStorage(const FlutterSecureStorage()),
        ),
      );

  @override
  Future<UploadInitResult> uploadInit({
    required String activityId,
    required String mimeType,
    required int sizeBytes,
    required String fileName,
  }) async {
    initCalls += 1;
    if (initCalls == 1) {
      throw StateError('transient upload-init failure');
    }

    return const UploadInitResult(
      evidenceId: 'ev-retry-1',
      objectPath: 'activities/act-upload-retry/evidences/retry.jpg',
      signedUrl: 'https://example.invalid/upload/retry.jpg',
      expiresAt: null,
    );
  }

  @override
  Future<void> uploadBytesToSignedUrl({
    required String signedUrl,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    uploadCalls += 1;
  }

  @override
  Future<void> uploadComplete({
    required String evidenceId,
    String? description,
  }) async {
    completeCalls += 1;
    lastCompletedDescription = description;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
          if (call.method == 'getApplicationDocumentsDirectory') {
            return Directory.systemTemp
                .createTempSync('sao_wizard_evidence')
                .path;
          }
          return null;
        });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
  });

  Future<void> seedCoreData(AppDb db) async {
    await db
        .into(db.roles)
        .insertOnConflictUpdate(
          const RolesCompanion(
            id: drift.Value(4),
            name: drift.Value('Operativo'),
          ),
        );
    await db
        .into(db.users)
        .insertOnConflictUpdate(
          UsersCompanion.insert(
            id: 'user-1',
            name: 'Usuario Operativo',
            roleId: 4,
          ),
        );
    await db
        .into(db.projects)
        .insertOnConflictUpdate(
          ProjectsCompanion.insert(
            id: 'TMQ',
            code: 'TMQ',
            name: 'Tren Mexico Queretaro',
            isActive: const drift.Value(true),
          ),
        );
    await db
        .into(db.catalogActivityTypes)
        .insertOnConflictUpdate(
          CatalogActivityTypesCompanion.insert(
            id: 'CAMINAMIENTO',
            code: 'CAMINAMIENTO',
            name: 'Caminamiento',
            requiresPk: const drift.Value(false),
            requiresGeo: const drift.Value(false),
            requiresMinuta: const drift.Value(false),
            requiresEvidence: const drift.Value(true),
            isActive: const drift.Value(true),
            catalogVersion: const drift.Value(1),
          ),
        );
  }

  WizardController buildController(AppDb db, {required String activityId}) {
    return WizardController(
      activity: TodayActivity(
        id: activityId,
        title: 'Caminamiento',
        frente: 'Frente 1',
        municipio: 'San Luis de la Paz',
        estado: 'Guanajuato',
        status: ActivityStatus.hoy,
        createdAt: DateTime(2026, 4, 6, 9, 0),
      ),
      projectCode: 'TMQ',
      catalogRepo: CatalogRepository(),
      pendingStore: PendingEvidenceStore(),
      database: db,
      currentUserId: 'user-1',
    );
  }

  void fillRequiredFields(WizardController controller) {
    controller.setRisk(RiskLevel.medio);
    controller.setHoraInicio(const TimeOfDay(hour: 9, minute: 0));
    controller.setHoraFin(const TimeOfDay(hour: 10, minute: 0));
    controller.setMunicipio('San Luis de la Paz');
    controller.setColonia('Centro');
    controller.setActivity(
      const CatItem(
        id: 'CAMINAMIENTO',
        label: 'Caminamiento',
        icon: Icons.directions_walk_rounded,
      ),
    );
    controller.setSubcategory(
      const CatItem(
        id: 'SUB_1',
        label: 'Subcategoría',
        icon: Icons.category_rounded,
      ),
    );
    controller.toggleTopic('TOP_1');
    controller.toggleAttendee('ATT_1');
    controller.setResult(
      const CatItem(
        id: 'RES_1',
        label: 'Resultado',
        icon: Icons.check_circle_rounded,
      ),
    );
  }

  test(
    'saveToDatabase queues captured photos for upload and persists them locally',
    () async {
      final db = AppDb();
      addTearDown(() => db.close());
      await seedCoreData(db);

      final controller = buildController(db, activityId: 'act-evidence-save');
      fillRequiredFields(controller);

      final tempDir = await Directory.systemTemp.createTemp(
        'sao_evidence_file',
      );
      final photo = File('${tempDir.path}/evidence.jpg');
      await photo.writeAsBytes(const [1, 2, 3, 4, 5]);

      controller.addPhoto(photo.path);
      controller.updateDescripcion(0, 'Foto de evidencia');

      final activityId = await controller.saveToDatabase();

      final evidences = await (db.select(
        db.evidences,
      )..where((t) => t.activityId.equals(activityId))).get();
      expect(evidences, hasLength(1));
      expect(evidences.first.filePathLocal, equals(photo.path));
      expect(evidences.first.caption, equals('Foto de evidencia'));

      final pendingUploads = await (db.select(
        db.pendingUploads,
      )..where((t) => t.activityId.equals(activityId))).get();
      expect(pendingUploads, hasLength(1));
      expect(pendingUploads.first.localPath, equals(photo.path));

      final snapshotField =
          await (db.select(db.activityFields)..where(
                (t) =>
                    t.activityId.equals(activityId) &
                    t.fieldKey.equals('wizard_payload_snapshot'),
              ))
              .getSingleOrNull();
      expect(snapshotField?.valueJson, contains('evidences'));
    },
  );

  test(
    'init recovers evidence list from wizard snapshot when local rows are missing',
    () async {
      final db = AppDb();
      addTearDown(() => db.close());
      await seedCoreData(db);

      final now = DateTime(2026, 4, 6, 11, 30);
      final tempDir = await Directory.systemTemp.createTemp(
        'sao_snapshot_evidence',
      );
      final photoPath = '${tempDir.path}/recover.jpg';
      await File(photoPath).writeAsBytes(const [7, 8, 9]);

      await db
          .into(db.activities)
          .insertOnConflictUpdate(
            ActivitiesCompanion.insert(
              id: 'act-evidence-recover',
              projectId: 'TMQ',
              activityTypeId: 'CAMINAMIENTO',
              title: 'Caminamiento',
              createdAt: now,
              createdByUserId: 'user-1',
              status: const drift.Value('RECHAZADA'),
              pk: const drift.Value(145000),
            ),
          );

      await db
          .into(db.activityFields)
          .insertOnConflictUpdate(
            ActivityFieldsCompanion.insert(
              id: 'act-evidence-recover:wizard_payload_snapshot',
              activityId: 'act-evidence-recover',
              fieldKey: 'wizard_payload_snapshot',
              valueJson: drift.Value(
                jsonEncode({
                  'risk_level': 'medio',
                  'activity': {'id': 'CAMINAMIENTO', 'name': 'Caminamiento'},
                  'subcategory': {'id': 'SUB_1', 'name': 'Subcategoría'},
                  'result': {'id': 'RES_1', 'name': 'Resultado'},
                  'evidences': [
                    {
                      'localPath': photoPath,
                      'descripcion': 'Evidencia recuperada',
                      'createdAt': now.toIso8601String(),
                      'lat': 21.0,
                      'lng': -100.0,
                    },
                  ],
                }),
              ),
            ),
          );

      final controller = buildController(
        db,
        activityId: 'act-evidence-recover',
      );
      await controller.init();

      expect(controller.evidencias, hasLength(1));
      expect(controller.evidencias.first.localPath, equals(photoPath));
      expect(
        controller.evidencias.first.descripcion,
        equals('Evidencia recuperada'),
      );

      final dbEvidences = await (db.select(
        db.evidences,
      )..where((t) => t.activityId.equals('act-evidence-recover'))).get();
      expect(dbEvidences, hasLength(1));
      expect(dbEvidences.first.caption, equals('Evidencia recuperada'));
    },
  );

  test(
    'retry worker resumes pending evidence uploads after a transient init failure',
    () async {
      final db = AppDb();
      addTearDown(() => db.close());
      await seedCoreData(db);

      final now = DateTime(2026, 4, 6, 12, 0);
      await db
          .into(db.activities)
          .insertOnConflictUpdate(
            ActivitiesCompanion.insert(
              id: 'act-upload-retry',
              projectId: 'TMQ',
              activityTypeId: 'CAMINAMIENTO',
              title: 'Actividad con reintento',
              createdAt: now,
              createdByUserId: 'user-1',
              status: const drift.Value('SYNCED'),
              pk: const drift.Value(150000),
            ),
          );

      final tempDir = await Directory.systemTemp.createTemp(
        'sao_evidence_retry',
      );
      final photo = File('${tempDir.path}/retry.jpg');
      await photo.writeAsBytes(const [5, 4, 3, 2, 1]);

      await db.into(db.evidences).insert(
        EvidencesCompanion.insert(
          id: 'evidence-retry-1',
          activityId: 'act-upload-retry',
          type: 'PHOTO',
          filePathLocal: photo.path,
          caption: const drift.Value('Foto con pie de foto persistente'),
          status: const drift.Value('QUEUED'),
        ),
      );

      await db.into(db.pendingUploads).insert(
        PendingUploadsCompanion.insert(
          id: 'upload-retry-1',
          activityId: 'act-upload-retry',
          localPath: photo.path,
          fileName: 'retry.jpg',
          mimeType: 'image/jpeg',
          sizeBytes: await photo.length(),
          status: const drift.Value('PENDING_INIT'),
          nextRetryAt: drift.Value(
            DateTime.now().subtract(const Duration(minutes: 1)),
          ),
        ),
      );

      final repository = _FlakyEvidenceUploadRepository(db: db);
      final worker = EvidenceUploadRetryWorker(
        db: db,
        repository: repository,
        interval: const Duration(hours: 1),
      );

      await worker.processDueUploads();

      var row = await (db.select(
        db.pendingUploads,
      )..where((t) => t.id.equals('upload-retry-1'))).getSingle();
      expect(row.status, equals('ERROR'));

      await worker.processDueUploads(ignoreRetrySchedule: true);

      row = await (db.select(
        db.pendingUploads,
      )..where((t) => t.id.equals('upload-retry-1'))).getSingle();
      expect(row.status, equals('DONE'));
      expect(repository.initCalls, equals(2));
      expect(repository.uploadCalls, equals(1));
      expect(repository.completeCalls, equals(1));
      expect(
        repository.lastCompletedDescription,
        equals('Foto con pie de foto persistente'),
      );
    },
  );
}
