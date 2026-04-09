/// Modelos para el Centro de Sincronización
library;

import 'package:flutter/material.dart';
import '../../../ui/theme/sao_colors.dart';

enum SyncHealthStatus {
  allSynced, // 🟢 Todo sincronizado
  hasPending, // 🟡 Hay elementos pendientes de subir
  syncing, // 🔵 Sincronizando...
  error, // 🔴 Error / Sin conexión
}

class SyncHealth {
  final SyncHealthStatus status;
  final String message;
  final DateTime? lastSyncAt;
  final int pendingCount;
  final int syncingCount;
  final int errorCount;

  const SyncHealth({
    required this.status,
    required this.message,
    this.lastSyncAt,
    this.pendingCount = 0,
    this.syncingCount = 0,
    this.errorCount = 0,
  });

  bool get hasErrors => errorCount > 0;
  bool get hasPending => pendingCount > 0 || syncingCount > 0;
  bool get isHealthy => status == SyncHealthStatus.allSynced;
}

enum UploadItemType {
  activity,
  event,
  evidence,
}

class UploadQueueItem {
  final String id;
  final String entityId;
  final String entity;
  final UploadItemType type;
  final String title;
  final String subtitle;
  final UploadItemStatus status;
  final double? progress; // 0.0 a 1.0 para uploading
  final String? errorMessage;
  final bool retryable;
  final String? suggestedAction;
  final int retryCount;
  final DateTime createdAt;

  const UploadQueueItem({
    required this.id,
    required this.entityId,
    required this.entity,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.status,
    this.progress,
    this.errorMessage,
    this.retryable = true,
    this.suggestedAction,
    this.retryCount = 0,
    required this.createdAt,
  });

  bool get isConflict =>
      status == UploadItemStatus.error &&
      (errorMessage?.toUpperCase().contains('CONFLICT') ?? false);

  IconData get icon {
    switch (type) {
      case UploadItemType.activity:
        return Icons.assignment_rounded;
      case UploadItemType.event:
        return Icons.warning_rounded;
      case UploadItemType.evidence:
        return Icons.photo_camera_rounded;
    }
  }

  Color get color {
    switch (type) {
      case UploadItemType.activity:
        return SaoColors.info;
      case UploadItemType.event:
        return SaoColors.warning;
      case UploadItemType.evidence:
        return SaoColors.success;
    }
  }
}

enum UploadItemStatus {
  pending, // Esperando red
  uploading, // Subiendo...
  error, // Error (reintentable)
}

enum DownloadResourceType {
  catalogo, // Catálogo de conceptos
}

class DownloadResource {
  final DownloadResourceType type;
  final String name;
  final int sizeMb;
  final DownloadResourceStatus status;
  final double? progress; // 0.0 a 1.0
  final DateTime? lastUpdatedAt;

  const DownloadResource({
    required this.type,
    required this.name,
    required this.sizeMb,
    required this.status,
    this.progress,
    this.lastUpdatedAt,
  });

  IconData get icon {
    switch (type) {
      case DownloadResourceType.catalogo:
        return Icons.list_alt_rounded;
    }
  }

  String get statusLabel {
    switch (status) {
      case DownloadResourceStatus.upToDate:
        return 'Al día';
      case DownloadResourceStatus.downloading:
        return 'Descargando...';
      case DownloadResourceStatus.pending:
        return 'Pendiente';
      case DownloadResourceStatus.error:
        return 'Error';
    }
  }
}

enum DownloadResourceStatus {
  upToDate,
  downloading,
  pending,
  error,
}

class SyncConfig {
  final bool wifiOnly;
  final int usedSpaceMb;
  final int availableSpaceMb;

  const SyncConfig({
    required this.wifiOnly,
    required this.usedSpaceMb,
    required this.availableSpaceMb,
  });

  double get usagePercentage => usedSpaceMb / (usedSpaceMb + availableSpaceMb);

  String get usageText => '$usedSpaceMb MB / ${usedSpaceMb + availableSpaceMb} MB';
}
