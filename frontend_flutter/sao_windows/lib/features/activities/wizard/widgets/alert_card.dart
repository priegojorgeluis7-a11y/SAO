// lib/features/activities/wizard/widgets/alert_card.dart
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.alertBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.alertBorder),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: AppColors.alertText, size: 20),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(message, style: AppTypography.alertText),
          ),
        ],
      ),
    );
  }
}
