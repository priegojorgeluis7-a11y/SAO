import 'package:flutter_test/flutter_test.dart';
import 'package:sao_windows/data/local/dao/activity_dao.dart';

void main() {
  group('ProjectCompletionStat', () {
    test('computes completion rate', () {
      const stat = ProjectCompletionStat(
        projectCode: 'TMQ',
        total: 10,
        completed: 7,
      );

      expect(stat.completionRate, 0.7);
    });

    test('returns zero when total is zero', () {
      const stat = ProjectCompletionStat(
        projectCode: 'TMQ',
        total: 0,
        completed: 0,
      );

      expect(stat.completionRate, 0);
    });
  });
}
