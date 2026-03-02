/// Evidencia (foto, PDF, etc.)
class EvidenceItem {
  final String id;
  final String filePath; // ruta local al archivo
  final String fileType; // IMAGE, VIDEO, AUDIO, DOCUMENT(PDF)
  final String? caption; // pie de foto editable
  final DateTime capturedAt;
  final double? latitude;
  final double? longitude;
  final String? hash; // para detectar duplicados
  final int? fileSizeBytes;

  EvidenceItem({
    required this.id,
    required this.filePath,
    required this.fileType,
    this.caption,
    required this.capturedAt,
    this.latitude,
    this.longitude,
    this.hash,
    this.fileSizeBytes,
  });

  bool get isImage => fileType == 'IMAGE';
  bool get isPdf => fileType == 'DOCUMENT';
}
