import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/project_providers.dart';
import '../../data/repositories/assignments_repository.dart';
import '../../data/repositories/backend_api_client.dart';

String _normalizedPlanningStatus(String status) {
  return status.trim().toLowerCase().replaceAll(' ', '_').replaceAll('-', '_');
}

bool _isVisiblePlanningAssignment(AssignmentItem item) {
  final normalized = _normalizedPlanningStatus(item.status);
  const hiddenStatuses = <String>{
    'cancelada',
    'cancelado',
    'cancelled',
    'canceled',
    'rechazada',
    'rechazado',
    'rejected',
    'eliminada',
    'eliminado',
    'deleted',
    'inactive',
    'inactiva',
    'inactivo',
  };
  return !hiddenStatuses.contains(normalized);
}

/// Provides today's assignments for the currently selected project.
final selectedPlanningDateProvider = StateProvider<DateTime>((ref) {
  return DateTime.now();
});

final planningAssignmentsProvider =
    FutureProvider.autoDispose<List<AssignmentItem>>((ref) async {
  final repo = ref.watch(assignmentsRepositoryProvider);
  final projectId = ref.watch(activeProjectIdProvider);
  final date = ref.watch(selectedPlanningDateProvider);

  if (projectId.isEmpty) return const [];
  final items = await repo.getForDate(projectId: projectId, date: date);
  return items.where(_isVisiblePlanningAssignment).toList(growable: false);
});

final planningMonthlyAssignmentsProvider =
    FutureProvider.autoDispose<List<AssignmentItem>>((ref) async {
  final repo = ref.watch(assignmentsRepositoryProvider);
  final projectId = ref.watch(activeProjectIdProvider);
  final date = ref.watch(selectedPlanningDateProvider);

  if (projectId.isEmpty) return const [];

  final start = DateTime(date.year, date.month, 1);
  final end = DateTime(date.year, date.month + 1, 0);
  final items = await repo.getForRange(projectId: projectId, from: start, to: end);
  return items.where(_isVisiblePlanningAssignment).toList(growable: false);
});

final planningReportActivityIdsProvider =
    FutureProvider.autoDispose<Set<String>>((ref) async {
  final projectId = ref.watch(activeProjectIdProvider).trim();
  if (projectId.isEmpty) return <String>{};

  try {
    const client = BackendApiClient();
    final decoded = await client.getJson(
      '/api/v1/completed-activities?project_id=${Uri.encodeQueryComponent(projectId)}',
    );
    if (decoded is! Map<String, dynamic>) return <String>{};
    final items = decoded['items'];
    if (items is! List) return <String>{};

    return items
        .whereType<Map<String, dynamic>>()
        .where((item) => (item['has_report'] as bool?) ?? false)
        .map((item) => (item['id'] ?? '').toString().trim())
        .where((id) => id.isNotEmpty)
        .toSet();
  } catch (_) {
    return <String>{};
  }
});
