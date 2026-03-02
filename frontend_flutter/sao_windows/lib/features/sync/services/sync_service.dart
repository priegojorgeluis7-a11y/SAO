// lib/features/sync/services/sync_service.dart
import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/utils/logger.dart';
import '../../../data/local/app_db.dart';
import '../../../features/events/data/events_api_repository.dart';
import '../../../features/events/data/events_local_repository.dart';
import '../../../features/events/models/event_dto.dart';
import '../data/sync_api_repository.dart';
import '../models/sync_dto.dart';

/// Result of a sync push operation.
class SyncResult {
  final int pushed;
  final int created;
  final int updated;
  final int unchanged;
  final int conflicts;
  final int errors;
  final String? errorMessage;
  final DateTime completedAt;

  const SyncResult({
    required this.pushed,
    required this.created,
    required this.updated,
    required this.unchanged,
    required this.conflicts,
    required this.errors,
    this.errorMessage,
    required this.completedAt,
  });

  bool get success => errorMessage == null;
  bool get hasConflicts => conflicts > 0;

  static SyncResult empty() => SyncResult(
        pushed: 0,
        created: 0,
        updated: 0,
        unchanged: 0,
        conflicts: 0,
        errors: 0,
        completedAt: DateTime.now(),
      );
}

// Internal container: queue row + deserialized DTO
class _PendingItem {
  final SyncQueueData row;
  final ActivityDTO dto;
  _PendingItem(this.row, this.dto);
}

/// Orchestrates activity + event sync push operations.
///
/// Flow for push:
/// 1. Read PENDING | ERROR ACTIVITY items from sync_queue (ordered by priority desc)
/// 2. Deserialize payloadJson as ActivityDTO
/// 3. Group by project_id
/// 4. POST /sync/push for each project batch
/// 5. Per result: CREATED/UPDATED/UNCHANGED → DONE; CONFLICT → ERROR
/// 6. Push EVENT items from sync_queue via POST /api/v1/events (idempotent)
/// 7. Update SyncState.lastSyncAt
class SyncService {
  final SyncApiRepository _apiRepository;
  final AppDb _db;
  final EventsApiRepository? _eventsApiRepository;

  SyncService({
    required SyncApiRepository apiRepository,
    required AppDb db,
    EventsApiRepository? eventsApiRepository,
  })  : _apiRepository = apiRepository,
        _db = db,
        _eventsApiRepository = eventsApiRepository;

  /// Push all pending activities to the backend.
  /// Safe to call when the queue is empty (returns quickly).
  Future<SyncResult> pushPendingChanges() async {
    int pushed = 0, created = 0, updated = 0, unchanged = 0, conflicts = 0, errors = 0;

    try {
      // 1. Fetch retryable items
      final pendingItems = await (_db.select(_db.syncQueue)
            ..where(
              (s) =>
                  s.entity.equals('ACTIVITY') &
                  s.status.isIn(const ['PENDING', 'ERROR']),
            )
            ..orderBy([(s) => OrderingTerm.desc(s.priority)]))
          .get();

      if (pendingItems.isEmpty) {
        appLogger.d('📭 Sync Push: queue is empty');
        return SyncResult.empty();
      }

      appLogger.i('📤 Sync Push: ${pendingItems.length} items to process');

      // 2. Mark all as IN_PROGRESS to prevent double-processing
      for (final item in pendingItems) {
        await (_db.update(_db.syncQueue)..where((s) => s.id.equals(item.id)))
            .write(const SyncQueueCompanion(status: Value('IN_PROGRESS')));
      }

      // 3. Deserialize payloads and group by project
      final Map<String, List<_PendingItem>> byProject = {};
      for (final item in pendingItems) {
        try {
          final payloadMap =
              jsonDecode(item.payloadJson) as Map<String, dynamic>;
          final dto = ActivityDTO.fromJson(payloadMap);
          byProject
              .putIfAbsent(dto.projectId, () => [])
              .add(_PendingItem(item, dto));
        } catch (e) {
          appLogger.e('⚠️ Cannot deserialize queue item ${item.id}: $e');
          await _markError(item, 'Payload inválido: $e');
          errors++;
        }
      }

      // 4. Push each project batch
      for (final entry in byProject.entries) {
        final projectId = entry.key;
        final items = entry.value;
        pushed += items.length;

        try {
          final response = await _apiRepository.pushActivities(
            projectId: projectId,
            activities: items.map((i) => i.dto).toList(),
          );

          // 5. Process per-item results
          for (final result in response.results) {
            final match = items.firstWhere(
              (i) => i.dto.uuid == result.uuid,
              orElse: () =>
                  throw StateError('Server returned unknown UUID ${result.uuid}'),
            );

            switch (result.status) {
              case 'CREATED':
                created++;
                await _markDone(match.row);
              case 'UPDATED':
                updated++;
                await _markDone(match.row);
              case 'UNCHANGED':
                unchanged++;
                await _markDone(match.row);
              case 'CONFLICT':
                conflicts++;
                await _markError(
                    match.row, 'CONFLICT: ítem modificado en servidor');
              default:
                errors++;
                await _markError(
                    match.row, 'Estado inesperado: ${result.status}');
            }
          }
        } on Exception catch (e) {
          // Network/server error → put all back to ERROR
          appLogger.e('❌ Push failed for project $projectId: $e');
          for (final item in items) {
            await _markError(item.row, e.toString());
          }
          errors += items.length;
          pushed -= items.length;
        }
      }

      // 6. Push pending events (if repository available)
      if (_eventsApiRepository != null) {
        final eventErrors = await _pushPendingEvents();
        errors += eventErrors;
      }

      // 7. Update last sync timestamp
      await (_db.update(_db.syncState)..where((s) => s.id.equals(1)))
          .write(SyncStateCompanion(lastSyncAt: Value(DateTime.now())));

      appLogger.i(
        '✅ Sync complete: pushed=$pushed created=$created '
        'updated=$updated unchanged=$unchanged '
        'conflicts=$conflicts errors=$errors',
      );

      return SyncResult(
        pushed: pushed,
        created: created,
        updated: updated,
        unchanged: unchanged,
        conflicts: conflicts,
        errors: errors,
        completedAt: DateTime.now(),
      );
    } catch (e, st) {
      appLogger.e(
        '💥 SyncService.pushPendingChanges fatal error',
        error: e,
        stackTrace: st,
      );
      return SyncResult(
        pushed: pushed,
        created: created,
        updated: updated,
        unchanged: unchanged,
        conflicts: conflicts,
        errors: errors,
        errorMessage: e.toString(),
        completedAt: DateTime.now(),
      );
    }
  }

  // ──────────────────────── helpers ────────────────────────

  Future<void> _markDone(SyncQueueData row) async {
    await (_db.update(_db.syncQueue)..where((s) => s.id.equals(row.id)))
        .write(SyncQueueCompanion(
      status: const Value('DONE'),
      lastAttemptAt: Value(DateTime.now()),
      attempts: Value(row.attempts + 1),
      lastError: const Value(null),
    ));
  }

  Future<void> _markError(SyncQueueData row, String error) async {
    await (_db.update(_db.syncQueue)..where((s) => s.id.equals(row.id)))
        .write(SyncQueueCompanion(
      status: const Value('ERROR'),
      lastError: Value(error),
      lastAttemptAt: Value(DateTime.now()),
      attempts: Value(row.attempts + 1),
    ));
  }

  /// Push all pending EVENT items from sync_queue.
  /// Returns number of errors encountered.
  Future<int> _pushPendingEvents() async {
    int errors = 0;

    final pendingEvents = await (_db.select(_db.syncQueue)
          ..where(
            (s) =>
                s.entity.equals('EVENT') &
                s.status.isIn(const ['PENDING', 'ERROR']),
          )
          ..orderBy([(s) => OrderingTerm.desc(s.priority)]))
        .get();

    if (pendingEvents.isEmpty) return 0;

    appLogger.i('📤 Event Push: ${pendingEvents.length} events to sync');

    final localEventsRepo = EventsLocalRepository(db: _db);

    for (final queueItem in pendingEvents) {
      // Mark as IN_PROGRESS
      await (_db.update(_db.syncQueue)
            ..where((s) => s.id.equals(queueItem.id)))
          .write(const SyncQueueCompanion(status: Value('IN_PROGRESS')));

      try {
        final payloadMap =
            jsonDecode(queueItem.payloadJson) as Map<String, dynamic>;
        final dto = EventDTO.fromJson(payloadMap);

        // POST /api/v1/events (idempotent by UUID)
        final result = await _eventsApiRepository!.createEvent(dto);

        // Mark queue item as DONE
        await (_db.update(_db.syncQueue)
              ..where((s) => s.id.equals(queueItem.id)))
            .write(SyncQueueCompanion(
          status: const Value('DONE'),
          lastAttemptAt: Value(DateTime.now()),
          attempts: Value(queueItem.attempts + 1),
          lastError: const Value(null),
        ));

        // Update local event with server_id and sync_version
        await localEventsRepo.markSynced(
          dto.uuid,
          serverId: result.serverId,
          syncVersion: result.syncVersion,
        );

        appLogger.d('✅ Event synced: ${dto.uuid} → serverId=${result.serverId}');
      } catch (e) {
        appLogger.e('❌ Event push failed for ${queueItem.entityId}: $e');
        await (_db.update(_db.syncQueue)
              ..where((s) => s.id.equals(queueItem.id)))
            .write(SyncQueueCompanion(
          status: const Value('ERROR'),
          lastError: Value(e.toString()),
          lastAttemptAt: Value(DateTime.now()),
          attempts: Value(queueItem.attempts + 1),
        ));
        await localEventsRepo.markError(queueItem.entityId, e.toString());
        errors++;
      }
    }

    return errors;
  }
}
