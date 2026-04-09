import '../../catalog/risk_catalog.dart';
import '../../data/catalog/activity_status.dart';
import '../../data/models/activity_model.dart';

String deriveActivityQueueStatus(ActivityWithDetails activity) {
  final reviewState = (activity.reviewState ?? '').trim().toUpperCase();
  final nextAction = (activity.nextAction ?? '').trim().toUpperCase();
  if (reviewState == 'REJECTED') {
    return ActivityStatus.rejected;
  }
  if (reviewState == 'RECHAZADO') {
    return ActivityStatus.rejected;
  }
  if (reviewState == 'CHANGES_REQUIRED') {
    return ActivityStatus.needsFix;
  }
  if (reviewState == 'NEEDS_FIX' || reviewState == 'REQUIERE_CAMBIOS') {
    return ActivityStatus.needsFix;
  }
  if (reviewState == 'PENDING_REVIEW') {
    return ActivityStatus.pendingReview;
  }
  if (reviewState == 'PENDIENTE_REVISION' || reviewState == 'EN_REVISION') {
    return ActivityStatus.pendingReview;
  }
  if (reviewState == 'APPROVED') {
    return ActivityStatus.approved;
  }
  if (reviewState == 'APROBADO') {
    return ActivityStatus.approved;
  }
  if (nextAction == 'CORREGIR_Y_REENVIAR') {
    return ActivityStatus.needsFix;
  }

  if (reviewState.isEmpty && nextAction.isEmpty) {
    if (activity.flags.checklistIncomplete) {
      return ActivityStatus.conflict;
    }
    return ActivityStatus.conflict;
  }

  if (activity.flags.checklistIncomplete) {
    return ActivityStatus.conflict;
  }
  return activity.activity.status;
}

String deriveActivityQueueStatusLabel(ActivityWithDetails activity) {
  switch (ActivityStatus.normalize(deriveActivityQueueStatus(activity))) {
    case ActivityStatus.rejected:
      return 'Rechazada';
    case ActivityStatus.needsFix:
      return 'Corrección solicitada';
    case ActivityStatus.approved:
      return 'Aprobada';
    case ActivityStatus.corrected:
      return 'Corregida';
    case ActivityStatus.conflict:
      return 'Con conflicto';
    case ActivityStatus.pendingReview:
    default:
      return 'Pendiente de revisión';
  }
}

String deriveActivityQueueStatusMessage(ActivityWithDetails activity) {
  final reviewState = (activity.reviewState ?? '').trim().toUpperCase();
  final nextAction = (activity.nextAction ?? '').trim().toUpperCase();
  final hasComment = (activity.activity.reviewComments ?? '').trim().isNotEmpty;

  switch (ActivityStatus.normalize(deriveActivityQueueStatus(activity))) {
    case ActivityStatus.rejected:
      return hasComment
          ? 'Rechazo enviado al móvil con observaciones.'
          : 'Rechazo enviado al móvil.';
    case ActivityStatus.needsFix:
      if (nextAction == 'CORREGIR_Y_REENVIAR') {
        return 'Se solicitó corregir y reenviar desde el móvil.';
      }
      if (reviewState == 'CHANGES_REQUIRED' ||
          reviewState == 'NEEDS_FIX' ||
          reviewState == 'REQUIERE_CAMBIOS') {
        return 'La actividad necesita corrección antes de volver a enviarse.';
      }
      return 'Actividad marcada para corrección.';
    case ActivityStatus.approved:
      return 'Aprobada y lista para el siguiente paso.';
    case ActivityStatus.corrected:
      return 'La actividad fue corregida y sigue en seguimiento.';
    case ActivityStatus.conflict:
      return 'Hay pendientes técnicos o de catálogo por resolver.';
    case ActivityStatus.pendingReview:
    default:
      return 'Esperando decisión de revisión.';
  }
}

List<String> deriveActivityBlockingIssues(ActivityWithDetails activity) {
  final issues = <String>[];
  final hasEvidence = activity.evidences.isNotEmpty;
  final hasPendingEvidence = activity.evidences.any((evidence) {
    final path = evidence.filePath.trim().toLowerCase();
    if (path.isEmpty) return true;
    if (path.startsWith('pending://')) return true;
    if (path.startsWith('backend://')) return false;
    if (path.startsWith('http://') ||
        path.startsWith('https://') ||
        path.startsWith('file://')) {
      return false;
    }
    return true;
  });

  if (activity.flags.catalogChanged) {
    issues.add('Cambio de catálogo pendiente');
  }
  if (!hasEvidence && activity.flags.checklistIncomplete) {
    issues.add('Sin evidencia técnica adjunta');
  }
  if (hasPendingEvidence) {
    issues.add('Evidencia pendiente de sincronización en servidor');
  }
  if (activity.flags.gpsMismatch) {
    issues.add('La evidencia no incluye coordenadas GPS válidas');
  }
  if (issues.isEmpty && activity.flags.checklistIncomplete) {
    issues.add('Checklist técnico incompleto o con datos obligatorios faltantes');
  }

  return issues.toSet().toList(growable: false);
}

bool isRejectedQueueBucket(ActivityWithDetails activity) {
  final normalizedStatus = ActivityStatus.normalize(
    deriveActivityQueueStatus(activity),
  );
  return normalizedStatus == ActivityStatus.rejected ||
      normalizedStatus == ActivityStatus.needsFix;
}

bool isPendingQueueBucket(ActivityWithDetails activity) {
  final normalizedStatus = ActivityStatus.normalize(
    deriveActivityQueueStatus(activity),
  );
  return normalizedStatus == ActivityStatus.pendingReview;
}

bool isChangesQueueBucket(ActivityWithDetails activity) {
  if (isRejectedQueueBucket(activity)) {
    return false;
  }
  final normalizedStatus = ActivityStatus.normalize(
    deriveActivityQueueStatus(activity),
  );
  return normalizedStatus == ActivityStatus.conflict ||
      activity.flags.catalogChanged ||
      activity.flags.checklistIncomplete;
}

bool isReadyToApproveQueueBucket(ActivityWithDetails activity) {
  return isPendingQueueBucket(activity) && !isChangesQueueBucket(activity);
}

RiskLevel deriveActivityQueueRisk(ActivityWithDetails activity) {
  final reviewState = (activity.reviewState ?? '').trim().toUpperCase();
  if (reviewState == 'REJECTED' ||
      reviewState == 'RECHAZADO' ||
      reviewState == 'CHANGES_REQUIRED' ||
      reviewState == 'NEEDS_FIX' ||
      reviewState == 'REQUIERE_CAMBIOS') {
    return RiskCatalog.prioritario;
  }
  if (reviewState == 'PENDING_REVIEW' ||
      reviewState == 'PENDIENTE_REVISION' ||
      reviewState == 'EN_REVISION') {
    return RiskCatalog.alto;
  }
  if (reviewState == 'APPROVED' || reviewState == 'APROBADO') {
    return RiskCatalog.bajo;
  }

  final description = (activity.activity.description ?? '').toLowerCase();
  if (description.contains('prioritario') || description.contains('crítico')) {
    return RiskCatalog.prioritario;
  }
  if (description.contains('alto')) {
    return RiskCatalog.alto;
  }
  if (description.contains('medio')) {
    return RiskCatalog.medio;
  }
  if (description.contains('bajo')) {
    return RiskCatalog.bajo;
  }

  final status = ActivityStatus.normalize(deriveActivityQueueStatus(activity));
  switch (status) {
    case ActivityStatus.rejected:
    case ActivityStatus.conflict:
    case ActivityStatus.needsFix:
      return RiskCatalog.prioritario;
    case ActivityStatus.pendingReview:
      return RiskCatalog.alto;
    case ActivityStatus.corrected:
      return RiskCatalog.medio;
    case ActivityStatus.approved:
      return RiskCatalog.bajo;
    default:
      return RiskCatalog.medio;
  }
}
