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

class TodayActivity {
  final String id;
  final String title;
  final String frente;
  final String municipio;
  final String estado;
  final int? pk; // 142900 => 142+900
  final ActivityStatus status;
  final ExecutionState executionState;
  final DateTime? horaInicio;
  final DateTime? horaFin;
  final String? gpsLocation;

  const TodayActivity({
    required this.id,
    required this.title,
    required this.frente,
    required this.municipio,
    required this.estado,
    this.pk,
    required this.status,
    this.executionState = ExecutionState.pendiente,
    this.horaInicio,
    this.horaFin,
    this.gpsLocation,
  });

  TodayActivity copyWith({
    ExecutionState? executionState,
    DateTime? horaInicio,
    DateTime? horaFin,
    String? gpsLocation,
  }) {
    return TodayActivity(
      id: id,
      title: title,
      frente: frente,
      municipio: municipio,
      estado: estado,
      pk: pk,
      status: status,
      executionState: executionState ?? this.executionState,
      horaInicio: horaInicio ?? this.horaInicio,
      horaFin: horaFin ?? this.horaFin,
      gpsLocation: gpsLocation ?? this.gpsLocation,
    );
  }
}
