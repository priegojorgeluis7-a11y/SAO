import 'package:flutter/material.dart';
import '../models/task_section_metrics.dart';

/// Enhanced section header showing metrics and priority
class TaskSectionHeader extends StatelessWidget {
  /// Display label like "Por Corregir"
  final String label;

  /// Number of items in this section
  final int itemCount;

  /// Metrics for this section (progress, priority, etc.)
  final TaskSectionMetrics metrics;

  /// Callback when tapped to expand/collapse
  final VoidCallback onTap;

  /// Whether section is currently expanded
  final bool isExpanded;

  /// Optional icon to override default
  final IconData? customIcon;

  const TaskSectionHeader({
    super.key,
    required this.label,
    required this.itemCount,
    required this.metrics,
    required this.onTap,
    required this.isExpanded,
    this.customIcon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: metrics.priority.backgroundColor,
        border: Border(
          left: BorderSide(
            color: metrics.priority.color,
            width: 4,
          ),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // Priority Icon
                Icon(
                  customIcon ?? metrics.priority.icon,
                  color: metrics.priority.color,
                  size: 20,
                ),
                const SizedBox(width: 8),

                // Title and Metadata
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Label with count
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              label,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                          // Count Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: metrics.priority.color,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              metrics.countBadge,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Metadata row: priority label + urgency hint
                      Row(
                        children: [
                          Text(
                            metrics.priorityLabel,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: metrics.priority.color,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (metrics.urgencyHint.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: metrics.hasCriticalItems
                                    ? Colors.red.withOpacity(0.1)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                metrics.urgencyHint,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: metrics.hasCriticalItems
                                      ? Colors.red.shade700
                                      : Colors.grey.shade600,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Expand/Collapse Chevron
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.expand_more_rounded,
                    color: metrics.priority.color,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Variant header showing progress bar
class TaskSectionHeaderWithProgress extends StatelessWidget {
  final String label;
  final int itemCount;
  final TaskSectionMetrics metrics;
  final VoidCallback onTap;
  final bool isExpanded;
  final IconData? customIcon;

  const TaskSectionHeaderWithProgress({
    super.key,
    required this.label,
    required this.itemCount,
    required this.metrics,
    required this.onTap,
    required this.isExpanded,
    this.customIcon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TaskSectionHeader(
          label: label,
          itemCount: itemCount,
          metrics: metrics,
          onTap: onTap,
          isExpanded: isExpanded,
          customIcon: customIcon,
        ),
        if (!isExpanded && metrics.totalCount > 0) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: metrics.completionPercent / 100,
                    minHeight: 4,
                    backgroundColor: metrics.priority.color.withOpacity(0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      metrics.priority.color,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        metrics.progressDisplay,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                    if (metrics.timeDisplay != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        metrics.timeDisplay!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
