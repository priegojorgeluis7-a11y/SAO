// lib/features/activities/wizard/widgets/hint_card.dart
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

class HintCard extends StatelessWidget {
  final String message;
  final IconData? icon;

  const HintCard({
    super.key,
    required this.message,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.gray100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: AppColors.gray600, size: 18),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(message, style: AppTypography.hint),
          ),
        ],
      ),
    );
  }
}
