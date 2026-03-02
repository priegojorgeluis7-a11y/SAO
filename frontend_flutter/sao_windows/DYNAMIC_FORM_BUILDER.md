# DynamicFormBuilder Implementation Guide

**Date:** February 24, 2026  
**Status:** ✅ Implementation Complete  
**Coverage:** Form rendering, validation, state management for catalog-driven forms

## Overview

The **DynamicFormBuilder** replaces hardcoded wizard fields with a dynamic form renderer that reads field definitions from the catalog stored in the Drift database. This enables:

- 🎯 **Dynamic field rendering** based on activity type
- ✅ **Automatic validation** from field metadata
- 🔄 **State management** with Provider/ChangeNotifier
- 🎨 **7+ field types** (text, number, date, select, multiselect, checkbox, textarea)
- 📦 **Reusable components** for any form-building scenario

## Architecture

```
┌─ CatalogFieldsRepository
│  └─ Queries CatalogFields from Drift DB
│     └─ Returns field definitions (key, label, type, options, etc.)
│
├─ DynamicFormState (ChangeNotifier)
│  ├─ Manages field values, errors, and touched state
│  ├─ Validates individual fields and all fields
│  └─ Provides getAllValues(), reset(), etc.
│
├─ DynamicFormFieldState
│  └─ Single field: key, label, type, value, error, isTouched
│
├─ FormFieldRendererFactory
│  └─ Creates field widgets based on fieldType
│     ├─ TextFieldRenderer (text)
│     ├─ NumberFieldRenderer (number/integer)
│     ├─ DateFieldRenderer (date/datetime)
│     ├─ SelectFieldRenderer (select/dropdown)
│     ├─ MultiSelectFieldRenderer (multiselect)
│     ├─ CheckboxFieldRenderer (checkbox/bool)
│     └─ TextAreaFieldRenderer (textarea)
│
└─ DynamicFormBuilder (Widget)
   ├─ Loads fields on init
   ├─ Renders fields with proper validation UI
   ├─ Provides form state to parent via callback
   └─ Supports simple and grouped layouts
```

## Database Schema

### CatalogActivityTypes Table
```sql
-- Mobile side: CatalogActivityTypes (from catalog_sync)
CREATE TABLE catalog_activity_types (
  id TEXT PRIMARY KEY,
  code TEXT NOT NULL UNIQUE,           -- "CAMINAMIENTO", "ASAMBLEA"
  name TEXT NOT NULL,                  -- "Caminamiento de ruta"
  requires_pk BOOLEAN DEFAULT FALSE,   -- Needs PK input
  requires_geo BOOLEAN DEFAULT FALSE,  -- Needs GPS
  requires_minuta BOOLEAN DEFAULT FALSE,
  requires_evidence BOOLEAN DEFAULT FALSE,
  is_active BOOLEAN DEFAULT TRUE,
  catalog_version INTEGER DEFAULT 1
);
```

### CatalogFields Table
```sql
-- Mobile side: CatalogFields (from catalog_sync)
CREATE TABLE catalog_fields (
  id TEXT PRIMARY KEY,
  activity_type_id TEXT NOT NULL REFERENCES catalog_activity_types(id),
  field_key TEXT NOT NULL,             -- "asistentes", "tema", etc.
  field_label TEXT NOT NULL,           -- "Number of Attendees"
  field_type TEXT NOT NULL,            -- "text", "number", "date", "select"
  options_json TEXT,                   -- [{"label":"...", "value":"..."}, ...]
  required_field BOOLEAN DEFAULT FALSE,
  order_index INTEGER DEFAULT 0,       -- Sort order for rendering
  is_active BOOLEAN DEFAULT TRUE,
  catalog_version INTEGER DEFAULT 1,
  UNIQUE(activity_type_id, field_key)
);
```

## Usage

### 1. Basic DynamicFormBuilder

```dart
// In your widget (e.g., activity creation page)
late DynamicFormState _formState;

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(title: const Text('Create Activity')),
    body: Column(
      children: [
        Expanded(
          child: DynamicFormBuilder(
            activityTypeId: widget.activityTypeId,
            onFormStateReady: (formState) {
              _formState = formState;
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SaoButton.primary(
            label: 'Submit',
            onPressed: _handleSubmit,
          ),
        ),
      ],
    ),
  );
}

void _handleSubmit() {
  final errors = _formState.validateAll();
  
  if (errors.isNotEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Please fix: ${errors.join(", ")}')),
    );
    return;
  }

  final formValues = _formState.getAllValues();
  print('Form submission: $formValues');
  // Send to backend
}
```

### 2. With Initial Values

```dart
DynamicFormBuilder(
  activityTypeId: 'activity-123',
  initialValues: {
    'name': 'John Doe',
    'email': 'john@example.com',
    'role': 'supervisor',
  },
  onFormStateReady: (formState) {
    // Form auto-populated with initial values
  },
)
```

### 3. Grouped Fields (Optional)

```dart
GroupedDynamicFormBuilder(
  activityTypeId: 'activity-123',
  fieldGroups: {
    'Personal Information': ['name', 'email', 'phone'],
    'Activity Details': ['activity_type', 'date', 'location'],
    'Evidence': ['evidence_url', 'notes'],
  },
  onFormStateReady: (formState) {
    _formState = formState;
  },
)
```

### 4. Custom Error Widget

```dart
DynamicFormBuilder(
  activityTypeId: 'activity-123',
  errorBuilder: (error) => CustomErrorWidget(
    title: 'Cannot load form',
    message: error,
    onRetry: () { /* reload */ },
  ),
  loadingWidget: CustomLoadingWidget(),
  onFormStateReady: (formState) { ... },
)
```

## Field Types Supported

| Type | Widget Class | Input | Example |
|------|------|-------|---------|
| `text` / `string` | TextFieldRenderer | Single-line input | Name, email, URL |
| `number` / `integer` | NumberFieldRenderer | Numeric input | Age, count, distance |
| `date` / `datetime` | DateFieldRenderer | Date picker | Activity date, timestamp |
| `select` / `dropdown` | SelectFieldRenderer | Dropdown menu | Category, type, status |
| `multiselect` / `multi` | MultiSelectFieldRenderer | Checkboxes | Tags, interests |
| `checkbox` / `bool` | CheckboxFieldRenderer | Single checkbox | Confirm, agree |
| `textarea` / `text_area` | TextAreaFieldRenderer | Multi-line input | Description, notes |

## Validation

### Built-in Validation

- ✅ **Required field check** - from `required_field` column
- ✅ **Field type coercion** - number fields only accept numeric input
- 🔲 **Regex validation** - prepared for custom validators (future enhancement)
- 🔲 **Min/Max values** - prepared for numeric constraints (future enhancement)

### Custom Validation Example

```dart
// After form is ready
_formState.validateField('email');  // Single field
_formState.validateAll();            // All fields

// Listen to changes
context.watch<DynamicFormState>().fields['email']?.error;
```

## State Management

The `DynamicFormState` is a `ChangeNotifier` that manages:

```dart
class DynamicFormState extends ChangeNotifier {
  // Get field value
  String? getFieldValue('email');
  
  // Set field value (clears error)
  setFieldValue('email', 'test@example.com');
  
  // Mark field as touched (shows error UI)
  touchField('email');
  
  // Validate single field
  String? validateField('email');  // Returns error or null
  
  // Validate all fields
  List<String> validateAll();  // Returns list of errors
  
  // Get all values
  Map<String, String> getAllValues();  // Map of key -> value
  
  // Reset form
  reset();  // Clears all values, errors, touched state
  
  // Get sorted fields for rendering
  List<DynamicFormFieldState> getSortedFields();
}
```

## Field Definition Example

From backend catalog_sync (becomes CatalogFields in Drift):

```json
{
  "id": "field-001",
  "activity_type_id": "act-type-1",
  "field_key": "asistentes",
  "field_label": "Number of Attendees",
  "field_type": "number",
  "options_json": null,
  "required_field": true,
  "order_index": 1,
  "is_active": true,
  "catalog_version": 1
}
```

```json
{
  "id": "field-002",
  "activity_type_id": "act-type-1",
  "field_key": "tipo_evento",
  "field_label": "Event Type",
  "field_type": "select",
  "options_json": "[{\"label\":\"Incidente\",\"value\":\"incidente\"},{\"label\":\"Jornada\",\"value\":\"jornada\"}]",
  "required_field": true,
  "order_index": 2,
  "is_active": true,
  "catalog_version": 1
}
```

## Loading Field Definitions

1. **From Mobile Catalog Sync (Phase 4C)**
   ```dart
   final result = await catalogSyncService.syncCatalog(projectId);
   // Fetches latest catalog from backend, persists to Drift
   // CatalogFields automatically populated
   ```

2. **Query Fields in DynamicFormBuilder**
   ```dart
   final fieldsRepo = CatalogFieldsRepository();
   final fields = await fieldsRepo.getFieldsByActivityType('activity-123');
   // Returns List<Map<String, dynamic>>
   ```

3. **Parse Options for Select Fields**
   ```dart
   final options = CatalogFieldsRepository.parseOptions(optionsJson);
   // Returns List<Map<String, String>>
   ```

## Integration Into Wizard

Current wizard has fixed fields. To migrate to dynamic:

### Before (Hardcoded)
```dart
class WizardStepFields extends StatefulWidget {
  // Fixed fields: risk, activity, subcategory, purpose, topic, etc.
  // 800+ lines of hardcoded UI
}
```

### After (Dynamic)
```dart
class WizardStepFields extends StatefulWidget {
  late DynamicFormState _formState;
  
  @override
  Widget build(BuildContext context) {
    return DynamicFormBuilder(
      activityTypeId: widget.selectedActivityType, // From wizard context
      onFormStateReady: (formState) {
        _formState = formState;
      },
    );
  }
  
  void _handleNext() {
    final errors = _formState.validateAll();
    if (errors.isNotEmpty) {
      // Show errors
      return;
    }
    
    final values = _formState.getAllValues();
    // Store in wizard controller
    widget.controller.updateFieldsStep(values);
    widget.onNext();
  }
}
```

## Testing

Unit tests included in `test/features/activities/wizard/dynamic_form_builder_test.dart`:

```bash
# Run tests
cd frontend_flutter/sao_windows
flutter test test/features/activities/wizard/dynamic_form_builder_test.dart

# Run with coverage
flutter test --coverage
```

Test coverage includes:
- ✅ Field initialization and sorting
- ✅ Value setting and retrieval
- ✅ Validation (required fields, multiple fields)
- ✅ Form reset
- ✅ Options parsing (JSON)
- ✅ Error handling

## Migration Checklist

- [ ] Deploy catalog_sync (Phase 4C) to populate CatalogFields
- [ ] Create DynamicFormBuilder widget in activity creation flow
- [ ] Replace hardcoded WizardStepFields with DynamicFormBuilder
- [ ] Test with different activity types and field combinations
- [ ] Add form grouping UI if needed (Group related fields into sections)
- [ ] Implement custom validators (regex, min/max values)
- [ ] Update wizard_controller to handle dynamic field values
- [ ] Test on mobile device with real catalog data
- [ ] Performance testing with 50+ fields

## Performance Considerations

- **Field loading:** Cached after first sync (no repeated DB queries)
- **Rendering:** ListView with separators (efficient scrolling)
- **Form state:** ChangeNotifier only notifies on changes (fine-grained updates)
- **Memory:** Dispose TextEditingControllers properly in renderers

## Error Handling

```dart
// If fields don't load
// → Shows error UI with "No form fields available"

// If invalid field type
// → Falls back to TextFieldRenderer

// If options JSON is malformed
// → Logs warning, returns empty options

// If catalog not synced
// → CatalogFields table is empty → error message
```

## Future Enhancements

- 🔲 **Conditional visibility** (show field only if another field has value)
- 🔲 **Regex validation** (from validationRegex column)
- 🔲 **Min/Max constraints** (from minValue/maxValue columns)
- 🔲 **Custom field types** (custom widget plugins)
- 🔲 **Field dependencies** (autofill, cascading dropdowns)
- 🔲 **Form versioning** (handle multiple catalog versions)
- 🔲 **Offline field definitions** (cache to disk)

## Files Created/Modified

### New Files
- ✅ `lib/features/catalog/data/catalog_fields_repository.dart` - Query fields from Drift
- ✅ `lib/features/activities/wizard/models/dynamic_form_state.dart` - Form state management
- ✅ `lib/features/activities/wizard/widgets/form_field_renderers.dart` - Field UI renderers
- ✅ `lib/features/activities/wizard/widgets/dynamic_form_builder.dart` - Main form builder widget
- ✅ `test/features/activities/wizard/dynamic_form_builder_test.dart` - Unit tests

### Modified Files
- 🔲 `lib/features/activities/wizard/wizard_step_fields.dart` - Requires integration (future PR)
- 🔲 `lib/features/activities/wizard/wizard_controller.dart` - Requires update (future PR)

## Related Documentation

- [ACTIVITY_MODEL_V1.md](../ACTIVITY_MODEL_V1.md) - Activity schema
- [STATUS.md](../STATUS.md) - Phase 4 catalog infrastructure
- [IMPLEMENTATION_GUIDE.md](../IMPLEMENTATION_GUIDE.md) - Mobile phases overview

## Questions / Support

For issues or questions about DynamicFormBuilder:
1. Check field definitions in Drift: `SELECT * FROM catalog_fields;`
2. Verify optionsJson is valid JSON for select fields
3. Check logs for field loading errors
4. Ensure activity type ID matches a real activity in catalog

---

**Implementation Status:** ✅ PHASE 5 COMPLETE (Mobile DynamicFormBuilder)

Enables Phase 6 next: Evidence capture + upload integration
