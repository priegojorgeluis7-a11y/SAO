import 'package:flutter_test/flutter_test.dart';
import 'package:sao_desktop/data/repositories/review_decision_outbox.dart';

void main() {
  group('ReviewDecisionOutbox', () {
    test('flush removes queued item after successful send', () async {
      var sends = 0;
      final outbox = ReviewDecisionOutbox(
        sender: (path, payload) async {
          sends += 1;
        },
        autoFlushOnEnqueue: false,
      );

      outbox.enqueue(
        path: '/api/v1/review/activity/a1/decision',
        payload: const {'decision': 'APPROVE'},
      );

      expect(outbox.pendingCount, 1);

      await outbox.flush();

      expect(sends, 1);
      expect(outbox.pendingCount, 0);
    });

    test('drops item after max attempts', () async {
      var sends = 0;
      final outbox = ReviewDecisionOutbox(
        sender: (path, payload) async {
          sends += 1;
          throw Exception('offline');
        },
        maxAttempts: 2,
        backoffFor: (_) => Duration.zero,
        autoFlushOnEnqueue: false,
      );

      outbox.enqueue(
        path: '/api/v1/review/activity/a2/decision',
        payload: const {'decision': 'REJECT'},
      );

      await outbox.flush();
      expect(outbox.pendingCount, 1);

      await outbox.flush();
      expect(outbox.pendingCount, 0);
      expect(sends, 2);
    });
  });
}
