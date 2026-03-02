import '../database/app_database.dart';
import '../catalog/activity_status.dart';

class ActivityWithDetails {
  final Activity activity;
  final ActivityType? activityType;
  final User? assignedUser;
  final Front? front;
  final Municipality? municipality;
  final List<Evidence> evidences;

  ActivityWithDetails({
    required this.activity,
    this.activityType,
    this.assignedUser,
    this.front,
    this.municipality,
    required this.evidences,
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
