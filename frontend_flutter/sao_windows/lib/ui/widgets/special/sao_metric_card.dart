// lib/ui/widgets/special/sao_metric_card.dart
import 'package:flutter/material.dart';
import '../../theme/sao_colors.dart';
import '../../theme/sao_typography.dart';
import '../../theme/sao_spacing.dart';
import '../../theme/sao_radii.dart';
import '../../theme/sao_shadows.dart';

/// Tarjeta de métrica para Dashboard Desktop
/// 
/// Muestra KPIs con título, valor, subtítulo y trend indicator.
enum MetricTrend { up, down, neutral }

class SaoMetricCard extends StatefulWidget {
  final String title;
  final String value;
  final String? subtitle;
  final MetricTrend trend;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const SaoMetricCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.trend = MetricTrend.neutral,
    required this.icon,
    this.color = SaoColors.primary,
    this.onTap,
  });

  @override
  State<SaoMetricCard> createState() => _SaoMetricCardState();
}

class _SaoMetricCardState extends State<SaoMetricCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(SaoRadii.md),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(SaoSpacing.cardPadding),
          decoration: BoxDecoration(
            color: SaoColors.surface,
            borderRadius: BorderRadius.circular(SaoRadii.md),
            border: Border.all(
              color: _isHovered ? widget.color.withValues(alpha: 0.3) : SaoColors.border,
            ),
            boxShadow: _isHovered ? SaoShadows.md : SaoShadows.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(widget.title, style: SaoTypography.caption),
                  Icon(widget.icon, color: widget.color, size: 20),
                ],
              ),
              const SizedBox(height: SaoSpacing.sm),
              Text(
                widget.value,
                style: SaoTypography.metricValue.copyWith(color: widget.color),
              ),
              if (widget.subtitle != null) ...[
                const SizedBox(height: SaoSpacing.xs),
                Row(
                  children: [
                    _buildTrendIcon(),
                    const SizedBox(width: SaoSpacing.xs),
                    Text(
                      widget.subtitle!,
                      style: SaoTypography.caption.copyWith(
                        color: _getTrendColor(),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrendIcon() {
    switch (widget.trend) {
      case MetricTrend.up:
        return const Icon(Icons.arrow_upward, size: 14, color: SaoColors.success);
      case MetricTrend.down:
        return const Icon(Icons.arrow_downward, size: 14, color: SaoColors.error);
      default:
        return const Icon(Icons.remove, size: 14, color: SaoColors.gray400);
    }
  }

  Color _getTrendColor() {
    switch (widget.trend) {
      case MetricTrend.up:
        return SaoColors.success;
      case MetricTrend.down:
        return SaoColors.error;
      default:
        return SaoColors.gray500;
    }
  }
}
