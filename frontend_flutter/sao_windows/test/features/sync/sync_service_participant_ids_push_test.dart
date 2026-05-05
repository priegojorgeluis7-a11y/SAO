// test/features/sync/sync_service_participant_ids_push_test.dart
//
// Verifica que participantUserIds (co-responsables) se preserve durante
// la normalización del SyncService al hacer push, incluso cuando otros
// campos del DTO (e.g. catalog_version_id) necesitan ser resueltos.
//
// Regresión para el bug donde _normalizePendingItem omitía participantUserIds
// al construir normalizedDto, perdiendo los co-responsables en el push.

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sao_windows/data/local/app_db.dart';
import 'package:sao_windows/features/sync/data/sync_api_repository.dart';
import 'package:sao_windows/features/sync/models/sync_dto.dart';
import 'package:sao_windows/features/sync/services/sync_service.dart';

class _CapturingSyncApiRepository implements SyncApiRepository {
  final List<ActivityDTO> capturedActivities = [];

  @override
  Future<SyncPullResponse> pullActivities({
    required String projectId,
    int sinceVersion = 0,
    String? afterUuid,
    int limit = 200,
    int? untilVersion,
  }) async {
    return const SyncPullResponse(
      currentVersion: 0,
      hasMore: false,
      nextSinceVersion: 0,
      nextAfterUuid: null,
      activities: [],
    );
  }

  @override
  Future<SyncPushResponse> pushActivities({
    required String projectId,
    required List<ActivityDTO> activities,
    bool forceOverride = false,
  }) async {
    capturedActivities.addAll(activities);
    // Return CREATED for all items so they are marked done.
    return SyncPushResponse(
      results: activities
          .map((a) => SyncPushResultItem(uuid: a.uuid, status: 'CREATED', syncVersion: 1))
          .toList(),
    );
  }

  @override
  Future<String?> resolveCatalogVersionUuid({required String projectId}) async =>
      null;

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
      if (call.method == 'getApplicationDocumentsDirectory' ||
          call.method == 'getTemporaryDirectory') {
        return Directory.systemTemp.createTempSync('sao_participant_ids_test').path;
      }
      return null;
    });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
  });

  test(
    'pushPendingChanges preserves participantUserIds when normalization resolves catalogVersionId',
    () async {
      final db = AppDb();
      addTearDown(db.close);

      final now = DateTime.now().toUtc();

      // ── Seed DB ──────────────────────────────────────────────────────────
      await db.into(db.roles).insertOnConflictUpdate(
            const RolesCompanion(
              id: drift.Value(4),
              name: drift.Value('Operativo'),
            ),
          );
      const userCreatorId = '550e8400-e29b-41d4-a716-446655440010';
      const userAssigneeId = '550e8400-e29b-41d4-a716-446655440011';
      const userCoResponsableId = '550e8400-e29b-41d4-a716-446655440022';

      for (final entry in [
        (userCreatorId, 'Creador'),
        (userAssigneeId, 'Asignado'),
        (userCoResponsableId, 'Co-responsable'),
      ]) {
        await db.into(db.users).insertOnConflictUpdate(
              UsersCompanion.insert(
                id: entry.$1,
                name: entry.$2,
                roleId: 4,
              ),
            );
      }

      // ── Build sync queue payload
      // - frontId is a non-UUID string → _sanitizeOptionalUuid returns null
      //   so normalizedFrontId != dto.frontId → normalization update IS triggered
      // - catalogVersionId is a non-UUID non-empty string → returned as-is
      // - activityTypeCode is a valid uppercase code → returned as-is
      // Together these ensure _normalizePendingItem writes normalizedDto back to DB,
      // which is the exact code path where participantUserIds was previously dropped.
      const activityId = '550e8400-e29b-41d4-a716-446655440099';
      final payload = ActivityDTO(
        uuid: activityId,
        projectId: 'TMQ',
        pkStart: 10000,
        executionState: 'COMPLETADA',
        assignedToUserId: userAssigneeId,
        participantUserIds: [userAssigneeId, userCoResponsableId],
        createdByUserId: userCreatorId,
        catalogVersionId: 'tmq-v1.0', // non-UUID → returned as-is, no change
        activityTypeCode: 'CAMINAMIENTO', // valid code → returned as-is
        frontId: 'frente-ref-no-es-uuid', // non-UUID → sanitized to null → CHANGE detected
        title: 'Caminamiento con co-responsable',
        createdAt: now,
        updatedAt: now,
        syncVersion: 0,
      );

      await db.into(db.syncQueue).insert(
            SyncQueueCompanion.insert(
              id: 'sq-participant-test-001',
              entity: 'ACTIVITY',
              entityId: activityId,
              action: 'UPSERT',
              payloadJson: jsonEncode(payload.toJson()),
              status: const drift.Value('PENDING'),
            ),
          );

      // ── Run push ──────────────────────────────────────────────────────────
      final apiRepo = _CapturingSyncApiRepository();
      final service = SyncService(apiRepository: apiRepo, db: db);

      await service.pushPendingChanges();

      // ── Assert ────────────────────────────────────────────────────────────
      expect(
        apiRepo.capturedActivities,
        isNotEmpty,
        reason: 'pushPendingChanges should have pushed the queued activity',
      );

      final sent = apiRepo.capturedActivities.first;
      expect(
        sent.participantUserIds,
        containsAll([userAssigneeId, userCoResponsableId]),
        reason:
            'participantUserIds must survive normalization — regression test for '
            'the bug where _normalizePendingItem dropped the field',
      );
    },
  );

  test(
    'ActivityDTO.toJson / fromJson round-trips participantUserIds',
    () {
      const userA = '550e8400-e29b-41d4-a716-446655440011';
      const userB = '550e8400-e29b-41d4-a716-446655440022';
      final now = DateTime.now().toUtc();

      final original = ActivityDTO(
        uuid: 'test-uuid',
        projectId: 'TMQ',
        pkStart: 0,
        executionState: 'COMPLETADA',
        participantUserIds: [userA, userB],
        createdByUserId: userA,
        catalogVersionId: 'ver-001',
        activityTypeCode: 'CAMINAMIENTO',
        createdAt: now,
        updatedAt: now,
        syncVersion: 1,
      );

      final json = original.toJson();
      expect(json['participant_user_ids'], equals([userA, userB]));

      final restored = ActivityDTO.fromJson(json);
      expect(restored.participantUserIds, equals([userA, userB]));
    },
  );
}
