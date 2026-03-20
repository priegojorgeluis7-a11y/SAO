import 'package:flutter_test/flutter_test.dart';
import 'package:sao_windows/features/activities/wizard/models/evidence_draft.dart';

void main() {
  group('EvidenceDraft', () {
    test('is invalid without description', () {
      final draft = EvidenceDraft(localPath: 'C:/tmp/photo.jpg');
      expect(draft.isValid, isFalse);
    });

    test('is valid with non-empty description', () {
      final draft = EvidenceDraft(
        localPath: 'C:/tmp/photo.jpg',
        descripcion: 'Frente norte, punto de inspeccion',
      );
      expect(draft.isValid, isTrue);
    });
  });
}
