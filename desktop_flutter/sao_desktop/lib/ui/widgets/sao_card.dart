// lib/ui/widgets/sao_card.dart
import 'package:flutter/material.dart';
import '../theme/sao_colors.dart';
import '../theme/sao_radii.dart';
import '../theme/sao_spacing.dart';
import '../theme/sao_shadows.dart';

/// Card base reutilizable de SAO
/// Uso: SaoCard(child: ...) en lugar de Card() o Container()
class SaoCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? color;
  final BorderSide? border;

  const SaoCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.color,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final cardContent = Container(
      decoration: BoxDecoration(
        color: color ?? SaoColors.surface,
        borderRadius: BorderRadius.circular(SaoRadii.lg),
        border: Border.fromBorderSide(
          border ?? const BorderSide(color: SaoColors.border),
        ),
        boxShadow: SaoShadows.cardShadow,
      ),
      padding: padding ?? const EdgeInsets.all(SaoSpacing.cardPadding),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(SaoRadii.lg),
          child: cardContent,
        ),
      );
    }

    return cardContent;
  }
}
