import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:sao_desktop/features/reports/reports_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() async {
    await initializeDateFormatting('es_MX');
    Intl.defaultLocale = 'es_MX';
  });

  group('reports_provider models', () {
    test('ReportFilters copyWith and ReportActivityItem mapping', () {
      final filters = ReportFilters(
        projectId: 'TMQ',
        frontName: 'Todos',
        dateRange: ReportDateRange(
          start: DateTime(2026, 3, 1),
          end: DateTime(2026, 3, 5),
        ),
      );

      final updated = filters.copyWith(frontName: 'Frente A');
      expect(updated.projectId, 'TMQ');
      expect(updated.frontName, 'Frente A');

      final item = ReportActivityItem.fromJson({
        'id': 'a1',
        'activity_type': 'Reunion',
        'pk': 'PK-10',
        'front_name': 'Frente A',
        'status': 'APROBADO',
        'created_at': '2026-03-05T00:00:00Z',
        'assigned_name': 'Operador',
        'project_id': 'TMQ',
      });

      expect(item.id, 'a1');
      expect(item.frontName, 'Frente A');
      expect(item.assignedName, 'Operador');
      expect(item.projectId, 'TMQ');
      expect(item.statusLabel, 'Aprobado');

      final approvedByReview = ReportActivityItem.fromJson({
        'id': 'a2',
        'activity_type': 'Caminamiento',
        'pk': 'PK-20',
        'front_name': 'Frente 1',
        'status': 'COMPLETADA',
        'review_decision': 'APPROVE',
        'review_status': 'APPROVED',
        'created_at': '2026-03-05T00:00:00Z',
      });

      expect(approvedByReview.statusLabel, 'Aprobado');

      final enrichedFromDataFields = ReportActivityItem.fromJson({
        'id': 'a3',
        'activity_type': 'Caminamiento',
        'front_name': 'Frente 1',
        'status': 'COMPLETADA',
        'review_decision': 'APPROVE',
        'review_status': 'APPROVED',
        'data_fields': {
          'purpose': 'Recorrido de seguimiento comunitario',
          'temas': ['Avance de obra', 'Acuerdos con vecinos'],
          'asistentes': ['SICT', 'ATTRAPI'],
          'resultado': 'Aprobado',
          'hora_inicio': '09:00',
          'hora_fin': '10:30',
        },
      });

      expect(enrichedFromDataFields.purpose, 'Recorrido de seguimiento comunitario');
      expect(enrichedFromDataFields.topics, contains('Avance de obra'));
      expect(enrichedFromDataFields.attendees, contains('ATTRAPI'));
      expect(enrichedFromDataFields.result, 'Aprobado');
      expect(enrichedFromDataFields.startTime, '09:00');
      expect(enrichedFromDataFields.endTime, '10:30');

      final fallback = ReportActivityItem.fromJson(const {});
      expect(fallback.activityType, 'Actividad');
      expect(fallback.pk, '-');
      expect(fallback.frontName, 'Sin frente');
      expect(fallback.statusLabel, 'Pendiente revisión');
    });
  });

  group('generateActivitiesPdf', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('sao_reports_provider_test_');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getApplicationDocumentsDirectory' ||
            call.method == 'getApplicationDocumentsPath') {
          return tempDir.path;
        }
        return tempDir.path;
      });
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('creates a PDF file under SAO_Reportes', () async {
      final items = [
        const ReportActivityItem(
          id: 'actividad-1',
          activityType: 'Inspeccion',
          pk: 'PK-01',
          frontName: 'Frente A',
          status: 'APROBADO',
          createdAt: '2026-03-05T00:00:00Z',
        ),
        const ReportActivityItem(
          id: 'actividad-2',
          activityType: 'Asamblea',
          pk: 'PK-02',
          frontName: 'Frente B',
          status: 'RECHAZADO',
          createdAt: '2026-03-05T00:00:00Z',
        ),
      ];

      final filters = ReportFilters(
        projectId: 'TMQ',
        frontName: 'Todos',
        dateRange: ReportDateRange(
          start: DateTime(2026, 3, 1),
          end: DateTime(2026, 3, 5),
        ),
      );

      final file = await generateActivitiesPdf(
        items,
        filters,
        executiveSummary: 'Resumen de prueba',
        includeAudit: true,
        includeNotes: true,
        includeAttachments: false,
      );

      expect(await file.exists(), isTrue);
      expect(file.path, contains('SAO_Reportes'));
      expect(file.path.toLowerCase(), endsWith('.pdf'));
    });
  });
}
