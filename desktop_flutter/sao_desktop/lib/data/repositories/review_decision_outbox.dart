import 'dart:async';

import 'backend_api_client.dart';

typedef ReviewDecisionSender = Future<void> Function(
  String path,
  Map<String, dynamic> payload,
);

class ReviewDecisionOutbox {
  ReviewDecisionOutbox({
    ReviewDecisionSender? sender,
    Duration retryInterval = const Duration(seconds: 12),
    int maxAttempts = 5,
    Duration Function(int attempts)? backoffFor,
    bool autoFlushOnEnqueue = true,
  })  : _sender = sender ?? _defaultSender,
        _retryInterval = retryInterval,
        _maxAttempts = maxAttempts,
        _backoffFor = backoffFor ?? _defaultBackoff,
        _autoFlushOnEnqueue = autoFlushOnEnqueue;

  static final ReviewDecisionOutbox shared = ReviewDecisionOutbox();

  static Future<void> _defaultSender(
    String path,
    Map<String, dynamic> payload,
  ) async {
    await const BackendApiClient().postJson(path, payload);
  }

  static Duration _defaultBackoff(int attempts) {
    final seconds = (attempts * attempts * 4).clamp(4, 90);
    return Duration(seconds: seconds);
  }

  final ReviewDecisionSender _sender;
  final Duration _retryInterval;
  final int _maxAttempts;
  final Duration Function(int attempts) _backoffFor;
  final bool _autoFlushOnEnqueue;

  final List<_QueuedDecision> _queue = <_QueuedDecision>[];

  Timer? _retryTimer;
  bool _isFlushing = false;

  int get pendingCount => _queue.length;

  void enqueue({
    required String path,
    required Map<String, dynamic> payload,
  }) {
    _queue.add(
      _QueuedDecision(
        path: path,
        payload: payload,
        enqueuedAt: DateTime.now(),
      ),
    );
    _ensureRetryTimer();
    if (_autoFlushOnEnqueue) {
      unawaited(flush());
    }
  }

  Future<void> flush() async {
    if (_isFlushing || _queue.isEmpty) {
      if (_queue.isEmpty) {
        _stopRetryTimer();
      }
      return;
    }

    _isFlushing = true;
    try {
      var index = 0;
      while (index < _queue.length) {
        final item = _queue[index];
        final now = DateTime.now();

        if (item.nextAttemptAt != null && now.isBefore(item.nextAttemptAt!)) {
          index++;
          continue;
        }

        try {
          await _sender(item.path, item.payload);
          _queue.removeAt(index);
          continue;
        } catch (_) {
          item.attempts += 1;
          if (item.attempts >= _maxAttempts) {
            _queue.removeAt(index);
            continue;
          }
          item.nextAttemptAt = now.add(_backoffFor(item.attempts));
          index++;
        }
      }
    } finally {
      _isFlushing = false;
      if (_queue.isEmpty) {
        _stopRetryTimer();
      } else {
        _ensureRetryTimer();
      }
    }
  }

  void _ensureRetryTimer() {
    _retryTimer ??= Timer.periodic(_retryInterval, (_) {
      unawaited(flush());
    });
  }

  void _stopRetryTimer() {
    _retryTimer?.cancel();
    _retryTimer = null;
  }
}

class _QueuedDecision {
  _QueuedDecision({
    required this.path,
    required this.payload,
    required this.enqueuedAt,
  });

  final String path;
  final Map<String, dynamic> payload;
  final DateTime enqueuedAt;

  int attempts = 0;
  DateTime? nextAttemptAt;
}
