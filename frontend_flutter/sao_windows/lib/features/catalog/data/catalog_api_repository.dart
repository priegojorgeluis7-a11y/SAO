// lib/features/catalog/data/catalog_api_repository.dart
import 'package:get_it/get_it.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/exceptions.dart';
import '../../../core/utils/logger.dart';
import '../models/catalog_dto.dart';

/// Repository for catalog API operations (Phase 4A)
/// Handles fetching catalog from backend using ApiClient (Phase 3A)
class CatalogApiRepository {
  final ApiClient _apiClient;

  CatalogApiRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? GetIt.instance<ApiClient>();

  /// Fetch the latest published catalog for a project
  /// 
  /// Calls GET /api/v1/catalog/latest?project_id={projectId}
  /// Returns complete catalog package with all 7 entity types
  /// 
  /// [projectId] - Project ID (e.g., "TMQ", "TAP", "TSNL")
  /// 
  /// Throws [NetworkException], [ApiTimeoutException], [ServerException]
  Future<CatalogPackageDTO> fetchLatestCatalog({
    required String projectId,
  }) async {
    try {
      appLogger.i('📦 Fetching latest catalog for project: $projectId');

      final response = await _apiClient.get<dynamic>(
        '/catalog/latest',
        queryParameters: {'project_id': projectId},
      );

      final data = Map<String, dynamic>.from(response.data as Map);

      final catalogPackage = CatalogPackageDTO.fromJson(data);

      appLogger.i(
        '✅ Catalog fetched successfully:\n'
        '  Version: ${catalogPackage.versionNumber} (${catalogPackage.versionId})\n'
        '  Hash: ${catalogPackage.hash.substring(0, 8)}...\n'
        '  Published: ${catalogPackage.publishedAt}\n'
        '  Activity Types: ${catalogPackage.activityTypes.length}\n'
        '  Event Types: ${catalogPackage.eventTypes.length}\n'
        '  Form Fields: ${catalogPackage.formFields.length}\n'
        '  Workflow States: ${catalogPackage.workflowStates.length}\n'
        '  Workflow Transitions: ${catalogPackage.workflowTransitions.length}\n'
        '  Evidence Rules: ${catalogPackage.evidenceRules.length}\n'
        '  Checklist Templates: ${catalogPackage.checklistTemplates.length}',
      );

      // Log activity types summary
      if (catalogPackage.activityTypes.isNotEmpty) {
        appLogger.d('🎯 Activity Types:');
        for (final activityType in catalogPackage.activityTypes
            .where((a) => a.isActive)
            .take(5)) {
          appLogger.d(
            '  - ${activityType.code}: ${activityType.name} '
            '(sort: ${activityType.sortOrder})',
          );
        }
        if (catalogPackage.activityTypes.length > 5) {
          appLogger.d(
            '  ... and ${catalogPackage.activityTypes.length - 5} more',
          );
        }
      }

      // Log event types summary
      if (catalogPackage.eventTypes.isNotEmpty) {
        appLogger.d('📋 Event Types:');
        for (final eventType in catalogPackage.eventTypes
            .where((e) => e.isActive)
            .take(5)) {
          appLogger.d(
            '  - ${eventType.code}: ${eventType.name} '
            '(priority: ${eventType.priority ?? "normal"})',
          );
        }
        if (catalogPackage.eventTypes.length > 5) {
          appLogger.d(
            '  ... and ${catalogPackage.eventTypes.length - 5} more',
          );
        }
      }

      return catalogPackage;
    } on NetworkException catch (e) {
      appLogger.e('❌ Catalog fetch network error: ${e.message}');
      rethrow;
    } on ApiTimeoutException catch (e) {
      appLogger.e('⏱️ Catalog fetch timeout: ${e.message}');
      rethrow;
    } on ServerException catch (e) {
      appLogger.e(
        '🔥 Catalog fetch server error: ${e.message} (${e.statusCode})',
      );
      rethrow;
    } catch (e, stackTrace) {
      appLogger.e(
        '💥 Catalog fetch unknown error',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Check if catalog updates are available
  /// 
  /// Calls GET /api/v1/catalog/check-updates?project_id={projectId}&current_hash={localHash}
  /// Compares local hash with server hash to determine if update is needed
  /// 
  /// [projectId] - Project ID
  /// [localHash] - Current catalog hash stored locally
  /// 
  /// Returns true if update is available, false if catalog is up-to-date
  /// 
  /// Throws [NetworkException], [ApiTimeoutException], [ServerException]
  Future<bool> checkUpdates({
    required String projectId,
    String? localHash,
  }) async {
    try {
      appLogger.i(
        '🔍 Checking catalog updates for project: $projectId\n'
        '  Local hash: ${localHash == null ? "none" : "${localHash.substring(0, 8)}..."}',
      );

      final queryParameters = <String, dynamic>{
        'project_id': projectId,
      };
      if (localHash != null && localHash.isNotEmpty) {
        queryParameters['current_hash'] = localHash;
      }

      final response = await _apiClient.get<dynamic>(
        '/catalog/check-updates',
        queryParameters: queryParameters,
      );

      final data = Map<String, dynamic>.from(response.data as Map);

      final updateAvailable = data['update_available'] as bool;

      if (updateAvailable) {
        final newVersion = data['new_version'] as String?;
        final newHash = data['new_hash'] as String?;
        final publishedAt = data['published_at'] as String?;

        appLogger.i(
          '🆕 Catalog update available!\n'
          '  New version: $newVersion\n'
          '  New hash: ${newHash?.substring(0, 8)}...\n'
          '  Published at: $publishedAt',
        );
      } else {
        final message = data['message'] as String?;
        appLogger.d('✅ Catalog is up-to-date: ${message ?? "No updates"}');
      }

      return updateAvailable;
    } on NetworkException catch (e) {
      appLogger.e('❌ Catalog update check network error: ${e.message}');
      rethrow;
    } on ApiTimeoutException catch (e) {
      appLogger.e('⏱️ Catalog update check timeout: ${e.message}');
      rethrow;
    } on ServerException catch (e) {
      appLogger.e(
        '🔥 Catalog update check server error: ${e.message} (${e.statusCode})',
      );
      rethrow;
    } catch (e, stackTrace) {
      appLogger.e(
        '💥 Catalog update check unknown error',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get catalog metadata (lightweight version info)
  /// Returns basic version info without fetching entire catalog
  Future<CatalogVersionDTO?> getCatalogVersion({
    required String projectId,
  }) async {
    // TODO: Implement in Phase 4B when we have version listing endpoint
    // For now, this is a placeholder
    appLogger.w('getCatalogVersion not yet implemented (Phase 4B)');
    return null;
  }

  /// List all catalog versions for a project
  /// Useful for admin/debug purposes
  Future<List<CatalogVersionDTO>> listCatalogVersions({
    required String projectId,
    String? status,
    int limit = 20,
  }) async {
    // TODO: Implement in Phase 4B for admin features
    // Calls GET /api/v1/catalog/versions
    appLogger.w('listCatalogVersions not yet implemented (Phase 4B)');
    return [];
  }
}
