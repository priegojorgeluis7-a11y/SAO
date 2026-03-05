import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sao_desktop/features/reporting/data/services/report_export_service.dart';
import 'package:sao_desktop/features/reporting/domain/entities/activity_report_data.dart';
import 'package:sao_desktop/features/reporting/domain/entities/agreement_item.dart';
import 'package:sao_desktop/features/reporting/domain/entities/attendee_item.dart';
import 'package:sao_desktop/features/reporting/domain/entities/audit_event.dart';
import 'package:sao_desktop/features/reporting/domain/entities/evidence_item.dart';
import 'package:sao_desktop/features/reporting/domain/entities/report_context.dart';
import 'package:sao_desktop/features/reporting/domain/entities/risk_classification.dart';

void main() {
  group('ReportExportService', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('sao_report_export_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    ReportContext buildContextWithEvidence(File evidenceFile) {
      return ReportContext(
        activity: ActivityReportData(
          id: 'act-1',
          projectCode: 'SAO',
          frontName: 'F1',
          activityType: 'reunion_comunitaria',
          title: 'Actividad demo',
          status: 'approved',
          executedAt: DateTime(2026, 3, 5),
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
        ),
        evidences: [
          EvidenceItem(
            id: 'ev-1',
            filePath: evidenceFile.path,
            fileType: 'DOCUMENT',
            capturedAt: DateTime(2026, 3, 5),
          ),
        ],
        agreements: [
          AgreementItem(
            id: 'agr-1',
            action: 'Seguimiento',
            responsible: 'Equipo SAO',
            commitmentDate: DateTime(2026, 3, 20),
            status: 'pending',
          ),
        ],
        attendees: [
          AttendeeItem(
            id: 'att-1',
            name: 'Persona 1',
            role: 'Coordinador',
            signed: true,
          ),
        ],
      );
    }

    test('exportPackage copies evidence and writes manifest', () async {
      final evidence = File('${tempDir.path}${Platform.pathSeparator}acta.pdf');
      await evidence.writeAsString('dummy-pdf');

      final context = buildContextWithEvidence(evidence);
      final doc = pw.Document();
      doc.addPage(
        pw.Page(
          build: (_) => pw.Text('hello'),
        ),
      );

      final packageDir = await ReportExportService.exportPackage(
        pdfDocument: doc,
        context: context,
        outputPath: tempDir.path,
      );

      final copiedEvidence = File(
        '${packageDir.path}${Platform.pathSeparator}evidencias${Platform.pathSeparator}acta.pdf',
      );
      final manifest = File('${packageDir.path}${Platform.pathSeparator}manifest.json');
      final exportedPdf = File(
        '${packageDir.path}${Platform.pathSeparator}${context.activity.folio}.pdf',
      );

      expect(await packageDir.exists(), isTrue);
      expect(await copiedEvidence.exists(), isTrue);
      expect(await manifest.exists(), isTrue);
      expect(await exportedPdf.exists(), isTrue);
    });
  });
}
