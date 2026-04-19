// lib/features/sync/data/sync_repository.dart
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../../core/di/service_locator.dart';
import '../../../data/local/app_db.dart';
import '../models/sync_models.dart';
import '../services/sync_service.dart';

/// Repositorio para gestionar sincronización y cola de subida
class SyncRepository {
  final AppDb _db;

  SyncRepository(this._db);

  // =================== Health Status ===================

  /// Stream de estado global de sincronización
  Stream<SyncHealth> watchSyncHealth() {
    return _db.select(_db.syncQueue).watch().map((queueItems) {
      final pending = queueItems.where((i) => i.status == 'PENDING').length;
      final syncing = queueItems.where((i) => i.status == 'IN_PROGRESS').length;
      final errors = queueItems.where((i) => i.status == 'ERROR').length;

      // Determinar estado
      SyncHealthStatus status;
      String message;

      if (errors > 0) {
        status = SyncHealthStatus.error;
        message = 'Error en $errors elemento${errors > 1 ? 's' : ''}';
      } else if (syncing > 0) {
        status = SyncHealthStatus.syncing;
        message = 'Sincronizando $syncing elemento${syncing > 1 ? 's' : ''}...';
      } else if (pending > 0) {
        status = SyncHealthStatus.syncing;
        message = '$pending pendiente${pending > 1 ? 's' : ''} de subir';
      } else {
        status = SyncHealthStatus.allSynced;
        message = 'Todo al día';
      }

      return SyncHealth(
        status: status,
        message: message,
        pendingCount: pending,
        syncingCount: syncing,
        errorCount: errors,
      );
    });
  }

  /// Obtiene última sincronización desde SyncState
  Future<DateTime?> getLastSyncTime() async {
    final state = await (_db.select(_db.syncState)
          ..where((s) => s.id.equals(1)))
        .getSingleOrNull();
    return state?.lastSyncAt;
  }

  // =================== Upload Queue ===================

  /// Stream de items en la cola de subida
  Stream<List<UploadQueueItem>> watchUploadQueue() {
    return (_db.select(_db.syncQueue)
          ..where((s) => s.status.isNotIn(['DONE']))
          ..orderBy([(s) => OrderingTerm.desc(s.priority)]))
        .watch()
        .map((rows) => rows.map(_mapToUploadItem).toList());
  }

  /// Reintentar un ítem específico
  Future<void> retryItem(String itemId) async {
    await (_db.update(_db.syncQueue)
          ..where((s) => s.id.equals(itemId)))
        .write(SyncQueueCompanion(
      status: const Value('PENDING'),
      attempts: const Value(0),
      lastError: const Value(null),
      priority: Value(
        DateTime.now()
            .millisecondsSinceEpoch, // Mayor prioridad por ser manual
      ),
    ));
  }

  /// Eliminar un ítem completado o con error irrecuperable
  Future<void> deleteItem(String itemId) async {
    await (_db.delete(_db.syncQueue)..where((s) => s.id.equals(itemId))).go();
  }

  Future<SyncQueueData?> getQueueItem(String itemId) {
    return (_db.select(_db.syncQueue)..where((s) => s.id.equals(itemId)))
        .getSingleOrNull();
  }

  Future<void> markDone(String itemId) async {
    await (_db.update(_db.syncQueue)..where((s) => s.id.equals(itemId))).write(
          SyncQueueCompanion(
            status: const Value('DONE'),
            lastError: const Value(null),
            lastAttemptAt: Value(DateTime.now()),
          ),
        );
  }

  // =================== Manual Sync ===================

  /// Forzar sincronización inmediata
  Future<void> forceSyncNow() async {
    // Resetear todos los pendientes a prioridad alta
    final pendingItems = await (_db.select(_db.syncQueue)
          ..where((s) => s.status.equals('PENDING')))
        .get();

    for (final item in pendingItems) {
      await (_db.update(_db.syncQueue)
            ..where((s) => s.id.equals(item.id)))
          .write(SyncQueueCompanion(
        priority: Value(
          DateTime.now().millisecondsSinceEpoch,
        ),
      ));
    }

    if (getIt.isRegistered<SyncService>()) {
      await getIt<SyncService>().pushPendingChanges();
    }
  }

  /// Actualizar último timestamp de sincronización
  Future<void> updateLastSyncTime(DateTime time) async {
    await (_db.update(_db.syncState)..where((s) => s.id.equals(1)))
        .write(SyncStateCompanion(
      lastSyncAt: Value(time),
    ));
  }

  // =================== Storage Management ===================

  /// Obtener uso de almacenamiento de la base local y archivos pendientes.
  Future<(int usedMb, int availableMb)> getStorageUsage() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dbFile = File(p.join(docsDir.path, 'sigef_local.sqlite'));

    var totalBytes = 0;
    if (dbFile.existsSync()) {
      totalBytes += dbFile.lengthSync();
    }

    final pendingUploads = await _db.select(_db.pendingUploads).get();
    final visitedPaths = <String>{};
    for (final upload in pendingUploads) {
      final path = upload.localPath.trim();
      if (path.isEmpty || visitedPaths.contains(path)) continue;
      visitedPaths.add(path);
      final file = File(path);
      if (file.existsSync()) {
        totalBytes += file.lengthSync();
      }
    }

    final usedMb = (totalBytes / (1024 * 1024)).ceil();
    final availableMb = usedMb >= 2048 ? 0 : 2048 - usedMb;
    return (usedMb, availableMb);
  }

  /// Limpiar elementos completados hace más de X días
  Future<int> cleanCompletedOlderThan(Duration duration) async {
    final threshold = DateTime.now().subtract(duration);

    final query = _db.delete(_db.syncQueue)
      ..where((s) =>
          s.status.equals('DONE') & s.lastAttemptAt.isSmallerThanValue(threshold));

    return query.go();
  }

  // =================== Helpers ===================

  UploadQueueItem _mapToUploadItem(SyncQueueData row) {
    // Mapear tipo
    UploadItemType type;
    switch (row.entity.toUpperCase()) {
      case 'ACTIVITY':
        type = UploadItemType.activity;
        break;
      case 'EVENT':
        type = UploadItemType.event;
        break;
      case 'EVIDENCE':
        type = UploadItemType.evidence;
        break;
      default:
        type = UploadItemType.activity;
    }

    // Mapear estado
    UploadItemStatus status;
    switch (row.status.toUpperCase()) {
      case 'PENDING':
        status = UploadItemStatus.pending;
        break;
      case 'IN_PROGRESS':
        status = UploadItemStatus.uploading;
        break;
      case 'ERROR':
        status = UploadItemStatus.error;
        break;
      default:
        status = UploadItemStatus.pending;
    }

    // Generar título y subtítulo desde payload (simplificado)
    final title = _extractTitle(row.entity, row.entityId);
    final subtitle = row.lastAttemptAt != null
        ? _formatTimestamp(row.lastAttemptAt)
        : 'Pendiente de sincronizar';
    final retryable = _resolveRetryable(row);
    final suggestedAction = _resolveSuggestedAction(row);
    final cleanError = _cleanErrorMessage(row.lastError);

    return UploadQueueItem(
      id: row.id,
      entityId: row.entityId,
      entity: row.entity,
      type: type,
      title: title,
      subtitle: subtitle,
      status: status,
      progress: status == UploadItemStatus.uploading ? 0.5 : null,
      errorMessage: cleanError,
      retryable: retryable,
      suggestedAction: suggestedAction,
      retryCount: row.attempts,
      createdAt: row.lastAttemptAt ?? DateTime.now(),
    );
  }

  bool _isRetryableError(String? rawError) {
    final error = rawError?.toUpperCase() ?? '';
    if (error.contains('[RETRYABLE]')) return true;
    if (error.contains('[NON_RETRYABLE]')) return false;
    return false;
  }

  bool _resolveRetryable(SyncQueueData row) {
    final inferred = _isRetryableError(row.lastError);
    return inferred || row.retryable;
  }

  String? _resolveSuggestedAction(SyncQueueData row) {
    final raw = row.suggestedAction ?? _extractSuggestedAction(row.lastError);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    return _humanizeSuggestedAction(raw.trim());
  }

  String _humanizeSuggestedAction(String action) {
    switch (action.toUpperCase()) {
      case 'RETRY_AUTOMATIC':
        return 'Reintentar automaticamente';
      case 'PULL_AND_RESOLVE_CONFLICT':
        return 'Actualizar desde servidor y resolver conflicto';
      case 'FIX_PROJECT_CONTEXT':
        return 'Verificar proyecto activo antes de reenviar';
      case 'REFRESH_CATALOG_AND_RETRY':
        return 'Actualizar catalogo y volver a intentar';
      case 'REVIEW_PAYLOAD':
        return 'Revisar datos capturados antes de reenviar';
      default:
        return action;
    }
  }

  String? _extractSuggestedAction(String? rawError) {
    final error = rawError?.trim();
    if (error == null || error.isEmpty) return null;
    const marker = '| accion sugerida:';
    final lower = error.toLowerCase();
    final idx = lower.indexOf(marker);
    if (idx == -1) return null;
    final value = error.substring(idx + marker.length).trim();
    return value.isEmpty ? null : value;
  }

  String? _cleanErrorMessage(String? rawError) {
    final error = rawError?.trim();
    if (error == null || error.isEmpty) return null;
    final markerIdx = error.toLowerCase().indexOf('| accion sugerida:');
    final base = markerIdx == -1 ? error : error.substring(0, markerIdx).trim();
    final withoutRetryable = base.replaceAll('[retryable]', '').replaceAll('[RETRYABLE]', '').trim();
    return withoutRetryable.isEmpty ? null : withoutRetryable;
  }

  String _extractTitle(String entity, String entityId) {
    final shortId = entityId.length <= 8 ? entityId : entityId.substring(0, 8);
    switch (entity.toUpperCase()) {
      case 'ACTIVITY':
        return 'Actividad #$shortId';
      case 'EVENT':
        return 'Incidencia #$shortId';
      case 'EVIDENCE':
        return 'Evidencia fotográfica';
      default:
        return 'Ítem #$shortId';
    }
  }

  String _formatTimestamp(DateTime? dt) {
    if (dt == null) return 'Sin fecha';

    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Hace un momento';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours}h';
    return '${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
