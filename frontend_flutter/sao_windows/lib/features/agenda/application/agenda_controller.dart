import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/logger.dart';
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
  /// true mientras se cargan asignaciones de la semana (red o local).
  final bool loadingAssignments;
  /// true mientras syncNow está en curso (usado para el ícono de cloud en AppBar).
  final bool isSyncing;
  /// true si el último syncNow terminó con error.
  final bool hasSyncError;
  final String? usersError;

  const AgendaState({
    required this.selectedDay,
    required this.weekOffset,
    required this.selectedFilterId,
    required this.resources,
    required this.items,
    required this.loadingUsers,
    this.loadingAssignments = false,
    this.isSyncing = false,
    this.hasSyncError = false,
    this.usersError,
  });

  factory AgendaState.initial() => AgendaState(
        selectedDay: DateTime.now(),
        weekOffset: 0,
        selectedFilterId: 'Todos',
        resources: const [],
        items: const [],
        loadingUsers: false,
        loadingAssignments: false,
        isSyncing: false,
        hasSyncError: false,
      );

  AgendaState copyWith({
    DateTime? selectedDay,
    int? weekOffset,
    String? selectedFilterId,
    List<Resource>? resources,
    List<AgendaItem>? items,
    bool? loadingUsers,
    bool? loadingAssignments,
    bool? isSyncing,
    bool? hasSyncError,
    String? usersError,
  }) {
    return AgendaState(
      selectedDay: selectedDay ?? this.selectedDay,
      weekOffset: weekOffset ?? this.weekOffset,
      selectedFilterId: selectedFilterId ?? this.selectedFilterId,
      resources: resources ?? this.resources,
      items: items ?? this.items,
      loadingUsers: loadingUsers ?? this.loadingUsers,
      loadingAssignments: loadingAssignments ?? this.loadingAssignments,
      isSyncing: isSyncing ?? this.isSyncing,
      hasSyncError: hasSyncError ?? this.hasSyncError,
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
  Resource? _selfResource;

  Future<void> initialize({
    String? projectId,
    required bool isOffline,
    Resource? selfResource,
  }) async {
    _projectId = projectId;
    _isOffline = isOffline;
    _selfResource = selfResource;
    state = state.copyWith(loadingUsers: true, usersError: null, items: const []);

    try {
      final fetched = await _usersRepository.getOperationalUsers(
        projectId: projectId,
        isOffline: isOffline,
      );
      final resources = _withSelfFirst(fetched, selfResource);
      final selectedFilterId = _resolveFilterSelection(
        currentFilterId: state.selectedFilterId,
        resources: resources,
        selfResource: selfResource,
        preferSelf: true,
      );
      appLogger.i(
        'AgendaController.initialize resources=${resources.length} '
        'project=$projectId offline=$isOffline',
      );
      state = state.copyWith(
        selectedFilterId: selectedFilterId,
        resources: resources,
        loadingUsers: false,
        usersError: null,
      );
    } catch (e) {
      appLogger.e('AgendaController.initialize users load error: $e');
      final fallbackResources = _withSelfFirst(const [], selfResource);
      final selectedFilterId = _resolveFilterSelection(
        currentFilterId: state.selectedFilterId,
        resources: fallbackResources,
        selfResource: selfResource,
        preferSelf: true,
      );
      state = state.copyWith(
        selectedFilterId: selectedFilterId,
        resources: fallbackResources,
        loadingUsers: false,
        usersError: 'No se pudieron cargar los recursos operativos.',
      );
    }

    await _loadCurrentWeekAssignments();
  }

  Future<void> _loadCurrentWeekAssignments() async {
    if (_projectId == null || _projectId!.trim().isEmpty) {
      state = state.copyWith(items: const [], loadingAssignments: false);
      return;
    }

    state = state.copyWith(loadingAssignments: true);

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

    state = state.copyWith(items: items, loadingAssignments: false);
  }

  /// Avanza o retrocede [delta] semanas.
  /// Actualiza [selectedDay] al día equivalente en la nueva semana para que
  /// el strip siempre tenga un día seleccionado válido.
  /// Se hace await explícito para evitar condiciones de carrera si el usuario
  /// cambia semana varias veces rápido.
  Future<void> changeWeek(int delta) async {
    final newOffset = state.weekOffset + delta;
    // Desplazar el día seleccionado la misma cantidad de semanas
    final newSelectedDay =
        state.selectedDay.add(Duration(days: delta * 7));
    state = state.copyWith(
      weekOffset: newOffset,
      selectedDay: newSelectedDay,
    );
    await _loadCurrentWeekAssignments();
  }

  /// Cambia el día seleccionado dentro de la semana actual.
  /// No recarga asignaciones: ya están en memoria para toda la semana.
  void selectDay(DateTime day) {
    state = state.copyWith(selectedDay: day);
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

  /// Vuelve a la semana actual y selecciona hoy.
  Future<void> goToToday() async {
    state = state.copyWith(
      weekOffset: 0,
      selectedDay: DateTime.now(),
    );
    await _loadCurrentWeekAssignments();
  }

  Future<void> refresh() async {
    await _loadCurrentWeekAssignments();
  }

  /// Cancela una asignación localmente.
  /// - Si está pendiente/en error: la elimina sin necesitar red.
  /// - Si ya fue sincronizada: la elimina del caché local; el próximo sync
  ///   la restaurará desde el servidor (la cancelación en servidor debe
  ///   gestionarse con el despachador).
  Future<void> cancelAssignment(AgendaItem item) async {
    // Eliminar optimistamente de la UI
    state = state.copyWith(
      items: state.items.where((i) => i.id != item.id).toList(),
    );
    await _assignmentsRepository.deleteLocal(item.id);
    appLogger.i(
      'AgendaController.cancelAssignment id=${item.id} '
      'syncStatus=${item.syncStatus}',
    );
  }

  /// Verifica que los recursos estén cargados; si no, los carga ahora.
  /// Guard antes de abrir el dispatcher para evitar retry manual en la UI.
  Future<void> ensureResourcesReady({required String? projectId}) async {
    if (state.resources.isNotEmpty || state.loadingUsers) return;
    if (projectId == null || projectId.trim().isEmpty) return;
    appLogger.i('AgendaController.ensureResourcesReady retry project=$projectId');
    await initialize(projectId: projectId, isOffline: false, selfResource: _selfResource);
  }

  /// Guarantees the logged user is present in resources.
  /// Useful when auth user arrives after initial agenda load.
  void ensureSelfResource(Resource? selfResource) {
    if (selfResource == null) return;
    _selfResource = selfResource;
    final updated = _withSelfFirst(state.resources, selfResource);
    final selectedFilterId = _resolveFilterSelection(
      currentFilterId: state.selectedFilterId,
      resources: updated,
      selfResource: selfResource,
      preferSelf: state.selectedFilterId == 'Todos',
    );
    if (_sameResourceOrder(updated, state.resources) &&
        selectedFilterId == state.selectedFilterId) {
      return;
    }
    state = state.copyWith(
      resources: updated,
      selectedFilterId: selectedFilterId,
    );
  }

  static String _resolveFilterSelection({
    required String currentFilterId,
    required List<Resource> resources,
    required Resource? selfResource,
    required bool preferSelf,
  }) {
    final activeIds = resources.where((resource) => resource.isActive).map((resource) => resource.id).toSet();
    final selfId = selfResource?.id;

    if (preferSelf && selfId != null && activeIds.contains(selfId)) {
      return selfId;
    }

    if (currentFilterId == 'Todos') {
      return 'Todos';
    }

    if (activeIds.contains(currentFilterId)) {
      return currentFilterId;
    }

    if (selfId != null && activeIds.contains(selfId)) {
      return selfId;
    }

    return 'Todos';
  }

  static bool _sameResourceOrder(List<Resource> a, List<Resource> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  /// Garantiza que [self] aparezca primero en la lista.
  /// Si ya está presente (mismo id), solo lo mueve al frente.
  static List<Resource> _withSelfFirst(List<Resource> resources, Resource? self) {
    if (self == null) return resources;
    final without = resources.where((r) => r.id != self.id).toList();
    return [self, ...without];
  }

  Future<void> syncNow() async {
    if (_projectId == null || _projectId!.trim().isEmpty) return;

    state = state.copyWith(isSyncing: true, hasSyncError: false);
    try {
      if (!_isOffline) {
        await _assignmentsRepository.syncPending(projectId: _projectId);
      }
      await _loadCurrentWeekAssignments();
      state = state.copyWith(isSyncing: false, hasSyncError: false);
    } catch (e) {
      appLogger.e('AgendaController.syncNow error: $e');
      state = state.copyWith(isSyncing: false, hasSyncError: true);
      rethrow;
    }
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
    database: getIt<AppDb>(),
  );
});

final agendaControllerProvider = StateNotifierProvider<AgendaController, AgendaState>((ref) {
  return AgendaController(
    usersRepository: ref.read(agendaUsersRepositoryProvider),
    assignmentsRepository: ref.read(assignmentsRepositoryProvider),
  );
});
