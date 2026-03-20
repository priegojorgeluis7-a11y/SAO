import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../catalog/state/catalog_providers.dart';
import '../catalog/sync/catalog_sync_service.dart';
import 'pending_sync_services.dart';

enum SyncOrchestratorStatus { idle, syncing, success, error }

class SyncOrchestratorState {
  const SyncOrchestratorState({
    required this.status,
    this.errorMessage,
    this.updatedAt,
  });

  final SyncOrchestratorStatus status;
  final String? errorMessage;
  final DateTime? updatedAt;

  bool get isSyncing => status == SyncOrchestratorStatus.syncing;

  SyncOrchestratorState copyWith({
    SyncOrchestratorStatus? status,
    String? errorMessage,
    DateTime? updatedAt,
  }) {
    return SyncOrchestratorState(
      status: status ?? this.status,
      errorMessage: errorMessage,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

abstract class CatalogSyncRunner {
  Future<void> ensureCatalogUpToDate(String projectId);
}

class CatalogSyncRunnerImpl implements CatalogSyncRunner {
  CatalogSyncRunnerImpl(this._service);

  final CatalogSyncService _service;

  @override
  Future<void> ensureCatalogUpToDate(String projectId) {
    return _service.ensureCatalogUpToDate(projectId);
  }
}

class SyncOrchestrator extends StateNotifier<SyncOrchestratorState> {
  SyncOrchestrator({
    required CatalogSyncRunner catalogSyncRunner,
    required ActivitySyncService activitySyncService,
    required AssignmentSyncService assignmentSyncService,
    required EvidenceSyncService evidenceSyncService,
  })  : _catalogSyncRunner = catalogSyncRunner,
        _activitySyncService = activitySyncService,
        _assignmentSyncService = assignmentSyncService,
        _evidenceSyncService = evidenceSyncService,
        super(const SyncOrchestratorState(status: SyncOrchestratorStatus.idle));

  final CatalogSyncRunner _catalogSyncRunner;
  final ActivitySyncService _activitySyncService;
  final AssignmentSyncService _assignmentSyncService;
  final EvidenceSyncService _evidenceSyncService;

  bool _isSyncing = false;

  Future<void> syncAll({required String projectId}) async {
    if (_isSyncing) return;
    _isSyncing = true;
    state = const SyncOrchestratorState(status: SyncOrchestratorStatus.syncing);

    try {
      try {
        await _catalogSyncRunner.ensureCatalogUpToDate(projectId);
      } catch (e) {
        if (!_isOptionalCatalogError(e)) {
          rethrow;
        }
      }
      await _activitySyncService.syncProject(projectId);
      await _assignmentSyncService.syncPending();
      await _evidenceSyncService.syncPending();

      state = SyncOrchestratorState(
        status: SyncOrchestratorStatus.success,
        updatedAt: DateTime.now(),
      );
    } catch (e) {
      state = SyncOrchestratorState(
        status: SyncOrchestratorStatus.error,
        errorMessage: _formatSyncError(e),
        updatedAt: DateTime.now(),
      );
    } finally {
      _isSyncing = false;
    }
  }

  bool _isOptionalCatalogError(Object error) {
    if (error is! DioException) {
      return false;
    }
    final statusCode = error.response?.statusCode;
    return statusCode == 403 || statusCode == 404;
  }

  String _formatSyncError(Object error) {
    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      final path = error.requestOptions.path;
      final detail = _extractBackendDetail(error.response?.data);

      if (statusCode == 403) {
        return detail?.isNotEmpty == true
            ? 'HTTP 403 en $path: $detail'
            : 'HTTP 403 en $path: el usuario no tiene permiso para esta operacion.';
      }

      if (statusCode != null) {
        return detail?.isNotEmpty == true
            ? 'HTTP $statusCode en $path: $detail'
            : 'HTTP $statusCode en $path durante la sincronizacion.';
      }

      return 'No fue posible sincronizar por un error de red.';
    }

    final text = error.toString().trim();
    if (text.isEmpty) {
      return 'No fue posible sincronizar. Intenta nuevamente.';
    }
    return text;
  }

  String? _extractBackendDetail(dynamic data) {
    if (data is Map<String, dynamic>) {
      final detail = data['detail'];
      if (detail is String && detail.trim().isNotEmpty) {
        return detail.trim();
      }
      if (detail is List && detail.isNotEmpty) {
        final messages = detail
            .map((item) {
              if (item is Map<String, dynamic> && item['msg'] != null) {
                return item['msg'].toString();
              }
              return item.toString();
            })
            .where((msg) => msg.trim().isNotEmpty)
            .join('; ');
        if (messages.isNotEmpty) {
          return messages;
        }
      }

      final message = data['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
    }

    if (data is String && data.trim().isNotEmpty) {
      return data.trim();
    }

    return null;
  }
}

final syncOrchestratorProvider =
    StateNotifierProvider<SyncOrchestrator, SyncOrchestratorState>((ref) {
  return SyncOrchestrator(
    catalogSyncRunner: CatalogSyncRunnerImpl(ref.read(catalogSyncServiceProvider)),
    activitySyncService: ref.read(activitySyncServiceProvider),
    assignmentSyncService: ref.read(assignmentSyncServiceProvider),
    evidenceSyncService: ref.read(evidenceSyncServiceProvider),
  );
});