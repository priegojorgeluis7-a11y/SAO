// lib/features/activities/wizard/models/evidence_draft.dart

/// Modelo de evidencia en borrador (offline)
/// Cada foto debe tener una descripción obligatoria
class EvidenceDraft {
  /// Ruta local del archivo en el dispositivo
  final String localPath;
  
  /// Descripción de la evidencia (OBLIGATORIA para guardar)
  String descripcion;
  
  /// Fecha y hora de creación
  final DateTime createdAt;
  
  /// Opcional: coordenadas si se obtienen del EXIF o GPS
  final double? lat;
  final double? lng;

  EvidenceDraft({
    required this.localPath,
    this.descripcion = '',
    DateTime? createdAt,
    this.lat,
    this.lng,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Valida si la evidencia tiene descripción
  bool get isValid => descripcion.trim().isNotEmpty;

  /// Copia con nuevos valores
  EvidenceDraft copyWith({
    String? localPath,
    String? descripcion,
    DateTime? createdAt,
    double? lat,
    double? lng,
  }) {
    return EvidenceDraft(
      localPath: localPath ?? this.localPath,
      descripcion: descripcion ?? this.descripcion,
      createdAt: createdAt ?? this.createdAt,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'localPath': localPath,
      'descripcion': descripcion,
      'createdAt': createdAt.toIso8601String(),
      'lat': lat,
      'lng': lng,
    };
  }

  factory EvidenceDraft.fromJson(Map<String, dynamic> json) {
    return EvidenceDraft(
      localPath: json['localPath'] as String,
      descripcion: json['descripcion'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
      lat: json['lat'] as double?,
      lng: json['lng'] as double?,
    );
  }
}
