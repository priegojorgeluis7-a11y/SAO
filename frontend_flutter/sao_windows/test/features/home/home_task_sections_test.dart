import 'package:flutter_test/flutter_test.dart';
import 'package:sao_windows/features/home/home_task_sections.dart';
import 'package:sao_windows/features/home/models/today_activity.dart';

TodayActivity _activity({
  required String id,
  required String frente,
  required String nextAction,
}) {
  return TodayActivity(
    id: id,
    title: 'Actividad $id',
    frente: frente,
    municipio: 'Toluca',
    estado: 'EDOMEX',
    status: ActivityStatus.hoy,
    createdAt: DateTime(2026, 3, 24, 8),
    nextAction: nextAction,
  );
}

void main() {
  group('homeTaskSectionIdForNextAction', () {
    test('maps canonical next actions to expected inbox sections', () {
      expect(homeTaskSectionIdForNextAction('INICIAR_ACTIVIDAD'), 'por_iniciar');
      expect(homeTaskSectionIdForNextAction('TERMINAR_ACTIVIDAD'), 'en_curso');
      expect(homeTaskSectionIdForNextAction('COMPLETAR_WIZARD'), 'por_completar');
      expect(homeTaskSectionIdForNextAction('CORREGIR_Y_REENVIAR'), 'por_corregir');
      expect(homeTaskSectionIdForNextAction('REVISAR_ERROR_SYNC'), 'error_sync');
      expect(homeTaskSectionIdForNextAction('SINCRONIZAR_PENDIENTE'), 'pendiente_sync');
      expect(homeTaskSectionIdForNextAction('ESPERAR_DECISION_COORDINACION'), 'en_revision');
      expect(homeTaskSectionIdForNextAction('SIN_ACCION'), 'otras');
    });
  });

  group('buildHomeTaskSections', () {
    test('returns non-empty sections in inbox priority order', () {
      final sections = buildHomeTaskSections([
        _activity(id: '5', frente: 'F2', nextAction: 'SINCRONIZAR_PENDIENTE'),
        _activity(id: '1', frente: 'F1', nextAction: 'INICIAR_ACTIVIDAD'),
        _activity(id: '4', frente: 'F1', nextAction: 'REVISAR_ERROR_SYNC'),
        _activity(id: '2', frente: 'F1', nextAction: 'TERMINAR_ACTIVIDAD'),
        _activity(id: '3', frente: 'F2', nextAction: 'COMPLETAR_WIZARD'),
      ]);

      expect(
        sections.map((section) => section.id).toList(),
        ['error_sync', 'por_completar', 'por_iniciar', 'en_curso', 'pendiente_sync'],
      );
      expect(sections.first.itemCount, 1);
      expect(sections.last.itemCount, 1);
    });

    test('keeps sub-groups by frente inside each section', () {
      final sections = buildHomeTaskSections([
        _activity(id: '1', frente: 'Frente A', nextAction: 'INICIAR_ACTIVIDAD'),
        _activity(id: '2', frente: 'Frente B', nextAction: 'INICIAR_ACTIVIDAD'),
        _activity(id: '3', frente: 'Frente A', nextAction: 'INICIAR_ACTIVIDAD'),
      ]);

      final section = sections.single;

      expect(section.id, 'por_iniciar');
      expect(section.groupedByFrente.keys.toList(), ['Frente A', 'Frente B']);
      expect(section.groupedByFrente['Frente A']!.map((item) => item.id).toList(), ['1', '3']);
      expect(section.groupedByFrente['Frente B']!.map((item) => item.id).toList(), ['2']);
    });
  });
}