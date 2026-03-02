import 'package:intl/intl.dart';
import 'audit_event.dart';
import 'risk_classification.dart';

/// Datos de una actividad para el reporte
class ActivityReportData {
  final String id;
  final String projectCode;
  final String? projectName;
  final String? frontName;
  final String? frontName_pk;
  final String activityType; // reunion_comunitaria, caminamiento, etc.
  final String title;
  final String? narrative;
  final String status; // pending, validated, approved, rejected
  final DateTime executedAt;
  final DateTime? validatedAt;
  final String? validatedBy;
  final String? rejectionReason;
  final double? latitude;
  final double? longitude;
  final String? pkDeclared;
  final double? gpsDistanceToPk;
  final RiskClassification riskClassification;
  final List<AuditEvent> auditEvents;
  final List<String>? internalNotes;

  ActivityReportData({
    required this.id,
    required this.projectCode,
    this.projectName,
    this.frontName,
    this.frontName_pk,
    required this.activityType,
    required this.title,
    this.narrative,
    required this.status,
    required this.executedAt,
    this.validatedAt,
    this.validatedBy,
    this.rejectionReason,
    this.latitude,
    this.longitude,
    this.pkDeclared,
    this.gpsDistanceToPk,
    required this.riskClassification,
    required this.auditEvents,
    this.internalNotes,
  });

  bool get isValidated => status == 'validated' || status == 'approved';
  bool get isApproved => status == 'approved';
  bool get isDraft => status == 'pending' || status == 'rejected';

  String get folio {
    // Formato: SAO-{PROY}-{FRENTE}-{PK|NA}-{YYYYMMDD}-{CONSEC}
    final dateStr = DateFormat('yyyyMMdd').format(executedAt);
    final pk = pkDeclared ?? 'NA';
    return 'SAO-$projectCode-${frontName ?? 'NA'}-$pk-$dateStr-001';
  }

  String get watermark {
    if (!isValidated) {
      return 'BORRADOR – NO VALIDADO';
    }
    if (isDraft) {
      return 'RECHAZADO';
    }
    return '';
  }

  String get typeLabel {
    switch (activityType) {
      case 'reunion_comunitaria':
        return 'Reunión Comunitaria';
      case 'caminamiento_tecnico':
        return 'Caminamiento Técnico';
      case 'reunion_tecnica_lddv':
        return 'Reunión Técnica LDDV';
      case 'mesa_interinstitucional':
        return 'Mesa Interinstitucional';
      case 'gestion_predios':
        return 'Gestión de Predios / Incidencias';
      default:
        return activityType;
    }
  }
}
