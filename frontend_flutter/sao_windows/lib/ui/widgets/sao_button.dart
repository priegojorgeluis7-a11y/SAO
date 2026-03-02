// lib/ui/widgets/sao_button.dart
import 'package:flutter/material.dart';
import '../theme/sao_colors.dart';
import '../theme/sao_radii.dart';
import '../theme/sao_spacing.dart';
import '../theme/sao_typography.dart';

/// Botones base reutilizables de SAO
/// Uso: SaoButton.primary(...), SaoButton.secondary(...), SaoButton.danger(...)

class SaoButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final _SaoButtonVariant _variant;

  const SaoButton.primary({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
  }) : _variant = _SaoButtonVariant.primary;

  const SaoButton.secondary({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
  }) : _variant = _SaoButtonVariant.secondary;

  const SaoButton.danger({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
  }) : _variant = _SaoButtonVariant.danger;

  const SaoButton.success({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
  }) : _variant = _SaoButtonVariant.success;

  @override
  Widget build(BuildContext context) {
    final colors = _getColors();

    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: colors.background,
        foregroundColor: colors.foreground,
        padding: const EdgeInsets.symmetric(
          horizontal: SaoSpacing.xxl,
          vertical: SaoSpacing.md,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SaoRadii.md),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLoading)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(colors.foreground),
              ),
            )
          else if (icon != null)
            Icon(icon, size: 18),
          if ((isLoading || icon != null) && label.isNotEmpty)
            const SizedBox(width: SaoSpacing.sm),
          if (label.isNotEmpty)
            Text(label, style: SaoTypography.buttonText),
        ],
      ),
    );
  }

  _ButtonColors _getColors() {
    switch (_variant) {
      case _SaoButtonVariant.primary:
        return _ButtonColors(
          background: SaoColors.primary,
          foreground: SaoColors.onPrimary,
        );
      case _SaoButtonVariant.secondary:
        return _ButtonColors(
          background: SaoColors.gray200,
          foreground: SaoColors.gray900,
        );
      case _SaoButtonVariant.danger:
        return _ButtonColors(
          background: SaoColors.error,
          foreground: Colors.white,
        );
      case _SaoButtonVariant.success:
        return _ButtonColors(
          background: SaoColors.success,
          foreground: Colors.white,
        );
    }
  }
}

enum _SaoButtonVariant { primary, secondary, danger, success }

class _ButtonColors {
  final Color background;
  final Color foreground;

  _ButtonColors({required this.background, required this.foreground});
}
