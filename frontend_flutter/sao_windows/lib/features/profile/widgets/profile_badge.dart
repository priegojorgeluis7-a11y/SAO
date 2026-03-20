import 'package:flutter/material.dart';
import '../../../ui/theme/sao_colors.dart';

class ProfileBadge extends StatelessWidget {
  final String label;
  final Color color;
  const ProfileBadge({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final textColor = color.computeLuminance() > 0.35 ? SaoColors.gray900 : SaoColors.onPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: textColor,
        ),
      ),
    );
  }
}
