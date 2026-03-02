// lib/core/widgets/risk_badge.dart
import 'package:flutter/material.dart';
import '../../ui/theme/sao_colors.dart';
import '../theme/app_spacing.dart';

/// Badge de nivel de riesgo - Diseño compartido móvil-desktop
class RiskBadge extends StatelessWidget {
  final String level; // 'bajo', 'medio', 'alto', 'prioritario'
  final bool showLabel;

  const RiskBadge({
    super.key,
    required this.level,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final config = _getRiskConfig(level);

    if (!showLabel) {
      return Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: config.color,
          shape: BoxShape.circle,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: config.bgColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(
          color: config.color.withOpacity(0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            config.emoji,
            style: const TextStyle(fontSize: 10),
          ),
          const SizedBox(width: 4),
          Text(
            config.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: config.color,
            ),
          ),
        ],
      ),
    );
  }

  _RiskConfig _getRiskConfig(String level) {
    switch (level.toLowerCase()) {
      case 'bajo':
      case 'low':
        return _RiskConfig(
          label: 'Bajo',
          emoji: '🟢',
          color: SaoColors.riskLow,
          bgColor: SaoColors.riskLow.withOpacity(0.12),
        );
      case 'medio':
      case 'medium':
        return _RiskConfig(
          label: 'Medio',
          emoji: '🟡',
          color: SaoColors.riskMedium,
          bgColor: SaoColors.riskMedium.withOpacity(0.12),
        );
      case 'alto':
      case 'high':
        return _RiskConfig(
          label: 'Alto',
          emoji: '🟠',
          color: SaoColors.riskHigh,
          bgColor: SaoColors.riskHigh.withOpacity(0.12),
        );
      case 'prioritario':
      case 'critical':
        return _RiskConfig(
          label: 'Prioritario',
          emoji: '🔴',
          color: SaoColors.riskPriority,
          bgColor: SaoColors.riskPriority.withOpacity(0.12),
        );
      default:
        return _RiskConfig(
          label: level,
          emoji: '⚪',
          color: SaoColors.gray600,
          bgColor: SaoColors.gray100,
        );
    }
  }
}

class _RiskConfig {
  final String label;
  final String emoji;
  final Color color;
  final Color bgColor;

  _RiskConfig({
    required this.label,
    required this.emoji,
    required this.color,
    required this.bgColor,
  });
}
