import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sao_windows/core/sync/pending_sync_services.dart';
import 'package:sao_windows/core/sync/sync_orchestrator.dart';

class _DelayedCatalogRunner implements CatalogSyncRunner {
  int calls = 0;
  final Completer<void> completer = Completer<void>();

  @override
  Future<void> ensureCatalogUpToDate(String projectId) async {
    calls++;
    await completer.future;
  }
}

class _OrderCatalogRunner implements CatalogSyncRunner {
  _OrderCatalogRunner(this.calls);

  final List<String> calls;

  @override
  Future<void> ensureCatalogUpToDate(String projectId) async {
    calls.add('catalog');
  }
}

class _ErrorCatalogRunner implements CatalogSyncRunner {
  @override
  Future<void> ensureCatalogUpToDate(String projectId) async {
    throw Exception('catalog failed');
  }
}

class _FakeActivitySyncService implements ActivitySyncService {
  _FakeActivitySyncService({this.calls, this.counter});

  final List<String>? calls;
  final void Function()? counter;

  @override
  Future<void> syncProject(String projectId) async {
    calls?.add('activity');
    counter?.call();
  }
}

class _FakeAssignmentSyncService implements AssignmentSyncService {
  _FakeAssignmentSyncService({this.calls, this.counter});

  final List<String>? calls;
  final void Function()? counter;

  @override
  Future<void> syncPending() async {
    calls?.add('assignment');
    counter?.call();
  }
}

class _FakeEvidenceSyncService implements EvidenceSyncService {
  _FakeEvidenceSyncService({this.calls, this.counter});

  final List<String>? calls;
  final void Function()? counter;

  @override
  Future<void> syncPending() async {
    calls?.add('evidence');
    counter?.call();
  }
}

void main() {
  group('SyncOrchestrator', () {
    test('no permite syncAll en paralelo', () async {
      final catalog = _DelayedCatalogRunner();
      var activityCalls = 0;
      var assignmentCalls = 0;
      var evidenceCalls = 0;

      final orchestrator = SyncOrchestrator(
        catalogSyncRunner: catalog,
        activitySyncService: _FakeActivitySyncService(counter: () => activityCalls++),
        assignmentSyncService: _FakeAssignmentSyncService(counter: () => assignmentCalls++),
        evidenceSyncService: _FakeEvidenceSyncService(counter: () => evidenceCalls++),
      );

      final first = orchestrator.syncAll(projectId: 'TMQ');
      final second = orchestrator.syncAll(projectId: 'TMQ');

      await Future<void>.delayed(Duration.zero);
      expect(catalog.calls, 1);

      catalog.completer.complete();
      await Future.wait([first, second]);

      expect(catalog.calls, 1);
      expect(activityCalls, 1);
      expect(assignmentCalls, 1);
      expect(evidenceCalls, 1);
    });

    test('syncAll ejecuta en orden catalog -> activity -> assignment -> evidence', () async {
      final calls = <String>[];
      final orchestrator = SyncOrchestrator(
        catalogSyncRunner: _OrderCatalogRunner(calls),
        activitySyncService: _FakeActivitySyncService(calls: calls),
        assignmentSyncService: _FakeAssignmentSyncService(calls: calls),
        evidenceSyncService: _FakeEvidenceSyncService(calls: calls),
      );

      await orchestrator.syncAll(projectId: 'TMQ');

      expect(calls, ['catalog', 'activity', 'assignment', 'evidence']);
      expect(orchestrator.state.status, SyncOrchestratorStatus.success);
    });

    test('cuando falla, deja estado error y no continúa con pendientes', () async {
      var activityCalls = 0;
      var assignmentCalls = 0;
      var evidenceCalls = 0;

      final orchestrator = SyncOrchestrator(
        catalogSyncRunner: _ErrorCatalogRunner(),
        activitySyncService: _FakeActivitySyncService(counter: () => activityCalls++),
        assignmentSyncService: _FakeAssignmentSyncService(counter: () => assignmentCalls++),
        evidenceSyncService: _FakeEvidenceSyncService(counter: () => evidenceCalls++),
      );

      await orchestrator.syncAll(projectId: 'TMQ');

      expect(orchestrator.state.status, SyncOrchestratorStatus.error);
      expect(orchestrator.state.errorMessage, contains('catalog failed'));
      expect(activityCalls, 0);
      expect(assignmentCalls, 0);
      expect(evidenceCalls, 0);
    });
  });
}
