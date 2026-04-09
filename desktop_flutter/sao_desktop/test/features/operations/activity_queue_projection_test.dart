import 'package:flutter_test/flutter_test.dart';
import 'package:sao_desktop/catalog/risk_catalog.dart';
import 'package:sao_desktop/data/catalog/activity_status.dart';
import 'package:sao_desktop/data/database/app_database.dart';
import 'package:sao_desktop/data/models/activity_model.dart';
import 'package:sao_desktop/features/operations/activity_queue_projection.dart';

ActivityWithDetails _activityWithDetails({
  String status = ActivityStatus.pendingReview,
  String? description,
  String? reviewState,
  String? nextAction,
  ActivityFlags flags = const ActivityFlags(),
  List<Evidence> evidences = const [],
}) {
  return ActivityWithDetails(
    activity: Activity(
      id: 'act-1',
      projectId: 'proj-1',
      activityTypeId: 'type-1',
      assignedTo: 'user-1',
      title: 'Actividad de prueba',
      description: description,
      status: status,
      createdAt: DateTime(2026, 3, 24, 10),
    ),
    evidences: evidences,
    flags: flags,
    reviewState: reviewState,
    nextAction: nextAction,
  );
}

void main() {
  group('deriveActivityQueueStatus', () {
    test('prioritizes canonical rejected review state', () {
      final activity = _activityWithDetails(
        status: ActivityStatus.pendingReview,
        reviewState: 'REJECTED',
      );

      expect(deriveActivityQueueStatus(activity), ActivityStatus.rejected);
    });

    test('maps changes required to needs fix', () {
      final activity = _activityWithDetails(
        status: ActivityStatus.pendingReview,
        reviewState: 'CHANGES_REQUIRED',
      );

      expect(deriveActivityQueueStatus(activity), ActivityStatus.needsFix);
    });

    test('maps pending review canonical state', () {
      final activity = _activityWithDetails(
        status: ActivityStatus.corrected,
        reviewState: 'PENDING_REVIEW',
      );

      expect(deriveActivityQueueStatus(activity), ActivityStatus.pendingReview);
    });

    test('maps approved canonical state', () {
      final activity = _activityWithDetails(
        status: ActivityStatus.pendingReview,
        reviewState: 'APPROVED',
      );

      expect(deriveActivityQueueStatus(activity), ActivityStatus.approved);
    });

    test('exposes a clear rejected label for desktop review', () {
      final activity = _activityWithDetails(
        status: ActivityStatus.pendingReview,
        reviewState: 'REJECTED',
      );

      expect(deriveActivityQueueStatusLabel(activity), 'Rechazada');
    });

    test('exposes correction requested label when resend is required', () {
      final activity = _activityWithDetails(
        status: ActivityStatus.pendingReview,
        reviewState: 'CHANGES_REQUIRED',
        nextAction: 'CORREGIR_Y_REENVIAR',
      );

      expect(
        deriveActivityQueueStatusLabel(activity),
        'Corrección solicitada',
      );
    });

    test('treats changes required as part of rejected queue bucket', () {
      final activity = _activityWithDetails(
        status: ActivityStatus.pendingReview,
        reviewState: 'CHANGES_REQUIRED',
        nextAction: 'CORREGIR_Y_REENVIAR',
      );

      expect(isRejectedQueueBucket(activity), isTrue);
      expect(isChangesQueueBucket(activity), isFalse);
    });

    test('keeps unresolved conflicts in the changes bucket', () {
      final activity = _activityWithDetails(
        status: 'UNKNOWN',
        flags: const ActivityFlags(checklistIncomplete: true),
      );

      expect(isChangesQueueBucket(activity), isTrue);
    });

    test('uses next action fallback for correction flow', () {
      final activity = _activityWithDetails(
        status: ActivityStatus.pendingReview,
        nextAction: 'CORREGIR_Y_REENVIAR',
      );

      expect(deriveActivityQueueStatus(activity), ActivityStatus.needsFix);
    });

    test('returns conflict when canonical fields are missing', () {
      final activity = _activityWithDetails(
        status: 'UNKNOWN',
        description: 'Actividad rechazada por coordinacion',
      );

      expect(deriveActivityQueueStatus(activity), ActivityStatus.conflict);
    });

    test('uses checklist incomplete as conflict fallback', () {
      final activity = _activityWithDetails(
        status: 'UNKNOWN',
        flags: const ActivityFlags(checklistIncomplete: true),
      );

      expect(deriveActivityQueueStatus(activity), ActivityStatus.conflict);
    });
  });

  group('deriveActivityQueueRisk', () {
    test('rejected review state yields priority risk', () {
      final activity = _activityWithDetails(reviewState: 'REJECTED');

      expect(deriveActivityQueueRisk(activity), RiskCatalog.prioritario);
    });

    test('pending review yields high risk', () {
      final activity = _activityWithDetails(reviewState: 'PENDING_REVIEW');

      expect(deriveActivityQueueRisk(activity), RiskCatalog.alto);
    });

    test('approved yields low risk', () {
      final activity = _activityWithDetails(reviewState: 'APPROVED');

      expect(deriveActivityQueueRisk(activity), RiskCatalog.bajo);
    });

    test('needs fix fallback yields priority risk', () {
      final activity = _activityWithDetails(nextAction: 'CORREGIR_Y_REENVIAR');

      expect(deriveActivityQueueRisk(activity), RiskCatalog.prioritario);
    });
  });

  group('deriveActivityBlockingIssues', () {
    test('explains when evidence is still pending synchronization', () {
      final activity = _activityWithDetails(
        flags: const ActivityFlags(checklistIncomplete: true),
        evidences: [
          Evidence(
            id: 'ev-1',
            activityId: 'act-1',
            filePath: 'pending://evidence/ev-1',
            fileType: 'IMAGE',
            caption: 'Foto pendiente',
            capturedAt: DateTime(2026, 4, 6, 12),
          ),
        ],
      );

      expect(
        deriveActivityBlockingIssues(activity),
        contains('Evidencia pendiente de sincronización en servidor'),
      );
    });

    test('explains when GPS validation is the blocker', () {
      final activity = _activityWithDetails(
        flags: const ActivityFlags(
          gpsMismatch: true,
          checklistIncomplete: true,
        ),
        evidences: [
          Evidence(
            id: 'ev-2',
            activityId: 'act-1',
            filePath: 'backend://evidence/ev-2',
            fileType: 'IMAGE',
            caption: 'Foto sin GPS',
            capturedAt: DateTime(2026, 4, 6, 12),
          ),
        ],
      );

      expect(
        deriveActivityBlockingIssues(activity),
        contains('La evidencia no incluye coordenadas GPS válidas'),
      );
    });
  });
}
