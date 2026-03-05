import 'package:flutter_test/flutter_test.dart';
import 'package:sao_desktop/data/models/activity_model.dart';

void main() {
  group('ActivityFlags', () {
    test('defaults all flags to false', () {
      const flags = ActivityFlags();
      expect(flags.gpsMismatch, isFalse);
      expect(flags.catalogChanged, isFalse);
      expect(flags.checklistIncomplete, isFalse);
    });

    test('accepts explicit true values', () {
      const flags = ActivityFlags(
        gpsMismatch: true,
        catalogChanged: true,
        checklistIncomplete: true,
      );
      expect(flags.gpsMismatch, isTrue);
      expect(flags.catalogChanged, isTrue);
      expect(flags.checklistIncomplete, isTrue);
    });

    test('partial flags leave others as default', () {
      const flags = ActivityFlags(gpsMismatch: true);
      expect(flags.gpsMismatch, isTrue);
      expect(flags.catalogChanged, isFalse);
      expect(flags.checklistIncomplete, isFalse);
    });

    test('two const instances with same values are equal via identity', () {
      const a = ActivityFlags();
      const b = ActivityFlags();
      // Dart const instances are identical
      expect(identical(a, b), isTrue);
    });
  });

  group('ActivityTimelineEntry', () {
    test('constructs with required fields', () {
      final entry = ActivityTimelineEntry(
        at: DateTime(2026, 3, 4),
        actor: null,
        action: 'APPROVED',
        details: null,
      );
      expect(entry.action, 'APPROVED');
      expect(entry.actor, isNull);
      expect(entry.details, isNull);
    });

    test('constructs with all fields', () {
      final entry = ActivityTimelineEntry(
        at: DateTime(2026, 3, 4, 12, 0),
        actor: 'coord@sao.dev',
        action: 'REJECTED',
        details: {'reason': 'PHOTO_BLUR'},
      );
      expect(entry.actor, 'coord@sao.dev');
      expect(entry.action, 'REJECTED');
      expect(entry.details!['reason'], 'PHOTO_BLUR');
    });
  });
}
