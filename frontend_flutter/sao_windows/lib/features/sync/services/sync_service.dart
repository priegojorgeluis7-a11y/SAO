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

class PullSyncResult {
  final int pulled;
  final int pages;
  final int currentVersion;
  final int pulledEvents;
  final int eventPages;
  final int currentEventVersion;
  final DateTime completedAt;

  const PullSyncResult({
    required this.pulled,
    required this.pages,
    required this.currentVersion,
    required this.pulledEvents,
    required this.eventPages,
    required this.currentEventVersion,
    required this.completedAt,
  });
}

class _PullCursor {
  final int sinceVersion;
  final String? afterUuid;

  const _PullCursor({required this.sinceVersion, this.afterUuid});
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

  Future<PullSyncResult> pullChanges({
    required String projectId,
    int pageSize = 500,
    bool resetActivityCursor = false,
  }) async {
    final initialCursor = resetActivityCursor
        ? const _PullCursor(sinceVersion: 0, afterUuid: null)
        : await _readProjectPullCursor(projectId);
    var cursor = initialCursor;
    var pages = 0;
    var pulled = 0;

    appLogger.i(
      '🔽 Starting pull sync: project=$projectId since=${cursor.sinceVersion} after=${cursor.afterUuid}',
    );

    while (true) {
      final response = await _apiRepository.pullActivities(
        projectId: projectId,
        sinceVersion: cursor.sinceVersion,
        afterUuid: cursor.afterUuid,
        limit: pageSize,
      );

      pages += 1;
      await _upsertPulledActivities(response.activities);
      pulled += response.activities.length;

      if (response.hasMore) {
        cursor = _PullCursor(
          sinceVersion: response.nextSinceVersion ?? response.currentVersion,
          afterUuid: response.nextAfterUuid,
        );
      } else {
        cursor = _PullCursor(
          sinceVersion: response.currentVersion,
          afterUuid: null,
        );
      }

      await _writeProjectPullCursor(projectId, cursor);

      if (!response.hasMore) {
        break;
      }
    }

    final eventPull = await _pullEventChanges(
      projectId: projectId,
      pageSize: pageSize,
    );

    await (_db.update(_db.syncState)..where((s) => s.id.equals(1))).write(
      SyncStateCompanion(lastSyncAt: Value(DateTime.now())),
    );

    appLogger.i(
      '✅ Pull sync complete: project=$projectId pages=$pages pulled=$pulled currentVersion=${cursor.sinceVersion}',
    );

    return PullSyncResult(
      pulled: pulled,
      pages: pages,
      currentVersion: cursor.sinceVersion,
      pulledEvents: eventPull.$1,
      eventPages: eventPull.$2,
      currentEventVersion: eventPull.$3,
      completedAt: DateTime.now(),
    );
  }

  /// Push all pending activities to the backend.
  /// Safe to call when the queue is empty (returns quickly).
  Future<SyncResult> pushPendingChanges({
    bool forceOverride = false,
    Set<String>? queueItemIds,
  }) async {
    int pushed = 0, created = 0, updated = 0, unchanged = 0, conflicts = 0, errors = 0;

    try {
      // 1. Fetch retryable items
      final pendingItems = await (_db.select(_db.syncQueue)
        ..where(
          (s) =>
          s.entity.equals('ACTIVITY') &
          s.status.isIn(const ['PENDING', 'ERROR']) &
          (queueItemIds == null
              ? const Constant(true)
              : s.id.isIn(queueItemIds.toList())),
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
            forceOverride: forceOverride,
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

        EventDTO? result;
        final action = queueItem.action.toUpperCase();
        if (action == 'DELETE') {
          await _eventsApiRepository!.deleteEvent(queueItem.entityId);
        } else {
          final dto = EventDTO.fromJson(payloadMap);
          if (action == 'UPDATE') {
            result = await _eventsApiRepository!.updateEvent(dto);
          } else {
            // UPSERT fallback: create is idempotent by UUID.
            result = await _eventsApiRepository!.createEvent(dto);
          }
        }

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
        if (action != 'DELETE' && result != null) {
          await localEventsRepo.markSynced(
            result.uuid,
            serverId: result.serverId,
            syncVersion: result.syncVersion,
          );
          appLogger.d(
            '✅ Event synced ($action): ${result.uuid} → serverId=${result.serverId}',
          );
        } else {
          appLogger.d('✅ Event synced (DELETE): ${queueItem.entityId}');
        }
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

  Future<void> _upsertPulledActivities(List<ActivityDTO> activities) async {
    if (activities.isEmpty) return;

    await _db.transaction(() async {
      for (final dto in activities) {
        if (dto.deletedAt != null) {
          final existing = await (_db.select(_db.activities)
                ..where((t) => t.id.equals(dto.uuid)))
              .getSingleOrNull();
          if (existing == null) {
            continue;
          }
        }

        await _ensureProjectExists(dto.projectId);
        await _ensureUserExists(dto.createdByUserId);
        final activityTypeId = await _ensureActivityTypeExists(dto.activityTypeCode);

        final existing = await (_db.select(_db.activities)
              ..where((t) => t.id.equals(dto.uuid)))
            .getSingleOrNull();

        await _db.into(_db.activities).insertOnConflictUpdate(
              ActivitiesCompanion.insert(
                id: dto.uuid,
                projectId: dto.projectId,
                segmentId: const Value(null),
                activityTypeId: activityTypeId,
                title: (dto.title == null || dto.title!.trim().isEmpty)
                    ? 'Actividad ${dto.activityTypeCode}'
                    : dto.title!,
                description: Value(dto.description),
                pk: Value(dto.pkStart),
                pkRefType: const Value(null),
                createdAt: dto.createdAt.toLocal(),
                startedAt: const Value(null),
                finishedAt: dto.executionState == 'COMPLETADA'
                    ? Value(dto.updatedAt.toLocal())
                    : const Value(null),
                createdByUserId: dto.createdByUserId,
                status: Value(dto.deletedAt != null ? 'CANCELED' : 'SYNCED'),
                geoLat: Value(_parseNullableDouble(dto.latitude)),
                geoLon: Value(_parseNullableDouble(dto.longitude)),
                geoAccuracy: const Value(null),
                deviceId: const Value(null),
                localRevision: Value(existing?.localRevision ?? 1),
                serverRevision: Value(dto.syncVersion),
              ),
            );
      }
    });
  }

  double? _parseNullableDouble(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return double.tryParse(value);
  }

  Future<void> _ensureProjectExists(String projectId) async {
    final existing = await (_db.select(_db.projects)
          ..where((t) => t.id.equals(projectId)))
        .getSingleOrNull();
    if (existing != null) {
      return;
    }
    await _db.into(_db.projects).insertOnConflictUpdate(
          ProjectsCompanion.insert(
            id: projectId,
            code: projectId,
            name: 'Proyecto $projectId',
          ),
        );
  }

  Future<void> _ensureUserExists(String userId) async {
    final existing = await (_db.select(_db.users)..where((t) => t.id.equals(userId)))
        .getSingleOrNull();
    if (existing != null) {
      return;
    }
    await _db.into(_db.users).insertOnConflictUpdate(
          UsersCompanion.insert(
            id: userId,
            name: 'Usuario ${userId.substring(0, 8)}',
            roleId: 4,
          ),
        );
  }

  Future<String> _ensureActivityTypeExists(String activityTypeCode) async {
    final byId = await (_db.select(_db.catalogActivityTypes)
          ..where((t) => t.id.equals(activityTypeCode)))
        .getSingleOrNull();
    if (byId != null) {
      return byId.id;
    }

    final byCode = await (_db.select(_db.catalogActivityTypes)
          ..where((t) => t.code.equals(activityTypeCode)))
        .getSingleOrNull();
    if (byCode != null) {
      return byCode.id;
    }

    await _db.into(_db.catalogActivityTypes).insertOnConflictUpdate(
          CatalogActivityTypesCompanion.insert(
            id: activityTypeCode,
            code: activityTypeCode,
            name: activityTypeCode,
          ),
        );
    return activityTypeCode;
  }

  Future<_PullCursor> _readProjectPullCursor(String projectId) async {
    final state = await (_db.select(_db.syncState)..where((s) => s.id.equals(1)))
        .getSingleOrNull();

    if (state?.lastServerCursor == null || state!.lastServerCursor!.trim().isEmpty) {
      return const _PullCursor(sinceVersion: 0, afterUuid: null);
    }

    final raw = state.lastServerCursor!.trim();
    final legacyCursor = int.tryParse(raw);
    if (legacyCursor != null) {
      return _PullCursor(sinceVersion: legacyCursor, afterUuid: null);
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return const _PullCursor(sinceVersion: 0, afterUuid: null);
      }
      final projectCursor = decoded[projectId];
      if (projectCursor is Map<String, dynamic>) {
        final since = (projectCursor['since_version'] as num?)?.toInt() ?? 0;
        final after = projectCursor['after_uuid'] as String?;
        return _PullCursor(sinceVersion: since, afterUuid: after);
      }
      if (projectCursor is num) {
        return _PullCursor(sinceVersion: projectCursor.toInt(), afterUuid: null);
      }
    } catch (_) {}

    return const _PullCursor(sinceVersion: 0, afterUuid: null);
  }

  Future<void> _writeProjectPullCursor(String projectId, _PullCursor cursor) async {
    final state = await (_db.select(_db.syncState)..where((s) => s.id.equals(1)))
        .getSingleOrNull();

    final map = <String, dynamic>{};
    final raw = state?.lastServerCursor?.trim();
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          map.addAll(decoded);
        }
      } catch (_) {}
    }

    map[projectId] = {
      'since_version': cursor.sinceVersion,
      'after_uuid': cursor.afterUuid,
    };

    await _db.into(_db.syncState).insertOnConflictUpdate(
          SyncStateCompanion.insert(
            id: const Value(1),
            lastSyncAt: Value(state?.lastSyncAt),
            lastServerCursor: Value(jsonEncode(map)),
            lastCatalogVersionByProjectJson:
                Value(state?.lastCatalogVersionByProjectJson ?? '{}'),
          ),
        );
  }

  Future<(int pulledEvents, int pages, int currentVersion)> _pullEventChanges({
    required String projectId,
    required int pageSize,
  }) async {
    if (_eventsApiRepository == null) {
      return (0, 0, 0);
    }

    final initialSince = await _readProjectEventCursor(projectId);
    var sinceVersion = initialSince;
    var page = 1;
    var pages = 0;
    var pulledEvents = 0;

    final localEventsRepo = EventsLocalRepository(db: _db);

    while (true) {
      final response = await _eventsApiRepository!.listEvents(
        projectId: projectId,
        sinceVersion: sinceVersion,
        includeDeleted: true,
        page: page,
        pageSize: pageSize,
      );

      pages += 1;
      if (response.items.isNotEmpty) {
        await localEventsRepo.upsertPulledEvents(response.items);
        pulledEvents += response.items.length;

        final pageMaxVersion = response.items
            .map((event) => event.syncVersion)
            .fold<int>(sinceVersion, (max, value) => value > max ? value : max);
        if (pageMaxVersion > sinceVersion) {
          sinceVersion = pageMaxVersion;
        }
      }

      if (!response.hasNext) {
        break;
      }
      page += 1;
    }

    await _writeProjectEventCursor(projectId, sinceVersion);
    return (pulledEvents, pages, sinceVersion);
  }

  Future<int> _readProjectEventCursor(String projectId) async {
    final state = await (_db.select(_db.syncState)..where((s) => s.id.equals(1)))
        .getSingleOrNull();

    final raw = state?.lastServerCursor?.trim();
    if (raw == null || raw.isEmpty) {
      return 0;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return 0;
      }
      final eventsRoot = decoded['_events'];
      if (eventsRoot is! Map<String, dynamic>) {
        return 0;
      }
      final value = eventsRoot[projectId];
      if (value is num) {
        return value.toInt();
      }
      if (value is Map<String, dynamic>) {
        return (value['since_version'] as num?)?.toInt() ?? 0;
      }
    } catch (_) {}

    return 0;
  }

  Future<void> _writeProjectEventCursor(String projectId, int sinceVersion) async {
    final state = await (_db.select(_db.syncState)..where((s) => s.id.equals(1)))
        .getSingleOrNull();

    final map = <String, dynamic>{};
    final raw = state?.lastServerCursor?.trim();
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          map.addAll(decoded);
        }
      } catch (_) {}
    }

    final eventsRoot = <String, dynamic>{};
    if (map['_events'] is Map<String, dynamic>) {
      eventsRoot.addAll(map['_events'] as Map<String, dynamic>);
    }
    eventsRoot[projectId] = sinceVersion;
    map['_events'] = eventsRoot;

    await _db.into(_db.syncState).insertOnConflictUpdate(
          SyncStateCompanion.insert(
            id: const Value(1),
            lastSyncAt: Value(state?.lastSyncAt),
            lastServerCursor: Value(jsonEncode(map)),
            lastCatalogVersionByProjectJson:
                Value(state?.lastCatalogVersionByProjectJson ?? '{}'),
          ),
        );
  }

  Future<SyncResult> resolveConflictUseLocal(String queueItemId) async {
    await (_db.update(_db.syncQueue)..where((s) => s.id.equals(queueItemId))).write(
          SyncQueueCompanion(
            status: const Value('PENDING'),
            lastError: const Value(null),
            priority: Value(DateTime.now().millisecondsSinceEpoch),
          ),
        );

    return pushPendingChanges(
      forceOverride: true,
      queueItemIds: {queueItemId},
    );
  }

  Future<PullSyncResult> resolveConflictUseServer({
    required String queueItemId,
    required String projectId,
  }) async {
    await (_db.update(_db.syncQueue)..where((s) => s.id.equals(queueItemId))).write(
          SyncQueueCompanion(
            status: const Value('DONE'),
            lastError: const Value(null),
            lastAttemptAt: Value(DateTime.now()),
          ),
        );

    return pullChanges(
      projectId: projectId,
      resetActivityCursor: true,
    );
  }
}
