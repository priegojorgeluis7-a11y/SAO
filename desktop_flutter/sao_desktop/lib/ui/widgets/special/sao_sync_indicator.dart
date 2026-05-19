// lib/ui/widgets/special/sao_sync_indicator.dart
import 'package:flutter/material.dart';
import '../../theme/sao_colors.dart';
import '../../theme/sao_spacing.dart';
import '../../theme/sao_typography.dart';

/// Indicador global de estado de sincronización offline/online
/// 
/// Muestra estado de conectividad, cambios pendientes y última sincronización.
class SaoSyncIndicator extends StatelessWidget {
  final bool isOnline;
  final int pendingCount;
  final DateTime? lastSyncTime;
  final VoidCallback? onTap;

  const SaoSyncIndicator({
    super.key,
    required this.isOnline,
    this.pendingCount = 0,
    this.lastSyncTime,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isOnline 
      ? (pendingCount > 0 ? SaoColors.warning : SaoColors.success)
      : SaoColors.error;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: SaoSpacing.sm,
          vertical: SaoSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isOnline ? Icons.cloud_done : Icons.cloud_off,
              color: color,
              size: 18,
            ),
            if (pendingCount > 0) ...[
              const SizedBox(width: SaoSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$pendingCount',
                  style: SaoTypography.caption.copyWith(
                    color: Colors.white,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
