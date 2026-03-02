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
  final String projectCode;  // TAP, TMQ, SNL
  final String frente;
  final String municipio;
  final String estado;
  final int? pk;
  final DateTime start;
  final DateTime end;
  final RiskLevel risk;
  final SyncStatus syncStatus;
  final String? activityTypeId;
  final String? notes;

  const AgendaItem({
    required this.id,
    required this.resourceId,
    required this.title,
    required this.projectCode,
    required this.frente,
    required this.municipio,
    required this.estado,
    this.pk,
    required this.start,
    required this.end,
    this.risk = RiskLevel.bajo,
    this.syncStatus = SyncStatus.pending,
    this.activityTypeId,
    this.notes,
  });

  AgendaItem copyWith({
    String? resourceId,
    String? title,
    String? projectCode,
    String? frente,
    String? municipio,
    String? estado,
    int? pk,
    DateTime? start,
    DateTime? end,
    RiskLevel? risk,
    SyncStatus? syncStatus,
    String? activityTypeId,
    String? notes,
  }) {
    return AgendaItem(
      id: id,
      resourceId: resourceId ?? this.resourceId,
      title: title ?? this.title,
      projectCode: projectCode ?? this.projectCode,
      frente: frente ?? this.frente,
      municipio: municipio ?? this.municipio,
      estado: estado ?? this.estado,
      pk: pk ?? this.pk,
      start: start ?? this.start,
      end: end ?? this.end,
      risk: risk ?? this.risk,
      syncStatus: syncStatus ?? this.syncStatus,
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
    return '$municipio, $estado';
  }

  Duration get duration => end.difference(start);

  bool overlaps(DateTime otherStart, DateTime otherEnd) {
    return start.isBefore(otherEnd) && end.isAfter(otherStart);
  }
}
