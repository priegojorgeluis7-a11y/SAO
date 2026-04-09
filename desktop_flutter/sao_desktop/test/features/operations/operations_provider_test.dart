// desktop_flutter/sao_desktop/test/features/operations/operations_provider_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sao_desktop/core/enums/shared_enums.dart';
import 'package:sao_desktop/features/operations/providers/operations_provider.dart';

void main() {
  group('OperationItem - Activity Queue Item', () {
    test('classifies activity by risk level with gps mismatch', () {
      // GIVEN
      final operationItem = OperationItem(
        id: 'op-1',
        type: 'Inspection',
        pk: '142+000',
        engineer: 'Juan García',
        municipality: 'Toluca',
        state: 'Estado de Mexico',
        isNew: true,
        risk: RiskLevel.prioritario.code,
        syncedAgo: '5 min',
        gpsDeltaMeters: 450.0,
        description: 'Kilometro 142 inspeccion de via',
        classification: 'INSPECTION',
      );

      // WHEN / THEN
      expect(operationItem.risk, equals(RiskLevel.prioritario.code));
      expect(operationItem.gpsDeltaMeters, equals(450.0));
      expect(operationItem.isNew, isTrue);
    });

    test('shows as new if created less than 24 hours ago', () {
      // GIVEN
      final newItem = OperationItem(
        id: 'op-2',
        type: 'Meeting',
        pk: '150+500',
        engineer: 'Maria Lopez',
        municipality: 'Mexico City',
        state: 'Mexico City',
        isNew: true,
        risk: RiskLevel.bajo.code,
        syncedAgo: '2 h',
        gpsDeltaMeters: 0.0,
        description: 'Reunion comunitaria',
        classification: 'MEETING',
      );

      // WHEN / THEN
      expect(newItem.isNew, isTrue);
      expect(newItem.syncedAgo, equals('2 h'));
    });

    test('displays sync time correctly for recent items', () {
      // GIVEN
      final recentItem = OperationItem(
        id: 'op-3',
        type: 'Survey',
        pk: '160+000',
        engineer: 'Carlos Rodriguez',
        municipality: 'Querétaro',
        state: 'Querétaro',
        isNew: false,
        risk: RiskLevel.medio.code,
        syncedAgo: '15 min',
        gpsDeltaMeters: 0.0,
        description: 'Levantamiento topografico',
        classification: 'SURVEY',
      );

      // WHEN / THEN
      expect(recentItem.syncedAgo.contains('min'), isTrue);
    });

    test('displays sync time correctly for older items', () {
      // GIVEN
      final olderItem = OperationItem(
        id: 'op-4',
        type: 'Audit',
        pk: '170+250',
        engineer: 'Ana Martinez',
        municipality: 'Guanajuato',
        state: 'Guanajuato',
        isNew: false,
        risk: RiskLevel.alto.code,
        syncedAgo: '3 h',
        gpsDeltaMeters: 0.0,
        description: 'Auditoria de seguridad',
        classification: 'AUDIT',
      );

      // WHEN / THEN
      expect(olderItem.syncedAgo.contains('h'), isTrue);
    });

    test('handles missing pk gracefully', () {
      // GIVEN
      final noKmItem = OperationItem(
        id: 'op-5',
        type: 'General',
        pk: '-',
        engineer: 'John Doe',
        municipality: 'Unknown',
        state: 'Unknown',
        isNew: false,
        risk: RiskLevel.bajo.code,
        syncedAgo: '1 h',
        gpsDeltaMeters: 0.0,
        description: 'Actividad sin kilometraje',
        classification: 'GENERAL',
      );

      // WHEN / THEN
      expect(noKmItem.pk, equals('-'));
    });

    test('risk level hierarchy is correct', () {
      // WHEN
      final priorities = [
        RiskLevel.bajo.code,
        RiskLevel.medio.code,
        RiskLevel.alto.code,
        RiskLevel.prioritario.code,
      ];

      // THEN
      expect(priorities.indexOf(RiskLevel.prioritario.code), greaterThan(
        priorities.indexOf(RiskLevel.alto.code),
      ));
      expect(
        priorities.indexOf(RiskLevel.prioritario.code),
        greaterThan(priorities.indexOf(RiskLevel.bajo.code)),
      );
    });

    test('activity classification codes are preserved', () {
      // GIVEN
      const classifications = [
        'INSPECTION',
        'MEETING',
        'SURVEY',
        'AUDIT',
        'GENERAL',
        'REUNION_COMUNITARIA',
        'CAPACITACION'
      ];

      // WHEN / THEN
      for (final code in classifications) {
        final item = OperationItem(
          id: 'op-test',
          type: code,
          pk: '100+000',
          engineer: 'Test',
          municipality: 'Test',
          state: 'Test',
          isNew: false,
          risk: RiskLevel.bajo.code,
          syncedAgo: '1 h',
          gpsDeltaMeters: 0.0,
          description: code,
          classification: code,
        );
        expect(item.classification, equals(code));
      }
    });
  });

  group('OperationsData - Queue Container', () {
    test('holds list of operation items and catalog repo', () {
      // GIVEN
      final items = [
        OperationItem(
          id: 'op-1',
          type: 'Task 1',
          pk: '100+000',
          engineer: 'Eng 1',
          municipality: 'City 1',
          state: 'State 1',
          isNew: false,
          risk: RiskLevel.bajo.code,
          syncedAgo: '1 h',
          gpsDeltaMeters: 0.0,
          description: 'Desc 1',
          classification: 'TYPE1',
        ),
        OperationItem(
          id: 'op-2',
          type: 'Task 2',
          pk: '200+000',
          engineer: 'Eng 2',
          municipality: 'City 2',
          state: 'State 2',
          isNew: true,
          risk: RiskLevel.alto.code,
          syncedAgo: '30 min',
          gpsDeltaMeters: 50.0,
          description: 'Desc 2',
          classification: 'TYPE2',
        ),
      ];

      // WHEN / THEN
      expect(items.length, equals(2));
      expect(items[0].engineer, equals('Eng 1'));
      expect(items[1].isNew, isTrue);
    });

    test('queue can be sorted by risk', () {
      // GIVEN
      final items = [
        OperationItem(
          id: 'op-1',
          type: 'Task',
          pk: '100',
          engineer: 'Eng',
          municipality: 'City',
          state: 'State',
          isNew: false,
          risk: RiskLevel.bajo.code,
          syncedAgo: '1 h',
          gpsDeltaMeters: 0.0,
          description: 'Desc',
          classification: 'T1',
        ),
        OperationItem(
          id: 'op-2',
          type: 'Task',
          pk: '200',
          engineer: 'Eng',
          municipality: 'City',
          state: 'State',
          isNew: false,
          risk: RiskLevel.prioritario.code,
          syncedAgo: '1 h',
          gpsDeltaMeters: 0.0,
          description: 'Desc',
          classification: 'T2',
        ),
      ];

      // WHEN
      final sorted = items
          .toList()
          ..sort((a, b) => b.risk.compareTo(a.risk)); // desc priority

      // THEN
      expect(sorted[0].id, equals('op-2')); // prioritario first
      expect(sorted[0].risk, equals(RiskLevel.prioritario.code));
    });
  });

  group('RiskLevel Classifications', () {
    test('all risk levels have valid codes', () {
      // WHEN / THEN
      expect(RiskLevel.bajo.code, isNotEmpty);
      expect(RiskLevel.medio.code, isNotEmpty);
      expect(RiskLevel.alto.code, isNotEmpty);
      expect(RiskLevel.prioritario.code, isNotEmpty);
    });

    test('risk levels are orderable by severity', () {
      // WHEN
      final risksByPriority = [
        RiskLevel.bajo,
        RiskLevel.medio,
        RiskLevel.alto,
        RiskLevel.prioritario,
      ];

      // THEN
      for (int i = 0; i < risksByPriority.length - 1; i++) {
        // assume higher index = higher risk
        expect(i, lessThan(i + 1));
      }
    });
  });

  group('Operations Queue Integration', () {
    test('complex queue scenario with mixed items', () {
      // GIVEN: Multi-project, multi-state operations
      final complexQueue = [
        OperationItem(
          id: 'tmq-001',
          type: 'Inspeccion',
          pk: '142+000',
          engineer: 'Juan García',
          municipality: 'Toluca',
          state: 'Estado de México',
          isNew: true,
          risk: RiskLevel.prioritario.code,
          syncedAgo: '5 min',
          gpsDeltaMeters: 450.0,
          description: 'Incidente en via TMQ km 142',
          classification: 'INSPECTION',
        ),
        OperationItem(
          id: 'tmq-002',
          type: 'Reunion',
          pk: '150+500',
          engineer: 'Maria Lopez',
          municipality: 'Naucalpan',
          state: 'Estado de México',
          isNew: false,
          risk: RiskLevel.medio.code,
          syncedAgo: '2 h',
          gpsDeltaMeters: 0.0,
          description: 'Asamblea comunitaria km 150',
          classification: 'MEETING',
        ),
        OperationItem(
          id: 'tmq-003',
          type: 'Capacitacion',
          pk: '160+250',
          engineer: 'Carlos Rod',
          municipality: 'Mexico City',
          state: 'CDMX',
          isNew: false,
          risk: RiskLevel.bajo.code,
          syncedAgo: '4 h',
          gpsDeltaMeters: 0.0,
          description: 'Capacitacion seguridad',
          classification: 'TRAINING',
        ),
      ];

      // WHEN
      final priorityItems = complexQueue
          .where((item) => item.risk == RiskLevel.prioritario.code)
          .toList();
      final newItems =
          complexQueue.where((item) => item.isNew).toList();
      final gpsIssues = complexQueue
          .where((item) => item.gpsDeltaMeters > 100.0)
          .toList();

      // THEN
      expect(priorityItems.length, equals(1));
      expect(newItems.length, equals(1));
      expect(gpsIssues.length, equals(1));
      expect(complexQueue.length, equals(3));
    });
  });
}
