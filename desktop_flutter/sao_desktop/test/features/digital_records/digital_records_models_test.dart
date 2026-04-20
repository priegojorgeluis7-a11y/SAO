import 'package:flutter_test/flutter_test.dart';
import 'package:sao_desktop/features/completed_activities/completed_activities_provider.dart';
import 'package:sao_desktop/features/digital_records/digital_records_page.dart';

void main() {
  test('CompletedActivity parses document_count from backend payload', () {
    final activity = CompletedActivity.fromJson({
      'id': 'act-1',
      'project_id': 'TMQ',
      'title': 'Caminamiento',
      'activity_type': 'CAM',
      'pk': 'PK 20+000',
      'front': 'Frente 1',
      'estado': 'Guanajuato',
      'municipio': 'Doctor Mora',
      'has_report': true,
      'document_count': 2,
      'evidence_count': 1,
    });

    expect(activity.hasReport, isTrue);
    expect(activity.documentCount, 2);
  });

  test('CompletedActivityDetail normalizes invalid related IDs', () {
    final detail = CompletedActivityDetail.fromJson({
      'id': 'act-1',
      'project_id': 'TMQ',
      'title': 'Actividad base',
      'activity_type': 'Reunión',
      'related_activity_ids': [null, 'act-2', '', ' null ', 'act-2', 'act-3'],
    });

    expect(detail.relatedActivityIds, ['act-2', 'act-3']);
  });

  test('CompletedActivityDetail parses related link tracking metadata', () {
    final detail = CompletedActivityDetail.fromJson({
      'id': 'act-1',
      'project_id': 'TMQ',
      'title': 'Actividad base',
      'activity_type': 'Reunión',
      'related_links': [
        {
          'activity_id': 'act-2',
          'relation_type': 'seguimiento',
          'status': 'en_seguimiento',
          'reason': 'Se está atendiendo el mismo caso',
          'next_action': 'Llamar al comisariado',
          'due_date': '2026-04-25',
        },
      ],
    });

    expect(detail.relatedActivityIds, ['act-2']);
    expect(detail.relatedLinks, hasLength(1));
    expect(detail.relatedLinks.single.relationType, 'seguimiento');
    expect(detail.relatedLinks.single.status, 'en_seguimiento');
    expect(detail.relatedLinks.single.nextAction, 'Llamar al comisariado');
  });

  test(
      'resolveDigitalRecordTreeItems preserves all project folders and counts when one project is selected',
      () {
    final items = [
      CompletedActivity.fromJson({
        'id': 'act-1',
        'project_id': 'TMQ',
        'title': 'Actividad GTO',
        'activity_type': 'Reunión',
        'pk': 'PK 1+000',
        'front': 'Frente Norte',
        'estado': 'Guanajuato',
        'municipio': 'Doctor Mora',
      }),
      CompletedActivity.fromJson({
        'id': 'act-2',
        'project_id': 'TMQ',
        'title': 'Actividad QRO',
        'activity_type': 'Reunión',
        'pk': 'PK 2+000',
        'front': 'Frente Norte',
        'estado': 'Querétaro',
        'municipio': 'Cadereyta',
      }),
      CompletedActivity.fromJson({
        'id': 'act-3',
        'project_id': 'ABC',
        'title': 'Otro proyecto',
        'activity_type': 'Asamblea',
        'pk': 'PK 3+000',
        'front': 'Frente Sur',
        'estado': 'Hidalgo',
        'municipio': 'Pachuca',
      }),
    ];

    final treeItems = resolveDigitalRecordTreeItems(
      items,
      selectedProject: 'TMQ',
    );

    expect(treeItems.map((item) => item.estado),
        containsAll(['Guanajuato', 'Querétaro']));
    expect(treeItems.any((item) => item.projectId == 'ABC'), isTrue);
  });

  test(
      'resolveManualRelatedActivities keeps only manually linked items in order',
      () {
    final current = CompletedActivity.fromJson({
      'id': 'act-1',
      'project_id': 'TMQ',
      'title': 'Reunión con ejidatarios por liberación de vía',
      'activity_type': 'Reunión',
      'pk': 'PK 20+000',
      'front': 'Frente Norte',
      'estado': 'Guanajuato',
      'municipio': 'Doctor Mora',
      'assigned_name': 'María Pérez',
    });

    final related = CompletedActivity.fromJson({
      'id': 'act-2',
      'project_id': 'TMQ',
      'title': 'Seguimiento con ejidatarios para liberación de vía',
      'activity_type': 'Reunión',
      'pk': 'PK 20+000',
      'front': 'Frente Norte',
      'estado': 'Guanajuato',
      'municipio': 'Doctor Mora',
      'assigned_name': 'María Pérez',
      'created_at': '2026-04-18T10:00:00Z',
    });

    final other = CompletedActivity.fromJson({
      'id': 'act-3',
      'project_id': 'TMQ',
      'title': 'Asamblea informativa distinta',
      'activity_type': 'Asamblea',
      'pk': 'PK 99+999',
      'front': 'Frente Sur',
      'estado': 'Querétaro',
      'municipio': 'Cadereyta',
      'assigned_name': 'Otro Responsable',
    });

    final linked = resolveManualRelatedActivities(
      current: current,
      relatedActivityIds: const ['act-2', 'act-3', 'act-1', 'missing'],
      candidates: [other, related],
    );

    expect(linked, hasLength(2));
    expect(linked.first.id, 'act-2');
    expect(linked.last.id, 'act-3');
  });
}
