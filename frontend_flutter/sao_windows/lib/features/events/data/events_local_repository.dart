// lib/features/events/data/events_local_repository.dart
import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/utils/logger.dart';
import '../../../data/local/app_db.dart';
import '../models/event_dto.dart';

/// Local (Drift) repository for Events.
/// Handles persistence + outbox enqueue for sync.
class EventsLocalRepository {
  final AppDb _db;

  EventsLocalRepository({required AppDb db}) : _db = db;

  // ──────────────────────────────────────────────
  // Write
  // ──────────────────────────────────────────────

  /// Saves a new event locally and enqueues it for sync.
  Future<void> saveEvent(EventDTO event) async {
    final now = DateTime.now().toUtc();

    await _db.transaction(() async {
      // 1. Upsert in local_events
      await _db.into(_db.localEvents).insertOnConflictUpdate(
            LocalEventsCompanion(
              id: Value(event.uuid),
              projectId: Value(event.projectId),
              eventTypeCode: Value(event.eventTypeCode),
              title: Value(event.title),
              description: Value(event.description),
              severity: Value(event.severity),
              locationPkMeters: Value(event.locationPkMeters),
              occurredAt: Value(DateTime.parse(event.occurredAt)),
              reportedByUserId: Value(event.reportedByUserId),
              formFieldsJson: Value(event.formFieldsJson),
              syncStatus: const Value('LOCAL_PENDING'),
              syncVersion: const Value(0),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      // 2. Enqueue to sync_queue with entity='EVENT'
      await _db.into(_db.syncQueue).insertOnConflictUpdate(
            SyncQueueCompanion(
              id: Value(event.uuid),
              entity: const Value('EVENT'),
              entityId: Value(event.uuid),
              action: const Value('UPSERT'),
              payloadJson: Value(jsonEncode(event.toJson())),
              status: const Value('PENDING'),
              priority: Value(now.millisecondsSinceEpoch),
            ),
          );
    });

    appLogger.i('📝 Event saved locally: ${event.uuid}');
  }

  /// Mark event as synced after successful push.
  Future<void> markSynced(String uuid, {int? serverId, int? syncVersion}) async {
    await (_db.update(_db.localEvents)..where((e) => e.id.equals(uuid)))
        .write(LocalEventsCompanion(
      syncStatus: const Value('SYNCED'),
      serverId: Value(serverId),
      syncVersion: Value(syncVersion ?? 0),
      updatedAt: Value(DateTime.now().toUtc()),
    ));
  }

  /// Updates an existing event locally and enqueues UPDATE/UPSERT as needed.
  Future<void> updateEvent(EventDTO event) async {
    final now = DateTime.now().toUtc();

    await _db.transaction(() async {
      final existingQueueItem = await (_db.select(_db.syncQueue)
            ..where((q) => q.id.equals(event.uuid)))
          .getSingleOrNull();
      // Preserve UPSERT when event has not reached server yet.
      final nextAction = _resolveActionForUpdate(existingQueueItem?.action);

      await (_db.update(_db.localEvents)..where((e) => e.id.equals(event.uuid)))
          .write(
        LocalEventsCompanion(
          eventTypeCode: Value(event.eventTypeCode),
          title: Value(event.title),
          description: Value(event.description),
          severity: Value(event.severity),
          locationPkMeters: Value(event.locationPkMeters),
          occurredAt: Value(DateTime.parse(event.occurredAt)),
          resolvedAt: Value(
            event.resolvedAt != null ? DateTime.parse(event.resolvedAt!) : null,
          ),
          formFieldsJson: Value(event.formFieldsJson),
          syncStatus: const Value('LOCAL_PENDING'),
          updatedAt: Value(now),
        ),
      );

      await _db.into(_db.syncQueue).insertOnConflictUpdate(
            SyncQueueCompanion(
              id: Value(event.uuid),
              entity: const Value('EVENT'),
              entityId: Value(event.uuid),
              action: Value(nextAction),
              payloadJson: Value(jsonEncode(event.toJson())),
              status: const Value('PENDING'),
              priority: Value(now.millisecondsSinceEpoch),
            ),
          );
    });

    appLogger.i('✏️ Event updated locally: ${event.uuid}');
  }

  String _resolveActionForUpdate(String? currentAction) {
    final normalized = (currentAction ?? '').toUpperCase();
    if (normalized == 'UPSERT') {
      return 'UPSERT';
    }
    return 'UPDATE';
  }

  /// Soft-deletes an event locally and enqueues a DELETE sync action.
  Future<void> deleteEvent(String uuid) async {
    final now = DateTime.now().toUtc();

    await _db.transaction(() async {
      await (_db.update(_db.localEvents)..where((e) => e.id.equals(uuid))).write(
        LocalEventsCompanion(
          deletedAt: Value(now),
          syncStatus: const Value('LOCAL_PENDING'),
          updatedAt: Value(now),
        ),
      );

      await _db.into(_db.syncQueue).insertOnConflictUpdate(
            SyncQueueCompanion(
              id: Value(uuid),
              entity: const Value('EVENT'),
              entityId: Value(uuid),
              action: const Value('DELETE'),
              payloadJson: Value(jsonEncode({'uuid': uuid})),
              status: const Value('PENDING'),
              priority: Value(now.millisecondsSinceEpoch),
            ),
          );
    });

    appLogger.i('🗑️ Event marked as deleted locally: $uuid');
  }

  /// Upsert server-pulled events into local_events without touching sync_queue.
  Future<void> upsertPulledEvents(List<EventDTO> events) async {
    if (events.isEmpty) return;

    final now = DateTime.now().toUtc();
    await _db.transaction(() async {
      for (final event in events) {
        await _db.into(_db.localEvents).insertOnConflictUpdate(
              LocalEventsCompanion(
                id: Value(event.uuid),
                projectId: Value(event.projectId),
                eventTypeCode: Value(event.eventTypeCode),
                title: Value(event.title),
                description: Value(event.description),
                severity: Value(event.severity),
                locationPkMeters: Value(event.locationPkMeters),
                occurredAt: Value(DateTime.parse(event.occurredAt)),
                resolvedAt: Value(
                  event.resolvedAt != null
                      ? DateTime.parse(event.resolvedAt!)
                      : null,
                ),
                deletedAt: Value(
                  event.deletedAt != null
                      ? DateTime.parse(event.deletedAt!)
                      : null,
                ),
                reportedByUserId: Value(event.reportedByUserId),
                formFieldsJson: Value(event.formFieldsJson),
                syncStatus: const Value('SYNCED'),
                syncVersion: Value(event.syncVersion),
                serverId: Value(event.serverId),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );
      }
    });
  }

  /// Mark event sync as failed.
  Future<void> markError(String uuid, String error) async {
    await (_db.update(_db.localEvents)..where((e) => e.id.equals(uuid)))
        .write(LocalEventsCompanion(
      syncStatus: const Value('ERROR'),
      updatedAt: Value(DateTime.now().toUtc()),
    ));
  }

  // ──────────────────────────────────────────────
  // Read
  // ──────────────────────────────────────────────

  /// Stream of all non-deleted events for a project.
  Stream<List<LocalEvent>> watchEvents(String projectId) {
    return (_db.select(_db.localEvents)
          ..where(
            (e) =>
                e.projectId.equals(projectId) &
                e.deletedAt.isNull(),
          )
          ..orderBy([(e) => OrderingTerm.desc(e.occurredAt)]))
        .watch();
  }

  /// Single fetch (non-streaming) for a project.
  Future<List<LocalEvent>> getEvents(String projectId) {
    return (_db.select(_db.localEvents)
          ..where(
            (e) =>
                e.projectId.equals(projectId) &
                e.deletedAt.isNull(),
          )
          ..orderBy([(e) => OrderingTerm.desc(e.occurredAt)]))
        .get();
  }

  /// Fetch all LOCAL_PENDING events (for sync push).
  Future<List<LocalEvent>> getPendingEvents() {
    return (_db.select(_db.localEvents)
          ..where((e) => e.syncStatus.equals('LOCAL_PENDING')))
        .get();
  }

  // ──────────────────────────────────────────────
  // Helpers
  // ──────────────────────────────────────────────

  /// Convert a Drift row to an EventDTO.
  EventDTO toDto(LocalEvent row) => EventDTO(
        uuid: row.id,
        serverId: row.serverId,
        projectId: row.projectId,
        reportedByUserId: row.reportedByUserId,
        eventTypeCode: row.eventTypeCode,
        title: row.title,
        description: row.description,
        severity: row.severity,
        locationPkMeters: row.locationPkMeters,
        occurredAt: row.occurredAt.toUtc().toIso8601String(),
        resolvedAt: row.resolvedAt?.toUtc().toIso8601String(),
        deletedAt: row.deletedAt?.toUtc().toIso8601String(),
        formFieldsJson: row.formFieldsJson,
        syncVersion: row.syncVersion,
      );
}
