bool shouldRefreshHomeFromPushType(String? rawType) {
  final type = (rawType ?? '').trim().toLowerCase();
  return const {
    'review_changes_required',
    'review_approved',
    'review_decision',
    'activity_update',
    'assignment_update',
  }.contains(type);
}

String homeRefreshMessageForPushType(String? rawType) {
  final type = (rawType ?? '').trim().toLowerCase();
  switch (type) {
    case 'review_changes_required':
      return 'Actividad rechazada. Actualizando solicitud de correccion...';
    case 'review_approved':
      return 'Actividad aprobada. Actualizando estado en el celular...';
    case 'review_decision':
      return 'Se detecto una decision de revision. Actualizando datos...';
    case 'activity_update':
      return 'Se detectaron cambios remotos en tus actividades. Actualizando...';
    case 'assignment_update':
      return 'Tu agenda cambio. Actualizando actividades...';
    default:
      return 'Actualizando estado remoto de actividades...';
  }
}
