// Mapper centralizado para estados de sincronización.
// 
// Define la correspondencia entre:
// - Backend values: Los valores que retorna la API (strings)
// - Frontend enum: Los estados del UI (SyncStatus enum)
// 
// Backend VALID_SYNC_STATES:
// - "LOCAL_ONLY"          → No enviado, nunca sincronizado
// - "READY_TO_SYNC"       → Cambios locales listos para subir
// - "SYNC_IN_PROGRESS"    → Subida en marcha
// - "SYNCED"              → Última versión en servidor
// - "SYNC_ERROR"          → Error en último intento de sincronización

import '../../../features/agenda/models/agenda_item.dart';

/// Valores de sincronización del Backend (VALID_SYNC_STATES)
abstract class BackendSyncStates {
  static const String localOnly = 'LOCAL_ONLY';
  static const String readyToSync = 'READY_TO_SYNC';
  static const String syncInProgress = 'SYNC_IN_PROGRESS';
  static const String synced = 'SYNCED';
  static const String syncError = 'SYNC_ERROR';

  /// Todos los valores válidos del backend
  static const List<String> allValues = [
    localOnly,
    readyToSync,
    syncInProgress,
    synced,
    syncError,
  ];

  /// Verifica si un valor es válido
  static bool isValid(String? value) => allValues.contains(value?.toUpperCase());
}

/// Mapper entre valores de Backend y enum de Frontend
class SyncStatusMapper {
  /// Converts Backend string value to Frontend SyncStatus enum
  /// 
  /// Mapping:
  /// - "LOCAL_ONLY", "READY_TO_SYNC" → SyncStatus.pending
  /// - "SYNC_IN_PROGRESS" → SyncStatus.uploading
  /// - "SYNCED" → SyncStatus.synced
  /// - "SYNC_ERROR" → SyncStatus.error
  /// - null, invalid → SyncStatus.pending (fallback seguro)
  static SyncStatus fromBackend(String? backendValue) {
    final normalized = backendValue?.trim().toUpperCase() ?? '';
    
    switch (normalized) {
      case BackendSyncStates.syncInProgress:
        return SyncStatus.uploading;
      case BackendSyncStates.synced:
        return SyncStatus.synced;
      case BackendSyncStates.syncError:
        return SyncStatus.error;
      case BackendSyncStates.localOnly:
      case BackendSyncStates.readyToSync:
      default:
        return SyncStatus.pending;
    }
  }

  /// Converts Frontend SyncStatus enum to Backend string value (si es necesario)
  /// 
  /// Inverse mapping (usado cuando hacemos push):
  /// - SyncStatus.pending → "READY_TO_SYNC" (será subido)
  /// - SyncStatus.uploading → "SYNC_IN_PROGRESS"
  /// - SyncStatus.synced → "SYNCED"
  /// - SyncStatus.error → "SYNC_ERROR"
  static String toBackend(SyncStatus frontendStatus) {
    switch (frontendStatus) {
      case SyncStatus.pending:
        return BackendSyncStates.readyToSync;
      case SyncStatus.uploading:
        return BackendSyncStates.syncInProgress;
      case SyncStatus.synced:
        return BackendSyncStates.synced;
      case SyncStatus.error:
        return BackendSyncStates.syncError;
    }
  }

  /// Descripción amigable para el usuario
  static String humanReadable(SyncStatus status) {
    switch (status) {
      case SyncStatus.pending:
        return 'Pendiente de sincronizar';
      case SyncStatus.uploading:
        return 'Sincronizando...';
      case SyncStatus.synced:
        return 'Sincronizado';
      case SyncStatus.error:
        return 'Error de sincronización';
    }
  }

  /// Ícono para mostrar en UI (emoji o icon)
  static String icon(SyncStatus status) {
    switch (status) {
      case SyncStatus.pending:
        return '⏱️'; // reloj
      case SyncStatus.uploading:
        return '📤'; // subiendo
      case SyncStatus.synced:
        return '✅'; // checkmark
      case SyncStatus.error:
        return '❌'; // error
    }
  }
}
