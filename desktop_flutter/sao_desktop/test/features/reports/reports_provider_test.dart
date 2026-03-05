import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sao_desktop/features/reports/reports_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.flutter.io/path_provider');

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
