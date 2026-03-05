import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/backend_api_client.dart';
import '../../features/auth/app_session_controller.dart';

class DashboardData {
  final int pendingCount;
  final int approvedToday;
  final int rejectedCount;
  final int needsFixCount;
  final int totalInQueue;
  final String projectId;
  final List<RecentActivityItem> recentItems;

  const DashboardData({
    required this.pendingCount,
    required this.approvedToday,
    required this.rejectedCount,
    required this.needsFixCount,
    required this.totalInQueue,
    required this.projectId,
    required this.recentItems,
  });

  double get avancePct {
    if (totalInQueue == 0) return 0;
    return approvedToday / totalInQueue;
  }
}

class RecentActivityItem {
  final String id;
  final String activityType;
  final String pk;
  final String front;
  final String status;
  final String createdAt;

  const RecentActivityItem({
    required this.id,
    required this.activityType,
    required this.pk,
    required this.front,
    required this.status,
    required this.createdAt,
  });
}

final dashboardProvider = FutureProvider.autoDispose<DashboardData>((ref) async {
  final client = const BackendApiClient();
  final user = ref.watch(currentAppUserProvider);

  try {
    final decoded = await client.getJson('/api/v1/dashboard/kpis') as Map<String, dynamic>?;
    if (decoded == null) return _empty(user);

    final counters = decoded['kpis'] as Map<String, dynamic>? ?? {};
    final items = decoded['recent_items'] as List<dynamic>? ?? const [];

    final pendingCount = (counters['pending_review'] as num?)?.toInt() ?? 0;
    final approvedToday = (counters['completed_today'] as num?)?.toInt() ?? 0;
    final rejectedCount = 0;
    final needsFixCount = (counters['in_progress'] as num?)?.toInt() ?? 0;

    // Get project from first item or user context
    final projectId = (decoded['project_id'] ?? 'N/A').toString();

    // Build recent items from latest 5
    final recent = items.take(5).map<RecentActivityItem>((raw) {
      final item = raw as Map<String, dynamic>;
      return RecentActivityItem(
        id: (item['id'] ?? '').toString(),
        activityType: (item['activity_type'] ?? 'Actividad').toString(),
        pk: (item['pk'] ?? '—').toString(),
        front: (item['front'] ?? 'Sin frente').toString(),
        status: (item['status'] ?? 'PENDIENTE_REVISION').toString(),
        createdAt: (item['created_at'] ?? '').toString(),
      );
    }).toList();

    return DashboardData(
      pendingCount: pendingCount,
      approvedToday: approvedToday,
      rejectedCount: rejectedCount,
      needsFixCount: needsFixCount,
      totalInQueue: (counters['total'] as num?)?.toInt() ??
          (pendingCount + approvedToday + rejectedCount + needsFixCount),
      projectId: projectId,
      recentItems: recent,
    );
  } catch (_) {
    return _empty(user);
  }
});

DashboardData _empty(dynamic user) => const DashboardData(
      pendingCount: 0,
      approvedToday: 0,
      rejectedCount: 0,
      needsFixCount: 0,
      totalInQueue: 0,
      projectId: 'N/A',
      recentItems: [],
    );
