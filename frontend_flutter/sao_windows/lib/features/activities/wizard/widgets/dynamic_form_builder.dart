// lib/features/activities/wizard/widgets/dynamic_form_builder.dart
// Main DynamicFormBuilder widget that renders forms dynamically from catalog.
// Orchestrates loading definitions, managing field state and rendering widgets.
// Usage:
//   DynamicFormBuilder(
//     activityTypeId: activity.typeId,
//     onFieldsLoaded: (formState) { ... },
//   )

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../catalog/data/catalog_fields_repository.dart';
import '../../../../core/utils/logger.dart';
import '../../../../ui/theme/sao_typography.dart';
import '../models/dynamic_form_state.dart';
import 'form_field_renderers.dart';

typedef OnFormStateReady = void Function(DynamicFormState formState);

class DynamicFormBuilder extends StatefulWidget {
  /// Activity type ID to load fields for.
  final String activityTypeId;

  /// Callback when form state is initialized and ready.
  final OnFormStateReady onFormStateReady;

  /// Optional initial values for form fields.
  final Map<String, String>? initialValues;

  /// Custom error widget builder.
  final Widget Function(String error)? errorBuilder;

  /// Custom loading widget.
  final Widget? loadingWidget;

  const DynamicFormBuilder({
    super.key,
    required this.activityTypeId,
    required this.onFormStateReady,
    this.initialValues,
    this.errorBuilder,
    this.loadingWidget,
  });

  @override
  State<DynamicFormBuilder> createState() => _DynamicFormBuilderState();
}

class _DynamicFormBuilderState extends State<DynamicFormBuilder> {
  late DynamicFormState _formState;
  final _fieldsRepository = CatalogFieldsRepository();

  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _formState = DynamicFormState(activityTypeId: widget.activityTypeId);
    _loadFields();
  }

  Future<void> _loadFields() async {
    try {
      appLogger.i('📋 Loading form fields for activity: ${widget.activityTypeId}');

      final fieldDefinitions = await _fieldsRepository.getFieldsByActivityType(
        widget.activityTypeId,
      );

      if (fieldDefinitions.isEmpty) {
        appLogger.w('⚠️ No fields found for activity ${widget.activityTypeId}');
        setState(() {
          _isLoading = false;
          _loadError = 'No form fields available for this activity type';
        });
        return;
      }

      _formState.initializeFields(fieldDefinitions);

      // Apply initial values if provided
      if (widget.initialValues != null) {
        for (final entry in widget.initialValues!.entries) {
          _formState.setFieldValue(entry.key, entry.value);
        }
      }

      // Notify parent that form is ready
      widget.onFormStateReady(_formState);

      setState(() {
        _isLoading = false;
      });

      appLogger.i('✅ Form fields loaded: ${fieldDefinitions.length} fields');
    } catch (e, stack) {
      appLogger.e('❌ Error loading form fields', error: e, stackTrace: stack);
      setState(() {
        _isLoading = false;
        _loadError = 'Failed to load form fields: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return widget.loadingWidget ??
          const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading form fields...'),
              ],
            ),
          );
    }

    if (_loadError != null) {
      return widget.errorBuilder?.call(_loadError!) ??
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Error loading form',
                  style: SaoTypography.titleMedium.copyWith(color: Colors.red),
                ),
                const SizedBox(height: 8),
                Text(
                  _loadError!,
                  style: SaoTypography.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
    }

    return ChangeNotifierProvider<DynamicFormState>.value(
      value: _formState,
      child: Consumer<DynamicFormState>(
        builder: (context, formState, child) {
          final sortedFields = formState.getSortedFields();

          if (sortedFields.isEmpty) {
            return const Center(
              child: Text(
                'No form fields to display',
                style: SaoTypography.bodyMedium,
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: sortedFields.length,
            separatorBuilder: (_, _) => const SizedBox(height: 24),
            itemBuilder: (context, index) {
              final fieldState = sortedFields[index];
              return _buildFormField(context, fieldState);
            },
          );
        },
      ),
    );
  }

  Widget _buildFormField(BuildContext context, DynamicFormFieldState fieldState) {
    return FormFieldRendererFactory.createFieldWidget(
      fieldState: fieldState,
      value: fieldState.value,
      onChanged: (newValue) {
        context.read<DynamicFormState>().setFieldValue(fieldState.fieldKey, newValue);
      },
      onTouched: () {
        context.read<DynamicFormState>().touchField(fieldState.fieldKey);
      },
    );
  }
}

/// Standalone form builder with optional sections and grouping.
/// Usage:
///   GroupedDynamicFormBuilder(
///     activityTypeId: 'activity-123',
///     fieldGroups: {
///       'Personal Info': ['name', 'email'],
///       'Details': ['description', 'date'],
///     },
///     onFormStateReady: (formState) { ... },
///   )
class GroupedDynamicFormBuilder extends StatefulWidget {
  final String activityTypeId;
  final Map<String, List<String>>? fieldGroups;
  final OnFormStateReady onFormStateReady;
  final Map<String, String>? initialValues;

  const GroupedDynamicFormBuilder({
    super.key,
    required this.activityTypeId,
    required this.onFormStateReady,
    this.fieldGroups,
    this.initialValues,
  });

  @override
  State<GroupedDynamicFormBuilder> createState() => _GroupedDynamicFormBuilderState();
}

class _GroupedDynamicFormBuilderState extends State<GroupedDynamicFormBuilder> {
  late DynamicFormState _formState;
  final _fieldsRepository = CatalogFieldsRepository();

  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _formState = DynamicFormState(activityTypeId: widget.activityTypeId);
    _loadFields();
  }

  Future<void> _loadFields() async {
    try {
      final fieldDefinitions = await _fieldsRepository.getFieldsByActivityType(
        widget.activityTypeId,
      );

      if (fieldDefinitions.isEmpty) {
        setState(() {
          _isLoading = false;
          _loadError = 'No form fields available';
        });
        return;
      }

      _formState.initializeFields(fieldDefinitions);

      if (widget.initialValues != null) {
        for (final entry in widget.initialValues!.entries) {
          _formState.setFieldValue(entry.key, entry.value);
        }
      }

      widget.onFormStateReady(_formState);

      setState(() {
        _isLoading = false;
      });
    } catch (e, stack) {
      appLogger.e('❌ Error loading form fields', error: e, stackTrace: stack);
      setState(() {
        _isLoading = false;
        _loadError = 'Failed to load: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null) {
      return Center(child: Text('Error: $_loadError'));
    }

    return ChangeNotifierProvider<DynamicFormState>.value(
      value: _formState,
      child: Consumer<DynamicFormState>(
        builder: (context, formState, child) {
          final sortedFields = formState.getSortedFields();

          if (widget.fieldGroups == null) {
            // Render without grouping
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: sortedFields.length,
              separatorBuilder: (_, _) => const SizedBox(height: 24),
              itemBuilder: (context, index) {
                return _buildFormField(context, sortedFields[index]);
              },
            );
          }

          // Render with grouping
          final groupedFields = <String, List<DynamicFormFieldState>>{};
          final ungroupedFields = <DynamicFormFieldState>[];

          for (final field in sortedFields) {
            bool found = false;
            for (final entry in widget.fieldGroups!.entries) {
              if (entry.value.contains(field.fieldKey)) {
                groupedFields.putIfAbsent(entry.key, () => []).add(field);
                found = true;
                break;
              }
            }
            if (!found) {
              ungroupedFields.add(field);
            }
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: groupedFields.length + (ungroupedFields.isNotEmpty ? 1 : 0),
            itemBuilder: (context, index) {
              if (index < groupedFields.length) {
                final groupName = groupedFields.keys.toList()[index];
                final groupFields = groupedFields[groupName]!;

                return _buildFieldGroup(context, groupName, groupFields);
              } else {
                return Column(
                  children: [
                    const SizedBox(height: 24),
                    ...ungroupedFields
                        .asMap()
                        .entries
                        .map((entry) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: _buildFormField(context, entry.value),
                          );
                        })
                        ,
                  ],
                );
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildFieldGroup(
    BuildContext context,
    String groupName,
    List<DynamicFormFieldState> fields,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(groupName, style: SaoTypography.titleMedium),
        const SizedBox(height: 16),
        ...fields
            .asMap()
            .entries
            .map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: _buildFormField(context, entry.value),
              );
            })
            ,
      ],
    );
  }

  Widget _buildFormField(BuildContext context, DynamicFormFieldState fieldState) {
    return FormFieldRendererFactory.createFieldWidget(
      fieldState: fieldState,
      value: fieldState.value,
      onChanged: (newValue) {
        context.read<DynamicFormState>().setFieldValue(fieldState.fieldKey, newValue);
      },
      onTouched: () {
        context.read<DynamicFormState>().touchField(fieldState.fieldKey);
      },
    );
  }
}
