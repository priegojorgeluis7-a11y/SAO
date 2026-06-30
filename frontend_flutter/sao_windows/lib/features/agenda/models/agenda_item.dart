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

/// Tipo de referencia de ubicación en una asignación.
enum LocationType {
  /// PK puntual — un solo kilómetro/punto de referencia.
  pk,
  /// Rango PK a PK — tramo entre dos puntos.
  pkRange,
  /// Lugar — descripción libre del sitio.
  lugar,
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
  final List<String> frenteIds;  // NUEVO: Lista de IDs de frentes seleccionados
  final bool allFronts;          // NUEVO: Flag para asignar a todos los frentes
  final String municipio;
  final String estado;
  final int? pk;
  final int? pkStart;
  final int? pkEnd;
  final String? lugar;
  final LocationType locationType;
  final DateTime start;
  final DateTime end;
  final RiskLevel risk;
  final SyncStatus syncStatus;
  final String operationalState;
  final String reviewState;
  final String nextAction;
  final String? activityTypeId;
  final String? notes;
  final List<String> coResponsableIds;

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
    this.frenteIds = const [],    // NUEVO
    this.allFronts = false,       // NUEVO
    required this.municipio,
    required this.estado,
    this.pk,
    this.pkStart,
    this.pkEnd,
    this.lugar,
    this.locationType = LocationType.pk,
    required this.start,
    required this.end,
    this.risk = RiskLevel.bajo,
    this.syncStatus = SyncStatus.pending,
    this.operationalState = 'PENDIENTE',
    this.reviewState = 'NOT_APPLICABLE',
    this.nextAction = 'SIN_ACCION',
    this.activityTypeId,
    this.notes,
    this.coResponsableIds = const [],
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
    List<String>? frenteIds,
    bool? allFronts,
    String? municipio,
    String? estado,
    int? pk,
    int? pkStart,
    int? pkEnd,
    String? lugar,
    LocationType? locationType,
    DateTime? start,
    DateTime? end,
    RiskLevel? risk,
    SyncStatus? syncStatus,
    String? operationalState,
    String? reviewState,
    String? nextAction,
    String? activityTypeId,
    String? notes,
    List<String>? coResponsableIds,
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
      frenteIds: frenteIds ?? this.frenteIds,
      allFronts: allFronts ?? this.allFronts,
      municipio: municipio ?? this.municipio,
      estado: estado ?? this.estado,
      pk: pk ?? this.pk,
      pkStart: pkStart ?? this.pkStart,
      pkEnd: pkEnd ?? this.pkEnd,
      lugar: lugar ?? this.lugar,
      locationType: locationType ?? this.locationType,
      start: start ?? this.start,
      end: end ?? this.end,
      risk: risk ?? this.risk,
      syncStatus: syncStatus ?? this.syncStatus,
      operationalState: operationalState ?? this.operationalState,
      reviewState: reviewState ?? this.reviewState,
      nextAction: nextAction ?? this.nextAction,
      activityTypeId: activityTypeId ?? this.activityTypeId,
      notes: notes ?? this.notes,
      coResponsableIds: coResponsableIds ?? this.coResponsableIds,
    );
  }

  String get location {
    switch (locationType) {
      case LocationType.lugar:
        final l = lugar?.trim() ?? '';
        if (l.isNotEmpty) return l;
        break;
      case LocationType.pkRange:
        if (pkStart != null && pkEnd != null) {
          String fmtPk(int v) {
            final km = v ~/ 1000;
            final m = v % 1000;
            return 'PK $km+${m.toString().padLeft(3, '0')}';
          }
          return '${fmtPk(pkStart!)} — ${fmtPk(pkEnd!)}';
        }
        if (pkStart != null) {
          final km = pkStart! ~/ 1000;
          final m = pkStart! % 1000;
          return 'PK $km+${m.toString().padLeft(3, '0')}';
        }
        break;
      case LocationType.pk:
        if (pk != null) {
          final km = pk! ~/ 1000;
          final m = pk! % 1000;
          return 'PK $km+${m.toString().padLeft(3, '0')}';
        }
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
