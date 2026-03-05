import 'package:flutter_test/flutter_test.dart';
import 'package:sao_windows/features/agenda/data/agenda_assignment_factory.dart';
import 'package:sao_windows/features/agenda/models/agenda_item.dart';

void main() {
  group('AgendaAssignmentFactory', () {
    test('crea asignación con ids reales', () {
      final factory = AgendaAssignmentFactory();
      final now = DateTime.now();

      final item = factory.build(
        id: 'asg-1',
        resourceId: 'user-1',
        activity: const EffectiveActivityInput(id: 'act-123', name: 'Inspección'),
        projectCode: 'TMQ',
        frente: 'Frente 2',
        start: now,
        end: now.add(const Duration(hours: 1)),
        pk: 12000,
        risk: RiskLevel.medio,
        effectiveVersionId: 'v-10',
        municipio: null,
        estado: null,
      );

      expect(item.projectCode, 'TMQ');
      expect(item.activityId, 'act-123');
      expect(item.syncStatus, SyncStatus.pending);
    });

    test('rechaza placeholders en projectCode/activityId', () {
      final factory = AgendaAssignmentFactory();
      final now = DateTime.now();

      expect(
        () => factory.build(
          id: 'asg-2',
          resourceId: 'user-1',
          activity: const EffectiveActivityInput(id: 'activity-type-uuid', name: 'X'),
          projectCode: 'P-001',
          frente: 'Frente 2',
          start: now,
          end: now.add(const Duration(hours: 1)),
          pk: null,
          risk: RiskLevel.bajo,
          effectiveVersionId: null,
          municipio: null,
          estado: null,
        ),
        throwsArgumentError,
      );
    });
  });
}
