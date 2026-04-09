import 'package:flutter/material.dart';

/// Priority tier for visual grouping in home sections
enum SectionPriority {
  critical('CRITICAL', 'Action Required'),
  active('ACTIVE', 'Trabajo activo'),
  awaiting('AWAITING', 'Awaiting Decision');

  final String value;
  final String label;
  const SectionPriority(this.value, this.label);
}

/// Color scheme for section priorities
extension SectionPriorityColors on SectionPriority {
  Color get color {
    return switch (this) {
      SectionPriority.critical => const Color(0xFFEF4444), // Red
      SectionPriority.active => const Color(0xFF3B82F6), // Blue
      SectionPriority.awaiting => const Color(0xFF9CA3AF), // Gray
    };
  }

  Color get backgroundColor {
    return switch (this) {
      SectionPriority.critical => const Color(0xFFFEE2E2),
      SectionPriority.active => const Color(0xFFEFF6FF),
      SectionPriority.awaiting => const Color(0xFFF3F4F6),
    };
  }

  IconData get icon {
    return switch (this) {
      SectionPriority.critical => Icons.warning_rounded,
      SectionPriority.active => Icons.sync_rounded,
      SectionPriority.awaiting => Icons.schedule_rounded,
    };
  }
}

/// Metrics for a task section showing progress and urgency
class TaskSectionMetrics {
  /// Total number of items in this section
  final int totalCount;

  /// Number of items marked as completed within section
  /// (NOTE: not implemented yet, reserved for future use)
  final int completedCount;

  /// Average time an item spends in this section (if tracked)
  /// For now, calculated from creation timestamp to now
  final Duration? averageTimeInSection;

  /// Number of items that are overdue or critical
  /// (e.g., items in 'error_sync' or 'por_corregir' sections are always critical)
  final int criticalCount;

  /// Priority level for visual hierarchy
  final SectionPriority priority;

  /// Human-readable priority label ("Action Required", "Active Work", etc.)
  String get priorityLabel => priority.label;

  /// Completion percentage (0-100)
  double get completionPercent {
    if (totalCount == 0) return 0;
    return (completedCount / totalCount * 100);
  }

  /// Whether this section is empty
  bool get isEmpty => totalCount == 0;

  /// Whether this section has critical items that need attention
  bool get hasCriticalItems => criticalCount > 0;

  TaskSectionMetrics({
    required this.totalCount,
    required this.completedCount,
    required this.priority,
    this.averageTimeInSection,
    this.criticalCount = 0,
  }) : assert(totalCount >= 0 && completedCount >= 0 && completedCount <= totalCount);

  /// Factory to create metrics from section ID
  /// Maps nextAction categories to priorities
  factory TaskSectionMetrics.fromSectionId(
    String sectionId, {
    required int count,
    required int completedCount,
    Duration? averageTime,
    int criticalCount = 0,
  }) {
    final priority = _priorityForSectionId(sectionId);
    return TaskSectionMetrics(
      totalCount: count,
      completedCount: completedCount,
      priority: priority,
      averageTimeInSection: averageTime,
      criticalCount: criticalCount,
    );
  }

  @override
  String toString() => 'TaskSectionMetrics('
      'total=$totalCount, completed=$completedCount ($completionPercent%), '
      'priority=${priority.value}, critical=$criticalCount)';
}

/// Maps section IDs to priority tiers for visual hierarchy
SectionPriority _priorityForSectionId(String sectionId) {
  return switch (sectionId.toLowerCase()) {
    // TIER 1: ACTION REQUIRED (Red/Warning)
    'por_corregir' => SectionPriority.critical,
    'error_sync' => SectionPriority.critical,
    'por_completar' => SectionPriority.critical,

    // TIER 2: ACTIVE WORK (Blue/Primary)
    'por_iniciar' => SectionPriority.active,
    'en_curso' => SectionPriority.active,
    'pendiente_sync' => SectionPriority.active,

    // TIER 3: AWAITING DECISION (Gray/Secondary)
    'en_revision' => SectionPriority.awaiting,
    'cerrada_cancelada' => SectionPriority.awaiting,

    // Default
    _ => SectionPriority.awaiting,
  };
}

/// Extension to display metrics in human-readable format
extension TaskSectionMetricsDisplay on TaskSectionMetrics {
  /// Returns a formatted string like "3/7 (43%)"
  String get progressDisplay {
    if (totalCount == 0) return 'Vacío';
    return '$completedCount/$totalCount (${completionPercent.toStringAsFixed(0)}%)';
  }

  /// Returns time display like "Avg 2h 15m" or null if not available
  String? get timeDisplay {
    if (averageTimeInSection == null) return null;
    final hours = averageTimeInSection!.inHours;
    final minutes = averageTimeInSection!.inMinutes % 60;
    if (hours > 0) {
      return '⏱️ Prom ${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '⏱️ Prom ${minutes}m';
    }
    return null;
  }

  /// Badge text for display in header
  String get countBadge => totalCount.toString();

  /// Subtle hint about urgency
  String get urgencyHint {
    if (!hasCriticalItems && totalCount < 3) {
      return 'Bajo volumen';
    } else if (hasCriticalItems) {
      return '$criticalCount crítico${criticalCount > 1 ? 's' : ''}';
    }
    return '';
  }
}
