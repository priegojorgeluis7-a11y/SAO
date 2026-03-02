// test/features/activities/wizard/dynamic_form_builder_test.dart
// Unit tests for DynamicFormBuilder and related components.
// Tests form state management, validation, and field rendering.

import 'package:flutter_test/flutter_test.dart';
import 'package:sao_windows/features/activities/wizard/models/dynamic_form_state.dart';
import 'package:sao_windows/features/catalog/data/catalog_fields_repository.dart';

void main() {
  group('DynamicFormFieldState', () {
    test('creates field with correct properties', () {
      const metadata = {'min': 1, 'max': 100};
      final field = DynamicFormFieldState(
        fieldKey: 'email',
        fieldLabel: 'Email Address',
        fieldType: 'text',
        required: true,
        metadata: metadata,
      );

      expect(field.fieldKey, 'email');
      expect(field.fieldLabel, 'Email Address');
      expect(field.fieldType, 'text');
      expect(field.required, true);
      expect(field.isTouched, false);
      expect(field.hasError, false);
    });

    test('touches field correctly', () {
      final field = DynamicFormFieldState(
        fieldKey: 'name',
        fieldLabel: 'Name',
        fieldType: 'text',
        required: false,
        metadata: {},
      );

      expect(field.isTouched, false);
      field.touch();
      expect(field.isTouched, true);
    });

    test('sets and clears error', () {
      final field = DynamicFormFieldState(
        fieldKey: 'age',
        fieldLabel: 'Age',
        fieldType: 'number',
        required: true,
        metadata: {},
      );

      expect(field.hasError, false);
      field.setError('Age must be a number');
      expect(field.hasError, true);
      expect(field.error, 'Age must be a number');

      field.clearError();
      expect(field.hasError, false);
      expect(field.error, null);
    });
  });

  group('DynamicFormState', () {
    test('initializes with empty fields', () {
      final formState = DynamicFormState(activityTypeId: 'activity-123');
      expect(formState.fields.isEmpty, true);
      expect(formState.activityTypeId, 'activity-123');
    });

    test('initializes fields from definitions', () {
      final formState = DynamicFormState(activityTypeId: 'activity-123');

      final definitions = [
        {
          'fieldKey': 'name',
          'fieldLabel': 'Full Name',
          'fieldType': 'text',
          'requiredField': true,
          'id': 'field-1',
          'orderIndex': 0,
          'optionsJson': null,
        },
        {
          'fieldKey': 'email',
          'fieldLabel': 'Email',
          'fieldType': 'text',
          'requiredField': true,
          'id': 'field-2',
          'orderIndex': 1,
          'optionsJson': null,
        },
      ];

      formState.initializeFields(definitions);

      expect(formState.fields.length, 2);
      expect(formState.fields.containsKey('name'), true);
      expect(formState.fields.containsKey('email'), true);
      expect(formState.fields['name']?.fieldLabel, 'Full Name');
    });

    test('sets and gets field values', () {
      final formState = DynamicFormState(activityTypeId: 'activity-123');

      final definitions = [
        {
          'fieldKey': 'name',
          'fieldLabel': 'Name',
          'fieldType': 'text',
          'requiredField': false,
          'id': 'field-1',
          'orderIndex': 0,
          'optionsJson': null,
        }
      ];

      formState.initializeFields(definitions);

      formState.setFieldValue('name', 'John Doe');
      expect(formState.getFieldValue('name'), 'John Doe');
    });

    test('validates required field', () {
      final formState = DynamicFormState(activityTypeId: 'activity-123');

      final definitions = [
        {
          'fieldKey': 'email',
          'fieldLabel': 'Email',
          'fieldType': 'text',
          'requiredField': true,
          'id': 'field-1',
          'orderIndex': 0,
          'optionsJson': null,
        }
      ];

      formState.initializeFields(definitions);

      final error = formState.validateField('email');
      expect(error, contains('required'));

      formState.setFieldValue('email', 'test@example.com');
      final noError = formState.validateField('email');
      expect(noError, null);
    });

    test('validates all fields with errors', () {
      final formState = DynamicFormState(activityTypeId: 'activity-123');

      final definitions = [
        {
          'fieldKey': 'name',
          'fieldLabel': 'Name',
          'fieldType': 'text',
          'requiredField': true,
          'id': 'field-1',
          'orderIndex': 0,
          'optionsJson': null,
        },
        {
          'fieldKey': 'email',
          'fieldLabel': 'Email',
          'fieldType': 'text',
          'requiredField': true,
          'id': 'field-2',
          'orderIndex': 1,
          'optionsJson': null,
        }
      ];

      formState.initializeFields(definitions);

      final errors = formState.validateAll();
      expect(errors.length, 2);
      expect(errors.any((e) => e.contains('Name')), true);
      expect(errors.any((e) => e.contains('Email')), true);
    });

    test('gets all values as map', () {
      final formState = DynamicFormState(activityTypeId: 'activity-123');

      final definitions = [
        {
          'fieldKey': 'name',
          'fieldLabel': 'Name',
          'fieldType': 'text',
          'requiredField': false,
          'id': 'field-1',
          'orderIndex': 0,
          'optionsJson': null,
        },
        {
          'fieldKey': 'email',
          'fieldLabel': 'Email',
          'fieldType': 'text',
          'requiredField': false,
          'id': 'field-2',
          'orderIndex': 1,
          'optionsJson': null,
        }
      ];

      formState.initializeFields(definitions);
      formState.setFieldValue('name', 'John');
      formState.setFieldValue('email', 'john@example.com');

      final values = formState.getAllValues();
      expect(values['name'], 'John');
      expect(values['email'], 'john@example.com');
      expect(values.length, 2);
    });

    test('resets form state', () {
      final formState = DynamicFormState(activityTypeId: 'activity-123');

      final definitions = [
        {
          'fieldKey': 'name',
          'fieldLabel': 'Name',
          'fieldType': 'text',
          'requiredField': false,
          'id': 'field-1',
          'orderIndex': 0,
          'optionsJson': null,
        }
      ];

      formState.initializeFields(definitions);
      formState.setFieldValue('name', 'John');
      formState.touchField('name');

      formState.reset();

      expect(formState.getFieldValue('name'), null);
      expect(formState.fields['name']?.isTouched, false);
    });

    test('sorts fields by orderIndex', () {
      final formState = DynamicFormState(activityTypeId: 'activity-123');

      final definitions = [
        {
          'fieldKey': 'email',
          'fieldLabel': 'Email',
          'fieldType': 'text',
          'requiredField': false,
          'id': 'field-2',
          'orderIndex': 2,
          'optionsJson': null,
        },
        {
          'fieldKey': 'name',
          'fieldLabel': 'Name',
          'fieldType': 'text',
          'requiredField': false,
          'id': 'field-1',
          'orderIndex': 1,
          'optionsJson': null,
        }
      ];

      formState.initializeFields(definitions);
      final sorted = formState.getSortedFields();

      expect(sorted[0].fieldKey, 'name');
      expect(sorted[1].fieldKey, 'email');
    });
  });

  group('CatalogFieldsRepository', () {
    test('parses options from JSON correctly', () {
      const optionsJson = '''
      [
        {"label": "Option 1", "value": "opt1"},
        {"label": "Option 2", "value": "opt2"}
      ]
      ''';

      final options = CatalogFieldsRepository.parseOptions(optionsJson);

      expect(options.length, 2);
      expect(options[0]['value'], 'opt1');
      expect(options[0]['label'], 'Option 1');
      expect(options[1]['value'], 'opt2');
      expect(options[1]['label'], 'Option 2');
    });

    test('returns empty list for null options', () {
      final options = CatalogFieldsRepository.parseOptions(null);
      expect(options.isEmpty, true);
    });

    test('returns empty list for empty options', () {
      final options = CatalogFieldsRepository.parseOptions('');
      expect(options.isEmpty, true);
    });

    test('handles invalid JSON gracefully', () {
      const invalidJson = 'not-valid-json';

      final options = CatalogFieldsRepository.parseOptions(invalidJson);
      expect(options.isEmpty, true);
    });
  });

  group('Form validation scenarios', () {
    test('validates multiple required fields', () {
      final formState = DynamicFormState(activityTypeId: 'activity-123');

      final definitions = [
        {
          'fieldKey': 'name',
          'fieldLabel': 'Full Name',
          'fieldType': 'text',
          'requiredField': true,
          'id': 'field-1',
          'orderIndex': 1,
          'optionsJson': null,
        },
        {
          'fieldKey': 'description',
          'fieldLabel': 'Description',
          'fieldType': 'textarea',
          'requiredField': true,
          'id': 'field-2',
          'orderIndex': 2,
          'optionsJson': null,
        },
        {
          'fieldKey': 'optional_field',
          'fieldLabel': 'Optional Info',
          'fieldType': 'text',
          'requiredField': false,
          'id': 'field-3',
          'orderIndex': 3,
          'optionsJson': null,
        }
      ];

      formState.initializeFields(definitions);

      // Initial validation should fail
      final initialErrors = formState.validateAll();
      expect(initialErrors.length, 2);

      // Fill in required fields
      formState.setFieldValue('name', 'John Doe');
      formState.setFieldValue('description', 'Test description');

      // Re-validate should pass
      formState.fields.clear();
      formState.initializeFields(definitions);
      formState.setFieldValue('name', 'John Doe');
      formState.setFieldValue('description', 'Test description');

      final finalErrors = formState.validateAll();
      expect(finalErrors.isEmpty, true);
    });
  });
}
