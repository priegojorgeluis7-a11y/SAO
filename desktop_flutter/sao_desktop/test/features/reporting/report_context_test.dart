import 'package:flutter_test/flutter_test.dart';
import 'package:sao_desktop/features/reporting/domain/entities/activity_report_data.dart';
import 'package:sao_desktop/features/reporting/domain/entities/agreement_item.dart';
import 'package:sao_desktop/features/reporting/domain/entities/attendee_item.dart';
import 'package:sao_desktop/features/reporting/domain/entities/audit_event.dart';
import 'package:sao_desktop/features/reporting/domain/entities/evidence_item.dart';
import 'package:sao_desktop/features/reporting/domain/entities/report_context.dart';
import 'package:sao_desktop/features/reporting/domain/entities/risk_classification.dart';

void main() {
  group('ReportContext', () {
    ReportContext buildContext({double? gpsDistanceToPk}) {
      final activity = ActivityReportData(
        id: 'act-1',
        projectCode: 'SAO',
        frontName: 'F1',
        activityType: 'reunion_comunitaria',
        title: 'Actividad demo',
        status: 'approved',
        executedAt: DateTime(2026, 3, 5),
        latitude: 19.5,
        longitude: -99.1,
        pkDeclared: 'PK-001',
        gpsDistanceToPk: gpsDistanceToPk,
        riskClassification: RiskClassification(
          riskLevel: 'bajo',
          tags: const [],
          autoDetected: true,
        ),
        auditEvents: [
          AuditEvent(
            id: 'evt-1',
            eventType: 'created',
            userId: 'u-1',
            timestamp: DateTime(2026, 3, 5),
          ),
        ],
      );

      return ReportContext(
        activity: activity,
        evidences: [
          EvidenceItem(
            id: 'e-img',
            filePath: 'C:/tmp/photo.jpg',
            fileType: 'IMAGE',
            capturedAt: DateTime(2026, 3, 5),
          ),
          EvidenceItem(
            id: 'e-pdf',
            filePath: 'C:/tmp/doc.pdf',
            fileType: 'DOCUMENT',
            capturedAt: DateTime(2026, 3, 5),
          ),
        ],
        agreements: [
          AgreementItem(
            id: 'a-1',
            action: 'Seguimiento',
            responsible: 'Equipo SAO',
            commitmentDate: DateTime(2026, 3, 20),
            status: 'pending',
          ),
        ],
        attendees: [
          AttendeeItem(
            id: 'p-1',
            name: 'Persona 1',
            role: 'Coordinador',
            signed: true,
          ),
        ],
      );
    }

    test('splits evidence by type and counts total', () {
      final context = buildContext(gpsDistanceToPk: 120);

      expect(context.totalEvidences, 2);
      expect(context.imageEvidences.length, 1);
      expect(context.pdfEvidences.length, 1);
      expect(context.hasGpsPkValidation, isTrue);
      expect(context.isGpsDiscrepancy, isFalse);
      expect(context.isGpsCritical, isFalse);
    });

    test('flags discrepancy and critical distance thresholds', () {
      final discrepancy = buildContext(gpsDistanceToPk: 350);
      final critical = buildContext(gpsDistanceToPk: 900);

      expect(discrepancy.isGpsDiscrepancy, isTrue);
      expect(discrepancy.isGpsCritical, isFalse);
      expect(critical.isGpsDiscrepancy, isTrue);
      expect(critical.isGpsCritical, isTrue);
    });
  });
}
