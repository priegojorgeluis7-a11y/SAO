import 'package:flutter/material.dart';
import '../../../data/models/activity_model.dart';
import '../../../ui/theme/sao_colors.dart';
import '../../../core/theme/app_spacing.dart';

class ReviewActions extends StatelessWidget {
  final ActivityWithDetails? activity;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onSkip;

  const ReviewActions({
    super.key,
    required this.activity,
    required this.onApprove,
    required this.onReject,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = activity != null;

    return Container(
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: SaoColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: SaoColors.border),
      ),
      child: Row(
        children: [
          // Aprobar
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 56,
              child: FilledButton.icon(
                onPressed: enabled ? onApprove : null,
                style: FilledButton.styleFrom(
                  backgroundColor: SaoColors.success,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                ),
                icon: const Icon(Icons.check_circle_rounded, size: 24),
                label: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'APROBAR',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Enter',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(width: AppSpacing.md),
          
          // Rechazar
          Expanded(
            child: SizedBox(
              height: 56,
              child: OutlinedButton.icon(
                onPressed: enabled ? onReject : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: SaoColors.error,
                  side: BorderSide(color: SaoColors.error, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                ),
                icon: const Icon(Icons.cancel_rounded),
                label: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'RECHAZAR',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'R',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(width: AppSpacing.md),
          
          // Saltar
          SizedBox(
            width: 120,
            height: 56,
            child: OutlinedButton.icon(
              onPressed: enabled ? onSkip : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: SaoColors.gray700,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
              ),
              icon: const Icon(Icons.skip_next_rounded),
              label: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('SALTAR', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('Esc', style: TextStyle(fontSize: 11)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
