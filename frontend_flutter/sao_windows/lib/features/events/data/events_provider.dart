// lib/features/events/data/events_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../../../data/local/app_db.dart';
import 'events_api_repository.dart';
import 'events_local_repository.dart';
import '../models/event_dto.dart';

// ─────────────────────────────────────────────
// Infrastructure providers
// ─────────────────────────────────────────────

final eventsApiRepositoryProvider = Provider<EventsApiRepository>(
  (ref) => GetIt.I<EventsApiRepository>(),
);

final eventsLocalRepositoryProvider = Provider<EventsLocalRepository>(
  (ref) => GetIt.I<EventsLocalRepository>(),
);

// ─────────────────────────────────────────────
// Events stream (per project)
// ─────────────────────────────────────────────

final eventsStreamProvider =
    StreamProvider.family<List<LocalEvent>, String>((ref, projectId) {
  final repo = ref.watch(eventsLocalRepositoryProvider);
  return repo.watchEvents(projectId);
});

// ─────────────────────────────────────────────
// Report Event Controller
// ─────────────────────────────────────────────

/// State for the report event flow
class ReportEventState {
  final bool isSubmitting;
  final bool success;
  final String? errorMessage;

  const ReportEventState({
    this.isSubmitting = false,
    this.success = false,
    this.errorMessage,
  });

  ReportEventState copyWith({
    bool? isSubmitting,
    bool? success,
    String? errorMessage,
  }) =>
      ReportEventState(
        isSubmitting: isSubmitting ?? this.isSubmitting,
        success: success ?? this.success,
        errorMessage: errorMessage,
      );
}

class ReportEventController extends StateNotifier<ReportEventState> {
  final EventsLocalRepository _localRepo;

  ReportEventController({required EventsLocalRepository localRepo})
      : _localRepo = localRepo,
        super(const ReportEventState());

  /// Submit a new event report.
  /// Saves locally + enqueues to sync_queue.
  Future<void> submit(EventDTO event) async {
    state = state.copyWith(isSubmitting: true, errorMessage: null);
    try {
      await _localRepo.saveEvent(event);
      state = state.copyWith(isSubmitting: false, success: true);
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Error al guardar: $e',
      );
    }
  }

  void reset() {
    state = const ReportEventState();
  }
}

final reportEventControllerProvider =
    StateNotifierProvider.autoDispose<ReportEventController, ReportEventState>(
  (ref) => ReportEventController(
    localRepo: ref.watch(eventsLocalRepositoryProvider),
  ),
);
