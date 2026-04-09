import 'package:flutter_test/flutter_test.dart';
import 'package:sao_windows/features/home/home_push_refresh_policy.dart';

void main() {
  group('home push refresh policy', () {
    test('refreshes mobile home for review correction pushes', () {
      expect(shouldRefreshHomeFromPushType('review_changes_required'), isTrue);
      expect(shouldRefreshHomeFromPushType('review_decision'), isTrue);
      expect(shouldRefreshHomeFromPushType('review_approved'), isTrue);
    });

    test('builds correction request message for rejected review push', () {
      expect(
        homeRefreshMessageForPushType('review_changes_required'),
        contains('correccion'),
      );
    });

    test('ignores unrelated push types for home refresh', () {
      expect(shouldRefreshHomeFromPushType('catalog_update'), isFalse);
      expect(shouldRefreshHomeFromPushType(''), isFalse);
    });
  });
}
