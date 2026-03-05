// lib/features/activities/wizard/widgets/risk_selector.dart
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../wizard_controller.dart';

class RiskSelector extends StatelessWidget {
  final WizardController controller;

  const RiskSelector({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildRiskButton(
          label: '🟢 Bajo',
          level: RiskLevel.bajo,
          color: AppColors.riskLow,
        ),
        const SizedBox(width: 8),
        _buildRiskButton(
          label: '🟡 Medio',
          level: RiskLevel.medio,
          color: AppColors.riskMedium,
        ),
        const SizedBox(width: 8),
        _buildRiskButton(
          label: '🟠 Alto',
          level: RiskLevel.alto,
          color: AppColors.riskHigh,
        ),
        const SizedBox(width: 8),
        _buildRiskButton(
          label: '🔴 Prioritario',
          level: RiskLevel.prioritario,
          color: AppColors.riskCritical,
        ),
      ],
    );
  }

  Widget _buildRiskButton({
    required String label,
    required RiskLevel level,
    required Color color,
  }) {
    final selected = controller.risk == level;
    
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => controller.setRisk(level),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.14) : AppColors.gray50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? color.withOpacity(0.6) : AppColors.border,
            ),
          ),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w900,
                color: selected ? color : AppColors.gray700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
