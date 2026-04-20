import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/project_providers.dart';
import '../../data/repositories/catalog_repository.dart';
import 'catalogs_controller.dart';

Color _readableForeground(Color background) {
  return background.computeLuminance() > 0.5 ? Colors.black : Colors.white;
}

class CatalogsPage extends ConsumerStatefulWidget {
  const CatalogsPage({super.key});

  @override
  ConsumerState<CatalogsPage> createState() => _CatalogsPageState();
}

class _CatalogsPageState extends ConsumerState<CatalogsPage> {
  static const List<String> _fallbackProjects = ['TMQ', 'TAP'];
  List<CatalogActivityItem>? _activityReorderDraft;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(catalogsControllerProvider);
    final controller = ref.read(catalogsControllerProvider.notifier);
    final projectsAsync = ref.watch(availableProjectsProvider);
    final activeProjectId =
        ref.watch(activeProjectIdProvider).trim().toUpperCase();

    final remoteProjects = projectsAsync.maybeWhen(
      data: (items) => items.where((item) => item.trim().isNotEmpty).toList(),
      orElse: () => const <String>[],
    );
    final projectOptions = <String>{
      ...(remoteProjects.isEmpty ? _fallbackProjects : remoteProjects),
      if (state.selectedProject.trim().isNotEmpty)
        state.selectedProject.trim().toUpperCase(),
    }.toList()
      ..sort();

    if (state.selectedProject.trim().isEmpty && projectOptions.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.setProject(projectOptions.first);
        ref
            .read(activeProjectIdProvider.notifier)
            .select(projectOptions.first.trim().toUpperCase());
        controller.refresh();
      });
    }

    if (activeProjectId.isNotEmpty &&
        activeProjectId != state.selectedProject &&
        projectOptions.contains(activeProjectId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.setProject(activeProjectId);
        controller.refresh();
      });
    }

    final tabUi = state.uiFor(state.selectedTab);

    if (!tabUi.reorderMode) {
      _activityReorderDraft = null;
    }

    ref.listen<String?>(
      catalogsControllerProvider.select((s) => s.error),
      (_, next) {
        if (next != null && next.isNotEmpty) {
          final background = Theme.of(context).colorScheme.errorContainer;
          final foreground = _readableForeground(background);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(next, style: TextStyle(color: foreground)),
              backgroundColor: background,
              duration: const Duration(seconds: 6),
            ),
          );
        }
      },
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CatalogsHeader(
            isBusy: state.isLoading || state.isMutating,
            isEditMode: state.isEditMode,
            selectedProject: state.selectedProject,
            versionId: state.versionId,
            publicationStatus: state.publicationStatus,
            hasPendingChanges: state.hasPendingChanges,
            projectOptions: projectOptions,
            itemCount: _currentTabCount(state),
            lastLoadedAt: state.lastLoadedAt,
            onProjectSelected: (value) {
              if (value.trim().toUpperCase() == state.selectedProject) return;
              ref
                  .read(activeProjectIdProvider.notifier)
                  .select(value.trim().toUpperCase());
              controller.setProject(value);
              controller.refresh();
            },
            onRefresh: controller.refresh,
            onEditModeChanged: controller.setEditMode,
            onValidate: _onValidatePressed,
            onPublish: _onPublishPressed,
            onRollback: _onRollbackPressed,
          ),
          const SizedBox(height: 10),
          CatalogsTabBar(
            selectedTab: state.selectedTab,
            counts: _counts(state.catalog),
            onTabChanged: controller.setTab,
          ),
          const SizedBox(height: 10),
          CatalogsToolbar(
            tab: state.selectedTab,
            tabUiState: tabUi,
            isBusy: state.isLoading || state.isMutating,
            isEditMode: state.isEditMode,
            visibleCount: _currentVisibleCount(state),
            totalCount: _currentTabCount(state),
            hasActiveFilters: _hasActiveFilters(state),
            onQueryChanged: (value) =>
                controller.updateQuery(state.selectedTab, value),
            onFilterChanged: (value) =>
                controller.updateActiveFilter(state.selectedTab, value),
            onSortChanged: (value) =>
                controller.updateSort(state.selectedTab, value),
            selectedActivityId: tabUi.selectedActivityId,
            selectedSubcategoryId: tabUi.selectedSubcategoryId,
            selectedTopicType: tabUi.selectedTopicType,
            activityFilterOptions: _activityFilterOptions(state),
            subcategoryFilterOptions: _subcategoryFilterOptions(
              state,
              selectedActivityId: tabUi.selectedActivityId,
            ),
            topicTypeFilterOptions: _topicTypeFilterOptions(state),
            onActivityScopeChanged: (value) =>
                controller.updateActivityScope(state.selectedTab, value),
            onSubcategoryScopeChanged: (value) =>
                controller.updateSubcategoryScope(state.selectedTab, value),
            onTopicTypeScopeChanged: (value) =>
                controller.updateTopicTypeScope(state.selectedTab, value),
            onAdd: () => _onCreatePressed(context, state.selectedTab),
            onRefresh: controller.refresh,
            onClearFilters: () {
              controller.updateQuery(state.selectedTab, '');
              controller.updateActiveFilter(
                  state.selectedTab, ActiveFilter.all);
              controller.updateSort(state.selectedTab, const CatalogSortSpec());
              controller.updateActivityScope(state.selectedTab, null);
              controller.updateSubcategoryScope(state.selectedTab, null);
              controller.updateTopicTypeScope(state.selectedTab, null);
            },
            onToggleReorder: state.selectedTab == CatalogTab.activities
                ? controller.toggleReorderMode
                : null,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _buildContent(state),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _stableId(String prefix, String name) {
    final upper = name
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[ÁÀÂÄ]'), 'A')
        .replaceAll(RegExp(r'[ÉÈÊË]'), 'E')
        .replaceAll(RegExp(r'[ÍÌÎÏ]'), 'I')
        .replaceAll(RegExp(r'[ÓÒÔÖ]'), 'O')
        .replaceAll(RegExp(r'[ÚÙÛÜ]'), 'U')
        .replaceAll('Ñ', 'N')
        .replaceAll(RegExp(r'[^A-Z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');

    if (upper.isEmpty) {
      final stamp = DateTime.now().millisecondsSinceEpoch;
      return '${prefix}_$stamp';
    }

    return '${prefix}_$upper';
  }

  String _resolveCreateId({
    required String prefix,
    required String typedId,
    required String fallbackName,
  }) {
    final clean = typedId.trim();
    if (clean.isNotEmpty) return clean.toUpperCase();
    return _stableId(prefix, fallbackName);
  }

  Widget _buildContent(CatalogsPageState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final tabContent = switch (state.selectedTab) {
      CatalogTab.activities => _buildActivitiesContent(state),
      CatalogTab.subcategories => _buildSubcategoriesContent(state),
      CatalogTab.purposes => _buildPurposesContent(state),
      CatalogTab.topics => _buildTopicsContent(state),
      CatalogTab.relations => _buildRelationsContent(state),
      CatalogTab.results => _buildResultsContent(state),
      CatalogTab.assistants => _buildAssistantsContent(state),
    };

    if (state.isEditMode) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeading(state.selectedTab.label, isLocked: false),
          const SizedBox(height: 8),
          Expanded(child: tabContent),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeading(state.selectedTab.label, isLocked: true),
        const SizedBox(height: 8),
        _buildReadOnlySectionBanner(state.selectedTab.label),
        const SizedBox(height: 10),
        Expanded(child: tabContent),
      ],
    );
  }

  Widget _buildSectionHeading(String sectionLabel, {required bool isLocked}) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(
          isLocked ? Icons.lock_outline_rounded : Icons.edit_note_rounded,
          size: 18,
          color: isLocked ? colors.onSurfaceVariant : colors.primary,
        ),
        const SizedBox(width: 8),
        Text(
          sectionLabel,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
              ),
        ),
      ],
    );
  }

  Widget _buildReadOnlySectionBanner(String sectionLabel) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline_rounded, size: 18, color: colors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Modo Ver activo en "$sectionLabel": puedes explorar, pero no modificar.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivitiesContent(CatalogsPageState state) {
    final ui = state.uiFor(CatalogTab.activities);

    if (ui.reorderMode) {
      _activityReorderDraft ??= [...state.catalog.activities]
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      final draft = _activityReorderDraft!;
      if (draft.isEmpty) {
        return _buildEmptyState(
          title: 'No hay Actividades aún',
          subtitle:
              'Agrega una actividad para comenzar a configurar el catálogo.',
          ctaLabel: 'Agregar Actividad',
          onPressed: () => _onCreatePressed(context, CatalogTab.activities),
        );
      }

      return ReorderableListView.builder(
        itemCount: draft.length,
        onReorder: (oldIndex, newIndex) async {
          if (newIndex > oldIndex) newIndex -= 1;
          setState(() {
            final item = draft.removeAt(oldIndex);
            draft.insert(newIndex, item);
          });

          final ids = draft.map((item) => item.id).toList();
          await ref
              .read(catalogsControllerProvider.notifier)
              .reorderActivities(ids);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Orden de actividades actualizado')),
            );
          }
        },
        itemBuilder: (context, index) {
          final item = draft[index];
          return ListTile(
            key: ValueKey(item.id),
            leading: const Icon(Icons.drag_indicator),
            title: Text(item.name),
            subtitle: Text(item.id),
            trailing: _activeChip(item.isActive,
                onTap: () => _setFilter(CatalogTab.activities, item.isActive)),
          );
        },
      );
    }

    final items = _visibleActivities(state);
    if (items.isEmpty) {
      return _buildEmptyState(
        title: 'No hay Actividades aún',
        subtitle:
            'Usa la barra superior para buscar o agrega una actividad nueva.',
        ctaLabel: 'Agregar Actividad',
        onPressed: () => _onCreatePressed(context, CatalogTab.activities),
      );
    }

    return CatalogDataTable(
      columns: const [
        DataColumn(label: Text('ID')),
        DataColumn(label: Text('Nombre')),
        DataColumn(label: Text('Activo')),
        DataColumn(label: Text('Orden')),
        DataColumn(label: Text('Acciones')),
      ],
      rows: items
          .map(
            (item) => DataRow(
              cells: [
                DataCell(Text(item.id)),
                DataCell(Text(item.name)),
                DataCell(_activeChip(item.isActive,
                    onTap: () =>
                        _setFilter(CatalogTab.activities, item.isActive))),
                DataCell(Text(item.sortOrder.toString())),
                DataCell(
                  _RowActionsMenu(
                    enabled: state.isEditMode,
                    isActive: item.isActive,
                    onEdit: () => _showActivityDialog(context, item: item),
                    onDuplicate: () =>
                        _showActivityDialog(context, duplicateFrom: item),
                    onToggleActive: () => _toggleActivity(item),
                    onDelete: () => _deleteActivity(item),
                  ),
                ),
              ],
            ),
          )
          .toList(),
    );
  }

  Widget _buildSubcategoriesContent(CatalogsPageState state) {
    final items = _visibleSubcategories(state);
    if (items.isEmpty) {
      return _buildEmptyState(
        title: 'No hay Subcategorías aún',
        subtitle: 'Las subcategorías dependen de Actividad.',
        ctaLabel: 'Agregar Subcategoría',
        onPressed: () => _onCreatePressed(context, CatalogTab.subcategories),
      );
    }

    return CatalogDataTable(
      columns: const [
        DataColumn(label: Text('ID')),
        DataColumn(label: Text('Actividad')),
        DataColumn(label: Text('Nombre')),
        DataColumn(label: Text('Activo')),
        DataColumn(label: Text('Acciones')),
      ],
      rows: items
          .map(
            (item) => DataRow(
              cells: [
                DataCell(Text(item.id)),
                DataCell(Text(item.activityId)),
                DataCell(Text(item.name)),
                DataCell(_activeChip(item.isActive,
                    onTap: () =>
                        _setFilter(CatalogTab.subcategories, item.isActive))),
                DataCell(
                  _RowActionsMenu(
                    enabled: state.isEditMode,
                    isActive: item.isActive,
                    onEdit: () => _showSubcategoryDialog(context, item: item),
                    onDuplicate: () =>
                        _showSubcategoryDialog(context, duplicateFrom: item),
                    onToggleActive: () => _toggleSubcategory(item),
                    onDelete: () => _deleteSubcategory(item),
                  ),
                ),
              ],
            ),
          )
          .toList(),
    );
  }

  Widget _buildPurposesContent(CatalogsPageState state) {
    final items = _visiblePurposes(state);
    if (items.isEmpty) {
      return _buildEmptyState(
        title: 'No hay Propósitos aún',
        subtitle: 'Los propósitos dependen de Actividad + Subcategoría.',
        ctaLabel: 'Agregar Propósito',
        onPressed: () => _onCreatePressed(context, CatalogTab.purposes),
      );
    }

    return CatalogDataTable(
      columns: const [
        DataColumn(label: Text('ID')),
        DataColumn(label: Text('Actividad')),
        DataColumn(label: Text('Subcategoría')),
        DataColumn(label: Text('Nombre')),
        DataColumn(label: Text('Activo')),
        DataColumn(label: Text('Acciones')),
      ],
      rows: items
          .map(
            (item) => DataRow(
              cells: [
                DataCell(Text(item.id)),
                DataCell(Text(item.activityId)),
                DataCell(Text(item.subcategoryId ?? '-')),
                DataCell(Text(item.name)),
                DataCell(_activeChip(item.isActive,
                    onTap: () =>
                        _setFilter(CatalogTab.purposes, item.isActive))),
                DataCell(
                  _RowActionsMenu(
                    enabled: state.isEditMode,
                    isActive: item.isActive,
                    onEdit: () => _showPurposeDialog(context, item: item),
                    onDuplicate: () =>
                        _showPurposeDialog(context, duplicateFrom: item),
                    onToggleActive: () => _togglePurpose(item),
                    onDelete: () => _deletePurpose(item),
                  ),
                ),
              ],
            ),
          )
          .toList(),
    );
  }

  Widget _buildTopicsContent(CatalogsPageState state) {
    final items = _visibleTopics(state);
    if (items.isEmpty) {
      return _buildEmptyState(
        title: 'No hay Temas aún',
        subtitle: 'Agrega temas para asociarlos a actividades.',
        ctaLabel: 'Agregar Tema',
        onPressed: () => _onCreatePressed(context, CatalogTab.topics),
      );
    }

    return CatalogDataTable(
      columns: const [
        DataColumn(label: Text('ID')),
        DataColumn(label: Text('Nombre')),
        DataColumn(label: Text('Tipo')),
        DataColumn(label: Text('Activo')),
        DataColumn(label: Text('Acciones')),
      ],
      rows: items
          .map(
            (item) => DataRow(
              cells: [
                DataCell(Text(item.id)),
                DataCell(Text(item.name)),
                DataCell(Text(item.type ?? '-')),
                DataCell(_activeChip(item.isActive,
                    onTap: () => _setFilter(CatalogTab.topics, item.isActive))),
                DataCell(
                  _RowActionsMenu(
                    enabled: state.isEditMode,
                    isActive: item.isActive,
                    onEdit: () => _showTopicDialog(context, item: item),
                    onDuplicate: () =>
                        _showTopicDialog(context, duplicateFrom: item),
                    onToggleActive: () => _toggleTopic(item),
                    onDelete: () => _deleteTopic(item),
                  ),
                ),
              ],
            ),
          )
          .toList(),
    );
  }

  Widget _buildRelationsContent(CatalogsPageState state) {
    if (state.catalog.activities.isEmpty) {
      return _buildEmptyState(
        title: 'No hay relaciones aún',
        subtitle:
            'Primero crea actividades y temas para configurar relaciones.',
        ctaLabel: 'Agregar Relación',
        onPressed: () => _showRelationCreateDialog(context),
      );
    }

    final tabUi = state.uiFor(CatalogTab.relations);

    return ActivityTopicRelationsEditor(
      activities: [...state.catalog.activities]
        ..sort((a, b) => a.name.compareTo(b.name)),
      // Use the full topics dataset for relations.
      // Applying Topics-tab filters here can hide just-selected relations.
      topics: [...state.catalog.topics]
        ..sort((a, b) => a.name.compareTo(b.name)),
      relations: state.catalog.relations,
      selectedActivityId: state.selectedRelationActivityId,
      query: tabUi.query,
      showSuggestedOnly: tabUi.showSuggestedOnly,
      onSelectActivity: (activityId) => ref
          .read(catalogsControllerProvider.notifier)
          .selectRelationActivity(activityId),
      onToggleSuggestedOnly: (value) => ref
          .read(catalogsControllerProvider.notifier)
          .setShowSuggestedOnly(value),
      onToggleTopic: (activityId, topicId, selected) async {
        if (!state.isEditMode) {
          return;
        }
        final controller = ref.read(catalogsControllerProvider.notifier);
        if (selected) {
          await controller.deleteRelation(activityId, topicId);
        } else {
          await controller.addRelation(activityId, topicId);
        }
      },
      onAddRelation: () => _showRelationCreateDialog(context),
      isEditMode: state.isEditMode,
      isBusy: state.isMutating,
    );
  }

  Widget _buildResultsContent(CatalogsPageState state) {
    final items = _visibleResults(state);
    if (items.isEmpty) {
      return _buildEmptyState(
        title: 'No hay Resultados aún',
        subtitle: 'Agrega resultados para el cierre de registro.',
        ctaLabel: 'Agregar Resultado',
        onPressed: () => _onCreatePressed(context, CatalogTab.results),
      );
    }

    return CatalogDataTable(
      columns: const [
        DataColumn(label: Text('ID')),
        DataColumn(label: Text('Categoría')),
        DataColumn(label: Text('Nombre')),
        DataColumn(label: Text('Activo')),
        DataColumn(label: Text('Acciones')),
      ],
      rows: items
          .map(
            (item) => DataRow(
              cells: [
                DataCell(Text(item.id)),
                DataCell(Text(item.category)),
                DataCell(Text(item.name)),
                DataCell(_activeChip(item.isActive,
                    onTap: () =>
                        _setFilter(CatalogTab.results, item.isActive))),
                DataCell(
                  _RowActionsMenu(
                    enabled: state.isEditMode,
                    isActive: item.isActive,
                    onEdit: () => _showResultDialog(context, item: item),
                    onDuplicate: () =>
                        _showResultDialog(context, duplicateFrom: item),
                    onToggleActive: () => _toggleResult(item),
                    onDelete: () => _deleteResult(item),
                  ),
                ),
              ],
            ),
          )
          .toList(),
    );
  }

  Widget _buildAssistantsContent(CatalogsPageState state) {
    final items = _visibleAssistants(state);
    if (items.isEmpty) {
      return _buildEmptyState(
        title: 'No hay Asistentes aún',
        subtitle: 'Agrega asistentes/participantes del catálogo.',
        ctaLabel: 'Agregar Asistente',
        onPressed: () => _onCreatePressed(context, CatalogTab.assistants),
      );
    }

    return CatalogDataTable(
      columns: const [
        DataColumn(label: Text('ID')),
        DataColumn(label: Text('Tipo')),
        DataColumn(label: Text('Nombre')),
        DataColumn(label: Text('Activo')),
        DataColumn(label: Text('Acciones')),
      ],
      rows: items
          .map(
            (item) => DataRow(
              cells: [
                DataCell(Text(item.id)),
                DataCell(Text(item.type)),
                DataCell(Text(item.name)),
                DataCell(_activeChip(item.isActive,
                    onTap: () =>
                        _setFilter(CatalogTab.assistants, item.isActive))),
                DataCell(
                  _RowActionsMenu(
                    enabled: state.isEditMode,
                    isActive: item.isActive,
                    onEdit: () => _showAssistantDialog(context, item: item),
                    onDuplicate: () =>
                        _showAssistantDialog(context, duplicateFrom: item),
                    onToggleActive: () => _toggleAssistant(item),
                    onDelete: () => _deleteAssistant(item),
                  ),
                ),
              ],
            ),
          )
          .toList(),
    );
  }

  Widget _buildEmptyState({
    required String title,
    required String subtitle,
    required String ctaLabel,
    required VoidCallback onPressed,
  }) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: 44, color: colors.outline),
          const SizedBox(height: 10),
          Text(
            title,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: TextStyle(color: colors.onSurfaceVariant)),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.add),
            label: Text(ctaLabel),
          ),
        ],
      ),
    );
  }

  Widget _activeChip(bool isActive, {VoidCallback? onTap}) {
    final colors = Theme.of(context).colorScheme;
    final background =
        isActive ? colors.primaryContainer : colors.errorContainer;
    final foreground =
        isActive ? colors.onPrimaryContainer : colors.onErrorContainer;

    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        isActive ? 'Activo' : 'Inactivo',
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    if (onTap == null) return child;
    return Tooltip(
      message: isActive ? 'Filtrar: Activos' : 'Filtrar: Inactivos',
      child: InkWell(
          onTap: onTap, borderRadius: BorderRadius.circular(14), child: child),
    );
  }

  Future<void> _onCreatePressed(BuildContext context, CatalogTab tab) async {
    final state = ref.read(catalogsControllerProvider);
    if (!state.isEditMode) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Activa Modo Editar para modificar el catálogo.'),
          ),
        );
      }
      return;
    }

    switch (tab) {
      case CatalogTab.activities:
        await _showActivityDialog(context);
        break;
      case CatalogTab.subcategories:
        await _showSubcategoryDialog(context);
        break;
      case CatalogTab.purposes:
        await _showPurposeDialog(context);
        break;
      case CatalogTab.topics:
        await _showTopicDialog(context);
        break;
      case CatalogTab.relations:
        await _showRelationCreateDialog(context);
        break;
      case CatalogTab.results:
        await _showResultDialog(context);
        break;
      case CatalogTab.assistants:
        await _showAssistantDialog(context);
        break;
    }
  }

  Future<void> _showActivityDialog(
    BuildContext context, {
    CatalogActivityItem? item,
    CatalogActivityItem? duplicateFrom,
  }) async {
    final source = item ?? duplicateFrom;
    final isCreate = item == null;
    final isDuplicate = duplicateFrom != null && item == null;

    final id = TextEditingController(
      text:
          source == null ? '' : (isDuplicate ? '${source.id}_COPY' : source.id),
    );
    final name = TextEditingController(text: source?.name ?? '');
    final description = TextEditingController(text: source?.description ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) {
          final canSave = name.text.trim().isNotEmpty;
          return AlertDialog(
            title: Text(
              item != null
                  ? 'Editar actividad'
                  : (isDuplicate ? 'Duplicar actividad' : 'Nueva actividad'),
            ),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: id,
                      enabled: isCreate,
                      decoration: const InputDecoration(labelText: 'ID'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Nombre *'),
                      onChanged: (_) => setLocalState(() {}),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: description,
                      decoration:
                          const InputDecoration(labelText: 'Descripción'),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar')),
              FilledButton(
                onPressed: canSave ? () => Navigator.pop(context, true) : null,
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );

    if (saved != true) return;

    final controller = ref.read(catalogsControllerProvider.notifier);
    final resolvedId = _resolveCreateId(
      prefix: 'ACT',
      typedId: id.text,
      fallbackName: name.text,
    );
    if (item == null) {
      await controller.createActivity(
          id: resolvedId, name: name.text, description: description.text);
    } else {
      await controller.updateActivity(item.id,
          name: name.text, description: description.text);
    }
  }

  Future<void> _showSubcategoryDialog(
    BuildContext context, {
    CatalogSubcategoryItem? item,
    CatalogSubcategoryItem? duplicateFrom,
  }) async {
    final source = item ?? duplicateFrom;
    final isCreate = item == null;
    final isDuplicate = duplicateFrom != null && item == null;

    var selectedActivity = source?.activityId ?? '';
    final id = TextEditingController(
      text:
          source == null ? '' : (isDuplicate ? '${source.id}_COPY' : source.id),
    );
    final name = TextEditingController(text: source?.name ?? '');
    final description = TextEditingController(text: source?.description ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) {
          final state = ref.read(catalogsControllerProvider);
          final activities = [...state.catalog.activities]..sort((a, b) {
              if (a.isActive == b.isActive) return a.name.compareTo(b.name);
              return a.isActive ? -1 : 1;
            });

          if (selectedActivity.isEmpty && activities.isNotEmpty) {
            selectedActivity = activities.first.id;
          }

          final selectedActivityItem = activities
              .where((entry) => entry.id == selectedActivity)
              .firstOrNull;
          final selectedActivityActive =
              selectedActivityItem?.isActive ?? false;

          final canSave =
              name.text.trim().isNotEmpty && selectedActivity.isNotEmpty;
          return AlertDialog(
            title: Text(
              item != null
                  ? 'Editar subcategoría'
                  : (isDuplicate
                      ? 'Duplicar subcategoría'
                      : 'Nueva subcategoría'),
            ),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: id,
                      enabled: isCreate,
                      decoration: const InputDecoration(labelText: 'ID'),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue:
                          selectedActivity.isEmpty ? null : selectedActivity,
                      items: activities
                          .map(
                            (entry) => DropdownMenuItem<String>(
                              value: entry.id,
                              enabled: entry.isActive,
                              child: Text(entry.isActive
                                  ? entry.name
                                  : '${entry.name} (inactiva)'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setLocalState(() => selectedActivity = value ?? ''),
                      decoration: const InputDecoration(labelText: 'Actividad'),
                    ),
                    if (!selectedActivityActive && selectedActivity.isNotEmpty)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Wrap(
                            spacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'Esta actividad está inactiva. Actívala para agregar subcategorías.',
                                style: TextStyle(
                                    color: Theme.of(context).colorScheme.error),
                              ),
                              TextButton(
                                onPressed: () async {
                                  await ref
                                      .read(catalogsControllerProvider.notifier)
                                      .updateActivity(selectedActivity,
                                          isActive: true);
                                  setLocalState(() {});
                                },
                                child: const Text('Activar actividad'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Nombre *'),
                      onChanged: (_) => setLocalState(() {}),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: description,
                      decoration:
                          const InputDecoration(labelText: 'Descripción'),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar')),
              FilledButton(
                onPressed: canSave ? () => Navigator.pop(context, true) : null,
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );

    if (saved != true) return;

    final state = ref.read(catalogsControllerProvider);
    final selectedActivityActive = state.catalog.activities
        .any((entry) => entry.id == selectedActivity && entry.isActive);

    if (item == null && !selectedActivityActive) {
      _showBlockedByInactiveParentMessage('actividad', selectedActivity);
      return;
    }

    final controller = ref.read(catalogsControllerProvider.notifier);
    final resolvedId = _resolveCreateId(
      prefix: 'SUB',
      typedId: id.text,
      fallbackName: name.text,
    );
    if (item == null) {
      await controller.createSubcategory(
        id: resolvedId,
        activityId: selectedActivity,
        name: name.text,
        description: description.text,
      );
    } else {
      await controller.updateSubcategory(
        item.id,
        activityId: selectedActivity,
        name: name.text,
        description: description.text,
      );
    }
  }

  Future<void> _showPurposeDialog(
    BuildContext context, {
    CatalogPurposeItem? item,
    CatalogPurposeItem? duplicateFrom,
  }) async {
    final source = item ?? duplicateFrom;
    final isCreate = item == null;
    final isDuplicate = duplicateFrom != null && item == null;

    final id = TextEditingController(
      text:
          source == null ? '' : (isDuplicate ? '${source.id}_COPY' : source.id),
    );
    final name = TextEditingController(text: source?.name ?? '');

    var selectedActivity = source?.activityId ?? '';
    String? selectedSubcategory = source?.subcategoryId;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) {
          final state = ref.read(catalogsControllerProvider);
          final activities = [...state.catalog.activities]..sort((a, b) {
              if (a.isActive == b.isActive) return a.name.compareTo(b.name);
              return a.isActive ? -1 : 1;
            });

          if (selectedActivity.isEmpty && activities.isNotEmpty) {
            selectedActivity = activities.first.id;
          }

          List<CatalogSubcategoryItem> subcategoriesForActivity(
              String activityId) {
            final scoped = state.catalog.subcategories
                .where((entry) => entry.activityId == activityId)
                .toList();
            scoped.sort((a, b) {
              if (a.isActive == b.isActive) return a.name.compareTo(b.name);
              return a.isActive ? -1 : 1;
            });
            return scoped;
          }

          final scopedSubcategories =
              subcategoriesForActivity(selectedActivity);
          if (selectedSubcategory != null &&
              !scopedSubcategories
                  .any((entry) => entry.id == selectedSubcategory)) {
            selectedSubcategory = scopedSubcategories.isNotEmpty
                ? scopedSubcategories.first.id
                : null;
          }
          if (selectedSubcategory == null && scopedSubcategories.isNotEmpty) {
            selectedSubcategory = scopedSubcategories.first.id;
          }

          final selectedActivityItem = activities
              .where((entry) => entry.id == selectedActivity)
              .firstOrNull;
          final selectedActivityActive =
              selectedActivityItem?.isActive ?? false;
          final selectedSubcategoryItem = scopedSubcategories
              .where((entry) => entry.id == selectedSubcategory)
              .firstOrNull;
          final selectedSubcategoryActive =
              selectedSubcategoryItem?.isActive ?? false;

          final canSave =
              name.text.trim().isNotEmpty && selectedActivity.isNotEmpty;
          return AlertDialog(
            title: Text(
              item != null
                  ? 'Editar propósito'
                  : (isDuplicate ? 'Duplicar propósito' : 'Nuevo propósito'),
            ),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: id,
                      enabled: isCreate,
                      decoration: const InputDecoration(labelText: 'ID'),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue:
                          selectedActivity.isEmpty ? null : selectedActivity,
                      items: activities
                          .map(
                            (entry) => DropdownMenuItem<String>(
                              value: entry.id,
                              enabled: entry.isActive,
                              child: Text(entry.isActive
                                  ? entry.name
                                  : '${entry.name} (inactiva)'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setLocalState(() {
                        selectedActivity = value ?? '';
                        selectedSubcategory = null;
                      }),
                      decoration: const InputDecoration(labelText: 'Actividad'),
                    ),
                    if (!selectedActivityActive && selectedActivity.isNotEmpty)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Wrap(
                            spacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'Esta actividad está inactiva. Actívala para agregar propósitos.',
                                style: TextStyle(
                                    color: Theme.of(context).colorScheme.error),
                              ),
                              TextButton(
                                onPressed: () async {
                                  await ref
                                      .read(catalogsControllerProvider.notifier)
                                      .updateActivity(selectedActivity,
                                          isActive: true);
                                  setLocalState(() {});
                                },
                                child: const Text('Activar actividad'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: selectedSubcategory,
                      items: scopedSubcategories
                          .map(
                            (entry) => DropdownMenuItem<String>(
                              value: entry.id,
                              enabled: entry.isActive,
                              child: Text(entry.isActive
                                  ? entry.name
                                  : '${entry.name} (inactiva)'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setLocalState(() => selectedSubcategory = value),
                      decoration:
                          const InputDecoration(labelText: 'Subcategoría'),
                    ),
                    if (!selectedSubcategoryActive &&
                        selectedSubcategory != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Wrap(
                            spacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'Esta subcategoría está inactiva. Actívala para agregar propósitos.',
                                style: TextStyle(
                                    color: Theme.of(context).colorScheme.error),
                              ),
                              TextButton(
                                onPressed: () async {
                                  await ref
                                      .read(catalogsControllerProvider.notifier)
                                      .updateSubcategory(selectedSubcategory!,
                                          isActive: true);
                                  setLocalState(() {});
                                },
                                child: const Text('Activar subcategoría'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Nombre *'),
                      onChanged: (_) => setLocalState(() {}),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar')),
              FilledButton(
                onPressed: canSave ? () => Navigator.pop(context, true) : null,
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );

    if (saved != true) return;

    final state = ref.read(catalogsControllerProvider);
    final activityActive = state.catalog.activities
        .any((entry) => entry.id == selectedActivity && entry.isActive);
    final subcategoryActive = selectedSubcategory == null
        ? true
        : state.catalog.subcategories
            .any((entry) => entry.id == selectedSubcategory && entry.isActive);

    if (item == null && !activityActive) {
      _showBlockedByInactiveParentMessage('actividad', selectedActivity);
      return;
    }
    if (item == null && !subcategoryActive && selectedSubcategory != null) {
      _showBlockedByInactiveParentMessage('subcategoría', selectedSubcategory);
      return;
    }

    final controller = ref.read(catalogsControllerProvider.notifier);
    final resolvedId = _resolveCreateId(
      prefix: 'PRS',
      typedId: id.text,
      fallbackName: name.text,
    );
    if (item == null) {
      await controller.createPurpose(
        id: resolvedId,
        activityId: selectedActivity,
        subcategoryId: selectedSubcategory,
        name: name.text,
      );
    } else {
      await controller.updatePurpose(
        item.id,
        activityId: selectedActivity,
        subcategoryId: selectedSubcategory,
        name: name.text,
      );
    }
  }

  Future<void> _showTopicDialog(
    BuildContext context, {
    CatalogTopicItem? item,
    CatalogTopicItem? duplicateFrom,
  }) async {
    final source = item ?? duplicateFrom;
    final isCreate = item == null;
    final isDuplicate = duplicateFrom != null && item == null;

    final id = TextEditingController(
      text:
          source == null ? '' : (isDuplicate ? '${source.id}_COPY' : source.id),
    );
    final name = TextEditingController(text: source?.name ?? '');
    final type = TextEditingController(text: source?.type ?? '');
    final description = TextEditingController(text: source?.description ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) {
          final canSave = name.text.trim().isNotEmpty;
          return AlertDialog(
            title: Text(
              item != null
                  ? 'Editar tema'
                  : (isDuplicate ? 'Duplicar tema' : 'Nuevo tema'),
            ),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: id,
                      enabled: isCreate,
                      decoration: const InputDecoration(labelText: 'ID'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Nombre *'),
                      onChanged: (_) => setLocalState(() {}),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                        controller: type,
                        decoration: const InputDecoration(labelText: 'Tipo')),
                    const SizedBox(height: 8),
                    TextField(
                      controller: description,
                      decoration:
                          const InputDecoration(labelText: 'Descripción'),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar')),
              FilledButton(
                onPressed: canSave ? () => Navigator.pop(context, true) : null,
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );

    if (saved != true) return;

    final controller = ref.read(catalogsControllerProvider.notifier);
    final resolvedId = _resolveCreateId(
      prefix: 'TOP',
      typedId: id.text,
      fallbackName: name.text,
    );
    if (item == null) {
      await controller.createTopic(
        id: resolvedId,
        name: name.text,
        type: type.text,
        description: description.text,
      );
    } else {
      await controller.updateTopic(
        item.id,
        name: name.text,
        type: type.text,
        description: description.text,
      );
    }
  }

  Future<void> _showRelationCreateDialog(BuildContext context) async {
    final stateSnapshot = ref.read(catalogsControllerProvider);
    if (!stateSnapshot.isEditMode) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Activa Modo Editar para agregar relaciones.'),
          ),
        );
      }
      return;
    }

    final state = ref.read(catalogsControllerProvider);
    final activities = state.catalog.activities;
    final topics = state.catalog.topics;

    if (activities.isEmpty || topics.isEmpty) return;

    var selectedActivity = activities.first.id;
    var selectedTopic = topics.first.id;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('Nueva relación actividad-tema'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedActivity,
                  items: activities
                      .map((entry) => DropdownMenuItem(
                          value: entry.id, child: Text(entry.name)))
                      .toList(),
                  onChanged: (value) => setLocalState(
                      () => selectedActivity = value ?? selectedActivity),
                  decoration: const InputDecoration(labelText: 'Actividad'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: selectedTopic,
                  items: topics
                      .map((entry) => DropdownMenuItem(
                          value: entry.id, child: Text(entry.name)))
                      .toList(),
                  onChanged: (value) => setLocalState(
                      () => selectedTopic = value ?? selectedTopic),
                  decoration: const InputDecoration(labelText: 'Tema'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Guardar')),
          ],
        ),
      ),
    );

    if (saved != true) return;

    await ref
        .read(catalogsControllerProvider.notifier)
        .addRelation(selectedActivity, selectedTopic);
  }

  Future<void> _showResultDialog(
    BuildContext context, {
    CatalogResultItem? item,
    CatalogResultItem? duplicateFrom,
  }) async {
    final source = item ?? duplicateFrom;
    final isCreate = item == null;
    final isDuplicate = duplicateFrom != null && item == null;

    final id = TextEditingController(
      text:
          source == null ? '' : (isDuplicate ? '${source.id}_COPY' : source.id),
    );
    final category = TextEditingController(text: source?.category ?? '');
    final name = TextEditingController(text: source?.name ?? '');
    final description = TextEditingController(text: source?.description ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) {
          final canSave =
              name.text.trim().isNotEmpty && category.text.trim().isNotEmpty;
          return AlertDialog(
            title: Text(
              item != null
                  ? 'Editar resultado'
                  : (isDuplicate ? 'Duplicar resultado' : 'Nuevo resultado'),
            ),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: id,
                      enabled: isCreate,
                      decoration: const InputDecoration(labelText: 'ID'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: category,
                      decoration:
                          const InputDecoration(labelText: 'Categoría *'),
                      onChanged: (_) => setLocalState(() {}),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Nombre *'),
                      onChanged: (_) => setLocalState(() {}),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: description,
                      decoration:
                          const InputDecoration(labelText: 'Descripción'),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar')),
              FilledButton(
                onPressed: canSave ? () => Navigator.pop(context, true) : null,
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );

    if (saved != true) return;

    final controller = ref.read(catalogsControllerProvider.notifier);
    final resolvedId = _resolveCreateId(
      prefix: 'RES',
      typedId: id.text,
      fallbackName: name.text,
    );
    if (item == null) {
      await controller.createResult(
        id: resolvedId,
        category: category.text,
        name: name.text,
        description: description.text,
      );
    } else {
      await controller.updateResult(
        item.id,
        category: category.text,
        name: name.text,
        description: description.text,
      );
    }
  }

  Future<void> _showAssistantDialog(
    BuildContext context, {
    CatalogAssistantItem? item,
    CatalogAssistantItem? duplicateFrom,
  }) async {
    final source = item ?? duplicateFrom;
    final isCreate = item == null;
    final isDuplicate = duplicateFrom != null && item == null;

    final id = TextEditingController(
      text:
          source == null ? '' : (isDuplicate ? '${source.id}_COPY' : source.id),
    );
    final type = TextEditingController(text: source?.type ?? '');
    final name = TextEditingController(text: source?.name ?? '');
    final description = TextEditingController(text: source?.description ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) {
          final canSave =
              name.text.trim().isNotEmpty && type.text.trim().isNotEmpty;
          return AlertDialog(
            title: Text(
              item != null
                  ? 'Editar asistente'
                  : (isDuplicate ? 'Duplicar asistente' : 'Nuevo asistente'),
            ),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: id,
                      enabled: isCreate,
                      decoration: const InputDecoration(labelText: 'ID'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: type,
                      decoration: const InputDecoration(labelText: 'Tipo *'),
                      onChanged: (_) => setLocalState(() {}),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Nombre *'),
                      onChanged: (_) => setLocalState(() {}),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: description,
                      decoration:
                          const InputDecoration(labelText: 'Descripción'),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar')),
              FilledButton(
                onPressed: canSave ? () => Navigator.pop(context, true) : null,
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );

    if (saved != true) return;

    final controller = ref.read(catalogsControllerProvider.notifier);
    final resolvedId = _resolveCreateId(
      prefix: 'AST',
      typedId: id.text,
      fallbackName: name.text,
    );
    if (item == null) {
      await controller.createAssistant(
        id: resolvedId,
        type: type.text,
        name: name.text,
        description: description.text,
      );
    } else {
      await controller.updateAssistant(
        item.id,
        type: type.text,
        name: name.text,
        description: description.text,
      );
    }
  }

  Future<void> _toggleActivity(CatalogActivityItem item) async {
    final controller = ref.read(catalogsControllerProvider.notifier);
    final next = !item.isActive;
    await controller.updateActivity(item.id, isActive: next);
    if (!mounted) return;
    _showUndoSnackBar(
      message: next ? 'Actividad activada' : 'Actividad desactivada',
      onUndo: () => controller.updateActivity(item.id, isActive: item.isActive),
    );
  }

  Future<void> _toggleSubcategory(CatalogSubcategoryItem item) async {
    final controller = ref.read(catalogsControllerProvider.notifier);
    final next = !item.isActive;
    await controller.updateSubcategory(item.id, isActive: next);
    if (!mounted) return;
    _showUndoSnackBar(
      message: next ? 'Subcategoría activada' : 'Subcategoría desactivada',
      onUndo: () =>
          controller.updateSubcategory(item.id, isActive: item.isActive),
    );
  }

  Future<void> _togglePurpose(CatalogPurposeItem item) async {
    final controller = ref.read(catalogsControllerProvider.notifier);
    final next = !item.isActive;
    await controller.updatePurpose(item.id, isActive: next);
    if (!mounted) return;
    _showUndoSnackBar(
      message: next ? 'Propósito activado' : 'Propósito desactivado',
      onUndo: () => controller.updatePurpose(item.id, isActive: item.isActive),
    );
  }

  Future<void> _toggleTopic(CatalogTopicItem item) async {
    final controller = ref.read(catalogsControllerProvider.notifier);
    final next = !item.isActive;
    await controller.updateTopic(item.id, isActive: next);
    if (!mounted) return;
    _showUndoSnackBar(
      message: next ? 'Tema activado' : 'Tema desactivado',
      onUndo: () => controller.updateTopic(item.id, isActive: item.isActive),
    );
  }

  Future<void> _toggleResult(CatalogResultItem item) async {
    final controller = ref.read(catalogsControllerProvider.notifier);
    final next = !item.isActive;
    await controller.updateResult(item.id, isActive: next);
    if (!mounted) return;
    _showUndoSnackBar(
      message: next ? 'Resultado activado' : 'Resultado desactivado',
      onUndo: () => controller.updateResult(item.id, isActive: item.isActive),
    );
  }

  Future<void> _toggleAssistant(CatalogAssistantItem item) async {
    final controller = ref.read(catalogsControllerProvider.notifier);
    final next = !item.isActive;
    await controller.updateAssistant(item.id, isActive: next);
    if (!mounted) return;
    _showUndoSnackBar(
      message: next ? 'Asistente activado' : 'Asistente desactivado',
      onUndo: () =>
          controller.updateAssistant(item.id, isActive: item.isActive),
    );
  }

  Future<void> _deleteActivity(CatalogActivityItem item) async {
    if (!await _confirmDelete('actividad ${item.id}')) return;
    final controller = ref.read(catalogsControllerProvider.notifier);
    await controller.deleteActivity(item.id);
    if (!mounted) return;
    _showUndoSnackBar(
      message: 'Actividad eliminada',
      onUndo: () => controller.restoreActivity(item),
    );
  }

  Future<void> _deleteSubcategory(CatalogSubcategoryItem item) async {
    if (!await _confirmDelete('subcategoría ${item.id}')) return;
    final controller = ref.read(catalogsControllerProvider.notifier);
    await controller.deleteSubcategory(item.id);
    if (!mounted) return;
    _showUndoSnackBar(
      message: 'Subcategoría eliminada',
      onUndo: () => controller.restoreSubcategory(item),
    );
  }

  Future<void> _deletePurpose(CatalogPurposeItem item) async {
    if (!await _confirmDelete('propósito ${item.id}')) return;
    final controller = ref.read(catalogsControllerProvider.notifier);
    await controller.deletePurpose(item.id);
    if (!mounted) return;
    _showUndoSnackBar(
      message: 'Propósito eliminado',
      onUndo: () => controller.restorePurpose(item),
    );
  }

  Future<void> _deleteTopic(CatalogTopicItem item) async {
    if (!await _confirmDelete('tema ${item.id}')) return;
    final controller = ref.read(catalogsControllerProvider.notifier);
    await controller.deleteTopic(item.id);
    if (!mounted) return;
    _showUndoSnackBar(
      message: 'Tema eliminado',
      onUndo: () => controller.restoreTopic(item),
    );
  }

  Future<void> _deleteResult(CatalogResultItem item) async {
    if (!await _confirmDelete('resultado ${item.id}')) return;
    final controller = ref.read(catalogsControllerProvider.notifier);
    await controller.deleteResult(item.id);
    if (!mounted) return;
    _showUndoSnackBar(
      message: 'Resultado eliminado',
      onUndo: () => controller.restoreResult(item),
    );
  }

  Future<void> _deleteAssistant(CatalogAssistantItem item) async {
    if (!await _confirmDelete('asistente ${item.id}')) return;
    final controller = ref.read(catalogsControllerProvider.notifier);
    await controller.deleteAssistant(item.id);
    if (!mounted) return;
    _showUndoSnackBar(
      message: 'Asistente eliminado',
      onUndo: () => controller.restoreAssistant(item),
    );
  }

  Future<bool> _confirmDelete(String label) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text('¿Eliminar $label?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar')),
        ],
      ),
    );
    return result == true;
  }

  void _showUndoSnackBar(
      {required String message, required Future<void> Function() onUndo}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 7),
        action: SnackBarAction(
          label: 'Deshacer',
          onPressed: () async => onUndo(),
        ),
      ),
    );
  }

  void _showBlockedByInactiveParentMessage(
      String parentType, String? parentId) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'No se puede crear porque el $parentType "${parentId ?? ''}" está inactivo.'),
      ),
    );
  }

  void _setFilter(CatalogTab tab, bool isActive) {
    ref.read(catalogsControllerProvider.notifier).updateActiveFilter(
        tab, isActive ? ActiveFilter.active : ActiveFilter.inactive);
  }

  List<CatalogActivityItem> _visibleActivities(CatalogsPageState state) {
    final ui = state.uiFor(CatalogTab.activities);
    final items = state.catalog.activities.where((item) {
      if (!_matchesActiveFilter(item.isActive, ui.activeFilter)) return false;
      return _matchesQuery(
          ui.query, [item.id, item.name, item.description ?? '']);
    }).toList();

    items.sort((a, b) => _sortCompare(
          ui.sort,
          idA: a.id,
          idB: b.id,
          nameA: a.name,
          nameB: b.name,
          activeA: a.isActive,
          activeB: b.isActive,
          orderA: a.sortOrder,
          orderB: b.sortOrder,
        ));
    return items;
  }

  List<CatalogSubcategoryItem> _visibleSubcategories(CatalogsPageState state) {
    final ui = state.uiFor(CatalogTab.subcategories);
    final items = state.catalog.subcategories.where((item) {
      if (!_matchesActiveFilter(item.isActive, ui.activeFilter)) {
        return false;
      }
      if (ui.selectedActivityId != null &&
          item.activityId != ui.selectedActivityId) {
        return false;
      }
      return _matchesQuery(ui.query,
          [item.id, item.name, item.activityId, item.description ?? '']);
    }).toList();

    items.sort((a, b) => _sortCompare(
          ui.sort,
          idA: a.id,
          idB: b.id,
          nameA: a.name,
          nameB: b.name,
          activeA: a.isActive,
          activeB: b.isActive,
          orderA: a.sortOrder,
          orderB: b.sortOrder,
        ));
    return items;
  }

  List<CatalogPurposeItem> _visiblePurposes(CatalogsPageState state) {
    final ui = state.uiFor(CatalogTab.purposes);
    final items = state.catalog.purposes.where((item) {
      if (!_matchesActiveFilter(item.isActive, ui.activeFilter)) {
        return false;
      }
      if (ui.selectedActivityId != null &&
          item.activityId != ui.selectedActivityId) {
        return false;
      }
      if (ui.selectedSubcategoryId != null &&
          item.subcategoryId != ui.selectedSubcategoryId) {
        return false;
      }
      return _matchesQuery(ui.query,
          [item.id, item.name, item.activityId, item.subcategoryId ?? '']);
    }).toList();

    items.sort((a, b) => _sortCompare(
          ui.sort,
          idA: a.id,
          idB: b.id,
          nameA: a.name,
          nameB: b.name,
          activeA: a.isActive,
          activeB: b.isActive,
          orderA: a.sortOrder,
          orderB: b.sortOrder,
        ));
    return items;
  }

  List<CatalogTopicItem> _visibleTopics(CatalogsPageState state) {
    final ui = state.uiFor(CatalogTab.topics);
    final items = state.catalog.topics.where((item) {
      if (!_matchesActiveFilter(item.isActive, ui.activeFilter)) {
        return false;
      }
      if (ui.selectedTopicType != null &&
          (item.type ?? '').trim() != ui.selectedTopicType) {
        return false;
      }
      return _matchesQuery(ui.query,
          [item.id, item.name, item.type ?? '', item.description ?? '']);
    }).toList();

    items.sort((a, b) => _sortCompare(
          ui.sort,
          idA: a.id,
          idB: b.id,
          nameA: a.name,
          nameB: b.name,
          activeA: a.isActive,
          activeB: b.isActive,
          orderA: a.sortOrder,
          orderB: b.sortOrder,
        ));
    return items;
  }

  List<CatalogResultItem> _visibleResults(CatalogsPageState state) {
    final ui = state.uiFor(CatalogTab.results);
    final items = state.catalog.results.where((item) {
      if (!_matchesActiveFilter(item.isActive, ui.activeFilter)) return false;
      return _matchesQuery(ui.query,
          [item.id, item.name, item.category, item.description ?? '']);
    }).toList();

    items.sort((a, b) => _sortCompare(
          ui.sort,
          idA: a.id,
          idB: b.id,
          nameA: a.name,
          nameB: b.name,
          activeA: a.isActive,
          activeB: b.isActive,
          orderA: a.sortOrder,
          orderB: b.sortOrder,
        ));
    return items;
  }

  List<CatalogAssistantItem> _visibleAssistants(CatalogsPageState state) {
    final ui = state.uiFor(CatalogTab.assistants);
    final items = state.catalog.assistants.where((item) {
      if (!_matchesActiveFilter(item.isActive, ui.activeFilter)) return false;
      return _matchesQuery(
          ui.query, [item.id, item.name, item.type, item.description ?? '']);
    }).toList();

    items.sort((a, b) => _sortCompare(
          ui.sort,
          idA: a.id,
          idB: b.id,
          nameA: a.name,
          nameB: b.name,
          activeA: a.isActive,
          activeB: b.isActive,
          orderA: a.sortOrder,
          orderB: b.sortOrder,
        ));
    return items;
  }

  bool _matchesQuery(String query, List<String> fields) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return fields.any((field) => field.toLowerCase().contains(q));
  }

  bool _matchesActiveFilter(bool isActive, ActiveFilter filter) {
    return switch (filter) {
      ActiveFilter.all => true,
      ActiveFilter.active => isActive,
      ActiveFilter.inactive => !isActive,
    };
  }

  List<CatItem> _activityFilterOptions(CatalogsPageState state) {
    final entries = [...state.catalog.activities]
      ..sort((a, b) => a.name.compareTo(b.name));
    return entries
        .map((entry) => CatItem(id: entry.id, name: entry.name))
        .toList();
  }

  List<CatItem> _subcategoryFilterOptions(
    CatalogsPageState state, {
    String? selectedActivityId,
  }) {
    final entries = state.catalog.subcategories.where((entry) {
      if (selectedActivityId == null || selectedActivityId.isEmpty) return true;
      return entry.activityId == selectedActivityId;
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return entries
        .map((entry) => CatItem(id: entry.id, name: entry.name))
        .toList();
  }

  List<CatItem> _topicTypeFilterOptions(CatalogsPageState state) {
    final values = <String>{};
    for (final topic in state.catalog.topics) {
      final type = (topic.type ?? '').trim();
      if (type.isNotEmpty) {
        values.add(type);
      }
    }
    final sorted = values.toList()..sort();
    return sorted.map((entry) => CatItem(id: entry, name: entry)).toList();
  }

  int _sortCompare(
    CatalogSortSpec sort, {
    required String idA,
    required String idB,
    required String nameA,
    required String nameB,
    required bool activeA,
    required bool activeB,
    required int orderA,
    required int orderB,
  }) {
    int value;
    switch (sort.field) {
      case CatalogSortField.id:
        value = idA.compareTo(idB);
        break;
      case CatalogSortField.name:
        value = nameA.compareTo(nameB);
        break;
      case CatalogSortField.active:
        value = (activeA ? 1 : 0).compareTo(activeB ? 1 : 0);
        break;
      case CatalogSortField.order:
        value = orderA.compareTo(orderB);
        break;
    }
    return sort.ascending ? value : -value;
  }

  Map<CatalogTab, int> _counts(CatalogData data) {
    return {
      CatalogTab.activities: data.activities.length,
      CatalogTab.subcategories: data.subcategories.length,
      CatalogTab.purposes: data.purposes.length,
      CatalogTab.topics: data.topics.length,
      CatalogTab.relations: data.relations.length,
      CatalogTab.results: data.results.length,
      CatalogTab.assistants: data.assistants.length,
    };
  }

  int _currentTabCount(CatalogsPageState state) {
    return _counts(state.catalog)[state.selectedTab] ?? 0;
  }

  int _currentVisibleCount(CatalogsPageState state) {
    return switch (state.selectedTab) {
      CatalogTab.activities => _visibleActivities(state).length,
      CatalogTab.subcategories => _visibleSubcategories(state).length,
      CatalogTab.purposes => _visiblePurposes(state).length,
      CatalogTab.topics => _visibleTopics(state).length,
      CatalogTab.relations => state.catalog.relations.length,
      CatalogTab.results => _visibleResults(state).length,
      CatalogTab.assistants => _visibleAssistants(state).length,
    };
  }

  bool _hasActiveFilters(CatalogsPageState state) {
    final ui = state.uiFor(state.selectedTab);
    return ui.query.trim().isNotEmpty ||
        ui.activeFilter != ActiveFilter.all ||
        ui.sort.field != CatalogSortField.name ||
        ui.sort.ascending != true ||
        ui.selectedActivityId != null ||
        ui.selectedSubcategoryId != null ||
        ui.selectedTopicType != null;
  }

  Future<void> _onValidatePressed() async {
    final result = await ref
        .read(catalogsControllerProvider.notifier)
        .validateCatalogDraft();
    if (!mounted) return;
    _showHookResult(result);
  }

  Future<void> _onPublishPressed() async {
    final notes = await _askPublishNotes();
    if (!mounted || notes == null) return;

    final normalized = notes.trim();
    final result = await ref
        .read(catalogsControllerProvider.notifier)
        .publishCatalogDraft(notes: normalized.isEmpty ? null : normalized);
    if (!mounted) return;
    _showHookResult(result);
  }

  Future<void> _onRollbackPressed() async {
    final result = await ref
        .read(catalogsControllerProvider.notifier)
        .rollbackCatalogDraft();
    if (!mounted) return;
    _showHookResult(result);
  }

  void _showHookResult(CatalogAdminHookResult result) {
    final colors = Theme.of(context).colorScheme;
    final color =
        result.success ? colors.primaryContainer : colors.errorContainer;
    final foreground = _readableForeground(color);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.message,
          style: TextStyle(color: foreground),
        ),
        backgroundColor: color,
      ),
    );
  }

  Future<String?> _askPublishNotes() async {
    final controller = TextEditingController();
    final notes = await showDialog<String?>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Publicar catálogo'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Notas (opcional)',
              hintText: 'Resumen de cambios para publicación',
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(null),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: const Text('Publicar'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return notes;
  }
}

class CatalogsHeader extends StatelessWidget {
  final bool isBusy;
  final bool isEditMode;
  final String selectedProject;
  final String? versionId;
  final String publicationStatus;
  final bool hasPendingChanges;
  final List<String> projectOptions;
  final int itemCount;
  final DateTime? lastLoadedAt;
  final ValueChanged<String> onProjectSelected;
  final VoidCallback onRefresh;
  final ValueChanged<bool> onEditModeChanged;
  final Future<void> Function() onValidate;
  final Future<void> Function() onPublish;
  final Future<void> Function() onRollback;

  const CatalogsHeader({
    super.key,
    required this.isBusy,
    required this.isEditMode,
    required this.selectedProject,
    required this.versionId,
    required this.publicationStatus,
    required this.hasPendingChanges,
    required this.projectOptions,
    required this.itemCount,
    required this.lastLoadedAt,
    required this.onProjectSelected,
    required this.onRefresh,
    required this.onEditModeChanged,
    required this.onValidate,
    required this.onPublish,
    required this.onRollback,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final lastLoaded = lastLoadedAt == null
        ? 'Sin carga previa'
        : '${lastLoadedAt!.hour.toString().padLeft(2, '0')}:${lastLoadedAt!.minute.toString().padLeft(2, '0')}';
    final publishedState = _statusLabel(publicationStatus);

    final changedColor = hasPendingChanges
        ? Colors.amber.withValues(alpha: 0.2)
        : Colors.green.withValues(alpha: 0.14);
    final changedBorder = hasPendingChanges
        ? Colors.amber.withValues(alpha: 0.6)
        : Colors.green.withValues(alpha: 0.45);
    final changedText = hasPendingChanges
        ? 'Cambios sin publicar'
        : 'Sin cambios pendientes';
    final changedIcon = hasPendingChanges
        ? Icons.edit_note_rounded
        : Icons.task_alt_rounded;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 1040;
            final summary = Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Última sincronización: $lastLoaded',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  '• $itemCount elementos',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  '• Estado: $publishedState',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                _statusChip(
                  context,
                  icon: changedIcon,
                  text: changedText,
                  customBackground: changedColor,
                  customBorder: changedBorder,
                ),
                PopupMenuButton<String>(
                  tooltip: 'Información avanzada',
                  icon: const Icon(Icons.info_outline_rounded, size: 20),
                  itemBuilder: (_) => [
                    PopupMenuItem<String>(
                      enabled: false,
                      child: Text('Versión: ${versionId ?? 'n/d'}'),
                    ),
                    PopupMenuItem<String>(
                      enabled: false,
                      child: Text('Proyecto: $selectedProject'),
                    ),
                    PopupMenuItem<String>(
                      enabled: false,
                      child: Text('Estado técnico: $publicationStatus'),
                    ),
                    PopupMenuItem<String>(
                      enabled: false,
                      child: Text('Última carga: $lastLoaded'),
                    ),
                  ],
                ),
              ],
            );

            final filterBar = Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 168,
                  child: DropdownButtonFormField<String>(
                    initialValue: projectOptions.contains(selectedProject)
                        ? selectedProject
                        : null,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Proyecto',
                      isDense: true,
                    ),
                    items: projectOptions
                        .map((id) => DropdownMenuItem(value: id, child: Text(id)))
                        .toList(),
                    onChanged: isBusy
                        ? null
                        : (value) {
                            if (value != null && value.isNotEmpty) {
                              onProjectSelected(value);
                            }
                          },
                  ),
                ),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment<bool>(value: false, label: Text('Modo Ver')),
                    ButtonSegment<bool>(value: true, label: Text('Modo Editar')),
                  ],
                  selected: {isEditMode},
                  onSelectionChanged:
                      isBusy ? null : (set) => onEditModeChanged(set.first),
                ),
              ],
            );

            final actionsBar = Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: isBusy ? null : onRefresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Actualizar'),
                ),
                FilledButton.icon(
                  onPressed: isBusy ? null : () => onValidate(),
                  icon: const Icon(Icons.rule),
                  label: const Text('Validar'),
                ),
                OutlinedButton.icon(
                  onPressed: (isBusy || !isEditMode) ? null : () => onPublish(),
                  icon: const Icon(Icons.publish),
                  label: const Text('Publicar'),
                ),
                OutlinedButton.icon(
                  onPressed: (isBusy || !isEditMode) ? null : () => onRollback(),
                  icon: const Icon(Icons.restore),
                  label: const Text('Rollback'),
                ),
              ],
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  summary,
                  const SizedBox(height: 10),
                  filterBar,
                  const SizedBox(height: 10),
                  actionsBar,
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: summary),
                    const SizedBox(width: 12),
                    actionsBar,
                  ],
                ),
                const SizedBox(height: 10),
                filterBar,
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _statusChip(BuildContext context,
      {required IconData icon,
      required String text,
      Color? customBackground,
      Color? customBorder}) {
    final colors = Theme.of(context).colorScheme;
    final bg = customBackground ?? colors.surfaceContainerHighest;
    final border = customBorder ?? colors.outlineVariant;
    final fg = _readableForeground(bg);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            text,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(String status) {
    return switch (status.trim().toLowerCase()) {
      'published' => 'Publicado',
      'draft' => 'Borrador',
      'warning' => 'Con observaciones',
      _ => 'No definido',
    };
  }
}

class CatalogsTabBar extends StatelessWidget {
  final CatalogTab selectedTab;
  final Map<CatalogTab, int> counts;
  final ValueChanged<CatalogTab> onTabChanged;

  const CatalogsTabBar({
    super.key,
    required this.selectedTab,
    required this.counts,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: CatalogTab.values.map((tab) {
          final selected = tab == selectedTab;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              selected: selected,
              shape: StadiumBorder(
                side: BorderSide(color: colors.outlineVariant),
              ),
              selectedColor: colors.primaryContainer,
              backgroundColor: colors.surface,
              onSelected: (_) => onTabChanged(tab),
              label: RichText(
                text: TextSpan(
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: selected
                            ? _readableForeground(colors.primaryContainer)
                            : colors.onSurface,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      ),
                  children: [
                    TextSpan(text: tab.label),
                    TextSpan(
                      text: ' (${counts[tab] ?? 0})',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: selected
                                ? _readableForeground(
                                        colors.primaryContainer)
                                    .withValues(alpha: 0.78)
                                : colors.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class CatalogsToolbar extends StatelessWidget {
  final CatalogTab tab;
  final CatalogTabUiState tabUiState;
  final bool isBusy;
  final bool isEditMode;
  final int visibleCount;
  final int totalCount;
  final bool hasActiveFilters;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<ActiveFilter> onFilterChanged;
  final ValueChanged<CatalogSortSpec> onSortChanged;
  final String? selectedActivityId;
  final String? selectedSubcategoryId;
  final String? selectedTopicType;
  final List<CatItem> activityFilterOptions;
  final List<CatItem> subcategoryFilterOptions;
  final List<CatItem> topicTypeFilterOptions;
  final ValueChanged<String?> onActivityScopeChanged;
  final ValueChanged<String?> onSubcategoryScopeChanged;
  final ValueChanged<String?> onTopicTypeScopeChanged;
  final VoidCallback onAdd;
  final VoidCallback onRefresh;
  final VoidCallback onClearFilters;
  final VoidCallback? onToggleReorder;

  const CatalogsToolbar({
    super.key,
    required this.tab,
    required this.tabUiState,
    required this.isBusy,
    required this.isEditMode,
    required this.visibleCount,
    required this.totalCount,
    required this.hasActiveFilters,
    required this.onQueryChanged,
    required this.onFilterChanged,
    required this.onSortChanged,
    required this.selectedActivityId,
    required this.selectedSubcategoryId,
    required this.selectedTopicType,
    required this.activityFilterOptions,
    required this.subcategoryFilterOptions,
    required this.topicTypeFilterOptions,
    required this.onActivityScopeChanged,
    required this.onSubcategoryScopeChanged,
    required this.onTopicTypeScopeChanged,
    required this.onAdd,
    required this.onRefresh,
    required this.onClearFilters,
    required this.onToggleReorder,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 260,
              child: TextFormField(
                initialValue: tabUiState.query,
                onChanged: onQueryChanged,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  labelText: 'Buscar (ID / nombre)',
                  isDense: true,
                ),
              ),
            ),
            DropdownButton<ActiveFilter>(
              value: tabUiState.activeFilter,
              onChanged: isBusy
                  ? null
                  : (value) {
                      if (value != null) onFilterChanged(value);
                    },
              items: const [
                DropdownMenuItem(value: ActiveFilter.all, child: Text('Todos')),
                DropdownMenuItem(
                    value: ActiveFilter.active, child: Text('Activos')),
                DropdownMenuItem(
                    value: ActiveFilter.inactive, child: Text('Inactivos')),
              ],
            ),
            DropdownButton<CatalogSortField>(
              value: tabUiState.sort.field,
              onChanged: isBusy
                  ? null
                  : (field) {
                      if (field == null) return;
                      onSortChanged(tabUiState.sort.copyWith(field: field));
                    },
              items: const [
                DropdownMenuItem(
                    value: CatalogSortField.name,
                    child: Text('Ordenar: Nombre')),
                DropdownMenuItem(
                    value: CatalogSortField.id, child: Text('Ordenar: ID')),
                DropdownMenuItem(
                    value: CatalogSortField.active,
                    child: Text('Ordenar: Activo')),
                DropdownMenuItem(
                    value: CatalogSortField.order,
                    child: Text('Ordenar: Orden')),
              ],
            ),
            IconButton(
              tooltip: tabUiState.sort.ascending ? 'Ascendente' : 'Descendente',
              onPressed: isBusy
                  ? null
                  : () => onSortChanged(tabUiState.sort
                      .copyWith(ascending: !tabUiState.sort.ascending)),
              icon: Icon(tabUiState.sort.ascending ? Icons.south : Icons.north),
            ),
            if (tab == CatalogTab.activities && onToggleReorder != null)
              FilterChip(
                label: const Text('Modo ordenar'),
                selected: tabUiState.reorderMode,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHigh,
                selectedColor: Theme.of(context).colorScheme.primaryContainer,
                checkmarkColor:
                    Theme.of(context).colorScheme.onPrimaryContainer,
                labelStyle: TextStyle(
                  color: tabUiState.reorderMode
                      ? _readableForeground(
                          Theme.of(context).colorScheme.primaryContainer)
                      : _readableForeground(
                          Theme.of(context).colorScheme.surfaceContainerHigh),
                  fontWeight: FontWeight.w600,
                ),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                onSelected: isBusy ? null : (_) => onToggleReorder!(),
              ),
            if (tab == CatalogTab.subcategories || tab == CatalogTab.purposes)
              DropdownButton<String?>(
                value: selectedActivityId,
                onChanged: isBusy ? null : onActivityScopeChanged,
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Actividad: Todas'),
                  ),
                  ...activityFilterOptions.map(
                    (entry) => DropdownMenuItem<String?>(
                      value: entry.id,
                      child: Text('Actividad: ${entry.name}'),
                    ),
                  ),
                ],
              ),
            if (tab == CatalogTab.purposes)
              DropdownButton<String?>(
                value: selectedSubcategoryId,
                onChanged: isBusy ? null : onSubcategoryScopeChanged,
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Subcategoría: Todas'),
                  ),
                  ...subcategoryFilterOptions.map(
                    (entry) => DropdownMenuItem<String?>(
                      value: entry.id,
                      child: Text('Subcategoría: ${entry.name}'),
                    ),
                  ),
                ],
              ),
            if (tab == CatalogTab.topics)
              DropdownButton<String?>(
                value: selectedTopicType,
                onChanged: isBusy ? null : onTopicTypeScopeChanged,
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Tipo: Todos'),
                  ),
                  ...topicTypeFilterOptions.map(
                    (entry) => DropdownMenuItem<String?>(
                      value: entry.id,
                      child: Text('Tipo: ${entry.name}'),
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              'Mostrando $visibleCount de $totalCount ${tab.entityLabel.toLowerCase()}s',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(width: 12),
            if (hasActiveFilters)
              TextButton.icon(
                onPressed: isBusy ? null : onClearFilters,
                icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
                label: const Text('Limpiar filtros'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: (isBusy || !isEditMode) ? null : onAdd,
              icon: const Icon(Icons.add),
              label: Text('Agregar ${tab.entityLabel}'),
            ),
            OutlinedButton.icon(
              onPressed: isBusy ? null : onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Actualizar'),
            ),
          ],
        ),
      ],
    );
  }
}

class CatalogDataTable extends StatelessWidget {
  final List<DataColumn> columns;
  final List<DataRow> rows;

  const CatalogDataTable({
    super.key,
    required this.columns,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: MediaQuery.of(context).size.width,
        child: SingleChildScrollView(
          child: DataTable(columns: columns, rows: rows),
        ),
      ),
    );
  }
}

class ActivityTopicRelationsEditor extends StatelessWidget {
  final List<CatalogActivityItem> activities;
  final List<CatalogTopicItem> topics;
  final List<CatalogRelationItem> relations;
  final String? selectedActivityId;
  final String query;
  final bool showSuggestedOnly;
  final ValueChanged<String> onSelectActivity;
  final ValueChanged<bool> onToggleSuggestedOnly;
  final Future<void> Function(
      String activityId, String topicId, bool currentlySelected) onToggleTopic;
  final VoidCallback onAddRelation;
  final bool isEditMode;
  final bool isBusy;

  const ActivityTopicRelationsEditor({
    super.key,
    required this.activities,
    required this.topics,
    required this.relations,
    required this.selectedActivityId,
    required this.query,
    required this.showSuggestedOnly,
    required this.onSelectActivity,
    required this.onToggleSuggestedOnly,
    required this.onToggleTopic,
    required this.onAddRelation,
    required this.isEditMode,
    required this.isBusy,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final q = query.trim().toLowerCase();
    final filteredActivities = activities.where((entry) {
      if (showSuggestedOnly && !entry.isActive) return false;
      if (q.isEmpty) return true;
      return entry.id.toLowerCase().contains(q) ||
          entry.name.toLowerCase().contains(q);
    }).toList();

    final selectedActivity = filteredActivities
        .where((entry) => entry.id == selectedActivityId)
        .firstOrNull;

    final topicPool = showSuggestedOnly
        ? topics.where((entry) => entry.isActive).toList()
        : topics;

    final selectedTopicIds = relations
        .where((entry) =>
            entry.activityId == selectedActivity?.id && entry.isActive)
        .map((entry) => entry.topicId)
        .toSet();
    final selectedTopicsCount = selectedTopicIds.length;

    return Row(
      children: [
        SizedBox(
          width: 320,
          child: Card(
            margin: EdgeInsets.zero,
            child: ListView.builder(
              itemCount: filteredActivities.length,
              itemBuilder: (context, index) {
                final item = filteredActivities[index];
                final selected = item.id == selectedActivity?.id;
                final selectedColor =
                    Theme.of(context).colorScheme.primaryContainer;
                final selectedForeground = _readableForeground(selectedColor);
                return ListTile(
                  selected: selected,
                  selectedTileColor: selectedColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  title: Text(
                    item.name,
                    style: TextStyle(
                      color: selected
                          ? selectedForeground
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    item.id,
                    style: TextStyle(
                      color: selected
                          ? selectedForeground.withValues(alpha: 0.88)
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: item.isActive
                      ? Icon(
                          Icons.check_circle,
                          color: selected
                              ? selectedForeground
                              : Theme.of(context).colorScheme.primary,
                          size: 18,
                        )
                      : Icon(
                          Icons.pause_circle,
                          color: selected
                              ? selectedForeground
                              : Theme.of(context).colorScheme.error,
                          size: 18,
                        ),
                  onTap: () => onSelectActivity(item.id),
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: selectedActivity == null
                  ? const Center(
                      child: Text(
                          'Selecciona una actividad para editar relaciones'),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Temas de ${selectedActivity.name} (${selectedActivity.id}) · $selectedTopicsCount/${topicPool.length}',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                            FilterChip(
                              label: Text(showSuggestedOnly
                                  ? 'Solo activos'
                                  : 'Todos los temas'),
                              selected: showSuggestedOnly,
                              backgroundColor: colors.surfaceContainerHigh,
                              selectedColor: colors.primaryContainer,
                              checkmarkColor: colors.onPrimaryContainer,
                              labelStyle: TextStyle(
                                color: showSuggestedOnly
                                    ? _readableForeground(
                                        colors.primaryContainer)
                                    : _readableForeground(
                                        colors.surfaceContainerHigh),
                                fontWeight: FontWeight.w600,
                              ),
                              side: BorderSide(color: colors.outlineVariant),
                              onSelected: (value) =>
                                  onToggleSuggestedOnly(value),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: (isBusy || !isEditMode)
                                  ? null
                                  : onAddRelation,
                              icon: const Icon(Icons.add_link),
                              label: const Text('Agregar relación'),
                            ),
                          ],
                        ),
                        if (!selectedActivity.isActive)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Actividad inactiva: la edición de relaciones está bloqueada.',
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error),
                            ),
                          ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: topicPool.map((topic) {
                                final selected =
                                    selectedTopicIds.contains(topic.id);
                                return FilterChip(
                                  selected: selected,
                                  label: Text('${topic.name} (${topic.id})'),
                                  backgroundColor: colors.surfaceContainerHigh,
                                  disabledColor: colors.surfaceContainerHighest,
                                  selectedColor: colors.secondaryContainer,
                                  checkmarkColor: colors.onSecondaryContainer,
                                  labelStyle: TextStyle(
                                    color: selected
                                        ? _readableForeground(
                                            colors.secondaryContainer)
                                        : _readableForeground(
                                            colors.surfaceContainerHigh),
                                    fontWeight: FontWeight.w600,
                                  ),
                                  side:
                                      BorderSide(color: colors.outlineVariant),
                                  onSelected: (!selectedActivity.isActive ||
                                          isBusy ||
                                          !isEditMode)
                                      ? null
                                      : (_) => onToggleTopic(
                                          selectedActivity.id,
                                          topic.id,
                                          selected),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RowActionsMenu extends StatelessWidget {
  final bool enabled;
  final bool isActive;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  const _RowActionsMenu({
    required this.enabled,
    required this.isActive,
    required this.onEdit,
    required this.onDuplicate,
    required this.onToggleActive,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      enabled: enabled,
      tooltip: enabled ? 'Más acciones' : 'Activa Modo Editar',
      onSelected: (value) {
        switch (value) {
          case 'edit':
            onEdit();
            break;
          case 'duplicate':
            onDuplicate();
            break;
          case 'toggle':
            onToggleActive();
            break;
          case 'delete':
            onDelete();
            break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'edit', child: Text('Editar')),
        const PopupMenuItem(value: 'duplicate', child: Text('Duplicar')),
        PopupMenuItem(
          value: 'toggle',
          child: Text(isActive ? 'Desactivar' : 'Activar'),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
      ],
    );
  }
}

extension on CatalogTab {
  String get label {
    switch (this) {
      case CatalogTab.activities:
        return 'Actividades';
      case CatalogTab.subcategories:
        return 'Subcategorías';
      case CatalogTab.purposes:
        return 'Propósitos';
      case CatalogTab.topics:
        return 'Temas de captura';
      case CatalogTab.relations:
        return 'Relaciones';
      case CatalogTab.results:
        return 'Resultados';
      case CatalogTab.assistants:
        return 'Asistentes';
    }
  }

  String get entityLabel {
    switch (this) {
      case CatalogTab.activities:
        return 'Actividad';
      case CatalogTab.subcategories:
        return 'Subcategoría';
      case CatalogTab.purposes:
        return 'Propósito';
      case CatalogTab.topics:
        return 'Tema';
      case CatalogTab.relations:
        return 'Relación';
      case CatalogTab.results:
        return 'Resultado';
      case CatalogTab.assistants:
        return 'Asistente';
    }
  }
}

extension _FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
