// lib/features/catalog/application/catalog_sync_service.dart
import '../../../core/utils/logger.dart';
import '../data/catalog_api_repository.dart';
import '../data/catalog_local_repository.dart';

/// Service for syncing catalog from API to local Drift DB.
/// Phase 4C: Orchestrates check-update-persist flow.
class CatalogSyncService {
  final CatalogApiRepository _apiRepo = CatalogApiRepository();
  final CatalogLocalRepository _localRepo = CatalogLocalRepository();

  /// Sync catalog for a project: check for updates, fetch if needed, persist.
  /// Returns a CatalogSyncResult with status and details.
  Future<CatalogSyncResult> syncCatalog(String projectId) async {
    final startTime = DateTime.now();
    appLogger.i('🔄 Starting catalog sync for project: $projectId');
    String? localVersionNumber;

    try {
      // 1) Read current local catalog hash/version from Drift
      final currentVersion = await _localRepo.getCurrentCatalogVersion(
        projectId: projectId,
      );

      final localHash = currentVersion?.checksum;
      localVersionNumber = currentVersion?.versionNumber.toString();

      appLogger.i('📚 Local catalog: version=$localVersionNumber, '
          'hash=${localHash?.substring(0, 8) ?? "none"}');

      // 2) Call checkUpdates; if no update -> log and return
      final hasUpdate = await _apiRepo.checkUpdates(
        projectId: projectId,
        localHash: localHash,
      );

      if (!hasUpdate) {
        appLogger.i('✅ Catalog is up-to-date, no sync needed');
        return CatalogSyncResult(
          status: CatalogSyncStatus.noChanges,
          localVersion: localVersionNumber,
          message: 'Catalog already up-to-date',
        );
      }

      appLogger.i('📥 Update available, fetching latest catalog...');

      // 3) fetchLatestCatalog
      final catalogPackage = await _apiRepo.fetchLatestCatalog(
        projectId: projectId,
      );

      appLogger.i('📦 Fetched catalog v${catalogPackage.versionNumber}, '
          'hash=${catalogPackage.hash.substring(0, 8)}...');

      // 4) Persist to Drift using catalog_local_repository.saveCatalogPackage
      await _localRepo.saveCatalogPackage(catalogPackage, projectId: projectId);

      // 5) Note: CatalogVersions table doesn't have last_applied_at column yet.
      // If/when added, update it here with: DateTime.now()

      final duration = DateTime.now().difference(startTime);
      appLogger.i('✅ Catalog sync completed in ${duration.inMilliseconds}ms');

      return CatalogSyncResult(
        status: CatalogSyncStatus.updated,
        localVersion: localVersionNumber,
        newVersion: catalogPackage.versionNumber,
        newHash: catalogPackage.hash,
        activityTypeCount: catalogPackage.activityTypes.length,
        formFieldCount: catalogPackage.formFields.length,
        message: 'Catalog updated successfully',
        durationMs: duration.inMilliseconds,
      );
    } catch (e, stack) {
      appLogger.e('❌ Catalog sync failed', error: e, stackTrace: stack);
      return CatalogSyncResult(
        status: CatalogSyncStatus.error,
        localVersion: localVersionNumber,
        message: 'Sync failed: $e',
      );
    }
  }

  /// Force fetch and save catalog, bypassing update check (for debugging).
  Future<CatalogSyncResult> forceSyncCatalog(String projectId) async {
    final startTime = DateTime.now();
    appLogger.i('🔄 Force syncing catalog for project: $projectId');
    String? localVersionNumber;

    try {
      final currentVersion = await _localRepo.getCurrentCatalogVersion(
        projectId: projectId,
      );

      localVersionNumber = currentVersion?.versionNumber.toString();

      // Fetch latest catalog directly
      final catalogPackage = await _apiRepo.fetchLatestCatalog(
        projectId: projectId,
      );

      appLogger.i('📦 Force fetched catalog v${catalogPackage.versionNumber}');

      // Persist to Drift
      await _localRepo.saveCatalogPackage(catalogPackage, projectId: projectId);

      final duration = DateTime.now().difference(startTime);
      appLogger.i('✅ Force sync completed in ${duration.inMilliseconds}ms');

      return CatalogSyncResult(
        status: CatalogSyncStatus.updated,
        localVersion: localVersionNumber,
        newVersion: catalogPackage.versionNumber,
        newHash: catalogPackage.hash,
        activityTypeCount: catalogPackage.activityTypes.length,
        formFieldCount: catalogPackage.formFields.length,
        message: 'Catalog force-synced successfully',
        durationMs: duration.inMilliseconds,
      );
    } catch (e, stack) {
      appLogger.e('❌ Force sync failed', error: e, stackTrace: stack);
      return CatalogSyncResult(
        status: CatalogSyncStatus.error,
        localVersion: localVersionNumber,
        message: 'Force sync failed: $e',
      );
    }
  }
}

/// Result of a catalog sync operation.
class CatalogSyncResult {
  final CatalogSyncStatus status;
  final String? localVersion;
  final String? newVersion;
  final String? newHash;
  final int? activityTypeCount;
  final int? formFieldCount;
  final String message;
  final int? durationMs;

  CatalogSyncResult({
    required this.status,
    this.localVersion,
    this.newVersion,
    this.newHash,
    this.activityTypeCount,
    this.formFieldCount,
    required this.message,
    this.durationMs,
  });

  bool get isSuccess => status == CatalogSyncStatus.updated || status == CatalogSyncStatus.noChanges;
  bool get hasChanges => status == CatalogSyncStatus.updated;
}

/// Status of catalog sync operation.
enum CatalogSyncStatus {
  updated,    // New version downloaded and saved
  noChanges,  // Catalog is already up-to-date
  error,      // Sync failed
}
