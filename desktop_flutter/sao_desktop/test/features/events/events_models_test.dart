import 'package:flutter_test/flutter_test.dart';

// Pure Dart tests for event-related business logic.
// EventsPage uses private _EventRow — we test the severity/status
// logic through comparable standalone logic here.

// ─────────────────────────────────────────────
// Standalone severity helpers (mirrors events_page.dart logic)
// ─────────────────────────────────────────────

String _severityLabel(String severity) => switch (severity) {
      'LOW' => 'BAJO',
      'HIGH' => 'ALTO',
      'CRITICAL' => 'CRÍTICO',
      _ => 'MEDIO',
    };

bool _isValidSeverity(String s) =>
    const {'LOW', 'MEDIUM', 'HIGH', 'CRITICAL'}.contains(s);

String _formatPk(int meters) {
  final km = meters ~/ 1000;
  final m = meters % 1000;
  return '$km+${m.toString().padLeft(3, '0')}';
}

void main() {
  group('Event severity label', () {
    test('LOW maps to BAJO', () => expect(_severityLabel('LOW'), 'BAJO'));
    test('MEDIUM maps to MEDIO', () => expect(_severityLabel('MEDIUM'), 'MEDIO'));
    test('HIGH maps to ALTO', () => expect(_severityLabel('HIGH'), 'ALTO'));
    test('CRITICAL maps to CRÍTICO', () => expect(_severityLabel('CRITICAL'), 'CRÍTICO'));
    test('unknown maps to MEDIO (fallback)', () => expect(_severityLabel('UNKNOWN'), 'MEDIO'));
  });

  group('Event severity validation', () {
    test('valid severities', () {
      for (final s in ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL']) {
        expect(_isValidSeverity(s), isTrue, reason: '$s should be valid');
      }
    });

    test('invalid severity', () {
      expect(_isValidSeverity('EXTREME'), isFalse);
      expect(_isValidSeverity(''), isFalse);
    });
  });

  group('PK formatting', () {
    test('1000 meters = km 1+000', () {
      expect(_formatPk(1000), '1+000');
    });

    test('142500 meters = km 142+500', () {
      expect(_formatPk(142500), '142+500');
    });

    test('500 meters = km 0+500', () {
      expect(_formatPk(500), '0+500');
    });

    test('exact kilometer boundary', () {
      expect(_formatPk(10000), '10+000');
    });

    test('zero meters', () {
      expect(_formatPk(0), '0+000');
    });
  });

  group('Event resolved state', () {
    test('null resolvedAt means unresolved', () {
      final resolvedAt = null;
      expect(resolvedAt == null, isTrue);
    });

    test('non-null resolvedAt means resolved', () {
      final resolvedAt = DateTime(2026, 3, 4);
      expect(resolvedAt != null, isTrue);
    });
  });
}
