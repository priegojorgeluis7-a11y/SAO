import 'package:flutter_test/flutter_test.dart';
import 'package:sao_windows/features/activities/wizard/wizard_controller.dart';

void main() {
  group('Report agreements sanitization', () {
    test('removes empty items and trims valid items', () {
      final input = ['  ', 'Acuerdo 1', '  Acuerdo 2  '];

      final output = WizardController.sanitizeReportAgreements(input);

      expect(output, equals(['Acuerdo 1', 'Acuerdo 2']));
    });
  });
}
