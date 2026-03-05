import '../models/agenda_item.dart';

class AgendaAssignmentFactory {
  static const Set<String> _forbiddenIds = {
    'P-001',
    'project-uuid-example',
    'activity-type-uuid',
    'unknown_activity_type',
  };

  AgendaItem build({
    required String id,
    required String resourceId,
    required EffectiveActivityInput activity,
    required String projectCode,
    required String frente,
    required DateTime start,
    required DateTime end,
    required int? pk,
    required RiskLevel risk,
    required String? effectiveVersionId,
    required String? municipio,
    required String? estado,
  }) {
    _ensureValid('projectCode', projectCode);
    _ensureValid('activityId', activity.id);

    return AgendaItem(
      id: id,
      resourceId: resourceId,
      title: activity.name,
      activityId: activity.id,
      activityNameSnapshot: activity.name,
      colorSnapshot: activity.colorHex,
      severitySnapshot: activity.severity,
      effectiveVersionId: effectiveVersionId,
      projectCode: projectCode,
      frente: frente,
      municipio: municipio?.trim() ?? '',
      estado: estado?.trim() ?? '',
      pk: pk,
      start: start,
      end: end,
      risk: risk,
      syncStatus: SyncStatus.pending,
    );
  }

  void _ensureValid(String field, String value) {
    final normalized = value.trim();
    if (normalized.isEmpty || _forbiddenIds.contains(normalized)) {
      throw ArgumentError('Invalid $field: $value');
    }
  }
}

class EffectiveActivityInput {
  final String id;
  final String name;
  final String? colorHex;
  final String? severity;

  const EffectiveActivityInput({
    required this.id,
    required this.name,
    this.colorHex,
    this.severity,
  });
}
