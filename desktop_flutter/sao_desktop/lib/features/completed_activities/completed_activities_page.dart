import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/widgets.dart' as pw;
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers/project_providers.dart';
import '../../data/repositories/evidence_repository.dart';
import '../../ui/sao_ui.dart';
import '../digital_records/digital_records_colors.dart';
import '../reports/reports_provider.dart' as reports;
import 'completed_activities_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Page root
// ─────────────────────────────────────────────────────────────────────────────

class CompletedActivitiesPage extends ConsumerStatefulWidget {
  const CompletedActivitiesPage({super.key});

  @override
  ConsumerState<CompletedActivitiesPage> createState() =>
      _CompletedActivitiesPageState();
}

class _CompletedActivitiesPageState
    extends ConsumerState<CompletedActivitiesPage> {
  final _searchCtrl = TextEditingController();
  String? _selectedActivityId;
  DateTime _lastSearch = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final globalProject = ref.read(activeProjectIdProvider);
      if (globalProject.isNotEmpty) {
        ref.read(completedProjectFilterProvider.notifier).state = globalProject;
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _clearAll() {
    _searchCtrl.clear();
    ref.read(completedProjectFilterProvider.notifier).state = '';
    ref.read(completedSearchQueryProvider.notifier).state    = '';
    ref.read(completedFrenteFilterProvider.notifier).state   = '';
    ref.read(completedTemaFilterProvider.notifier).state     = '';
    ref.read(completedEstadoFilterProvider.notifier).state   = '';
    ref.read(completedMunicipioFilterProvider.notifier).state = '';
    ref.read(completedUsuarioFilterProvider.notifier).state  = '';
  }

  void _resetDependentFilters() {
    ref.read(completedFrenteFilterProvider.notifier).state   = '';
    ref.read(completedTemaFilterProvider.notifier).state     = '';
    ref.read(completedEstadoFilterProvider.notifier).state   = '';
    ref.read(completedMunicipioFilterProvider.notifier).state = '';
    ref.read(completedUsuarioFilterProvider.notifier).state  = '';
  }

  void _ensureSelection(List<CompletedActivity> items) {
    if (items.isEmpty) {
      if (_selectedActivityId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() => _selectedActivityId = null);
        });
      }
      return;
    }

    final alreadySelected =
        _selectedActivityId != null && items.any((item) => item.id == _selectedActivityId);
    if (alreadySelected) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _selectedActivityId = items.first.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final projectsAsync   = ref.watch(availableProjectsProvider);
    final selectedProject = ref.watch(completedProjectFilterProvider);
    final activitiesAsync = ref.watch(completedActivitiesProvider);

    // Reset dependent filters when project changes
    ref.listen(completedProjectFilterProvider, (_, __) {
      _resetDependentFilters();
    });

    return Scaffold(
      backgroundColor: SaoColors.scaffoldBackgroundFor(context),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PageHeader(
            total: activitiesAsync.maybeWhen(
                data: (d) => d.length, orElse: () => null),
            hasSelection: _selectedActivityId != null,
            onRefresh: () {
              ref.invalidate(completedActivitiesProvider);
              ref.invalidate(completedFilterOptionsProvider);
            },
          ),

          _FilterBar(
            projectsAsync:    projectsAsync,
            selectedProject:  selectedProject,
            searchCtrl:       _searchCtrl,
            searchSuggestions: activitiesAsync.maybeWhen(
              data: (items) => items
                  .expand((a) => [a.pk, a.title, a.activityType])
                  .where((v) => v.trim().isNotEmpty)
                  .toSet()
                  .toList(growable: false),
              orElse: () => const <String>[],
            ),
            onProjectChanged: (v) {
              ref.read(completedProjectFilterProvider.notifier).state = v ?? '';
            },
            onSearchChanged: (v) {
              final now = DateTime.now();
              if (now.difference(_lastSearch) >
                  const Duration(milliseconds: 350)) {
                _lastSearch = now;
                ref.read(completedSearchQueryProvider.notifier).state = v;
              }
            },
            onClearAll: _clearAll,
          ),

          const Divider(height: 1),

          Expanded(
            child: activitiesAsync.when(
              loading: () => const _TableSkeletonState(),
              error: (e, _) => _ErrorState(message: e.toString()),
              data: (items) {
                _ensureSelection(items);
                if (items.isEmpty) {
                  return const _EmptyState();
                }
                return Column(
                  children: [
                    _RecordsSummary(items: items),
                    Expanded(
                      child: _SplitView(
                        items: items,
                        selectedActivityId: _selectedActivityId,
                        onSelectActivity: (id) =>
                            setState(() => _selectedActivityId = id),
                        onCloseDetail: () =>
                            setState(() => _selectedActivityId = null),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────

class _PageHeader extends StatelessWidget {
  final int? total;
  final bool hasSelection;
  final VoidCallback onRefresh;

  const _PageHeader({
    this.total,
    required this.hasSelection,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: DigitalRecordColors.headerSurfaceFor(context),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(
        children: [
          const Icon(Icons.folder_copy_rounded, color: DigitalRecordColors.accent, size: 20),
          const SizedBox(width: 10),
          Text('Expediente digital',
              style: SaoTypography.pageTitle.copyWith(fontSize: 17)),
          const SizedBox(width: 8),
          if (total != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: SaoColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('$total',
                  style: SaoTypography.bodyTextBold
                      .copyWith(color: SaoColors.success, fontSize: 12)),
            ),
          const Spacer(),
          if (hasSelection)
            Text('Trazabilidad completa →',
                style: SaoTypography.caption
                    .copyWith(color: DigitalRecordColors.accent, fontSize: 12)),
          const SizedBox(width: 16),
          Text('Proyectos, frentes, estados y documentos aprobados',
              style: SaoTypography.caption
                .copyWith(color: SaoColors.gray600, fontSize: 11)),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 18),
            tooltip: 'Actualizar',
            onPressed: onRefresh,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }
}

class _RecordsSummary extends StatelessWidget {
  final List<CompletedActivity> items;

  const _RecordsSummary({required this.items});

  @override
  Widget build(BuildContext context) {
    final uniqueProjects = items
        .map((item) => item.projectId.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .length;
    final uniqueFronts = items
        .map((item) => item.front.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .length;
    final uniqueStates = items
        .map((item) => item.estado.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .length;
    final generatedDocs = items.where((item) => item.hasReport).length;
    final totalEvidence = items.fold<int>(
      0,
      (sum, item) => sum + item.evidenceCount,
    );

    return Container(
      width: double.infinity,
      color: SaoColors.surfaceMutedFor(context),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _SummaryChip(
            label: 'Proyectos',
            value: '$uniqueProjects',
            icon: Icons.domain_rounded,
          ),
          _SummaryChip(
            label: 'Frentes',
            value: '$uniqueFronts',
            icon: Icons.alt_route_rounded,
          ),
          _SummaryChip(
            label: 'Estados',
            value: '$uniqueStates',
            icon: Icons.map_outlined,
          ),
          _SummaryChip(
            label: 'Documentos generados',
            value: '$generatedDocs',
            icon: Icons.description_outlined,
          ),
          _SummaryChip(
            label: 'Evidencias',
            value: '$totalEvidence',
            icon: Icons.photo_library_outlined,
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _SummaryChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: SaoColors.surfaceFor(context),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: SaoColors.borderFor(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: DigitalRecordColors.accentSurfaceFor(context),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Icon(icon, color: DigitalRecordColors.accent, size: 12),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: SaoTypography.bodyTextBold.copyWith(
              color: DigitalRecordColors.accent,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: SaoTypography.caption.copyWith(
              color: SaoColors.textMutedFor(context),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter bar  — all dropdowns, options loaded from backend
// ─────────────────────────────────────────────────────────────────────────────

class _FilterBar extends ConsumerWidget {
  final AsyncValue<List<String>> projectsAsync;
  final String selectedProject;
  final TextEditingController searchCtrl;
  final List<String> searchSuggestions;
  final ValueChanged<String?> onProjectChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearAll;

  const _FilterBar({
    required this.projectsAsync,
    required this.selectedProject,
    required this.searchCtrl,
    required this.searchSuggestions,
    required this.onProjectChanged,
    required this.onSearchChanged,
    required this.onClearAll,
  });

  static InputDecoration _deco(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12, color: SaoColors.gray400),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: SaoColors.gray200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: SaoColors.gray200),
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final optAsync = ref.watch(completedFilterOptionsProvider);
    final opts = optAsync.maybeWhen(
        data: (o) => o, orElse: () => const FilterOptions.empty());
    final isLoading = optAsync.isLoading;

    final tema      = ref.watch(completedTemaFilterProvider);
    final municipio = ref.watch(completedMunicipioFilterProvider);
    final usuario   = ref.watch(completedUsuarioFilterProvider);

    return Container(
      color: SaoColors.surfaceFor(context),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
          // ── Búsqueda libre ──────────────────────────────────────────────────
              SizedBox(
                width: 280,
                child: _SearchAutocompleteField(
                  controller: searchCtrl,
                  suggestions: searchSuggestions,
                  onChanged: onSearchChanged,
                ),
              ),

          // ── Tema / Tipo ─────────────────────────────────────────────────────
          _OptionDropdown(
            label: 'Tema / Tipo',
            width: 150,
            value: tema.isEmpty ? null : tema,
            options: opts.temas,
            loading: isLoading,
            onChanged: (v) =>
                ref.read(completedTemaFilterProvider.notifier).state = v ?? '',
          ),

          // ── Municipio ───────────────────────────────────────────────────────
          _OptionDropdown(
            label: 'Municipio',
            width: 150,
            value: municipio.isEmpty ? null : municipio,
            options: opts.municipios,
            loading: isLoading,
            onChanged: (v) =>
                ref.read(completedMunicipioFilterProvider.notifier).state =
                    v ?? '',
          ),

          // ── Responsable ─────────────────────────────────────────────────────
          _OptionDropdown(
            label: 'Responsable',
            width: 170,
            value: usuario.isEmpty ? null : usuario,
            options: opts.usuarios,
            loading: isLoading,
            icon: Icons.person_outlined,
            onChanged: (v) =>
                ref.read(completedUsuarioFilterProvider.notifier).state =
                    v ?? '',
          ),

          // ── Limpiar ─────────────────────────────────────────────────────────
              OutlinedButton.icon(
                onPressed: onClearAll,
                icon: const Icon(Icons.filter_alt_off_rounded, size: 15),
                label: const Text('Limpiar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: SaoColors.gray700,
                  side: BorderSide(color: SaoColors.borderFor(context)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  textStyle: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Reusable options dropdown with "Todos" as first element
class _OptionDropdown extends StatelessWidget {
  final String label;
  final double width;
  final String? value;
  final List<String> options;
  final bool loading;
  final IconData? icon;
  final ValueChanged<String?> onChanged;

  const _OptionDropdown({
    required this.label,
    required this.width,
    required this.value,
    required this.options,
    required this.onChanged,
    this.loading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedOptions = <String, String>{};
    for (final raw in options) {
      final option = raw.trim();
      if (option.isEmpty) continue;
      normalizedOptions.putIfAbsent(option.toLowerCase(), () => option);
    }
    final dedupedOptions = normalizedOptions.values.toList();

    String? safeValue;
    final current = (value ?? '').trim();
    if (current.isNotEmpty) {
      safeValue = normalizedOptions[current.toLowerCase()];
    }

    return SizedBox(
      width: width,
      child: DropdownButtonFormField<String>(
          initialValue: safeValue,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: loading ? '$label…' : label,
            labelStyle: const TextStyle(fontSize: 12, color: SaoColors.gray400),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          prefixIcon: icon != null
              ? Icon(icon, size: 15, color: SaoColors.gray400)
              : null,
          prefixIconConstraints:
              const BoxConstraints(minWidth: 28, minHeight: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: SaoColors.gray200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: SaoColors.gray200),
          ),
          suffixIcon: loading
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  ),
                )
              : null,
        ),
        items: [
          const DropdownMenuItem<String>(
              value: null, child: Text('Todos', style: TextStyle(fontSize: 13))),
          ...dedupedOptions.map((o) => DropdownMenuItem<String>(
                value: o,
                child:
                    Text(o, style: const TextStyle(fontSize: 13)),
              )),
        ],
        onChanged: loading ? null : onChanged,
      ),
    );
  }
}

class _SearchAutocompleteField extends StatelessWidget {
  final TextEditingController controller;
  final List<String> suggestions;
  final ValueChanged<String> onChanged;

  const _SearchAutocompleteField({
    required this.controller,
    required this.suggestions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: controller.text),
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.trim().toLowerCase();
        if (query.isEmpty) return const Iterable<String>.empty();
        return suggestions.where(
          (s) => s.toLowerCase().contains(query),
        ).take(8);
      },
      onSelected: (value) {
        controller.text = value;
        onChanged(value);
      },
      fieldViewBuilder: (context, textCtrl, focusNode, onFieldSubmitted) {
        if (textCtrl.text != controller.text) {
          textCtrl.value = TextEditingValue(
            text: controller.text,
            selection: TextSelection.collapsed(offset: controller.text.length),
          );
        }
        return TextField(
          controller: textCtrl,
          focusNode: focusNode,
          decoration: _FilterBar._deco('Buscar PK / título…'),
          onChanged: (value) {
            controller.text = value;
            onChanged(value);
          },
          onSubmitted: onChanged,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Split view: table ← → detail panel
// ─────────────────────────────────────────────────────────────────────────────

class _SplitView extends StatefulWidget {
  final List<CompletedActivity> items;
  final String? selectedActivityId;
  final ValueChanged<String> onSelectActivity;
  final VoidCallback onCloseDetail;

  const _SplitView({
    required this.items,
    required this.selectedActivityId,
    required this.onSelectActivity,
    required this.onCloseDetail,
  });

  static const _treeWidth = 272.0;
  static const _panelWidth = 440.0;

  @override
  State<_SplitView> createState() => _SplitViewState();
}

class _SplitViewState extends State<_SplitView> {
  bool _isHierarchyCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final selectedItem = widget.selectedActivityId == null
        ? null
        : widget.items.cast<CompletedActivity?>().firstWhere(
              (item) => item?.id == widget.selectedActivityId,
              orElse: () => null,
            );

    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          width: _isHierarchyCollapsed ? 44 : _SplitView._treeWidth,
          child: _isHierarchyCollapsed
              ? Center(
                  child: IconButton(
                    tooltip: 'Mostrar carpetas SAO',
                    onPressed: () => setState(() => _isHierarchyCollapsed = false),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                )
              : _HierarchyPanel(
                  onCollapse: () => setState(() => _isHierarchyCollapsed = true),
                ),
        ),
        const VerticalDivider(width: 1, thickness: 1),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _MasterPaneHeader(
                total: widget.items.length,
                selectedItem: selectedItem,
                onClearSelection: widget.selectedActivityId == null
                    ? null
                    : () => widget.onCloseDetail(),
              ),
              Expanded(
                child: _ActivitiesTable(
                  items: widget.items,
                  selectedActivityId: widget.selectedActivityId,
                  onTap: widget.onSelectActivity,
                ),
              ),
            ],
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          width: _SplitView._panelWidth,
          clipBehavior: Clip.hardEdge,
          decoration: const BoxDecoration(),
          child: widget.selectedActivityId != null
              ? _DetailPanel(
                  activityId: widget.selectedActivityId!,
                  onClose: widget.onCloseDetail,
                )
              : const _DetailPlaceholder(),
        ),
      ],
    );
  }
}

class _MasterPaneHeader extends StatelessWidget {
  const _MasterPaneHeader({
    required this.total,
    required this.selectedItem,
    required this.onClearSelection,
  });

  final int total;
  final CompletedActivity? selectedItem;
  final VoidCallback? onClearSelection;

  @override
  Widget build(BuildContext context) {
    final title = selectedItem == null
        ? 'Selecciona un expediente para ver su trazabilidad'
        : (selectedItem!.title.isNotEmpty ? selectedItem!.title : selectedItem!.activityType);
    final subtitle = selectedItem == null
        ? '$total expedientes en resultado'
        : '${selectedItem!.pk.isEmpty ? selectedItem!.id : selectedItem!.pk} · ${selectedItem!.projectId} · ${selectedItem!.front}';

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        color: SaoColors.surfaceFor(context),
        border: Border(
          bottom: BorderSide(color: SaoColors.borderFor(context)),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: DigitalRecordColors.accentSurfaceFor(context),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.table_rows_rounded,
              size: 14,
              color: DigitalRecordColors.accent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SaoTypography.bodyTextBold.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SaoTypography.caption.copyWith(
                    color: SaoColors.textMutedFor(context),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (onClearSelection != null)
            TextButton.icon(
              onPressed: onClearSelection,
              icon: const Icon(Icons.deselect_rounded, size: 14),
              label: const Text('Limpiar selección'),
            ),
        ],
      ),
    );
  }
}

class _HierarchyPanel extends ConsumerWidget {
  final VoidCallback onCollapse;

  const _HierarchyPanel({required this.onCollapse});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(completedActivitiesProvider);
    final selectedProject = ref.watch(completedProjectFilterProvider);
    final selectedFront = ref.watch(completedFrenteFilterProvider);
    final selectedState = ref.watch(completedEstadoFilterProvider);

    return Container(
      color: SaoColors.surfaceFor(context),
      child: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No se pudo construir el árbol del expediente: $error',
            style: SaoTypography.caption,
          ),
        ),
        data: (items) {
          final tree = _buildHierarchy(items);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Carpetas SAO', style: SaoTypography.sectionTitle),
                          const SizedBox(height: 4),
                          Text(
                            'Proyecto > Frente > Estado. Abre una carpeta para navegar el expediente.',
                            style: SaoTypography.caption.copyWith(
                              color: SaoColors.textMutedFor(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Colapsar carpetas',
                      onPressed: onCollapse,
                      icon: const Icon(Icons.chevron_left_rounded, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FolderBreadcrumbBar(
                      project: selectedProject,
                      front: selectedFront,
                      state: selectedState,
                    ),
                    const SizedBox(height: 10),
                    _FolderPathTile(
                      level: 0,
                      title: 'Proyecto',
                      value: selectedProject.isEmpty ? 'Raiz de proyectos' : selectedProject,
                      isOpen: selectedProject.isNotEmpty,
                      icon: Icons.folder_copy_outlined,
                      onTap: () {
                        ref.read(completedProjectFilterProvider.notifier).state = '';
                        ref.read(completedFrenteFilterProvider.notifier).state = '';
                        ref.read(completedEstadoFilterProvider.notifier).state = '';
                      },
                    ),
                    const SizedBox(height: 8),
                    _FolderPathTile(
                      level: 1,
                      title: 'Frente',
                      value: selectedFront.isEmpty ? 'Todos los frentes' : selectedFront,
                      isOpen: selectedFront.isNotEmpty,
                      icon: Icons.folder_open_rounded,
                      onTap: () {
                        ref.read(completedFrenteFilterProvider.notifier).state = '';
                        ref.read(completedEstadoFilterProvider.notifier).state = '';
                      },
                    ),
                    const SizedBox(height: 8),
                    _FolderPathTile(
                      level: 2,
                      title: 'Estado',
                      value: selectedState.isEmpty ? 'Todos los estados' : selectedState,
                      isOpen: selectedState.isNotEmpty,
                      icon: Icons.inventory_2_outlined,
                      onTap: () {
                        ref.read(completedEstadoFilterProvider.notifier).state = '';
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: tree.isEmpty
                    ? const Center(child: Text('Sin expedientes disponibles'))
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(10, 0, 10, 16),
                        children: tree
                            .map(
                              (project) => _ProjectNodeTile(
                                node: project,
                                selectedProject: selectedProject,
                                selectedFront: selectedFront,
                                selectedState: selectedState,
                              ),
                            )
                            .toList(growable: false),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FolderBreadcrumbBar extends StatelessWidget {
  final String project;
  final String front;
  final String state;

  const _FolderBreadcrumbBar({
    required this.project,
    required this.front,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final segments = <String>[
      project.isEmpty ? 'Proyectos' : project,
      front.isEmpty ? 'Frentes' : front,
      state.isEmpty ? 'Estados' : state,
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: DigitalRecordColors.panelSurfaceFor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DigitalRecordColors.borderFor(context)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.folder_zip_rounded,
            size: 15,
            color: DigitalRecordColors.accent,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (var index = 0; index < segments.length; index++) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: index == segments.length - 1
                          ? DigitalRecordColors.accentSurfaceFor(context)
                          : SaoColors.surfaceMutedFor(context),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      segments[index],
                      style: SaoTypography.caption.copyWith(
                        color: index == segments.length - 1
                            ? DigitalRecordColors.accent
                            : SaoColors.textFor(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (index < segments.length - 1)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 14,
                        color: SaoColors.textMutedFor(context),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FolderPathTile extends StatelessWidget {
  final int level;
  final String title;
  final String value;
  final bool isOpen;
  final IconData icon;
  final VoidCallback onTap;

  const _FolderPathTile({
    required this.level,
    required this.title,
    required this.value,
    required this.isOpen,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final leftInset = level * 16.0;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        margin: EdgeInsets.only(left: leftInset),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isOpen
              ? DigitalRecordColors.accentSurfaceFor(context)
              : SaoColors.surfaceMutedFor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isOpen
                ? DigitalRecordColors.selectedBorderFor(context)
                : SaoColors.borderFor(context),
          ),
        ),
        child: Row(
          children: [
            if (level > 0) ...[
              Container(
                width: 10,
                height: 1,
                margin: const EdgeInsets.only(right: 8),
                color: SaoColors.borderFor(context),
              ),
            ],
            Icon(
              isOpen ? Icons.folder_open_rounded : icon,
              size: 16,
              color: isOpen
                  ? DigitalRecordColors.accent
                  : SaoColors.textMutedFor(context),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: SaoTypography.caption.copyWith(
                      color: SaoColors.textMutedFor(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: SaoTypography.bodyTextSmall.copyWith(
                      color: isOpen
                          ? DigitalRecordColors.accent
                          : SaoColors.textFor(context),
                      fontWeight: isOpen ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              isOpen ? 'Abierta' : 'Abrir',
              style: SaoTypography.caption.copyWith(
                color: isOpen
                    ? DigitalRecordColors.accent
                    : SaoColors.textMutedFor(context),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectNodeTile extends ConsumerWidget {
  final _ProjectHierarchyNode node;
  final String selectedProject;
  final String selectedFront;
  final String selectedState;

  const _ProjectNodeTile({
    required this.node,
    required this.selectedProject,
    required this.selectedFront,
    required this.selectedState,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelected = selectedProject == node.projectId;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: isSelected
          ? DigitalRecordColors.selectedSurfaceFor(context)
          : SaoColors.surfaceFor(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? DigitalRecordColors.selectedBorderFor(context)
              : SaoColors.borderFor(context),
        ),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        childrenPadding: const EdgeInsets.only(bottom: 8),
        leading: const Icon(Icons.domain_rounded, size: 18),
        title: Text(node.projectId, style: SaoTypography.bodyTextBold),
        subtitle: Text(
          '${node.activityCount} expedientes · ${node.documentCount} documentos',
          style: SaoTypography.caption,
        ),
        trailing: TextButton(
          onPressed: () {
            ref.read(completedProjectFilterProvider.notifier).state = node.projectId;
            ref.read(completedFrenteFilterProvider.notifier).state = '';
            ref.read(completedEstadoFilterProvider.notifier).state = '';
          },
          child: Text(isSelected ? 'Abierta' : 'Abrir'),
        ),
        children: node.fronts
            .map(
              (front) => _FrontNodeTile(
                projectId: node.projectId,
                node: front,
                selectedProject: selectedProject,
                selectedFront: selectedFront,
                selectedState: selectedState,
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _FrontNodeTile extends ConsumerWidget {
  final String projectId;
  final _FrontHierarchyNode node;
  final String selectedProject;
  final String selectedFront;
  final String selectedState;

  const _FrontNodeTile({
    required this.projectId,
    required this.node,
    required this.selectedProject,
    required this.selectedFront,
    required this.selectedState,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelected = selectedProject == projectId && selectedFront == node.frontName;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        childrenPadding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
        leading: const Icon(Icons.folder_open_rounded, size: 16),
        title: Text(node.frontName, style: SaoTypography.bodyText),
        subtitle: Text(
          '${node.activityCount} expedientes · ${node.documentCount} documentos',
          style: SaoTypography.caption,
        ),
        trailing: TextButton(
          onPressed: () {
            ref.read(completedProjectFilterProvider.notifier).state = projectId;
            ref.read(completedFrenteFilterProvider.notifier).state = node.frontName;
            ref.read(completedEstadoFilterProvider.notifier).state = '';
          },
          child: Text(isSelected ? 'Abierta' : 'Abrir'),
        ),
        children: node.states
            .map(
              (state) => _StateNodeTile(
                projectId: projectId,
                frontName: node.frontName,
                node: state,
                selectedProject: selectedProject,
                selectedFront: selectedFront,
                selectedState: selectedState,
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _StateNodeTile extends ConsumerWidget {
  final String projectId;
  final String frontName;
  final _StateHierarchyNode node;
  final String selectedProject;
  final String selectedFront;
  final String selectedState;

  const _StateNodeTile({
    required this.projectId,
    required this.frontName,
    required this.node,
    required this.selectedProject,
    required this.selectedFront,
    required this.selectedState,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelected =
        selectedProject == projectId && selectedFront == frontName && selectedState == node.stateName;
    return InkWell(
      onTap: () {
        ref.read(completedProjectFilterProvider.notifier).state = projectId;
        ref.read(completedFrenteFilterProvider.notifier).state = frontName;
        ref.read(completedEstadoFilterProvider.notifier).state = node.stateName;
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? DigitalRecordColors.selectedSurfaceFor(context)
              : SaoColors.surfaceMutedFor(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? DigitalRecordColors.selectedBorderFor(context)
                : SaoColors.borderFor(context),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.map_rounded, size: 14, color: SaoColors.gray500),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(node.stateName, style: SaoTypography.bodyTextSmall),
                  const SizedBox(height: 2),
                  Text(
                    '${node.activityCount} expedientes · ${node.documentCount} documentos · ${node.evidenceCount} evidencias',
                    style: SaoTypography.caption,
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, size: 16, color: DigitalRecordColors.accent),
          ],
        ),
      ),
    );
  }
}

List<_ProjectHierarchyNode> _buildHierarchy(List<CompletedActivity> items) {
  final projects = <String, Map<String, List<CompletedActivity>>>{};
  for (final item in items) {
    final projectId = item.projectId.trim().isEmpty ? 'SIN_PROYECTO' : item.projectId.trim();
    final frontName = item.front.trim().isEmpty ? 'Sin frente' : item.front.trim();
    final stateName = item.estado.trim().isEmpty ? 'Sin estado' : item.estado.trim();
    final fronts = projects.putIfAbsent(projectId, () => <String, List<CompletedActivity>>{});
    final frontKey = '$frontName::$stateName';
    fronts.putIfAbsent(frontKey, () => <CompletedActivity>[]).add(item);
  }

  final result = <_ProjectHierarchyNode>[];
  final sortedProjects = projects.keys.toList()..sort();
  for (final projectId in sortedProjects) {
    final groupedFronts = <String, List<CompletedActivity>>{};
    final groupedStates = <String, Map<String, List<CompletedActivity>>>{};
    for (final entry in projects[projectId]!.entries) {
      final parts = entry.key.split('::');
      final frontName = parts.first;
      final stateName = parts.length > 1 ? parts[1] : 'Sin estado';
      groupedFronts.putIfAbsent(frontName, () => <CompletedActivity>[]).addAll(entry.value);
      final states = groupedStates.putIfAbsent(frontName, () => <String, List<CompletedActivity>>{});
      states.putIfAbsent(stateName, () => <CompletedActivity>[]).addAll(entry.value);
    }

    final fronts = groupedFronts.entries.map((frontEntry) {
      final stateMap = groupedStates[frontEntry.key] ?? const <String, List<CompletedActivity>>{};
      final states = stateMap.entries.map((stateEntry) {
        final stateItems = stateEntry.value;
        return _StateHierarchyNode(
          stateName: stateEntry.key,
          activityCount: stateItems.length,
          documentCount: stateItems.where((item) => item.hasReport).length,
          evidenceCount: stateItems.fold<int>(0, (sum, item) => sum + item.evidenceCount),
        );
      }).toList()
        ..sort((a, b) => a.stateName.compareTo(b.stateName));

      return _FrontHierarchyNode(
        frontName: frontEntry.key,
        activityCount: frontEntry.value.length,
        documentCount: frontEntry.value.where((item) => item.hasReport).length,
        states: states,
      );
    }).toList()
      ..sort((a, b) => a.frontName.compareTo(b.frontName));

    final projectItems = groupedFronts.values.expand((items) => items).toList(growable: false);
    result.add(
      _ProjectHierarchyNode(
        projectId: projectId,
        activityCount: projectItems.length,
        documentCount: projectItems.where((item) => item.hasReport).length,
        fronts: fronts,
      ),
    );
  }

  return result;
}

class _ProjectHierarchyNode {
  final String projectId;
  final int activityCount;
  final int documentCount;
  final List<_FrontHierarchyNode> fronts;

  const _ProjectHierarchyNode({
    required this.projectId,
    required this.activityCount,
    required this.documentCount,
    required this.fronts,
  });
}

class _FrontHierarchyNode {
  final String frontName;
  final int activityCount;
  final int documentCount;
  final List<_StateHierarchyNode> states;

  const _FrontHierarchyNode({
    required this.frontName,
    required this.activityCount,
    required this.documentCount,
    required this.states,
  });
}

class _StateHierarchyNode {
  final String stateName;
  final int activityCount;
  final int documentCount;
  final int evidenceCount;

  const _StateHierarchyNode({
    required this.stateName,
    required this.activityCount,
    required this.documentCount,
    required this.evidenceCount,
  });
}

class _TableSkeletonState extends StatelessWidget {
  const _TableSkeletonState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: List.generate(
          8,
          (index) => Container(
            height: 36,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: SaoColors.surfaceRaisedFor(context),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Activities table
// ─────────────────────────────────────────────────────────────────────────────

class _ActivitiesTable extends StatefulWidget {
  final List<CompletedActivity> items;
  final String? selectedActivityId;
  final ValueChanged<String> onTap;

  const _ActivitiesTable({
    required this.items,
    required this.selectedActivityId,
    required this.onTap,
  });

  @override
  State<_ActivitiesTable> createState() => _ActivitiesTableState();
}

class _ActivitiesTableState extends State<_ActivitiesTable> {
  final _vertCtrl  = ScrollController();
  final _horizCtrl = ScrollController();
  final Map<String, bool> _columnVisible = {
    'Proyecto': true,
    'PK': true,
    'Actividad / Tema': true,
    'Frente': true,
    'Estado': true,
    'Municipio': true,
    'Responsable': true,
    'Revisó': true,
    'Duración': true,
    'Decisión': true,
    'Reporte': true,
    'Evidencias': true,
    'Fecha revisión': true,
  };

  @override
  void dispose() {
    _vertCtrl.dispose();
    _horizCtrl.dispose();
    super.dispose();
  }

  String _fmtDate(String raw) {
    if (raw.isEmpty) return '—';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return DateFormat('dd/MM/yy HH:mm').format(dt.toLocal());
  }

  String _durationBetween(String startRaw, String endRaw) {
    final start = DateTime.tryParse(startRaw);
    final end = DateTime.tryParse(endRaw);
    if (start == null || end == null) return '—';
    final diff = end.toLocal().difference(start.toLocal());
    if (diff.inMinutes < 0) return '—';
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    if (h == 0) return '${diff.inMinutes}m';
    return '${h}h ${m}m';
  }

  bool _isMissing(String text) {
    final t = text.trim();
    if (t.isEmpty || t == '—') return true;
    return t.toLowerCase().startsWith('sin ');
  }

  String _titleCase(String text) {
    final normalized = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) return '';
    return normalized
        .split(' ')
        .map((word) {
          final lower = word.toLowerCase();
          return lower.isEmpty
              ? lower
              : '${lower[0].toUpperCase()}${lower.substring(1)}';
        })
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final visible = _columnVisible.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList(growable: false);

    final columns = visible
        .map((name) => DataColumn(label: Text(name)))
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
          child: Row(
            children: [
              const Spacer(),
              PopupMenuButton<String>(
                tooltip: 'Ocultar/mostrar columnas',
                icon: const Icon(Icons.tune_rounded, size: 18),
                itemBuilder: (context) => _columnVisible.entries
                    .map(
                      (e) => CheckedPopupMenuItem<String>(
                        value: e.key,
                        checked: e.value,
                        child: Text(e.key),
                      ),
                    )
                    .toList(growable: false),
                onSelected: (value) {
                  setState(() {
                    final currentlyVisible =
                        _columnVisible.values.where((v) => v).length;
                    final isOn = _columnVisible[value] ?? true;
                    if (isOn && currentlyVisible == 1) return;
                    _columnVisible[value] = !isOn;
                  });
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, viewport) {
              return Scrollbar(
                controller: _vertCtrl,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _vertCtrl,
                  child: Scrollbar(
                    controller: _horizCtrl,
                    thumbVisibility: true,
                    notificationPredicate: (n) => n.depth == 1,
                    child: SingleChildScrollView(
                      controller: _horizCtrl,
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: viewport.maxWidth),
                        child: DataTable(
                          showCheckboxColumn: false,
                          columnSpacing: 12,
                          headingRowHeight: 38,
                          dataRowMinHeight: 40,
                          dataRowMaxHeight: 50,
                          headingRowColor:
                              WidgetStateProperty.all(SaoColors.gray100),
                          border: const TableBorder(
                            horizontalInside:
                                BorderSide(color: SaoColors.gray200, width: 0.5),
                          ),
                          columns: columns,
                          rows: widget.items
                              .map((a) => _buildRow(a, visible))
                              .toList(growable: false),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  DataRow _buildRow(CompletedActivity a, List<String> visible) {
    final isSelected = a.id == widget.selectedActivityId;
    final allCells = <String, DataCell>{
      'Proyecto': DataCell(_pill(a.projectId,
          SaoColors.actionPrimary.withValues(alpha: 0.1),
          SaoColors.actionPrimary)),
      'PK': DataCell(Text(a.pk,
          style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: Color(0xFF475569)))),
      'Actividad / Tema': DataCell(SizedBox(
        width: 190,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              a.title.isNotEmpty ? a.title : a.activityType,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: SaoTypography.bodyText.copyWith(fontSize: 12),
            ),
            if (a.activityType.isNotEmpty && a.title.isNotEmpty)
              Text(a.activityType,
                  style: SaoTypography.caption
                      .copyWith(color: SaoColors.gray400)),
          ],
        ),
      )),
      'Frente': DataCell(_txt(a.front, w: 110)),
      'Estado': DataCell(_txt(a.estado, w: 100)),
      'Municipio': DataCell(_txt(a.municipio, w: 110)),
      'Responsable': DataCell(_txt(_titleCase(a.assignedName), w: 140)),
      'Revisó': DataCell(_txt(_titleCase(a.reviewedByName), w: 140)),
      'Duración': DataCell(Text(
        _durationBetween(a.createdAt, a.reviewedAt),
        style: SaoTypography.caption.copyWith(fontSize: 11, color: SaoColors.gray600),
      )),
      'Decisión': DataCell(_DecisionBadge(decision: a.reviewDecision)),
      'Reporte': DataCell(
        SizedBox(
          width: 96,
          child: Align(
            alignment: Alignment.center,
            child: Text(
              a.hasReport ? 'Generado' : 'Sin reporte',
              style: SaoTypography.caption.copyWith(
                fontSize: 11,
                color: a.hasReport ? DigitalRecordColors.accent : SaoColors.gray500,
                fontWeight: a.hasReport ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
      'Evidencias': DataCell(
        SizedBox(
          width: 72,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.photo_library_outlined, size: 13, color: SaoColors.gray500),
              const SizedBox(width: 4),
              Text(
                '${a.evidenceCount}',
                style: SaoTypography.caption.copyWith(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
      'Fecha revisión': DataCell(
        SizedBox(
          width: 96,
          child: Text(
            _fmtDate(a.reviewedAt),
            style: SaoTypography.caption.copyWith(fontSize: 11, color: SaoColors.gray500),
          ),
        ),
      ),
    };

    return DataRow(
      selected: isSelected,
      color: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return DigitalRecordColors.selectedSurfaceFor(context);
        }
        return null;
      }),
      onSelectChanged: (_) => widget.onTap(a.id),
      cells: visible.map((name) => allCells[name]!).toList(growable: false),
    );
  }

  Widget _pill(String text, Color bg, Color fg) {
    if (text.isEmpty) return const Text('—');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(text,
          style: SaoTypography.caption.copyWith(color: fg, fontSize: 11)),
    );
  }

  Widget _txt(String text, {double? w}) {
    final content = !_isMissing(text)
        ? Text(text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SaoTypography.bodyText.copyWith(fontSize: 12))
        : Text('—',
            style: SaoTypography.caption
            .copyWith(color: SaoColors.gray500, fontWeight: FontWeight.w600));
    return w != null ? SizedBox(width: w, child: content) : content;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Detail panel — full traceability
// ─────────────────────────────────────────────────────────────────────────────

class _DetailPanel extends ConsumerWidget {
  final String activityId;
  final VoidCallback onClose;

  const _DetailPanel({required this.activityId, required this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync =
        ref.watch(completedActivityDetailProvider(activityId));

    return Container(
      decoration: BoxDecoration(
        color: SaoColors.surfaceFor(context),
        border:
            Border(left: BorderSide(color: SaoColors.borderFor(context), width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(-4, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PanelHeader(onClose: onClose),
          const Divider(height: 1),
          Expanded(
            child: detailAsync.when(
              loading: () => const _DetailSkeleton(),
              error: (e, _) => _PanelError(message: e.toString()),
              data: (detail) => _PanelContent(detail: detail),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailPlaceholder extends StatelessWidget {
  const _DetailPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: SaoColors.surfaceFor(context),
        border: Border(
          left: BorderSide(color: SaoColors.borderFor(context), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PanelHeader(onClose: () {}),
          const Divider(height: 1),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: DigitalRecordColors.accentSurfaceFor(context),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.fact_check_outlined,
                        size: 24,
                        color: DigitalRecordColors.accent,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Sin expediente seleccionado',
                      style: SaoTypography.sectionTitle.copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Selecciona una fila de la tabla para ver trazabilidad, evidencias, notas y acciones del expediente.',
                      textAlign: TextAlign.center,
                      style: SaoTypography.caption.copyWith(
                        color: SaoColors.textMutedFor(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  final VoidCallback onClose;
  const _PanelHeader({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: DigitalRecordColors.mutedSurfaceFor(context),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: DigitalRecordColors.accentSurfaceFor(context),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Icon(
              Icons.manage_search_rounded,
              size: 14,
              color: DigitalRecordColors.accent,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Expediente seleccionado',
                    style: SaoTypography.caption.copyWith(
                      color: SaoColors.textMutedFor(context),
                      fontSize: 11,
                    )),
                Text('Trazabilidad completa',
                    style: SaoTypography.bodyTextBold.copyWith(
                      fontSize: 13,
                      color: SaoColors.textFor(context),
                    )),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 16),
            tooltip: 'Cerrar panel',
            onPressed: onClose,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }
}

class _PanelError extends StatelessWidget {
  final String message;
  const _PanelError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
            const Icon(Icons.error_outline_rounded, size: 40, color: SaoColors.error),
          const SizedBox(height: 10),
          Text('Error al cargar detalle',
              style: SaoTypography.sectionTitle
                  .copyWith(color: SaoColors.error)),
          const SizedBox(height: 6),
          Text(message,
              textAlign: TextAlign.center,
              style: SaoTypography.caption
                  .copyWith(color: SaoColors.gray500)),
        ],
      ),
    );
  }
}

class _PanelContent extends StatelessWidget {
  final CompletedActivityDetail detail;
  const _PanelContent({required this.detail});

  String _fmtDate(String raw) {
    if (raw.isEmpty) return '—';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return DateFormat('dd/MM/yyyy HH:mm').format(dt.toLocal());
  }

  bool _hasValue(String raw) {
    final v = raw.trim();
    if (v.isEmpty || v == '—') return false;
    return !v.toLowerCase().startsWith('sin ');
  }

  String _titleCase(String text) {
    final normalized = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) return '';
    return normalized
        .split(' ')
        .map((word) {
          final lower = word.toLowerCase();
          return lower.isEmpty
              ? lower
              : '${lower[0].toUpperCase()}${lower.substring(1)}';
        })
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final s = detail.summary;
    final generalRows = <_InfoRow>[
      _InfoRow('Proyecto', s.projectId),
      _InfoRow('Tipo', s.activityType),
      _InfoRow('PK', s.pk),
      _InfoRow('Sync v.', '${detail.syncVersion}'),
    ].where((r) => _hasValue(r.value)).toList(growable: false);

    final locationRows = <_InfoRow>[
      _InfoRow('Frente', s.front),
      _InfoRow('Estado', s.estado),
      _InfoRow('Municipio', s.municipio),
      _InfoRow('Colonia', detail.colonia),
    ].where((r) => _hasValue(r.value)).toList(growable: false);

    final actorsRows = <_InfoRow>[
      _InfoRow('Responsable', _titleCase(s.assignedName)),
      _InfoRow('Revisó', _titleCase(s.reviewedByName)),
    ].where((r) => _hasValue(r.value)).toList(growable: false);

    final timingRows = <_InfoRow>[
      _InfoRow('Creado', _fmtDate(s.createdAt)),
      _InfoRow('Revisado', _fmtDate(s.reviewedAt)),
    ].where((r) => _hasValue(r.value)).toList(growable: false);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // Activity header
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.title.isNotEmpty ? s.title : s.activityType,
                    style: SaoTypography.sectionTitle.copyWith(fontSize: 14),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${s.pk}  ·  ${s.projectId}',
                    style: SaoTypography.caption
                        .copyWith(color: SaoColors.gray400, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _DecisionBadge(decision: s.reviewDecision, large: true),
          ],
        ),

        const SizedBox(height: 14),
        _PanelQuickActions(detail: detail),
        const SizedBox(height: 10),
        const Divider(height: 1),
        const SizedBox(height: 12),

          const _SectionTitle(icon: Icons.info_outline_rounded, label: 'Datos generales'),
        const SizedBox(height: 8),
        if (generalRows.isNotEmpty) ...[
            const _SubsectionLabel(label: 'General'),
          const SizedBox(height: 6),
          _InfoGrid(rows: generalRows),
        ],
        if (locationRows.isNotEmpty) ...[
          const SizedBox(height: 10),
            const _SubsectionLabel(label: 'Ubicación'),
          const SizedBox(height: 6),
          _InfoGrid(rows: locationRows),
        ],
        if (actorsRows.isNotEmpty) ...[
          const SizedBox(height: 10),
            const _SubsectionLabel(label: 'Responsables'),
          const SizedBox(height: 6),
          _InfoGrid(rows: actorsRows),
        ],
        if (timingRows.isNotEmpty) ...[
          const SizedBox(height: 10),
            const _SubsectionLabel(label: 'Tiempos'),
          const SizedBox(height: 6),
          _InfoGrid(rows: timingRows),
        ],

        if (detail.reviewNotes.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),
          const _SectionTitle(
              icon: Icons.comment_outlined, label: 'Notas de revisión'),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: SaoColors.surfaceMutedFor(context),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: SaoColors.borderFor(context)),
            ),
            child: Text(detail.reviewNotes,
                style: SaoTypography.bodyText.copyWith(fontSize: 12)),
          ),
        ],

        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 10),
        _SectionTitle(
          icon: Icons.photo_library_outlined,
          label: 'Evidencias (${detail.evidences.length})',
        ),
        const SizedBox(height: 6),
        if (detail.evidences.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text('Sin evidencias registradas',
                style: SaoTypography.caption
                    .copyWith(color: SaoColors.gray400)),
          )
        else
          ...detail.evidences
              .map((e) => _EvidenceRow(ev: e, fmtDate: _fmtDate)),

        if (detail.dataFields.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),
          const _SectionTitle(
              icon: Icons.list_alt_rounded, label: 'Campos registrados'),
          const SizedBox(height: 6),
          _DataFieldsTable(fields: detail.dataFields),
        ],

        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 10),
        _SectionTitle(
          icon: Icons.timeline_rounded,
          label: 'Trazabilidad (${detail.auditTrail.length})',
        ),
        const SizedBox(height: 8),
        if (detail.auditTrail.isEmpty)
          _TimelinePlaceholder(status: s.reviewDecision)
        else
          _AuditTimeline(
              entries: detail.auditTrail, fmtDate: _fmtDate),

        const SizedBox(height: 24),
      ],
    );
  }
}

class _SubsectionLabel extends StatelessWidget {
  final String label;
  const _SubsectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: SaoTypography.caption.copyWith(
        fontSize: 11,
        color: SaoColors.gray500,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _PanelQuickActions extends StatelessWidget {
  final CompletedActivityDetail detail;
  const _PanelQuickActions({required this.detail});

  String _sanitizeSegment(String value) {
    final cleaned = value.trim().replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_');
    final compact = cleaned.replaceAll(RegExp(r'\s+'), '_');
    return compact.isEmpty ? 'evidencia' : compact;
  }

  String _safeLabel(String value, String fallback) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }

  String _resolvedFrontForExport() {
    final candidates = [
      detail.summary.front,
      detail.dataFields['front'],
      detail.dataFields['front_name'],
      detail.dataFields['frente'],
      detail.dataFields['frente_name'],
      detail.dataFields['frenteNombre'],
    ];

    for (final candidate in candidates) {
      final value = (candidate?.toString() ?? '').trim();
      if (value.isNotEmpty && value.toLowerCase() != 'null') {
        return value;
      }
    }
    return 'SIN_FRENTE';
  }

  Directory _buildActivityDirectory(CompletedActivity summary) {
    final userProfile = Platform.environment['USERPROFILE'];
    final documentsRoot = userProfile == null || userProfile.isEmpty
        ? Directory.current.path
        : p.join(userProfile, 'Documents');

    final projectDir = _sanitizeSegment(_safeLabel(summary.projectId, 'SIN_PROYECTO'));
    final frontDir = _sanitizeSegment(_resolvedFrontForExport());
    final stateDir = _sanitizeSegment(_safeLabel(summary.estado, 'SIN_ESTADO'));
    final activityName = _sanitizeSegment(_safeLabel(summary.title, 'ACTIVIDAD'));
    final pkPart = summary.pk.trim().isNotEmpty ? '__${_sanitizeSegment(summary.pk)}' : '';

    return Directory(
      p.join(documentsRoot, 'SAO', projectDir, frontDir, stateDir, '$activityName$pkPart'),
    );
  }

  String _guessExtension(EvidenceItem evidence, String signedUrl) {
    String extractExtension(String raw) {
      if (raw.trim().isEmpty) return '';
      final withoutQuery = raw.split('?').first;
      return p.extension(withoutQuery);
    }

    final fromPath = extractExtension(evidence.gcsPath);
    if (fromPath.isNotEmpty) return fromPath;

    final fromUrl = extractExtension(signedUrl);
    if (fromUrl.isNotEmpty) return fromUrl;

    switch (evidence.type.toUpperCase()) {
      case 'PDF':
      case 'DOCUMENT':
        return '.pdf';
      case 'VIDEO':
        return '.mp4';
      default:
        return '.jpg';
    }
  }

  String _buildFileName(
    CompletedActivity summary,
    EvidenceItem evidence,
    int index,
    String signedUrl,
  ) {
    final pkPart = _sanitizeSegment(summary.pk.isNotEmpty ? summary.pk : summary.id);
    final descPart = _sanitizeSegment(
      evidence.description.isNotEmpty ? evidence.description : 'evidencia_${index + 1}',
    );
    final ext = _guessExtension(evidence, signedUrl);
    return '${(index + 1).toString().padLeft(2, '0')}_${pkPart}_$descPart$ext';
  }

  Map<String, dynamic> _buildActivitySnapshot() {
    final s = detail.summary;
    return {
      'exported_at': DateTime.now().toIso8601String(),
      'summary': {
        'id': s.id,
        'project_id': s.projectId,
        'title': s.title,
        'activity_type': s.activityType,
        'pk': s.pk,
        'front': s.front,
        'estado': s.estado,
        'municipio': s.municipio,
        'created_at': s.createdAt,
        'reviewed_at': s.reviewedAt,
        'assigned_name': s.assignedName,
        'reviewed_by_name': s.reviewedByName,
        'review_decision': s.reviewDecision,
        'has_report': s.hasReport,
        'evidence_count': s.evidenceCount,
      },
      'detail': {
        'colonia': detail.colonia,
        'review_notes': detail.reviewNotes,
        'sync_version': detail.syncVersion,
        'data_fields': detail.dataFields,
        'audit_trail': detail.auditTrail
            .map((entry) => {
                  'id': entry.id,
                  'action': entry.action,
                  'actor_email': entry.actorEmail,
                  'actor_name': entry.actorName,
                  'changes': entry.changes,
                  'notes': entry.notes,
                  'timestamp': entry.timestamp,
                })
            .toList(growable: false),
        'evidences': detail.evidences
            .map((evidence) => {
                  'id': evidence.id,
                  'type': evidence.type,
                  'description': evidence.description,
                  'gcs_path': evidence.gcsPath,
                  'uploaded_at': evidence.uploadedAt,
                  'uploader_name': evidence.uploaderName,
                })
            .toList(growable: false),
      },
    };
  }

  String? _pickDetailField(List<String> keys) {
    final normalizedKeys = keys
        .map((key) => key.trim().toLowerCase().replaceAll(' ', '_'))
        .toSet();

    for (final entry in detail.dataFields.entries) {
      final normalizedEntryKey = entry.key
          .trim()
          .toLowerCase()
          .replaceAll(' ', '_');
      if (!normalizedKeys.contains(normalizedEntryKey)) {
        continue;
      }
      final value = entry.value?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  reports.ReportActivityItem _buildReportActivityItem() {
    final s = detail.summary;
    return reports.ReportActivityItem(
      id: s.id,
      projectId: s.projectId,
      title: s.title,
      activityType: s.activityType,
      pk: s.pk,
      frontName: s.front.isEmpty ? 'Sin frente' : s.front,
      status: s.reviewDecision.isEmpty ? 'COMPLETADA' : s.reviewDecision,
      reviewDecision: s.reviewDecision,
      reviewStatus: s.reviewDecision,
      createdAt: s.reviewedAt.isNotEmpty ? s.reviewedAt : s.createdAt,
      assignedName: s.assignedName,
      purpose: _pickDetailField(const ['purpose', 'proposito', 'objetivo']),
      detail: _pickDetailField(
        const ['detail', 'description', 'descripcion', 'minuta', 'comments'],
      ),
      agreements: _pickDetailField(
        const ['agreements', 'acuerdos', 'commitments', 'compromisos'],
      ),
      municipality: s.municipio,
      state: s.estado,
      colony: detail.colonia,
      riskLevel: _pickDetailField(const ['risk_level', 'risk', 'riesgo']),
      locationType: _pickDetailField(
        const ['location_type', 'ubicacion_tipo'],
      ),
      pkStart: _pickDetailField(const ['pk_start', 'pk_inicio']) ?? s.pk,
      pkEnd: _pickDetailField(const ['pk_end', 'pk_fin']),
      startTime: _pickDetailField(
        const ['start_time', 'hora_inicio', 'horario_inicio'],
      ),
      endTime: _pickDetailField(
        const ['end_time', 'hora_fin', 'horario_fin'],
      ),
      subcategory: _pickDetailField(
        const ['subcategory', 'subcategoria'],
      ),
      result: _pickDetailField(const ['result', 'resultado']),
      notes: detail.reviewNotes,
      pendingEvidence: detail.evidences.isEmpty,
      hasReport: s.hasReport,
      evidences: detail.evidences
          .map(
            (evidence) => reports.ReportEvidenceItem(
              id: evidence.id,
              filePath: evidence.gcsPath,
              fileType: evidence.type,
              caption: evidence.description,
              capturedAt: evidence.uploadedAt,
            ),
          )
          .toList(growable: false),
    );
  }

  Future<File> _buildDetailedPdf(Directory pdfDir) async {
    final s = detail.summary;
    final createdAt = DateTime.tryParse(s.createdAt) ?? DateTime.now();
    final reviewedAt = DateTime.tryParse(s.reviewedAt) ?? createdAt;
    final start = createdAt.isBefore(reviewedAt) ? createdAt : reviewedAt;
    final end = reviewedAt.isAfter(start)
        ? reviewedAt
        : start.add(const Duration(minutes: 1));

    return reports.generateActivitiesPdf(
      [_buildReportActivityItem()],
      reports.ReportFilters(
        projectId: s.projectId,
        frontName: s.front.isEmpty ? 'Todos' : s.front,
        dateRange: reports.ReportDateRange(start: start, end: end),
        includeAlreadyReported: true,
      ),
      executiveSummary: detail.reviewNotes.trim(),
      includeAudit: true,
      includeNotes: true,
      includeAttachments: true,
      saveFilePath: p.join(pdfDir.path, 'reporte_con_evidencias.pdf'),
    );
  }

  Future<void> _exportPdf(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final activityDir = _buildActivityDirectory(detail.summary);
    final pdfDir = Directory(p.join(activityDir.path, 'pdfs'));

    try {
      await _writeActivityFiles(activityDir);
      final file = await _buildDetailedPdf(pdfDir);

      if (!context.mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('PDF exportado en ${file.path}'),
            duration: const Duration(seconds: 10),
            action: SnackBarAction(
              label: 'Abrir carpeta',
              onPressed: () {
                _openDirectory(pdfDir.path);
              },
            ),
          ),
        );
    } catch (e) {
      if (!context.mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('No se pudo exportar el PDF: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
    }
  }

  Future<void> _writeActivityFiles(Directory activityDir) async {
    final dataDir = Directory(p.join(activityDir.path, 'datos'));
    final pdfDir = Directory(p.join(activityDir.path, 'pdfs'));
    await dataDir.create(recursive: true);
    await pdfDir.create(recursive: true);

    final snapshot = _buildActivitySnapshot();
    const encoder = JsonEncoder.withIndent('  ');
    await File(p.join(dataDir.path, 'actividad_detalle.json'))
        .writeAsString(encoder.convert(snapshot), flush: true);

    final s = detail.summary;
    final resumen = StringBuffer()
      ..writeln('SAO - Resumen de actividad')
      ..writeln('Proyecto: ${s.projectId}')
      ..writeln('Frente: ${s.front}')
      ..writeln('Estado: ${s.estado}')
      ..writeln('Municipio: ${s.municipio}')
      ..writeln('Colonia: ${detail.colonia}')
      ..writeln('Actividad: ${s.title}')
      ..writeln('Tipo: ${s.activityType}')
      ..writeln('PK: ${s.pk}')
      ..writeln('Responsable: ${s.assignedName}')
      ..writeln('Revisó: ${s.reviewedByName}')
      ..writeln('Decisión: ${s.reviewDecision}')
      ..writeln('Creado: ${s.createdAt}')
      ..writeln('Revisado: ${s.reviewedAt}')
      ..writeln('Versión sync: ${detail.syncVersion}')
      ..writeln('Notas: ${detail.reviewNotes.isEmpty ? 'Sin notas' : detail.reviewNotes}');

    await File(p.join(dataDir.path, 'actividad_resumen.txt'))
        .writeAsString(resumen.toString(), flush: true);

    final pdf = pw.Document();
    final dataRows = detail.dataFields.entries
        .where((entry) => entry.value != null && entry.value.toString().trim().isNotEmpty)
        .map((entry) => [entry.key, entry.value.toString()])
        .toList(growable: false);

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text(
            'SAO - Resumen de actividad',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.Text('Proyecto: ${s.projectId}'),
          pw.Text('Frente: ${s.front}'),
          pw.Text('Estado: ${s.estado}'),
          pw.Text('Municipio: ${s.municipio}'),
          pw.Text('Colonia: ${detail.colonia}'),
          pw.Text('Actividad: ${s.title}'),
          pw.Text('Tipo: ${s.activityType}'),
          pw.Text('PK: ${s.pk}'),
          pw.Text('Responsable: ${s.assignedName}'),
          pw.Text('Revisó: ${s.reviewedByName}'),
          pw.Text('Decisión: ${s.reviewDecision}'),
          pw.Text('Creado: ${s.createdAt}'),
          pw.Text('Revisado: ${s.reviewedAt}'),
          pw.Text('Versión sync: ${detail.syncVersion}'),
          if (detail.reviewNotes.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            pw.Text(
              'Notas de revisión',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(detail.reviewNotes),
          ],
          if (dataRows.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Text(
              'Campos registrados',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
              headers: const ['Campo', 'Valor'],
              data: dataRows,
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellAlignment: pw.Alignment.centerLeft,
              headerDecoration: const pw.BoxDecoration(),
            ),
          ],
          if (detail.evidences.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Text(
              'Evidencias',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            ...detail.evidences.take(50).map(
                  (evidence) => pw.Bullet(
                    text:
                        '${evidence.type} • ${evidence.description.isEmpty ? 'Sin descripción' : evidence.description} • ${evidence.uploadedAt}',
                  ),
                ),
          ],
        ],
      ),
    );

    await File(p.join(pdfDir.path, 'resumen_actividad.pdf'))
        .writeAsBytes(await pdf.save(), flush: true);
  }

  Directory _targetDirectoryForEvidence(Directory activityDir, EvidenceItem evidence) {
    final upper = evidence.type.toUpperCase();
    final folderName = upper == 'PDF' || upper == 'DOCUMENT' ? 'pdfs' : 'evidencias';
    return Directory(p.join(activityDir.path, folderName));
  }

  Future<List<int>> _downloadBytes(String signedUrl) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20)
      ..idleTimeout = const Duration(seconds: 20);
    try {
      final request = await client.getUrl(Uri.parse(signedUrl));
      request.followRedirects = true;
      request.maxRedirects = 5;
      request.headers.set(HttpHeaders.userAgentHeader, 'SAO-Desktop/1.0');
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('HTTP ${response.statusCode} al descargar evidencia');
      }
      return response.fold<List<int>>(<int>[], (buffer, chunk) {
        buffer.addAll(chunk);
        return buffer;
      });
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _downloadFileWithFallback(String signedUrl, File targetFile) async {
    Object? lastError;

    try {
      final bytes = await _downloadBytes(signedUrl);
      if (bytes.isEmpty) {
        throw StateError('La evidencia regresó 0 bytes');
      }
      await targetFile.writeAsBytes(bytes, flush: true);
      if (await targetFile.exists() && await targetFile.length() > 0) {
        return;
      }
      throw StateError('El archivo descargado quedó vacío');
    } catch (error) {
      lastError = error;
    }

    if (Platform.isWindows) {
      final curlResult = await Process.run(
        'curl.exe',
        ['-L', '--fail', '--silent', '--show-error', '-o', targetFile.path, signedUrl],
      );
      if (curlResult.exitCode == 0 && await targetFile.exists() && await targetFile.length() > 0) {
        return;
      }
      final stderr = (curlResult.stderr ?? '').toString().trim();
      if (stderr.isNotEmpty) {
        lastError = stderr;
      }
    }

    throw Exception('No se pudo descargar ${targetFile.path}: $lastError');
  }

  Future<void> _openDirectory(String path) async {
    final command = switch (Platform.operatingSystem) {
      'macos' => 'open',
      'linux' => 'xdg-open',
      _ => 'explorer.exe',
    };
    await Process.run(command, [path]);
  }

  Future<void> _downloadEvidences(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final summary = detail.summary;
    final activityDir = _buildActivityDirectory(summary);

    try {
      if (!await activityDir.exists()) {
        await activityDir.create(recursive: true);
      }

      final evidencesDir = Directory(p.join(activityDir.path, 'evidencias'));
      final pdfDir = Directory(p.join(activityDir.path, 'pdfs'));
      if (!await evidencesDir.exists()) {
        await evidencesDir.create(recursive: true);
      }
      if (!await pdfDir.exists()) {
        await pdfDir.create(recursive: true);
      }

      await _writeActivityFiles(activityDir);
      await _buildDetailedPdf(pdfDir);

      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Actualizando paquete SAO en ${activityDir.path}...'),
            duration: const Duration(seconds: 2),
          ),
        );

      final repository = EvidenceRepository();
      int savedCount = 0;
      int skippedCount = 0;
      final failedDescriptions = <String>[];

      for (var i = 0; i < detail.evidences.length; i++) {
        final evidence = detail.evidences[i];
        try {
          final signedUrl = await repository.getDownloadSignedUrl(evidence.id);
          final fileName = _buildFileName(summary, evidence, i, signedUrl);
          final targetDir = _targetDirectoryForEvidence(activityDir, evidence);
          if (!await targetDir.exists()) {
            await targetDir.create(recursive: true);
          }
          final file = File(p.join(targetDir.path, fileName));

          if (await file.exists() && await file.length() > 0) {
            skippedCount++;
            continue;
          }

          await _downloadFileWithFallback(signedUrl, file);
          savedCount++;
        } catch (error) {
          failedDescriptions.add(
            '${evidence.description.isNotEmpty ? evidence.description : 'Evidencia ${i + 1}'} -> $error',
          );
        }
      }

      final dataDir = Directory(p.join(activityDir.path, 'datos'));
      if (!await dataDir.exists()) {
        await dataDir.create(recursive: true);
      }
      final failedFile = File(p.join(dataDir.path, 'evidencias_no_descargadas.txt'));
      if (failedDescriptions.isNotEmpty) {
        await failedFile.writeAsString(
          failedDescriptions.join('\n'),
          flush: true,
        );
      } else if (await failedFile.exists()) {
        await failedFile.delete();
      }

      if (!context.mounted) return;

      final message = detail.evidences.isEmpty
          ? 'Carpeta SAO actualizada en ${activityDir.path}'
          : failedDescriptions.isEmpty
              ? 'Actividad actualizada: $savedCount nuevas, $skippedCount ya existentes.'
              : 'Actividad actualizada: $savedCount nuevas, $skippedCount existentes, ${failedDescriptions.length} con error.';

      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 10),
            action: SnackBarAction(
              label: 'Abrir carpeta',
              onPressed: () {
                _openDirectory(activityDir.path);
              },
            ),
          ),
        );
    } catch (e) {
      if (!context.mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('No se pudo actualizar la carpeta SAO: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = detail.summary;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Edición rápida disponible próximamente.')),
            );
          },
          icon: const Icon(Icons.edit_outlined, size: 15),
          label: const Text('Editar'),
        ),
        OutlinedButton.icon(
          onPressed: () => _exportPdf(context),
          icon: const Icon(Icons.picture_as_pdf_outlined, size: 15),
          label: const Text('Exportar PDF'),
        ),
        OutlinedButton.icon(
          onPressed: () async {
            final query = [s.pk, s.estado, s.municipio]
                .where((v) => v.trim().isNotEmpty)
                .join(' ');
            final uri = Uri.https('www.google.com', '/maps/search/', {
              'api': '1',
              'query': query,
            });
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          },
          icon: const Icon(Icons.map_outlined, size: 15),
          label: const Text('Ver en mapa'),
        ),
        if (s.reviewDecision == 'APPROVE' && detail.evidences.isNotEmpty)
          FilledButton.tonalIcon(
            onPressed: () => _downloadEvidences(context),
            icon: const Icon(Icons.download_rounded, size: 15),
            label: const Text('Descargar evidencias'),
          ),
      ],
    );
  }
}

class _TimelinePlaceholder extends StatelessWidget {
  final String status;
  const _TimelinePlaceholder({required this.status});

  @override
  Widget build(BuildContext context) {
    final steps = [
      ('Creado', true),
      ('Revisado', status.isNotEmpty),
      ('Aprobado', status == 'APPROVE' || status == 'APPROVE_EXCEPTION'),
    ];
    return Column(
      children: List.generate(steps.length, (i) {
        final (label, done) = steps[i];
        final isLast = i == steps.length - 1;
        final color = done ? SaoColors.success : SaoColors.gray300;
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 20,
                child: Column(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: done
                            ? color.withValues(alpha: 0.15)
                            : SaoColors.surfaceFor(context),
                        shape: BoxShape.circle,
                        border: Border.all(color: color, width: 1.5),
                      ),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 1.5,
                          color: SaoColors.borderFor(context),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
                child: Text(
                  label,
                  style: SaoTypography.bodyText.copyWith(
                    fontSize: 12,
                    color: done
                        ? SaoColors.textFor(context)
                        : SaoColors.textMutedFor(context),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: List.generate(
          10,
          (index) => Container(
            height: index == 0 ? 44 : 30,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: SaoColors.surfaceRaisedFor(context),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Detail sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _InfoRow {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);
}

class _InfoGrid extends StatelessWidget {
  final List<_InfoRow> rows;
  const _InfoGrid({required this.rows});

  @override
  Widget build(BuildContext context) {
    final pairs = <Widget>[];
    for (var i = 0; i < rows.length; i += 2) {
      final a = rows[i];
      final b = i + 1 < rows.length ? rows[i + 1] : null;
      pairs.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _InfoCell(label: a.label, value: a.value)),
          if (b != null) ...[
            const SizedBox(width: 8),
            Expanded(child: _InfoCell(label: b.label, value: b.value)),
          ],
        ],
      ));
    }
    return Column(
      children: pairs
          .expand((w) => [w, const SizedBox(height: 4)])
          .toList(growable: false),
    );
  }
}

class _InfoCell extends StatelessWidget {
  final String label;
  final String value;
  const _InfoCell({required this.label, required this.value});

  static const Set<String> _nameLikeLabels = {
    'Responsable',
    'Revisó',
    'Supervisor',
    'Capturó',
    'Actualizó',
  };

  String _displayValue() {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '—';
    }
    if (_nameLikeLabels.contains(label)) {
      return trimmed
          .split(RegExp(r'\s+'))
          .where((part) => part.isNotEmpty)
          .map(
            (part) => '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
          )
          .join(' ');
    }
    return trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final displayValue = _displayValue();
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: SaoColors.surfaceMutedFor(context),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: SaoColors.borderFor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: SaoTypography.caption
                  .copyWith(color: SaoColors.textMutedFor(context), fontSize: 10)),
          const SizedBox(height: 2),
          Text(
            displayValue,
            style: SaoTypography.bodyText.copyWith(fontSize: 12),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionTitle({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: SaoColors.textMutedFor(context)),
        const SizedBox(width: 6),
        Text(label,
            style: SaoTypography.bodyTextBold
                .copyWith(fontSize: 12, color: SaoColors.textMutedFor(context))),
      ],
    );
  }
}

class _EvidenceRow extends StatelessWidget {
  final EvidenceItem ev;
  final String Function(String) fmtDate;
  const _EvidenceRow({required this.ev, required this.fmtDate});

  @override
  Widget build(BuildContext context) {
    final isPhoto = ev.type.toUpperCase().contains('PHOTO') ||
        ev.type.toUpperCase().contains('FOTO');
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: SaoColors.surfaceMutedFor(context),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: SaoColors.borderFor(context)),
      ),
      child: Row(
        children: [
          Icon(
            isPhoto
                ? Icons.camera_alt_outlined
                : Icons.attach_file_rounded,
            size: 14,
            color: SaoColors.actionPrimary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ev.description.isNotEmpty ? ev.description : ev.type,
                  style: SaoTypography.bodyText.copyWith(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${ev.uploaderName.isNotEmpty ? ev.uploaderName : "—"}  ·  ${fmtDate(ev.uploadedAt)}',
                  style: SaoTypography.caption
                      .copyWith(color: SaoColors.textMutedFor(context), fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DataFieldsTable extends StatelessWidget {
  final Map<String, dynamic> fields;
  const _DataFieldsTable({required this.fields});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: fields.entries.map((e) {
        return Container(
          margin: const EdgeInsets.only(bottom: 3),
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: SaoColors.surfaceMutedFor(context),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: SaoColors.borderFor(context)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 120,
                child: Text(e.key,
                    style: SaoTypography.caption
                        .copyWith(color: SaoColors.textMutedFor(context), fontSize: 11),
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  e.value?.toString() ?? '—',
                  style: SaoTypography.bodyText.copyWith(fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Audit timeline
// ─────────────────────────────────────────────────────────────────────────────

class _AuditTimeline extends StatelessWidget {
  final List<AuditEntry> entries;
  final String Function(String) fmtDate;
  const _AuditTimeline({required this.entries, required this.fmtDate});

  static const _actionColors = <String, Color>{
    'CREATE':  Color(0xFF3B82F6),
    'CREATED': Color(0xFF3B82F6),
    'UPDATE':  Color(0xFFF59E0B),
    'UPDATED': Color(0xFFF59E0B),
    'DELETE':  Color(0xFFEF4444),
    'DELETED': Color(0xFFEF4444),
    'APPROVE': Color(0xFF10B981),
    'REVIEW':  Color(0xFF10B981),
    'REJECT':  Color(0xFFEF4444),
    'SYNC':    Color(0xFF8B5CF6),
  };

  Color _colorFor(String action) {
    final key = action.toUpperCase().split('_').first;
    return _actionColors[key] ??
        _actionColors[action.toUpperCase()] ??
        SaoColors.gray400;
  }

  IconData _iconFor(String action) {
    final up = action.toUpperCase();
    if (up.contains('APPROVE') || up.contains('DECISION')) {
      return Icons.check_circle_outline_rounded;
    }
    if (up.contains('REJECT'))  return Icons.cancel_outlined;
    if (up.contains('CREATE'))  return Icons.add_circle_outline_rounded;
    if (up.contains('UPDATE') || up.contains('EDIT')) {
      return Icons.edit_outlined;
    }
    if (up.contains('DELETE'))  return Icons.delete_outline_rounded;
    if (up.contains('SYNC'))    return Icons.sync_rounded;
    if (up.contains('EVIDENCE') || up.contains('PHOTO')) {
      return Icons.camera_alt_outlined;
    }
    return Icons.circle_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(entries.length, (i) {
        final e = entries[i];
        final color = _colorFor(e.action);
        final isLast = i == entries.length - 1;
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 24,
                child: Column(
                  children: [
                    const SizedBox(height: 2),
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: color, width: 1.5),
                      ),
                      child: Icon(_iconFor(e.action), size: 10, color: color),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Center(
                          child: Container(
                              width: 1.5, color: SaoColors.gray200),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(
                            _friendlyAction(e.action),
                            style: SaoTypography.bodyTextBold
                                .copyWith(fontSize: 12, color: color),
                          ),
                        ),
                        Text(fmtDate(e.timestamp),
                            style: SaoTypography.caption.copyWith(
                                color: SaoColors.gray400, fontSize: 10)),
                      ]),
                      if (e.actorName.isNotEmpty || e.actorEmail.isNotEmpty)
                        Text(
                          e.actorName.isNotEmpty
                              ? e.actorName
                              : e.actorEmail,
                          style: SaoTypography.caption.copyWith(
                              color: SaoColors.gray500, fontSize: 11),
                        ),
                      if (e.notes.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: SaoColors.surfaceMutedFor(context),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: SaoColors.borderFor(context)),
                          ),
                          child: Text(e.notes,
                              style: SaoTypography.caption
                                  .copyWith(fontSize: 11)),
                        ),
                      ],
                      if (e.changes.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        _ChangesChips(changes: e.changes),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  String _friendlyAction(String action) {
    return action
        .replaceAll('_', ' ')
        .toLowerCase()
        .split(' ')
        .map((w) =>
            w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}

class _ChangesChips extends StatefulWidget {
  final Map<String, dynamic> changes;
  const _ChangesChips({required this.changes});

  @override
  State<_ChangesChips> createState() => _ChangesChipsState();
}

class _ChangesChipsState extends State<_ChangesChips> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 13,
                color: SaoColors.gray400,
              ),
              Text(
                '${widget.changes.length} campo(s) modificado(s)',
                style: SaoTypography.caption
                    .copyWith(color: SaoColors.gray500, fontSize: 10),
              ),
            ],
          ),
        ),
        if (_expanded)
          ...widget.changes.entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 2, left: 16),
                child: Text(
                  '${e.key}: ${e.value}',
                  style: SaoTypography.caption
                      .copyWith(fontSize: 10, color: SaoColors.gray500),
                  overflow: TextOverflow.ellipsis,
                ),
              )),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Decision badge
// ─────────────────────────────────────────────────────────────────────────────

class _DecisionBadge extends StatelessWidget {
  final String decision;
  final bool large;
  const _DecisionBadge({required this.decision, this.large = false});

  @override
  Widget build(BuildContext context) {
    Color bg, fg;
    String label;
    IconData icon;

    final upper = decision.toUpperCase();
    if (upper == 'APPROVE_EXCEPTION') {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFFD97706);
      label = large ? 'Aprobado con observaciones' : 'Aprobado*';
      icon = Icons.warning_amber_rounded;
    } else if (upper.contains('REJECT')) {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFDC2626);
      label = 'Rechazado';
      icon = Icons.cancel_rounded;
    } else if (upper.contains('PENDING') || upper.contains('REVIEW')) {
      bg = const Color(0xFFFFF7ED);
      fg = const Color(0xFFEA580C);
      label = 'Revisión pendiente';
      icon = Icons.schedule_rounded;
    } else {
      bg = SaoColors.success.withValues(alpha: 0.12);
      fg = SaoColors.success;
      label = 'Aprobado';
      icon = Icons.check_circle_rounded;
    }

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: large ? 10 : 7, vertical: large ? 4 : 2),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(large ? 6 : 4)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: large ? 13 : 11, color: fg),
          SizedBox(width: large ? 5 : 3),
          Text(label,
              style: SaoTypography.caption
                  .copyWith(color: fg, fontSize: large ? 12 : 10)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty / Error full-page states
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
            const Icon(Icons.check_circle_outline_rounded,
              size: 56, color: SaoColors.gray200),
          const SizedBox(height: 16),
          Text('Sin actividades completadas',
              style: SaoTypography.sectionTitle
                  .copyWith(color: SaoColors.gray400)),
          const SizedBox(height: 8),
          Text(
            'Ajusta los filtros o verifica que existan actividades aprobadas.',
            style: SaoTypography.caption.copyWith(color: SaoColors.gray400),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: SaoColors.error),
          const SizedBox(height: 12),
          Text('Error al cargar actividades',
              style: SaoTypography.sectionTitle
                  .copyWith(color: SaoColors.error)),
          const SizedBox(height: 8),
          SizedBox(
            width: 400,
            child: Text(message,
                textAlign: TextAlign.center,
                style: SaoTypography.caption
                    .copyWith(color: SaoColors.gray500)),
          ),
        ],
      ),
    );
  }
}
