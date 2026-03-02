/// Evento de auditoría - Trazabilidad de cambios
class AuditEvent {
  final String id;
  final String eventType; // created, edited, validated, approved, rejected, exported
  final String? description;
  final String userId; // usuario que realizó la acción
  final String? userName;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata; // datos adicionales del evento

  AuditEvent({
    required this.id,
    required this.eventType,
    this.description,
    required this.userId,
    this.userName,
    required this.timestamp,
    this.metadata,
  });

  String get displayLabel {
    switch (eventType) {
      case 'created':
        return 'Creado';
      case 'edited':
        return 'Editado';
      case 'validated':
        return 'Validado';
      case 'approved':
        return 'Aprobado';
      case 'rejected':
        return 'Rechazado';
      case 'exported':
        return 'Exportado';
      default:
        return eventType;
    }
  }
}
