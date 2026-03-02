import 'activity_report_data.dart';
import 'evidence_item.dart';
import 'agreement_item.dart';
import 'attendee_item.dart';

/// Contexto completo para construir un reporte
class ReportContext {
  final ActivityReportData activity;
  final List<EvidenceItem> evidences;
  final List<AgreementItem> agreements;
  final List<AttendeeItem> attendees;
  
  // Opciones de generación
  final bool includeAuditTrail;
  final bool includeInternalNotes;
  final bool includeAttachments;
  final String? headerlogoPath; // ruta a logo institucional
  final String? letterheadImagePath; // ruta a membrete

  ReportContext({
    required this.activity,
    required this.evidences,
    required this.agreements,
    required this.attendees,
    this.includeAuditTrail = true,
    this.includeInternalNotes = false,
    this.includeAttachments = true,
    this.headerlogoPath,
    this.letterheadImagePath,
  });

  /// Images grouped by type
  List<EvidenceItem> get imageEvidences => 
      evidences.where((e) => e.isImage).toList();
  
  /// PDF attachments
  List<EvidenceItem> get pdfEvidences => 
      evidences.where((e) => e.isPdf).toList();

  /// Total cantidad de evidencias
  int get totalEvidences => evidences.length;

  /// Validación GPS vs PK
  bool get hasGpsPkValidation => 
      activity.latitude != null && activity.longitude != null && 
      activity.pkDeclared != null;

  bool get isGpsDiscrepancy => 
      hasGpsPkValidation && 
      activity.gpsDistanceToPk != null && 
      activity.gpsDistanceToPk! > 200;

  bool get isGpsCritical => 
      hasGpsPkValidation && 
      activity.gpsDistanceToPk != null && 
      activity.gpsDistanceToPk! > 800;
}
