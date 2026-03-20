import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/activity_model.dart';
import '../../../ui/theme/sao_colors.dart';
import '../../../ui/theme/sao_spacing.dart';
import '../../../ui/theme/sao_radii.dart';
import '../../../ui/theme/sao_typography.dart';
import '../../../data/catalog/activity_status.dart';
import '../../../catalog/risk_catalog.dart';
import '../../../catalog/status_catalog.dart';

/// Panel de cola de actividades — lista compacta para poder-usuario.
///
/// Rediseño UX v2:
/// - Filas compactas (~54px) en lugar de tarjetas grandes
/// - Punto de color para prioridad (rojo/amarillo/verde)
/// - Icono ▲ de conflicto si tiene GPS / catálogo / checklist issue
/// - Checkbox de selección masiva (aparece en hover o modo bulk)
/// - Agrupación por frentes colapsables
class ActivityQueuePanel extends StatefulWidget {
  final AsyncValue<List<ActivityWithDetails>> activitiesAsync;
  final ActivityWithDetails? selectedActivity;
  final Function(ActivityWithDetails) onSelectActivity;
  final String? searchQuery;
  final bool filterPending;
  final bool filterRejected;
  final bool filterChanges;
  final bool filterOnlyConflicts;
  final String queueTab;
  final ValueChanged<String>? onQueueTabChanged;
  final ValueChanged<List<ActivityWithDetails>>? onVisibleActivitiesChanged;
  final String? filterFront;
  final DateTime? filterDateFrom;
  final DateTime? filterDateTo;
  // Bulk selection
  final Set<String> bulkSelectedIds;
  final ValueChanged<String> onBulkToggle;
  final VoidCallback onBulkSelectAll;
  final VoidCallback onBulkClear;

  const ActivityQueuePanel({
    super.key,
    required this.activitiesAsync,
    required this.selectedActivity,
    required this.onSelectActivity,
    this.searchQuery,
    this.filterPending = false,
    this.filterRejected = false,
    this.filterChanges = false,
    this.filterOnlyConflicts = false,
    this.queueTab = 'PENDING',
    this.onQueueTabChanged,
    this.onVisibleActivitiesChanged,
    this.filterFront,
    this.filterDateFrom,
    this.filterDateTo,
    this.bulkSelectedIds = const {},
    required this.onBulkToggle,
    required this.onBulkSelectAll,
    required this.onBulkClear,
  });

  @override
  State<ActivityQueuePanel> createState() => _ActivityQueuePanelState();
}

class _ActivityQueuePanelState extends State<ActivityQueuePanel> {
  final Set<String> _collapsedFronts = {};

  Map<String, List<ActivityWithDetails>> _groupByFront(
    List<ActivityWithDetails> activities,
  ) {
    final Map<String, List<ActivityWithDetails>> grouped = {};
    for (final activity in activities) {
      final frontName = activity.front?.name ?? 'Sin asignar';
      grouped.putIfAbsent(frontName, () => []).add(activity);
    }
    return grouped;
  }

  List<ActivityWithDetails> _filterActivities(
    List<ActivityWithDetails> activities,
  ) {
    var filtered = activities;

    if (widget.searchQuery != null && widget.searchQuery!.isNotEmpty) {
      final query = widget.searchQuery!.toLowerCase();
      filtered = filtered.where((activity) {
        final searchableText = [
          activity.activity.id,
          activity.activity.title,
          activity.front?.name ?? '',
          activity.municipality?.name ?? '',
          activity.activityType?.name ?? '',
        ].join(' ').toLowerCase();
        return searchableText.contains(query);
      }).toList();
    }

    filtered = filtered.where((activity) {
      final status = _deriveStatus(activity);
      final hasGpsConflict = activity.flags.gpsMismatch;
      final hasCatalogChange = activity.flags.catalogChanged;
      final hasChecklistIncomplete = activity.flags.checklistIncomplete;

      switch (widget.queueTab) {
        case 'ALL':
          return true;
        case 'PENDING':
          return status == ActivityStatus.pendingReview;
        case 'CHANGED':
          return status == ActivityStatus.conflict ||
              hasCatalogChange ||
              hasChecklistIncomplete;
        case 'REJECTED':
          return status == ActivityStatus.rejected;
        default:
          return true;
      }
    }).toList();

    if (widget.filterPending ||
        widget.filterRejected ||
        widget.filterChanges) {
      filtered = filtered.where((activity) {
        final status = _deriveStatus(activity);
        if (widget.filterPending &&
            status == ActivityStatus.pendingReview) return true;
        if (widget.filterRejected &&
            status == ActivityStatus.rejected) return true;
        if (widget.filterChanges &&
            (status == ActivityStatus.conflict ||
                activity.flags.catalogChanged ||
                activity.flags.checklistIncomplete)) return true;
        return false;
      }).toList();
    }

    // "Solo conflictos" — oculta lo que no requiere decisión
    if (widget.filterOnlyConflicts) {
      filtered = filtered.where((activity) {
        return activity.flags.catalogChanged ||
            activity.flags.checklistIncomplete ||
            _deriveStatus(activity) == ActivityStatus.conflict ||
            _deriveStatus(activity) == ActivityStatus.rejected;
      }).toList();
    }

    if (widget.filterFront != null && widget.filterFront!.isNotEmpty) {
      filtered = filtered
          .where((a) =>
              (a.front?.name ?? 'Sin asignar') == widget.filterFront)
          .toList();
    }

    if (widget.filterDateFrom != null) {
      final from = widget.filterDateFrom!;
      filtered = filtered
          .where((a) => !a.activity.createdAt.isBefore(from))
          .toList();
    }
    if (widget.filterDateTo != null) {
      final to = widget.filterDateTo!.add(const Duration(days: 1));
      filtered =
          filtered.where((a) => a.activity.createdAt.isBefore(to)).toList();
    }

    return filtered;
  }

  Map<String, int> _buildTabCounters(List<ActivityWithDetails> activities) {
    final counters = <String, int>{
      'ALL': activities.length,
      'PENDING': 0,
      'CHANGED': 0,
      'REJECTED': 0,
    };
    for (final activity in activities) {
      final status = _deriveStatus(activity);
      if (status == ActivityStatus.pendingReview) {
        counters['PENDING'] = (counters['PENDING'] ?? 0) + 1;
      }
      if (status == ActivityStatus.conflict ||
          activity.flags.catalogChanged ||
          activity.flags.checklistIncomplete) {
        counters['CHANGED'] = (counters['CHANGED'] ?? 0) + 1;
      }
      if (status == ActivityStatus.rejected) {
        counters['REJECTED'] = (counters['REJECTED'] ?? 0) + 1;
      }
    }
    return counters;
  }

  Color _getRiskColor(ActivityWithDetails activity) =>
      _deriveRisk(activity).color;

  RiskLevel _deriveRisk(ActivityWithDetails activity) {
    final description = (activity.activity.description ?? '').toLowerCase();
    if (description.contains('prioritario') ||
        description.contains('crítico')) return RiskCatalog.prioritario;
    if (description.contains('alto')) return RiskCatalog.alto;
    if (description.contains('medio')) return RiskCatalog.medio;
    if (description.contains('bajo')) return RiskCatalog.bajo;

    final status = ActivityStatus.normalize(_deriveStatus(activity));
    switch (status) {
      case ActivityStatus.rejected:
      case ActivityStatus.conflict:
      case ActivityStatus.needsFix:
        return RiskCatalog.prioritario;
      case ActivityStatus.pendingReview:
        return RiskCatalog.alto;
      case ActivityStatus.corrected:
        return RiskCatalog.medio;
      case ActivityStatus.approved:
        return RiskCatalog.bajo;
      default:
        return RiskCatalog.medio;
    }
  }

  String _deriveStatus(ActivityWithDetails activity) {
    final description =
        (activity.activity.description ?? '').trim().toLowerCase();
    if (description.contains('rechazada') ||
        description.contains('rechazado')) return ActivityStatus.rejected;
    if (description.contains('corregida') ||
        description.contains('corregido')) return ActivityStatus.corrected;
    if (description.contains('necesita') ||
        description.contains('falta')) return ActivityStatus.needsFix;
    if (description.contains('cambios') ||
        description.contains('discrepancia')) return ActivityStatus.conflict;
    if (activity.flags.checklistIncomplete) return ActivityStatus.conflict;
    if (description.contains('aprobada') ||
        description.contains('aprobado')) return ActivityStatus.approved;
    return activity.activity.status;
  }

  @override
  Widget build(BuildContext context) {
    final hasBulkMode = widget.bulkSelectedIds.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: SaoColors.surface,
        borderRadius: BorderRadius.circular(SaoRadii.lg),
        border: Border.all(color: SaoColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
                SaoSpacing.lg, SaoSpacing.md, SaoSpacing.sm, SaoSpacing.sm),
            child: Row(
              children: [
                const Icon(Icons.pending_actions_rounded,
                    size: 18, color: SaoColors.primary),
                const SizedBox(width: SaoSpacing.sm),
                const Expanded(
                  child: Text('Cola de Revisión',
                      style: SaoTypography.sectionTitle),
                ),
                // Bulk action buttons
                if (hasBulkMode) ...[
                  Text(
                    '${widget.bulkSelectedIds.length} sel.',
                    style: SaoTypography.caption.copyWith(
                      color: SaoColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: SaoSpacing.xs),
                  IconButton(
                    icon: const Icon(Icons.deselect_rounded, size: 16),
                    tooltip: 'Deseleccionar todo',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                        minWidth: 28, minHeight: 28),
                    onPressed: widget.onBulkClear,
                  ),
                ] else ...[
                  widget.activitiesAsync.when(
                    data: (activities) {
                      final filtered = _filterActivities(activities);
                      return _CountBadge(count: filtered.length);
                    },
                    loading: () => const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    error: (_, __) => const Icon(Icons.error_outline, size: 16),
                  ),
                ],
              ],
            ),
          ),

          // ── Tab pills ────────────────────────────────────────────
          widget.activitiesAsync.when(
            data: (activities) {
              final counters = _buildTabCounters(activities);
              final tabs = const <(String, String)>[
                ('PENDING', 'Pendientes'),
                ('CHANGED', 'Cambios'),
                ('REJECTED', 'Rechazadas'),
                ('ALL', 'Todas'),
              ];
              return SizedBox(
                height: 36,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                      horizontal: SaoSpacing.md),
                  scrollDirection: Axis.horizontal,
                  itemCount: tabs.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: SaoSpacing.xxs),
                  itemBuilder: (context, index) {
                    final tab = tabs[index];
                    final selected = widget.queueTab == tab.$1;
                    final count = counters[tab.$1] ?? 0;
                    return _TabPill(
                      label: tab.$2,
                      count: count,
                      selected: selected,
                      onTap: () =>
                          widget.onQueueTabChanged?.call(tab.$1),
                    );
                  },
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          const Divider(height: 1),

          // ── "Select all" header when bulk mode ──────────────────
          if (hasBulkMode)
            _BulkSelectHeader(
              selectedCount: widget.bulkSelectedIds.length,
              onSelectAll: widget.onBulkSelectAll,
              onClear: widget.onBulkClear,
            ),

          // ── Lista agrupada ───────────────────────────────────────
          Expanded(
            child: widget.activitiesAsync.when(
              data: (activities) {
                final filtered = _filterActivities(activities);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  widget.onVisibleActivitiesChanged?.call(filtered);
                });

                if (filtered.isEmpty) return _buildEmptyState();

                final grouped = _groupByFront(filtered);
                return ListView.builder(
                  padding:
                      const EdgeInsets.only(bottom: SaoSpacing.md),
                  itemCount: grouped.length,
                  itemBuilder: (context, index) {
                    final frontName = grouped.keys.elementAt(index);
                    final frontActivities = grouped[frontName]!;
                    final isCollapsed =
                        _collapsedFronts.contains(frontName);

                    return _FrontSection(
                      frontName: frontName,
                      activities: frontActivities,
                      selectedActivity: widget.selectedActivity,
                      isCollapsed: isCollapsed,
                      hasBulkMode: hasBulkMode,
                      bulkSelectedIds: widget.bulkSelectedIds,
                      onToggleCollapse: () => setState(() {
                        if (isCollapsed) {
                          _collapsedFronts.remove(frontName);
                        } else {
                          _collapsedFronts.add(frontName);
                        }
                      }),
                      onSelectActivity: widget.onSelectActivity,
                      onBulkToggle: widget.onBulkToggle,
                      getRiskColor: _getRiskColor,
                      deriveRisk: _deriveRisk,
                      deriveStatus: _deriveStatus,
                    );
                  },
                );
              },
              loading: () => _buildLoadingState(),
              error: (error, __) => _buildErrorState(error.toString()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final hasSearch = widget.searchQuery?.isNotEmpty == true;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SaoSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasSearch
                  ? Icons.search_off_rounded
                  : Icons.inbox_rounded,
              size: 40,
              color: SaoColors.gray300,
            ),
            const SizedBox(height: SaoSpacing.md),
            Text(
              hasSearch
                  ? 'Sin resultados'
                  : 'Sin actividades pendientes',
              style: SaoTypography.bodyText
                  .copyWith(color: SaoColors.gray500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() => const Center(
        child: Padding(
          padding: EdgeInsets.all(SaoSpacing.xl),
          child: CircularProgressIndicator(),
        ),
      );

  Widget _buildErrorState(String error) => Center(
        child: Padding(
          padding: const EdgeInsets.all(SaoSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 36, color: SaoColors.error),
              const SizedBox(height: SaoSpacing.sm),
              Text(error,
                  style: SaoTypography.caption
                      .copyWith(color: SaoColors.gray600),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// SECCIÓN DE FRENTE (colapsable)
// ─────────────────────────────────────────────────────────────────────────────

class _FrontSection extends StatelessWidget {
  final String frontName;
  final List<ActivityWithDetails> activities;
  final ActivityWithDetails? selectedActivity;
  final bool isCollapsed;
  final bool hasBulkMode;
  final Set<String> bulkSelectedIds;
  final VoidCallback onToggleCollapse;
  final Function(ActivityWithDetails) onSelectActivity;
  final ValueChanged<String> onBulkToggle;
  final Color Function(ActivityWithDetails) getRiskColor;
  final RiskLevel Function(ActivityWithDetails) deriveRisk;
  final String Function(ActivityWithDetails) deriveStatus;

  const _FrontSection({
    required this.frontName,
    required this.activities,
    required this.selectedActivity,
    required this.isCollapsed,
    required this.hasBulkMode,
    required this.bulkSelectedIds,
    required this.onToggleCollapse,
    required this.onSelectActivity,
    required this.onBulkToggle,
    required this.getRiskColor,
    required this.deriveRisk,
    required this.deriveStatus,
  });

  String _pkLabel(ActivityWithDetails activity) {
    // pkLabel is explicitly set from backend data
    final pk = activity.pkLabel?.trim() ?? '';
    if (pk.isNotEmpty) return pk;
    // Fallback: scan title + description for any PK pattern
    final text =
        '${activity.activity.title} ${activity.activity.description ?? ''}';
    final rangeMatch =
        RegExp(r'PK\s*\d+[+]?\d*\s*[\-–]\s*\d+[+]?\d*', caseSensitive: false)
            .firstMatch(text);
    if (rangeMatch != null) return rangeMatch.group(0)!.replaceAll(RegExp(r'\s+'), ' ');
    final singleMatch =
        RegExp(r'PK\s*\d+', caseSensitive: false).firstMatch(text);
    if (singleMatch != null) return singleMatch.group(0)!.replaceAll(RegExp(r'\s+'), ' ');
    return 'Sin PK';
  }

  String _relativeTime(DateTime when) {
    final diff = DateTime.now().difference(when);
    if (diff.inMinutes < 1) return 'ahora';
    if (diff.inHours < 1) return 'hace ${diff.inMinutes} min';
    if (diff.inDays < 1) return 'hace ${diff.inHours} h';
    return 'hace ${diff.inDays} d';
  }

  int _conflictCount(ActivityWithDetails activity) {
    int c = 0;
    if (activity.flags.catalogChanged) c++;
    if (activity.flags.checklistIncomplete) c++;
    final st = ActivityStatus.normalize(deriveStatus(activity));
    if (st == ActivityStatus.rejected || st == ActivityStatus.conflict) c++;
    return c;
  }

  @override
  Widget build(BuildContext context) {
    // Count pending vs conflict in this front
    final totalConflicts = activities
        .where((a) => _conflictCount(a) > 0)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Front header ─────────────────────────────────────────
        InkWell(
          onTap: onToggleCollapse,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: SaoSpacing.md, vertical: SaoSpacing.xs),
            color: SaoColors.gray50,
            child: Row(
              children: [
                Icon(
                  isCollapsed
                      ? Icons.chevron_right_rounded
                      : Icons.expand_more_rounded,
                  size: 16,
                  color: SaoColors.gray500,
                ),
                const SizedBox(width: SaoSpacing.xs),
                Expanded(
                  child: Text(
                    frontName,
                    style: SaoTypography.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: SaoColors.gray700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                if (totalConflicts > 0) ...[
                  const Icon(Icons.warning_rounded,
                      size: 12, color: SaoColors.warning),
                  const SizedBox(width: 3),
                  Text(
                    '$totalConflicts',
                    style: SaoTypography.caption.copyWith(
                      color: SaoColors.warning,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: SaoSpacing.sm),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: SaoSpacing.xs, vertical: 2),
                  decoration: BoxDecoration(
                    color: SaoColors.gray200,
                    borderRadius:
                        BorderRadius.circular(SaoRadii.full),
                  ),
                  child: Text(
                    '${activities.length}',
                    style: SaoTypography.caption.copyWith(
                      color: SaoColors.gray600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Activity rows ────────────────────────────────────────
        if (!isCollapsed)
          ...activities.map((activity) {
            final isSelected =
                selectedActivity?.activity.id == activity.activity.id;
            final isBulkChecked =
                bulkSelectedIds.contains(activity.activity.id);
            final risk = deriveRisk(activity);
            final conflicts = _conflictCount(activity);
            final actor = activity.assignedUser?.fullName ??
                activity.activity.assignedTo;
            final pk = _pkLabel(activity);
            final eventTime =
                activity.activity.executedAt ?? activity.activity.createdAt;

            return _CompactQueueItem(
              key: ValueKey(activity.activity.id),
              activity: activity,
              isSelected: isSelected,
              isBulkChecked: isBulkChecked,
              hasBulkMode: hasBulkMode,
              risk: risk,
              conflictCount: conflicts,
              pkLabel: pk,
              actorName: actor,
              relativeTime: _relativeTime(eventTime),
              onTap: () => onSelectActivity(activity),
              onBulkToggle: (v) => onBulkToggle(activity.activity.id),
            );
          }),

        const Divider(height: 1, indent: SaoSpacing.md),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPACT QUEUE ITEM — el corazón del diseño power-user
// ─────────────────────────────────────────────────────────────────────────────

class _CompactQueueItem extends StatefulWidget {
  final ActivityWithDetails activity;
  final bool isSelected;
  final bool isBulkChecked;
  final bool hasBulkMode;
  final RiskLevel risk;
  final int conflictCount;
  final String pkLabel;
  final String actorName;
  final String relativeTime;
  final VoidCallback onTap;
  final ValueChanged<bool> onBulkToggle;

  const _CompactQueueItem({
    super.key,
    required this.activity,
    required this.isSelected,
    required this.isBulkChecked,
    required this.hasBulkMode,
    required this.risk,
    required this.conflictCount,
    required this.pkLabel,
    required this.actorName,
    required this.relativeTime,
    required this.onTap,
    required this.onBulkToggle,
  });

  @override
  State<_CompactQueueItem> createState() => _CompactQueueItemState();
}

class _CompactQueueItemState extends State<_CompactQueueItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final riskColor = widget.risk.color;
    final hasConflict = widget.conflictCount > 0;
    final showCheckbox = widget.hasBulkMode || _hovered;
    final activityName =
        widget.activity.activityType?.name ?? widget.activity.activity.title;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? SaoColors.primary.withValues(alpha: 0.05)
                : _hovered
                    ? SaoColors.gray50
                    : SaoColors.surface,
            border: Border(
              left: BorderSide(
                color: widget.isSelected ? riskColor : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          padding: EdgeInsets.only(
            left: widget.isSelected ? SaoSpacing.md - 3 : SaoSpacing.md,
            right: SaoSpacing.sm,
            top: SaoSpacing.sm,
            bottom: SaoSpacing.sm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Priority dot ─────────────────────────────────
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: riskColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: SaoSpacing.xs),

              // ── Conflict warning icon ─────────────────────────
              SizedBox(
                width: 16,
                child: hasConflict
                    ? Tooltip(
                        message: '${widget.conflictCount} conflicto(s)',
                        child: const Icon(
                          Icons.warning_rounded,
                          size: 13,
                          color: SaoColors.warning,
                        ),
                      )
                    : null,
              ),

              // ── Bulk checkbox (animated) ──────────────────────
              AnimatedSize(
                duration: const Duration(milliseconds: 150),
                child: showCheckbox
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(width: SaoSpacing.xs),
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: Checkbox(
                              value: widget.isBulkChecked,
                              onChanged: (v) =>
                                  widget.onBulkToggle(v ?? false),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              activeColor: SaoColors.primary,
                            ),
                          ),
                          const SizedBox(width: SaoSpacing.xs),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),

              // ── Main content ──────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            activityName,
                            style: SaoTypography.bodyText.copyWith(
                              fontWeight: widget.isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: widget.isSelected
                                  ? SaoColors.primary
                                  : SaoColors.gray800,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: SaoSpacing.xs),
                        // PK badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: hasConflict
                                ? SaoColors.warning.withValues(alpha: 0.12)
                                : SaoColors.gray100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            widget.pkLabel,
                            style: SaoTypography.monoSmall.copyWith(
                              color: hasConflict
                                  ? SaoColors.warning
                                  : SaoColors.gray600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.actorName} · ${widget.relativeTime}',
                      style: SaoTypography.caption.copyWith(
                          color: SaoColors.gray400),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // ── Selected chevron ──────────────────────────────
              const SizedBox(width: SaoSpacing.xxs),
              if (widget.isSelected)
                const Icon(Icons.chevron_right_rounded,
                    size: 14, color: SaoColors.primary)
              else
                const SizedBox(width: 14),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

class _TabPill extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _TabPill({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        padding: const EdgeInsets.symmetric(
            horizontal: SaoSpacing.sm, vertical: SaoSpacing.xxs),
        decoration: BoxDecoration(
          color: selected ? SaoColors.primary : SaoColors.gray100,
          borderRadius: BorderRadius.circular(SaoRadii.full),
          border: Border.all(
            color: selected ? SaoColors.primary : SaoColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: SaoTypography.caption.copyWith(
                color: selected ? Colors.white : SaoColors.gray600,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.25)
                      : SaoColors.gray300,
                  borderRadius: BorderRadius.circular(SaoRadii.full),
                ),
                child: Text(
                  '$count',
                  style: SaoTypography.caption.copyWith(
                    color: selected ? Colors.white : SaoColors.gray700,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: SaoSpacing.sm, vertical: 3),
      decoration: BoxDecoration(
        color: count > 0
            ? SaoColors.statusPendiente.withValues(alpha: 0.15)
            : SaoColors.gray100,
        borderRadius: BorderRadius.circular(SaoRadii.full),
      ),
      child: Text(
        '$count',
        style: SaoTypography.caption.copyWith(
          color: count > 0 ? SaoColors.statusPendiente : SaoColors.gray500,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _BulkSelectHeader extends StatelessWidget {
  final int selectedCount;
  final VoidCallback onSelectAll;
  final VoidCallback onClear;

  const _BulkSelectHeader({
    required this.selectedCount,
    required this.onSelectAll,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: SaoSpacing.md, vertical: SaoSpacing.xs),
      color: SaoColors.primary.withValues(alpha: 0.05),
      child: Row(
        children: [
          Text(
            '$selectedCount seleccionadas',
            style: SaoTypography.caption.copyWith(
              color: SaoColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onSelectAll,
            child: Text(
              'Seleccionar todas',
              style: SaoTypography.caption.copyWith(
                color: SaoColors.info,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
