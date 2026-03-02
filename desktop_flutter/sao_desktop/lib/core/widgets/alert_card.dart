// lib/core/widgets/alert_card.dart
import 'package:flutter/material.dart';
import '../../ui/theme/sao_colors.dart';
import '../theme/app_typography.dart';
import '../theme/app_spacing.dart';

/// Card de alerta (warning) - Diseño compartido móvil-desktop
class AlertCard extends StatelessWidget {
  final String message;
  final IconData? icon;

  const AlertCard({
    super.key,
    required this.message,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: SaoColors.alertBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SaoColors.alertBorder),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: SaoColors.alertText, size: 20),
            const SizedBox(width: AppSpacing.sm + 2),
          ],
          Expanded(
            child: Text(message, style: AppTypography.alertText),
          ),
        ],
      ),
    );
  }
}
