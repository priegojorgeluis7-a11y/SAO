import 'package:flutter_test/flutter_test.dart';
import 'package:sao_windows/core/utils/format_utils.dart';

void main() {
  group('PK normalization', () {
    test('normalizes short numeric PK values as chainage kilometers', () {
      expect(normalizePkMeters(90), 90000);
      expect(parsePkMeters('90'), 90000);
      expect(parsePkMeters('90+250'), 90250);
    });

    test('formats historical short PK values consistently', () {
      expect(formatPk(90), '90+000');
      expect(formatPk(90250), '90+250');
    });
  });
}
