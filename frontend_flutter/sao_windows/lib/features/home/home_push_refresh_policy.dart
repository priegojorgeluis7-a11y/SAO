bool shouldRefreshHomeFromPushType(String? rawType) {
  final type = (rawType ?? '').trim().toLowerCase();
  return const {
    'review_changes_required',
    'review_approved',
    'review_decision',
    'activity_update',
    'assignment_update',
    'new_assignment',
    'assignment_transferred',
    'catalog_update',
    'assignment_cancelled',
  }.contains(type);
}

/// Returns true if the push type should trigger a local sync push
/// (upload pending evidence/activity data to the server).
bool shouldTriggerSyncPushFromPushType(String? rawType) {
  return (rawType ?? '').trim().toLowerCase() == 'sync_required';
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
    case 'new_assignment':
      return 'Tu agenda cambio. Actualizando actividades...';
    case 'assignment_transferred':
      return 'Una actividad fue transferida a ti. Actualizando agenda...';
    case 'catalog_update':
      return 'Nuevo catalogo disponible. Actualizando...';
    case 'assignment_cancelled':
      return 'Una actividad fue cancelada. Actualizando agenda...';
    case 'sync_required':
      return 'Solicitud de sincronizacion recibida. Enviando datos al servidor...';
    default:
      return 'Actualizando estado remoto de actividades...';
  }
}
