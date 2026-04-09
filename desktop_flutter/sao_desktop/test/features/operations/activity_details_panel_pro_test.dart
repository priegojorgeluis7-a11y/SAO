import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sao_desktop/data/database/app_database.dart';
import 'package:sao_desktop/data/models/activity_model.dart';
import 'package:sao_desktop/data/repositories/catalog_repository.dart';
import 'package:sao_desktop/features/operations/widgets/activity_details_panel_pro.dart';

class _FakeCatalogRepository extends CatalogRepository {
  @override
  bool get isReady => true;

  @override
  String get projectId => 'TMQ';

  @override
  Future<void> loadProject(String projectId) async {}

  @override
  List<CatItem> getActivityTypes() {
    return [CatItem(id: 'CAM', name: 'Caminamiento')];
  }

  @override
  List<CatItem> subcategoriesFor(String activityId) {
    return [CatItem(id: 'sub-1', name: 'Marcaje de afectaciones')];
  }

  @override
  List<CatItem> temasSugeridosFor(String activityId,
      {bool includeAllWhenAllowed = true}) {
    return [CatItem(id: 'topic-1', name: 'Gálibos ferroviarios')];
  }

  @override
  List<CatItem> purposesFor({
    required String activityId,
    String? subcategoryId,
  }) {
    return [CatItem(id: 'purpose-1', name: 'Recorrido operativo')];
  }

  @override
  List<String> getMunicipalities() {
    return ['Doctor Mora'];
  }
}

ActivityWithDetails _buildActivity({
  String subcategory = 'Marcaje de afectaciones',
  String title = 'Caminamiento',
  String activityTypeName = 'Caminamiento',
  String assignedFullName = 'Jesús Pérez López',
  String assignedEmail = 'jesus.perez.lopez@sao.mx',
  String colony = 'Centro',
}) {
  return ActivityWithDetails(
    activity: Activity(
      id: 'act-1',
      projectId: 'TMQ',
      activityTypeId: 'CAM',
      assignedTo: 'user-1',
      title: title,
      description: 'Actividad de prueba',
      status: 'PENDING_REVIEW',
      createdAt: DateTime(2026, 4, 6, 17, 10),
    ),
    activityType: ActivityType(
      id: 'CAM',
      name: activityTypeName,
      code: 'CAM',
      projectId: 'TMQ',
    ),
    assignedUser: User(
      id: 'user-1',
      email: assignedEmail,
      fullName: assignedFullName,
      role: 'ENGINEER',
      status: 'ACTIVE',
      createdAt: DateTime(2026, 4, 6, 10, 0),
    ),
    front: Front(id: 'front-1', name: 'Frente 1', projectId: 'TMQ'),
    municipality: Municipality(id: 'mun-1', name: 'Doctor Mora', state: 'Guanajuato'),
    evidences: const [],
    flags: const ActivityFlags(),
    wizardPayload: {
      'subcategory': {'name': subcategory},
      'topics': [
        {'name': 'Gálibos ferroviarios'}
      ],
      'purpose': {'name': 'Recorrido operativo'},
      'location': {
        'municipio': 'Doctor Mora',
        'estado': 'Guanajuato',
        'colonia': colony,
      },
    },
  );
}

Widget _buildSubject(ActivityWithDetails activity) {
  return ProviderScope(
    overrides: [
      catalogRepositoryProvider.overrideWithValue(_FakeCatalogRepository()),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 1400,
          height: 900,
          child: ActivityDetailsPanelPro(activity: activity),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'keeps catalog actions collapsed when captured values already match the catalog',
    (tester) async {
      await tester.pumpWidget(_buildSubject(_buildActivity()));
      await tester.pumpAndSettle();

      expect(find.textContaining('Todos los campos coinciden con catálogo'), findsOneWidget);
      expect(find.text('Agregar al catálogo'), findsNothing);
      expect(find.text('Solicitar corrección'), findsNothing);
    },
  );

  testWidgets(
    'auto-expands catalog actions when a field requires change',
    (tester) async {
      await tester.pumpWidget(
        _buildSubject(_buildActivity(subcategory: 'Subcategoría nueva no catalogada')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Agregar al catálogo'), findsOneWidget);
      expect(find.text('Solicitar corrección'), findsOneWidget);
      expect(find.text('Requiere cambio'), findsWidgets);
    },
  );

  testWidgets(
    'shows grouped operational summary with friendly activity type name',
    (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          _buildActivity(
            title: 'Actividad operativa de prueba',
            activityTypeName: 'CAM',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('RESUMEN OPERATIVO'), findsOneWidget);
      expect(find.text('DATOS EDITABLES'), findsOneWidget);
      expect(find.text('Caminamiento'), findsWidgets);
    },
  );

  testWidgets(
    'shows editable first plus full location and surnames for personnel',
    (tester) async {
      await tester.pumpWidget(
        _buildSubject(
          _buildActivity(
            assignedFullName: 'Jesus',
            assignedEmail: 'jesus.perez.lopez@sao.mx',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Personal'), findsOneWidget);
      expect(find.text('Jesus Perez Lopez'), findsOneWidget);
      expect(find.text('jesus.perez.lopez@sao.mx'), findsNothing);
      expect(find.text('Estado'), findsOneWidget);
      expect(find.text('Guanajuato'), findsOneWidget);
      expect(find.text('Colonia'), findsOneWidget);
      expect(find.text('Centro'), findsWidgets);
      expect(find.textContaining('Coincide con'), findsNothing);
      expect(find.text('Marcaje de afectaciones'), findsWidgets);

      final editableTop = tester.getTopLeft(find.text('DATOS EDITABLES')).dy;
      final locationTop = tester.getTopLeft(find.text('Ubicación operativa')).dy;
      final identityTop = tester.getTopLeft(find.text('Identidad de actividad')).dy;
      final trackingTop = tester.getTopLeft(find.text('Seguimiento y evidencia')).dy;

      expect(editableTop <= locationTop, isTrue);
      expect(locationTop <= identityTop, isTrue);
      expect(identityTop <= trackingTop, isTrue);
    },
  );
}
