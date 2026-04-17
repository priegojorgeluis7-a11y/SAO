class ActivityFlowProjection {
  final String operationalState;
  final String reviewState;
  final String nextAction;

  const ActivityFlowProjection({
    required this.operationalState,
    required this.reviewState,
    required this.nextAction,
  });
}

ActivityFlowProjection deriveLocalActivityFlowProjection({
  required String localStatus,
  DateTime? startedAt,
  DateTime? finishedAt,
  required String syncLifecycle,
}) {
  final normalizedStatus = localStatus.trim().toUpperCase();
  final normalizedSync = syncLifecycle.trim().toUpperCase();

  final operationalState = switch (normalizedStatus) {
    'CANCELED' => 'CANCELADA',
    'RECHAZADA' => 'POR_COMPLETAR',
    'REVISION_PENDIENTE' => 'POR_COMPLETAR',
    _ =>
      finishedAt != null
          ? 'POR_COMPLETAR'
          : startedAt != null
          ? 'EN_CURSO'
          : 'PENDIENTE',
  };

  final reviewState = switch (normalizedStatus) {
    'RECHAZADA' => 'REJECTED',
    'REVISION_PENDIENTE' => 'NOT_APPLICABLE',
    _ =>
      finishedAt != null && normalizedSync == 'SYNCED'
          ? 'PENDING_REVIEW'
          : 'NOT_APPLICABLE',
  };

  if (reviewState == 'REJECTED') {
    return const ActivityFlowProjection(
      operationalState: 'POR_COMPLETAR',
      reviewState: 'REJECTED',
      nextAction: 'CORREGIR_Y_REENVIAR',
    );
  }

  if (normalizedStatus == 'CANCELED') {
    return const ActivityFlowProjection(
      operationalState: 'CANCELADA',
      reviewState: 'NOT_APPLICABLE',
      nextAction: 'CERRADA_CANCELADA',
    );
  }

  if (normalizedSync == 'SYNC_ERROR') {
    return ActivityFlowProjection(
      operationalState: operationalState,
      reviewState: reviewState,
      nextAction: 'REVISAR_ERROR_SYNC',
    );
  }

  if (normalizedStatus == 'REVISION_PENDIENTE') {
    return const ActivityFlowProjection(
      operationalState: 'POR_COMPLETAR',
      reviewState: 'NOT_APPLICABLE',
      nextAction: 'COMPLETAR_WIZARD',
    );
  }

  if (startedAt == null) {
    return ActivityFlowProjection(
      operationalState: operationalState,
      reviewState: reviewState,
      nextAction: 'INICIAR_ACTIVIDAD',
    );
  }

  if (finishedAt == null) {
    return ActivityFlowProjection(
      operationalState: operationalState,
      reviewState: reviewState,
      nextAction: 'TERMINAR_ACTIVIDAD',
    );
  }

  if (normalizedSync == 'READY_TO_SYNC' || normalizedSync == 'LOCAL_ONLY') {
    return ActivityFlowProjection(
      operationalState: operationalState,
      reviewState: reviewState,
      nextAction: 'SINCRONIZAR_PENDIENTE',
    );
  }

  if (reviewState == 'PENDING_REVIEW') {
    return ActivityFlowProjection(
      operationalState: operationalState,
      reviewState: reviewState,
      nextAction: 'ESPERAR_DECISION_COORDINACION',
    );
  }

  return ActivityFlowProjection(
    operationalState: operationalState,
    reviewState: reviewState,
    nextAction: 'SIN_ACCION',
  );
}

String deriveLocalStatusFromCanonicalFlow({
  required String executionState,
  required String operationalState,
  required String reviewState,
  required String syncState,
  required bool isRejectedByReview,
}) {
  final normalizedExecution = executionState.trim().toUpperCase();
  final normalizedOperational = operationalState.trim().toUpperCase();
  final normalizedReview = reviewState.trim().toUpperCase();
  final normalizedSync = syncState.trim().toUpperCase();

  if (normalizedReview == 'REJECTED' ||
      normalizedReview == 'CHANGES_REQUIRED' ||
      isRejectedByReview) {
    return 'RECHAZADA';
  }

  if (normalizedReview == 'PENDING_REVIEW') {
    return 'REVISION_PENDIENTE';
  }

  if (normalizedExecution == 'REVISION_PENDIENTE') {
    return 'REVISION_PENDIENTE';
  }
  if (normalizedExecution == 'CANCELED') {
    return 'CANCELED';
  }

  if (normalizedOperational == 'CANCELADA') {
    return 'CANCELED';
  }

  if (normalizedSync == 'SYNC_ERROR') {
    return 'ERROR';
  }

  return 'SYNCED';
}

bool isRejectedForCorrectionFlow({
  required String localStatus,
  String? reviewState,
  String? nextAction,
}) {
  final normalizedStatus = localStatus.trim().toUpperCase();
  final normalizedReview = reviewState?.trim().toUpperCase() ?? '';
  final normalizedNextAction = nextAction?.trim().toUpperCase() ?? '';

  return normalizedStatus == 'RECHAZADA' ||
      normalizedReview == 'REJECTED' ||
      normalizedReview == 'CHANGES_REQUIRED' ||
      normalizedNextAction == 'CORREGIR_Y_REENVIAR' ||
      normalizedNextAction == 'CERRADA_RECHAZADA';
}

bool hasAuthoritativeCanonicalReviewFlow({
  String? reviewState,
  String? nextAction,
}) {
  final normalizedReview = reviewState?.trim().toUpperCase() ?? '';
  final normalizedNextAction = nextAction?.trim().toUpperCase() ?? '';

  return const {
        'PENDING_REVIEW',
        'CHANGES_REQUIRED',
        'APPROVED',
        'REJECTED',
      }.contains(normalizedReview) ||
      const {
        'CORREGIR_Y_REENVIAR',
        'ESPERAR_DECISION_COORDINACION',
        'CERRADA_RECHAZADA',
        'CERRADA_APROBADA',
      }.contains(normalizedNextAction);
}

String syncLifecycleFromLocalStatus(String localStatus) {
  final normalized = localStatus.trim().toUpperCase();
  return switch (normalized) {
    'READY_TO_SYNC' => 'READY_TO_SYNC',
    'DRAFT' => 'LOCAL_ONLY',
    'ERROR' => 'SYNC_ERROR',
    _ => 'SYNCED',
  };
}

String nextActionLabel(String nextAction) {
  switch (nextAction.trim().toUpperCase()) {
    case 'CORREGIR_Y_REENVIAR':
    case 'CERRADA_RECHAZADA':
      return 'Corregir y reenviar';
    case 'REVISAR_ERROR_SYNC':
      return 'Revisar error de sync';
    case 'SINCRONIZAR_PENDIENTE':
      return 'Sincronizar pendiente';
    case 'COMPLETAR_WIZARD':
      return 'Completar captura';
    case 'INICIAR_ACTIVIDAD':
      return 'Iniciar actividad';
    case 'TERMINAR_ACTIVIDAD':
      return 'Terminar actividad';
    case 'ESPERAR_DECISION_COORDINACION':
      return 'Esperando revision';
    case 'CERRADA_CANCELADA':
      return 'Cancelada';
    case 'CERRADA_APROBADA':
      return 'Terminada';
    default:
      return 'Sin accion';
  }
}
