import 'package:flutter_test/flutter_test.dart';
import 'package:sao_windows/core/flow/activity_flow_projection.dart';

void main() {
  group('deriveLocalActivityFlowProjection', () {
    test('keeps started local draft as terminar actividad', () {
      final projection = deriveLocalActivityFlowProjection(
        localStatus: 'DRAFT',
        startedAt: DateTime(2026, 3, 30, 8),
        finishedAt: null,
        syncLifecycle: 'LOCAL_ONLY',
      );

      expect(projection.operationalState, 'EN_CURSO');
      expect(projection.reviewState, 'NOT_APPLICABLE');
      expect(projection.nextAction, 'TERMINAR_ACTIVIDAD');
    });

    test('keeps revision pendiente as completar wizard before sync action', () {
      final projection = deriveLocalActivityFlowProjection(
        localStatus: 'REVISION_PENDIENTE',
        startedAt: DateTime(2026, 3, 30, 8),
        finishedAt: DateTime(2026, 3, 30, 9),
        syncLifecycle: 'READY_TO_SYNC',
      );

      expect(projection.operationalState, 'POR_COMPLETAR');
      expect(projection.reviewState, 'NOT_APPLICABLE');
      expect(projection.nextAction, 'COMPLETAR_WIZARD');
    });

    test('uses sincronizar pendiente only after completed local flow', () {
      final projection = deriveLocalActivityFlowProjection(
        localStatus: 'READY_TO_SYNC',
        startedAt: DateTime(2026, 3, 30, 8),
        finishedAt: DateTime(2026, 3, 30, 9),
        syncLifecycle: 'READY_TO_SYNC',
      );

      expect(projection.operationalState, 'POR_COMPLETAR');
      expect(projection.nextAction, 'SINCRONIZAR_PENDIENTE');
    });
  });

  group('deriveLocalStatusFromCanonicalFlow', () {
    test(
      'maps changes required to rejected local status for correction flow',
      () {
        final localStatus = deriveLocalStatusFromCanonicalFlow(
          executionState: 'REVISION_PENDIENTE',
          operationalState: 'POR_COMPLETAR',
          reviewState: 'CHANGES_REQUIRED',
          syncState: 'SYNCED',
          isRejectedByReview: false,
        );

        expect(localStatus, 'RECHAZADA');
      },
    );

    test('treats legacy review rejections as rejected local status too', () {
      final localStatus = deriveLocalStatusFromCanonicalFlow(
        executionState: 'REVISION_PENDIENTE',
        operationalState: 'POR_COMPLETAR',
        reviewState: 'NOT_APPLICABLE',
        syncState: 'SYNCED',
        isRejectedByReview: true,
      );

      expect(localStatus, 'RECHAZADA');
    });
  });

  group('canonical review helpers', () {
    test('detects correction-required flow from canonical review fields', () {
      expect(
        isRejectedForCorrectionFlow(
          localStatus: 'SYNCED',
          reviewState: 'CHANGES_REQUIRED',
          nextAction: 'CORREGIR_Y_REENVIAR',
        ),
        isTrue,
      );
    });

    test(
      'treats legacy closed-rejected actions as correction-required too',
      () {
        expect(
          isRejectedForCorrectionFlow(
            localStatus: 'SYNCED',
            reviewState: 'NOT_APPLICABLE',
            nextAction: 'CERRADA_RECHAZADA',
          ),
          isTrue,
        );
        expect(nextActionLabel('CERRADA_RECHAZADA'), 'Corregir y reenviar');
      },
    );

    test('shows approved closed actions as terminated', () {
      expect(nextActionLabel('CERRADA_APROBADA'), 'Terminada');
    });

    test('prefers canonical review outcomes when backend already decided', () {
      expect(
        hasAuthoritativeCanonicalReviewFlow(
          reviewState: 'CHANGES_REQUIRED',
          nextAction: 'CORREGIR_Y_REENVIAR',
        ),
        isTrue,
      );
      expect(
        hasAuthoritativeCanonicalReviewFlow(
          reviewState: 'NOT_APPLICABLE',
          nextAction: 'SIN_ACCION',
        ),
        isFalse,
      );
    });
  });
}
