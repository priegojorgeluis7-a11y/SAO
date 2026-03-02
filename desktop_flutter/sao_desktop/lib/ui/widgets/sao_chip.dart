// lib/ui/widgets/sao_chip.dart
import 'package:flutter/material.dart';
import '../theme/sao_colors.dart';
import '../theme/sao_radii.dart';
import '../theme/sao_spacing.dart';
import '../theme/sao_typography.dart';

/// Chip reutilizable de SAO
/// Uso: SaoChip(label: '...', selected: true/false)
class SaoChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  const SaoChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(SaoRadii.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: SaoSpacing.md,
          vertical: SaoSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: selected 
              ? SaoColors.primary.withOpacity(0.12) 
              : SaoColors.gray50,
          borderRadius: BorderRadius.circular(SaoRadii.sm),
          border: Border.all(
            color: selected ? SaoColors.primary : SaoColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: selected ? SaoColors.primary : SaoColors.gray600,
              ),
              const SizedBox(width: SaoSpacing.xs),
            ],
            Text(
              label,
              style: SaoTypography.chipText.copyWith(
                color: selected ? SaoColors.primary : SaoColors.gray700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
