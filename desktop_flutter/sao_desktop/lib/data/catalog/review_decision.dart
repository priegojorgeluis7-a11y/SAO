/// Catálogo centralizado de decisiones de revisión de actividades
/// Proporciona constantes y métodos de utilidad para decisiones del coordinador
class ReviewDecision {
  ReviewDecision._(); // Private constructor para prevenir instanciación

  // Decisiones de revisión (constantes canónicas)
  /// Aprobación estándar de la actividad
  static const String approve = 'APPROVE';
  
  /// Aprobación con excepción (requiere comentario y rol ADMIN)
  static const String approveException = 'APPROVE_EXCEPTION';
  
  /// Rechazo de la actividad (regresa al operativo para corrección)
  static const String reject = 'REJECT';
  
  /// Cambios requeridos (sin comentario obligatorio)
  static const String changesRequired = 'CHANGES_REQUIRED';

  // Estados derivados (para display)
  /// Actividad aprobada - aparece en reportes
  static const String approved = 'APPROVED';
  
  /// Actividad rechazada - aparece en cola de corrección
  static const String rejected = 'REJECTED';

  /// Obtiene el label de decisión en español
  static String getDisplayLabel(String decision) {
    switch (decision.toUpperCase()) {
      case 'APPROVE':
        return 'Aprobada';
      
      case 'APPROVE_EXCEPTION':
        return 'Aprobada con excepción';
      
      case 'REJECT':
        return 'Rechazada';
      
      case 'CHANGES_REQUIRED':
        return 'Cambios requeridos';
      
      case 'APPROVED':
        return 'Aprobada';
      
      case 'REJECTED':
        return 'Rechazada';
      
      default:
        return decision;
    }
  }

  /// Obtiene el color asociado a la decisión
  static int getColorValue(String decision) {
    switch (decision.toUpperCase()) {
      case 'APPROVE':
      case 'APPROVE_EXCEPTION':
      case 'APPROVED':
        return 0xFF10B981; // Verde
      
      case 'REJECT':
      case 'REJECTED':
        return 0xFFEF4444; // Rojo
      
      case 'CHANGES_REQUIRED':
        return 0xFFF59E0B; // Amarillo/Naranja
      
      default:
        return 0xFF6B7280; // Gris
    }
  }

  /// Normaliza una decisión a su forma canónica
  static String normalize(String decision) {
    final upper = decision.toUpperCase().trim();
    
    // Decisiones canónicas
    if (upper == 'APPROVE') return approve;
    if (upper == 'APPROVE_EXCEPTION') return approveException;
    if (upper == 'REJECT') return reject;
    if (upper == 'CHANGES_REQUIRED') return changesRequired;
    
    // Estados derivados (se mapean a decisiones)
    if (upper == 'APPROVED') return approved;
    if (upper == 'REJECTED') return rejected;
    
    // Alias en español
    if (upper == 'APROBADO') return approve;
    if (upper == 'RECHAZADO') return reject;
    if (upper == 'CAMBios_REQUERIDOS' || upper == 'REQUIERE_CAMBIOS') return changesRequired;
    
    return decision;
  }

  /// Verifica si una decisión es de aprobación
  static bool isApproved(String decision) {
    final normalized = normalize(decision);
    return normalized == approve || 
           normalized == approveException || 
           normalized == approved;
  }

  /// Verifica si una decisión es de rechazo
  static bool isRejected(String decision) {
    final normalized = normalize(decision);
    return normalized == reject || 
           normalized == rejected;
  }

  /// Verifica si una decisión requiere corrección
  static bool requiresChanges(String decision) {
    final normalized = normalize(decision);
    return normalized == reject || 
           normalized == changesRequired ||
           normalized == rejected;
  }

  /// Lista de todas las decisiones válidas
  static const List<String> validDecisions = [
    approve,
    approveException,
    reject,
    changesRequired,
  ];

  /// Verifica si una decisión es válida
  static bool isValid(String decision) {
    return validDecisions.contains(normalize(decision));
  }
}
