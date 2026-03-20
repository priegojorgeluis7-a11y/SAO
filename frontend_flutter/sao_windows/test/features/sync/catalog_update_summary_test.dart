import 'package:flutter_test/flutter_test.dart';
import 'package:sao_windows/features/sync/catalog_update_summary.dart';

void main() {
  group('summarizeCatalogDiff', () {
    test('returns zero summary for null diff', () {
      final summary = summarizeCatalogDiff(null);
      expect(summary.upserts, 0);
      expect(summary.deletes, 0);
      expect(summary.hasChanges, isFalse);
    });

    test('aggregates upserts and deletes across sections', () {
      final diff = <String, dynamic>{
        'changes': <String, dynamic>{
          'activities': {
            'upserts': [1, 2, 3],
            'deletes': [1],
          },
          'topics': {
            'upserts': [1],
            'deletes': [1, 2],
          },
        },
      };

      final summary = summarizeCatalogDiff(diff);
      expect(summary.upserts, 4);
      expect(summary.deletes, 3);
      expect(summary.hasChanges, isTrue);
      expect(summary.shortLabel, '4 alta/actualizacion, 3 baja(s)');
    });
  });
}
