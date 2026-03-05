// lib/data/local/dao/activity_dao.dart
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../app_db.dart';
import '../tables.dart';

part 'activity_dao.g.dart';

const _uuid = Uuid();

class HomeActivityRecord {
  final Activity activity;
  final String? activityTypeName;
  final String? segmentName;
  final String? frontName;
  final bool isUnplanned;

  const HomeActivityRecord({
    required this.activity,
    this.activityTypeName,
    this.segmentName,
    this.frontName,
    required this.isUnplanned,
  });
}

@DriftAccessor(tables: [Activities, ActivityFields, ActivityLog, Evidences, SyncQueue])
class ActivityDao extends DatabaseAccessor<AppDb> with _$ActivityDaoMixin {
  ActivityDao(super.db);

  Future<List<Project>> listActiveProjects() {
    return (select(projects)
          ..where((t) => t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.code)]))
        .get();
  }

  Future<List<ProjectSegment>> listActiveSegmentsByProject(String projectCodeOrId) async {
    final projectId = await resolveProjectId(projectCodeOrId);
    return (select(projectSegments)
          ..where((t) => t.projectId.equals(projectId) & t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.segmentName)]))
        .get();
  }

  Future<Activity?> getActivityById(String activityId) {
    return (select(activities)..where((t) => t.id.equals(activityId))).getSingleOrNull();
  }

  Future<String> resolveProjectId(String projectCodeOrId) async {
    final normalized = projectCodeOrId.trim();
    if (normalized.isEmpty) return projectCodeOrId;

    final byId = await (select(projects)..where((t) => t.id.equals(normalized))).getSingleOrNull();
    if (byId != null) return byId.id;

    final byCode = await (select(projects)..where((t) => t.code.equals(normalized))).getSingleOrNull();
    if (byCode != null) return byCode.id;

    return normalized;
  }

  Future<String> resolveActivityTypeId(String activityTypeCodeOrId) async {
    final normalized = activityTypeCodeOrId.trim();
    if (normalized.isEmpty) return activityTypeCodeOrId;

    final byId = await (select(catalogActivityTypes)..where((t) => t.id.equals(normalized))).getSingleOrNull();
    if (byId != null) return byId.id;

    final byCode = await (select(catalogActivityTypes)..where((t) => t.code.equals(normalized))).getSingleOrNull();
    if (byCode != null) return byCode.id;

    return normalized;
  }

  Future<bool> activityExists(String activityId) async {
    final row = await (select(activities)..where((t) => t.id.equals(activityId))).getSingleOrNull();
    return row != null;
  }

  Future<Map<String, ActivityField>> getFieldsByKey(String activityId) async {
    final rows = await (select(activityFields)..where((t) => t.activityId.equals(activityId))).get();
    return {
      for (final row in rows) row.fieldKey: row,
    };
  }

  Future<List<HomeActivityRecord>> listHomeActivitiesByProject(String projectCodeOrId) async {
    final projectId = await resolveProjectId(projectCodeOrId);

    final rows = await (select(activities)
          ..where((t) => t.projectId.equals(projectId) & t.status.isNotValue('CANCELED'))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();

    if (rows.isEmpty) {
      return const [];
    }

    final segmentIds = rows
        .map((row) => row.segmentId)
        .whereType<String>()
        .where((id) => id.trim().isNotEmpty)
        .toSet()
        .toList();

    final activityTypeIds = rows
        .map((row) => row.activityTypeId)
        .where((id) => id.trim().isNotEmpty)
        .toSet()
        .toList();

    final activityIds = rows.map((row) => row.id).toList();

    final segments = segmentIds.isEmpty
        ? <ProjectSegment>[]
        : await (select(projectSegments)..where((t) => t.id.isIn(segmentIds))).get();
    final segmentById = {for (final segment in segments) segment.id: segment};

    final types = activityTypeIds.isEmpty
        ? <CatalogActivityType>[]
        : await (select(catalogActivityTypes)..where((t) => t.id.isIn(activityTypeIds))).get();
    final typeById = {for (final type in types) type.id: type};

    final fieldRows = await (select(activityFields)
          ..where((t) => t.activityId.isIn(activityIds) & t.fieldKey.isIn(const ['front_name', 'origin'])))
        .get();

    final frontNameByActivityId = <String, String>{};
    final isUnplannedByActivityId = <String, bool>{};

    for (final field in fieldRows) {
      if (field.fieldKey == 'front_name' && (field.valueText?.trim().isNotEmpty ?? false)) {
        frontNameByActivityId[field.activityId] = field.valueText!.trim();
      }
      if (field.fieldKey == 'origin' && field.valueText == 'unplanned') {
        isUnplannedByActivityId[field.activityId] = true;
      }
    }

    return rows
        .map(
          (row) => HomeActivityRecord(
            activity: row,
            activityTypeName: typeById[row.activityTypeId]?.name,
            segmentName: row.segmentId == null ? null : segmentById[row.segmentId!]?.segmentName,
            frontName: frontNameByActivityId[row.id],
            isUnplanned: isUnplannedByActivityId[row.id] ?? false,
          ),
        )
        .toList();
  }

  Future<void> upsertDraft({
    required ActivitiesCompanion activity,
    required List<ActivityFieldsCompanion> fields,
  }) async {
    await transaction(() async {
      await into(activities).insertOnConflictUpdate(activity);

      final actId = activity.id.value;
      await (delete(activityFields)..where((t) => t.activityId.equals(actId))).go();
      await batch((b) => b.insertAll(activityFields, fields));

      await into(activityLog).insert(
        ActivityLogCompanion.insert(
          id: _uuid.v4(),
          activityId: actId,
          eventType: 'EDITED',
          at: DateTime.now(),
          userId: activity.createdByUserId.value,
          note: const Value('draft_saved'),
        ),
      );
    });
  }

  Future<void> markReadyToSync({
    required String activityId,
    required String userId,
    required Map<String, dynamic> payload,
    int priority = 50,
  }) async {
    await transaction(() async {
      await (update(activities)..where((t) => t.id.equals(activityId)))
          .write(const ActivitiesCompanion(status: Value('READY_TO_SYNC')));

      await into(activityLog).insert(
        ActivityLogCompanion.insert(
          id: _uuid.v4(),
          activityId: activityId,
          eventType: 'SUBMITTED',
          at: DateTime.now(),
          userId: userId,
          note: const Value('queued_for_sync'),
        ),
      );

      await into(syncQueue).insert(
        SyncQueueCompanion.insert(
          id: _uuid.v4(),
          entity: 'ACTIVITY',
          entityId: activityId,
          action: 'UPSERT',
          payloadJson: jsonEncode(payload),
          priority: Value(priority),
        ),
      );
    });
  }
}
