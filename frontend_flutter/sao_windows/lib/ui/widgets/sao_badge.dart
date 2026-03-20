// lib/ui/widgets/sao_badge.dart
import 'package:flutter/material.dart';
import '../helpers/sao_contrast.dart';
import '../theme/sao_colors.dart';
import '../theme/sao_radii.dart';
import '../theme/sao_spacing.dart';
import '../theme/sao_typography.dart';

/// Badge reutilizable de SAO (riesgo, estatus)
/// Uso: SaoBadge.risk('low'), SaoBadge.status('pending')
class SaoBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color backgroundColor;

  const SaoBadge({
    super.key,
    required this.label,
    required this.color,
    required this.backgroundColor,
  });

  factory SaoBadge.risk(String risk) {
    return SaoBadge(
      label: _getRiskLabel(risk),
      color: SaoColors.getRiskColor(risk),
      backgroundColor: SaoColors.getRiskBackground(risk),
    );
  }

  factory SaoBadge.status(String status) {
    final colors = _getStatusColors(status);
    return SaoBadge(
      label: status.toUpperCase(),
      color: colors.$1,
      backgroundColor: colors.$2,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textColor = SaoContrast.getContrastColor(backgroundColor);
    
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SaoSpacing.sm,
        vertical: SaoSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(SaoRadii.sm),
      ),
      child: Text(
        label,
        style: SaoTypography.badgeText.copyWith(color: textColor),
      ),
    );
  }

  static String _getRiskLabel(String risk) {
    switch (risk.toLowerCase()) {
      case 'low':
      case 'bajo':
        return 'BAJO';
      case 'medium':
      case 'medio':
        return 'MEDIO';
      case 'high':
      case 'alto':
        return 'ALTO';
      case 'critical':
      case 'critico':
      case 'crítico':
        return 'CRÍTICO';
      default:
        return risk.toUpperCase();
    }
  }

  static (Color, Color) _getStatusColors(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'pendiente':
        return (SaoColors.warning, SaoColors.warning.withValues(alpha: 0.14));
      case 'approved':
      case 'aprobado':
        return (SaoColors.success, SaoColors.success.withValues(alpha: 0.14));
      case 'rejected':
      case 'rechazado':
        return (SaoColors.error, SaoColors.error.withValues(alpha: 0.14));
      default:
        return (SaoColors.gray600, SaoColors.gray100);
    }
  }
}
