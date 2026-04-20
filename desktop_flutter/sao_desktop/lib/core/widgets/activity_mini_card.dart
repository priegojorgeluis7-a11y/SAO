// lib/core/widgets/activity_mini_card.dart
import 'package:flutter/material.dart';
import '../../ui/theme/sao_colors.dart';
import '../theme/app_typography.dart';
import '../theme/app_spacing.dart';
import 'package:intl/intl.dart';
import '../../data/catalog/activity_status.dart';

/// Mini card para lista de actividades - Diseño compartido móvil-desktop
class ActivityMiniCard extends StatelessWidget {
  final String id;
  final String title;
  final String? subtitle;
  final String status;
  final DateTime? date;
  final bool isSelected;
  final VoidCallback? onTap;
  final Color? riskColor;

  const ActivityMiniCard({
    super.key,
    required this.id,
    required this.title,
    this.subtitle,
    required this.status,
    this.date,
    this.isSelected = false,
    this.onTap,
    this.riskColor,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(status);
    final df = DateFormat('dd/MM HH:mm', 'es');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: (riskColor ?? statusColor).withValues(
                alpha: isSelected ? 0.35 : 0.18,
              ),
              width: isSelected ? 1.4 : 1,
            ),
            color: isSelected
                ? SaoColors.primary.withValues(alpha: 0.06)
                : SaoColors.surface,
          ),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.cardPadding,
            AppSpacing.sm + 2,
            AppSpacing.cardPadding,
            AppSpacing.sm + 2,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      id,
                      style: AppTypography.mono.copyWith(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (date != null)
                    Text(
                      df.format(date!),
                      style: AppTypography.caption.copyWith(fontSize: 10),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyTextBold.copyWith(fontSize: 13),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    final normalizedStatus = ActivityStatus.normalize(status);
    
    switch (normalizedStatus) {
      case ActivityStatus.pendingReview:
        return SaoColors.statusPendiente;
      case ActivityStatus.approved:
        return SaoColors.statusAprobado;
      case ActivityStatus.rejected:
        return SaoColors.statusRechazado;
      case ActivityStatus.needsFix:
        return SaoColors.riskHigh;
      default:
        return SaoColors.gray400;
    }
  }
}
