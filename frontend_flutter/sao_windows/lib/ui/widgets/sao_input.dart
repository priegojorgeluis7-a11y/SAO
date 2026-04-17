// lib/ui/widgets/sao_input.dart
import 'package:flutter/material.dart';
import '../theme/sao_colors.dart';
import '../theme/sao_radii.dart';
import '../theme/sao_spacing.dart';

/// Input reutilizable de SAO
/// Uso: SaoInput(label: '...', controller: ...)
class SaoInput extends StatelessWidget {
  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final int maxLines;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final bool readOnly;
  final VoidCallback? onTap;

  const SaoInput({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.maxLines = 1,
    this.obscureText = false,
    this.keyboardType,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.onChanged,
    this.readOnly = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
      readOnly: readOnly,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
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
          borderSide: const BorderSide(color: SaoColors.primary, width: 2),
        ),
        filled: true,
        fillColor: SaoColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: SaoSpacing.lg,
          vertical: SaoSpacing.md,
        ),
      ),
    );
  }
}
