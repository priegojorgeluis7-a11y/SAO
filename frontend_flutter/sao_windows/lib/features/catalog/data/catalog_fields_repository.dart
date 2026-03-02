// lib/features/catalog/data/catalog_fields_repository.dart
/// Repository for querying form fields from the catalog.
/// Used by DynamicFormBuilder to render dynamic forms.
library;


import 'dart:convert';
import 'package:drift/drift.dart';
import '../../../core/utils/logger.dart';
import '../../../data/local/db_instance.dart';

class CatalogFieldsRepository {
  /// Get all fields for a specific activity type, ordered by orderIndex.
  ///
  /// Returns a list of field rows (maps) with all field metadata.
  /// Used by DynamicFormBuilder to render form fields dynamically.
  Future<List<Map<String, dynamic>>> getFieldsByActivityType(
    String activityTypeId, {
    int catalogVersion = 1,
  }) async {
    try {
      appLogger.i('📋 Fetching fields for activity: $activityTypeId, version: $catalogVersion');

      final fields = await (appDb.select(appDb.catalogFields)
            ..where((t) =>
                t.activityTypeId.equals(activityTypeId) &
                t.isActive.equals(true) &
                t.catalogVersion.equals(catalogVersion))
            ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)]))
          .get();

      appLogger.i('✅ Found ${fields.length} fields for activity type');

      // Convert to maps for flexibility
      return fields.map((f) {
        return {
          'id': f.id,
          'activityTypeId': f.activityTypeId,
          'fieldKey': f.fieldKey,
          'fieldLabel': f.fieldLabel,
          'fieldType': f.fieldType,
          'optionsJson': f.optionsJson,
          'requiredField': f.requiredField,
          'orderIndex': f.orderIndex,
          'isActive': f.isActive,
          'catalogVersion': f.catalogVersion,
        };
      }).toList();
    } catch (e, stack) {
      appLogger.e('❌ Error fetching fields', error: e, stackTrace: stack);
      return [];
    }
  }

  /// Get a single field by ID.
  Future<Map<String, dynamic>?> getFieldById(String fieldId) async {
    try {
      final field = await (appDb.select(appDb.catalogFields)
            ..where((t) => t.id.equals(fieldId)))
          .getSingleOrNull();

      if (field == null) return null;

      return {
        'id': field.id,
        'activityTypeId': field.activityTypeId,
        'fieldKey': field.fieldKey,
        'fieldLabel': field.fieldLabel,
        'fieldType': field.fieldType,
        'optionsJson': field.optionsJson,
        'requiredField': field.requiredField,
        'orderIndex': field.orderIndex,
        'isActive': field.isActive,
        'catalogVersion': field.catalogVersion,
      };
    } catch (e, stack) {
      appLogger.e('❌ Error fetching field', error: e, stackTrace: stack);
      return null;
    }
  }

  /// Parse options from JSON for select/multiselect fields.
  /// Options expected format: [{"label": "Option 1", "value": "opt1"}, ...]
  static List<Map<String, String>> parseOptions(String? optionsJson) {
    if (optionsJson == null || optionsJson.isEmpty) {
      return [];
    }

    try {
      final parsed = jsonDecode(optionsJson);
      if (parsed is List) {
        return List<Map<String, String>>.from(
          parsed.map((opt) => Map<String, String>.from(
                (opt as Map).map((k, v) => MapEntry(k.toString(), v.toString())),
              )),
        );
      }
    } catch (e) {
      appLogger.w('⚠️ Failed to parse options JSON: $optionsJson', error: e);
    }

    return [];
  }
}
