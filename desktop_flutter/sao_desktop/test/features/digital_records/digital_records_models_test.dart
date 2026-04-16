import 'package:flutter_test/flutter_test.dart';
import 'package:sao_desktop/features/completed_activities/completed_activities_provider.dart';

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
}
