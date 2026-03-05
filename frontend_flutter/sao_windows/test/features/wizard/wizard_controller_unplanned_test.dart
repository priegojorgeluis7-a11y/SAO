// test/features/wizard/wizard_controller_unplanned_test.dart
//
// Unit tests for the unplanned-activity mode of the wizard.
// Uses the pure-function helpers extracted into unplanned_validation.dart
// so that no Drift, CatalogRepository, or WidgetTester dependencies are needed.

import 'package:flutter_test/flutter_test.dart';
import 'package:sao_windows/features/activities/wizard/validation/unplanned_validation.dart';

void main() {
  // ──────────────────────────────────────────────────────────
  // validateUnplannedFields
  // ──────────────────────────────────────────────────────────
  group('validateUnplannedFields', () {
    // ── Case 1 ───────────────────────────────────────────────
    test('1. isUnplanned=false => always valid regardless of other fields', () {
      final result = validateUnplannedFields(
        isUnplanned: false,
        unplannedReason: null,
        unplannedReasonOtherText: '',
      );

      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
    });

    // ── Case 2 ───────────────────────────────────────────────
    test('2. isUnplanned=true, reason=null => invalid with unplanned_reason error', () {
      final result = validateUnplannedFields(
        isUnplanned: true,
        unplannedReason: null,
        unplannedReasonOtherText: '',
      );

      expect(result.isValid, isFalse);
      expect(
        result.errors.any((e) => e.fieldKey == 'unplanned_reason'),
        isTrue,
      );
    });

    // ── Case 3 ───────────────────────────────────────────────
    test('3. isUnplanned=true, reason with text => valid', () {
      final result = validateUnplannedFields(
        isUnplanned: true,
        unplannedReason: 'Ajuste por bloqueo de acceso',
        unplannedReasonOtherText: '',
      );

      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
    });

    // ── Case 4 ───────────────────────────────────────────────
    test('4. isUnplanned=true, reason="" => invalid with unplanned_reason error', () {
      final result = validateUnplannedFields(
        isUnplanned: true,
        unplannedReason: '',
        unplannedReasonOtherText: '',
      );

      expect(result.isValid, isFalse);
      expect(
        result.errors.any((e) => e.fieldKey == 'unplanned_reason'),
        isTrue,
      );
    });

    test('4b. isUnplanned=true, reason="   " (only spaces) => invalid', () {
      final result = validateUnplannedFields(
        isUnplanned: true,
        unplannedReason: '   ',
        unplannedReasonOtherText: '   ',
      );

      expect(result.isValid, isFalse);
      expect(
        result.errors.any((e) => e.fieldKey == 'unplanned_reason'),
        isTrue,
      );
    });

    // ── Case 5 ───────────────────────────────────────────────
    test('5. isUnplanned=true, reason="  Falla de acceso  " => valid', () {
      final result = validateUnplannedFields(
        isUnplanned: true,
        unplannedReason: '  Falla de acceso  ',
        unplannedReasonOtherText: '  Falla de acceso  ',
      );

      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
    });
  });

  // ──────────────────────────────────────────────────────────
  // hasUnplannedReference  (reference trim / persistence gate)
  // ──────────────────────────────────────────────────────────
  group('hasUnplannedReference', () {
    // ── Case 6 ───────────────────────────────────────────────
    test('6a. whitespace-only reference => NOT persisted (hasUnplannedReference=false)', () {
      expect(hasUnplannedReference('   '), isFalse);
    });

    test('6b. empty string => NOT persisted', () {
      expect(hasUnplannedReference(''), isFalse);
    });

    test('6c. "OT-2026-042" => persisted (hasUnplannedReference=true)', () {
      expect(hasUnplannedReference('OT-2026-042'), isTrue);
    });

    test('6d. "  OT-2026-042  " (with surrounding spaces) => persisted', () {
      expect(hasUnplannedReference('  OT-2026-042  '), isTrue);
    });
  });

  // ──────────────────────────────────────────────────────────
  // labelForUnplannedReason
  // ──────────────────────────────────────────────────────────
  group('labelForUnplannedReason', () {
    // ── Case 7 ───────────────────────────────────────────────
    test('7a. reason with text => same text', () {
      expect(
        labelForUnplannedReason(
            unplannedReason: 'Ajuste operativo', unplannedReasonOtherText: ''),
        equals('Ajuste operativo'),
      );
    });

    test('7b. reason with surrounding spaces => trimmed text', () {
      expect(
        labelForUnplannedReason(
            unplannedReason: '  Ajuste en sitio  ', unplannedReasonOtherText: ''),
        equals('Ajuste en sitio'),
      );
    });

    test('7c. reason empty + legacy other text => uses legacy value', () {
      expect(
        labelForUnplannedReason(
            unplannedReason: '', unplannedReasonOtherText: '  Fallback legado  '),
        equals('Fallback legado'),
      );
    });

    test('7d. reason null + otherText empty => "—"', () {
      expect(
        labelForUnplannedReason(
            unplannedReason: null, unplannedReasonOtherText: ''),
        equals('—'),
      );
    });

    test('7e. reason only spaces + otherText spaces => "—"', () {
      expect(
        labelForUnplannedReason(
            unplannedReason: '   ', unplannedReasonOtherText: '   '),
        equals('—'),
      );
    });
  });
}
