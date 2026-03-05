import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/catalog_repository.dart';

enum CatalogTab { activities, subcategories, purposes, topics, relations, results, assistants }

enum ActiveFilter { all, active, inactive }

enum CatalogSortField { id, name, active, order }

class CatalogSortSpec {
  final CatalogSortField field;
  final bool ascending;

  const CatalogSortSpec({
    this.field = CatalogSortField.name,
    this.ascending = true,
  });

  CatalogSortSpec copyWith({
    CatalogSortField? field,
    bool? ascending,
  }) {
    return CatalogSortSpec(
      field: field ?? this.field,
      ascending: ascending ?? this.ascending,
    );
  }
}

class CatalogTabUiState {
  final String query;
  final ActiveFilter activeFilter;
  final CatalogSortSpec sort;
  final bool reorderMode;
  final bool showSuggestedOnly;
  final String? selectedActivityId;
  final String? selectedSubcategoryId;
  final String? selectedTopicType;

  const CatalogTabUiState({
    this.query = '',
    this.activeFilter = ActiveFilter.all,
    this.sort = const CatalogSortSpec(),
    this.reorderMode = false,
    this.showSuggestedOnly = true,
    this.selectedActivityId,
    this.selectedSubcategoryId,
    this.selectedTopicType,
  });

  CatalogTabUiState copyWith({
    String? query,
    ActiveFilter? activeFilter,
    CatalogSortSpec? sort,
    bool? reorderMode,
    bool? showSuggestedOnly,
    String? selectedActivityId,
    bool clearSelectedActivityId = false,
    String? selectedSubcategoryId,
    bool clearSelectedSubcategoryId = false,
    String? selectedTopicType,
    bool clearSelectedTopicType = false,
  }) {
    return CatalogTabUiState(
      query: query ?? this.query,
      activeFilter: activeFilter ?? this.activeFilter,
      sort: sort ?? this.sort,
      reorderMode: reorderMode ?? this.reorderMode,
      showSuggestedOnly: showSuggestedOnly ?? this.showSuggestedOnly,
      selectedActivityId: clearSelectedActivityId
          ? null
          : (selectedActivityId ?? this.selectedActivityId),
      selectedSubcategoryId: clearSelectedSubcategoryId
          ? null
          : (selectedSubcategoryId ?? this.selectedSubcategoryId),
      selectedTopicType: clearSelectedTopicType
          ? null
          : (selectedTopicType ?? this.selectedTopicType),
    );
  }
}

class CatalogsPageState {
  final String selectedProject;
  final CatalogTab selectedTab;
  final Map<CatalogTab, CatalogTabUiState> uiByTab;
  final CatalogData catalog;
  final String? selectedRelationActivityId;
  final bool isLoading;
  final bool isMutating;
  final String? error;
  final DateTime? lastLoadedAt;

  const CatalogsPageState({
    required this.selectedProject,
    required this.selectedTab,
    required this.uiByTab,
    required this.catalog,
    required this.selectedRelationActivityId,
    required this.isLoading,
    required this.isMutating,
    required this.error,
    required this.lastLoadedAt,
  });

  CatalogTabUiState uiFor(CatalogTab tab) => uiByTab[tab] ?? const CatalogTabUiState();

  CatalogsPageState copyWith({
    String? selectedProject,
    CatalogTab? selectedTab,
    Map<CatalogTab, CatalogTabUiState>? uiByTab,
    CatalogData? catalog,
    String? selectedRelationActivityId,
    bool clearSelectedRelationActivityId = false,
    bool? isLoading,
    bool? isMutating,
    String? error,
    bool clearError = false,
    DateTime? lastLoadedAt,
  }) {
    return CatalogsPageState(
      selectedProject: selectedProject ?? this.selectedProject,
      selectedTab: selectedTab ?? this.selectedTab,
      uiByTab: uiByTab ?? this.uiByTab,
      catalog: catalog ?? this.catalog,
      selectedRelationActivityId: clearSelectedRelationActivityId
          ? null
          : (selectedRelationActivityId ?? this.selectedRelationActivityId),
      isLoading: isLoading ?? this.isLoading,
      isMutating: isMutating ?? this.isMutating,
      error: clearError ? null : (error ?? this.error),
      lastLoadedAt: lastLoadedAt ?? this.lastLoadedAt,
    );
  }
}

class CatalogsController extends StateNotifier<CatalogsPageState> {
  final CatalogRepository _repository;

  CatalogsController(this._repository)
      : super(
          CatalogsPageState(
            selectedProject: _repository.projectId,
            selectedTab: CatalogTab.activities,
            uiByTab: {
              for (final tab in CatalogTab.values) tab: const CatalogTabUiState(),
            },
            catalog: _repository.data,
            selectedRelationActivityId:
                _repository.data.activities.isNotEmpty ? _repository.data.activities.first.id : null,
            isLoading: false,
            isMutating: false,
            error: null,
            lastLoadedAt: null,
          ),
        ) {
    refresh();
  }

  void setProject(String projectId) {
    state = state.copyWith(selectedProject: projectId.trim().toUpperCase());
  }

  void setTab(CatalogTab tab) {
    state = state.copyWith(selectedTab: tab);
  }

  void updateQuery(CatalogTab tab, String query) {
    _updateTabUi(tab, state.uiFor(tab).copyWith(query: query));
  }

  void updateActiveFilter(CatalogTab tab, ActiveFilter filter) {
    _updateTabUi(tab, state.uiFor(tab).copyWith(activeFilter: filter));
  }

  void updateSort(CatalogTab tab, CatalogSortSpec sort) {
    _updateTabUi(tab, state.uiFor(tab).copyWith(sort: sort));
  }

  void updateActivityScope(CatalogTab tab, String? activityId) {
    final normalized = _normalizeNullable(activityId);
    _updateTabUi(
      tab,
      state.uiFor(tab).copyWith(
            selectedActivityId: normalized,
            clearSelectedActivityId: normalized == null,
            clearSelectedSubcategoryId: tab == CatalogTab.purposes,
          ),
    );
  }

  void updateSubcategoryScope(CatalogTab tab, String? subcategoryId) {
    final normalized = _normalizeNullable(subcategoryId);
    _updateTabUi(
      tab,
      state.uiFor(tab).copyWith(
            selectedSubcategoryId: normalized,
            clearSelectedSubcategoryId: normalized == null,
          ),
    );
  }

  void updateTopicTypeScope(CatalogTab tab, String? topicType) {
    final normalized = _normalizeNullable(topicType);
    _updateTabUi(
      tab,
      state.uiFor(tab).copyWith(
            selectedTopicType: normalized,
            clearSelectedTopicType: normalized == null,
          ),
    );
  }

  void toggleReorderMode() {
    final ui = state.uiFor(CatalogTab.activities);
    _updateTabUi(CatalogTab.activities, ui.copyWith(reorderMode: !ui.reorderMode));
  }

  void setShowSuggestedOnly(bool value) {
    final ui = state.uiFor(CatalogTab.relations);
    _updateTabUi(CatalogTab.relations, ui.copyWith(showSuggestedOnly: value));
  }

  void selectRelationActivity(String activityId) {
    state = state.copyWith(selectedRelationActivityId: activityId);
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repository.loadProject(state.selectedProject);
      _syncAfterDataChange();
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }

  Future<void> reorderActivities(List<String> orderedIds) async {
    await _mutate(() => _repository.reorder('activity', orderedIds));
  }

  Future<void> createActivity({
    required String id,
    required String name,
    String? description,
  }) async {
    await _mutate(() => _repository.createActivity(id: id, name: name, description: description));
  }

  Future<void> updateActivity(
    String id, {
    String? name,
    String? description,
    bool? isActive,
  }) async {
    await _mutate(
      () => _repository.updateActivity(id, name: name, description: description, isActive: isActive),
    );
  }

  Future<void> deleteActivity(String id) async {
    await _mutate(() => _repository.deleteActivity(id));
  }

  Future<void> restoreActivity(CatalogActivityItem item) async {
    await _mutate(() async {
      await _repository.createActivity(id: item.id, name: item.name, description: item.description);
      if (!item.isActive) {
        await _repository.updateActivity(item.id, isActive: false);
      }
    });
  }

  Future<void> createSubcategory({
    required String id,
    required String activityId,
    required String name,
    String? description,
  }) async {
    await _mutate(
      () => _repository.createSubcategory(
        id: id,
        activityId: activityId,
        name: name,
        description: description,
      ),
    );
  }

  Future<void> updateSubcategory(
    String id, {
    String? activityId,
    String? name,
    String? description,
    bool? isActive,
  }) async {
    await _mutate(
      () => _repository.updateSubcategory(
        id,
        activityId: activityId,
        name: name,
        description: description,
        isActive: isActive,
      ),
    );
  }

  Future<void> deleteSubcategory(String id) async {
    await _mutate(() => _repository.deleteSubcategory(id));
  }

  Future<void> restoreSubcategory(CatalogSubcategoryItem item) async {
    await _mutate(() async {
      await _repository.createSubcategory(
        id: item.id,
        activityId: item.activityId,
        name: item.name,
        description: item.description,
      );
      if (!item.isActive) {
        await _repository.updateSubcategory(item.id, isActive: false);
      }
    });
  }

  Future<void> createPurpose({
    required String id,
    required String activityId,
    String? subcategoryId,
    required String name,
  }) async {
    await _mutate(
      () => _repository.createPurpose(
        id: id,
        activityId: activityId,
        subcategoryId: subcategoryId,
        name: name,
      ),
    );
  }

  Future<void> updatePurpose(
    String id, {
    String? activityId,
    String? subcategoryId,
    String? name,
    bool? isActive,
  }) async {
    await _mutate(
      () => _repository.updatePurpose(
        id,
        activityId: activityId,
        subcategoryId: subcategoryId,
        name: name,
        isActive: isActive,
      ),
    );
  }

  Future<void> deletePurpose(String id) async {
    await _mutate(() => _repository.deletePurpose(id));
  }

  Future<void> restorePurpose(CatalogPurposeItem item) async {
    await _mutate(() async {
      await _repository.createPurpose(
        id: item.id,
        activityId: item.activityId,
        subcategoryId: item.subcategoryId,
        name: item.name,
      );
      if (!item.isActive) {
        await _repository.updatePurpose(item.id, isActive: false);
      }
    });
  }

  Future<void> createTopic({
    required String id,
    required String name,
    String? type,
    String? description,
  }) async {
    await _mutate(() => _repository.createTopic(id: id, name: name, type: type, description: description));
  }

  Future<void> updateTopic(
    String id, {
    String? name,
    String? type,
    String? description,
    bool? isActive,
  }) async {
    await _mutate(
      () => _repository.updateTopic(
        id,
        name: name,
        type: type,
        description: description,
        isActive: isActive,
      ),
    );
  }

  Future<void> deleteTopic(String id) async {
    await _mutate(() => _repository.deleteTopic(id));
  }

  Future<void> restoreTopic(CatalogTopicItem item) async {
    await _mutate(() async {
      await _repository.createTopic(
        id: item.id,
        name: item.name,
        type: item.type,
        description: item.description,
      );
      if (!item.isActive) {
        await _repository.updateTopic(item.id, isActive: false);
      }
    });
  }

  Future<void> createResult({
    required String id,
    required String category,
    required String name,
    String? description,
  }) async {
    await _mutate(
      () => _repository.createResult(
        id: id,
        category: category,
        name: name,
        description: description,
      ),
    );
  }

  Future<void> updateResult(
    String id, {
    String? category,
    String? name,
    String? description,
    bool? isActive,
  }) async {
    await _mutate(
      () => _repository.updateResult(
        id,
        category: category,
        name: name,
        description: description,
        isActive: isActive,
      ),
    );
  }

  Future<void> deleteResult(String id) async {
    await _mutate(() => _repository.deleteResult(id));
  }

  Future<void> restoreResult(CatalogResultItem item) async {
    await _mutate(() async {
      await _repository.createResult(
        id: item.id,
        category: item.category,
        name: item.name,
        description: item.description,
      );
      if (!item.isActive) {
        await _repository.updateResult(item.id, isActive: false);
      }
    });
  }

  Future<void> createAssistant({
    required String id,
    required String type,
    required String name,
    String? description,
  }) async {
    await _mutate(
      () => _repository.createAssistant(
        id: id,
        type: type,
        name: name,
        description: description,
      ),
    );
  }

  Future<void> updateAssistant(
    String id, {
    String? type,
    String? name,
    String? description,
    bool? isActive,
  }) async {
    await _mutate(
      () => _repository.updateAssistant(
        id,
        type: type,
        name: name,
        description: description,
        isActive: isActive,
      ),
    );
  }

  Future<void> deleteAssistant(String id) async {
    await _mutate(() => _repository.deleteAssistant(id));
  }

  Future<void> restoreAssistant(CatalogAssistantItem item) async {
    await _mutate(() async {
      await _repository.createAssistant(
        id: item.id,
        type: item.type,
        name: item.name,
        description: item.description,
      );
      if (!item.isActive) {
        await _repository.updateAssistant(item.id, isActive: false);
      }
    });
  }

  Future<void> addRelation(String activityId, String topicId) async {
    await _mutate(() => _repository.addRelation(activityId, topicId));
  }

  Future<void> deleteRelation(String activityId, String topicId) async {
    await _mutate(() => _repository.deleteRelation(activityId, topicId));
  }

  Future<void> restoreRelation(CatalogRelationItem item) async {
    await _mutate(() => _repository.addRelation(item.activityId, item.topicId));
  }

  Future<CatalogAdminHookResult> validateCatalogDraft() async {
    state = state.copyWith(isMutating: true, clearError: true);
    try {
      final result = await _repository.validateDraftCatalog();
      _syncAfterDataChange(isMutating: false);
      return result;
    } catch (error) {
      state = state.copyWith(isMutating: false, error: error.toString());
      return CatalogAdminHookResult(
        supported: false,
        success: false,
        message: error.toString(),
      );
    }
  }

  Future<CatalogAdminHookResult> publishCatalogDraft({String? notes}) async {
    state = state.copyWith(isMutating: true, clearError: true);
    try {
      final result = await _repository.publishDraftCatalog(notes: notes);
      _syncAfterDataChange(isMutating: false);
      return result;
    } catch (error) {
      state = state.copyWith(isMutating: false, error: error.toString());
      return CatalogAdminHookResult(
        supported: false,
        success: false,
        message: error.toString(),
      );
    }
  }

  Future<CatalogAdminHookResult> rollbackCatalogDraft() async {
    state = state.copyWith(isMutating: true, clearError: true);
    try {
      final result = await _repository.rollbackDraftCatalog();
      _syncAfterDataChange(isMutating: false);
      return result;
    } catch (error) {
      state = state.copyWith(isMutating: false, error: error.toString());
      return CatalogAdminHookResult(
        supported: false,
        success: false,
        message: error.toString(),
      );
    }
  }

  Future<void> _mutate(Future<void> Function() action) async {
    state = state.copyWith(isMutating: true, clearError: true);
    try {
      await action();
      _syncAfterDataChange(isMutating: false);
    } catch (error) {
      state = state.copyWith(isMutating: false, error: error.toString());
    }
  }

  void _syncAfterDataChange({bool isMutating = false}) {
    final data = _repository.data;
    final selected = state.selectedRelationActivityId;
    final selectedStillExists = selected != null && data.activities.any((entry) => entry.id == selected);
    final normalizedUiByTab = _normalizeUiByTab(state.uiByTab, data);

    state = state.copyWith(
      uiByTab: normalizedUiByTab,
      catalog: data,
      selectedRelationActivityId: selectedStillExists
          ? selected
          : (data.activities.isNotEmpty ? data.activities.first.id : null),
      isLoading: false,
      isMutating: isMutating,
      clearError: true,
      lastLoadedAt: DateTime.now(),
    );
  }

  void _updateTabUi(CatalogTab tab, CatalogTabUiState uiState) {
    final next = Map<CatalogTab, CatalogTabUiState>.from(state.uiByTab);
    next[tab] = uiState;
    state = state.copyWith(uiByTab: next);
  }

  Map<CatalogTab, CatalogTabUiState> _normalizeUiByTab(
    Map<CatalogTab, CatalogTabUiState> source,
    CatalogData data,
  ) {
    final next = Map<CatalogTab, CatalogTabUiState>.from(source);

    final subUi = next[CatalogTab.subcategories] ?? const CatalogTabUiState();
    final subActivity = subUi.selectedActivityId;
    if (subActivity != null && !data.activities.any((entry) => entry.id == subActivity)) {
      next[CatalogTab.subcategories] = subUi.copyWith(clearSelectedActivityId: true);
    }

    final purposeUi = next[CatalogTab.purposes] ?? const CatalogTabUiState();
    final purposeActivity = purposeUi.selectedActivityId;
    final purposeSubcategory = purposeUi.selectedSubcategoryId;

    final activityValid = purposeActivity == null || data.activities.any((entry) => entry.id == purposeActivity);
    final subcategoryValid = purposeSubcategory == null ||
        data.subcategories.any(
          (entry) =>
              entry.id == purposeSubcategory &&
              (purposeActivity == null || entry.activityId == purposeActivity),
        );

    next[CatalogTab.purposes] = purposeUi.copyWith(
      clearSelectedActivityId: !activityValid,
      clearSelectedSubcategoryId: !subcategoryValid || !activityValid,
    );

    final topicsUi = next[CatalogTab.topics] ?? const CatalogTabUiState();
    final topicType = topicsUi.selectedTopicType;
    if (topicType != null) {
      final typeStillExists = data.topics.any((entry) => (entry.type ?? '').trim() == topicType);
      if (!typeStillExists) {
        next[CatalogTab.topics] = topicsUi.copyWith(clearSelectedTopicType: true);
      }
    }

    return next;
  }

  String? _normalizeNullable(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

final catalogsControllerProvider =
    StateNotifierProvider<CatalogsController, CatalogsPageState>((ref) {
  final repository = ref.read(catalogRepositoryProvider);
  return CatalogsController(repository);
});
