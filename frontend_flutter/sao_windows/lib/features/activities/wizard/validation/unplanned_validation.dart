// lib/features/activities/wizard/validation/unplanned_validation.dart
//
// Pure-function helpers extracted from WizardController so that unit tests
// can exercise the unplanned-mode logic without instantiating the full
// controller (which requires Drift, CatalogRepository, etc.).

import '../wizard_validation.dart';

/// Validates the unplanned-activity specific fields.
///
/// Returns [ValidationResult.valid()] immediately when [isUnplanned] is false
/// so that calling code never needs to gate on the flag itself.
ValidationResult validateUnplannedFields({
  required bool isUnplanned,
  required String? unplannedReason,
  required String unplannedReasonOtherText,
}) {
  if (!isUnplanned) return ValidationResult.valid();

  final errors = <ValidationError>[];

  if (unplannedReason == null || unplannedReason.trim().isEmpty) {
    errors.add(ValidationError(
      fieldKey: 'unplanned_reason',
      message: 'Describe el motivo de la actividad no planeada',
      step: 'context',
    ));
  }

  return errors.isEmpty
      ? ValidationResult.valid()
      : ValidationResult.invalid(errors);
}

/// Returns a human-readable label for the given [unplannedReason] value.
///
/// In catalog-safe mode this is currently plain free text entered by user.
String labelForUnplannedReason({
  required String? unplannedReason,
  required String unplannedReasonOtherText,
}) {
  final trimmed = unplannedReason?.trim() ?? '';
  if (trimmed.isNotEmpty) return trimmed;
  final legacyOther = unplannedReasonOtherText.trim();
  return legacyOther.isNotEmpty ? legacyOther : '—';
}

/// Returns true when [unplannedReference] has meaningful content after
/// trimming.  Mirrors the save-time condition used in [WizardController].
bool hasUnplannedReference(String unplannedReference) =>
    unplannedReference.trim().isNotEmpty;
