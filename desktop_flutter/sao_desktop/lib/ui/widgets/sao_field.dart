// lib/ui/widgets/sao_field.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/sao_colors.dart';
import '../theme/sao_spacing.dart';
import '../theme/sao_radii.dart';

/// TextField mejorado y consistente para el SAO
class SaoField extends StatelessWidget {
  const SaoField({
    super.key,
    this.controller,
    this.initialValue,
    this.label,
    this.hint,
    this.helperText,
    this.icon,
    this.suffixIcon,
    this.prefixText,
    this.suffixText,
    this.validator,
    this.onChanged,
    this.onSaved,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.inputFormatters,
    this.autofocus = false,
    this.isDense = false,
    this.isEdited = false, // Marca visual si fue editado
  });

  final TextEditingController? controller;
  final String? initialValue;
  final String? label;
  final String? hint;
  final String? helperText;
  final IconData? icon;
  final Widget? suffixIcon;
  final String? prefixText;
  final String? suffixText;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String?>? onSaved;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final bool enabled;
  final bool readOnly;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final bool autofocus;
  final bool isDense;
  final bool isEdited;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      initialValue: initialValue,
      validator: validator,
      onChanged: onChanged,
      onSaved: onSaved,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      enabled: enabled,
      readOnly: readOnly,
      maxLines: maxLines,
      minLines: minLines,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      autofocus: autofocus,
      style: TextStyle(
        fontSize: 14,
        color: enabled ? SaoColors.textFor(context) : SaoColors.textMutedFor(context),
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helperText,
        prefixIcon: icon != null ? Icon(icon, size: 18) : null,
        suffixIcon: suffixIcon ?? _buildEditedIndicator(),
        prefixText: prefixText,
        suffixText: suffixText,
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
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SaoRadii.md),
          borderSide: const BorderSide(color: SaoColors.gray300),
        ),
        filled: true,
        fillColor: _getFillColor(context),
        contentPadding: EdgeInsets.symmetric(
          horizontal: SaoSpacing.lg,
          vertical: isDense ? SaoSpacing.sm : SaoSpacing.md,
        ),
        counterText: '', // Ocultar contador por defecto
      ),
    );
  }

  Color _getFillColor(BuildContext context) {
    if (!enabled) return SaoColors.surfaceRaisedFor(context);
    if (isEdited) return SaoColors.warning.withValues(alpha: 0.08);
    return SaoColors.surfaceFor(context);
  }

  Widget? _buildEditedIndicator() {
    if (!isEdited) return null;
    
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Chip(
        label: const Text(
          'Editado',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
        ),
        backgroundColor: SaoColors.warning.withValues(alpha: 0.2),
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

/// Campo de búsqueda especializado
class SaoSearchField extends StatelessWidget {
  const SaoSearchField({
    super.key,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.hint = 'Buscar...',
    this.autofocus = false,
  });

  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String hint;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      autofocus: autofocus,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: controller?.text.isNotEmpty == true
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  controller?.clear();
                  onChanged?.call('');
                },
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SaoRadii.lg),
          borderSide: const BorderSide(color: SaoColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SaoRadii.lg),
          borderSide: const BorderSide(color: SaoColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SaoRadii.lg),
          borderSide: const BorderSide(color: SaoColors.actionPrimary, width: 2),
        ),
        filled: true,
        fillColor: SaoColors.surfaceFor(context),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: SaoSpacing.lg,
          vertical: SaoSpacing.sm,
        ),
        isDense: true,
      ),
      style: const TextStyle(fontSize: 14),
    );
  }
}

/// Campo numérico con botones +/-
class SaoNumberField extends StatefulWidget {
  const SaoNumberField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.min,
    this.max,
    this.step = 1,
    this.decimals = 0,
    this.enabled = true,
  });

  final num value;
  final ValueChanged<num> onChanged;
  final String? label;
  final num? min;
  final num? max;
  final num step;
  final int decimals;
  final bool enabled;

  @override
  State<SaoNumberField> createState() => _SaoNumberFieldState();
}

class _SaoNumberFieldState extends State<SaoNumberField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _formatValue(widget.value));
  }

  @override
  void didUpdateWidget(SaoNumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _controller.text = _formatValue(widget.value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatValue(num value) {
    return widget.decimals > 0
        ? value.toStringAsFixed(widget.decimals)
        : value.toInt().toString();
  }

  void _increment() {
    final newValue = widget.value + widget.step;
    if (widget.max == null || newValue <= widget.max!) {
      widget.onChanged(newValue);
    }
  }

  void _decrement() {
    final newValue = widget.value - widget.step;
    if (widget.min == null || newValue >= widget.min!) {
      widget.onChanged(newValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: widget.enabled ? _decrement : null,
          icon: const Icon(Icons.remove_circle_outline),
          color: SaoColors.actionPrimary,
        ),
        Expanded(
          child: SaoField(
            controller: _controller,
            label: widget.label,
            keyboardType: TextInputType.numberWithOptions(
              decimal: widget.decimals > 0,
            ),
            textInputAction: TextInputAction.done,
            enabled: widget.enabled,
            onChanged: (value) {
              final parsed = widget.decimals > 0
                  ? double.tryParse(value)
                  : int.tryParse(value);
              if (parsed != null) {
                widget.onChanged(parsed);
              }
            },
          ),
        ),
        IconButton(
          onPressed: widget.enabled ? _increment : null,
          icon: const Icon(Icons.add_circle_outline),
          color: SaoColors.actionPrimary,
        ),
      ],
    );
  }
}
