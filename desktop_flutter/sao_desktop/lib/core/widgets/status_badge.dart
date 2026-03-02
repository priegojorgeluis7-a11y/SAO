// lib/core/widgets/status_badge.dart
import 'package:flutter/material.dart';
import '../../ui/theme/sao_colors.dart';
import '../theme/app_typography.dart';
import '../theme/app_spacing.dart';
import '../../data/catalog/activity_status.dart';

/// Badge de estado de actividad - Diseño compartido móvil-desktop
class StatusBadge extends StatelessWidget {
  final String status;
  final bool small;

  const StatusBadge({
    super.key,
    required this.status,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final config = _getStatusConfig(status);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? AppSpacing.sm : AppSpacing.md,
        vertical: small ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: config.bgColor,
        borderRadius: BorderRadius.circular(small ? 16 : 20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            config.icon,
            size: small ? 12 : 14,
            color: config.color,
          ),
          SizedBox(width: small ? 4 : 6),
          Text(
            config.label,
            style: AppTypography.badgeText.copyWith(
              fontSize: small ? 10 : 11,
              color: config.color,
            ),
          ),
        ],
      ),
    );
  }

  _StatusConfig _getStatusConfig(String status) {
    final normalizedStatus = ActivityStatus.normalize(status);
    
    switch (normalizedStatus) {
      case ActivityStatus.pendingReview:
        return _StatusConfig(
          label: 'PENDIENTE',
          icon: Icons.pending_actions_rounded,
          color: SaoColors.statusPendiente,
          bgColor: SaoColors.statusPendiente.withOpacity(0.12),
        );
      case ActivityStatus.approved:
        return _StatusConfig(
          label: 'APROBADA',
          icon: Icons.check_circle_rounded,
          color: SaoColors.statusAprobado,
          bgColor: SaoColors.statusAprobado.withOpacity(0.12),
        );
      case ActivityStatus.rejected:
        return _StatusConfig(
          label: 'RECHAZADA',
          icon: Icons.cancel_rounded,
          color: SaoColors.statusRechazado,
          bgColor: SaoColors.statusRechazado.withOpacity(0.12),
        );
      case ActivityStatus.needsFix:
        return _StatusConfig(
          label: 'REQUIERE FIX',
          icon: Icons.build_circle_rounded,
          color: SaoColors.riskHigh,
          bgColor: SaoColors.riskHigh.withOpacity(0.12),
        );
      case ActivityStatus.corrected:
        return _StatusConfig(
          label: 'CORREGIDA',
          icon: Icons.build_circle_rounded,
          color: SaoColors.info,
          bgColor: SaoColors.info.withOpacity(0.12),
        );
      case ActivityStatus.conflict:
        return _StatusConfig(
          label: 'PENDIENTE',
          icon: Icons.warning_amber_rounded,
          color: SaoColors.warning,
          bgColor: SaoColors.warning.withOpacity(0.12),
        );
      default:
        return _StatusConfig(
          label: status,
          icon: Icons.circle,
          color: SaoColors.gray600,
          bgColor: SaoColors.gray100,
        );
    }
  }
}

class _StatusConfig {
  final String label;
  final IconData icon;
  final Color color;
  final Color bgColor;

  _StatusConfig({
    required this.label,
    required this.icon,
    required this.color,
    required this.bgColor,
  });
}
