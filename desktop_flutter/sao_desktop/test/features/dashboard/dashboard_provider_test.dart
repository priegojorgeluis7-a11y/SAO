// desktop_flutter/sao_desktop/test/features/dashboard/dashboard_provider_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sao_desktop/features/dashboard/dashboard_provider.dart';

void main() {
  group('DashboardData - KPI Calculations', () {
    test('avancePct returns percentage of approved', () {
      // GIVEN
      final dashData = DashboardData(
        pendingCount: 3,
        approvedCount: 7,
        rejectedCount: 0,
        needsFixCount: 0,
        totalInQueue: 10,
        projectId: 'TMQ',
        range: DashboardRange.today,
        approvedTrend: const DashboardTrend(current: 7, previous: 5),
        rejectedTrend: const DashboardTrend(current: 0, previous: 0),
        needsFixTrend: const DashboardTrend(current: 0, previous: 0),
        pendingTrend: const DashboardTrend(current: 3, previous: 5),
        queueItems: const [],
        geoPoints: const [],
        topErrors: const [],
        locationCounts: const [],
        riskCounts: const {},
        frontProgress: const [],
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
      final dashData = DashboardData(
        pendingCount: 0,
        approvedCount: 0,
        rejectedCount: 0,
        needsFixCount: 0,
        totalInQueue: 0,
        projectId: 'TMQ',
        range: DashboardRange.today,
        approvedTrend: const DashboardTrend(current: 0, previous: 0),
        rejectedTrend: const DashboardTrend(current: 0, previous: 0),
        needsFixTrend: const DashboardTrend(current: 0, previous: 0),
        pendingTrend: const DashboardTrend(current: 0, previous: 0),
        queueItems: const [],
        geoPoints: const [],
        topErrors: const [],
        locationCounts: const [],
        riskCounts: const {},
        frontProgress: const [],
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
      );

      // WHEN / THEN
      expect(geoPoint.id, 'geo-1');
      expect(geoPoint.risk, 'critical');
      expect(geoPoint.lat, lessThan(90));
      expect(geoPoint.lon, lessThan(180));
      expect(geoPoint.municipality, 'Toluca');
    });

    test('handles null optional fields', () {
      // GIVEN
      const geoPoint = DashboardGeoPoint(
        id: 'geo-2',
        risk: 'low',
        status: 'PENDIENTE',
        reviewStatus: 'pending',
        front: 'Frente B',
        municipality: 'Mexico City',
        state: 'Mexico City',
        label: 'Km 150',
        lat: 19.4326,
        lon: -99.1332,
      );

      // WHEN / THEN
      expect(geoPoint.reviewDecision, isNull);
      expect(geoPoint.assignedToUserId, isNull);
      expect(geoPoint.assignedName, isNull);
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
    test('dashboard data comprehensively models review queue state', () {
      // GIVEN: Complex multi-front, multi-status scenario
      final geoPoints = [
        const DashboardGeoPoint(
          id: 'g1',
          risk: 'critical',
          status: 'COMPLETADA',
          reviewStatus: 'approved',
          front: 'Frente A',
          municipality: 'Toluca',
          state: 'EDOMEX',
          label: 'Km 142',
          lat: 19.28,
          lon: -99.65,
        ),
        const DashboardGeoPoint(
          id: 'g2',
          risk: 'low',
          status: 'PENDIENTE',
          reviewStatus: 'pending',
          front: 'Frente B',
          municipality: 'Mexico City',
          state: 'CDMX',
          label: 'Km 150',
          lat: 19.43,
          lon: -99.13,
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
