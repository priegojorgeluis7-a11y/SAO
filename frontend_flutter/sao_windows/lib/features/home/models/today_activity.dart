enum ActivityStatus {
  vencida,
  hoy,
  programada,
}

enum ExecutionState {
  pendiente,   // Nadie la ha tocado (Gris/Blanco)
  enCurso,     // Cronómetro corriendo (Verde/Activo) 
  revisionPendiente, // Se detuvo el tiempo pero no se guardó el formulario (Ámbar/Alerta)
  terminada,   // Guardado en BD (Verde Oscuro/Oculto)
}

enum ActivitySyncState {
  pending,
  synced,
  error,
  unknown,
}

class TodayActivity {
  final String id;
  final String title;
  final String frente;
  final String municipio;
  final String estado;
  final int? pk; // 142900 => 142+900
  final ActivityStatus status;
  final DateTime createdAt;
  final ExecutionState executionState;
  final DateTime? horaInicio;
  final DateTime? horaFin;
  final String? gpsLocation;
  final bool isUnplanned; // true when saved with origin==unplanned
  final bool isRejected;
  final ActivitySyncState syncState;
  final String operationalState;
  final String reviewState;
  final String nextAction;
  final String? assignedToUserId;
  final String? assignedToName;

  const TodayActivity({
    required this.id,
    required this.title,
    required this.frente,
    required this.municipio,
    required this.estado,
    this.pk,
    required this.status,
    required this.createdAt,
    this.executionState = ExecutionState.pendiente,
    this.horaInicio,
    this.horaFin,
    this.gpsLocation,
    this.isUnplanned = false,
    this.isRejected = false,
    this.syncState = ActivitySyncState.unknown,
    this.operationalState = 'PENDIENTE',
    this.reviewState = 'NOT_APPLICABLE',
    this.nextAction = 'SIN_ACCION',
    this.assignedToUserId,
    this.assignedToName,
  });

  TodayActivity copyWith({
    ExecutionState? executionState,
    DateTime? horaInicio,
    DateTime? horaFin,
    String? gpsLocation,
    bool? isUnplanned,
    bool? isRejected,
    ActivitySyncState? syncState,
    String? operationalState,
    String? reviewState,
    String? nextAction,
    String? assignedToUserId,
    String? assignedToName,
  }) {
    return TodayActivity(
      id: id,
      title: title,
      frente: frente,
      municipio: municipio,
      estado: estado,
      pk: pk,
      status: status,
      createdAt: createdAt,
      executionState: executionState ?? this.executionState,
      horaInicio: horaInicio ?? this.horaInicio,
      horaFin: horaFin ?? this.horaFin,
      gpsLocation: gpsLocation ?? this.gpsLocation,
      isUnplanned: isUnplanned ?? this.isUnplanned,
      isRejected: isRejected ?? this.isRejected,
      syncState: syncState ?? this.syncState,
      operationalState: operationalState ?? this.operationalState,
      reviewState: reviewState ?? this.reviewState,
      nextAction: nextAction ?? this.nextAction,
      assignedToUserId: assignedToUserId ?? this.assignedToUserId,
      assignedToName: assignedToName ?? this.assignedToName,
    );
  }
}
