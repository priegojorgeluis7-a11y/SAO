import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sao_windows/data/local/app_db.dart';
import 'package:sao_windows/features/activities/wizard/wizard_controller.dart';
import 'package:sao_windows/features/catalog/catalog_repository.dart';
import 'package:sao_windows/features/evidence/pending_evidence_store.dart';
import 'package:sao_windows/features/home/models/today_activity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  WizardController buildController() {
    return WizardController(
      activity: const TodayActivity(
        id: 'act-gps-1',
        title: 'Actividad GPS',
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
    );
  }

  void fillMinimumDataForSave(WizardController controller) {
    controller.setRisk(RiskLevel.bajo);
    controller.setHoraInicio(const TimeOfDay(hour: 9, minute: 0));
    controller.setHoraFin(const TimeOfDay(hour: 10, minute: 0));
    controller.setMunicipio('Celaya');
    controller.setColonia('Centro');

    controller.setActivity(
      const CatItem(
        id: 'ACT_GPS',
        label: 'Actividad con GPS',
        icon: Icons.category_rounded,
        requiresGeo: true,
      ),
    );
    controller.setSubcategory(
      const CatItem(
        id: 'SUB_1',
        label: 'Subcategoría',
        icon: Icons.subdirectory_arrow_right_rounded,
      ),
    );

    controller.toggleTopic('TOPIC_1');
    controller.toggleAttendee('ATT_1');
    controller.setResult(
      const CatItem(
        id: 'RES_1',
        label: 'Resultado',
        icon: Icons.check_circle_rounded,
      ),
    );

    controller.addPhoto('/tmp/foto.jpg');
    controller.updateDescripcion(0, 'Evidencia de campo');
  }

  group('WizardController GPS required validation', () {
    test('validateBeforeSave blocks when selected activity requires GPS and coordinates are missing', () {
      final controller = buildController();
      addTearDown(() async => controller.database.close());

      fillMinimumDataForSave(controller);

      final result = controller.validateBeforeSave();

      expect(result.isValid, isFalse);
      expect(result.errorFieldKey, 'gps_required');
    });

    test('validateBeforeSave passes when selected activity requires GPS and coordinates are present', () {
      final controller = buildController();
      addTearDown(() async => controller.database.close());

      fillMinimumDataForSave(controller);
      controller.setGpsCoordinates(latitude: 20.523, longitude: -100.812, accuracy: 8);

      final result = controller.validateBeforeSave();

      expect(result.isValid, isTrue);
    });

    test('validateBeforeSave blocks when workflow checklist requires photo_min_2 and only one evidence exists', () {
      final controller = buildController();
      addTearDown(() async => controller.database.close());

      controller.setRisk(RiskLevel.bajo);
      controller.setHoraInicio(const TimeOfDay(hour: 9, minute: 0));
      controller.setHoraFin(const TimeOfDay(hour: 10, minute: 0));
      controller.setMunicipio('Celaya');
      controller.setColonia('Centro');

      controller.setActivity(
        const CatItem(
          id: 'ACT_MIN_2',
          label: 'Actividad con mínimo 2 fotos',
          icon: Icons.category_rounded,
          workflowChecklist: ['photo_min_2'],
        ),
      );
      controller.setSubcategory(
        const CatItem(
          id: 'SUB_1',
          label: 'Subcategoría',
          icon: Icons.subdirectory_arrow_right_rounded,
        ),
      );
      controller.toggleTopic('TOPIC_1');
      controller.toggleAttendee('ATT_1');
      controller.setResult(
        const CatItem(
          id: 'RES_1',
          label: 'Resultado',
          icon: Icons.check_circle_rounded,
        ),
      );

      controller.addPhoto('/tmp/foto-1.jpg');
      controller.updateDescripcion(0, 'Evidencia 1');

      final result = controller.validateBeforeSave();

      expect(result.isValid, isFalse);
      expect(result.errorFieldKey, 'btn_agregar_foto');
      expect(result.errorMessage, contains('2 foto'));
    });

    test('validateBeforeSave passes when workflow checklist requires photo_min_2 and two evidences exist', () {
      final controller = buildController();
      addTearDown(() async => controller.database.close());

      controller.setRisk(RiskLevel.bajo);
      controller.setHoraInicio(const TimeOfDay(hour: 9, minute: 0));
      controller.setHoraFin(const TimeOfDay(hour: 10, minute: 0));
      controller.setMunicipio('Celaya');
      controller.setColonia('Centro');

      controller.setActivity(
        const CatItem(
          id: 'ACT_MIN_2_OK',
          label: 'Actividad con mínimo 2 fotos',
          icon: Icons.category_rounded,
          workflowChecklist: ['photo_min_2'],
          requiresGeo: true,
        ),
      );
      controller.setSubcategory(
        const CatItem(
          id: 'SUB_1',
          label: 'Subcategoría',
          icon: Icons.subdirectory_arrow_right_rounded,
        ),
      );
      controller.toggleTopic('TOPIC_1');
      controller.toggleAttendee('ATT_1');
      controller.setResult(
        const CatItem(
          id: 'RES_1',
          label: 'Resultado',
          icon: Icons.check_circle_rounded,
        ),
      );
      controller.setGpsCoordinates(latitude: 20.523, longitude: -100.812, accuracy: 8);

      controller.addPhoto('/tmp/foto-1.jpg');
      controller.updateDescripcion(0, 'Evidencia 1');
      controller.addPhoto('/tmp/foto-2.jpg');
      controller.updateDescripcion(1, 'Evidencia 2');

      final result = controller.validateBeforeSave();

      expect(result.isValid, isTrue);
    });
  });
}
