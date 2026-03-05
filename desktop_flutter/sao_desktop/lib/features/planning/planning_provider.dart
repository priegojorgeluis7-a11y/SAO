import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/project_providers.dart';
import '../../data/repositories/assignments_repository.dart';

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
  return repo.getForDate(projectId: projectId, date: date);
});
