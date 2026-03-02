// lib/ui/widgets/special/sao_role_badge.dart
import 'package:flutter/material.dart';
import '../../theme/sao_colors.dart';
import '../../theme/sao_typography.dart';
import '../../theme/sao_spacing.dart';
import '../../theme/sao_radii.dart';

/// Badge institucional de rol/permiso
/// 
/// Muestra rol del usuario con color e ícono distintivo.
enum BadgeSize { small, medium, large }

class SaoRoleBadge extends StatelessWidget {
  final String role;
  final BadgeSize size;

  const SaoRoleBadge({
    super.key,
    required this.role,
    this.size = BadgeSize.medium,
  });

  @override
  Widget build(BuildContext context) {
    final config = _getRoleConfig(role);
    final dimensions = _getDimensions(size);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dimensions.padding,
        vertical: dimensions.padding * 0.6,
      ),
      decoration: BoxDecoration(
        color: config.color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(SaoRadii.sm),
        border: Border.all(color: config.color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            config.icon,
            color: config.color,
            size: dimensions.iconSize,
          ),
          SizedBox(width: SaoSpacing.xs),
          Text(
            config.label,
            style: SaoTypography.badgeText.copyWith(
              color: config.color,
              fontSize: dimensions.fontSize,
            ),
          ),
        ],
      ),
    );
  }

  _RoleConfig _getRoleConfig(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return _RoleConfig(
          label: 'ADMIN',
          color: SaoColors.error,
          icon: Icons.shield,
        );
      case 'coordinador':
        return _RoleConfig(
          label: 'COORDINADOR',
          color: SaoColors.info,
          icon: Icons.star,
        );
      case 'supervisor':
        return _RoleConfig(
          label: 'SUPERVISOR',
          color: SaoColors.success,
          icon: Icons.check_circle,
        );
      default:
        return _RoleConfig(
          label: 'OPERATIVO',
          color: SaoColors.warning,
          icon: Icons.person,
        );
    }
  }

  _BadgeDimensions _getDimensions(BadgeSize size) {
    switch (size) {
      case BadgeSize.small:
        return _BadgeDimensions(padding: 4, iconSize: 12, fontSize: 10);
      case BadgeSize.large:
        return _BadgeDimensions(padding: 10, iconSize: 18, fontSize: 13);
      default:
        return _BadgeDimensions(padding: 6, iconSize: 14, fontSize: 11);
    }
  }
}

class _RoleConfig {
  final String label;
  final Color color;
  final IconData icon;

  _RoleConfig({
    required this.label,
    required this.color,
    required this.icon,
  });
}

class _BadgeDimensions {
  final double padding;
  final double iconSize;
  final double fontSize;

  _BadgeDimensions({
    required this.padding,
    required this.iconSize,
    required this.fontSize,
  });
}
