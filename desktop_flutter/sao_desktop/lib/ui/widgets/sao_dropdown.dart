// lib/ui/widgets/sao_dropdown.dart
import 'package:flutter/material.dart';
import '../theme/sao_colors.dart';
import '../theme/sao_spacing.dart';
import '../theme/sao_radii.dart';

/// Dropdown mejorado y consistente para el SAO
class SaoDropdown<T> extends StatelessWidget {
  const SaoDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.label,
    this.hint,
    this.icon,
    this.validator,
    this.enabled = true,
    this.isDense = false,
  });

  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? label;
  final String? hint;
  final IconData? icon;
  final String? Function(T?)? validator;
  final bool enabled;
  final bool isDense;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: enabled ? onChanged : null,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon, size: 18) : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SaoRadii.md),
          borderSide: const BorderSide(color: SaoColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SaoRadii.md),
          borderSide: const BorderSide(color: SaoColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SaoRadii.md),
          borderSide: const BorderSide(color: SaoColors.actionPrimary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SaoRadii.md),
          borderSide: const BorderSide(color: SaoColors.error),
        ),
        filled: true,
        fillColor: enabled
          ? SaoColors.surfaceFor(context)
          : SaoColors.surfaceRaisedFor(context),
        contentPadding: EdgeInsets.symmetric(
          horizontal: SaoSpacing.lg,
          vertical: isDense ? SaoSpacing.sm : SaoSpacing.md,
        ),
      ),
      isDense: isDense,
      isExpanded: true,
      icon: Icon(Icons.arrow_drop_down, color: SaoColors.textMutedFor(context)),
      dropdownColor: SaoColors.surfaceFor(context),
      style: TextStyle(
        fontSize: 14,
        color: SaoColors.textFor(context),
      ),
    );
  }
}

/// Dropdown simple sin FormField (para uso sin formularios)
class SaoSimpleDropdown<T> extends StatelessWidget {
  const SaoSimpleDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
    this.icon,
    this.isDense = false,
  });

  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? hint;
  final IconData? icon;
  final bool isDense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: SaoSpacing.md,
        vertical: isDense ? SaoSpacing.xs : SaoSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: SaoColors.surfaceFor(context),
        border: Border.all(color: SaoColors.borderFor(context)),
        borderRadius: BorderRadius.circular(SaoRadii.md),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: SaoColors.gray600),
            Icon(icon, size: 16, color: SaoColors.textMutedFor(context)),
            const SizedBox(width: SaoSpacing.sm),
          ],
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                items: items,
                onChanged: onChanged,
                hint: hint != null
                    ? Text(
                        hint!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: SaoColors.gray500,
                        ),
                      )
                    : null,
                isDense: isDense,
                isExpanded: true,
                icon: const Icon(Icons.arrow_drop_down, size: 20),
                iconEnabledColor: SaoColors.textMutedFor(context),
                dropdownColor: SaoColors.surfaceFor(context),
                style: TextStyle(
                  fontSize: 14,
                  color: SaoColors.textFor(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dropdown multiselección (con chips)
class SaoMultiDropdown<T> extends StatefulWidget {
  const SaoMultiDropdown({
    super.key,
    required this.selectedValues,
    required this.items,
    required this.onChanged,
    this.label,
    this.hint = 'Seleccionar',
    this.icon,
    this.itemLabelBuilder,
  });

  final List<T> selectedValues;
  final List<T> items;
  final ValueChanged<List<T>> onChanged;
  final String? label;
  final String hint;
  final IconData? icon;
  final String Function(T)? itemLabelBuilder;

  @override
  State<SaoMultiDropdown<T>> createState() => _SaoMultiDropdownState<T>();
}

class _SaoMultiDropdownState<T> extends State<SaoMultiDropdown<T>> {
  bool _isOpen = false;

  String _getLabel(T item) {
    if (widget.itemLabelBuilder != null) {
      return widget.itemLabelBuilder!(item);
    }
    return item.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: SaoColors.gray700,
            ),
          ),
          const SizedBox(height: SaoSpacing.sm),
        ],
        InkWell(
          onTap: () => setState(() => _isOpen = !_isOpen),
          borderRadius: BorderRadius.circular(SaoRadii.md),
          child: Container(
            padding: const EdgeInsets.all(SaoSpacing.md),
            decoration: BoxDecoration(
              color: SaoColors.surfaceFor(context),
              border: Border.all(color: SaoColors.borderFor(context)),
              borderRadius: BorderRadius.circular(SaoRadii.md),
            ),
            child: Row(
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, size: 16, color: SaoColors.textMutedFor(context)),
                  const SizedBox(width: SaoSpacing.sm),
                ],
                Expanded(
                  child: widget.selectedValues.isEmpty
                      ? Text(
                          widget.hint,
                          style: const TextStyle(
                            fontSize: 14,
                            color: SaoColors.gray500,
                          ),
                        )
                      : Wrap(
                          spacing: SaoSpacing.xs,
                          runSpacing: SaoSpacing.xs,
                          children: widget.selectedValues.map((item) {
                            return Chip(
                              label: Text(
                                _getLabel(item),
                                style: const TextStyle(fontSize: 11),
                              ),
                              onDeleted: () {
                                final newList = List<T>.from(widget.selectedValues)
                                  ..remove(item);
                                widget.onChanged(newList);
                              },
                              deleteIconColor: SaoColors.gray600,
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            );
                          }).toList(),
                        ),
                ),
                Icon(
                  _isOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                  color: SaoColors.textMutedFor(context),
                ),
              ],
            ),
          ),
        ),
        if (_isOpen) ...[
          const SizedBox(height: SaoSpacing.xs),
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: SaoColors.surfaceFor(context),
              border: Border.all(color: SaoColors.borderFor(context)),
              borderRadius: BorderRadius.circular(SaoRadii.md),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.items.length,
              itemBuilder: (context, index) {
                final item = widget.items[index];
                final isSelected = widget.selectedValues.contains(item);
                
                return CheckboxListTile(
                  value: isSelected,
                  title: Text(_getLabel(item)),
                  dense: true,
                  onChanged: (checked) {
                    if (checked == true) {
                      widget.onChanged([...widget.selectedValues, item]);
                    } else {
                      final newList = List<T>.from(widget.selectedValues)
                        ..remove(item);
                      widget.onChanged(newList);
                    }
                  },
                  activeColor: SaoColors.actionPrimary,
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
