/// Elemento de acuerdo/compromiso
class AgreementItem {
  final String id;
  final String action; // descripción del acuerdo
  final String responsible; // responsable del compromiso
  final DateTime commitmentDate; // fecha de compromiso
  final String status; // pending, completed, overdue
  final String? notes;

  AgreementItem({
    required this.id,
    required this.action,
    required this.responsible,
    required this.commitmentDate,
    required this.status,
    this.notes,
  });

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'Pendiente';
      case 'completed':
        return 'Completado';
      case 'overdue':
        return 'Vencido';
      default:
        return status;
    }
  }
}
