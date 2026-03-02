// lib/features/catalog/data/catalog_local_repository.dart
import 'dart:convert';
import 'package:drift/drift.dart';
import '../../../core/utils/logger.dart';
import '../../../data/local/app_db.dart';
import '../../../data/local/db_instance.dart';
import '../models/catalog_dto.dart';

/// Repository for persisting catalog data into Drift DB.
/// Phase 4B: Local persistence with transactions.
class CatalogLocalRepository {
  final AppDb _db = appDb;

  int _toVersionInt(String value) {
    final numeric = RegExp(r'\d+').stringMatch(value);
    return int.tryParse(numeric ?? '') ?? 1;
  }

  /// Get the current catalog version for a project (or global if projectId is null).
  /// Returns null if no catalog exists.
  Future<CatalogVersion?> getCurrentCatalogVersion({String? projectId}) async {
    try {
      final query = _db.select(_db.catalogVersions)
        ..orderBy([(t) => OrderingTerm.desc(t.versionNumber)])
        ..limit(1);

      if (projectId != null) {
        query.where((t) => t.projectId.equals(projectId));
      } else {
        query.where((t) => t.projectId.isNull());
      }

      final result = await query.getSingleOrNull();
      appLogger.i('📚 Current catalog version: ${result?.versionNumber ?? "none"} '
          '(checksum: ${result?.checksum?.substring(0, 8) ?? "n/a"})');
      return result;
    } catch (e, stack) {
      appLogger.e('❌ Error fetching current catalog version', error: e, stackTrace: stack);
      return null;
    }
  }

  /// Save a complete catalog package to the database.
  /// Uses a transaction to ensure atomicity.
  /// 
  /// Strategy:
  /// 1. Upsert CatalogVersions record
  /// 2. Delete old CatalogActivityTypes for this catalog version (if re-importing)
  /// 3. Batch insert CatalogActivityTypes
  /// 4. Delete old CatalogFields for this catalog version
  /// 5. Batch insert CatalogFields
  Future<void> saveCatalogPackage(
    CatalogPackageDTO package, {
    String? projectId,
  }) async {
    final startTime = DateTime.now();
    appLogger.i('💾 Starting catalog save: version=${package.versionNumber}, '
        'hash=${package.hash.substring(0, 8)}...');

    try {
      await _db.transaction(() async {
        // 1. Upsert CatalogVersions
        final versionCompanion = CatalogVersionsCompanion(
          id: Value(package.versionId),
          projectId: Value(projectId), // null for global catalog
          versionNumber: Value(_toVersionInt(package.versionNumber)),
          publishedAt: Value(package.publishedAt),
          checksum: Value(package.hash),
          notes: Value('Published at ${package.publishedAt.toIso8601String()}'),
        );

        await _db.into(_db.catalogVersions).insertOnConflictUpdate(versionCompanion);
        appLogger.i('  ✅ Upserted CatalogVersions: id=${package.versionId}, v=${package.versionNumber}');

        // 2. Delete old activity types for this catalog version
        await (_db.delete(_db.catalogActivityTypes)
            ..where((t) => t.catalogVersion.equals(_toVersionInt(package.versionNumber))))
            .go();

        // 3. Batch insert CatalogActivityTypes
        if (package.activityTypes.isNotEmpty) {
          final activityTypeCompanions = package.activityTypes.map((dto) {
            return CatalogActivityTypesCompanion(
              id: Value(dto.id),
              code: Value(dto.code),
              name: Value(dto.name),
              // Map requiresApproval to requiresPk (closest semantic match)
              // Other requires* fields default to false
              requiresPk: Value(dto.requiresApproval),
              requiresGeo: const Value(false),
              requiresMinuta: const Value(false),
              requiresEvidence: const Value(false),
              isActive: Value(dto.isActive),
              catalogVersion: Value(_toVersionInt(package.versionNumber)),
            );
          }).toList();

          await _db.batch((batch) {
            batch.insertAll(_db.catalogActivityTypes, activityTypeCompanions);
          });

          appLogger.i('  ✅ Inserted ${activityTypeCompanions.length} CatalogActivityTypes');
        }

        // 4. Delete old fields for this catalog version
        await (_db.delete(_db.catalogFields)
            ..where((t) => t.catalogVersion.equals(_toVersionInt(package.versionNumber))))
            .go();

        // 5. Batch insert CatalogFields (only for activity_type entity)
        final activityFormFields = package.formFields
            .where((f) => f.entityType == 'activity_type')
            .toList();

        if (activityFormFields.isNotEmpty) {
          final fieldCompanions = activityFormFields.map((dto) {
            // Encode options as JSON string if present
            String? optionsJson;
            if (dto.options != null && dto.options!.isNotEmpty) {
              optionsJson = jsonEncode(dto.options);
            }

            return CatalogFieldsCompanion(
              id: Value(dto.id),
              activityTypeId: Value(dto.typeId), // FK to activity type
              fieldKey: Value(dto.key),
              fieldLabel: Value(dto.label),
              fieldType: Value(dto.widget), // widget → fieldType
              optionsJson: Value(optionsJson),
              requiredField: Value(dto.required),
              orderIndex: Value(dto.sortOrder),
              isActive: const Value(true),
              catalogVersion: Value(_toVersionInt(package.versionNumber)),
            );
          }).toList();

          await _db.batch((batch) {
            batch.insertAll(_db.catalogFields, fieldCompanions);
          });

          appLogger.i('  ✅ Inserted ${fieldCompanions.length} CatalogFields (activity_type only)');
        }

        // Note: Other entity types (eventTypes, workflowStates, etc.) are not persisted
        // in this schema version. They may be handled by the effective catalog system.
        if (package.eventTypes.isNotEmpty ||
            package.workflowStates.isNotEmpty ||
            package.workflowTransitions.isNotEmpty ||
            package.evidenceRules.isNotEmpty ||
            package.checklistTemplates.isNotEmpty) {
          appLogger.w('  ⚠️  Skipped ${package.eventTypes.length} eventTypes, '
              '${package.workflowStates.length} workflowStates, '
              '${package.workflowTransitions.length} transitions, '
              '${package.evidenceRules.length} evidenceRules, '
              '${package.checklistTemplates.length} checklistTemplates '
              '(no Drift tables exist yet)');
        }
      });

      final duration = DateTime.now().difference(startTime);
      appLogger.i('✅ Catalog saved successfully in ${duration.inMilliseconds}ms');
    } catch (e, stack) {
      appLogger.e('❌ Error saving catalog package', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Get all activity types for the current catalog version.
  Future<List<CatalogActivityType>> getActivityTypes({String? projectId}) async {
    try {
      // Get current version first
      final currentVersion = await getCurrentCatalogVersion(projectId: projectId);
      if (currentVersion == null) {
        appLogger.w('📚 No current catalog version found, returning empty activity types');
        return [];
      }

      final query = _db.select(_db.catalogActivityTypes)
        ..where((t) => t.catalogVersion.equals(currentVersion.versionNumber))
        ..orderBy([(t) => OrderingTerm.asc(t.code)]);

      final results = await query.get();
      appLogger.i('📚 Fetched ${results.length} activity types for version ${currentVersion.versionNumber}');
      return results;
    } catch (e, stack) {
      appLogger.e('❌ Error fetching activity types', error: e, stackTrace: stack);
      return [];
    }
  }

  /// Get all form fields for a specific activity type.
  Future<List<CatalogField>> getFieldsForActivityType(
    String activityTypeId, {
    String? projectId,
  }) async {
    try {
      // Get current version first
      final currentVersion = await getCurrentCatalogVersion(projectId: projectId);
      if (currentVersion == null) {
        appLogger.w('📚 No current catalog version found, returning empty fields');
        return [];
      }

      final query = _db.select(_db.catalogFields)
        ..where((t) =>
            t.activityTypeId.equals(activityTypeId) &
            t.catalogVersion.equals(currentVersion.versionNumber) &
            t.isActive.equals(true))
        ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)]);

      final results = await query.get();
      appLogger.i('📚 Fetched ${results.length} fields for activity type $activityTypeId');
      return results;
    } catch (e, stack) {
      appLogger.e('❌ Error fetching fields for activity type', error: e, stackTrace: stack);
      return [];
    }
  }

  /// Get all catalog versions (for admin/debugging).
  Future<List<CatalogVersion>> listAllVersions({String? projectId}) async {
    try {
      final query = _db.select(_db.catalogVersions)
        ..orderBy([(t) => OrderingTerm.desc(t.versionNumber)]);

      if (projectId != null) {
        query.where((t) => t.projectId.equals(projectId));
      }

      final results = await query.get();
      appLogger.i('📚 Found ${results.length} catalog versions');
      return results;
    } catch (e, stack) {
      appLogger.e('❌ Error listing catalog versions', error: e, stackTrace: stack);
      return [];
    }
  }

  /// Delete a specific catalog version and all its data.
  /// Use with caution - this cascades to activity types and fields.
  Future<void> deleteCatalogVersion(int versionNumber) async {
    try {
      await _db.transaction(() async {
        // Delete fields first (FK constraint)
        await (_db.delete(_db.catalogFields)
              ..where((t) => t.catalogVersion.equals(versionNumber)))
            .go();

        // Delete activity types
        await (_db.delete(_db.catalogActivityTypes)
              ..where((t) => t.catalogVersion.equals(versionNumber)))
            .go();

        // Delete version record
        await (_db.delete(_db.catalogVersions)
              ..where((t) => t.versionNumber.equals(versionNumber)))
            .go();

        appLogger.i('🗑️  Deleted catalog version $versionNumber and all related data');
      });
    } catch (e, stack) {
      appLogger.e('❌ Error deleting catalog version', error: e, stackTrace: stack);
      rethrow;
    }
  }
}
