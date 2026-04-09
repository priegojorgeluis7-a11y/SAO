// lib/features/sync/services/sync_service.dart
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import '../../../core/flow/activity_flow_projection.dart';
import '../../../core/network/exceptions.dart';
import '../../../core/utils/logger.dart';
import '../../../data/local/app_db.dart';
import '../../../features/evidence/data/evidence_upload_retry_worker.dart';
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
  final EvidenceUploadRetryWorker? _evidenceUploadRetryWorker;
  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );

  SyncService({
    required SyncApiRepository apiRepository,
    required AppDb db,
    EventsApiRepository? eventsApiRepository,
    EvidenceUploadRetryWorker? evidenceUploadRetryWorker,
  })  : _apiRepository = apiRepository,
        _db = db,
        _eventsApiRepository = eventsApiRepository,
        _evidenceUploadRetryWorker = evidenceUploadRetryWorker;

  Future<PullSyncResult> pullChanges({
    required String projectId,
    int pageSize = 200,
    bool resetActivityCursor = false,
  }) async {
    final effectivePageSize = pageSize.clamp(1, 200).toInt();
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
        limit: effectivePageSize,
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
      pageSize: effectivePageSize,
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
      await _evidenceUploadRetryWorker?.processDueUploads(
        ignoreRetrySchedule: true,
      );

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

        final fallbackCatalogVersionId =
            await _apiRepository.resolveCatalogVersionUuid(projectId: projectId);

        final normalizedItems = <_PendingItem>[];
        for (final item in items) {
          final normalized = await _normalizePendingItem(
            item,
            fallbackCatalogVersionId: fallbackCatalogVersionId,
          );
          if (normalized == null) {
            errors++;
            pushed--;
            continue;
          }
          normalizedItems.add(normalized);
        }

        if (normalizedItems.isEmpty) {
          continue;
        }

        try {
          final response = await _apiRepository.pushActivities(
            projectId: projectId,
            activities: normalizedItems.map((i) => i.dto).toList(),
            forceOverride: forceOverride,
          );

          final itemByUuid = {
            for (final item in normalizedItems) item.dto.uuid: item,
          };
          final retryWithOverride = <_PendingItem>[];

          // 5. Process per-item results
          for (final result in response.results) {
            final match = itemByUuid[result.uuid];
            if (match == null) {
              errors++;
              appLogger.w('Server returned unknown UUID ${result.uuid}');
              continue;
            }

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
                if (!forceOverride) {
                  retryWithOverride.add(match);
                } else {
                  conflicts++;
                  await _markError(match.row, _buildGuidedError(result));
                }
              case 'INVALID':
                errors++;
                await _markError(match.row, _buildGuidedError(result));
              default:
                errors++;
                await _markError(match.row, _buildGuidedError(result));
            }
          }

          if (retryWithOverride.isNotEmpty && !forceOverride) {
            appLogger.w(
              'Retrying ${retryWithOverride.length} conflicted item(s) with force override for project $projectId',
            );
            try {
              final retryResponse = await _apiRepository.pushActivities(
                projectId: projectId,
                activities: retryWithOverride.map((i) => i.dto).toList(),
                forceOverride: true,
              );

              for (final retryResult in retryResponse.results) {
                final retryMatch = itemByUuid[retryResult.uuid];
                if (retryMatch == null) {
                  errors++;
                  appLogger.w('Retry returned unknown UUID ${retryResult.uuid}');
                  continue;
                }

                switch (retryResult.status) {
                  case 'CREATED':
                    created++;
                    await _markDone(retryMatch.row);
                  case 'UPDATED':
                    updated++;
                    await _markDone(retryMatch.row);
                  case 'UNCHANGED':
                    unchanged++;
                    await _markDone(retryMatch.row);
                  case 'CONFLICT':
                    conflicts++;
                    await _markError(retryMatch.row, _buildGuidedError(retryResult));
                  case 'INVALID':
                    errors++;
                    await _markError(retryMatch.row, _buildGuidedError(retryResult));
                  default:
                    errors++;
                    await _markError(
                      retryMatch.row,
                      _buildGuidedError(retryResult),
                    );
                }
              }
            } on Exception catch (retryError) {
              final retryErrorDetail = _formatSyncError(retryError);
              appLogger.e(
                'Conflict retry failed for project $projectId: $retryErrorDetail',
              );
              for (final retryItem in retryWithOverride) {
                await _markError(retryItem.row, retryErrorDetail);
                errors++;
              }
            }
          }
        } on Exception catch (e) {
          // Network/server error -> put all back to ERROR
          final errorDetail = _formatSyncError(e);
          appLogger.e('Push failed for project $projectId: $errorDetail');
          for (final item in normalizedItems) {
            await _markError(item.row, errorDetail);
          }
          errors += normalizedItems.length;
          pushed -= normalizedItems.length;
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
        'Sync complete: pushed=$pushed created=$created '
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
        'SyncService.pushPendingChanges fatal error',
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

  Future<_PendingItem?> _normalizePendingItem(
    _PendingItem item, {
    required String? fallbackCatalogVersionId,
  }) async {
    final dto = item.dto;

    final normalizedCatalogVersionId = await _resolveCatalogVersionId(
      activityId: dto.uuid,
      dtoCatalogVersionId: dto.catalogVersionId,
      fallbackCatalogVersionId: fallbackCatalogVersionId,
    );
    if (normalizedCatalogVersionId == null) {
      await _markError(
        item.row,
        'Missing valid catalog version ID for sync payload',
      );
      return null;
    }

    final normalizedActivityTypeCode = await _resolveActivityTypeCode(
      activityId: dto.uuid,
      dtoActivityTypeCode: dto.activityTypeCode,
    );
    if (normalizedActivityTypeCode == null) {
      await _markError(
        item.row,
        'Missing valid activity type code for sync payload | accion sugerida: REFRESH_CATALOG_AND_RETRY',
      );
      return null;
    }

    final normalizedFrontId = _sanitizeOptionalUuid(dto.frontId);
    final normalizedAssignedToUserId = _sanitizeOptionalUuid(dto.assignedToUserId);
    final normalizedCreatedByUserId = _sanitizeRequiredUuid(dto.createdByUserId);
    if (normalizedCreatedByUserId == null) {
      await _markError(
        item.row,
        'Missing valid created_by_user_id UUID for sync payload',
      );
      return null;
    }

    final normalizedDto = ActivityDTO(
      uuid: dto.uuid,
      serverId: dto.serverId,
      projectId: dto.projectId,
      frontId: normalizedFrontId,
      pkStart: dto.pkStart,
      pkEnd: dto.pkEnd,
      executionState: dto.executionState,
      assignedToUserId: normalizedAssignedToUserId,
      assignedToUserName: dto.assignedToUserName,
      createdByUserId: normalizedCreatedByUserId,
      catalogVersionId: normalizedCatalogVersionId,
      activityTypeCode: normalizedActivityTypeCode,
      latitude: dto.latitude,
      longitude: dto.longitude,
      title: dto.title,
      description: dto.description,
      wizardPayload: dto.wizardPayload,
      createdAt: dto.createdAt,
      updatedAt: dto.updatedAt,
      deletedAt: dto.deletedAt,
      syncVersion: dto.syncVersion,
    );

    if (normalizedCatalogVersionId == dto.catalogVersionId &&
        normalizedActivityTypeCode == dto.activityTypeCode &&
        normalizedFrontId == dto.frontId &&
        normalizedAssignedToUserId == dto.assignedToUserId &&
        normalizedCreatedByUserId == dto.createdByUserId) {
      return item;
    }

    await (_db.update(_db.syncQueue)..where((s) => s.id.equals(item.row.id))).write(
      SyncQueueCompanion(payloadJson: Value(jsonEncode(normalizedDto.toJson()))),
    );

    return _PendingItem(item.row, normalizedDto);
  }

  Future<String?> _resolveCatalogVersionId({
    required String activityId,
    required String? dtoCatalogVersionId,
    required String? fallbackCatalogVersionId,
  }) async {
    if (_isUuid(dtoCatalogVersionId)) {
      return dtoCatalogVersionId!.trim();
    }

    // Accept non-UUID non-empty strings (e.g., "tmq-v1.0.0").
    // The backend schema now accepts semantic version strings in Firestore mode.
    final rawDto = dtoCatalogVersionId?.trim() ?? '';
    if (rawDto.isNotEmpty) {
      return rawDto;
    }

    final activity = await ( _db.select(_db.activities)
          ..where((a) => a.id.equals(activityId)))
        .getSingleOrNull();
    if (activity == null) {
      return _isUuid(fallbackCatalogVersionId) ? fallbackCatalogVersionId!.trim() : null;
    }

    if (_isUuid(activity.catalogVersionId)) {
      return activity.catalogVersionId!.trim();
    }

    final catalogIndex = await (_db.select(_db.catalogIndex)
          ..where((c) => c.projectId.equals(activity.projectId)))
        .getSingleOrNull();
    if (_isUuid(catalogIndex?.activeVersionId)) {
      return catalogIndex!.activeVersionId.trim();
    }

    if (_isUuid(fallbackCatalogVersionId)) {
      return fallbackCatalogVersionId!.trim();
    }

    return null;
  }

  Future<String?> _resolveActivityTypeCode({
    required String activityId,
    required String dtoActivityTypeCode,
  }) async {
    final raw = dtoActivityTypeCode.trim();
    if (_isValidPushActivityTypeCode(raw)) {
      return raw;
    }

    final activity = await (_db.select(_db.activities)
          ..where((a) => a.id.equals(activityId)))
        .getSingleOrNull();
    if (activity == null) {
      return null;
    }

    final type = await (_db.select(_db.catalogActivityTypes)
          ..where((t) => t.id.equals(activity.activityTypeId)))
        .getSingleOrNull();
    final resolved = type?.code.trim();
    if (_isValidPushActivityTypeCode(resolved)) {
      return resolved;
    }

    final candidates = <String>{
      if (raw.isNotEmpty) raw,
      if (activity.activityTypeId.trim().isNotEmpty) activity.activityTypeId.trim(),
      if (activity.title.trim().isNotEmpty) activity.title.trim(),
    };

    final fromCatalog = await _resolveCatalogCodeByNormalizedCandidate(candidates);
    if (_isValidPushActivityTypeCode(fromCatalog)) {
      return fromCatalog;
    }

    final fromEffectiveCatalog = await _resolveEffectiveActivityIdByCandidate(candidates);
    if (_isValidPushActivityTypeCode(fromEffectiveCatalog)) {
      return fromEffectiveCatalog;
    }

    return null;
  }

  Future<String?> _resolveEffectiveActivityIdByCandidate(Set<String> rawCandidates) async {
    if (rawCandidates.isEmpty) return null;

    final normalizedCandidates = rawCandidates
        .map(_normalizeActivityTypeKey)
        .where((v) => v.isNotEmpty)
        .toSet();
    if (normalizedCandidates.isEmpty) return null;

    final activities = await (_db.select(_db.catActivities)).get();
    for (final activity in activities) {
      final id = activity.id.trim();
      if (!_isValidPushActivityTypeCode(id)) {
        continue;
      }

      final keys = <String>{
        _normalizeActivityTypeKey(activity.id),
        _normalizeActivityTypeKey(activity.name),
      };

      if (keys.any(normalizedCandidates.contains)) {
        return id;
      }
    }

    return null;
  }

  Future<String?> _resolveCatalogCodeByNormalizedCandidate(Set<String> rawCandidates) async {
    if (rawCandidates.isEmpty) return null;

    final normalizedCandidates = rawCandidates
        .map(_normalizeActivityTypeKey)
        .where((v) => v.isNotEmpty)
        .toSet();
    if (normalizedCandidates.isEmpty) return null;

    final types = await (_db.select(_db.catalogActivityTypes)).get();
    for (final type in types) {
      final code = type.code.trim();
      if (!_isValidPushActivityTypeCode(code)) {
        continue;
      }

      final keys = <String>{
        _normalizeActivityTypeKey(type.id),
        _normalizeActivityTypeKey(type.code),
        _normalizeActivityTypeKey(type.name),
      };

      if (keys.any(normalizedCandidates.contains)) {
        return code;
      }
    }

    return null;
  }

  String _normalizeActivityTypeKey(String? value) {
    final raw = value?.trim().toUpperCase() ?? '';
    if (raw.isEmpty) return '';
    return raw
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll(RegExp(r'[_\-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _isValidPushActivityTypeCode(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty || _isUuid(raw)) {
      return false;
    }

    final normalized = raw.toUpperCase();
    if (normalized == 'UNKNOWN' ||
        normalized == 'UNK' ||
        normalized == 'UNKNOWN_ACTIVITY_TYPE') {
      return false;
    }

    return true;
  }

  bool _isUuid(String? value) {
    final raw = value?.trim();
    if (raw == null || raw.isEmpty) return false;
    return _uuidPattern.hasMatch(raw);
  }

  String? _sanitizeOptionalUuid(String? value) {
    if (!_isUuid(value)) return null;
    return value!.trim();
  }

  String? _sanitizeRequiredUuid(String? value) {
    if (!_isUuid(value)) return null;
    return value!.trim();
  }

  String _formatSyncError(Exception error) {
    if (error is ServerException) {
      final detail = _extractBackendDetail(error.data);
      if (detail != null && detail.isNotEmpty) {
        return 'HTTP ${error.statusCode}: $detail';
      }
      return error.toString();
    }

    if (error is DioException) {
      final detail = _extractBackendDetail(error.response?.data);
      if (detail != null && detail.isNotEmpty) {
        return 'HTTP ${error.response?.statusCode}: $detail';
      }
      return error.toString();
    }
    return error.toString();
  }

  String? _extractBackendDetail(dynamic data) {
    if (data is Map) {
      final detail = data['detail'];
      if (detail is String && detail.trim().isNotEmpty) {
        return detail.trim();
      }
      if (detail is List && detail.isNotEmpty) {
        final messages = detail
            .map((item) {
              if (item is Map && item['msg'] != null) {
                return item['msg'].toString();
              }
              return item.toString();
            })
            .where((msg) => msg.trim().isNotEmpty)
            .join('; ');
        if (messages.isNotEmpty) {
          return messages;
        }
      }
      final message = data['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
    }
    return null;
  }

  // ──────────────────────── helpers ────────────────────────

  Future<void> _markDone(SyncQueueData row) async {
    await (_db.update(_db.syncQueue)..where((s) => s.id.equals(row.id)))
        .write(SyncQueueCompanion(
      status: const Value('DONE'),
      lastAttemptAt: Value(DateTime.now()),
      attempts: Value(row.attempts + 1),
      errorCode: const Value(null),
      retryable: const Value(true),
      suggestedAction: const Value(null),
      lastError: const Value(null),
    ));
    // Update activity local status so home view reflects "Sincronizada"
    if (row.entity == 'ACTIVITY') {
      await (_db.update(_db.activities)
            ..where((a) =>
                a.id.equals(row.entityId) &
                a.status.isIn(const ['READY_TO_SYNC', 'DRAFT'])))
          .write(const ActivitiesCompanion(status: Value('SYNCED')));
    }
  }

  Future<void> _markError(SyncQueueData row, String error) async {
    final guidance = _parseGuidanceFromStoredError(error);
    await (_db.update(_db.syncQueue)..where((s) => s.id.equals(row.id)))
        .write(SyncQueueCompanion(
      status: const Value('ERROR'),
      errorCode: Value(guidance.$1),
      retryable: Value(guidance.$2),
      suggestedAction: Value(guidance.$3),
      lastError: Value(error),
      lastAttemptAt: Value(DateTime.now()),
      attempts: Value(row.attempts + 1),
    ));
  }

  (String?, bool, String?) _parseGuidanceFromStoredError(String error) {
    final normalized = error.trim();
    final code = normalized.startsWith('CONFLICT:')
        ? 'CONFLICT'
      : normalized.startsWith('INVALID:')
        ? 'INVALID'
        : normalized.startsWith('Unexpected server status:')
            ? 'UNEXPECTED_STATUS'
            : null;
    final retryable = normalized.toUpperCase().contains('[RETRYABLE]');
    const marker = '| accion sugerida:';
    final lower = normalized.toLowerCase();
    final idx = lower.indexOf(marker);
    final suggestedAction = idx == -1
        ? null
        : normalized.substring(idx + marker.length).trim();
    return (
      code,
      retryable,
      suggestedAction?.isEmpty == true ? null : suggestedAction,
    );
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
            try {
              result = await _eventsApiRepository!.updateEvent(dto);
            } on DioException catch (e) {
              if (e.response?.statusCode == 404) {
                appLogger.w(
                  '⚠️ UPDATE 404 for event ${dto.uuid} — falling back to CREATE',
                );
                result = await _eventsApiRepository!.createEvent(dto);
              } else {
                rethrow;
              }
            }
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
        final executionState = dto.executionState.trim().toUpperCase();
        final reviewDecision = dto.reviewDecision?.trim().toUpperCase();
        final operationalState = dto.operationalState.trim().toUpperCase();
        final reviewState = dto.reviewState.trim().toUpperCase();
        final nextAction = dto.nextAction.trim().toUpperCase();
        final syncState = dto.syncState.trim().toUpperCase();
        final isRejectedByReview = const {
          'REJECT',
          'REJECTED',
          'CHANGES_REQUIRED',
          'REQUEST_CHANGES',
          'REQUIRES_CHANGES',
        }.contains(reviewDecision);
        final keepVisibleForCorrection =
            dto.deletedAt != null &&
            (executionState == 'REVISION_PENDIENTE' ||
                reviewState == 'CHANGES_REQUIRED' ||
                nextAction == 'CORREGIR_Y_REENVIAR' ||
                isRejectedByReview);

        if (dto.deletedAt != null && !keepVisibleForCorrection) {
          final existing = await (_db.select(_db.activities)
                ..where((t) => t.id.equals(dto.uuid)))
              .getSingleOrNull();
          if (existing == null) {
            continue;
          }
        }

        final creatorId = dto.createdByUserId.trim();
        if (creatorId.isEmpty || creatorId.length < 8) {
          appLogger.w(
            'Sync Pull Diagnostics: suspicious created_by_user_id '
            '(activity=${dto.uuid}, project=${dto.projectId}, value=${_maskIdForLog(creatorId)})',
          );
        }

        await _ensureProjectExists(dto.projectId);
        await _ensureUserExists(dto.createdByUserId);
        final activityTypeId = await _ensureActivityTypeExists(dto.activityTypeCode);
        final activityTypeName = await _resolveActivityTypeName(activityTypeId);
        final resolvedTitle = _resolveActivityTitle(
          catalogActivityName: activityTypeName,
          fallbackTitle: dto.title,
          activityTypeCode: dto.activityTypeCode,
        );

        final existing = await (_db.select(_db.activities)
              ..where((t) => t.id.equals(dto.uuid)))
            .getSingleOrNull();

          // Detectar si el usuario ya modificó localmente esta actividad.
          // El servidor aún puede reportar PENDIENTE (no sabe del cambio local),
          // pero NO debemos pisar el estado local con el del server.
          final existingLocalStatus = (existing?.status ?? '').trim().toUpperCase();
          final locallyModified = dto.deletedAt == null &&
              executionState == 'PENDIENTE' &&
              (existingLocalStatus == 'REVISION_PENDIENTE' ||
                  existingLocalStatus == 'READY_TO_SYNC' ||
                  (existingLocalStatus == 'DRAFT' && existing?.startedAt != null));

          final startedAt = locallyModified
              ? existing?.startedAt
              : switch (executionState) {
                  'EN_CURSO' => existing?.startedAt ?? dto.updatedAt.toLocal(),
                  'COMPLETADA' => existing?.startedAt ?? dto.updatedAt.toLocal(),
                  'REVISION_PENDIENTE' => existing?.startedAt ?? dto.updatedAt.toLocal(),
                  _ => null,
                };
          final finishedAt = locallyModified
              ? existing?.finishedAt
              : switch (executionState) {
                  'COMPLETADA' => dto.updatedAt.toLocal(),
                  'REVISION_PENDIENTE' => dto.updatedAt.toLocal(),
                  _ => null,
                };
          final localStatus =
              dto.deletedAt != null && !keepVisibleForCorrection
              ? 'CANCELED'
              : locallyModified
                  ? existingLocalStatus
                  : _deriveLocalStatus(
                      executionState: executionState,
                      operationalState: operationalState,
                      reviewState: reviewState,
                      syncState: syncState,
                      isRejectedByReview: isRejectedByReview,
                    );

        await _db.into(_db.activities).insertOnConflictUpdate(
              ActivitiesCompanion.insert(
                id: dto.uuid,
                projectId: dto.projectId,
                segmentId: const Value(null),
                activityTypeId: activityTypeId,
                title: resolvedTitle,
                description: Value(dto.description),
                pk: Value(dto.pkStart),
                pkRefType: const Value(null),
                createdAt: dto.createdAt.toLocal(),
                startedAt: Value(startedAt),
                finishedAt: Value(finishedAt),
                createdByUserId: dto.createdByUserId,
                assignedToUserId: Value(dto.assignedToUserId?.trim()),
                status: Value(localStatus),
                geoLat: Value(_parseNullableDouble(dto.latitude)),
                geoLon: Value(_parseNullableDouble(dto.longitude)),
                geoAccuracy: const Value(null),
                deviceId: const Value(null),
                localRevision: Value(existing?.localRevision ?? 1),
                serverRevision: Value(dto.syncVersion),
                catalogVersionId: Value(dto.catalogVersionId),
              ),
            );

        if (dto.assignedToUserId != null && dto.assignedToUserId!.trim().isNotEmpty) {
          final assignedId = dto.assignedToUserId!.trim();
          if (assignedId.length < 8) {
            appLogger.w(
              'Sync Pull Diagnostics: suspicious assigned_to_user_id '
              '(activity=${dto.uuid}, project=${dto.projectId}, value=${_maskIdForLog(assignedId)})',
            );
          }
          await _ensureUserExists(
            dto.assignedToUserId!,
            name: dto.assignedToUserName,
          );
          final fieldId = '${dto.uuid}:assignee_user_id';
          await _db.into(_db.activityFields).insertOnConflictUpdate(
                ActivityFieldsCompanion.insert(
                  id: fieldId,
                  activityId: dto.uuid,
                  fieldKey: 'assignee_user_id',
                  valueText: Value(dto.assignedToUserId!.trim()),
                ),
              );
        }

        // Persist canonical flow projection so Home/Agenda can consume backend truth
        // and only fallback to local inference when needed.
        final canonicalFields = <String, String>{
          'operational_state': operationalState,
          'review_state': reviewState,
          'next_action': nextAction,
          'sync_state': syncState,
          if ((dto.reviewComment ?? '').trim().isNotEmpty)
            'review_comment': dto.reviewComment!.trim(),
          if ((dto.reviewRejectReasonCode ?? '').trim().isNotEmpty)
            'review_reject_reason_code': dto.reviewRejectReasonCode!
                .trim()
                .toUpperCase(),
          ..._extractWizardTextFieldsFromPayload(dto.wizardPayload),
        };
        for (final entry in canonicalFields.entries) {
          await _upsertActivityField(
            dto.uuid,
            entry.key,
            text: entry.value,
          );
        }

        final wizardJsonFields = _extractWizardJsonFieldsFromPayload(
          dto.wizardPayload,
        );
        for (final entry in wizardJsonFields.entries) {
          await _upsertActivityField(
            dto.uuid,
            entry.key,
            json: entry.value,
          );
        }
      }
    });
  }

  double? _parseNullableDouble(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return double.tryParse(value);
  }

  Future<void> _upsertActivityField(
    String activityId,
    String key, {
    String? text,
    String? json,
  }) async {
    final normalizedText = text?.trim();
    final normalizedJson = json?.trim();
    if ((normalizedText == null || normalizedText.isEmpty) &&
        (normalizedJson == null || normalizedJson.isEmpty)) {
      return;
    }

    final existing = await (_db.select(_db.activityFields)
          ..where(
            (t) =>
                t.activityId.equals(activityId) &
                t.fieldKey.equals(key),
          )
          ..limit(1))
        .getSingleOrNull();

    await _db.into(_db.activityFields).insertOnConflictUpdate(
          ActivityFieldsCompanion.insert(
            id: existing?.id ?? '$activityId:$key',
            activityId: activityId,
            fieldKey: key,
            valueText: Value(normalizedText),
            valueJson: Value(normalizedJson),
          ),
        );
  }

  String? _normalizeWizardPayloadValue(dynamic raw) {
    final value = raw?.toString().trim();
    if (value == null || value.isEmpty || value.toLowerCase() == 'null') {
      return null;
    }
    return value;
  }

  Map<String, String> _extractWizardTextFieldsFromPayload(
    Map<String, dynamic>? wizardPayload,
  ) {
    if (wizardPayload == null) {
      return const {};
    }

    final fields = <String, String>{};

    void putText(String key, dynamic raw, {bool uppercase = false}) {
      final value = _normalizeWizardPayloadValue(raw);
      if (value == null) return;
      fields[key] = uppercase ? value.toUpperCase() : value;
    }

    putText('risk_level', wizardPayload['risk_level']);

    final activityRaw = wizardPayload['activity'];
    if (activityRaw is Map) {
      final activity = Map<String, dynamic>.from(activityRaw);
      putText('activity_type', activity['id']);
    }

    final subcategoryRaw = wizardPayload['subcategory'];
    if (subcategoryRaw is Map) {
      final subcategory = Map<String, dynamic>.from(subcategoryRaw);
      putText('subcategory', subcategory['id']);
      putText('subcategory_other_text', subcategory['other_text']);
    }

    final purposeRaw = wizardPayload['purpose'];
    if (purposeRaw is Map) {
      final purpose = Map<String, dynamic>.from(purposeRaw);
      putText('purpose', purpose['id']);
    }

    putText('topic_other_text', wizardPayload['topic_other_text']);

    final resultRaw = wizardPayload['result'];
    if (resultRaw is Map) {
      final result = Map<String, dynamic>.from(resultRaw);
      putText('result', result['id']);
    }

    putText('report_notes', wizardPayload['notes']);

    final locationRaw = wizardPayload['location'];
    if (locationRaw is Map) {
      final location = Map<String, dynamic>.from(locationRaw);
      putText('draft_tipo_ubicacion', location['tipo_ubicacion']);
      putText('draft_pk_inicio', location['pk_inicio']);
      putText('draft_pk_fin', location['pk_fin']);
      putText('front_id', location['front_id']);
      putText('front_name', location['front_name']);
      putText('estado', location['estado']);
      putText('municipio', location['municipio']);
      putText('colonia', location['colonia']);
    }

    final unplannedRaw = wizardPayload['unplanned'];
    if (unplannedRaw is Map) {
      final unplanned = Map<String, dynamic>.from(unplannedRaw);
      final isUnplanned = unplanned['is_unplanned'] == true;
      if (isUnplanned) {
        fields['origin'] = 'unplanned';
      }
      putText('unplanned_reason', unplanned['reason']);
      putText('unplanned_reason_other_text', unplanned['reason_other_text']);
      putText('unplanned_reference', unplanned['reference']);
    }

    return fields;
  }

  Map<String, String> _extractWizardJsonFieldsFromPayload(
    Map<String, dynamic>? wizardPayload,
  ) {
    if (wizardPayload == null) {
      return const {};
    }

    final fields = <String, String>{
      'wizard_payload_snapshot': jsonEncode(wizardPayload),
    };

    final topicsRaw = wizardPayload['topics'];
    if (topicsRaw is List) {
      final topicIds = topicsRaw
          .map((item) {
            if (item is Map) {
              final topic = Map<String, dynamic>.from(item);
              return _normalizeWizardPayloadValue(topic['id']) ??
                  _normalizeWizardPayloadValue(topic['name']);
            }
            return _normalizeWizardPayloadValue(item);
          })
          .whereType<String>()
          .toList(growable: false);
      if (topicIds.isNotEmpty) {
        fields['topics'] = jsonEncode(topicIds);
      }
    }

    final attendeesRaw = wizardPayload['attendees'];
    if (attendeesRaw is List) {
      final attendeeIds = <String>[];
      final attendeeRepresentatives = <String, String>{};
      for (final item in attendeesRaw) {
        if (item is Map) {
          final attendee = Map<String, dynamic>.from(item);
          final attendeeId = _normalizeWizardPayloadValue(attendee['id']) ??
              _normalizeWizardPayloadValue(attendee['name']);
          if (attendeeId == null) {
            continue;
          }
          attendeeIds.add(attendeeId);
          final representative = _normalizeWizardPayloadValue(
            attendee['representative_name'],
          );
          if (representative != null) {
            attendeeRepresentatives[attendeeId] = representative;
          }
        } else {
          final attendeeId = _normalizeWizardPayloadValue(item);
          if (attendeeId != null) {
            attendeeIds.add(attendeeId);
          }
        }
      }
      if (attendeeIds.isNotEmpty) {
        fields['attendees'] = jsonEncode(attendeeIds);
      }
      if (attendeeRepresentatives.isNotEmpty) {
        fields['attendee_representatives'] = jsonEncode(
          attendeeRepresentatives,
        );
      }
    }

    final agreementsRaw = wizardPayload['agreements'];
    if (agreementsRaw is List) {
      final agreements = agreementsRaw
          .map(_normalizeWizardPayloadValue)
          .whereType<String>()
          .toList(growable: false);
      if (agreements.isNotEmpty) {
        fields['report_agreements'] = jsonEncode(agreements);
      }
    }

    return fields;
  }

  /// Derives a local status for database persistence.
  /// 
  /// IMPORTANT: The backend already provides derived states (operationalState, reviewState, syncState).
  /// This function creates a composite "status" field for quick filtering/display.
  /// Trust backend-provided values first; only use local logic for edge cases.
  String _deriveLocalStatus({
    required String executionState,
    required String operationalState,
    required String reviewState,
    required String syncState,
    required bool isRejectedByReview,
  }) {
    return deriveLocalStatusFromCanonicalFlow(
      executionState: executionState,
      operationalState: operationalState,
      reviewState: reviewState,
      syncState: syncState,
      isRejectedByReview: isRejectedByReview,
    );
  }

  String _buildGuidedError(SyncPushResultItem result) {
    final status = result.status.trim().toUpperCase();
    final base = switch (status) {
      'CONFLICT' => 'CONFLICT: item changed on server',
      'INVALID' => _buildInvalidStatusMessage(result),
      _ => 'Unexpected server status: ${result.status}',
    };
    final action = result.suggestedAction?.trim();
    if (action == null || action.isEmpty) {
      return base;
    }
    final retryHint = result.retryable ? ' [retryable]' : '';
    return '$base$retryHint | accion sugerida: $action';
  }

  String _buildInvalidStatusMessage(SyncPushResultItem result) {
    final detail = result.message?.trim();
    if (detail != null && detail.isNotEmpty) {
      return 'INVALID: $detail';
    }

    final errorCode = result.errorCode?.trim();
    if (errorCode != null && errorCode.isNotEmpty) {
      return 'INVALID: $errorCode';
    }

    return 'INVALID: server validation failed';
  }

  String _maskIdForLog(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return '<empty>';
    }
    if (normalized.length <= 8) {
      return normalized;
    }
    return '${normalized.substring(0, 8)}...';
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

  Future<void> _ensureUserExists(String userId, {String? name}) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      return;
    }

    final existing = await (_db.select(_db.users)..where((t) => t.id.equals(normalizedUserId)))
        .getSingleOrNull();

    final fallbackLabel = normalizedUserId.length >= 8
        ? normalizedUserId.substring(0, 8)
        : normalizedUserId;
    final resolvedName = (name?.trim().isNotEmpty ?? false)
        ? name!.trim()
        : 'Usuario $fallbackLabel';

    if (existing != null) {
      // Update name if we now have a real name and the stored one is still a placeholder.
      final isPlaceholder = existing.name.startsWith('Usuario ');
      if (isPlaceholder && !resolvedName.startsWith('Usuario ')) {
        await (_db.update(_db.users)..where((t) => t.id.equals(normalizedUserId)))
            .write(UsersCompanion(name: Value(resolvedName)));
      }
      return;
    }

    await _db.into(_db.users).insertOnConflictUpdate(
          UsersCompanion.insert(
            id: normalizedUserId,
            name: resolvedName,
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

  Future<String?> _resolveActivityTypeName(String activityTypeId) async {
    final row = await (_db.select(_db.catalogActivityTypes)
          ..where((t) => t.id.equals(activityTypeId)))
        .getSingleOrNull();
    final name = row?.name.trim();
    if (name == null || name.isEmpty) return null;
    return name;
  }

  String _resolveActivityTitle({
    required String? catalogActivityName,
    required String? fallbackTitle,
    required String activityTypeCode,
  }) {
    final byCatalog = catalogActivityName?.trim();
    if (byCatalog != null && byCatalog.isNotEmpty) {
      return byCatalog;
    }

    final fallback = _stripLegacyTitlePrefixes(fallbackTitle ?? '');
    if (fallback.isNotEmpty) {
      return fallback;
    }
    return activityTypeCode.trim().isEmpty ? 'Actividad' : activityTypeCode.trim();
  }

  String _stripLegacyTitlePrefixes(String rawTitle) {
    final trimmed = rawTitle.trim();
    if (trimmed.isEmpty) return '';
    final lowered = trimmed.toLowerCase();
    if (lowered.startsWith('frente:') ||
        lowered.startsWith('estado:') ||
        lowered.startsWith('municipio:')) {
      return '';
    }
    return trimmed;
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
    } catch (e, st) {
      appLogger.w(
        'Invalid pull cursor payload for project=$projectId: $e\n$st',
      );
    }

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
      } catch (e, st) {
        appLogger.w(
          'Failed to decode existing pull cursor map for project=$projectId: $e\n$st',
        );
      }
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
      final response = await (() async {
        try {
          return await _eventsApiRepository.listEvents(
            projectId: projectId,
            sinceVersion: sinceVersion,
            includeDeleted: true,
            page: page,
            pageSize: pageSize,
          );
        } catch (e) {
          if (_isOptionalEventEndpointAccessError(e)) {
            appLogger.w(
              'Skipping event pull for project=$projectId due to '
              'insufficient permission or unavailable endpoint: $e',
            );
            return null;
          }
          if (_isUnsupportedSqlDependencyError(e)) {
            appLogger.w(
              'Skipping event pull for project=$projectId because backend endpoint '
              'is not available in current DATA_BACKEND mode: $e',
            );
            return null;
          }
          rethrow;
        }
      })();

      if (response == null) {
        break;
      }

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

  bool _isUnsupportedSqlDependencyError(Object error) {
    if (error is! DioException) {
      return false;
    }

    final data = error.response?.data;
    String detail = '';
    if (data is Map<String, dynamic>) {
      detail = (data['detail'] ?? '').toString();
    } else if (data != null) {
      detail = data.toString();
    }

    final normalized = detail.toLowerCase();
    return normalized.contains('sql database is disabled for current data_backend mode') ||
        normalized.contains('sync pull/push is still sql-backed') ||
        normalized.contains('sql database is unavailable for current backend mode');
  }

  bool _isOptionalEventEndpointAccessError(Object error) {
    if (error is! DioException) {
      return false;
    }

    final statusCode = error.response?.statusCode;
    if (statusCode != 403 && statusCode != 404) {
      return false;
    }

    final data = error.response?.data;
    String detail = '';
    if (data is Map<String, dynamic>) {
      final rawDetail = data['detail'];
      if (rawDetail is String) {
        detail = rawDetail;
      } else if (rawDetail is List) {
        detail = rawDetail.map((item) => item.toString()).join(' ');
      } else {
        detail = data.toString();
      }
    } else if (data != null) {
      detail = data.toString();
    }

    final normalized = detail.toLowerCase();
    if (statusCode == 404) {
      return true;
    }

    return normalized.contains('missing permission') ||
        normalized.contains('auth_missing_permission') ||
        normalized.contains('for project');
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
    } catch (e, st) {
      appLogger.w(
        'Invalid event cursor payload for project=$projectId: $e\n$st',
      );
    }

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
      } catch (e, st) {
        appLogger.w(
          'Failed to decode existing event cursor map for project=$projectId: $e\n$st',
        );
      }
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
