// lib/ui/widgets/sao_alert_card.dart
import 'package:flutter/material.dart';
import '../theme/sao_colors.dart';
import '../theme/sao_radii.dart';
import '../theme/sao_spacing.dart';
import '../theme/sao_typography.dart';

/// Tarjeta de alerta reutilizable de SAO
/// Uso: SaoAlertCard(message: '...', icon: Icons.warning)
class SaoAlertCard extends StatelessWidget {
  final String message;
  final IconData? icon;

  const SaoAlertCard({
    super.key,
    required this.message,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(SaoSpacing.md),
      decoration: BoxDecoration(
        color: SaoColors.alertBg,
        borderRadius: BorderRadius.circular(SaoRadii.md),
        border: Border.all(color: SaoColors.alertBorder),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: SaoColors.alertText, size: 20),
            const SizedBox(width: SaoSpacing.sm),
          ],
          Expanded(
            child: Text(message, style: SaoTypography.alertText),
          ),
        ],
      ),
    );
  }
}
