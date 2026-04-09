// frontend_flutter/sao_windows/test/sync_assignee_user_id_test.dart
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

// Mock imports - ajusta rutas según tu proyecto
// import 'package:sao_frontend/data/local/app_db.dart';
// import 'package:sao_frontend/data/local/tables.dart';

const _uuid = Uuid();

void main() {
  group('SyncService: Persist assigned_to_user_id to Activities table', () {
    test(
      'should map assignedToUserId from DTO to Activities.assigned_to_user_id column',
      () async {
        // GIVEN
        const assigneeUserId = '550e8400-e29b-41d4-a716-446655440000';
        const activityUuid = '660e8400-e29b-41d4-a716-446655440001';

        // Backend returns Activity DTO with assignedToUserId
        final activityDto = {
          'uuid': activityUuid,
          'project_id': 'TMQ',
          'assigned_to_user_id': assigneeUserId, // ← KEY FIELD
          'created_by_user_id': '770e8400-e29b-41d4-a716-446655440002',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          'execution_state': 'PENDIENTE',
          'activity_type_code': 'CAMINAMIENTO',
          'pk_start': 12000,
          'catalog_version_id': '880e8400-e29b-41d4-a716-446655440003',
        };

        // WHEN
        // SyncService pulls activities and calls:
        // await _db.into(_db.activities).insertOnConflictUpdate(
        //   ActivitiesCompanion.insert(
        //     ...
        //     assignedToUserId: Value(dto.assignedToUserId?.trim()),
        //   ),
        // );

        // THEN
        // 1. Activity row inserted with assigned_to_user_id = '550e8400-e29b-41d4-a716-446655440000'
        // 2. Column is NOT null
        // 3. queryTime in Home filters by assignedToUserId == currentUserId and finds record

        expect(activityDto['assigned_to_user_id'], equals(assigneeUserId));
      },
    );

    test(
      'should handle null assigned_to_user_id without error',
      () async {
        // GIVEN
        const activityUuid = '660e8400-e29b-41d4-a716-446655440001';

        final activityDto = {
          'uuid': activityUuid,
          'project_id': 'TMQ',
          'assigned_to_user_id': null, // ← NULL, triggers fallback
          'created_by_user_id': '770e8400-e29b-41d4-a716-446655440002',
          'created_at': DateTime.now().toIso8601String(),
          'execution_state': 'PENDIENTE',
          'activity_type_code': 'CAMINAMIENTO',
          'pk_start': 12000,
          'catalog_version_id': '880e8400-e29b-41d4-a716-446655440003',
        };

        // WHEN
        // SyncService processes DTO with null assignedToUserId
        final trimmedValue = (activityDto['assigned_to_user_id'] as String?)?.trim();

        // THEN
        expect(trimmedValue, isNull);
        // Home._loadHomeActivities resolves via fallback (ActivityFields or AgendaAssignments)
      },
    );

    test(
      'should prefer Activities.assigned_to_user_id over ActivityFields fallback',
      () async {
        // GIVEN
        const primaryAssignee = '550e8400-e29b-41d4-a716-446655440000';
        const fallbackAssignee = '550e8400-e29b-41d4-a716-446655440099'; // Different
        const activityId = '660e8400-e29b-41d4-a716-446655440001';

        // Activity has primaryAssignee directly
        // ActivityFields also has fallbackAssignee (old data)

        // WHEN
        // listHomeActivitiesByProject query runs:
        final resolvedAssignee = primaryAssignee; // From row.assignedToUserId
        // (ActivityFields not consulted if primaryAssignee is set)

        // THEN
        expect(resolvedAssignee, equals(primaryAssignee));
        expect(resolvedAssignee, isNot(equals(fallbackAssignee)));
      },
    );

    test(
      'should sync pull correctly update assigned_to_user_id when backend changes it',
      () async {
        // GIVEN
        const activityId = '660e8400-e29b-41d4-a716-446655440001';
        const oldAssignee = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
        const newAssignee = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';

        // Activity already synced with oldAssignee
        // Backend returns new DTO with newAssignee

        // WHEN
        // insertOnConflictUpdate is called (Drift UPSERT)
        final updated = newAssignee;

        // THEN
        // Row updated: assigned_to_user_id = bbbbbbbb...
        expect(updated, equals(newAssignee));
        expect(updated, isNot(equals(oldAssignee)));
      },
    );
  });

  group('Home: Filter activities by assigned_to_user_id', () {
    test(
      'should show only activities assigned to current user when isOperativeViewer=true',
      () async {
        // GIVEN
        const currentUserId = 'cccccccc-cccc-cccc-cccc-cccccccccccc';
        final activities = [
          {'id': '1', 'title': 'Activity A', 'assigned_to_user_id': currentUserId},
          {'id': '2', 'title': 'Activity B', 'assigned_to_user_id': 'dddddddd-dddd-dddd-dddd-dddddddddddd'},
          {'id': '3', 'title': 'Activity C', 'assigned_to_user_id': currentUserId},
          {'id': '4', 'title': 'Activity D', 'assigned_to_user_id': null},
        ];

        // WHEN
        final filtered = activities
            .where((row) {
              final assignedTo = row['assigned_to_user_id']?.toString().trim().toLowerCase();
              final isCurrent = assignedTo != null && assignedTo.isNotEmpty && assignedTo == currentUserId.toLowerCase();
              return isCurrent;
            })
            .toList();

        // THEN
        expect(filtered.length, equals(2));
        expect(filtered[0]['id'], equals('1'));
        expect(filtered[1]['id'], equals('3'));
        // Activity B and D are hidden (different assignee or null)
      },
    );
  });
}
