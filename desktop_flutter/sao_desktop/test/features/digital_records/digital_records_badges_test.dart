import 'package:flutter_test/flutter_test.dart';
import 'package:sao_desktop/features/completed_activities/completed_activities_provider.dart';
import 'package:sao_desktop/features/digital_records/digital_records_page.dart';

void main() {
  group('resolveDigitalRecordFollowUpSummary', () {
    test('returns unique related count and latest follow-up status', () {
      final summary = resolveDigitalRecordFollowUpSummary(
        relatedActivityIds: const ['A1', 'A2', 'A1'],
        relatedLinks: const [
          ManualRelatedLink(
            activityId: 'A1',
            status: 'abierta',
            createdAt: '2026-04-01T10:00:00Z',
          ),
          ManualRelatedLink(
            activityId: 'A2',
            status: 'resuelta',
            createdAt: '2026-04-03T10:00:00Z',
          ),
        ],
      );

      expect(summary.hasRelatedActivities, isTrue);
      expect(summary.relatedCount, 2);
      expect(summary.latestStatus, 'resuelta');
    });

    test('falls back to no follow-up when there are no related activities', () {
      final summary = resolveDigitalRecordFollowUpSummary(
        relatedActivityIds: const [],
        relatedLinks: const [],
      );

      expect(summary.hasRelatedActivities, isFalse);
      expect(summary.relatedCount, 0);
      expect(summary.latestStatus, 'sin_seguimiento');
    });
  });

  group('resolveDigitalRecordUserOptions', () {
    test('returns Todo first and deduplicated user names', () {
      final options = resolveDigitalRecordUserOptions(
        backendUsers: const ['María Pérez', 'juan lopez'],
        items: const [
          CompletedActivity(
            id: '1',
            projectId: 'TAP',
            title: 'Actividad 1',
            activityType: 'Visita',
            pk: 'PK1',
            front: 'Frente 1',
            estado: 'Jalisco',
            municipio: 'Zapopan',
            hasReport: false,
            documentCount: 0,
            reviewedAt: '',
            createdAt: '2026-04-01T10:00:00Z',
            evidenceCount: 0,
            assignedName: 'Juan Lopez',
            reviewedByName: '',
            reviewDecision: '',
          ),
          CompletedActivity(
            id: '2',
            projectId: 'TAP',
            title: 'Actividad 2',
            activityType: 'Visita',
            pk: 'PK2',
            front: 'Frente 1',
            estado: 'Jalisco',
            municipio: 'Zapopan',
            hasReport: false,
            documentCount: 0,
            reviewedAt: '',
            createdAt: '2026-04-02T10:00:00Z',
            evidenceCount: 0,
            assignedName: ' María Pérez ',
            reviewedByName: '',
            reviewDecision: '',
          ),
        ],
      );

      expect(options.first, 'Todo');
      expect(options, contains('Juan Lopez'));
      expect(options, contains('María Pérez'));
      expect(options.where((value) => value == 'Juan Lopez').length, 1);
    });
  });
}
