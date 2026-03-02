// lib/features/activities/wizard/wizard_validation.dart

/// Representa un error de validación con el campo que falló
class ValidationError {
  final String fieldKey;
  final String message;
  final String step; // 'context', 'fields', 'evidence'

  ValidationError({
    required this.fieldKey,
    required this.message,
    required this.step,
  });
}

/// Resultado de validación con lista de errores
class ValidationResult {
  final bool isValid;
  final List<ValidationError> errors;

  ValidationResult({
    required this.isValid,
    required this.errors,
  });

  factory ValidationResult.valid() => ValidationResult(isValid: true, errors: []);
  
  factory ValidationResult.invalid(List<ValidationError> errors) {
    return ValidationResult(isValid: false, errors: errors);
  }

  /// Obtiene el primer error (para scroll)
  ValidationError? get firstError => errors.isEmpty ? null : errors.first;
}

/// Resultado del Gatekeeper - Validación Final antes de Guardar
class GatekeeperResult {
  final bool isValid;
  final String? errorMessage;
  final String? errorFieldKey;
  final int? step; // Paso del wizard (0-indexed)
  final int? evidenceIndex; // Índice de evidencia sin descripción (si aplica)

  GatekeeperResult({
    required this.isValid,
    this.errorMessage,
    this.errorFieldKey,
    this.step,
    this.evidenceIndex,
  });

  factory GatekeeperResult.valid() => GatekeeperResult(isValid: true);
}
