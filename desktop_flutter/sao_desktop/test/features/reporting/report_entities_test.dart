import 'package:flutter_test/flutter_test.dart';
import 'package:sao_desktop/features/reporting/domain/entities/activity_report_data.dart';
import 'package:sao_desktop/features/reporting/domain/entities/audit_event.dart';
import 'package:sao_desktop/features/reporting/domain/entities/evidence_item.dart';
import 'package:sao_desktop/features/reporting/domain/entities/risk_classification.dart';

void main() {
  group('RiskClassification', () {
    test('maps color and label for known levels', () {
      final critical = RiskClassification(
        riskLevel: 'crítico',
        tags: const [],
        autoDetected: true,
      );
      final medium = RiskClassification(
        riskLevel: 'medio',
        tags: const [],
        autoDetected: true,
      );

      expect(critical.colorHex, '#DC2626');
      expect(critical.displayLabel, 'Riesgo Crítico');
      expect(medium.colorHex, '#F59E0B');
      expect(medium.displayLabel, 'Riesgo Medio');
    });

    test('classifies text with infrastructure and social hints', () {
      final infra = RiskClassification.fromText('Incidente en gasoducto de CENAGAS');
      final social = RiskClassification.fromText('Asamblea en comunidad ejidal');
      final low = RiskClassification.fromText('actividad rutinaria');

      expect(infra.riskLevel, 'crítico');
      expect(infra.tags, contains('infraestructura_crítica'));
      expect(infra.autoDetected, isTrue);
      expect(social.riskLevel, 'alto');
      expect(social.tags, contains('social'));
      expect(low.riskLevel, 'bajo');
    });
  });

  group('ActivityReportData', () {
    test('computes workflow flags and derived labels', () {
      final approved = ActivityReportData(
        id: 'a1',
        projectCode: 'TMQ',
        frontName: 'F1',
        activityType: 'reunion_comunitaria',
        title: 'Actividad',
        status: 'approved',
        executedAt: DateTime(2026, 3, 5),
        riskClassification: RiskClassification(
          riskLevel: 'bajo',
          tags: const [],
          autoDetected: true,
        ),
        auditEvents: const <AuditEvent>[],
      );

      final rejected = ActivityReportData(
        id: 'a2',
        projectCode: 'TMQ',
        frontName: 'F2',
        activityType: 'mesa_interinstitucional',
        title: 'Actividad 2',
        status: 'rejected',
        executedAt: DateTime(2026, 3, 5),
        riskClassification: RiskClassification(
          riskLevel: 'alto',
          tags: const ['social'],
          autoDetected: true,
        ),
        auditEvents: const <AuditEvent>[],
      );

      expect(approved.isApproved, isTrue);
      expect(approved.isValidated, isTrue);
      expect(approved.isDraft, isFalse);
      expect(approved.watermark, isEmpty);
      expect(approved.folio, contains('SAO-TMQ-F1-NA-'));
      expect(approved.typeLabel, 'Reunión Comunitaria');

      expect(rejected.isDraft, isTrue);
      expect(rejected.watermark, 'BORRADOR – NO VALIDADO');
      expect(rejected.typeLabel, 'Mesa Interinstitucional');
    });
  });

  group('AuditEvent and EvidenceItem', () {
    test('maps labels and file type helpers', () {
      final event = AuditEvent(
        id: 'ev-1',
        eventType: 'approved',
        userId: 'u1',
        timestamp: DateTime(2026, 3, 5),
      );
      final image = EvidenceItem(
        id: 'img-1',
        filePath: 'C:/tmp/foto.jpg',
        fileType: 'IMAGE',
        capturedAt: DateTime(2026, 3, 5),
      );
      final doc = EvidenceItem(
        id: 'doc-1',
        filePath: 'C:/tmp/acta.pdf',
        fileType: 'DOCUMENT',
        capturedAt: DateTime(2026, 3, 5),
      );

      expect(event.displayLabel, 'Aprobado');
      expect(image.isImage, isTrue);
      expect(image.isPdf, isFalse);
      expect(doc.isImage, isFalse);
      expect(doc.isPdf, isTrue);
    });
  });
}
