import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sao_windows/features/activities/wizard/report_share_utils.dart';
import 'package:sao_windows/features/home/models/today_activity.dart';

void main() {
  group('buildInitialWhatsAppReport', () {
    test('builds a concise field-ready summary without fixed heading and supports bold custom title', () {
      final activity = TodayActivity(
        id: 'act-1',
        title: 'Asamblea informativa',
        frente: 'Frente 1',
        municipio: 'Doctor Mora',
        estado: 'Guanajuato',
        pk: 142900,
        status: ActivityStatus.hoy,
        executionState: ExecutionState.terminada,
        operationalState: 'COMPLETADA',
        reviewState: 'NOT_APPLICABLE',
        nextAction: 'SIN_ACCION',
        createdAt: DateTime(2026, 4, 15, 9, 0),
        horaInicio: DateTime(2026, 4, 15, 9, 0),
        horaFin: DateTime(2026, 4, 15, 10, 30),
        assignedToName: 'Jorge Prieto',
      );

      final defaultText = buildInitialWhatsAppReport(
        projectCode: 'TMQ',
        activity: activity,
        resultLabel: 'Acuerdo con comunidad',
        notes: 'Se revisó avance de obra y se atendieron solicitudes vecinales.',
        agreements: const [
          'Compartir minuta con autoridades locales',
          'Programar siguiente visita técnica',
        ],
        evidenceCount: 2,
      );

      final titledText = buildInitialWhatsAppReport(
        projectCode: 'TMQ',
        activity: activity,
        customTitle: 'REPORTE DE CAMPO',
        resultLabel: 'Acuerdo con comunidad',
        notes: 'Se revisó avance de obra y se atendieron solicitudes vecinales.',
        agreements: const [
          'Compartir minuta con autoridades locales',
        ],
        evidenceCount: 2,
      );

      expect(defaultText, isNot(contains('Primer reporte de actividad')));
      expect(defaultText, contains('*Proyecto:* TMQ'));
      expect(defaultText, contains('*Actividad:* Asamblea informativa'));
      expect(defaultText, contains('Doctor Mora, Guanajuato'));
      expect(defaultText, contains('*Resultado:* Acuerdo con comunidad'));
      expect(defaultText, isNot(contains('*Evidencia:*')));
      expect(defaultText, isNot(contains('fotos adjuntas')));
      expect(defaultText, contains('• Compartir minuta con autoridades locales'));
      expect(titledText.split('\n').first, '*REPORTE DE CAMPO*');
    });

    test('collects only existing image files for sharing', () async {
      final dir = await Directory.systemTemp.createTemp('share_paths_test');
      try {
        final imageFile = File('${dir.path}/evidence.jpg')..writeAsStringSync('ok');
        final nonImageFile = File('${dir.path}/note.pdf')..writeAsStringSync('ok');

        final result = collectShareableImagePaths([
          imageFile.path,
          nonImageFile.path,
          '${dir.path}/missing.png',
          '   ',
        ]);

        expect(result, [imageFile.path]);
      } finally {
        await dir.delete(recursive: true);
      }
    });
  });
}
