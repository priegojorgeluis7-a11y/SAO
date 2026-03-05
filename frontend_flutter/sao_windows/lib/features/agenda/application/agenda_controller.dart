import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/network/api_client.dart';
import '../../../data/local/app_db.dart';
import '../data/assignments_dao.dart';
import '../data/assignments_repository.dart';
import '../data/users_dao.dart';
import '../data/users_repository.dart';
import '../models/agenda_item.dart';
import '../models/resource.dart';

class AgendaState {
  final DateTime selectedDay;
  final int weekOffset;
  final String selectedFilterId;
  final List<Resource> resources;
  final List<AgendaItem> items;
  final bool loadingUsers;
  final String? usersError;

  const AgendaState({
    required this.selectedDay,
    required this.weekOffset,
    required this.selectedFilterId,
    required this.resources,
    required this.items,
    required this.loadingUsers,
    this.usersError,
  });

  factory AgendaState.initial() => AgendaState(
        selectedDay: DateTime.now(),
        weekOffset: 0,
        selectedFilterId: 'Todos',
        resources: const [],
        items: const [],
        loadingUsers: false,
      );

  AgendaState copyWith({
    DateTime? selectedDay,
    int? weekOffset,
    String? selectedFilterId,
    List<Resource>? resources,
    List<AgendaItem>? items,
    bool? loadingUsers,
    String? usersError,
  }) {
    return AgendaState(
      selectedDay: selectedDay ?? this.selectedDay,
      weekOffset: weekOffset ?? this.weekOffset,
      selectedFilterId: selectedFilterId ?? this.selectedFilterId,
      resources: resources ?? this.resources,
      items: items ?? this.items,
      loadingUsers: loadingUsers ?? this.loadingUsers,
      usersError: usersError,
    );
  }
}

class AgendaController extends StateNotifier<AgendaState> {
  AgendaController({
    required AgendaUsersRepository usersRepository,
    required AssignmentsRepository assignmentsRepository,
  })  : _usersRepository = usersRepository,
        _assignmentsRepository = assignmentsRepository,
        super(AgendaState.initial());

  final AgendaUsersRepository _usersRepository;
  final AssignmentsRepository _assignmentsRepository;
  String? _projectId;
  bool _isOffline = false;

  Future<void> initialize({
    String? projectId,
    required bool isOffline,
  }) async {
    _projectId = projectId;
    _isOffline = isOffline;
    state = state.copyWith(loadingUsers: true, usersError: null, items: const []);

    try {
      final resources = await _usersRepository.getOperationalUsers(
        projectId: projectId,
        isOffline: isOffline,
      );
      state = state.copyWith(
        resources: resources,
        loadingUsers: false,
        usersError: null,
      );
    } catch (e) {
      state = state.copyWith(
        loadingUsers: false,
        usersError: 'No se pudieron cargar los recursos operativos.',
      );
    }

    await _loadCurrentWeekAssignments();
  }

  Future<void> _loadCurrentWeekAssignments() async {
    if (_projectId == null || _projectId!.trim().isEmpty) {
      state = state.copyWith(items: const []);
      return;
    }

    final now = DateTime.now();
    final base = DateTime(now.year, now.month, now.day)
        .add(Duration(days: state.weekOffset * 7));
    final startOfWeek = base.subtract(Duration(days: (base.weekday - 1) % 7));
    final from = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    final to = from.add(const Duration(days: 7));

    final items = await _assignmentsRepository.loadRange(
      projectId: _projectId!,
      from: from,
      to: to,
      isOffline: _isOffline,
    );

    state = state.copyWith(items: items);
  }

  void changeWeek(int delta) {
    state = state.copyWith(weekOffset: state.weekOffset + delta);
    _loadCurrentWeekAssignments();
  }

  void selectDay(DateTime day) {
    state = state.copyWith(selectedDay: day);
    _loadCurrentWeekAssignments();
  }

  void changeFilter(String filterId) {
    state = state.copyWith(selectedFilterId: filterId);
  }

  void addAssignmentOptimistic(AgendaItem item) {
    state = state.copyWith(items: [...state.items, item]);
  }

  Future<void> createAssignmentFromDispatcher(AgendaItem item) async {
    addAssignmentOptimistic(item);
    await _assignmentsRepository.saveLocal(item);

    if (!_isOffline) {
      await _assignmentsRepository.pushOne(item);
    }

    await _loadCurrentWeekAssignments();
  }
}

final agendaUsersRepositoryProvider = Provider<AgendaUsersRepository>((ref) {
  return AgendaUsersRepository(
    apiClient: getIt<ApiClient>(),
    usersDao: UsersDao(getIt<AppDb>()),
  );
});

final assignmentsRepositoryProvider = Provider<AssignmentsRepository>((ref) {
  return AssignmentsRepository(
    apiClient: getIt<ApiClient>(),
    localStore: AssignmentsDao(getIt<AppDb>()),
  );
});

final agendaControllerProvider = StateNotifierProvider<AgendaController, AgendaState>((ref) {
  return AgendaController(
    usersRepository: ref.read(agendaUsersRepositoryProvider),
    assignmentsRepository: ref.read(assignmentsRepositoryProvider),
  );
});
