// lib/features/activities/wizard/widgets/form_field_renderers.dart
// Field renderers for different widget types in dynamic forms.
// Supports: text, number, date, select, checkbox, multiselect, textarea.
// Each renderer returns a widget that displays the field with appropriate
// input type and handles user interaction.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../catalog/data/catalog_fields_repository.dart';
import '../../../../ui/theme/sao_colors.dart';
import '../../../../ui/theme/sao_typography.dart';
import '../models/dynamic_form_state.dart';

/// Factory for creating field widgets based on field type.
class FormFieldRendererFactory {
  static Widget createFieldWidget({
    required DynamicFormFieldState fieldState,
    required ValueChanged<String?> onChanged,
    required VoidCallback onTouched,
    required String? value,
  }) {
    switch (fieldState.fieldType.toLowerCase()) {
      case 'text':
      case 'string':
        return TextFieldRenderer(
          fieldState: fieldState,
          value: value,
          onChanged: onChanged,
          onTouched: onTouched,
        );

      case 'number':
      case 'integer':
        return NumberFieldRenderer(
          fieldState: fieldState,
          value: value,
          onChanged: onChanged,
          onTouched: onTouched,
        );

      case 'date':
      case 'datetime':
        return DateFieldRenderer(
          fieldState: fieldState,
          value: value,
          onChanged: onChanged,
          onTouched: onTouched,
        );

      case 'select':
      case 'dropdown':
        return SelectFieldRenderer(
          fieldState: fieldState,
          value: value,
          onChanged: onChanged,
          onTouched: onTouched,
        );

      case 'multiselect':
      case 'multi':
        return MultiSelectFieldRenderer(
          fieldState: fieldState,
          value: value,
          onChanged: onChanged,
          onTouched: onTouched,
        );

      case 'checkbox':
      case 'bool':
      case 'boolean':
        return CheckboxFieldRenderer(
          fieldState: fieldState,
          value: value,
          onChanged: onChanged,
          onTouched: onTouched,
        );

      case 'textarea':
      case 'text_area':
        return TextAreaFieldRenderer(
          fieldState: fieldState,
          value: value,
          onChanged: onChanged,
          onTouched: onTouched,
        );

      default:
        return TextFieldRenderer(
          fieldState: fieldState,
          value: value,
          onChanged: onChanged,
          onTouched: onTouched,
        );
    }
  }
}

/// Text input field (string type).
class TextFieldRenderer extends StatefulWidget {
  final DynamicFormFieldState fieldState;
  final String? value;
  final ValueChanged<String?> onChanged;
  final VoidCallback onTouched;

  const TextFieldRenderer({
    super.key,
    required this.fieldState,
    required this.value,
    required this.onChanged,
    required this.onTouched,
  });

  @override
  State<TextFieldRenderer> createState() => _TextFieldRendererState();
}

class _TextFieldRendererState extends State<TextFieldRenderer> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value ?? '');
  }

  @override
  void didUpdateWidget(TextFieldRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _controller.text = widget.value ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(),
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          onChanged: widget.onChanged,
          onTap: widget.onTouched,
          decoration: InputDecoration(
            hintText: widget.fieldState.fieldLabel,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: widget.fieldState.hasError ? Colors.red : SaoColors.borderLight,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: widget.fieldState.hasError ? Colors.red : SaoColors.primary,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          style: SaoTypography.bodyMedium,
        ),
        if (widget.fieldState.hasError) ...[
          const SizedBox(height: 6),
          Text(
            widget.fieldState.error!,
            style: SaoTypography.bodySmall.copyWith(color: Colors.red),
          ),
        ],
      ],
    );
  }

  Widget _buildLabel() {
    return Row(
      children: [
        Text(widget.fieldState.fieldLabel, style: SaoTypography.labelMedium),
        if (widget.fieldState.required) ...[
          const SizedBox(width: 4),
          const Text('*', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        ],
      ],
    );
  }
}

/// Number input field (integer/float type).
class NumberFieldRenderer extends StatefulWidget {
  final DynamicFormFieldState fieldState;
  final String? value;
  final ValueChanged<String?> onChanged;
  final VoidCallback onTouched;

  const NumberFieldRenderer({
    super.key,
    required this.fieldState,
    required this.value,
    required this.onChanged,
    required this.onTouched,
  });

  @override
  State<NumberFieldRenderer> createState() => _NumberFieldRendererState();
}

class _NumberFieldRendererState extends State<NumberFieldRenderer> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(),
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          onChanged: widget.onChanged,
          onTap: widget.onTouched,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.-]'))],
          decoration: InputDecoration(
            hintText: 'Enter number',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: widget.fieldState.hasError ? Colors.red : SaoColors.borderLight,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: widget.fieldState.hasError ? Colors.red : SaoColors.primary,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          style: SaoTypography.bodyMedium,
        ),
        if (widget.fieldState.hasError) ...[
          const SizedBox(height: 6),
          Text(
            widget.fieldState.error!,
            style: SaoTypography.bodySmall.copyWith(color: Colors.red),
          ),
        ],
      ],
    );
  }

  Widget _buildLabel() {
    return Row(
      children: [
        Text(widget.fieldState.fieldLabel, style: SaoTypography.labelMedium),
        if (widget.fieldState.required) ...[
          const SizedBox(width: 4),
          const Text('*', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        ],
      ],
    );
  }
}

/// Date input field.
class DateFieldRenderer extends StatefulWidget {
  final DynamicFormFieldState fieldState;
  final String? value;
  final ValueChanged<String?> onChanged;
  final VoidCallback onTouched;

  const DateFieldRenderer({
    super.key,
    required this.fieldState,
    required this.value,
    required this.onChanged,
    required this.onTouched,
  });

  @override
  State<DateFieldRenderer> createState() => _DateFieldRendererState();
}

class _DateFieldRendererState extends State<DateFieldRenderer> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    widget.onTouched();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );

    if (picked != null) {
      final formatted = picked.toIso8601String().split('T')[0]; // YYYY-MM-DD
      _controller.text = formatted;
      widget.onChanged(formatted);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(),
        const SizedBox(height: 8),
        InkWell(
          onTap: _selectDate,
          child: IgnorePointer(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Select date (YYYY-MM-DD)',
                suffixIcon: const Icon(Icons.calendar_today),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: widget.fieldState.hasError ? Colors.red : SaoColors.borderLight,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: widget.fieldState.hasError ? Colors.red : SaoColors.primary,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              style: SaoTypography.bodyMedium,
            ),
          ),
        ),
        if (widget.fieldState.hasError) ...[
          const SizedBox(height: 6),
          Text(
            widget.fieldState.error!,
            style: SaoTypography.bodySmall.copyWith(color: Colors.red),
          ),
        ],
      ],
    );
  }

  Widget _buildLabel() {
    return Row(
      children: [
        Text(widget.fieldState.fieldLabel, style: SaoTypography.labelMedium),
        if (widget.fieldState.required) ...[
          const SizedBox(width: 4),
          const Text('*', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        ],
      ],
    );
  }
}

/// Select (dropdown) field.
class SelectFieldRenderer extends StatefulWidget {
  final DynamicFormFieldState fieldState;
  final String? value;
  final ValueChanged<String?> onChanged;
  final VoidCallback onTouched;

  const SelectFieldRenderer({
    super.key,
    required this.fieldState,
    required this.value,
    required this.onChanged,
    required this.onTouched,
  });

  @override
  State<SelectFieldRenderer> createState() => _SelectFieldRendererState();
}

class _SelectFieldRendererState extends State<SelectFieldRenderer> {
  late List<Map<String, String>> options;

  @override
  void initState() {
    super.initState();
    options = CatalogFieldsRepository.parseOptions(
      widget.fieldState.metadata['optionsJson'] as String?,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: widget.fieldState.hasError ? Colors.red : SaoColors.borderLight,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButton<String>(
            isExpanded: true,
            value: widget.value,
            hint: Text(widget.fieldState.fieldLabel),
            onChanged: (String? newValue) {
              widget.onTouched();
              widget.onChanged(newValue);
            },
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            items: options
                .map((opt) => DropdownMenuItem<String>(
                      value: opt['value'] ?? '',
                      child: Text(
                        opt['label'] ?? opt['value'] ?? '',
                        style: SaoTypography.bodyMedium,
                      ),
                    ))
                .toList(),
          ),
        ),
        if (widget.fieldState.hasError) ...[
          const SizedBox(height: 6),
          Text(
            widget.fieldState.error!,
            style: SaoTypography.bodySmall.copyWith(color: Colors.red),
          ),
        ],
      ],
    );
  }

  Widget _buildLabel() {
    return Row(
      children: [
        Text(widget.fieldState.fieldLabel, style: SaoTypography.labelMedium),
        if (widget.fieldState.required) ...[
          const SizedBox(width: 4),
          const Text('*', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        ],
      ],
    );
  }
}

/// Multi-select field (checkboxes).
class MultiSelectFieldRenderer extends StatefulWidget {
  final DynamicFormFieldState fieldState;
  final String? value;
  final ValueChanged<String?> onChanged;
  final VoidCallback onTouched;

  const MultiSelectFieldRenderer({
    super.key,
    required this.fieldState,
    required this.value,
    required this.onChanged,
    required this.onTouched,
  });

  @override
  State<MultiSelectFieldRenderer> createState() => _MultiSelectFieldRendererState();
}

class _MultiSelectFieldRendererState extends State<MultiSelectFieldRenderer> {
  late List<Map<String, String>> options;
  late Set<String> selectedValues;

  @override
  void initState() {
    super.initState();
    options = CatalogFieldsRepository.parseOptions(
      widget.fieldState.metadata['optionsJson'] as String?,
    );
    selectedValues = (widget.value ?? '')
        .split(',')
        .where((v) => v.isNotEmpty)
        .map((v) => v.trim())
        .toSet();
  }

  void _updateSelection(String value, bool isSelected) {
    widget.onTouched();
    if (isSelected) {
      selectedValues.add(value);
    } else {
      selectedValues.remove(value);
    }

    widget.onChanged(selectedValues.join(','));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(),
        const SizedBox(height: 8),
        ...options.map((opt) {
          final value = opt['value'] ?? '';
          final label = opt['label'] ?? value;
          final isSelected = selectedValues.contains(value);

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: CheckboxListTile(
              value: isSelected,
              onChanged: (bool? newValue) {
                _updateSelection(value, newValue ?? false);
              },
              title: Text(label, style: SaoTypography.bodyMedium),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
            ),
          );
        }),
        if (widget.fieldState.hasError) ...[
          const SizedBox(height: 6),
          Text(
            widget.fieldState.error!,
            style: SaoTypography.bodySmall.copyWith(color: Colors.red),
          ),
        ],
      ],
    );
  }

  Widget _buildLabel() {
    return Row(
      children: [
        Text(widget.fieldState.fieldLabel, style: SaoTypography.labelMedium),
        if (widget.fieldState.required) ...[
          const SizedBox(width: 4),
          const Text('*', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        ],
      ],
    );
  }
}

/// Checkbox field (boolean type).
class CheckboxFieldRenderer extends StatefulWidget {
  final DynamicFormFieldState fieldState;
  final String? value;
  final ValueChanged<String?> onChanged;
  final VoidCallback onTouched;

  const CheckboxFieldRenderer({
    super.key,
    required this.fieldState,
    required this.value,
    required this.onChanged,
    required this.onTouched,
  });

  @override
  State<CheckboxFieldRenderer> createState() => _CheckboxFieldRendererState();
}

class _CheckboxFieldRendererState extends State<CheckboxFieldRenderer> {
  @override
  Widget build(BuildContext context) {
    final isChecked = widget.value == 'true' || widget.value == '1';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckboxListTile(
          value: isChecked,
          onChanged: (bool? newValue) {
            widget.onTouched();
            widget.onChanged((newValue ?? false) ? 'true' : 'false');
          },
          title: Text(widget.fieldState.fieldLabel, style: SaoTypography.labelMedium),
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
        if (widget.fieldState.hasError) ...[
          const SizedBox(height: 6),
          Text(
            widget.fieldState.error!,
            style: SaoTypography.bodySmall.copyWith(color: Colors.red),
          ),
        ],
      ],
    );
  }
}

/// Textarea field (multi-line text).
class TextAreaFieldRenderer extends StatefulWidget {
  final DynamicFormFieldState fieldState;
  final String? value;
  final ValueChanged<String?> onChanged;
  final VoidCallback onTouched;

  const TextAreaFieldRenderer({
    super.key,
    required this.fieldState,
    required this.value,
    required this.onChanged,
    required this.onTouched,
  });

  @override
  State<TextAreaFieldRenderer> createState() => _TextAreaFieldRendererState();
}

class _TextAreaFieldRendererState extends State<TextAreaFieldRenderer> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(),
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          onChanged: widget.onChanged,
          onTap: widget.onTouched,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: widget.fieldState.fieldLabel,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: widget.fieldState.hasError ? Colors.red : SaoColors.borderLight,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: widget.fieldState.hasError ? Colors.red : SaoColors.primary,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          style: SaoTypography.bodyMedium,
        ),
        if (widget.fieldState.hasError) ...[
          const SizedBox(height: 6),
          Text(
            widget.fieldState.error!,
            style: SaoTypography.bodySmall.copyWith(color: Colors.red),
          ),
        ],
      ],
    );
  }

  Widget _buildLabel() {
    return Row(
      children: [
        Text(widget.fieldState.fieldLabel, style: SaoTypography.labelMedium),
        if (widget.fieldState.required) ...[
          const SizedBox(width: 4),
          const Text('*', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        ],
      ],
    );
  }
}
