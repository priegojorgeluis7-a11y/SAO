import 'package:flutter_test/flutter_test.dart';
import 'package:sao_desktop/data/catalog/activity_status.dart';

void main() {
  group('ActivityStatus.getDisplayLabel', () {
    test('returns spanish label for PENDING_REVIEW', () {
      expect(
        ActivityStatus.getDisplayLabel(ActivityStatus.pendingReview),
        'Pendiente de revisión',
      );
    });

    test('returns spanish label for APPROVED', () {
      expect(
        ActivityStatus.getDisplayLabel(ActivityStatus.approved),
        'Aprobada',
      );
    });

    test('returns spanish label for REJECTED', () {
      expect(
        ActivityStatus.getDisplayLabel(ActivityStatus.rejected),
        'Rechazada',
      );
    });

    test('returns spanish label for NEEDS_FIX', () {
      expect(
        ActivityStatus.getDisplayLabel(ActivityStatus.needsFix),
        'Necesita corrección',
      );
    });

    test('returns spanish label for CORRECTED', () {
      expect(
        ActivityStatus.getDisplayLabel(ActivityStatus.corrected),
        'Corregida',
      );
    });

    test('returns original string for unknown status (fallback)', () {
      expect(
        ActivityStatus.getDisplayLabel('UNKNOWN_STATUS'),
        'UNKNOWN_STATUS',
      );
    });

    test('handles legacy spanish states', () {
      expect(ActivityStatus.getDisplayLabel('aprobado'), 'Aprobada');
      expect(ActivityStatus.getDisplayLabel('rechazado'), 'Rechazada');
    });
  });

  group('ActivityStatus.normalize', () {
    test('normalizes lowercase pending_review', () {
      expect(ActivityStatus.normalize('pending_review'), ActivityStatus.pendingReview);
    });

    test('normalizes spanish pendiente', () {
      expect(ActivityStatus.normalize('pendiente'), ActivityStatus.pendingReview);
    });

    test('normalizes approved variants', () {
      expect(ActivityStatus.normalize('approved'), ActivityStatus.approved);
      expect(ActivityStatus.normalize('aprobado'), ActivityStatus.approved);
    });

    test('normalizes rejected variants', () {
      expect(ActivityStatus.normalize('rejected'), ActivityStatus.rejected);
      expect(ActivityStatus.normalize('rechazado'), ActivityStatus.rejected);
    });

    test('normalizes needs_fix', () {
      expect(ActivityStatus.normalize('needs_fix'), ActivityStatus.needsFix);
    });

    test('normalizes corrected variants', () {
      expect(ActivityStatus.normalize('corrected'), ActivityStatus.corrected);
      expect(ActivityStatus.normalize('corregida'), ActivityStatus.corrected);
    });

    test('returns original for unknown', () {
      expect(ActivityStatus.normalize('SOME_STATUS'), 'SOME_STATUS');
    });
  });

  group('ActivityStatus.isValid', () {
    test('valid statuses return true', () {
      for (final status in ActivityStatus.validStatuses) {
        expect(ActivityStatus.isValid(status), isTrue,
            reason: '$status should be valid');
      }
    });

    test('unknown status returns false', () {
      expect(ActivityStatus.isValid('MADE_UP_STATUS'), isFalse);
    });

    test('empty string returns false', () {
      expect(ActivityStatus.isValid(''), isFalse);
    });
  });

  group('ActivityStatus constants', () {
    test('validStatuses contains expected entries', () {
      expect(ActivityStatus.validStatuses, contains(ActivityStatus.pendingReview));
      expect(ActivityStatus.validStatuses, contains(ActivityStatus.approved));
      expect(ActivityStatus.validStatuses, contains(ActivityStatus.rejected));
      expect(ActivityStatus.validStatuses, contains(ActivityStatus.needsFix));
      expect(ActivityStatus.validStatuses, contains(ActivityStatus.corrected));
      expect(ActivityStatus.validStatuses, contains(ActivityStatus.conflict));
    });
  });
}
