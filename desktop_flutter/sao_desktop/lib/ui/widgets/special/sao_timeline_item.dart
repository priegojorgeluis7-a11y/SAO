// lib/ui/widgets/special/sao_timeline_item.dart
import 'package:flutter/material.dart';
import '../../theme/sao_colors.dart';
import '../../theme/sao_typography.dart';
import '../../theme/sao_spacing.dart';

/// Elemento de timeline para historial de actividades
/// 
/// Muestra eventos cronológicos con usuario, acción y timestamp.
class SaoTimelineItem extends StatelessWidget {
  final DateTime timestamp;
  final String user;
  final String action;
  final String? details;
  final String status;
  final IconData icon;
  final bool isFirst;
  final bool isLast;

  const SaoTimelineItem({
    super.key,
    required this.timestamp,
    required this.user,
    required this.action,
    this.details,
    required this.status,
    required this.icon,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = SaoColors.getStatusColor(status);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline visual
          Column(
            children: [
              if (!isFirst)
                Container(
                  width: 2,
                  height: 20,
                  color: SaoColors.border,
                ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.14),
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: SaoColors.border,
                  ),
                ),
            ],
          ),
          SizedBox(width: SaoSpacing.md),
          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: SaoSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(user, style: SaoTypography.bodyTextBold),
                      SizedBox(width: SaoSpacing.xs),
                      Text(action, style: SaoTypography.bodyText),
                    ],
                  ),
                  if (details != null) ...[
                    SizedBox(height: SaoSpacing.xs),
                    Text(details!, style: SaoTypography.hint),
                  ],
                  SizedBox(height: SaoSpacing.xs),
                  Text(
                    _formatTimestamp(timestamp),
                    style: SaoTypography.caption,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Hace menos de 1 min';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} horas';
    return 'Hace ${diff.inDays} días';
  }
}
