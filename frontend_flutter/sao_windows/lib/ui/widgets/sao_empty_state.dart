// lib/ui/widgets/sao_empty_state.dart
import 'package:flutter/material.dart';
import '../theme/sao_colors.dart';
import '../theme/sao_spacing.dart';
import '../theme/sao_typography.dart';

/// Estado vacío reutilizable de SAO
/// Uso: SaoEmptyState(icon: Icons.inbox, message: '...')
class SaoEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? subtitle;

  const SaoEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: SaoColors.gray400.withValues(alpha: 0.5),
          ),
          const SizedBox(height: SaoSpacing.lg),
          Text(
            message,
            style: SaoTypography.bodyTextBold.copyWith(
              color: SaoColors.gray600,
            ),
            textAlign: TextAlign.center,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: SaoSpacing.xs),
            Text(
              subtitle!,
              style: SaoTypography.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
