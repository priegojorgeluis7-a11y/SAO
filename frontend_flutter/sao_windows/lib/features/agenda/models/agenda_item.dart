// lib/features/agenda/models/agenda_item.dart

enum SyncStatus {
  pending,    // ☁️🕒 Pendiente de subir
  uploading,  // ☁️🕒 Subiendo
  synced,     // ☁️✅ Sincronizado
  error,      // ☁️❌ Error al sincronizar
}

enum RiskLevel {
  bajo,
  medio,
  alto,
  prioritario,
}

class AgendaItem {
  final String id;
  final String resourceId;
  final String title;
  final String? activityId;
  final String? activityNameSnapshot;
  final String? colorSnapshot;
  final String? severitySnapshot;
  final String? effectiveVersionId;
  final String projectCode;  // TAP, TMQ, SNL
  final String frente;
  final String municipio;
  final String estado;
  final int? pk;
  final DateTime start;
  final DateTime end;
  final RiskLevel risk;
  final SyncStatus syncStatus;
  final String operationalState;
  final String reviewState;
  final String nextAction;
  final String? activityTypeId;
  final String? notes;

  const AgendaItem({
    required this.id,
    required this.resourceId,
    required this.title,
    this.activityId,
    this.activityNameSnapshot,
    this.colorSnapshot,
    this.severitySnapshot,
    this.effectiveVersionId,
    required this.projectCode,
    required this.frente,
    required this.municipio,
    required this.estado,
    this.pk,
    required this.start,
    required this.end,
    this.risk = RiskLevel.bajo,
    this.syncStatus = SyncStatus.pending,
    this.operationalState = 'PENDIENTE',
    this.reviewState = 'NOT_APPLICABLE',
    this.nextAction = 'SIN_ACCION',
    this.activityTypeId,
    this.notes,
  });

  AgendaItem copyWith({
    String? resourceId,
    String? title,
    String? activityId,
    String? activityNameSnapshot,
    String? colorSnapshot,
    String? severitySnapshot,
    String? effectiveVersionId,
    String? projectCode,
    String? frente,
    String? municipio,
    String? estado,
    int? pk,
    DateTime? start,
    DateTime? end,
    RiskLevel? risk,
    SyncStatus? syncStatus,
    String? operationalState,
    String? reviewState,
    String? nextAction,
    String? activityTypeId,
    String? notes,
  }) {
    return AgendaItem(
      id: id,
      resourceId: resourceId ?? this.resourceId,
      title: title ?? this.title,
      activityId: activityId ?? this.activityId,
      activityNameSnapshot: activityNameSnapshot ?? this.activityNameSnapshot,
      colorSnapshot: colorSnapshot ?? this.colorSnapshot,
      severitySnapshot: severitySnapshot ?? this.severitySnapshot,
      effectiveVersionId: effectiveVersionId ?? this.effectiveVersionId,
      projectCode: projectCode ?? this.projectCode,
      frente: frente ?? this.frente,
      municipio: municipio ?? this.municipio,
      estado: estado ?? this.estado,
      pk: pk ?? this.pk,
      start: start ?? this.start,
      end: end ?? this.end,
      risk: risk ?? this.risk,
      syncStatus: syncStatus ?? this.syncStatus,
      operationalState: operationalState ?? this.operationalState,
      reviewState: reviewState ?? this.reviewState,
      nextAction: nextAction ?? this.nextAction,
      activityTypeId: activityTypeId ?? this.activityTypeId,
      notes: notes ?? this.notes,
    );
  }

  String get location {
    if (pk != null) {
      final km = pk! ~/ 1000;
      final m = pk! % 1000;
      return 'PK $km+${m.toString().padLeft(3, '0')}';
    }
    final city = municipio.trim();
    final state = estado.trim();
    if (city.isNotEmpty && state.isNotEmpty) {
      return '$city, $state';
    }
    if (city.isNotEmpty) return city;
    if (state.isNotEmpty) return state;
    return 'Sin ubicación';
  }

  Duration get duration => end.difference(start);

  bool overlaps(DateTime otherStart, DateTime otherEnd) {
    return start.isBefore(otherEnd) && end.isAfter(otherStart);
  }
}
