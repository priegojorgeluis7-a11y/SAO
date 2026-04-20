import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/data_mode.dart';
import '../../core/providers/project_providers.dart';
import '../../data/models/activity_model.dart';
import '../auth/app_session_controller.dart';
import '../../data/repositories/activity_repository.dart';
import '../../data/repositories/catalog_repository.dart';
import '../../ui/sao_ui.dart';
import '../../ui/widgets/sao_validation_search_bar.dart';
import 'activity_queue_projection.dart';
import 'widgets/activity_queue_panel.dart';
import 'widgets/activity_details_panel_pro.dart';
import 'widgets/evidence_gallery_panel_pro.dart';
import 'widgets/board_shortcuts.dart';

class ValidationPageNewDesign extends ConsumerStatefulWidget {
  final String? initialActivityId;

  const ValidationPageNewDesign({super.key, this.initialActivityId});

  @override
  ConsumerState<ValidationPageNewDesign> createState() =>
      _ValidationPageNewDesignState();
}

class _ValidationPageNewDesignState
    extends ConsumerState<ValidationPageNewDesign>
    with SingleTickerProviderStateMixin {
  ActivityWithDetails? _selectedActivity;
  List<ActivityWithDetails> _visibleActivities = const [];
  int _selectedEvidenceIndex = 0;
  String _searchQuery = '';
  String _queueTab = 'PENDING';
  final bool _filterPending = false;
  final bool _filterRejected = false;
  final bool _filterChanges = false;
  final bool _filterOnlyConflicts = false; // "Solo conflictos" quick-switch
  String? _selectedRejectReasonCode;
  bool _approving = false;
  late TextEditingController _reviewCommentsController;
  List<ActivityTimelineEntry> _timelineEntries = const [];
  bool _timelineLoading = false;
  String? _timelineError;

  // Filtros avanzados
  String? _filterFront;
  DateTime? _filterDateFrom;
  DateTime? _filterDateTo;

  // Bulk selection
  final Set<String> _bulkSelectedIds = {};
  final Set<String> _dismissedActivityIds = {};
  bool _autoSelectDone = false;

  // ── Panel animations ────────────────────────────────────────────────────
  late AnimationController _panelAnim;
  late Animation<Offset> _slideB; // columna B: desplazamiento
  late Animation<Offset> _slideC; // columna C: empieza 80ms después
  late Animation<double> _fadePanel; // fade del contenedor
  late Animation<double> _fadeContent; // fade del contenido (cascada)

  static const _kOpen = Duration(milliseconds: 280);

  // Auto-refresh
  static const _autoRefreshInterval = Duration(hours: 4);
  Timer? _autoRefreshTimer;
  int _secondsUntilRefresh = _autoRefreshInterval.inSeconds;
  Timer? _countdownTimer;

  bool _canDeleteActivities(AppUser? user, {String? projectId}) {
    if (user == null) return false;
    return user.hasPermission('activity.delete', projectId: projectId);
  }

  void _showDeleteNotAllowedMessage() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tu usuario no tiene permiso para eliminar actividades'),
        backgroundColor: SaoColors.warning,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _reviewCommentsController = TextEditingController();
    final initialProjectId =
        ref.read(activeProjectIdProvider).trim().toUpperCase();

    // Avoid mutating providers during build-related lifecycle callbacks.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final currentProjectId =
          ref.read(operationsProjectFilterProvider).trim().toUpperCase();
      if (currentProjectId != initialProjectId) {
        ref.read(operationsProjectFilterProvider.notifier).state =
            initialProjectId;
      }
    });

    _panelAnim = AnimationController(vsync: this, duration: _kOpen);
    _panelAnim.value = 1.0;

    // B entra desde 6% a la derecha con easeOutCubic
    _slideB = Tween<Offset>(
      begin: const Offset(0.06, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _panelAnim,
      curve: Curves.easeOutCubic,
    ));

    // C entra desde 10% con un inicio retrasado 10% (cascada)
    _slideC = Tween<Offset>(
      begin: const Offset(0.10, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _panelAnim,
      curve: const Interval(0.10, 1.0, curve: Curves.easeOutCubic),
    ));

    _fadePanel = CurvedAnimation(
      parent: _panelAnim,
      curve: Curves.easeOut,
    );

    // El contenido empieza a aparecer cuando el contenedor ya avanzó un 35%
    _fadeContent = CurvedAnimation(
      parent: _panelAnim,
      curve: const Interval(0.35, 1.0, curve: Curves.easeOut),
    );

    _startAutoRefresh();
  }

  Future<void> _handleProjectScopeChanged(String projectId) async {
    setState(() {
      _dismissedActivityIds.clear();
      _bulkSelectedIds.clear();
      _selectedActivity = null;
      _selectedEvidenceIndex = 0;
    });
  }

  Future<void> _persistDismissedActivityIds() async {
    // Persisted hidden queue entries disabled to avoid project views appearing empty.
    return;
  }

  @override
  void dispose() {
    _panelAnim.dispose();
    _reviewCommentsController.dispose();
    _autoRefreshTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  // Selecciona actividad y orquesta la animación
  void _selectActivity(ActivityWithDetails activity) {
    setState(() {
      _selectedActivity = activity;
      _selectedEvidenceIndex = 0;
    });
    _loadTimelineForActivity(activity.activity.id);
    unawaited(_hydrateSelectedActivity(activity));
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _countdownTimer?.cancel();
    _secondsUntilRefresh = _autoRefreshInterval.inSeconds;

    _autoRefreshTimer = Timer.periodic(_autoRefreshInterval, (_) {
      if (!mounted) return;
      ref.invalidate(pendingActivitiesProvider);
      setState(() => _secondsUntilRefresh = _autoRefreshInterval.inSeconds);
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_secondsUntilRefresh > 0) _secondsUntilRefresh--;
      });
    });
  }

  void _manualRefresh() {
    setState(() {
      _dismissedActivityIds.clear();
    });
    unawaited(_persistDismissedActivityIds());
    ref.invalidate(pendingActivitiesProvider);
    _startAutoRefresh();
  }

  String _formatRefreshCountdown() {
    final total = _secondsUntilRefresh;
    final hours = total ~/ 3600;
    final minutes = (total % 3600) ~/ 60;
    final seconds = total % 60;

    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
    }
    if (minutes > 0) {
      return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
    }
    return '${seconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final textColor = SaoColors.textFor(context);
    final mutedTextColor = SaoColors.textMutedFor(context);
    final surfaceRaisedColor = SaoColors.surfaceRaisedFor(context);
    final borderColor = SaoColors.borderFor(context);
    final selectedProjectFilter =
        ref.watch(operationsProjectFilterProvider).trim().toUpperCase();
    final availableProjectsAsync = ref.watch(availableProjectsProvider);
    final projectOptions = _buildProjectOptions(
      availableProjectsAsync.valueOrNull ?? const <String>[],
      selectedProjectFilter,
    );

    final activitiesAsync = ref.watch(pendingActivitiesProvider).whenData(
          (activities) => activities
              .where((a) => !_dismissedActivityIds.contains(a.activity.id))
              .toList(growable: false),
        );
    final opsSummaryItems = activitiesAsync.maybeWhen(
      data: (items) => items,
      orElse: () => const <ActivityWithDetails>[],
    );

    final currentUser = ref.watch(currentAppUserProvider);
    final canDeleteActivities = _canDeleteActivities(
      currentUser,
      projectId: selectedProjectFilter.isEmpty ? null : selectedProjectFilter,
    );

    return BoardShortcuts(
      onApprove: () {
        if (_selectedActivity == null) return;
        _approveActivity();
      },
      onReject: () {
        if (_selectedActivity == null) return;
        _showRejectDialog();
      },
      onSkip: () {
        setState(() {
          _selectedActivity = null;
          _selectedEvidenceIndex = 0;
        });
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Column(
          children: [
            // Top bar con nueva busqueda inteligente
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color:
                        Theme.of(context).colorScheme.shadow.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header con título
                  Row(
                    children: [
                      Icon(Icons.verified_rounded,
                          color: textColor, size: 28),
                      const SizedBox(width: 12),
                      Text(
                        'Validación de Actividades',
                        style: SaoTypography.pageTitle.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      // Auto-refresh indicator
                      Tooltip(
                        message: 'Actualización automática cada 4 h',
                        child: InkWell(
                          onTap: _manualRefresh,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: surfaceRaisedColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    value: _secondsUntilRefresh /
                                        _autoRefreshInterval.inSeconds,
                                    strokeWidth: 2,
                                    color: textColor,
                                    backgroundColor: borderColor,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _formatRefreshCountdown(),
                                  style: SaoTypography.caption.copyWith(
                                    color: mutedTextColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Barra de busqueda inteligente
                  SaoValidationSearchBar(
                    onSearchChanged: (query) {
                      setState(() => _searchQuery = query);
                    },
                    resultCount: activitiesAsync.maybeWhen(
                      data: (activities) {
                        if (_searchQuery.isEmpty) return activities.length;
                        final filtered = activities.where((activity) {
                          final searchableText = [
                            activity.activity.id,
                            activity.activity.title,
                            activity.front?.name ?? '',
                            activity.municipality?.name ?? '',
                            activity.activityType?.name ?? '',
                          ].join(' ').toLowerCase();
                          return searchableText
                              .contains(_searchQuery.toLowerCase());
                        }).toList();
                        return filtered.length;
                      },
                      orElse: () => null,
                    ),
                    projectName: selectedProjectFilter,
                    projectOptions: projectOptions,
                    onProjectChanged: (projectId) {
                      unawaited(_setProjectFilter(projectId));
                    },
                    allProjectsLabel: 'Todos',
                    onFilterPressed: () => _showAdvancedFilters(),
                  ),
                  const SizedBox(height: 10),
                  _buildConflictSummaryStrip(),
                  const SizedBox(height: 8),
                  _OperationsHealthStrip(items: opsSummaryItems),
                ],
              ),
            ),

            // ── Bulk action bar (visible when items are selected) ──
            if (_bulkSelectedIds.isNotEmpty)
              _BulkActionBar(
                selectedCount: _bulkSelectedIds.length,
                visibleActivities: _visibleActivities,
                bulkSelectedIds: _bulkSelectedIds,
                onClear: () => setState(() => _bulkSelectedIds.clear()),
                onApproveAll: _bulkApproveSelected,
                canDeleteAll: canDeleteActivities,
                onDeleteAll: _bulkDeleteSelected,
              ),

            // ── Tres columnas 20 / 45 / 35 ─────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── A. Cola compacta (20%) + scrim ───────────
                    Expanded(
                      flex: 20,
                      child: Stack(
                        children: [
                          ActivityQueuePanel(
                            activitiesAsync: activitiesAsync,
                            selectedActivity: _selectedActivity,
                            searchQuery: _searchQuery,
                            queueTab: _queueTab,
                            filterPending: _filterPending,
                            filterRejected: _filterRejected,
                            filterChanges: _filterChanges,
                            filterOnlyConflicts: _filterOnlyConflicts,
                            filterFront: _filterFront,
                            filterDateFrom: _filterDateFrom,
                            filterDateTo: _filterDateTo,
                            bulkSelectedIds: _bulkSelectedIds,
                            onBulkToggle: (id) => setState(() {
                              if (_bulkSelectedIds.contains(id)) {
                                _bulkSelectedIds.remove(id);
                              } else {
                                _bulkSelectedIds.add(id);
                              }
                            }),
                            onBulkSelectAll: () => setState(() {
                              _bulkSelectedIds.addAll(
                                  _visibleActivities.map((a) => a.activity.id));
                            }),
                            onBulkClear: () =>
                                setState(() => _bulkSelectedIds.clear()),
                            onQueueTabChanged: (tab) =>
                                setState(() => _queueTab = tab),
                            onVisibleActivitiesChanged: (activities) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!mounted) return;
                                setState(() => _visibleActivities = activities);
                                final targetId = widget.initialActivityId;
                                if (targetId != null &&
                                    !_autoSelectDone &&
                                    activities.isNotEmpty) {
                                  final match = activities
                                      .cast<ActivityWithDetails?>()
                                      .firstWhere(
                                        (a) => a!.activity.id == targetId,
                                        orElse: () => null,
                                      );
                                  if (match != null) {
                                    _autoSelectDone = true;
                                    _selectActivity(match);
                                  }
                                }
                              });
                            },
                            onSelectActivity: _selectActivity,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),

                    // ── B. Diff / Detalles (45%) — slide + fade ───
                    Expanded(
                      flex: 45,
                      child: ClipRect(
                        child: SlideTransition(
                          position: _slideB,
                          child: FadeTransition(
                            opacity: _fadePanel,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius:
                                    BorderRadius.circular(SaoRadii.md),
                                border: Border.all(
                                    color:
                                        Theme.of(context).colorScheme.outline),
                              ),
                              // Contenido con fade en cascada
                              child: FadeTransition(
                                opacity: _fadeContent,
                                child: ActivityDetailsPanelPro(
                                  activity: _selectedActivity,
                                  timelineEntries: _timelineEntries,
                                  timelineLoading: _timelineLoading,
                                  timelineError: _timelineError,
                                  onFieldChanged: (field, value) async {
                                    await _handleQuickFieldChange(field, value);
                                  },
                                  onAcceptChange: (field) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(SnackBar(
                                      content: Text('Cambio aceptado: $field'),
                                      backgroundColor: SaoColors.success,
                                    ));
                                  },
                                  onRevertChange: (field) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(SnackBar(
                                      content: Text('Cambio revertido: $field'),
                                      backgroundColor: SaoColors.warning,
                                    ));
                                  },
                                  onCatalogAdd: (field, capturedValue) async {
                                    await _handleCatalogAdd(
                                        field, capturedValue);
                                  },
                                  onCatalogLink: (field, capturedValue,
                                      selectedValue) async {
                                    await _handleCatalogLink(
                                        field, capturedValue, selectedValue);
                                  },
                                  onCatalogCorrection:
                                      (field, capturedValue) async {
                                    await _handleCatalogCorrection(
                                        field, capturedValue);
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // ── C. Evidencias + Mapa (35%) — slide retrasado (cascada)
                    Expanded(
                      flex: 35,
                      child: ClipRect(
                        child: SlideTransition(
                          position: _slideC,
                          child: FadeTransition(
                            opacity: _fadePanel,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius:
                                    BorderRadius.circular(SaoRadii.md),
                                border: Border.all(
                                    color:
                                        Theme.of(context).colorScheme.outline),
                              ),
                              child: FadeTransition(
                                opacity: _fadeContent,
                                child: EvidenceGalleryPanelPro(
                                  activity: _selectedActivity,
                                  selectedIndex: _selectedEvidenceIndex,
                                  onSelectEvidence: (index) => setState(
                                      () => _selectedEvidenceIndex = index),
                                  onCaptionChanged: (evidenceId, caption) =>
                                      _saveEvidenceCaption(evidenceId, caption),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer con acciones rapidas
            if (_selectedActivity != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: const Border(
                    top: BorderSide(color: SaoColors.border),
                  ),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 1260;

                    final currentIssues = _selectedActivity == null
                        ? const <String>[]
                        : deriveActivityBlockingIssues(_selectedActivity!);
                    final guidanceText = _selectedActivity == null
                        ? 'Selecciona una actividad para empezar.'
                        : currentIssues.isEmpty
                            ? 'Siguiente paso: revisa la foto y presiona “Validar y enviar”.'
                            : 'Siguiente paso: ${currentIssues.first}. Después decide si validas o solicitas corrección.';

                    final helpText = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          guidanceText,
                          maxLines: compact ? 3 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: SaoTypography.bodyText.copyWith(
                            color: SaoColors.gray800,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.keyboard_rounded,
                                color: SaoColors.gray400, size: 14),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                canDeleteActivities
                                    ? 'Atajos: Enter = Validar  ·  R = Rechazar  ·  Del = Eliminar  ·  Esc = Limpiar selección'
                                    : 'Atajos: Enter = Validar  ·  R = Rechazar  ·  Esc = Limpiar selección',
                                maxLines: compact ? 2 : 1,
                                overflow: TextOverflow.ellipsis,
                                style: SaoTypography.caption
                                    .copyWith(color: SaoColors.gray400),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );

                    final actions = Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      alignment: WrapAlignment.end,
                      children: [
                        if (canDeleteActivities)
                          ElevatedButton.icon(
                            onPressed: _selectedActivity == null
                                ? null
                                : () => _deleteSelectedActivity(),
                            icon: const Icon(Icons.delete_outline_rounded),
                            label: const Text('Eliminar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: SaoColors.gray700,
                              foregroundColor: SaoColors.onPrimary,
                              disabledBackgroundColor: SaoColors.gray300,
                            ),
                          ),
                        ElevatedButton.icon(
                          onPressed: _selectedActivity == null
                              ? null
                              : () => _showRejectDialog(),
                          icon: const Icon(Icons.cancel_rounded),
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Rechazar'),
                              const SizedBox(width: SaoSpacing.xs),
                              _buildShortcutPill('R'),
                            ],
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: SaoColors.error,
                            foregroundColor: SaoColors.onPrimary,
                            disabledBackgroundColor: SaoColors.gray300,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _selectedActivity == null
                              ? null
                              : () => _approveActivity(),
                          icon: const Icon(Icons.check_circle_rounded),
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Validar y enviar'),
                              const SizedBox(width: SaoSpacing.xs),
                              _buildShortcutPill('Enter'),
                            ],
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: SaoColors.success,
                            foregroundColor: SaoColors.onPrimary,
                            disabledBackgroundColor: SaoColors.gray300,
                          ),
                        ),
                      ],
                    );

                    if (compact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          helpText,
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: actions,
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: helpText),
                        const SizedBox(width: 16),
                        actions,
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAdvancedFilters() async {
    // Extraer frentes únicos de las actividades cargadas
    final activitiesSnapshot =
        ref.read(pendingActivitiesProvider).value ?? const [];
    final fronts = activitiesSnapshot
        .map((a) => a.front?.name ?? 'Sin asignar')
        .toSet()
        .toList()
      ..sort();

    // Valores temporales dentro del diálogo
    String? tempFront = _filterFront;
    DateTime? tempFrom = _filterDateFrom;
    DateTime? tempTo = _filterDateTo;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setLocal) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.filter_alt_rounded, color: SaoColors.primary),
                SizedBox(width: 10),
                Text('Filtros avanzados'),
              ],
            ),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Frente ---
                  Text('Frente',
                      style: SaoTypography.caption
                          .copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: tempFront,
                    isExpanded: true,
                    decoration: InputDecoration(
                      hintText: 'Todos los frentes',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                          value: null, child: Text('Todos los frentes')),
                      ...fronts.map(
                          (f) => DropdownMenuItem(value: f, child: Text(f))),
                    ],
                    onChanged: (v) => setLocal(() => tempFront = v),
                  ),
                  const SizedBox(height: 20),
                  // --- Fecha desde ---
                  Text('Fecha desde',
                      style: SaoTypography.caption
                          .copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  _DatePickerField(
                    value: tempFrom,
                    hint: 'Sin límite inferior',
                    onPicked: (d) => setLocal(() => tempFrom = d),
                    onCleared: () => setLocal(() => tempFrom = null),
                  ),
                  const SizedBox(height: 16),
                  // --- Fecha hasta ---
                  Text('Fecha hasta',
                      style: SaoTypography.caption
                          .copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  _DatePickerField(
                    value: tempTo,
                    hint: 'Sin límite superior',
                    onPicked: (d) => setLocal(() => tempTo = d),
                    onCleared: () => setLocal(() => tempTo = null),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _filterFront = null;
                    _filterDateFrom = null;
                    _filterDateTo = null;
                  });
                  Navigator.pop(ctx);
                },
                child:
                  const Text('Limpiar', style: TextStyle(color: SaoColors.gray600)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () {
                  setState(() {
                    _filterFront = tempFront;
                    _filterDateFrom = tempFrom;
                    _filterDateTo = tempTo;
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('Aplicar'),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _loadTimelineForActivity(String activityId) async {
    setState(() {
      _timelineLoading = true;
      _timelineError = null;
      _timelineEntries = const [];
    });

    final repo = ref.read(activityRepositoryProvider);
    try {
      final timeline = await repo.getActivityTimeline(activityId);
      if (!mounted || _selectedActivity?.activity.id != activityId) return;
      setState(() {
        _timelineEntries = timeline;
      });
    } catch (_) {
      if (!mounted || _selectedActivity?.activity.id != activityId) return;
      setState(() {
        _timelineError = 'No se pudo cargar el historial';
      });
    } finally {
      if (mounted && _selectedActivity?.activity.id == activityId) {
        setState(() {
          _timelineLoading = false;
        });
      }
    }
  }

  Future<void> _hydrateSelectedActivity(ActivityWithDetails summary) async {
    final repo = ref.read(activityRepositoryProvider);
    try {
      final hydrated = await repo.hydrateReviewActivity(summary);
      if (!mounted || hydrated == null) return;
      if (_selectedActivity?.activity.id != summary.activity.id) return;
      setState(() {
        _selectedActivity = hydrated;
      });
    } catch (_) {
      // Keep summary data if backend detail hydration fails.
    }
  }

  Widget _buildShortcutPill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SaoSpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: SaoColors.onPrimary.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(SaoRadii.sm),
        border: Border.all(color: SaoColors.onPrimary.withValues(alpha: 0.6)),
      ),
      child: Text(
        label,
        style: SaoTypography.caption.copyWith(
          color: SaoColors.onPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  bool _isConflict(ActivityWithDetails activity) {
    return activity.flags.gpsMismatch ||
        activity.flags.catalogChanged ||
        activity.flags.checklistIncomplete;
  }

  void _jumpToNextConflict() {
    final conflicts = _visibleActivities.where(_isConflict).toList();
    if (conflicts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay conflictos en la vista actual')),
      );
      return;
    }

    if (_selectedActivity == null) {
      _selectActivity(conflicts.first);
      return;
    }

    final currentIndex = conflicts.indexWhere(
      (a) => a.activity.id == _selectedActivity!.activity.id,
    );
    final next = currentIndex == -1 || currentIndex + 1 >= conflicts.length
        ? conflicts.first
        : conflicts[currentIndex + 1];
    _selectActivity(next);
  }

  Widget _buildConflictSummaryStrip() {
    if (_visibleActivities.isEmpty) {
      return const SizedBox.shrink();
    }

    final total = _visibleActivities.length;
    final conflicts = _visibleActivities.where(_isConflict).length;
    final healthy = total - conflicts;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: conflicts > 0
            ? SaoColors.warning.withValues(alpha: 0.08)
            : SaoColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: conflicts > 0 ? SaoColors.warning : SaoColors.success,
        ),
      ),
      child: Row(
        children: [
          Icon(
            conflicts > 0
                ? Icons.warning_amber_rounded
                : Icons.verified_rounded,
            size: 18,
            color: conflicts > 0 ? SaoColors.warning : SaoColors.success,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              conflicts > 0
                  ? 'Hay $conflicts actividades con conflicto en esta vista ($healthy sin conflicto).'
                  : 'No hay conflictos en la vista actual ($healthy actividades saludables).',
              style: SaoTypography.caption.copyWith(
                color: SaoColors.gray700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (conflicts > 0)
            TextButton.icon(
              onPressed: _jumpToNextConflict,
              icon: const Icon(Icons.skip_next_rounded, size: 16),
              label: const Text('Ir al siguiente conflicto'),
            ),
        ],
      ),
    );
  }

  /// Aprueba la actividad seleccionada y carga la siguiente
  Future<void> _approveActivity() async {
    if (_selectedActivity == null || _approving) return;
    final previousActivityId = _selectedActivity!.activity.id;

    final repo = ref.read(activityRepositoryProvider);
    try {
      setState(() => _approving = true);
      final readiness = await repo.getActivityReadiness(previousActivityId);
      if (!readiness.ready) {
        if (mounted) {
          await _showReadinessBlockedDialog(readiness);
        }
        return;
      }

      await repo.approveActivity(previousActivityId, 'usr-admin-001');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: SaoColors.onPrimary),
                SizedBox(width: SaoSpacing.md),
                Expanded(
                  child: Text(
                    'Actividad validada y enviada a Reportes',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: SaoColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(SaoRadii.sm)),
            duration: const Duration(seconds: 2),
          ),
        );

        await _refreshQueueAfterDecision(
          processedActivityId: previousActivityId,
          targetTab: 'PENDING',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al aprobar: $e'),
            backgroundColor: SaoColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _approving = false);
      }
    }
  }

  Future<void> _showReadinessBlockedDialog(
    ActivityReadinessResult readiness,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.rule_rounded, color: SaoColors.warning),
              SizedBox(width: 8),
              Expanded(child: Text('Faltan requisitos antes de enviar')),
            ],
          ),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Checklist: ${readiness.checklistSummary.completed}/${readiness.checklistSummary.total} completado · Evidencias: ${readiness.evidenceCount}',
                  style: SaoTypography.caption.copyWith(
                    color: SaoColors.textMutedFor(ctx),
                  ),
                ),
                const SizedBox(height: SaoSpacing.md),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: readiness.missing
                          .map(
                            (item) => Container(
                              margin: const EdgeInsets.only(bottom: SaoSpacing.sm),
                              padding: const EdgeInsets.all(SaoSpacing.md),
                              decoration: BoxDecoration(
                                color: SaoColors.surfaceMutedFor(ctx),
                                borderRadius: BorderRadius.circular(SaoRadii.md),
                                border: Border.all(color: SaoColors.borderFor(ctx)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.warning_amber_rounded,
                                    color: SaoColors.warning,
                                    size: 20,
                                  ),
                                  const SizedBox(width: SaoSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.message,
                                          style: SaoTypography.bodyTextBold,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Código: ${item.code}',
                                          style: SaoTypography.caption.copyWith(
                                            color: SaoColors.textMutedFor(ctx),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          _readinessActionByCode(item.code),
                                          style: SaoTypography.caption.copyWith(
                                            color: SaoColors.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Entendido'),
            ),
          ],
        );
      },
    );
  }

  String _readinessActionByCode(String code) {
    return switch (code.toUpperCase()) {
      'MISSING_GPS_COORDINATES' =>
        'Sugerencia: captura o corrige ubicación en el paso de ubicación.',
      'GPS_MISMATCH_FLAG' =>
        'Sugerencia: revisa PK/ubicación y vuelve a registrar GPS en sitio.',
      'MIN_EVIDENCE_NOT_MET' =>
        'Sugerencia: agrega las evidencias faltantes antes de enviar.',
      'WIZARD_NOT_FILLED' =>
        'Sugerencia: completa el formulario principal de la actividad.',
      'CHECKLIST_INCOMPLETE' =>
        'Sugerencia: completa los pendientes del checklist del wizard.',
      _ => 'Sugerencia: revisa y completa el requisito marcado.',
    };
  }

  /// Muestra diálogo para rechazar la actividad
  void _showRejectDialog() {
    final repo = ref.read(activityRepositoryProvider);
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: SaoColors.surfaceFor(ctx),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SaoRadii.xl)),
        child: Container(
          width: 550,
          padding: const EdgeInsets.all(SaoSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(SaoSpacing.md),
                    decoration: BoxDecoration(
                      color: SaoColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(SaoRadii.md),
                    ),
                    child: const Icon(Icons.cancel_rounded,
                        color: SaoColors.error, size: 28),
                  ),
                  const SizedBox(width: SaoSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rechazar Actividad',
                          style: SaoTypography.pageTitle.copyWith(
                            color: SaoColors.textFor(ctx),
                          ),
                        ),
                        Text(
                          'Se enviará solicitud de corrección al móvil',
                          style: SaoTypography.caption.copyWith(
                            color: SaoColors.textMutedFor(ctx),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: SaoSpacing.xxl),
              const Text(
                'Motivo del rechazo:',
                style: SaoTypography.bodyTextBold,
              ),
              const SizedBox(height: SaoSpacing.md),
              TextField(
                controller: _reviewCommentsController,
                maxLines: 4,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Ej: La foto está borrosa, tomar de nuevo',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(SaoRadii.md)),
                  filled: true,
                  fillColor: SaoColors.surfaceMutedFor(ctx),
                ),
              ),
              const SizedBox(height: SaoSpacing.lg),
              Text(
                'Motivos comunes:',
                style:
                    SaoTypography.caption.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: SaoSpacing.md),
              FutureBuilder<List<RejectionPlaybookItem>>(
                future: repo.getRejectPlaybook(
                    projectId: _selectedActivity?.activity.projectId),
                builder: (context, snapshot) {
                  final items =
                      (snapshot.data != null && snapshot.data!.isNotEmpty)
                          ? snapshot.data!
                          : const <RejectionPlaybookItem>[
                              RejectionPlaybookItem(
                                reasonCode: 'PHOTO_BLUR',
                                label: 'Foto borrosa',
                                severity: 'MED',
                                requiresComment: false,
                              ),
                              RejectionPlaybookItem(
                                reasonCode: 'GPS_MISMATCH',
                                label: 'GPS no coincide',
                                severity: 'HIGH',
                                requiresComment: true,
                              ),
                              RejectionPlaybookItem(
                                reasonCode: 'MISSING_INFO',
                                label: 'Falta información',
                                severity: 'MED',
                                requiresComment: true,
                              ),
                            ];

                  return Wrap(
                    spacing: SaoSpacing.sm,
                    runSpacing: SaoSpacing.sm,
                    children: items.map((item) {
                      return _buildReasonChip(
                        item.label,
                        reasonCode: item.reasonCode,
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: SaoSpacing.xxl),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      _reviewCommentsController.clear();
                      Navigator.pop(ctx);
                    },
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: SaoSpacing.md),
                  FilledButton.icon(
                    onPressed: () async {
                      if (_reviewCommentsController.text.trim().isEmpty) return;
                      Navigator.pop(ctx);
                      await _rejectActivity();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: SaoColors.error,
                      padding: const EdgeInsets.symmetric(
                          horizontal: SaoSpacing.xxl, vertical: SaoSpacing.md),
                    ),
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: const Text('Enviar Rechazo'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Chip con motivo común de rechazo
  Widget _buildReasonChip(String reason, {required String reasonCode}) {
    return ActionChip(
      label: Text(reason, style: SaoTypography.chipText),
      onPressed: () {
        _selectedRejectReasonCode = reasonCode;
        _reviewCommentsController.text = reason;
      },
      backgroundColor: SaoColors.surfaceRaisedFor(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: SaoColors.borderFor(context)),
      ),
    );
  }

  /// Rechaza la actividad con comentarios
  Future<void> _rejectActivity() async {
    if (_selectedActivity == null) return;
    final previousActivityId = _selectedActivity!.activity.id;

    final comments = _reviewCommentsController.text.trim();
    if (comments.isEmpty) return;

    final repo = ref.read(activityRepositoryProvider);
    try {
      await repo.rejectActivity(
        previousActivityId,
        'usr-admin-001',
        comments,
        _selectedRejectReasonCode,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.cancel_rounded, color: SaoColors.onPrimary),
                SizedBox(width: SaoSpacing.md),
                Expanded(
                  child: Text(
                    'Actividad rechazada y visible en Rechazadas',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: SaoColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(SaoRadii.sm)),
            duration: const Duration(seconds: 2),
          ),
        );

        // Limpiar controles
        _reviewCommentsController.clear();
        _selectedRejectReasonCode = null;

        await _refreshQueueAfterDecision(
          processedActivityId: previousActivityId,
          targetTab: 'REJECTED',
          highlightProcessedActivity: true,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al rechazar: $e'),
            backgroundColor: SaoColors.error,
          ),
        );
      }
    }
  }

  Future<void> _saveEvidenceCaption(String evidenceId, String caption) async {
    final repo = ref.read(activityRepositoryProvider);
    try {
      await repo.updateEvidenceCaption(evidenceId, caption);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pie de foto guardado'),
          duration: Duration(seconds: 1),
          backgroundColor: SaoColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo guardar el pie de foto: $e'),
          backgroundColor: SaoColors.error,
        ),
      );
    }
  }

  Future<void> _handleQuickFieldChange(String field, String value) async {
    if (_selectedActivity == null) {
      return;
    }
    if (!_ensureRealBackendAvailable()) {
      return;
    }

    final activityId = _selectedActivity!.activity.id;
    final repo = ref.read(activityRepositoryProvider);

    try {
      switch (field) {
        case 'title':
          await repo.updateActivityFields(activityId, title: value);
          break;
        case 'description':
          await repo.updateActivityFields(activityId, description: value);
          break;
        default:
          break;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Campo "$field" guardado'),
          duration: const Duration(seconds: 1),
          backgroundColor: SaoColors.success,
        ),
      );
      ref.invalidate(pendingActivitiesProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo guardar "$field": $e'),
          backgroundColor: SaoColors.error,
        ),
      );
    }
  }

  Future<void> _handleCatalogAdd(String field, String capturedValue) async {
    final activity = _selectedActivity;
    if (activity == null) return;
    if (!_ensureRealBackendAvailable()) {
      return;
    }

    final value = capturedValue.trim();
    if (value.isEmpty || value.toLowerCase() == 'sin propósito capturado') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay valor válido para agregar al catálogo'),
          backgroundColor: SaoColors.warning,
        ),
      );
      return;
    }

    final projectId = activity.activity.projectId.trim().isNotEmpty
        ? activity.activity.projectId
        : ref.read(activeProjectIdProvider);
    final catalogRepo = ref.read(catalogRepositoryProvider);
    final repo = ref.read(activityRepositoryProvider);

    try {
      await catalogRepo.loadProject(projectId);

      switch (field) {
        case 'subcategoria':
          final activityId =
              await _ensureCatalogActivity(catalogRepo, projectId);
          await catalogRepo.createSubcategory(
            id: _buildCatalogEntityId('subcat', value),
            activityId: activityId,
            name: value,
            projectId: projectId,
          );
          break;
        case 'tema':
          await catalogRepo.createTopic(
            id: _buildCatalogEntityId('topic', value),
            name: value,
            type: 'OPERATIVO',
            projectId: projectId,
          );
          break;
        case 'proposito':
          final activityId =
              await _ensureCatalogActivity(catalogRepo, projectId);
          await catalogRepo.createPurpose(
            id: _buildCatalogEntityId('purpose', value),
            activityId: activityId,
            name: value,
            projectId: projectId,
          );
          break;
        case 'municipio':
          final currentDescription = activity.activity.description ?? '';
          final mergedDescription = _mergeMunicipalityMarker(
              currentDescription, value,
              mode: 'validado');
          await repo.updateActivityFields(
            activity.activity.id,
            description: mergedDescription,
          );
          break;
        default:
          return;
      }

      // Vincular el campo de la actividad al valor recién creado en catálogo,
      // para que el campo quede marcado como resuelto en la vista.
      try {
        switch (field) {
          case 'subcategoria':
            await repo.updateActivityFields(activity.activity.id,
                title: value);
            break;
          case 'tema':
            await repo.updateActivityFields(activity.activity.id,
                activityTypeCode: value);
            break;
          case 'proposito':
            await repo.updateActivityFields(activity.activity.id,
                description: value);
            break;
          default:
            break;
        }

        // Refrescar _selectedActivity para que la UI muestre el campo como resuelto.
        final refreshed = await repo.getActivityById(activity.activity.id);
        if (mounted &&
            refreshed != null &&
            _selectedActivity?.activity.id == activity.activity.id) {
          setState(() {
            _selectedActivity = refreshed;
          });
        }
      } catch (_) {
        // Si el vínculo falla, el catálogo ya fue creado; no bloquear al usuario.
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"$value" agregado al catálogo y campo actualizado'),
          backgroundColor: SaoColors.success,
        ),
      );
      ref.invalidate(pendingActivitiesProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al agregar en catálogo: $e'),
          backgroundColor: SaoColors.error,
        ),
      );
    }
  }

  Future<void> _handleCatalogLink(
    String field,
    String capturedValue,
    String selectedValue,
  ) async {
    final activity = _selectedActivity;
    if (activity == null) return;
    if (!_ensureRealBackendAvailable()) {
      return;
    }

    final repo = ref.read(activityRepositoryProvider);
    try {
      switch (field) {
        case 'subcategoria':
          await repo.updateActivityFields(activity.activity.id,
              title: selectedValue);
          break;
        case 'tema':
          await repo.updateActivityFields(
            activity.activity.id,
            activityTypeCode: selectedValue,
          );
          break;
        case 'proposito':
          await repo.updateActivityFields(activity.activity.id,
              description: selectedValue);
          break;
        case 'municipio':
          final currentDescription = activity.activity.description ?? '';
          final mergedDescription = _mergeMunicipalityMarker(
            currentDescription,
            selectedValue,
            mode: 'vinculado',
          );
          await repo.updateActivityFields(
            activity.activity.id,
            description: mergedDescription,
          );
          break;
        default:
          return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Vinculación aplicada: "$capturedValue" -> "$selectedValue"'),
          backgroundColor: SaoColors.success,
        ),
      );

      // Ensure UI reflects persisted backend values after linking.
      final refreshed = await repo.getActivityById(activity.activity.id);
      if (!mounted) return;
      if (refreshed != null &&
          _selectedActivity?.activity.id == activity.activity.id) {
        setState(() {
          _selectedActivity = refreshed;
        });
      }

      ref.invalidate(pendingActivitiesProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo vincular en catálogo: $e'),
          backgroundColor: SaoColors.error,
        ),
      );
    }
  }

  Future<void> _handleCatalogCorrection(
      String field, String capturedValue) async {
    final activity = _selectedActivity;
    if (activity == null) return;
    if (!_ensureRealBackendAvailable()) {
      return;
    }

    final repo = ref.read(activityRepositoryProvider);
    final comment = 'Corrección solicitada en $field: $capturedValue';
    try {
      await repo.markNeedsFixStrictBackend(
        activity.activity.id,
        comment,
        'MISSING_INFO',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Solicitud de corrección enviada para $field'),
          backgroundColor: SaoColors.warning,
        ),
      );
      ref.invalidate(pendingActivitiesProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo solicitar corrección: $e'),
          backgroundColor: SaoColors.error,
        ),
      );
    }
  }

  Future<String> _ensureCatalogActivity(
      CatalogRepository catalogRepo, String projectId) async {
    final selected = _selectedActivity;

    // Preferir el ID real del tipo de actividad, que es el mismo que usa el
    // panel de detalle en _catalogLookupKeys para buscar subcategorías/propósitos.
    // Si no existe como actividad en catálogo, crearlo con ese mismo ID.
    final actTypeId = selected?.activityType?.id?.trim() ?? '';
    final actTypeCode = selected?.activityType?.code?.trim() ?? '';
    final candidateName =
        (selected?.activityType?.name ?? selected?.activity.title ?? 'General')
            .trim();

    // 1. Primero buscar por ID exacto en catálogo.
    if (actTypeId.isNotEmpty) {
      for (final item in catalogRepo.data.activities) {
        if (item.id.trim() == actTypeId) return actTypeId;
      }
      // No existe: crear con el actTypeId para que el panel lo encuentre.
      await catalogRepo.createActivity(
        id: actTypeId,
        name: candidateName.isNotEmpty ? candidateName : actTypeId,
        description: 'Generada desde validación de operaciones',
        projectId: projectId,
      );
      return actTypeId;
    }

    // 2. Si no hay ID, buscar por nombre.
    final normalizedName = candidateName.toLowerCase();
    for (final item in catalogRepo.data.activities) {
      if (item.name.trim().toLowerCase() == normalizedName) {
        return item.id;
      }
    }

    // 3. Crear con código si está disponible, o generar ID.
    final baseId = actTypeCode.isNotEmpty
        ? actTypeCode
        : _buildCatalogEntityId('act', candidateName);
    await catalogRepo.createActivity(
      id: baseId,
      name: candidateName.isNotEmpty ? candidateName : baseId,
      description: 'Generada desde validación de operaciones',
      projectId: projectId,
    );
    return baseId;
  }

  String _buildCatalogEntityId(String prefix, String value) {
    final source = value
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ñ', 'n');
    final normalized = source.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    final compact = normalized
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final suffix = DateTime.now().millisecondsSinceEpoch;
    final safe = compact.isEmpty ? 'item' : compact;
    return '${prefix}_${safe}_$suffix';
  }

  String _mergeMunicipalityMarker(
    String description,
    String municipality, {
    required String mode,
  }) {
    final markerPrefix =
        mode == 'validado' ? 'Municipio validado:' : 'Municipio vinculado:';
    final cleanMunicipality = municipality.trim();

    final keptLines = description
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .where(
          (line) =>
              !line.toLowerCase().startsWith('municipio vinculado:') &&
              !line.toLowerCase().startsWith('municipio validado:'),
        )
        .toList(growable: true);

    if (cleanMunicipality.isNotEmpty) {
      keptLines.add('$markerPrefix $cleanMunicipality');
    }

    return keptLines.join('\n').trim();
  }

  bool _ensureRealBackendAvailable() {
    if (AppDataMode.backendBaseUrl.trim().isNotEmpty) {
      return true;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Este flujo requiere backend real configurado (SAO_BACKEND_URL).'),
          backgroundColor: SaoColors.error,
        ),
      );
    }
    return false;
  }

  Future<void> _refreshQueueAfterDecision({
    required String processedActivityId,
    required String targetTab,
    bool highlightProcessedActivity = false,
  }) async {
    final repo = ref.read(activityRepositoryProvider);
    ActivityWithDetails? refreshedActivity;

    if (highlightProcessedActivity) {
      try {
        refreshedActivity = await repo.getActivityById(processedActivityId);
      } catch (_) {
        refreshedActivity = null;
      }
    }

    if (!mounted) return;

    ref.invalidate(pendingActivitiesProvider);

    if (highlightProcessedActivity && refreshedActivity != null) {
      setState(() {
        _queueTab = targetTab;
        _selectedActivity = refreshedActivity;
        _selectedEvidenceIndex = 0;
      });
      _loadTimelineForActivity(processedActivityId);
      unawaited(_hydrateSelectedActivity(refreshedActivity));
      return;
    }

    setState(() => _queueTab = targetTab);
    _loadNextActivity(processedActivityId);
  }

  /// Carga la siguiente actividad en la cola
  void _loadNextActivity(String processedActivityId) {
    final queue = _visibleActivities;
    final currentIndex =
        queue.indexWhere((item) => item.activity.id == processedActivityId);

    ActivityWithDetails? next;
    if (queue.length > 1 && currentIndex >= 0) {
      final forwardIndex = currentIndex + 1;
      if (forwardIndex < queue.length) {
        next = queue[forwardIndex];
      } else {
        next = queue[currentIndex - 1];
      }
    }

    setState(() {
      _selectedActivity = next;
      _selectedEvidenceIndex = 0;
    });
  }

  /// Aprueba en lote todas las actividades seleccionadas sin conflictos
  Future<void> _bulkApproveSelected() async {
    if (_approving) return;
    final repo = ref.read(activityRepositoryProvider);
    final toApprove = _visibleActivities
        .where((a) =>
            _bulkSelectedIds.contains(a.activity.id) &&
            !a.flags.catalogChanged &&
            !a.flags.checklistIncomplete)
        .toList();

    if (toApprove.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hay actividades sin conflictos en la selección'),
            backgroundColor: SaoColors.warning,
          ),
        );
      }
      return;
    }

    setState(() => _approving = true);
    int approved = 0;
    int blocked = 0;
    for (final activity in toApprove) {
      try {
        final readiness = await repo.getActivityReadiness(activity.activity.id);
        if (!readiness.ready) {
          blocked++;
          continue;
        }
        await repo.approveActivity(activity.activity.id, 'usr-admin-001');
        approved++;
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _bulkSelectedIds.clear();
        _approving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            blocked > 0
                ? '$approved validadas · $blocked bloqueadas por requisitos de envío'
                : '$approved actividades validadas',
          ),
          backgroundColor: blocked > 0 ? SaoColors.warning : SaoColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      ref.invalidate(pendingActivitiesProvider);
    } else {
      _approving = false;
    }
  }

  Future<bool> _confirmDeleteDialog({required int count}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar actividades'),
        content: Text(
          count == 1
              ? 'Esta acción eliminará la actividad seleccionada. ¿Deseas continuar?'
              : 'Esta acción eliminará $count actividades seleccionadas. ¿Deseas continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: SaoColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _deleteSelectedActivity() async {
    final currentProjectId = ref.read(operationsProjectFilterProvider).trim();
    if (!_canDeleteActivities(
      ref.read(currentAppUserProvider),
      projectId: currentProjectId.isEmpty ? null : currentProjectId,
    )) {
      _showDeleteNotAllowedMessage();
      return;
    }
    if (_selectedActivity == null) return;
    final shouldDelete = await _confirmDeleteDialog(count: 1);
    if (!shouldDelete) return;

    final activityId = _selectedActivity!.activity.id;
    try {
      await _removeActivityFromQueue(activityId);
      if (!mounted) return;
      setState(() {
        _dismissedActivityIds.add(activityId);
        _bulkSelectedIds.remove(activityId);
        _selectedActivity = null;
        _selectedEvidenceIndex = 0;
      });
      unawaited(_persistDismissedActivityIds());
      ref.invalidate(pendingActivitiesProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Actividad eliminada correctamente'),
          backgroundColor: SaoColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al eliminar: $e'),
          backgroundColor: SaoColors.error,
        ),
      );
    }
  }

  Future<void> _bulkDeleteSelected() async {
    final currentProjectId = ref.read(operationsProjectFilterProvider).trim();
    if (!_canDeleteActivities(
      ref.read(currentAppUserProvider),
      projectId: currentProjectId.isEmpty ? null : currentProjectId,
    )) {
      _showDeleteNotAllowedMessage();
      return;
    }
    if (_bulkSelectedIds.isEmpty) return;
    final ids = _bulkSelectedIds.toList(growable: false);
    final shouldDelete = await _confirmDeleteDialog(count: ids.length);
    if (!shouldDelete) return;

    var deleted = 0;
    final deletedIds = <String>[];
    for (final id in ids) {
      try {
        await _removeActivityFromQueue(id);
        deleted++;
        deletedIds.add(id);
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _dismissedActivityIds.addAll(deletedIds);
      _bulkSelectedIds.removeAll(deletedIds);
      if (_selectedActivity != null &&
          deletedIds.contains(_selectedActivity!.activity.id)) {
        _selectedActivity = null;
        _selectedEvidenceIndex = 0;
      }
    });
    if (deletedIds.isNotEmpty) {
      unawaited(_persistDismissedActivityIds());
    }
    ref.invalidate(pendingActivitiesProvider);
    final failed = ids.length - deleted;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          deleted == ids.length
              ? '$deleted actividades eliminadas'
              : deleted > 0
                  ? '$deleted eliminadas · $failed sin autorización o sin confirmación del servidor'
                  : 'No se pudo eliminar ninguna actividad',
        ),
        backgroundColor: deleted > 0 ? SaoColors.success : SaoColors.warning,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _removeActivityFromQueue(String activityId) async {
    final repo = ref.read(activityRepositoryProvider);
    await repo.deleteActivity(activityId);
  }

  List<String> _buildProjectOptions(
      List<String> projects, String selectedProjectId) {
    final normalized = <String>{
      for (final projectId in projects)
        if (projectId.trim().isNotEmpty) projectId.trim().toUpperCase(),
    };
    if (selectedProjectId.isNotEmpty) {
      normalized.add(selectedProjectId);
    }
    final result = normalized.toList()..sort();
    return result;
  }

  Future<void> _setProjectFilter(String projectId) async {
    final normalizedProjectId = projectId.trim().toUpperCase();
    final currentProjectId =
        ref.read(operationsProjectFilterProvider).trim().toUpperCase();
    if (normalizedProjectId == currentProjectId) return;
    ref.read(operationsProjectFilterProvider.notifier).state =
        normalizedProjectId;
    await _handleProjectScopeChanged(normalizedProjectId);
  }
}

class _OperationsHealthStrip extends StatelessWidget {
  final List<ActivityWithDetails> items;
  const _OperationsHealthStrip({required this.items});

  int _pending(List<ActivityWithDetails> values) {
    return values.where(isPendingQueueBucket).length;
  }

  int _observations(List<ActivityWithDetails> values) {
    return values.where(isChangesQueueBucket).length;
  }

  int _readyToApprove(List<ActivityWithDetails> values) {
    return values.where(isReadyToApproveQueueBucket).length;
  }

  @override
  Widget build(BuildContext context) {
    final pending = _pending(items);
    final observations = _observations(items);
    final readyToApprove = _readyToApprove(items);
    final withEvidence = items.where((a) => a.evidences.isNotEmpty).length;
    final withoutConflicts = items.where(isReadyToApproveQueueBucket).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: SaoColors.surfaceMutedFor(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SaoColors.borderFor(context)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: _OpsMiniPieChart(
              pending: pending,
              observations: observations,
              readyToApprove: readyToApprove,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _OpsSummaryChip(
                  color: SaoColors.actionPrimary,
                  label: 'Pendientes',
                  count: pending,
                ),
                _OpsSummaryChip(
                  color: const Color(0xFFD97706),
                  label: 'Con observaciones',
                  count: observations,
                ),
                _OpsSummaryChip(
                  color: SaoColors.success,
                  label: 'Listas para aprobar',
                  count: readyToApprove,
                ),
                _OpsSummaryChip(
                  color: SaoColors.gray600,
                  label: 'Total',
                  count: items.length,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 290,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _OpsCoverageBar(
                  label: 'Con evidencias',
                  value: '$withEvidence/${items.length}',
                  ratio: items.isEmpty ? 0 : withEvidence / items.length,
                  color: SaoColors.actionPrimary,
                ),
                const SizedBox(height: 6),
                _OpsCoverageBar(
                  label: 'Sin conflictos',
                  value: '$withoutConflicts/${items.length}',
                  ratio: items.isEmpty ? 0 : withoutConflicts / items.length,
                  color: const Color(0xFF7C3AED),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OpsSummaryChip extends StatelessWidget {
  final Color color;
  final String label;
  final int count;

  const _OpsSummaryChip({
    required this.color,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $count',
        style: SaoTypography.caption.copyWith(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _OpsMiniPieChart extends StatelessWidget {
  final int pending;
  final int observations;
  final int readyToApprove;

  const _OpsMiniPieChart({
    required this.pending,
    required this.observations,
    required this.readyToApprove,
  });

  @override
  Widget build(BuildContext context) {
    final total = pending + observations + readyToApprove;
    if (total == 0) {
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: SaoColors.borderFor(context)),
        ),
        child: Center(
          child: Text(
            '0',
            style: SaoTypography.caption.copyWith(
              color: SaoColors.textMutedFor(context),
            ),
          ),
        ),
      );
    }

    return CustomPaint(
      painter: _OpsPiePainter(
        segments: [
          _OpsPieSegment(
              value: pending / total, color: SaoColors.actionPrimary),
          _OpsPieSegment(
              value: observations / total, color: const Color(0xFFD97706)),
          _OpsPieSegment(
              value: readyToApprove / total, color: SaoColors.success),
        ],
      ),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: SaoColors.surfaceFor(context),
            ),
          ),
        ),
      ),
    );
  }
}

class _OpsPieSegment {
  final double value;
  final Color color;
  const _OpsPieSegment({required this.value, required this.color});
}

class _OpsPiePainter extends CustomPainter {
  final List<_OpsPieSegment> segments;
  const _OpsPiePainter({required this.segments});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.butt;

    double start = -1.57079632679;
    for (final segment in segments) {
      if (segment.value <= 0) continue;
      stroke.color = segment.color;
      final sweep = 6.28318530718 * segment.value;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: size.shortestSide / 2 - 5),
        start,
        sweep,
        false,
        stroke,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _OpsPiePainter oldDelegate) {
    if (oldDelegate.segments.length != segments.length) return true;
    for (var i = 0; i < segments.length; i++) {
      if (segments[i].value != oldDelegate.segments[i].value ||
          segments[i].color != oldDelegate.segments[i].color) {
        return true;
      }
    }
    return false;
  }
}

class _OpsCoverageBar extends StatelessWidget {
  final String label;
  final String value;
  final double ratio;
  final Color color;

  const _OpsCoverageBar({
    required this.label,
    required this.value,
    required this.ratio,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: SaoTypography.caption.copyWith(
                  fontSize: 11,
                  color: SaoColors.gray600,
                ),
              ),
            ),
            Text(
              value,
              style: SaoTypography.caption.copyWith(
                fontSize: 11,
                color: SaoColors.gray700,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: ratio.clamp(0, 1),
            minHeight: 6,
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BULK ACTION BAR
// ─────────────────────────────────────────────────────────────────────────────

class _BulkActionBar extends StatelessWidget {
  final int selectedCount;
  final List<ActivityWithDetails> visibleActivities;
  final Set<String> bulkSelectedIds;
  final bool canDeleteAll;
  final VoidCallback onClear;
  final VoidCallback onApproveAll;
  final VoidCallback onDeleteAll;

  const _BulkActionBar({
    required this.selectedCount,
    required this.visibleActivities,
    required this.bulkSelectedIds,
    required this.canDeleteAll,
    required this.onClear,
    required this.onApproveAll,
    required this.onDeleteAll,
  });

  @override
  Widget build(BuildContext context) {
    // Count clean (no-conflict) selected
    final cleanCount = visibleActivities
        .where((a) =>
            bulkSelectedIds.contains(a.activity.id) &&
            !a.flags.catalogChanged &&
            !a.flags.checklistIncomplete)
        .length;

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: SaoSpacing.lg, vertical: SaoSpacing.sm),
      decoration: BoxDecoration(
        color: SaoColors.primary.withValues(alpha: 0.04),
        border: const Border(
          bottom: BorderSide(color: SaoColors.border),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_box_rounded,
              size: 16, color: SaoColors.primary),
          const SizedBox(width: SaoSpacing.sm),
          Text(
            '$selectedCount seleccionadas',
            style: SaoTypography.bodyText.copyWith(
              color: SaoColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (cleanCount > 0) ...[
            const SizedBox(width: SaoSpacing.xs),
            Text(
              '($cleanCount sin conflictos)',
              style: SaoTypography.caption.copyWith(
                color: SaoColors.gray500,
              ),
            ),
          ],
          const Spacer(),
          TextButton(
            onPressed: onClear,
            child: const Text('Cancelar selección'),
          ),
          if (canDeleteAll) ...[
            const SizedBox(width: SaoSpacing.sm),
            FilledButton.icon(
              onPressed: onDeleteAll,
              style: FilledButton.styleFrom(
                backgroundColor: SaoColors.error,
                padding: const EdgeInsets.symmetric(
                    horizontal: SaoSpacing.lg, vertical: SaoSpacing.sm),
              ),
              icon: const Icon(Icons.delete_outline_rounded, size: 16),
              label: const Text('Eliminar selección'),
            ),
          ],
          const SizedBox(width: SaoSpacing.sm),
          if (cleanCount > 0)
            FilledButton.icon(
              onPressed: onApproveAll,
              style: FilledButton.styleFrom(
                backgroundColor: SaoColors.success,
                padding: const EdgeInsets.symmetric(
                    horizontal: SaoSpacing.lg, vertical: SaoSpacing.sm),
              ),
              icon: const Icon(Icons.check_circle_rounded, size: 16),
              label: Text('Aprobar $cleanCount sin conflictos'),
            )
          else
            Tooltip(
              message:
                  'Todas las seleccionadas tienen conflictos que requieren revisión manual',
              child: FilledButton.icon(
                onPressed: null,
                style: FilledButton.styleFrom(
                  backgroundColor: SaoColors.gray300,
                ),
                icon: const Icon(Icons.check_circle_rounded, size: 16),
                label: const Text('Aprobar selección'),
              ),
            ),
        ],
      ),
    );
  }
}

final operationsProjectFilterProvider = StateProvider<String>((ref) => '');

final pendingActivitiesProvider =
    StreamProvider<List<ActivityWithDetails>>((ref) {
  final repo = ref.watch(activityRepositoryProvider);
  final projectId =
      ref.watch(operationsProjectFilterProvider).trim().toUpperCase();
  return repo.watchPendingReview(
    projectId: projectId.isEmpty ? null : projectId,
  );
});

/// Campo de selección de fecha con botón de limpiar
class _DatePickerField extends StatelessWidget {
  final DateTime? value;
  final String hint;
  final ValueChanged<DateTime> onPicked;
  final VoidCallback onCleared;

  const _DatePickerField({
    required this.value,
    required this.hint,
    required this.onPicked,
    required this.onCleared,
  });

  @override
  Widget build(BuildContext context) {
    final label = value == null
        ? hint
        : '${value!.day.toString().padLeft(2, '0')}/${value!.month.toString().padLeft(2, '0')}/${value!.year}';

    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (picked != null) onPicked(picked);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: SaoColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded,
                size: 16, color: SaoColors.gray600),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: SaoTypography.bodyText.copyWith(
                  color: value == null ? SaoColors.gray400 : SaoColors.gray900,
                ),
              ),
            ),
            if (value != null)
              GestureDetector(
                onTap: onCleared,
                child: const Icon(Icons.close_rounded,
                    size: 16, color: SaoColors.gray400),
              ),
          ],
        ),
      ),
    );
  }
}
