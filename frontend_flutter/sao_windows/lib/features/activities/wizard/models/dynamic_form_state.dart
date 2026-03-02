// lib/features/activities/wizard/models/dynamic_form_state.dart
/// State model for dynamic form field values, errors, and touched state.
/// Used by DynamicFormBuilder to manage form submission and validation.
library;


import 'package:flutter/foundation.dart';

class DynamicFormFieldState {
  final String fieldKey;
  final String fieldLabel;
  final String fieldType;
  final bool required;
  final Map<String, dynamic> metadata; // min/max, regex, options, etc.

  String? value;
  String? error;
  bool isTouched = false;

  DynamicFormFieldState({
    required this.fieldKey,
    required this.fieldLabel,
    required this.fieldType,
    required this.required,
    required this.metadata,
    this.value,
    this.error,
  });

  /// Mark this field as touched and revalidate.
  void touch() {
    isTouched = true;
  }

  /// Clear the error state.
  void clearError() {
    error = null;
  }

  /// Set a new error.
  void setError(String? newError) {
    error = newError;
  }

  /// Check if field has any error.
  bool get hasError => error != null && error!.isNotEmpty;
}

class DynamicFormState extends ChangeNotifier {
  final Map<String, DynamicFormFieldState> fields = {};
  final String activityTypeId;

  DynamicFormState({required this.activityTypeId});

  /// Initialize fields from catalog metadata.
  void initializeFields(List<Map<String, dynamic>> fieldDefinitions) {
    fields.clear();

    for (final def in fieldDefinitions) {
      final fieldKey = def['fieldKey'] as String;
      final fieldState = DynamicFormFieldState(
        fieldKey: fieldKey,
        fieldLabel: def['fieldLabel'] as String,
        fieldType: def['fieldType'] as String,
        required: def['requiredField'] as bool? ?? false,
        metadata: {
          'optionsJson': def['optionsJson'],
          'id': def['id'],
          'orderIndex': def['orderIndex'],
        },
      );

      fields[fieldKey] = fieldState;
    }

    notifyListeners();
  }

  /// Get field value by key.
  String? getFieldValue(String fieldKey) {
    return fields[fieldKey]?.value;
  }

  /// Set field value.
  void setFieldValue(String fieldKey, String? value) {
    final field = fields[fieldKey];
    if (field != null) {
      field.value = value;
      field.clearError();
      notifyListeners();
    }
  }

  /// Mark field as touched.
  void touchField(String fieldKey) {
    final field = fields[fieldKey];
    if (field != null) {
      field.touch();
      notifyListeners();
    }
  }

  /// Validate a single field.
  /// Returns error message or null if valid.
  String? validateField(String fieldKey) {
    final field = fields[fieldKey];
    if (field == null) return null;

    // Check required
    if (field.required && (field.value == null || field.value!.isEmpty)) {
      field.setError('${field.fieldLabel} is required');
      return field.error;
    }

    // Clear error if value exists for required field
    if (field.value != null && field.value!.isNotEmpty) {
      field.clearError();
    }

    return field.error;
  }

  /// Validate all fields and return list of errors.
  List<String> validateAll() {
    final errors = <String>[];

    for (final field in fields.values) {
      field.touch();
      final error = validateField(field.fieldKey);
      if (error != null) {
        errors.add(error);
      }
    }

    notifyListeners();
    return errors;
  }

  /// Get all field values as a map.
  Map<String, String> getAllValues() {
    final result = <String, String>{};
    for (final entry in fields.entries) {
      if (entry.value.value != null) {
        result[entry.key] = entry.value.value!;
      }
    }
    return result;
  }

  /// Reset form state.
  void reset() {
    for (final field in fields.values) {
      field.value = null;
      field.error = null;
      field.isTouched = false;
    }
    notifyListeners();
  }

  /// Get sorted fields for rendering.
  List<DynamicFormFieldState> getSortedFields() {
    final sorted = fields.values.toList();
    sorted.sort((a, b) {
      final orderA = (a.metadata['orderIndex'] as int?) ?? 999;
      final orderB = (b.metadata['orderIndex'] as int?) ?? 999;
      return orderA.compareTo(orderB);
    });
    return sorted;
  }
}
