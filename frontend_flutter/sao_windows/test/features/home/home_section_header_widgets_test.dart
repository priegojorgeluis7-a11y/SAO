import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sao_windows/features/home/models/task_section_metrics.dart';
import 'package:sao_windows/features/home/widgets/home_section_header.dart';
import 'package:sao_windows/features/home/models/today_activity.dart';
import 'package:sao_windows/features/home/widgets/home_quick_action_button.dart';

void main() {
  group('TaskSectionHeader Widget Tests', () {
    testWidgets('renders header with icon, title, and count badge', (WidgetTester tester) async {
      final metrics = TaskSectionMetrics(
        totalCount: 5,
        completedCount: 2,
        priority: SectionPriority.critical,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskSectionHeader(
              label: 'Por Corregir',
              itemCount: 5,
              metrics: metrics,
              onTap: () {},
              isExpanded: false,
            ),
          ),
        ),
      );

      expect(find.text('Por Corregir'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.byIcon(Icons.warning_rounded), findsOneWidget);
    });

    testWidgets('shows priority label', (WidgetTester tester) async {
      final metrics = TaskSectionMetrics(
        totalCount: 3,
        completedCount: 0,
        priority: SectionPriority.active,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskSectionHeader(
              label: 'Por Iniciar',
              itemCount: 3,
              metrics: metrics,
              onTap: () {},
              isExpanded: false,
            ),
          ),
        ),
      );

      expect(find.text('Trabajo activo'), findsOneWidget);
    });

    testWidgets('animates chevron when expanded', (WidgetTester tester) async {
      final metrics = TaskSectionMetrics(
        totalCount: 1,
        completedCount: 0,
        priority: SectionPriority.awaiting,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskSectionHeader(
              label: 'En Revision',
              itemCount: 1,
              metrics: metrics,
              onTap: () {},
              isExpanded: false,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.expand_more_rounded), findsOneWidget);

      // Verify chevron rotation based on isExpanded
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskSectionHeader(
              label: 'En Revision',
              itemCount: 1,
              metrics: metrics,
              onTap: () {},
              isExpanded: true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.expand_more_rounded), findsOneWidget);
    });

    testWidgets('calls onTap when header tapped', (WidgetTester tester) async {
      bool tapped = false;
      final metrics = TaskSectionMetrics(
        totalCount: 2,
        completedCount: 0,
        priority: SectionPriority.critical,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskSectionHeader(
              label: 'Error de Envio',
              itemCount: 2,
              metrics: metrics,
              onTap: () => tapped = true,
              isExpanded: false,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(InkWell));
      expect(tapped, isTrue);
    });

    testWidgets('shows urgency hint for critical items', (WidgetTester tester) async {
      final metrics = TaskSectionMetrics(
        totalCount: 7,
        completedCount: 0,
        priority: SectionPriority.critical,
        criticalCount: 3,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskSectionHeader(
              label: 'Por Corregir',
              itemCount: 7,
              metrics: metrics,
              onTap: () {},
              isExpanded: false,
            ),
          ),
        ),
      );

      expect(find.text('3 críticos'), findsOneWidget);
    });

    testWidgets('uses custom icon when provided', (WidgetTester tester) async {
      final metrics = TaskSectionMetrics(
        totalCount: 1,
        completedCount: 0,
        priority: SectionPriority.active,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskSectionHeader(
              label: 'Custom Section',
              itemCount: 1,
              metrics: metrics,
              onTap: () {},
              isExpanded: false,
              customIcon: Icons.star_rounded,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    });
  });

  group('TaskSectionHeaderWithProgress Widget Tests', () {
    testWidgets('renders progress bar when not expanded', (WidgetTester tester) async {
      final metrics = TaskSectionMetrics(
        totalCount: 10,
        completedCount: 4,
        priority: SectionPriority.active,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskSectionHeaderWithProgress(
              label: 'Por Iniciar',
              itemCount: 10,
              metrics: metrics,
              onTap: () {},
              isExpanded: false,
            ),
          ),
        ),
      );

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('4/10 (40%)'), findsOneWidget);
    });

    testWidgets('hides progress bar when expanded', (WidgetTester tester) async {
      final metrics = TaskSectionMetrics(
        totalCount: 10,
        completedCount: 4,
        priority: SectionPriority.active,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskSectionHeaderWithProgress(
              label: 'Por Iniciar',
              itemCount: 10,
              metrics: metrics,
              onTap: () {},
              isExpanded: true,
            ),
          ),
        ),
      );

      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('shows time display when available', (WidgetTester tester) async {
      final metrics = TaskSectionMetrics(
        totalCount: 5,
        completedCount: 0,
        priority: SectionPriority.active,
        averageTimeInSection: const Duration(hours: 2, minutes: 30),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskSectionHeaderWithProgress(
              label: 'En Curso',
              itemCount: 5,
              metrics: metrics,
              onTap: () {},
              isExpanded: false,
            ),
          ),
        ),
      );

      expect(find.text('⏱️ Prom 2h 30m'), findsOneWidget);
    });
  });

  group('QuickActionButton Widget Tests', () {
    testWidgets('renders INICIAR button for INICIAR_ACTIVIDAD', (WidgetTester tester) async {
      final activity = TodayActivity(
        id: 'id1',
        title: 'Test Activity',
        frente: 'Frente A',
        municipio: 'Municipio',
        estado: 'Estado',
        pk: 100,
        status: ActivityStatus.hoy,
        executionState: ExecutionState.pendiente,
        createdAt: DateTime.now(),
        operationalState: 'PENDIENTE',
        reviewState: 'NOT_APPLICABLE',
        nextAction: 'INICIAR_ACTIVIDAD',
        isUnplanned: false,
        isRejected: false,
        syncState: ActivitySyncState.synced,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickActionButton(
              activity: activity,
              onPressed: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Iniciar'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('renders TERMINAR button for TERMINAR_ACTIVIDAD', (WidgetTester tester) async {
      final activity = TodayActivity(
        id: 'id1',
        title: 'Test Activity',
        frente: 'Frente A',
        municipio: 'Municipio',
        estado: 'Estado',
        pk: 100,
        status: ActivityStatus.hoy,
        executionState: ExecutionState.enCurso,
        createdAt: DateTime.now(),
        operationalState: 'EN_CURSO',
        reviewState: 'NOT_APPLICABLE',
        nextAction: 'TERMINAR_ACTIVIDAD',
        isUnplanned: false,
        isRejected: false,
        syncState: ActivitySyncState.synced,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickActionButton(
              activity: activity,
              onPressed: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Terminar'), findsOneWidget);
    });

    testWidgets('renders COMPLETAR button for COMPLETAR_WIZARD', (WidgetTester tester) async {
      final activity = TodayActivity(
        id: 'id1',
        title: 'Test Activity',
        frente: 'Frente A',
        municipio: 'Municipio',
        estado: 'Estado',
        pk: 100,
        status: ActivityStatus.hoy,
        executionState: ExecutionState.revisionPendiente,
        createdAt: DateTime.now(),
        operationalState: 'POR_COMPLETAR',
        reviewState: 'NOT_APPLICABLE',
        nextAction: 'COMPLETAR_WIZARD',
        isUnplanned: false,
        isRejected: false,
        syncState: ActivitySyncState.synced,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickActionButton(
              activity: activity,
              onPressed: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Completar'), findsOneWidget);
    });

    testWidgets('renders CORREGIR button for CORREGIR_Y_REENVIAR', (WidgetTester tester) async {
      final activity = TodayActivity(
        id: 'id1',
        title: 'Test Activity',
        frente: 'Frente A',
        municipio: 'Municipio',
        estado: 'Estado',
        pk: 100,
        status: ActivityStatus.hoy,
        executionState: ExecutionState.pendiente,
        createdAt: DateTime.now(),
        operationalState: 'PENDIENTE',
        reviewState: 'REJECTED',
        nextAction: 'CORREGIR_Y_REENVIAR',
        isUnplanned: false,
        isRejected: true,
        syncState: ActivitySyncState.synced,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickActionButton(
              activity: activity,
              onPressed: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Corregir'), findsOneWidget);
    });

    testWidgets('renders SINCRONIZAR button for SINCRONIZAR_PENDIENTE', (WidgetTester tester) async {
      final activity = TodayActivity(
        id: 'id1',
        title: 'Test Activity',
        frente: 'Frente A',
        municipio: 'Municipio',
        estado: 'Estado',
        pk: 100,
        status: ActivityStatus.hoy,
        executionState: ExecutionState.terminada,
        createdAt: DateTime.now(),
        operationalState: 'EN_CURSO',
        reviewState: 'NOT_APPLICABLE',
        nextAction: 'SINCRONIZAR_PENDIENTE',
        isUnplanned: false,
        isRejected: false,
        syncState: ActivitySyncState.pending,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickActionButton(
              activity: activity,
              onPressed: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Sincronizar'), findsOneWidget);
    });

    testWidgets('calls onPressed with correct action name', (WidgetTester tester) async {
      String? capturedAction;
      final activity = TodayActivity(
        id: 'id1',
        title: 'Test Activity',
        frente: 'Frente A',
        municipio: 'Municipio',
        estado: 'Estado',
        pk: 100,
        status: ActivityStatus.hoy,
        executionState: ExecutionState.pendiente,
        createdAt: DateTime.now(),
        operationalState: 'PENDIENTE',
        reviewState: 'NOT_APPLICABLE',
        nextAction: 'INICIAR_ACTIVIDAD',
        isUnplanned: false,
        isRejected: false,
        syncState: ActivitySyncState.synced,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickActionButton(
              activity: activity,
              onPressed: (action) => capturedAction = action,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(OutlinedButton));
      expect(capturedAction, equals('INICIAR'));
    });

    testWidgets('shows loading state when isLoading true', (WidgetTester tester) async {
      final activity = TodayActivity(
        id: 'id1',
        title: 'Test Activity',
        frente: 'Frente A',
        municipio: 'Municipio',
        estado: 'Estado',
        pk: 100,
        status: ActivityStatus.hoy,
        executionState: ExecutionState.pendiente,
        createdAt: DateTime.now(),
        operationalState: 'PENDIENTE',
        reviewState: 'NOT_APPLICABLE',
        nextAction: 'SINCRONIZAR_PENDIENTE',
        isUnplanned: false,
        isRejected: false,
        syncState: ActivitySyncState.pending,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickActionButton(
              activity: activity,
              onPressed: (_) {},
              isLoading: true,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders filled button when outlined=false', (WidgetTester tester) async {
      final activity = TodayActivity(
        id: 'id1',
        title: 'Test Activity',
        frente: 'Frente A',
        municipio: 'Municipio',
        estado: 'Estado',
        pk: 100,
        status: ActivityStatus.hoy,
        executionState: ExecutionState.pendiente,
        createdAt: DateTime.now(),
        operationalState: 'PENDIENTE',
        reviewState: 'NOT_APPLICABLE',
        nextAction: 'INICIAR_ACTIVIDAD',
        isUnplanned: false,
        isRejected: false,
        syncState: ActivitySyncState.synced,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuickActionButton(
              activity: activity,
              onPressed: (_) {},
              outlined: false,
            ),
          ),
        ),
      );

      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.byType(OutlinedButton), findsNothing);
    });
  });
}
