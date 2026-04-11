/// Catálogo centralizado de estados de actividades
/// Proporciona constantes de estado y métodos de utilidad para labels y colores
class ActivityStatus {
  ActivityStatus._(); // Private constructor para prevenir instanciación

  // Estados de actividad (constantes)
  static const String pendingReview = 'PENDING_REVIEW';
  static const String approved = 'APPROVED';
  static const String rejected = 'REJECTED';
  static const String needsFix = 'NEEDS_FIX';
  static const String corrected = 'CORRECTED';
  static const String conflict = 'CONFLICT';

  // Estados alternativos en español (para compatibilidad con datos legacy)
  static const String pendiente = 'pendiente';
  static const String aprobado = 'aprobado';
  static const String rechazado = 'rechazado';

  /// Obtiene el label de estado en español
  static String getDisplayLabel(String status) {
    switch (status) {
      case pendingReview:
      case 'PENDIENTE':
      case pendiente:
        return 'Pendiente de revisión';
      
      case approved:
      case aprobado:
        return 'Aprobada';
      
      case rejected:
      case rechazado:
        return 'Rechazada';
      
      case needsFix:
        return 'Necesita corrección';

      case corrected:
      case 'CORREGIDA':
        return 'Corregida';

      case conflict:
        return 'Pendiente de revisión';
      
      default:
        return status; // Fallback: devolver el estado original
    }
  }

  /// Normaliza un estado a su forma canónica (uppercase con underscores)
  static String normalize(String status) {
    switch (status.toLowerCase()) {
      case 'pending_review':
      case 'pendiente':
        return pendingReview;
      
      case 'approved':
      case 'aprobado':
        return approved;
      
      case 'rejected':
      case 'rechazado':
        return rejected;
      
      case 'needs_fix':
        return needsFix;

      case 'corrected':
      case 'corregida':
        return corrected;

      case 'conflict':
        return conflict;
      
      default:
        return status;
    }
  }

  /// Lista de todos los estados válidos
  static const List<String> validStatuses = [
    pendingReview,
    approved,
    rejected,
    needsFix,
    corrected,
    conflict,
  ];

  /// Verifica si un estado es válido
  static bool isValid(String status) {
    return validStatuses.contains(normalize(status));
  }
}
