import '../database/app_database.dart';
import '../catalog/activity_status.dart';

class ActivityWithDetails {
  final Activity activity;
  final ActivityType? activityType;
  final User? assignedUser;
  final Front? front;
  final Municipality? municipality;
  final List<Evidence> evidences;
  final ActivityFlags flags;

  ActivityWithDetails({
    required this.activity,
    this.activityType,
    this.assignedUser,
    this.front,
    this.municipality,
    required this.evidences,
    this.flags = const ActivityFlags(),
  });

  String get statusLabel {
    return ActivityStatus.getDisplayLabel(activity.status);
  }

  String get statusColor {
    switch (activity.status) {
      case ActivityStatus.pendingReview:
        return 'warning';
      case ActivityStatus.approved:
        return 'success';
      case ActivityStatus.rejected:
        return 'error';
      case ActivityStatus.needsFix:
        return 'info';
      default:
        return 'default';
    }
  }
}

class ActivityFlags {
  final bool gpsMismatch;
  final bool catalogChanged;
  final bool checklistIncomplete;

  const ActivityFlags({
    this.gpsMismatch = false,
    this.catalogChanged = false,
    this.checklistIncomplete = false,
  });
}

class ActivityTimelineEntry {
  final DateTime at;
  final String? actor;
  final String action;
  final Map<String, dynamic>? details;

  const ActivityTimelineEntry({
    required this.at,
    required this.actor,
    required this.action,
    required this.details,
  });
}
