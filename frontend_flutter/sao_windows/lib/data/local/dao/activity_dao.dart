// lib/data/local/dao/activity_dao.dart
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../app_db.dart';
import '../tables.dart';

part 'activity_dao.g.dart';

const _uuid = Uuid();

@DriftAccessor(tables: [Activities, ActivityFields, ActivityLog, Evidences, SyncQueue])
class ActivityDao extends DatabaseAccessor<AppDb> with _$ActivityDaoMixin {
  ActivityDao(super.db);

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
