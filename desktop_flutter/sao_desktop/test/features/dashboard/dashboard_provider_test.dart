// desktop_flutter/sao_desktop/test/features/dashboard/dashboard_provider_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sao_desktop/core/providers/project_providers.dart';
import 'package:sao_desktop/data/repositories/backend_api_client.dart';
import 'package:sao_desktop/features/auth/app_session_controller.dart';
import 'package:sao_desktop/features/dashboard/dashboard_page.dart';
import 'package:sao_desktop/features/dashboard/dashboard_provider.dart';

class _DashboardFakeBackendApiClient extends BackendApiClient {
  const _DashboardFakeBackendApiClient(this.responses);

  final Map<String, Object> responses;

  @override
  Future<dynamic> getJson(String path) async {
    for (final entry in responses.entries) {
      if (path == entry.key || path.startsWith(entry.key)) {
        final value = entry.value;
        if (value is Exception) throw value;
        return value;
      }
    }
    throw Exception('Unexpected GET $path');
  }
}

void main() {
  group('DashboardData - KPI Calculations', () {
    test('avancePct returns percentage of approved', () {
      // GIVEN
      const dashData = DashboardData(
        pendingCount: 3,
        approvedCount: 7,
        rejectedCount: 0,
        needsFixCount: 0,
        totalInQueue: 10,
        projectId: 'TMQ',
        range: DashboardRange.today,
        approvedTrend: DashboardTrend(current: 7, previous: 5),
        rejectedTrend: DashboardTrend(current: 0, previous: 0),
        needsFixTrend: DashboardTrend(current: 0, previous: 0),
        pendingTrend: DashboardTrend(current: 3, previous: 5),
        queueItems: [],
        geoPoints: [],
        topErrors: [],
        locationCounts: [],
        riskCounts: {},
        frontProgress: [],
        avgValidationHours: 2.5,
      );

      // WHEN
      final pct = dashData.avancePct;

      // THEN
      expect(pct, equals(0.7)); // 7/10 = 70%
      expect(dashData.approvedTrend.delta, equals(2)); // 7 - 5 = 2
      expect(dashData.pendingTrend.delta, equals(-2)); // 3 - 5 = -2
    });

    test('avancePct returns 0 when totalInQueue is 0', () {
      // GIVEN
      const dashData = DashboardData(
        pendingCount: 0,
        approvedCount: 0,
        rejectedCount: 0,
        needsFixCount: 0,
        totalInQueue: 0,
        projectId: 'TMQ',
        range: DashboardRange.today,
        approvedTrend: DashboardTrend(current: 0, previous: 0),
        rejectedTrend: DashboardTrend(current: 0, previous: 0),
        needsFixTrend: DashboardTrend(current: 0, previous: 0),
        pendingTrend: DashboardTrend(current: 0, previous: 0),
        queueItems: [],
        geoPoints: [],
        topErrors: [],
        locationCounts: [],
        riskCounts: {},
        frontProgress: [],
        avgValidationHours: 0,
      );

      // WHEN / THEN
      expect(dashData.avancePct, equals(0.0));
    });
  });

  group('DashboardTrend', () {
    test('computes delta correctly', () {
      // GIVEN
      const trend = DashboardTrend(current: 15, previous: 10);

      // WHEN
      final delta = trend.delta;

      // THEN
      expect(delta, equals(5)); // +5 improvement
    });

    test('delta can be negative', () {
      // GIVEN
      const trend = DashboardTrend(current: 8, previous: 12);

      // WHEN
      final delta = trend.delta;

      // THEN
      expect(delta, equals(-4)); // -4 regression
    });
  });

  group('ValidationQueueItem', () {
    test('isOver24h returns true for items older than 24 hours', () {
      // GIVEN
      final oldCreatedAt = DateTime.now().toUtc().subtract(const Duration(hours: 25));
      final queueItem = ValidationQueueItem(
        id: 'item-1',
        projectId: 'TMQ',
        userName: 'Juan',
        activityType: 'Inspection',
        pk: '142+000',
        front: 'Frente A',
        municipality: 'Toluca',
        risk: 'high',
        severity: 'critical',
        status: 'pending_approval',
        createdAt: oldCreatedAt,
        lat: 19.2832,
        lon: -99.6554,
      );

      // WHEN / THEN
      expect(queueItem.isOver24h, isTrue);
    });

    test('isOver24h returns false for items newer than 24 hours', () {
      // GIVEN
      final recentCreatedAt = DateTime.now().toUtc().subtract(const Duration(hours: 10));
      final queueItem = ValidationQueueItem(
        id: 'item-1',
        projectId: 'TMQ',
        userName: 'Juan',
        activityType: 'Inspection',
        pk: '142+000',
        front: 'Frente A',
        municipality: 'Toluca',
        risk: 'low',
        severity: 'info',
        status: 'pending_approval',
        createdAt: recentCreatedAt,
        lat: 19.2832,
        lon: -99.6554,
      );

      // WHEN / THEN
      expect(queueItem.isOver24h, isFalse);
    });
  });

  group('DashboardGeoPoint', () {
    test('maps location and review status correctly', () {
      // GIVEN
      const geoPoint = DashboardGeoPoint(
        id: 'geo-1',
        projectId: 'TMQ',
        risk: 'critical',
        status: 'COMPLETADA',
        reviewStatus: 'approved',
        reviewDecision: 'APROBADO',
        front: 'Frente A',
        municipality: 'Toluca',
        state: 'Estado de Mexico',
        label: 'Km 142 - Inspección',
        assignedToUserId: 'user-123',
        assignedName: 'Juan García',
        lat: 19.2832,
        lon: -99.6554,
        hasReport: true,
      );

      // WHEN / THEN
      expect(geoPoint.id, 'geo-1');
      expect(geoPoint.projectId, 'TMQ');
      expect(geoPoint.risk, 'critical');
      expect(geoPoint.lat, lessThan(90));
      expect(geoPoint.lon, lessThan(180));
      expect(geoPoint.municipality, 'Toluca');
      expect(geoPoint.hasReport, isTrue);
    });

    test('handles null optional fields', () {
      // GIVEN
      const geoPoint = DashboardGeoPoint(
        id: 'geo-2',
        projectId: 'TMQ',
        risk: 'low',
        status: 'PENDIENTE',
        reviewStatus: 'pending',
        front: 'Frente B',
        municipality: 'Mexico City',
        state: 'Mexico City',
        label: 'Km 150',
        lat: 19.4326,
        lon: -99.1332,
        hasReport: false,
      );

      // WHEN / THEN
      expect(geoPoint.reviewDecision, isNull);
      expect(geoPoint.assignedToUserId, isNull);
      expect(geoPoint.assignedName, isNull);
      expect(geoPoint.hasReport, isFalse);
    });

    test('uses activity id fallback from backend payload', () {
      final geoPoint = dashboardGeoPointFromJson(
        {
          'activity_id': 'activity-42',
          'project_id': 'TMQ',
          'risk_level': 'alto',
          'status': 'COMPLETADA',
          'review_status': 'APPROVED',
          'front_name': 'Frente A',
          'municipio': 'Doctor Mora',
          'estado': 'Guanajuato',
          'activity_type': 'Asamblea',
          'assignee_name': 'Operativo Demo',
          'assignee_user_id': 'user-42',
          'document_url': 'https://example.com/report.pdf',
        },
        lat: 21.142,
        lon: -100.312,
      );

      expect(geoPoint.id, 'activity-42');
      expect(geoPoint.projectId, 'TMQ');
      expect(geoPoint.hasReport, isTrue);
      expect(geoPoint.label, 'Asamblea');
      expect(geoPoint.assignedName, 'Operativo Demo');
      expect(geoPoint.assignedToUserId, 'user-42');
    });
  });

  group('Dashboard filtering helpers', () {
    test('matches KPI filters even when backend status uses alternate tokens', () {
      final pendingItem = ValidationQueueItem(
        id: 'item-1',
        projectId: 'TMQ',
        userName: 'Juan',
        activityType: 'Inspección',
        pk: '142+000',
        front: 'Frente A',
        municipality: 'Toluca',
        risk: 'alto',
        severity: 'critical',
        status: 'pending_approval',
        createdAt: DateTime.utc(2026, 4, 19, 10),
      );

      final approvedItem = ValidationQueueItem(
        id: 'item-2',
        projectId: 'TMQ',
        userName: 'Ana',
        activityType: 'Asamblea',
        pk: '143+000',
        front: 'Frente B',
        municipality: 'Toluca',
        risk: 'medio',
        severity: 'info',
        status: 'approved',
        createdAt: DateTime.utc(2026, 4, 19, 11),
      );

      expect(dashboardMatchesKpiFilter(pendingItem, DashboardKpiFilter.pending), isTrue);
      expect(dashboardMatchesKpiFilter(approvedItem, DashboardKpiFilter.approved), isTrue);
      expect(dashboardMatchesKpiFilter(approvedItem, DashboardKpiFilter.rejected), isFalse);
    });

    test('normalizes planning map filters for uppercase risk and review aliases', () {
      const point = DashboardGeoPoint(
        id: 'geo-3',
        projectId: 'TMQ',
        risk: 'ALTO',
        status: 'approved',
        reviewStatus: 'pending',
        reviewDecision: 'approve',
        front: 'Frente C',
        municipality: 'Celaya',
        state: 'Guanajuato',
        label: 'Actividad crítica',
        assignedName: 'Marta',
        lat: 20.5,
        lon: -100.8,
        hasReport: true,
      );

      expect(
        dashboardPointMatchesPlanningFilters(
          point,
          statusFilter: 'COMPLETADA',
          riskFilter: 'alto',
          reviewFilter: 'APROBADO',
          userFilter: 'Todo',
          frontFilter: 'Todo',
          stateFilter: 'Todo',
          municipalityFilter: 'Todo',
          searchQuery: 'critica',
        ),
        isTrue,
      );
    });

    test('builds dashboard user options with Todo and deduped names', () {
      final options = resolveDashboardUserOptions(
        projectUsers: const ['Operativo TMQ', 'Jorge Priego Cruz'],
        queueItems: [
          ValidationQueueItem(
            id: '1',
            projectId: 'TMQ',
            userName: 'Jorge Priego Cruz',
            activityType: 'Inspección',
            pk: '10+000',
            front: 'A',
            municipality: 'Doctor Mora',
            risk: 'medio',
            severity: 'info',
            status: 'COMPLETADA',
            createdAt: DateTime.utc(2026, 4, 19, 10),
          ),
        ],
        geoPoints: const [
          DashboardGeoPoint(
            id: 'g1',
            projectId: 'TMQ',
            risk: 'medio',
            status: 'COMPLETADA',
            reviewStatus: 'APPROVED',
            front: 'Frente A',
            municipality: 'Doctor Mora',
            state: 'Guanajuato',
            label: 'Actividad',
            assignedName: 'jesus gaspar rios',
            lat: 21.1,
            lon: -100.3,
            hasReport: true,
          ),
        ],
      );

      expect(options.first, 'Todo');
      expect(options, contains('Operativo TMQ'));
      expect(options, contains('Jorge Priego Cruz'));
      expect(options, contains('jesus gaspar rios'));
    });

    test('keeps project users available even when dashboard data is empty', () {
      final options = resolveDashboardUserOptions(
        projectUsers: const ['Operativo TMQ', 'Supervisor TMQ'],
        queueItems: const [],
        geoPoints: const [],
      );

      expect(options, equals(const ['Todo', 'Operativo TMQ', 'Supervisor TMQ']));
    });

    test('matches dashboard user filter by responsible name', () {
      expect(dashboardMatchesUserFilter('Jorge Priego Cruz', 'Todo'), isTrue);
      expect(dashboardMatchesUserFilter('Jorge Priego Cruz', 'Jorge Priego Cruz'), isTrue);
      expect(dashboardMatchesUserFilter('Jesus Gaspar Rios', 'Jorge Priego Cruz'), isFalse);
    });

    test('critical queue keeps only alto prioritario or conflicts', () {
      final highRiskItem = ValidationQueueItem(
        id: 'high-risk',
        projectId: 'TMQ',
        userName: 'Jorge',
        activityType: 'Inspección',
        pk: '10+000',
        front: 'Norte',
        municipality: 'Doctor Mora',
        risk: 'alto',
        severity: 'info',
        status: 'PENDIENTE',
        createdAt: DateTime.utc(2026, 4, 19, 10),
      );
      final conflictItem = ValidationQueueItem(
        id: 'conflict',
        projectId: 'TMQ',
        userName: 'Ana',
        activityType: 'Asamblea',
        pk: '11+000',
        front: 'Sur',
        municipality: 'San Luis',
        risk: 'medio',
        severity: 'info',
        status: 'PENDIENTE',
        hasConflicts: true,
        createdAt: DateTime.utc(2026, 4, 19, 11),
      );
      final lowRiskItem = ValidationQueueItem(
        id: 'low-risk',
        projectId: 'TMQ',
        userName: 'Luis',
        activityType: 'Recorrido',
        pk: '12+000',
        front: 'Centro',
        municipality: 'Celaya',
        risk: 'bajo',
        severity: 'info',
        status: 'PENDIENTE',
        createdAt: DateTime.utc(2026, 4, 19, 12),
      );

      expect(isCriticalDashboardQueueItem(highRiskItem), isTrue);
      expect(isCriticalDashboardQueueItem(conflictItem), isTrue);
      expect(isCriticalDashboardQueueItem(lowRiskItem), isFalse);
    });

    test('filters map points by front state and municipality', () {
      const point = DashboardGeoPoint(
        id: 'geo-4',
        projectId: 'TMQ',
        risk: 'medio',
        status: 'COMPLETADA',
        reviewStatus: 'APPROVED',
        front: 'Frente Norte',
        municipality: 'Doctor Mora',
        state: 'Guanajuato',
        label: 'Actividad territorial',
        assignedName: 'Operativo TMQ',
        lat: 21.14,
        lon: -100.31,
        hasReport: true,
      );

      expect(
        dashboardPointMatchesPlanningFilters(
          point,
          statusFilter: 'todos',
          riskFilter: 'todos',
          reviewFilter: 'todos',
          userFilter: 'Todo',
          frontFilter: 'Frente Norte',
          stateFilter: 'Guanajuato',
          municipalityFilter: 'Doctor Mora',
          searchQuery: '',
        ),
        isTrue,
      );

      expect(
        dashboardPointMatchesPlanningFilters(
          point,
          statusFilter: 'todos',
          riskFilter: 'todos',
          reviewFilter: 'todos',
          userFilter: 'Todo',
          frontFilter: 'Frente Sur',
          stateFilter: 'Todo',
          municipalityFilter: 'Todo',
          searchQuery: '',
        ),
        isFalse,
      );
    });
  });

  group('Dashboard map data hydration', () {
    test('keeps project activities visible even when assignments only contain one user', () {
      final scoped = scopeDashboardItemsToAssignments(
        const [
          {
            'id': 'activity-1',
            'project_id': 'TMQ',
            'title': 'Actividad de Jorge',
            'assigned_name': 'Jorge',
            'latitude': 20.1,
            'longitude': -100.2,
          },
          {
            'id': 'activity-2',
            'project_id': 'TMQ',
            'title': 'Actividad de Fernanda',
            'assigned_name': 'Fernanda',
            'latitude': 20.2,
            'longitude': -100.3,
          },
        ],
        const [
          {
            'id': 'activity-1',
            'project_id': 'TMQ',
            'assigned_to_user_id': 'user-1',
            'assigned_name': 'Jorge',
          },
        ],
      );

      expect(scoped, hasLength(2));
      expect(scoped.map((item) => item['id']), containsAll(<String>['activity-1', 'activity-2']));
    });

    test('merges activities with reports so existing activities stay visible', () {
      final merged = mergeDashboardMapSourceItems(
        const [
          {
            'id': 'activity-1',
            'project_id': 'TMQ',
            'title': 'Inspección base',
            'status': 'PENDIENTE',
            'latitude': 20.1,
            'longitude': -100.2,
          },
          {
            'id': 'activity-2',
            'project_id': 'TMQ',
            'title': 'Asamblea sin reporte',
            'status': 'EN_CURSO',
            'latitude': 20.2,
            'longitude': -100.3,
          },
        ],
        const [
          {
            'activity_id': 'activity-1',
            'report_url': 'https://example.com/report.pdf',
            'review_status': 'APPROVED',
          },
        ],
      );

      expect(merged, hasLength(2));
      expect(merged.where((item) => (item['id'] ?? item['activity_id']) == 'activity-2'), isNotEmpty);
      expect((merged.firstWhere((item) => (item['id'] ?? item['activity_id']) == 'activity-1'))['report_url'], isNotEmpty);
    });

    test('extracts coordinates from wizard payload when top-level GPS is absent', () {
      final geoPoint = dashboardGeoPointFromMapItem({
        'id': 'activity-99',
        'project_id': 'TMQ',
        'status': 'PENDIENTE',
        'wizard_payload': {
          'location': {'latitude': 21.1234, 'longitude': -100.9876},
          'activity': {'name': 'Recorrido'},
        },
      });

      expect(geoPoint, isNotNull);
      expect(geoPoint!.lat, closeTo(21.1234, 0.000001));
      expect(geoPoint.lon, closeTo(-100.9876, 0.000001));
      expect(geoPoint.label, 'Recorrido');
    });

    test('deduplicates one activity when activity api uses uuid and report api uses id', () {
      final merged = mergeDashboardMapSourceItems(
        const [
          {
            'uuid': 'uuid-123',
            'project_id': 'TMQ',
            'title': 'Actividad con reporte',
            'execution_state': 'COMPLETADA',
            'latitude': 20.55,
            'longitude': -100.44,
          },
        ],
        const [
          {
            'id': 'uuid-123',
            'project_id': 'TMQ',
            'title': 'Actividad con reporte',
            'status': 'COMPLETADA',
            'review_status': 'APPROVED',
            'report_url': 'https://example.com/reporte.pdf',
            'latitude': 20.55,
            'longitude': -100.44,
          },
        ],
      );

      expect(merged, hasLength(1));
      expect(merged.first['report_url'], isNotEmpty);
    });
  });

  group('Dashboard metrics formulas', () {
    test('counts project activities consistently with and without report', () {
      final metrics = summarizeDashboardActivityMetrics([
        {
          'id': 'activity-1',
          'project_id': 'TMQ',
          'execution_state': 'COMPLETADA',
          'review_status': 'APPROVED',
        },
        {
          'id': 'activity-2',
          'project_id': 'TMQ',
          'execution_state': 'PENDIENTE',
        },
      ]);

      expect(metrics.total, 2);
      expect(metrics.approved, 1);
      expect(metrics.pending, 1);
      expect(metrics.needsFix, 0);
      expect(metrics.rejected, 0);
    });

    test('treats review_decision approve as approved instead of pending', () {
      final metrics = summarizeDashboardActivityMetrics([
        {
          'id': 'activity-approve-token',
          'project_id': 'TMQ',
          'execution_state': 'REVISION_PENDIENTE',
          'review_decision': 'APPROVE',
        },
      ]);

      expect(metrics.approved, 1);
      expect(metrics.pending, 0);
    });

    test('invalid persisted project falls back to all allowed projects', () {
      final resolved = resolveDashboardProjectSelection('ABC', const ['TMQ']);
      expect(resolved, '');
    });

    test('caps progress at 100 percent when counts drift', () {
      const dashData = DashboardData(
        pendingCount: 0,
        approvedCount: 3,
        rejectedCount: 0,
        needsFixCount: 0,
        totalInQueue: 2,
        projectId: 'TMQ',
        range: DashboardRange.today,
        approvedTrend: DashboardTrend(current: 3, previous: 2),
        rejectedTrend: DashboardTrend(current: 0, previous: 0),
        needsFixTrend: DashboardTrend(current: 0, previous: 0),
        pendingTrend: DashboardTrend(current: 0, previous: 1),
        queueItems: [],
        geoPoints: [],
        topErrors: [],
        locationCounts: [],
        riskCounts: {},
        frontProgress: [],
        avgValidationHours: 1.0,
      );

      expect(dashData.avancePct, 1.0);
    });
  });

  group('Dashboard range filters', () {
    test('filters activities for today week month and all using assignment or execution dates', () {
      final now = DateTime.utc(2026, 4, 15, 12);
      final items = [
        {
          'id': 'today-1',
          'executed_at': DateTime.utc(2026, 4, 15, 9).toIso8601String(),
        },
        {
          'id': 'week-1',
          'assignment_start_at': DateTime.utc(2026, 4, 14, 10).toIso8601String(),
        },
        {
          'id': 'month-1',
          'scheduled_for': DateTime.utc(2026, 4, 2, 8).toIso8601String(),
        },
        {
          'id': 'old-1',
          'scheduled_for': DateTime.utc(2026, 3, 20, 8).toIso8601String(),
        },
      ];

      expect(filterDashboardItemsByRange(items, DashboardRange.today, now), hasLength(1));
      expect(filterDashboardItemsByRange(items, DashboardRange.week, now), hasLength(2));
      expect(filterDashboardItemsByRange(items, DashboardRange.month, now), hasLength(3));
      expect(filterDashboardItemsByRange(items, DashboardRange.all, now), hasLength(4));
    });

    test('today does not include older activities updated or reviewed later', () {
      final now = DateTime.utc(2026, 4, 15, 12);
      final items = [
        {
          'id': 'old-reviewed-today',
          'completed_at': DateTime.utc(2026, 4, 12, 9).toIso8601String(),
          'updated_at': DateTime.utc(2026, 4, 15, 10).toIso8601String(),
          'reviewed_at': DateTime.utc(2026, 4, 15, 11).toIso8601String(),
        },
        {
          'id': 'today-real',
          'assignment_start_at': DateTime.utc(2026, 4, 15, 8).toIso8601String(),
        },
      ];

      final filtered = filterDashboardItemsByRange(items, DashboardRange.today, now);

      expect(filtered, hasLength(1));
      expect(filtered.single['id'], 'today-real');
    });

    test('today excludes activities created today but not assigned or executed today', () {
      final now = DateTime.utc(2026, 4, 15, 12);
      final items = [
        {
          'id': 'created-only-today',
          'created_at': DateTime.utc(2026, 4, 15, 7).toIso8601String(),
        },
        {
          'id': 'assigned-today',
          'scheduled_for': DateTime.utc(2026, 4, 15, 10).toIso8601String(),
          'created_at': DateTime.utc(2026, 4, 10, 7).toIso8601String(),
        },
      ];

      final filtered = filterDashboardItemsByRange(items, DashboardRange.today, now);

      expect(filtered, hasLength(1));
      expect(filtered.single['id'], 'assigned-today');
    });

    test('today prioritizes scheduled activity date over report creation date', () {
      final now = DateTime.utc(2026, 4, 15, 12);
      final items = [
        {
          'id': 'future-scheduled-created-today',
          'created_at': DateTime.utc(2026, 4, 15, 8).toIso8601String(),
          'scheduled_for': DateTime.utc(2026, 4, 17, 9).toIso8601String(),
        },
        {
          'id': 'today-scheduled',
          'created_at': DateTime.utc(2026, 4, 14, 18).toIso8601String(),
          'scheduled_for': DateTime.utc(2026, 4, 15, 10).toIso8601String(),
        },
      ];

      final filtered = filterDashboardItemsByRange(items, DashboardRange.today, now);

      expect(filtered, hasLength(1));
      expect(filtered.single['id'], 'today-scheduled');
    });

    test('week uses monday through sunday boundaries', () {
      final now = DateTime.utc(2026, 4, 15, 12); // Wednesday
      final items = [
        {
          'id': 'previous-sunday',
          'scheduled_for': DateTime.utc(2026, 4, 12, 23, 59).toIso8601String(),
        },
        {
          'id': 'monday-start',
          'scheduled_for': DateTime.utc(2026, 4, 13, 0, 0).toIso8601String(),
        },
        {
          'id': 'sunday-end',
          'scheduled_for': DateTime.utc(2026, 4, 19, 23, 59).toIso8601String(),
        },
        {
          'id': 'next-monday',
          'scheduled_for': DateTime.utc(2026, 4, 20, 0, 0).toIso8601String(),
        },
      ];

      final filtered = filterDashboardItemsByRange(items, DashboardRange.week, now);
      final ids = filtered.map((item) => item['id']).toList();

      expect(ids, containsAll(['monday-start', 'sunday-end']));
      expect(ids, isNot(contains('previous-sunday')));
      expect(ids, isNot(contains('next-monday')));
    });

    test('today scope follows scheduled assignments instead of all activity records', () {
      final scoped = scopeDashboardItemsToAssignments(
        [
          {
            'id': 'activity-today',
            'created_at': DateTime.utc(2026, 4, 15, 8).toIso8601String(),
            'title': 'Actividad de hoy',
          },
          {
            'id': 'activity-other-day',
            'created_at': DateTime.utc(2026, 4, 15, 9).toIso8601String(),
            'title': 'Actividad fuera de hoy',
          },
        ],
        [
          {
            'activity_id': 'activity-today',
            'start_at': DateTime.utc(2026, 4, 15, 10).toIso8601String(),
          },
        ],
      );

      expect(scoped, hasLength(1));
      expect(scoped.single['id'], 'activity-today');
      expect(scoped.single['start_at'], DateTime.utc(2026, 4, 15, 10).toIso8601String());
    });
  });

  group('FrontProgressItem', () {
    test('tracks planned vs executed activities', () {
      // GIVEN
      const progress = FrontProgressItem(
        front: 'Frente A',
        planned: 50,
        executed: 35,
      );

      // WHEN
      final executionRate = progress.executed / progress.planned;

      // THEN
      expect(executionRate, equals(0.7)); // 70% execution
      expect(progress.front, 'Frente A');
    });
  });

  group('DashboardRange', () {
    test('enum values exist', () {
      // WHEN / THEN
      expect(DashboardRange.today, isNotNull);
      expect(DashboardRange.week, isNotNull);
      expect(DashboardRange.month, isNotNull);
    });
  });

  group('DashboardKpiFilter', () {
    test('filter enum values exist', () {
      // WHEN / THEN
      expect(DashboardKpiFilter.all, isNotNull);
      expect(DashboardKpiFilter.approved, isNotNull);
      expect(DashboardKpiFilter.rejected, isNotNull);
      expect(DashboardKpiFilter.needsFix, isNotNull);
      expect(DashboardKpiFilter.pending, isNotNull);
    });
  });

  group('Dashboard Integration Tests', () {
    test('dashboard provider falls back to scoped activity data when kpis endpoint is forbidden', () async {
      final now = DateTime.now().toUtc();
      final createdAt = now.subtract(const Duration(hours: 1)).toIso8601String();
      final scheduledFor = now.subtract(const Duration(hours: 2)).toIso8601String();

      final container = ProviderContainer(
        overrides: [
          backendApiClientProvider.overrideWithValue(
            _DashboardFakeBackendApiClient({
              '/api/v1/me/projects': [
                {'project_id': 'TMQ', 'project_name': 'TMQ'},
              ],
              '/api/v1/dashboard/kpis': Exception('403 Forbidden'),
              '/api/v1/review/queue': {
                'items': [],
              },
              '/api/v1/reports/activities': {
                'items': [],
              },
              '/api/v1/activities?project_id=TMQ&page=1&page_size=100': {
                'items': [
                  {
                    'id': 'approved-1',
                    'project_id': 'TMQ',
                    'execution_state': 'COMPLETADA',
                    'review_status': 'APPROVED',
                    'front': 'Frente Norte',
                    'municipality': 'Doctor Mora',
                    'created_at': createdAt,
                    'scheduled_for': scheduledFor,
                  },
                ],
                'has_next': false,
              },
              '/api/v1/assignments?project_id=TMQ': [],
            }),
          ),
          currentAppUserProvider.overrideWithValue(
            const AppUser(
              id: 'oper-1',
              email: 'operativo@sao.mx',
              fullName: 'Operativo TMQ',
              role: 'OPERATIVO',
              roles: ['OPERATIVO'],
              permissionScopes: [
                AppUserPermissionScope(
                  permissionCode: 'activity.view',
                  projectId: 'TMQ',
                  effect: 'allow',
                ),
              ],
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final data = await container.read(dashboardProvider.future);

      expect(data.totalInQueue, 1);
      expect(data.approvedCount, 1);
      expect(data.pendingCount, 0);
    });

    test('dashboard data comprehensively models review queue state', () {
      // GIVEN: Complex multi-front, multi-status scenario
      final List<DashboardGeoPoint> geoPoints = [
        const DashboardGeoPoint(
          id: 'g1',
          projectId: 'TMQ',
          risk: 'critical',
          status: 'COMPLETADA',
          reviewStatus: 'approved',
          front: 'Frente A',
          municipality: 'Toluca',
          state: 'EDOMEX',
          label: 'Km 142',
          lat: 19.28,
          lon: -99.65,
          hasReport: true,
        ),
        const DashboardGeoPoint(
          id: 'g2',
          projectId: 'TMQ',
          risk: 'low',
          status: 'PENDIENTE',
          reviewStatus: 'pending',
          front: 'Frente B',
          municipality: 'Mexico City',
          state: 'CDMX',
          label: 'Km 150',
          lat: 19.43,
          lon: -99.13,
          hasReport: false,
        ),
      ];

      final dashData = DashboardData(
        pendingCount: 5,
        approvedCount: 20,
        rejectedCount: 2,
        needsFixCount: 3,
        totalInQueue: 30,
        projectId: 'TMQ',
        range: DashboardRange.today,
        approvedTrend: const DashboardTrend(current: 20, previous: 15),
        rejectedTrend: const DashboardTrend(current: 2, previous: 4),
        needsFixTrend: const DashboardTrend(current: 3, previous: 1),
        pendingTrend: const DashboardTrend(current: 5, previous: 10),
        queueItems: const [],
        geoPoints: geoPoints,
        topErrors: const [
          TopErrorItem(label: 'Missing GPS', count: 8),
          TopErrorItem(label: 'Wrong Activity Type', count: 5),
        ],
        locationCounts: const [
          LocationCountItem(label: 'Toluca', count: 15),
          LocationCountItem(label: 'Mexico City', count: 15),
        ],
        riskCounts: {
          'critical': 8,
          'high': 12,
          'low': 10,
        },
        frontProgress: const [
          FrontProgressItem(front: 'Frente A', planned: 50, executed: 35),
          FrontProgressItem(front: 'Frente B', planned: 25, executed: 25),
        ],
        avgValidationHours: 4.2,
      );

      // WHEN / THEN
      expect(dashData.avancePct, equals(20 / 30)); // 66.67%
      expect(dashData.geoPoints.length, equals(2));
      expect(dashData.topErrors.length, equals(2));
      expect(dashData.riskCounts['critical'], equals(8));
      expect(dashData.frontProgress.first.executed, equals(35));
      expect(dashData.approvedTrend.delta, equals(5)); // improved
      expect(dashData.pendingTrend.delta, equals(-5)); // improved
    });
  });
}
