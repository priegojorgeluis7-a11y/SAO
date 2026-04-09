import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sao_windows/features/home/home_task_sections.dart';
import 'package:sao_windows/features/home/models/task_section_metrics.dart';
import 'package:sao_windows/features/home/models/today_activity.dart';

void main() {
  group('Task Section Metrics Calculation', () {
    test('calculateSectionMetrics returns empty metrics for no activities', () {
      final metrics = calculateSectionMetrics('por_iniciar', []);
      
      expect(metrics.isEmpty, isTrue);
      expect(metrics.totalCount, equals(0));
      expect(metrics.criticalCount, equals(0));
    });

    test('calculateSectionMetrics marks all items as critical for error_sync', () {
      final now = DateTime.now();
      final activities = List.generate(
        3,
        (i) => TodayActivity(
          id: 'id$i',
          title: 'Activity $i',
          frente: 'Frente A',
          municipio: 'Municipio',
          estado: 'Estado',
          pk: 100 + i,
          status: ActivityStatus.hoy,
          executionState: ExecutionState.pendiente,
          horaInicio: now,
          createdAt: now,
          operationalState: 'PENDIENTE',
          reviewState: 'NOT_APPLICABLE',
          nextAction: 'REVISAR_ERROR_SYNC',
          isUnplanned: false,
          isRejected: false,
          syncState: ActivitySyncState.error,
        ),
      );

      final metrics = calculateSectionMetrics('error_sync', activities);

      expect(metrics.totalCount, equals(3));
      expect(metrics.criticalCount, equals(3));
      expect(metrics.priority, equals(SectionPriority.critical));
    });

    test('calculateSectionMetrics detects correct priority for por_corregir', () {
      final now = DateTime.now();
      final activity = TodayActivity(
        id: 'id1',
        title: 'Rejected Activity',
        frente: 'Frente B',
        municipio: 'Municipio',
        estado: 'Estado',
        pk: 100,
        status: ActivityStatus.hoy,
        executionState: ExecutionState.pendiente,
        horaInicio: now,
        createdAt: now,
        operationalState: 'PENDIENTE',
        reviewState: 'REJECTED',
        nextAction: 'CORREGIR_Y_REENVIAR',
        isUnplanned: false,
        isRejected: true,
        syncState: ActivitySyncState.synced,
      );

      final metrics = calculateSectionMetrics('por_corregir', [activity]);

      expect(metrics.priority, equals(SectionPriority.critical));
      expect(metrics.totalCount, equals(1));
      expect(metrics.criticalCount, equals(1));
    });

    test('calculateSectionMetrics assigns active priority for por_iniciar', () {
      final now = DateTime.now();
      final activity = TodayActivity(
        id: 'id1',
        title: 'Ready Activity',
        frente: 'Frente A',
        municipio: 'Municipio',
        estado: 'Estado',
        pk: 100,
        status: ActivityStatus.hoy,
        executionState: ExecutionState.pendiente,
        createdAt: now,
        operationalState: 'PENDIENTE',
        reviewState: 'NOT_APPLICABLE',
        nextAction: 'INICIAR_ACTIVIDAD',
        isUnplanned: false,
        isRejected: false,
        syncState: ActivitySyncState.synced,
      );

      final metrics = calculateSectionMetrics('por_iniciar', [activity]);

      expect(metrics.priority, equals(SectionPriority.active));
      expect(metrics.totalCount, equals(1));
    });

    test('calculateSectionMetrics assigns awaiting priority for en_revision', () {
      final now = DateTime.now();
      final activity = TodayActivity(
        id: 'id1',
        title: 'In Review',
        frente: 'Frente C',
        municipio: 'Municipio',
        estado: 'Estado',
        pk: 100,
        status: ActivityStatus.hoy,
        executionState: ExecutionState.pendiente,
        createdAt: now,
        operationalState: 'EN_CURSO',
        reviewState: 'PENDING_REVIEW',
        nextAction: 'ESPERAR_DECISION_COORDINACION',
        isUnplanned: false,
        isRejected: false,
        syncState: ActivitySyncState.synced,
      );

      final metrics = calculateSectionMetrics('en_revision', [activity]);

      expect(metrics.priority, equals(SectionPriority.awaiting));
    });

    test('calculateSectionMetrics computes average time in section', () {
      final now = DateTime.now();
      final oneHourAgo = now.subtract(const Duration(hours: 1));
      final activities = [
        TodayActivity(
          id: 'id1',
          title: 'Old Activity',
          frente: 'Frente A',
          municipio: 'Municipio',
          estado: 'Estado',
          pk: 100,
          status: ActivityStatus.hoy,
          executionState: ExecutionState.pendiente,
          createdAt: oneHourAgo,
          operationalState: 'PENDIENTE',
          reviewState: 'NOT_APPLICABLE',
          nextAction: 'INICIAR_ACTIVIDAD',
          isUnplanned: false,
          isRejected: false,
          syncState: ActivitySyncState.synced,
        ),
      ];

      final metrics = calculateSectionMetrics('por_iniciar', activities);

      expect(metrics.averageTimeInSection, isNotNull);
      expect(metrics.averageTimeInSection!.inMinutes, greaterThan(55));
      expect(metrics.averageTimeInSection!.inMinutes, lessThan(65));
    });
  });

  group('Home Task Sections Grouping', () {
    test('buildHomeTaskSections groups activities by priority and frente', () {
      final now = DateTime.now();
      final activities = [
        // Critical section
        TodayActivity(
          id: 'id1',
          title: 'Activity 1',
          frente: 'Frente A',
          municipio: 'Municipio',
          estado: 'Estado',
          pk: 100,
          status: ActivityStatus.hoy,
          executionState: ExecutionState.pendiente,
          createdAt: now,
          operationalState: 'PENDIENTE',
          reviewState: 'REJECTED',
          nextAction: 'CORREGIR_Y_REENVIAR',
          isUnplanned: false,
          isRejected: true,
          syncState: ActivitySyncState.synced,
        ),
        // Active section
        TodayActivity(
          id: 'id2',
          title: 'Activity 2',
          frente: 'Frente A',
          municipio: 'Municipio',
          estado: 'Estado',
          pk: 101,
          status: ActivityStatus.hoy,
          executionState: ExecutionState.pendiente,
          createdAt: now,
          operationalState: 'PENDIENTE',
          reviewState: 'NOT_APPLICABLE',
          nextAction: 'INICIAR_ACTIVIDAD',
          isUnplanned: false,
          isRejected: false,
          syncState: ActivitySyncState.synced,
        ),
        // Awaiting section
        TodayActivity(
          id: 'id3',
          title: 'Activity 3',
          frente: 'Frente B',
          municipio: 'Municipio',
          estado: 'Estado',
          pk: 102,
          status: ActivityStatus.hoy,
          executionState: ExecutionState.pendiente,
          createdAt: now,
          operationalState: 'EN_CURSO',
          reviewState: 'PENDING_REVIEW',
          nextAction: 'ESPERAR_DECISION_COORDINACION',
          isUnplanned: false,
          isRejected: false,
          syncState: ActivitySyncState.synced,
        ),
      ];

      final sections = buildHomeTaskSections(activities);

      expect(sections, hasLength(3));
      
      // First section should be critical (por_corregir)
      expect(sections[0].id, equals('por_corregir'));
      expect(sections[0].metrics.priority, equals(SectionPriority.critical));
      expect(sections[0].itemCount, equals(1));
      expect(sections[0].shouldAutoExpand, isTrue);

      // Second section should be active (por_iniciar)
      expect(sections[1].id, equals('por_iniciar'));
      expect(sections[1].metrics.priority, equals(SectionPriority.active));
      expect(sections[1].itemCount, equals(1));
      expect(sections[1].shouldAutoExpand, isFalse);

      // Third section should be awaiting (en_revision)
      expect(sections[2].id, equals('en_revision'));
      expect(sections[2].metrics.priority, equals(SectionPriority.awaiting));
      expect(sections[2].itemCount, equals(1));
    });

    test('buildHomeTaskSections skips empty sections', () {
      final now = DateTime.now();
      final activities = [
        TodayActivity(
          id: 'id1',
          title: 'Activity 1',
          frente: 'Frente A',
          municipio: 'Municipio',
          estado: 'Estado',
          pk: 100,
          status: ActivityStatus.hoy,
          executionState: ExecutionState.pendiente,
          createdAt: now,
          operationalState: 'PENDIENTE',
          reviewState: 'NOT_APPLICABLE',
          nextAction: 'INICIAR_ACTIVIDAD',
          isUnplanned: false,
          isRejected: false,
          syncState: ActivitySyncState.synced,
        ),
      ];

      final sections = buildHomeTaskSections(activities);

      expect(sections, hasLength(1));
      expect(sections[0].id, equals('por_iniciar'));
    });

    test('buildHomeTaskSections groups by frente within section', () {
      final now = DateTime.now();
      final activities = [
        TodayActivity(
          id: 'id1',
          title: 'Activity 1A',
          frente: 'Frente A',
          municipio: 'Municipio',
          estado: 'Estado',
          pk: 100,
          status: ActivityStatus.hoy,
          executionState: ExecutionState.pendiente,
          createdAt: now,
          operationalState: 'PENDIENTE',
          reviewState: 'NOT_APPLICABLE',
          nextAction: 'INICIAR_ACTIVIDAD',
          isUnplanned: false,
          isRejected: false,
          syncState: ActivitySyncState.synced,
        ),
        TodayActivity(
          id: 'id2',
          title: 'Activity 1B',
          frente: 'Frente A',
          municipio: 'Municipio',
          estado: 'Estado',
          pk: 101,
          status: ActivityStatus.hoy,
          executionState: ExecutionState.pendiente,
          createdAt: now,
          operationalState: 'PENDIENTE',
          reviewState: 'NOT_APPLICABLE',
          nextAction: 'INICIAR_ACTIVIDAD',
          isUnplanned: false,
          isRejected: false,
          syncState: ActivitySyncState.synced,
        ),
        TodayActivity(
          id: 'id3',
          title: 'Activity 2',
          frente: 'Frente B',
          municipio: 'Municipio',
          estado: 'Estado',
          pk: 102,
          status: ActivityStatus.hoy,
          executionState: ExecutionState.pendiente,
          createdAt: now,
          operationalState: 'PENDIENTE',
          reviewState: 'NOT_APPLICABLE',
          nextAction: 'INICIAR_ACTIVIDAD',
          isUnplanned: false,
          isRejected: false,
          syncState: ActivitySyncState.synced,
        ),
      ];

      final sections = buildHomeTaskSections(activities);

      expect(sections, hasLength(1));
      expect(sections[0].itemCount, equals(3));
      expect(sections[0].groupedByFrente.keys, containsAll(['Frente A', 'Frente B']));
      expect(sections[0].groupedByFrente['Frente A'], hasLength(2));
      expect(sections[0].groupedByFrente['Frente B'], hasLength(1));
    });
  });

  group('Section Metrics Display Formatting', () {
    test('progressDisplay formats correctly', () {
      final metrics = TaskSectionMetrics(
        totalCount: 7,
        completedCount: 3,
        priority: SectionPriority.active,
      );

      expect(metrics.progressDisplay, equals('3/7 (43%)'));
    });

    test('progressDisplay shows Vacío for empty section', () {
      final metrics = TaskSectionMetrics(
        totalCount: 0,
        completedCount: 0,
        priority: SectionPriority.awaiting,
      );

      expect(metrics.progressDisplay, equals('Vacío'));
    });

    test('timeDisplay formats hours and minutes', () {
      final metrics = TaskSectionMetrics(
        totalCount: 5,
        completedCount: 0,
        priority: SectionPriority.active,
        averageTimeInSection: const Duration(hours: 2, minutes: 15),
      );

      expect(metrics.timeDisplay, equals('⏱️ Prom 2h 15m'));
    });

    test('timeDisplay handles only minutes', () {
      final metrics = TaskSectionMetrics(
        totalCount: 5,
        completedCount: 0,
        priority: SectionPriority.active,
        averageTimeInSection: const Duration(minutes: 45),
      );

      expect(metrics.timeDisplay, equals('⏱️ Prom 45m'));
    });

    test('urgencyHint indicates critical items', () {
      final metrics = TaskSectionMetrics(
        totalCount: 10,
        completedCount: 2,
        priority: SectionPriority.critical,
        criticalCount: 3,
      );

      expect(metrics.urgencyHint, equals('3 críticos'));
    });

    test('urgencyHint indicates low volume', () {
      final metrics = TaskSectionMetrics(
        totalCount: 1,
        completedCount: 0,
        priority: SectionPriority.active,
        criticalCount: 0,
      );

      expect(metrics.urgencyHint, equals('Bajo volumen'));
    });
  });

  group('Section Priority Color Coding', () {
    test('critical priority has red color', () {
      expect(
        SectionPriority.critical.color,
        equals(const Color(0xFFEF4444)),
      );
    });

    test('active priority has blue color', () {
      expect(
        SectionPriority.active.color,
        equals(const Color(0xFF3B82F6)),
      );
    });

    test('awaiting priority has gray color', () {
      expect(
        SectionPriority.awaiting.color,
        equals(const Color(0xFF9CA3AF)),
      );
    });

    test('background colors are lighter variants', () {
      expect(
        SectionPriority.critical.backgroundColor,
        equals(const Color(0xFFFEE2E2)),
      );
      expect(
        SectionPriority.active.backgroundColor,
        equals(const Color(0xFFEFF6FF)),
      );
      expect(
        SectionPriority.awaiting.backgroundColor,
        equals(const Color(0xFFF3F4F6)),
      );
    });

    test('icons match priority', () {
      expect(SectionPriority.critical.icon, equals(Icons.warning_rounded));
      expect(SectionPriority.active.icon, equals(Icons.sync_rounded));
      expect(SectionPriority.awaiting.icon, equals(Icons.schedule_rounded));
    });
  });
}
