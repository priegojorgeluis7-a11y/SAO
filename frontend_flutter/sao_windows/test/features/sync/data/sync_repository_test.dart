import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sao_windows/data/local/app_db.dart';
import 'package:sao_windows/features/sync/data/sync_repository.dart';
import 'package:sao_windows/features/sync/models/sync_models.dart';

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

  group('SyncRepository upload queue mapping', () {
    test('uses persisted retryable=false and humanizes suggested action', () async {
      final db = AppDb();
      addTearDown(db.close);
      final repo = SyncRepository(db);

      await db.into(db.syncQueue).insert(
            SyncQueueCompanion.insert(
              id: 'q-1',
              entity: 'ACTIVITY',
              entityId: 'activity-1',
              action: 'UPSERT',
              payloadJson: '{}',
              status: const drift.Value('ERROR'),
              retryable: const drift.Value(false),
              suggestedAction: const drift.Value('REFRESH_CATALOG_AND_RETRY'),
              lastError: const drift.Value('VALIDATION_ERROR'),
            ),
          );

      final queue = await repo.watchUploadQueue().first;
      expect(queue, hasLength(1));
      expect(queue.first.status, UploadItemStatus.error);
      expect(queue.first.retryable, isFalse);
      expect(queue.first.suggestedAction, 'Actualizar catalogo y volver a intentar');
      expect(queue.first.errorMessage, 'VALIDATION_ERROR');
    });

    test('recognizes explicit [RETRYABLE] marker when metadata is false', () async {
      final db = AppDb();
      addTearDown(db.close);
      final repo = SyncRepository(db);

      await db.into(db.syncQueue).insert(
            SyncQueueCompanion.insert(
              id: 'q-2',
              entity: 'EVENT',
              entityId: 'event-1',
              action: 'UPSERT',
              payloadJson: '{}',
              status: const drift.Value('ERROR'),
              retryable: const drift.Value(false),
              lastError: const drift.Value('[RETRYABLE] network timeout'),
            ),
          );

      final queue = await repo.watchUploadQueue().first;
      expect(queue, hasLength(1));
      expect(queue.first.retryable, isTrue);
      expect(queue.first.errorMessage, 'network timeout');
    });

    test('extracts and humanizes suggested action from error payload fallback', () async {
      final db = AppDb();
      addTearDown(db.close);
      final repo = SyncRepository(db);

      await db.into(db.syncQueue).insert(
            SyncQueueCompanion.insert(
              id: 'q-3',
              entity: 'ACTIVITY',
              entityId: 'activity-3',
              action: 'UPSERT',
              payloadJson: '{}',
              status: const drift.Value('ERROR'),
              retryable: const drift.Value(false),
              lastError: const drift.Value('CONFLICT | accion sugerida: PULL_AND_RESOLVE_CONFLICT'),
            ),
          );

      final queue = await repo.watchUploadQueue().first;
      expect(queue, hasLength(1));
      expect(queue.first.retryable, isFalse);
      expect(queue.first.suggestedAction, 'Actualizar desde servidor y resolver conflicto');
      expect(queue.first.errorMessage, 'CONFLICT');
    });
  });
}
