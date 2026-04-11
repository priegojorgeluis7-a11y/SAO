import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers/project_providers.dart';
import '../../ui/theme/sao_colors.dart';
import '../../ui/theme/sao_spacing.dart';
import '../../ui/theme/sao_typography.dart';
import '../../ui/theme/sao_radii.dart';
import 'reports_provider.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

const _kMonths = [
  'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
  'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
];

String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')} ${_kMonths[d.month - 1]} ${d.year}';

String _fmtCreatedAt(String raw) {
  try {
    return _fmtDate(DateTime.parse(raw));
  } catch (_) {
    return raw;
  }
}

String _previewLocation(ReportActivityItem item) {
  final parts = [item.municipality, item.state, item.colony]
      .where((value) => (value ?? '').trim().isNotEmpty)
      .cast<String>()
      .toList(growable: false);
  return parts.isEmpty ? 'Ubicación por confirmar' : parts.join(', ');
}

bool _isApproved(ReportActivityItem item) => item.isApprovedForReport;

String _normalizeReportProject(String value) => value.trim().toUpperCase();

bool _matchesVisibleProject(ReportActivityItem item, String projectId) {
  final selectedProject = _normalizeReportProject(projectId);
  if (selectedProject.isEmpty) return true;
  return _normalizeReportProject(item.projectId ?? '') == selectedProject;
}

bool _matchesVisibleFront(ReportActivityItem item, String frontName) {
  final normalizedFront = frontName.trim().toLowerCase();
  if (normalizedFront.isEmpty ||
      normalizedFront == 'todos' ||
      normalizedFront == 'todo' ||
      normalizedFront == 'all' ||
      normalizedFront == '*') {
    return true;
  }
  return item.frontName.toLowerCase().contains(normalizedFront);
}

bool _looksGenericReportText(String value) {
  final normalized = value.trim().toLowerCase();
  return normalized.startsWith('actividad realizada en ') ||
      normalized.startsWith('actividad validada para emision') ||
      normalized.startsWith('actividad validada para emisión') ||
      normalized.startsWith('actividad:') ||
      normalized.contains('|');
}

String _resolvedDraftPurpose(ReportActivityItem item) {
  final purpose = item.purpose?.trim() ?? '';
  if (purpose.isEmpty || _looksGenericReportText(purpose)) {
    return 'Desarrollar las acciones operativas previstas para la actividad y documentar sus resultados en campo.';
  }
  return purpose;
}

String _resolvedDraftDetail(ReportActivityItem item) {
  final detail = item.detail?.trim() ?? '';
  if (detail.isEmpty || _looksGenericReportText(detail)) {
    return buildReportNaturalNarrative(
      item,
      fallbackText:
          'Actividad realizada en ${_previewLocation(item)} para seguimiento operativo del frente ${item.frontName}.',
    );
  }
  return detail;
}

class _ActivityDraft {
  String title;
  String purpose;
  String detail;
  String agreements;

  _ActivityDraft({
    required this.title,
    required this.purpose,
    required this.detail,
    required this.agreements,
  });

  factory _ActivityDraft.from(ReportActivityItem item) => _ActivityDraft(
        title: item.title?.trim().isNotEmpty == true
            ? item.title!
            : item.activityType,
        purpose: _resolvedDraftPurpose(item),
        detail: _resolvedDraftDetail(item),
        agreements: item.agreements?.trim().isNotEmpty == true
            ? item.agreements!
            : '',
      );
}

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: 2, vsync: this);

  // Selection & focus
  final Set<String> _selectedIds = {};
  String? _focusedId;
  bool _initialized = false;
  bool _sidebarCollapsed = false;
  String _projectScope = '';

  // Per-activity drafts
  final Map<String, _ActivityDraft> _drafts = {};

  // Editor controllers (bound to the focused activity)
  final _titleCtrl = TextEditingController();
  final _purposeCtrl = TextEditingController();
  final _detailCtrl = TextEditingController();
  final _agreementsCtrl = TextEditingController();
  final _summaryCtrl = TextEditingController();

  // PDF options
  bool _includeAudit = true;
  bool _includeNotes = false;
  bool _includeAttachments = true;
  bool _showRisk = false;
  bool _showTechGps = false;
  bool _showPhotoGps = false;

  // Generation state
  bool _isGenerating = false;
  String? _lastSavedPath;

  @override
  void initState() {
    super.initState();
    _projectScope = ref.read(activeProjectIdProvider).trim().toUpperCase();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncToProject(_projectScope, updateGlobal: false);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleCtrl.dispose();
    _purposeCtrl.dispose();
    _detailCtrl.dispose();
    _agreementsCtrl.dispose();
    _summaryCtrl.dispose();
    super.dispose();
  }

  void _resetViewStateForProject() {
    _selectedIds.clear();
    _drafts.clear();
    _focusedId = null;
    _initialized = false;
    _lastSavedPath = null;
    _titleCtrl.clear();
    _purposeCtrl.clear();
    _detailCtrl.clear();
    _agreementsCtrl.clear();
    _summaryCtrl.clear();
  }

  void _syncToProject(String projectId, {required bool updateGlobal}) {
    final normalizedProject = projectId.trim().toUpperCase();
    final currentFilters = ref.read(reportFiltersProvider);
    final filtersChanged = currentFilters.projectId != normalizedProject ||
        currentFilters.frontName != 'Todos';

    if (updateGlobal) {
      ref.read(activeProjectIdProvider.notifier).select(normalizedProject);
    }

    setState(() {
      _projectScope = normalizedProject;
      _resetViewStateForProject();
    });

    if (filtersChanged) {
      ref.read(reportFiltersProvider.notifier).state = currentFilters.copyWith(
            projectId: normalizedProject,
            frontName: 'Todos',
          );
    }

    ref.invalidate(reportActivitiesProvider);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _initIfNeeded(List<ReportActivityItem> items) {
    if (_initialized) return;
    _initialized = true;
    final approved = items.where(_isApproved).toList();
    _selectedIds.addAll(approved.map((a) => a.id));
    if (approved.isNotEmpty) _loadIntoEditor(approved.first);
  }

  void _flushEditor() {
    if (_focusedId == null) return;
    _drafts[_focusedId!] = _ActivityDraft(
      title: _titleCtrl.text,
      purpose: _purposeCtrl.text,
      detail: _detailCtrl.text,
      agreements: _agreementsCtrl.text,
    );
  }

  void _loadIntoEditor(ReportActivityItem item) {
    _flushEditor();
    _focusedId = item.id;
    final draft = _drafts.putIfAbsent(item.id, () => _ActivityDraft.from(item));
    _titleCtrl.text = draft.title;
    _purposeCtrl.text = draft.purpose;
    _detailCtrl.text = draft.detail;
    _agreementsCtrl.text = draft.agreements;
  }

  ReportActivityItem _withDraft(ReportActivityItem item) {
    final resolvedPurpose = _purposeCtrl.text.trim().isEmpty
        ? _resolvedDraftPurpose(item)
        : _purposeCtrl.text;
    final resolvedDetail = _detailCtrl.text.trim().isEmpty ||
            _looksGenericReportText(_detailCtrl.text)
        ? _resolvedDraftDetail(item)
        : _detailCtrl.text;

    if (item.id == _focusedId) {
      return ReportActivityItem(
        id: item.id,
        activityType: item.activityType,
        pk: item.pk,
        frontName: item.frontName,
        status: item.status,
        reviewDecision: item.reviewDecision,
        reviewStatus: item.reviewStatus,
        createdAt: item.createdAt,
        assignedName: item.assignedName,
        projectId: item.projectId,
        title: _titleCtrl.text,
        purpose: resolvedPurpose,
        detail: resolvedDetail,
        agreements: _agreementsCtrl.text,
        municipality: item.municipality,
        state: item.state,
        colony: item.colony,
        riskLevel: item.riskLevel,
        locationType: item.locationType,
        pkStart: item.pkStart,
        pkEnd: item.pkEnd,
        startTime: item.startTime,
        endTime: item.endTime,
        technicalLatitude: item.technicalLatitude,
        technicalLongitude: item.technicalLongitude,
        gpsPrecision: item.gpsPrecision,
        isUnplanned: item.isUnplanned,
        unplannedReason: item.unplannedReason,
        referenceFolio: item.referenceFolio,
        subcategory: item.subcategory,
        topics: item.topics,
        attendees: item.attendees,
        result: item.result,
        notes: item.notes,
        pendingEvidence: item.pendingEvidence,
        evidenceDueAt: item.evidenceDueAt,
        evidences: item.evidences,
      );
    }
    final d = _drafts[item.id];
    if (d == null) return item;
    final resolvedDraftPurposeText = d.purpose.trim().isEmpty ||
        _looksGenericReportText(d.purpose)
      ? _resolvedDraftPurpose(item)
      : d.purpose;
    final resolvedDraftDetailText = d.detail.trim().isEmpty ||
        _looksGenericReportText(d.detail)
      ? _resolvedDraftDetail(item)
      : d.detail;
    return ReportActivityItem(
      id: item.id,
      activityType: item.activityType,
      pk: item.pk,
      frontName: item.frontName,
      status: item.status,
      reviewDecision: item.reviewDecision,
      reviewStatus: item.reviewStatus,
      createdAt: item.createdAt,
      assignedName: item.assignedName,
      projectId: item.projectId,
      title: d.title,
      purpose: resolvedDraftPurposeText,
      detail: resolvedDraftDetailText,
      agreements: d.agreements,
      municipality: item.municipality,
      state: item.state,
      colony: item.colony,
      riskLevel: item.riskLevel,
      locationType: item.locationType,
      pkStart: item.pkStart,
      pkEnd: item.pkEnd,
      startTime: item.startTime,
      endTime: item.endTime,
      technicalLatitude: item.technicalLatitude,
      technicalLongitude: item.technicalLongitude,
      gpsPrecision: item.gpsPrecision,
      isUnplanned: item.isUnplanned,
      unplannedReason: item.unplannedReason,
      referenceFolio: item.referenceFolio,
      subcategory: item.subcategory,
      topics: item.topics,
      attendees: item.attendees,
      result: item.result,
      notes: item.notes,
      pendingEvidence: item.pendingEvidence,
      evidenceDueAt: item.evidenceDueAt,
      evidences: item.evidences,
    );
  }

  Future<void> _generatePdf(
      List<ReportActivityItem> items, ReportFilters filters) async {
    _flushEditor();
    setState(() {
      _isGenerating = true;
      _lastSavedPath = null;
    });
    try {
      final patched = items.map(_withDraft).toList();
      final file = await generateActivitiesPdf(
        patched,
        filters,
        executiveSummary: _summaryCtrl.text.trim(),
        includeAudit: _includeAudit,
        includeNotes: _includeNotes,
        includeAttachments: _includeAttachments,
      );
      setState(() => _lastSavedPath = file.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: SaoColors.success,
            duration: const Duration(seconds: 6),
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('PDF guardado: ${file.path}',
                      style: const TextStyle(color: Colors.white)),
                ),
                TextButton(
                  onPressed: () async {
                    final uri = Uri.file(file.parent.path);
                    if (await canLaunchUrl(uri)) launchUrl(uri);
                  },
                  child: const Text('Abrir carpeta',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar PDF: $e'),
            backgroundColor: SaoColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final activeProjectId = ref.watch(activeProjectIdProvider).trim().toUpperCase();
    final filters = ref.watch(reportFiltersProvider);
    final activitiesAsync = ref.watch(reportActivitiesProvider);

    if (activeProjectId != _projectScope) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _syncToProject(activeProjectId, updateGlobal: false);
      });
    }

    final allItems = activitiesAsync.valueOrNull ?? const [];
    final reportableItems = allItems
      .where(_isApproved)
      .where((item) => _matchesVisibleProject(item, filters.projectId))
      .where((item) => _matchesVisibleFront(item, filters.frontName))
      .toList(growable: false);

    // Auto-initialize once data arrives
    if (reportableItems.isNotEmpty && !_initialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _initIfNeeded(reportableItems));
      });
    }

    final selectedItems = reportableItems
        .where((a) => _selectedIds.contains(a.id))
        .toList();

    final focusedItem = _focusedId == null
        ? null
        : reportableItems.cast<ReportActivityItem?>().firstWhere(
              (a) => a?.id == _focusedId,
              orElse: () => null,
            );

    final focusedApproved =
      focusedItem != null && _isApproved(focusedItem) ? focusedItem : null;

    final frontsSorted = reportableItems.map((a) => a.frontName).toSet().toList()
      ..sort();
    final fronts = ['Todos', ...frontsSorted];

    void refresh() {
      setState(() => _initialized = false);
      ref.invalidate(reportActivitiesProvider);
    }

    return Column(
      children: [
        // ── Top bar ──────────────────────────────────────────────────────────
        _TopBar(
          filters: filters,
          fronts: fronts,
          selectedCount: focusedApproved == null ? 0 : 1,
          isGenerating: _isGenerating,
          canGenerate: focusedApproved != null && !_isGenerating,
          onRefresh: refresh,
          onProjectChanged: (projectId) => _syncToProject(projectId, updateGlobal: true),
          onGenerate: () => _generatePdf([focusedApproved!], filters),
        ),
        const Divider(height: 1),

        // ── Body ─────────────────────────────────────────────────────────────
        Expanded(
          child: Row(
            children: [
              // Left tray (collapsible)
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                width: _sidebarCollapsed ? 0 : 296,
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.topLeft,
                    maxWidth: 296,
                    minWidth: 296,
                    child: _ActivityTray(
                      activitiesAsync: activitiesAsync,
                      selectedIds: _selectedIds,
                      focusedId: _focusedId,
                      allItems: reportableItems,
                      includeAudit: _includeAudit,
                      includeNotes: _includeNotes,
                      includeAttachments: _includeAttachments,
                      summaryCtrl: _summaryCtrl,
                      lastSavedPath: _lastSavedPath,
                      onTap: (item) {
                        setState(() => _loadIntoEditor(item));
                        _tabController.animateTo(0);
                      },
                      onToggleSelect: (item) {
                        setState(() {
                          if (_selectedIds.contains(item.id)) {
                            _selectedIds.remove(item.id);
                          } else {
                            _selectedIds.add(item.id);
                          }
                        });
                      },
                      onSelectAll: () => setState(() {
                        _selectedIds.addAll(
                            reportableItems.map((a) => a.id));
                      }),
                      onDeselectAll: () => setState(() {
                        _selectedIds.removeAll(
                            reportableItems.map((a) => a.id));
                      }),
                      onIncludeAudit: (v) =>
                          setState(() => _includeAudit = v),
                      onIncludeNotes: (v) =>
                          setState(() => _includeNotes = v),
                      onIncludeAttachments: (v) =>
                          setState(() => _includeAttachments = v),
                      onCollapse: () =>
                          setState(() => _sidebarCollapsed = true),
                    ),
                  ),
                ),
              ),
              // Collapse toggle strip
              Tooltip(
                message: _sidebarCollapsed ? 'Mostrar panel' : 'Ocultar panel',
                child: GestureDetector(
                  onTap: () => setState(() => _sidebarCollapsed = !_sidebarCollapsed),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Container(
                      width: 16,
                      color: SaoColors.surfaceRaisedFor(context),
                      alignment: Alignment.center,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 1,
                            color: SaoColors.borderFor(context),
                          ),
                          Container(
                            width: 16,
                            height: 36,
                            decoration: BoxDecoration(
                              color: SaoColors.surfaceFor(context),
                              border: Border.all(
                                color: SaoColors.borderFor(context),
                              ),
                              borderRadius: BorderRadius.circular(SaoRadii.sm),
                            ),
                            child: Icon(
                              _sidebarCollapsed
                                  ? Icons.chevron_right_rounded
                                  : Icons.chevron_left_rounded,
                              size: 13,
                              color: SaoColors.textMutedFor(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Main workbench
              Expanded(
                child: _MainWorkbench(
                  filters: filters,
                  tabController: _tabController,
                  allItems: reportableItems,
                  focusedItem: focusedItem,
                  selectedItems: selectedItems,
                  summaryCtrl: _summaryCtrl,
                  titleCtrl: _titleCtrl,
                  purposeCtrl: _purposeCtrl,
                  detailCtrl: _detailCtrl,
                  agreementsCtrl: _agreementsCtrl,
                  includeAudit: _includeAudit,
                  includeNotes: _includeNotes,
                  includeAttachments: _includeAttachments,
                  showRisk: _showRisk,
                  showTechGps: _showTechGps,
                  showPhotoGps: _showPhotoGps,
                  onToggleRisk: () =>
                      setState(() => _showRisk = !_showRisk),
                  onToggleTechGps: () =>
                      setState(() => _showTechGps = !_showTechGps),
                  onTogglePhotoGps: () =>
                      setState(() => _showPhotoGps = !_showPhotoGps),
                  withDraft: _withDraft,
                  onFocusPrev: () {
                    if (reportableItems.isEmpty || _focusedId == null) return;
                    final idx =
                        reportableItems.indexWhere((a) => a.id == _focusedId);
                    if (idx > 0) {
                      setState(() => _loadIntoEditor(reportableItems[idx - 1]));
                    }
                  },
                  onFocusNext: () {
                    if (reportableItems.isEmpty || _focusedId == null) return;
                    final idx =
                        reportableItems.indexWhere((a) => a.id == _focusedId);
                    if (idx < reportableItems.length - 1) {
                      setState(() => _loadIntoEditor(reportableItems[idx + 1]));
                    }
                  },
                  focusedIdx:
                      _focusedId == null ? -1 : reportableItems.indexWhere((a) => a.id == _focusedId),
                  totalItems: reportableItems.length,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TOP BAR
// ═══════════════════════════════════════════════════════════════════════════════

class _TopBar extends ConsumerWidget {
  final ReportFilters filters;
  final List<String> fronts;
  final int selectedCount;
  final bool isGenerating;
  final bool canGenerate;
  final VoidCallback onRefresh;
  final ValueChanged<String> onProjectChanged;
  final VoidCallback onGenerate;

  const _TopBar({
    required this.filters,
    required this.fronts,
    required this.selectedCount,
    required this.isGenerating,
    required this.canGenerate,
    required this.onRefresh,
    required this.onProjectChanged,
    required this.onGenerate,
  });

  void _updateFilters(WidgetRef ref, ReportFilters updated) =>
      ref.read(reportFiltersProvider.notifier).state = updated;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(reportProjectsProvider);

    return Container(
      height: 52,
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: SaoSpacing.md),
      child: Row(
        children: [
          // Title
          const Icon(Icons.summarize_rounded,
              color: SaoColors.primary, size: 18),
          const SizedBox(width: SaoSpacing.sm),
          const Text('Reportes Operativos', style: SaoTypography.sectionTitle),
          const SizedBox(width: SaoSpacing.lg),

          // Project filter
          projectsAsync.when(
            loading: () => const SizedBox(
                width: 120,
                child: LinearProgressIndicator(minHeight: 2)),
            error: (_, __) => const SizedBox(),
            data: (projects) {
              final val = projects.contains(filters.projectId)
                  ? filters.projectId
                  : (projects.isNotEmpty ? projects.first : '');
              return _CompactDropdown(
                label: 'Proyecto',
                value: val,
                items: projects,
                onChanged: onProjectChanged,
              );
            },
          ),
          const SizedBox(width: SaoSpacing.sm),

          // Front filter
          _CompactDropdown(
            label: 'Frente',
            value: fronts.contains(filters.frontName)
                ? filters.frontName
                : fronts.first,
            items: fronts,
            onChanged: (v) =>
                _updateFilters(ref, filters.copyWith(frontName: v)),
          ),
          const SizedBox(width: SaoSpacing.sm),

          // Date range
          _DateButton(
            range: filters.dateRange,
            onPick: (picked) => _updateFilters(
              ref,
              filters.copyWith(
                dateRange: ReportDateRange(
                    start: picked.start, end: picked.end),
              ),
            ),
          ),

          const Spacer(),

          // Refresh
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 18),
            tooltip: 'Actualizar lista',
            onPressed: onRefresh,
          ),
          const SizedBox(width: SaoSpacing.xs),

          // Generate PDF
          FilledButton.icon(
            onPressed: canGenerate ? onGenerate : null,
            style: FilledButton.styleFrom(
              backgroundColor: SaoColors.primary,
              foregroundColor: SaoColors.onPrimary,
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(SaoRadii.md)),
            ),
            icon: isGenerating
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.picture_as_pdf_rounded, size: 16),
            label: Text(
              isGenerating
                  ? 'Generando…'
                  : selectedCount == 0
                      ? 'Generar PDF'
                      : 'Generar PDF  ($selectedCount)',
              style: SaoTypography.buttonText
                  .copyWith(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  const _CompactDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox();
    final safeVal = items.contains(value) ? value : items.first;
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: SaoColors.borderFor(context)),
        borderRadius: BorderRadius.circular(SaoRadii.sm),
        color: SaoColors.surfaceMutedFor(context),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: safeVal,
          isDense: true,
          items: items
              .map((p) => DropdownMenuItem(value: p, child: Text(p)))
              .toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
          style: SaoTypography.bodyText.copyWith(fontSize: 13),
          hint: Text(label,
              style: SaoTypography.caption.copyWith(
                  color: SaoColors.textMutedFor(context))),
        ),
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  final ReportDateRange range;
  final ValueChanged<DateTimeRange> onPick;

  const _DateButton({required this.range, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () async {
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2024),
          lastDate: DateTime(2030),
          initialDateRange:
              DateTimeRange(start: range.start, end: range.end),
        );
        if (picked != null) onPick(picked);
      },
      style: OutlinedButton.styleFrom(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        side: const BorderSide(color: SaoColors.border),
        foregroundColor: SaoColors.gray700,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SaoRadii.sm)),
      ),
      icon: const Icon(Icons.calendar_today_rounded, size: 14),
      label: Text(
        '${_fmtDate(range.start)} → ${_fmtDate(range.end)}',
        style: SaoTypography.caption
            .copyWith(color: SaoColors.gray700, fontSize: 12),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// LEFT ACTIVITY TRAY
// ═══════════════════════════════════════════════════════════════════════════════

class _ActivityTray extends StatelessWidget {
  final AsyncValue<List<ReportActivityItem>> activitiesAsync;
  final Set<String> selectedIds;
  final String? focusedId;
  final List<ReportActivityItem> allItems;
  final bool includeAudit;
  final bool includeNotes;
  final bool includeAttachments;
  final TextEditingController summaryCtrl;
  final String? lastSavedPath;
  final ValueChanged<ReportActivityItem> onTap;
  final ValueChanged<ReportActivityItem> onToggleSelect;
  final VoidCallback onSelectAll;
  final VoidCallback onDeselectAll;
  final ValueChanged<bool> onIncludeAudit;
  final ValueChanged<bool> onIncludeNotes;
  final ValueChanged<bool> onIncludeAttachments;
  final VoidCallback onCollapse;

  const _ActivityTray({
    required this.activitiesAsync,
    required this.selectedIds,
    required this.focusedId,
    required this.allItems,
    required this.includeAudit,
    required this.includeNotes,
    required this.includeAttachments,
    required this.summaryCtrl,
    required this.lastSavedPath,
    required this.onTap,
    required this.onToggleSelect,
    required this.onSelectAll,
    required this.onDeselectAll,
    required this.onIncludeAudit,
    required this.onIncludeNotes,
    required this.onIncludeAttachments,
    required this.onCollapse,
  });

  @override
  Widget build(BuildContext context) {
    final approvedItems =
        allItems.where(_isApproved).toList(growable: false);
    final selectedApproved = approvedItems
        .where((a) => selectedIds.contains(a.id))
        .length;
    final allSelected =
        approvedItems.isNotEmpty && selectedApproved == approvedItems.length;
    final textColor = SaoColors.textFor(context);
    final mutedTextColor = SaoColors.textMutedFor(context);
    final raisedSurface = SaoColors.surfaceRaisedFor(context);
    final borderColor = SaoColors.borderFor(context);
    final accent = Theme.of(context).colorScheme.primary;

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Tray header ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: SaoSpacing.sm, vertical: 8),
            color: Theme.of(context).colorScheme.surface,
            child: Row(
              children: [
                Text(
                  'Actividades',
                  style: SaoTypography.sectionTitle.copyWith(color: textColor),
                ),
                const SizedBox(width: SaoSpacing.xs),
                if (approvedItems.isNotEmpty)
                  _CountBadge(
                    label: '$selectedApproved / ${approvedItems.length}',
                    color: SaoColors.success,
                  ),
                const Spacer(),
                // Select all toggle
                if (approvedItems.isNotEmpty)
                  Tooltip(
                    message: allSelected
                        ? 'Quitar todas'
                        : 'Seleccionar todas aprobadas',
                    child: InkWell(
                      onTap: allSelected ? onDeselectAll : onSelectAll,
                      borderRadius: BorderRadius.circular(SaoRadii.sm),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: allSelected
                              ? accent
                              : raisedSurface,
                          borderRadius:
                              BorderRadius.circular(SaoRadii.sm),
                          border: Border.all(
                            color: allSelected
                                ? accent
                                : borderColor,
                          ),
                        ),
                        child: Text(
                          allSelected ? 'Quitar todas' : 'Sel. todas',
                          style: SaoTypography.caption.copyWith(
                            color: allSelected
                                ? Theme.of(context).colorScheme.onPrimary
                                : mutedTextColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(width: 4),
                // Collapse button
                Tooltip(
                  message: 'Ocultar panel',
                  child: InkWell(
                    onTap: onCollapse,
                    borderRadius: BorderRadius.circular(SaoRadii.sm),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.chevron_left_rounded,
                        size: 16,
                        color: mutedTextColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── Activity list ────────────────────────────────────────────────
          Expanded(
            child: activitiesAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator()),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(SaoSpacing.md),
                child: Text('Error: $e',
                    style: SaoTypography.caption
                        .copyWith(color: SaoColors.error)),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.inbox_rounded,
                          size: 40,
                          color: mutedTextColor,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sin actividades',
                          style: TextStyle(
                            color: mutedTextColor,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(SaoSpacing.sm),
                  itemCount: items.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 4),
                  itemBuilder: (_, i) {
                    final item = items[i];
                    final approved = _isApproved(item);
                    return _TrayItem(
                      item: item,
                      isApproved: approved,
                      isSelected: selectedIds.contains(item.id),
                      isFocused: focusedId == item.id,
                      onTap: () => onTap(item),
                      onToggle: approved
                          ? () => onToggleSelect(item)
                          : null,
                    );
                  },
                );
              },
            ),
          ),

          const Divider(height: 1),

          // ── PDF Options ──────────────────────────────────────────────────
          Container(
            color: Theme.of(context).colorScheme.surface,
            padding: const EdgeInsets.fromLTRB(
                SaoSpacing.md, SaoSpacing.sm, SaoSpacing.md, SaoSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Opciones del reporte',
                  style: SaoTypography.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: SaoColors.gray600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: SaoSpacing.xs),
                _OptionRow(
                  icon: Icons.history_rounded,
                  label: 'Auditoría',
                  value: includeAudit,
                  onChanged: onIncludeAudit,
                ),
                _OptionRow(
                  icon: Icons.sticky_note_2_outlined,
                  label: 'Notas internas',
                  value: includeNotes,
                  onChanged: onIncludeNotes,
                ),
                _OptionRow(
                  icon: Icons.photo_library_outlined,
                  label: 'Anexos fotográficos',
                  value: includeAttachments,
                  onChanged: onIncludeAttachments,
                ),
                const SizedBox(height: SaoSpacing.xs),
                Text(
                  'Resumen ejecutivo',
                  style: SaoTypography.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: SaoColors.gray600,
                  ),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: summaryCtrl,
                  maxLines: 3,
                  style: SaoTypography.caption.copyWith(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Texto para la portada del PDF…',
                    hintStyle: SaoTypography.caption
                        .copyWith(color: SaoColors.gray400),
                    isDense: true,
                    contentPadding: const EdgeInsets.all(8),
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(SaoRadii.sm),
                      borderSide:
                          const BorderSide(color: SaoColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(SaoRadii.sm),
                      borderSide:
                          const BorderSide(color: SaoColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(SaoRadii.sm),
                      borderSide: const BorderSide(
                          color: SaoColors.primary, width: 1.5),
                    ),
                  ),
                ),

                // Last saved
                if (lastSavedPath != null) ...[
                  const SizedBox(height: SaoSpacing.xs),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: SaoColors.success.withValues(alpha: 0.07),
                      border: Border.all(
                        color: SaoColors.success.withValues(alpha: 0.4)),
                      borderRadius:
                          BorderRadius.circular(SaoRadii.sm),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            size: 14, color: SaoColors.success),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'PDF guardado',
                            style: SaoTypography.caption.copyWith(
                              color: SaoColors.success,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () async {
                            final f = File(lastSavedPath!);
                            final uri = Uri.file(f.parent.path);
                            if (await canLaunchUrl(uri)) {
                              launchUrl(uri);
                            }
                          },
                          child: Text(
                            'Abrir',
                            style: SaoTypography.caption.copyWith(
                              color: SaoColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
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

// ── Tray item ─────────────────────────────────────────────────────────────────

class _TrayItem extends StatefulWidget {
  final ReportActivityItem item;
  final bool isApproved;
  final bool isSelected;
  final bool isFocused;
  final VoidCallback onTap;
  final VoidCallback? onToggle;

  const _TrayItem({
    required this.item,
    required this.isApproved,
    required this.isSelected,
    required this.isFocused,
    required this.onTap,
    required this.onToggle,
  });

  @override
  State<_TrayItem> createState() => _TrayItemState();
}

class _TrayItemState extends State<_TrayItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final statusColor = SaoColors.getStatusColor(widget.item.status);
    final dimmed = !widget.isApproved;
    final isDark = SaoColors.isDarkMode(context);
    final accent = Theme.of(context).colorScheme.primary;

    // Visual states
    Color cardColor;
    Color borderColor;
    double borderWidth;
    if (widget.isFocused) {
      cardColor = accent.withValues(alpha: isDark ? 0.18 : 0.07);
      borderColor = accent.withValues(alpha: isDark ? 0.75 : 0.55);
      borderWidth = 1.5;
    } else if (widget.isSelected && widget.isApproved) {
      cardColor = SaoColors.success.withValues(alpha: 0.06);
      borderColor = SaoColors.success.withValues(alpha: 0.45);
      borderWidth = 1.5;
    } else if (_hovered) {
      cardColor = SaoColors.surfaceRaisedFor(context);
      borderColor = SaoColors.borderFor(context);
      borderWidth = 1;
    } else {
      cardColor = SaoColors.surfaceFor(context);
      borderColor = SaoColors.borderFor(context);
      borderWidth = 1;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(SaoRadii.sm),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(SaoRadii.sm),
              border: Border.all(color: borderColor, width: borderWidth),
            ),
            child: Row(
              children: [
                // Status color bar — thicker when focused/selected
                AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  width: (widget.isFocused || widget.isSelected) ? 4 : 3,
                  height: 44,
                  decoration: BoxDecoration(
                    color: dimmed ? SaoColors.gray200 : statusColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),

                // Info
                Expanded(
                  child: Opacity(
                    opacity: dimmed ? 0.45 : 1.0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.item.activityType,
                          style: SaoTypography.caption.copyWith(
                            fontWeight: FontWeight.w700,
                            color: widget.isFocused
                                ? SaoColors.primary
                                : SaoColors.gray800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.item.frontName}  ·  ${_fmtCreatedAt(widget.item.createdAt)}',
                          style: SaoTypography.caption.copyWith(
                              color: SaoColors.gray500, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _StatusPill(status: widget.item.status),
                            const SizedBox(width: 5),
                            if (widget.item.evidences.isNotEmpty)
                              _EvidenceBadge(count: widget.item.evidences.length),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Right side: hover actions OR checkbox
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 140),
                  child: _hovered && !widget.isFocused && widget.isApproved
                      // Hover: show quick-action icon
                      ? Tooltip(
                          key: const ValueKey('edit-icon'),
                          message: 'Editar este reporte',
                          child: Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: SaoColors.primary.withValues(alpha: 0.09),
                                borderRadius: BorderRadius.circular(SaoRadii.sm),
                                border: Border.all(
                                  color: SaoColors.primary.withValues(alpha: 0.25)),
                              ),
                              child: const Icon(Icons.edit_rounded,
                                  size: 13, color: SaoColors.primary),
                            ),
                          ),
                        )
                      // Normal: checkbox (approved only)
                      : widget.isApproved
                          ? GestureDetector(
                              key: const ValueKey('checkbox'),
                              onTap: widget.onToggle,
                              behavior: HitTestBehavior.opaque,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: widget.isSelected
                                        ? SaoColors.primary
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: widget.isSelected
                                          ? SaoColors.primary
                                          : SaoColors.gray300,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: widget.isSelected
                                      ? const Icon(Icons.check_rounded,
                                          size: 12, color: Colors.white)
                                      : null,
                                ),
                              ),
                            )
                          : const SizedBox(key: ValueKey('empty'), width: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Small tray helpers ───────────────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = SaoColors.getStatusColor(status);
    final bg = SaoColors.getStatusBackground(status);
    final label = SaoColors.getStatusLabel(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(SaoRadii.full),
        // Border improves contrast for low-saturation states (e.g. PENDIENTE)
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Text(
        label,
        style: SaoTypography.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 10,
        ),
      ),
    );
  }
}

class _EvidenceBadge extends StatelessWidget {
  final int count;
  const _EvidenceBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: SaoColors.info.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(SaoRadii.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.photo_camera_rounded,
              size: 10, color: SaoColors.info),
          const SizedBox(width: 3),
          Text(
            '$count',
            style: SaoTypography.caption.copyWith(
                color: SaoColors.info,
                fontWeight: FontWeight.w700,
                fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _CountBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(SaoRadii.full),
      ),
      child: Text(
        label,
        style: SaoTypography.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _OptionRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(SaoRadii.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Icon(icon,
                size: 14,
                color: value ? SaoColors.primary : SaoColors.gray400),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: SaoTypography.caption.copyWith(
                  color: value ? SaoColors.gray800 : SaoColors.gray400,
                  fontWeight: value ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            // On/Off label — shows state at a glance
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: value
                    ? SaoColors.primary.withValues(alpha: 0.10)
                    : SaoColors.surfaceRaisedFor(context),
                borderRadius: BorderRadius.circular(SaoRadii.full),
              ),
              child: Text(
                value ? 'On' : 'Off',
                style: SaoTypography.caption.copyWith(
                  color: value ? SaoColors.primary : SaoColors.gray400,
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Switch(
              value: value,
              onChanged: onChanged,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              thumbColor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.selected)
                      ? Colors.white
                      : SaoColors.gray400),
              trackColor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.selected)
                      ? SaoColors.primary
                      : SaoColors.gray200),
              trackOutlineColor:
                  WidgetStateProperty.all(Colors.transparent),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN WORKBENCH — Tabs
// ═══════════════════════════════════════════════════════════════════════════════

class _MainWorkbench extends StatelessWidget {
  final ReportFilters filters;
  final TabController tabController;
  final List<ReportActivityItem> allItems;
  final ReportActivityItem? focusedItem;
  final List<ReportActivityItem> selectedItems;
  final TextEditingController summaryCtrl;
  final TextEditingController titleCtrl;
  final TextEditingController purposeCtrl;
  final TextEditingController detailCtrl;
  final TextEditingController agreementsCtrl;
  final bool includeAudit;
  final bool includeNotes;
  final bool includeAttachments;
  final bool showRisk;
  final bool showTechGps;
  final bool showPhotoGps;
  final VoidCallback onToggleRisk;
  final VoidCallback onToggleTechGps;
  final VoidCallback onTogglePhotoGps;
  final ReportActivityItem Function(ReportActivityItem) withDraft;
  final VoidCallback onFocusPrev;
  final VoidCallback onFocusNext;
  final int focusedIdx;
  final int totalItems;

  const _MainWorkbench({
    required this.filters,
    required this.tabController,
    required this.allItems,
    required this.focusedItem,
    required this.selectedItems,
    required this.summaryCtrl,
    required this.titleCtrl,
    required this.purposeCtrl,
    required this.detailCtrl,
    required this.agreementsCtrl,
    required this.includeAudit,
    required this.includeNotes,
    required this.includeAttachments,
    required this.showRisk,
    required this.showTechGps,
    required this.showPhotoGps,
    required this.onToggleRisk,
    required this.onToggleTechGps,
    required this.onTogglePhotoGps,
    required this.withDraft,
    required this.onFocusPrev,
    required this.onFocusNext,
    required this.focusedIdx,
    required this.totalItems,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tab bar
        Container(
          color: Theme.of(context).colorScheme.surface,
          child: TabBar(
            controller: tabController,
            labelStyle: SaoTypography.caption.copyWith(
                fontWeight: FontWeight.w700, fontSize: 13),
            unselectedLabelStyle: SaoTypography.caption
                .copyWith(fontWeight: FontWeight.w500, fontSize: 13),
            labelColor: SaoColors.primary,
            unselectedLabelColor: SaoColors.gray500,
            indicatorColor: SaoColors.primary,
            indicatorWeight: 2,
            tabs: [
              const Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_rounded, size: 15),
                    SizedBox(width: 6),
                    Text('Editar'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.preview_rounded, size: 15),
                    const SizedBox(width: 6),
                    const Text('Vista previa'),
                    if (selectedItems.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      _CountBadge(
                        label: '${selectedItems.length}',
                        color: SaoColors.primary,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Tab content
        Expanded(
          child: TabBarView(
            controller: tabController,
            children: [
              // ── Editor tab ─────────────────────────────────────────────
              ListenableBuilder(
                listenable: Listenable.merge(
                    [titleCtrl, purposeCtrl, detailCtrl, agreementsCtrl]),
                builder: (_, __) => _EditorTab(
                  filters: filters,
                  item: focusedItem,
                  summaryCtrl: summaryCtrl,
                  titleCtrl: titleCtrl,
                  purposeCtrl: purposeCtrl,
                  detailCtrl: detailCtrl,
                  agreementsCtrl: agreementsCtrl,
                  includeAudit: includeAudit,
                  includeNotes: includeNotes,
                  includeAttachments: includeAttachments,
                  showRisk: showRisk,
                  showTechGps: showTechGps,
                  showPhotoGps: showPhotoGps,
                  onToggleRisk: onToggleRisk,
                  onToggleTechGps: onToggleTechGps,
                  onTogglePhotoGps: onTogglePhotoGps,
                  focusedIdx: focusedIdx,
                  totalItems: totalItems,
                  onFocusPrev: onFocusPrev,
                  onFocusNext: onFocusNext,
                ),
              ),

              // ── Preview tab ────────────────────────────────────────────
              ListenableBuilder(
                listenable: Listenable.merge(
                    [titleCtrl, purposeCtrl, detailCtrl, agreementsCtrl]),
                builder: (_, __) => _PreviewTab(
                  filters: filters,
                  selectedItems:
                      selectedItems.map(withDraft).toList(),
                  executiveSummary: summaryCtrl.text.trim(),
                  includeAudit: includeAudit,
                  includeNotes: includeNotes,
                  includeAttachments: includeAttachments,
                  showRisk: showRisk,
                  showPhotoGps: showPhotoGps,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// EDITOR TAB
// ═══════════════════════════════════════════════════════════════════════════════

class _EditorTab extends StatelessWidget {
  final ReportFilters filters;
  final ReportActivityItem? item;
  final TextEditingController summaryCtrl;
  final TextEditingController titleCtrl;
  final TextEditingController purposeCtrl;
  final TextEditingController detailCtrl;
  final TextEditingController agreementsCtrl;
  final bool includeAudit;
  final bool includeNotes;
  final bool includeAttachments;
  final bool showRisk;
  final bool showTechGps;
  final bool showPhotoGps;
  final VoidCallback onToggleRisk;
  final VoidCallback onToggleTechGps;
  final VoidCallback onTogglePhotoGps;
  final int focusedIdx;
  final int totalItems;
  final VoidCallback onFocusPrev;
  final VoidCallback onFocusNext;

  const _EditorTab({
    required this.filters,
    required this.item,
    required this.summaryCtrl,
    required this.titleCtrl,
    required this.purposeCtrl,
    required this.detailCtrl,
    required this.agreementsCtrl,
    required this.includeAudit,
    required this.includeNotes,
    required this.includeAttachments,
    required this.showRisk,
    required this.showTechGps,
    required this.showPhotoGps,
    required this.onToggleRisk,
    required this.onToggleTechGps,
    required this.onTogglePhotoGps,
    required this.focusedIdx,
    required this.totalItems,
    required this.onFocusPrev,
    required this.onFocusNext,
  });

  @override
  Widget build(BuildContext context) {
    if (item == null) {
      return const _EmptyEditor();
    }

    final statusColor = SaoColors.getStatusColor(item!.status);
    final statusBg = SaoColors.getStatusBackground(item!.status);

    return Container(
      color: SaoColors.surfaceMutedFor(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Left: Form ───────────────────────────────────────────────────
          Expanded(
            flex: 5,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(SaoSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Activity header
                  Container(
                    padding: const EdgeInsets.all(SaoSpacing.md),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius:
                          BorderRadius.circular(SaoRadii.md),
                      border: Border.all(color: Theme.of(context).colorScheme.outline),
                    ),
                    child: Row(
                      children: [
                        // Status bar
                        Container(
                          width: 4,
                          height: 40,
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: SaoSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                item!.activityType,
                                style:
                                    SaoTypography.bodyTextBold,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${item!.frontName}  ·  ${_previewLocation(item!)}  ·  ${_fmtCreatedAt(item!.createdAt)}',
                                style: SaoTypography.caption
                                    .copyWith(
                                        color: SaoColors.gray500),
                              ),
                            ],
                          ),
                        ),
                        // Status chip
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(
                                SaoRadii.full),
                          ),
                          child: Text(
                            SaoColors.getStatusLabel(item!.status),
                            style: SaoTypography.caption.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: SaoSpacing.md),

                  // Fields — minLines lets them start compact and grow
                  _EditorField(
                    label: 'Título del reporte',
                    hint: 'Nombre claro y descriptivo de la actividad…',
                    controller: titleCtrl,
                    minLines: 1,
                    maxLines: 2,
                    icon: Icons.title_rounded,
                  ),
                  const SizedBox(height: SaoSpacing.sm),
                  _EditorField(
                    label: 'Propósito',
                    hint: 'Objetivo principal de la actividad…',
                    controller: purposeCtrl,
                    minLines: 2,
                    maxLines: 4,
                    icon: Icons.track_changes_rounded,
                  ),
                  const SizedBox(height: SaoSpacing.sm),
                  _EditorField(
                    label: 'Descripción y desarrollo',
                    hint: 'Detalle de lo ocurrido, personas presentes, acciones tomadas…',
                    controller: detailCtrl,
                    minLines: 4,
                    maxLines: 10,
                    icon: Icons.description_rounded,
                  ),
                  const SizedBox(height: SaoSpacing.sm),
                  _EditorField(
                    label: 'Acuerdos y compromisos',
                    hint: 'Lista los acuerdos alcanzados, uno por línea…',
                    controller: agreementsCtrl,
                    minLines: 3,
                    maxLines: 8,
                    icon: Icons.handshake_rounded,
                  ),
                  const SizedBox(height: SaoSpacing.md),

                  // Display options
                  Container(
                    padding: const EdgeInsets.all(SaoSpacing.md),
                    decoration: BoxDecoration(
                      color: SaoColors.surfaceFor(context),
                      borderRadius:
                          BorderRadius.circular(SaoRadii.md),
                      border: Border.all(color: SaoColors.borderFor(context)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Campos adicionales en el PDF',
                          style: SaoTypography.caption.copyWith(
                            fontWeight: FontWeight.w700,
                            color: SaoColors.gray600,
                          ),
                        ),
                        const SizedBox(height: SaoSpacing.sm),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _ToggleChip(
                              label: 'GPS técnico',
                              icon: Icons.my_location_rounded,
                              active: showTechGps,
                              onTap: onToggleTechGps,
                            ),
                            _ToggleChip(
                              label: 'GPS en fotos',
                              icon: Icons.photo_camera_rounded,
                              active: showPhotoGps,
                              onTap: onTogglePhotoGps,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const VerticalDivider(width: 1),

          // ── Right: Live mini-preview ─────────────────────────────────────
          Expanded(
            flex: 4,
            child: _MiniDocPreview(
              filters: filters,
              item: item!,
              summaryCtrl: summaryCtrl,
              titleCtrl: titleCtrl,
              purposeCtrl: purposeCtrl,
              detailCtrl: detailCtrl,
              agreementsCtrl: agreementsCtrl,
              includeAudit: includeAudit,
              includeNotes: includeNotes,
              includeAttachments: includeAttachments,
              showRisk: showRisk,
              showTechGps: showTechGps,
              showPhotoGps: showPhotoGps,
              focusedIdx: focusedIdx,
              totalItems: totalItems,
              onFocusPrev: onFocusPrev,
              onFocusNext: onFocusNext,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Editor field ──────────────────────────────────────────────────────────────

class _EditorField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final int maxLines;
  final IconData icon;
  final int minLines;

  const _EditorField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.maxLines,
    required this.icon,
    this.minLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: SaoColors.gray500),
            const SizedBox(width: 5),
            Text(
              label,
              style: SaoTypography.caption.copyWith(
                fontWeight: FontWeight.w700,
                color: SaoColors.gray600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          minLines: minLines,
          maxLines: maxLines,
          style: SaoTypography.bodyText.copyWith(fontSize: 13, height: 1.45),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                SaoTypography.caption.copyWith(color: SaoColors.gray300),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: SaoSpacing.sm, vertical: 9),
            filled: true,
            fillColor: SaoColors.surfaceFor(context),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(SaoRadii.sm),
              borderSide: BorderSide(color: SaoColors.borderFor(context)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(SaoRadii.sm),
              borderSide: BorderSide(color: SaoColors.borderFor(context)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(SaoRadii.sm),
              borderSide:
                  const BorderSide(color: SaoColors.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Toggle chip ───────────────────────────────────────────────────────────────

class _ToggleChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _ToggleChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(SaoRadii.full),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          // Solid fill when active — unmistakable on/off state
          color: active ? SaoColors.primary : SaoColors.surfaceRaisedFor(context),
          borderRadius: BorderRadius.circular(SaoRadii.full),
          border: Border.all(
            color: active ? SaoColors.primary : SaoColors.borderFor(context),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Checkmark only when active
            if (active) ...[
              const Icon(Icons.check_rounded, size: 11, color: Colors.white),
              const SizedBox(width: 4),
            ],
            Icon(
              icon,
              size: 13,
              color: active ? Colors.white : SaoColors.gray400,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: SaoTypography.caption.copyWith(
                color: active ? Colors.white : SaoColors.gray500,
                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Mini doc preview (editor right panel) ─────────────────────────────────────

class _MiniDocPreview extends StatelessWidget {
  final ReportFilters filters;
  final ReportActivityItem item;
  final TextEditingController summaryCtrl;
  final TextEditingController titleCtrl;
  final TextEditingController purposeCtrl;
  final TextEditingController detailCtrl;
  final TextEditingController agreementsCtrl;
  final bool includeAudit;
  final bool includeNotes;
  final bool includeAttachments;
  final bool showRisk;
  final bool showTechGps;
  final bool showPhotoGps;
  final int focusedIdx;
  final int totalItems;
  final VoidCallback onFocusPrev;
  final VoidCallback onFocusNext;

  const _MiniDocPreview({
    required this.filters,
    required this.item,
    required this.summaryCtrl,
    required this.titleCtrl,
    required this.purposeCtrl,
    required this.detailCtrl,
    required this.agreementsCtrl,
    required this.includeAudit,
    required this.includeNotes,
    required this.includeAttachments,
    required this.showRisk,
    required this.showTechGps,
    required this.showPhotoGps,
    required this.focusedIdx,
    required this.totalItems,
    required this.onFocusPrev,
    required this.onFocusNext,
  });

  static const double _previewPageWidth = 760;

  @override
  Widget build(BuildContext context) {
    final previewItem = ReportActivityItem(
      id: item.id,
      activityType: item.activityType,
      pk: item.pk,
      frontName: item.frontName,
      status: item.status,
      reviewDecision: item.reviewDecision,
      reviewStatus: item.reviewStatus,
      createdAt: item.createdAt,
      assignedName: item.assignedName,
      projectId: item.projectId,
      title: titleCtrl.text.trim().isNotEmpty ? titleCtrl.text : item.title,
      purpose: purposeCtrl.text.trim().isNotEmpty ? purposeCtrl.text : item.purpose,
      detail: detailCtrl.text.trim().isNotEmpty ? detailCtrl.text : item.detail,
      agreements: agreementsCtrl.text.trim().isNotEmpty
          ? agreementsCtrl.text
          : item.agreements,
      municipality: item.municipality,
      state: item.state,
      colony: item.colony,
      riskLevel: item.riskLevel,
      locationType: item.locationType,
      pkStart: item.pkStart,
      pkEnd: item.pkEnd,
      startTime: item.startTime,
      endTime: item.endTime,
      technicalLatitude: item.technicalLatitude,
      technicalLongitude: item.technicalLongitude,
      gpsPrecision: item.gpsPrecision,
      isUnplanned: item.isUnplanned,
      unplannedReason: item.unplannedReason,
      referenceFolio: item.referenceFolio,
      subcategory: item.subcategory,
      topics: item.topics,
      attendees: item.attendees,
      result: item.result,
      notes: item.notes,
      pendingEvidence: item.pendingEvidence,
      evidenceDueAt: item.evidenceDueAt,
      evidences: item.evidences,
    );

    return Container(
      color: SaoColors.surfaceMutedFor(context),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: SaoSpacing.md, vertical: 8),
            color: SaoColors.surfaceFor(context),
            child: Row(
              children: [
                const Icon(Icons.article_rounded,
                    size: 14, color: SaoColors.gray500),
                const SizedBox(width: 6),
                Text(
                  'Vista previa del documento',
                  style: SaoTypography.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: SaoColors.gray600,
                  ),
                ),
                const Spacer(),
                if (totalItems > 1) ...[
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded, size: 18),
                    onPressed: focusedIdx > 0 ? onFocusPrev : null,
                    tooltip: 'Actividad anterior',
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
                  ),
                  Text(
                    '${focusedIdx + 1} / $totalItems',
                    style: SaoTypography.caption
                        .copyWith(color: SaoColors.gray500),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded, size: 18),
                    onPressed: focusedIdx < totalItems - 1
                        ? onFocusNext
                        : null,
                    tooltip: 'Actividad siguiente',
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(SaoSpacing.md),
              child: _ActualPdfPreview(
                items: [previewItem],
                filters: filters,
                executiveSummary: summaryCtrl.text.trim(),
                includeAudit: includeAudit,
                includeNotes: includeNotes,
                includeAttachments: includeAttachments,
                maxPageWidth: _previewPageWidth,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PREVIEW TAB — Full document preview for all selected activities
// ═══════════════════════════════════════════════════════════════════════════════

class _PreviewTab extends StatelessWidget {
  final ReportFilters filters;
  final List<ReportActivityItem> selectedItems;
  final String executiveSummary;
  final bool includeAudit;
  final bool includeNotes;
  final bool includeAttachments;
  final bool showRisk;
  final bool showPhotoGps;

  const _PreviewTab({
    required this.filters,
    required this.selectedItems,
    required this.executiveSummary,
    required this.includeAudit,
    required this.includeNotes,
    required this.includeAttachments,
    required this.showRisk,
    required this.showPhotoGps,
  });

  static const double _previewPageWidth = 760;

  @override
  Widget build(BuildContext context) {
    if (selectedItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.picture_as_pdf_rounded,
                size: 56, color: SaoColors.gray300),
            const SizedBox(height: 12),
            Text(
              'Ninguna actividad seleccionada para el PDF',
              style: SaoTypography.bodyText
                  .copyWith(color: SaoColors.gray400),
            ),
            const SizedBox(height: 4),
            Text(
              'Usa los checkboxes del panel izquierdo para incluir actividades',
              style: SaoTypography.caption
                  .copyWith(color: SaoColors.gray400),
            ),
          ],
        ),
      );
    }

    return Container(
      color: SaoColors.surfaceMutedFor(context),
      child: Padding(
        padding: const EdgeInsets.all(SaoSpacing.md),
        child: _ActualPdfPreview(
          items: selectedItems,
          filters: filters,
          executiveSummary: executiveSummary,
          includeAudit: includeAudit,
          includeNotes: includeNotes,
          includeAttachments: includeAttachments,
          maxPageWidth: _previewPageWidth,
        ),
      ),
    );
  }
}

class _ActualPdfPreview extends StatelessWidget {
  final List<ReportActivityItem> items;
  final ReportFilters filters;
  final String executiveSummary;
  final bool includeAudit;
  final bool includeNotes;
  final bool includeAttachments;
  final double maxPageWidth;

  const _ActualPdfPreview({
    required this.items,
    required this.filters,
    required this.executiveSummary,
    required this.includeAudit,
    required this.includeNotes,
    required this.includeAttachments,
    required this.maxPageWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: SaoColors.surfaceMutedFor(context),
        borderRadius: BorderRadius.circular(SaoRadii.sm),
        border: Border.all(color: SaoColors.borderFor(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(SaoSpacing.sm),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: SaoColors.surfaceFor(context),
            borderRadius: BorderRadius.circular(SaoRadii.sm),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(SaoRadii.sm),
            child: PdfPreview(
              build: (_) => buildActivitiesPdfBytes(
                items,
                filters,
                executiveSummary: executiveSummary,
                includeAudit: includeAudit,
                includeNotes: includeNotes,
                includeAttachments: includeAttachments,
              ),
              canChangePageFormat: false,
              canChangeOrientation: false,
              canDebug: false,
              allowPrinting: false,
              allowSharing: false,
              useActions: false,
              maxPageWidth: maxPageWidth,
              pdfFileName: 'preview.pdf',
            ),
          ),
        ),
      ),
    );
  }
}

// ── Empty states ──────────────────────────────────────────────────────────────

class _EmptyEditor extends StatelessWidget {
  const _EmptyEditor();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.touch_app_rounded,
              size: 56, color: SaoColors.gray300),
          const SizedBox(height: 12),
          Text(
            'Selecciona una actividad del panel izquierdo',
            style:
                SaoTypography.bodyText.copyWith(color: SaoColors.gray400),
          ),
          const SizedBox(height: 4),
          Text(
            'Las actividades aprobadas se pueden editar antes de generar el PDF',
            style: SaoTypography.caption
                .copyWith(color: SaoColors.gray400),
          ),
        ],
      ),
    );
  }
}

// ── String helper extension ───────────────────────────────────────────────────

