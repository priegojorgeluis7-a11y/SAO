import 'package:flutter_test/flutter_test.dart';
import 'package:sao_windows/data/local/app_db.dart';
import 'package:sao_windows/features/activities/wizard/wizard_controller.dart';
import 'package:sao_windows/features/catalog/catalog_repository.dart';
import 'package:sao_windows/features/evidence/pending_evidence_store.dart';
import 'package:sao_windows/features/home/models/today_activity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  WizardController buildController({required bool isUnplanned}) {
    return WizardController(
      activity: const TodayActivity(
        id: 'act-1',
        title: 'Actividad de prueba',
        frente: 'Frente A',
        municipio: 'Celaya',
        estado: 'Guanajuato',
        status: ActivityStatus.hoy,
      ),
      projectCode: 'TMQ',
      catalogRepo: CatalogRepository(),
      pendingStore: PendingEvidenceStore(),
      database: AppDb(),
      currentUserId: 'test-user',
      isUnplanned: isUnplanned,
    );
  }

  group('WizardController unplanned context', () {
    test('validateContextStep falla si isUnplanned y projectId es null', () {
      final controller = buildController(isUnplanned: true);
      addTearDown(() async => controller.database.close());
      controller.setRisk(RiskLevel.bajo);

      final result = controller.validateContextStep();

      expect(result.isValid, isFalse);
      expect(
        result.errors.any((error) => error.fieldKey == 'project'),
        isTrue,
      );
    });

    test('setProject actualiza estado y label usado por tarjeta', () {
      final controller = buildController(isUnplanned: true);
      addTearDown(() async => controller.database.close());

      controller.setProject(
        const ProjectRef(
          id: 'proj-1',
          code: 'TMQ',
          name: 'Tren México–Querétaro',
        ),
      );

      expect(controller.selectedProjectId, 'proj-1');
      expect(controller.contextProjectLabel, 'Tren México–Querétaro');
    });
  });
}
