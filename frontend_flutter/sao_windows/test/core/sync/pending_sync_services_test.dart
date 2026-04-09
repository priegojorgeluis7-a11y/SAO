import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sao_windows/core/sync/pending_sync_services.dart';
import 'package:sao_windows/features/sync/services/sync_service.dart';

class _FakeRunner implements ActivitySyncRunner {
  _FakeRunner({
    this.pushError,
    this.pullError,
    this.failPullOnce = false,
    this.pullResult,
  });

  final Object? pushError;
  final Object? pullError;
  final bool failPullOnce;
  final PullSyncResult? pullResult;
  bool _pullFailed = false;
  final List<String> calls = <String>[];

  @override
  Future<SyncResult> pushPendingChanges({
    bool forceOverride = false,
    Set<String>? queueItemIds,
  }) async {
    calls.add('push');
    if (pushError != null) throw pushError!;
    return SyncResult.empty();
  }

  @override
  Future<PullSyncResult> pullChanges({
    required String projectId,
    int pageSize = 200,
    bool resetActivityCursor = false,
  }) async {
    calls.add('pull:$projectId:$resetActivityCursor');
    if (pullError != null && (!failPullOnce || !_pullFailed)) {
      _pullFailed = true;
      throw pullError!;
    }
    return pullResult ??
        PullSyncResult(
          pulled: 1,
          pages: 1,
          currentVersion: 1,
          pulledEvents: 0,
          eventPages: 0,
          currentEventVersion: 0,
          completedAt: DateTime.now(),
        );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ActivitySyncServiceImpl', () {
    test('continues with pull even when push fails', () async {
      final runner = _FakeRunner(pushError: Exception('push failed'));
      final service = ActivitySyncServiceImpl(runner);

      await service.syncProject('TMQ');

      expect(runner.calls, ['push', 'pull:TMQ:false']);
    });

    test('continues with pull on 403 push errors', () async {
      final runner = _FakeRunner(
        pushError: DioException(
          requestOptions: RequestOptions(path: '/sync/push'),
          response: Response(
            requestOptions: RequestOptions(path: '/sync/push'),
            statusCode: 403,
          ),
        ),
      );
      final service = ActivitySyncServiceImpl(runner);

      await service.syncProject('TMQ');

      expect(runner.calls, ['push', 'pull:TMQ:false']);
    });

    test('retries pull with reset cursor after 422 errors', () async {
      final runner = _FakeRunner(
        pullError: DioException(
          requestOptions: RequestOptions(path: '/sync/pull'),
          response: Response(
            requestOptions: RequestOptions(path: '/sync/pull'),
            statusCode: 422,
          ),
        ),
        failPullOnce: true,
      );
      final service = ActivitySyncServiceImpl(runner);

      await service.syncProject('TMQ');

      expect(runner.calls, ['push', 'pull:TMQ:false', 'pull:TMQ:true']);
    });

    test('forces a full pull when cursor version is ahead of local cache', () async {
      final runner = _FakeRunner(
        pullResult: PullSyncResult(
          pulled: 0,
          pages: 1,
          currentVersion: 16,
          pulledEvents: 0,
          eventPages: 0,
          currentEventVersion: 0,
          completedAt: DateTime.now(),
        ),
      );
      final service = ActivitySyncServiceImpl(
        runner,
        shouldRecoverCursorGap: ({
          required String projectId,
          required int currentVersion,
          required int pulled,
        }) async =>
            projectId == 'TMQ' && currentVersion == 16 && pulled == 0,
      );

      await service.syncProject('TMQ');

      expect(runner.calls, ['push', 'pull:TMQ:false', 'pull:TMQ:true']);
    });
  });
}
