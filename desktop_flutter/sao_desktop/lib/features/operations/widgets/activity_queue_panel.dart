import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/activity_model.dart';
import '../../../ui/theme/sao_colors.dart';
import '../../../ui/theme/sao_spacing.dart';
import '../../../ui/theme/sao_radii.dart';
import '../../../ui/theme/sao_typography.dart';
import '../../../data/catalog/activity_status.dart';
import '../../../catalog/risk_catalog.dart';
import '../activity_queue_projection.dart';

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
      switch (widget.queueTab) {
        case 'ALL':
          return true;
        case 'PENDING':
          return isPendingQueueBucket(activity);
        case 'CHANGED':
          return isChangesQueueBucket(activity);
        case 'REJECTED':
          return isRejectedQueueBucket(activity);
        default:
          return true;
      }
    }).toList();

    if (widget.filterPending || widget.filterRejected || widget.filterChanges) {
      filtered = filtered.where((activity) {
        if (widget.filterPending && isPendingQueueBucket(activity)) {
          return true;
        }
        if (widget.filterRejected && isRejectedQueueBucket(activity)) {
          return true;
        }
        if (widget.filterChanges && isChangesQueueBucket(activity)) {
          return true;
        }
        return false;
      }).toList();
    }

    // "Solo conflictos" — oculta lo que no requiere decisión
    if (widget.filterOnlyConflicts) {
      filtered = filtered.where((activity) {
        return isChangesQueueBucket(activity) ||
            isRejectedQueueBucket(activity);
      }).toList();
    }

    if (widget.filterFront != null && widget.filterFront!.isNotEmpty) {
      filtered = filtered
          .where((a) => (a.front?.name ?? 'Sin asignar') == widget.filterFront)
          .toList();
    }

    if (widget.filterDateFrom != null) {
      final from = widget.filterDateFrom!;
      filtered =
          filtered.where((a) => !a.activity.createdAt.isBefore(from)).toList();
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
      if (isPendingQueueBucket(activity)) {
        counters['PENDING'] = (counters['PENDING'] ?? 0) + 1;
      }
      if (isChangesQueueBucket(activity)) {
        counters['CHANGED'] = (counters['CHANGED'] ?? 0) + 1;
      }
      if (isRejectedQueueBucket(activity)) {
        counters['REJECTED'] = (counters['REJECTED'] ?? 0) + 1;
      }
    }
    return counters;
  }

  Color _getRiskColor(ActivityWithDetails activity) =>
      _deriveRisk(activity).color;

  RiskLevel _deriveRisk(ActivityWithDetails activity) {
    return deriveActivityQueueRisk(activity);
  }

  String _deriveStatus(ActivityWithDetails activity) {
    return deriveActivityQueueStatus(activity);
  }

  @override
  Widget build(BuildContext context) {
    final hasBulkMode = widget.bulkSelectedIds.isNotEmpty;
    final surfaceColor = SaoColors.surfaceFor(context);
    final borderColor = SaoColors.borderFor(context);
    final textColor = SaoColors.textFor(context);

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(SaoRadii.lg),
        border: Border.all(color: borderColor),
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
                Icon(Icons.pending_actions_rounded,
                    size: 18, color: textColor),
                const SizedBox(width: SaoSpacing.sm),
                Expanded(
                  child: Text('Cola de Revisión',
                      style: SaoTypography.sectionTitle.copyWith(
                        color: textColor,
                      )),
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
                    constraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
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
              const tabs = <(String, String)>[
                ('PENDING', 'Pendientes'),
                ('CHANGED', 'Cambios'),
                ('REJECTED', 'Rechazadas'),
                ('ALL', 'Todas'),
              ];
              return SizedBox(
                height: 36,
                child: ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(horizontal: SaoSpacing.md),
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
                      onTap: () => widget.onQueueTabChanged?.call(tab.$1),
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
                  padding: const EdgeInsets.only(bottom: SaoSpacing.md),
                  itemCount: grouped.length,
                  itemBuilder: (context, index) {
                    final frontName = grouped.keys.elementAt(index);
                    final frontActivities = grouped[frontName]!;
                    final isCollapsed = _collapsedFronts.contains(frontName);

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
    final mutedTextColor = SaoColors.textMutedFor(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 140 || constraints.maxWidth < 130;
        final ultraCompact = constraints.maxHeight < 96 || constraints.maxWidth < 96;
        final iconSize = compact ? 24.0 : 40.0;
        final content = ultraCompact
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    hasSearch ? Icons.search_off_rounded : Icons.inbox_rounded,
                    size: 18,
                    color: mutedTextColor,
                  ),
                  const SizedBox(width: SaoSpacing.xs),
                  Flexible(
                    child: Text(
                      hasSearch ? 'Sin resultados' : 'Sin pendientes',
                      style: SaoTypography.caption.copyWith(color: mutedTextColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    hasSearch ? Icons.search_off_rounded : Icons.inbox_rounded,
                    size: iconSize,
                    color: mutedTextColor,
                  ),
                  SizedBox(height: compact ? SaoSpacing.xs : SaoSpacing.md),
                  Text(
                    hasSearch ? 'Sin resultados' : 'Sin actividades pendientes',
                    style: SaoTypography.bodyText.copyWith(color: mutedTextColor),
                    textAlign: TextAlign.center,
                    maxLines: compact ? 2 : 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              );

        return Center(
          child: Padding(
            padding: EdgeInsets.all(compact ? SaoSpacing.sm : SaoSpacing.xl),
            child: constraints.maxHeight.isFinite
                ? SingleChildScrollView(child: content)
                : content,
          ),
        );
      },
    );
  }

  Widget _buildLoadingState() => const Center(
        child: Padding(
          padding: EdgeInsets.all(SaoSpacing.xl),
          child: CircularProgressIndicator(),
        ),
      );

  Widget _buildErrorState(String error) => LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 140 || constraints.maxWidth < 130;
          final ultraCompact = constraints.maxHeight < 96 || constraints.maxWidth < 96;
          final content = ultraCompact
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        size: 18, color: SaoColors.error),
                    const SizedBox(width: SaoSpacing.xs),
                    Flexible(
                      child: Text(
                        'Error de carga',
                        style: SaoTypography.caption.copyWith(
                          color: SaoColors.textMutedFor(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: compact ? 24 : 36,
                      color: SaoColors.error,
                    ),
                    SizedBox(height: compact ? SaoSpacing.xs : SaoSpacing.sm),
                    Text(
                      error,
                      style: SaoTypography.caption.copyWith(
                        color: SaoColors.textMutedFor(context),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: compact ? 3 : 5,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                );

          return Center(
            child: Padding(
              padding: EdgeInsets.all(compact ? SaoSpacing.sm : SaoSpacing.xl),
              child: constraints.maxHeight.isFinite
                  ? SingleChildScrollView(child: content)
                  : content,
            ),
          );
        },
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
    if (rangeMatch != null)
      return rangeMatch.group(0)!.replaceAll(RegExp(r'\s+'), ' ');
    final singleMatch =
        RegExp(r'PK\s*\d+', caseSensitive: false).firstMatch(text);
    if (singleMatch != null)
      return singleMatch.group(0)!.replaceAll(RegExp(r'\s+'), ' ');
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
    final totalConflicts =
        activities.where((a) => _conflictCount(a) > 0).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Front header ─────────────────────────────────────────
        InkWell(
          onTap: onToggleCollapse,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: SaoSpacing.md, vertical: SaoSpacing.xs),
            color: SaoColors.surfaceMutedFor(context),
            child: Row(
              children: [
                Icon(
                  isCollapsed
                      ? Icons.chevron_right_rounded
                      : Icons.expand_more_rounded,
                  size: 16,
                  color: SaoColors.textMutedFor(context),
                ),
                const SizedBox(width: SaoSpacing.xs),
                Expanded(
                  child: Text(
                    frontName,
                    style: SaoTypography.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: SaoColors.textFor(context),
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
                    color: SaoColors.surfaceRaisedFor(context),
                    borderRadius: BorderRadius.circular(SaoRadii.full),
                  ),
                  child: Text(
                    '${activities.length}',
                    style: SaoTypography.caption.copyWith(
                      color: SaoColors.textMutedFor(context),
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
            final actor =
                activity.assignedUser?.fullName ?? activity.activity.assignedTo;
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
                ? Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.10)
                : _hovered
                    ? SaoColors.surfaceMutedFor(context)
                    : SaoColors.surfaceFor(context),
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
                              onChanged: (v) => widget.onBulkToggle(v ?? false),
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
                                  ? Theme.of(context).colorScheme.primary
                                  : SaoColors.textFor(context),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: SaoSpacing.xs),
                        // PK badge
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: hasConflict
                                  ? SaoColors.warning.withValues(alpha: 0.12)
                                  : SaoColors.surfaceRaisedFor(context),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              widget.pkLabel,
                              style: SaoTypography.monoSmall.copyWith(
                                color: hasConflict
                                    ? SaoColors.warning
                                    : SaoColors.textMutedFor(context),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.actorName} · ${widget.relativeTime}',
                      style: SaoTypography.caption
                          .copyWith(color: SaoColors.textMutedFor(context)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // ── Selected chevron ──────────────────────────────
              const SizedBox(width: SaoSpacing.xxs),
              if (widget.isSelected)
                Icon(Icons.chevron_right_rounded,
                    size: 14, color: Theme.of(context).colorScheme.primary)
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
    final accent = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        padding: const EdgeInsets.symmetric(
            horizontal: SaoSpacing.sm, vertical: SaoSpacing.xxs),
        decoration: BoxDecoration(
          color: selected ? accent : SaoColors.surfaceRaisedFor(context),
          borderRadius: BorderRadius.circular(SaoRadii.full),
          border: Border.all(
            color: selected ? accent : SaoColors.borderFor(context),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: SaoTypography.caption.copyWith(
                color: selected
                    ? Theme.of(context).colorScheme.onPrimary
                    : SaoColors.textMutedFor(context),
                fontWeight: FontWeight.w600,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? Theme.of(context)
                          .colorScheme
                          .onPrimary
                          .withValues(alpha: 0.22)
                      : SaoColors.borderFor(context),
                  borderRadius: BorderRadius.circular(SaoRadii.full),
                ),
                child: Text(
                  '$count',
                  style: SaoTypography.caption.copyWith(
                    color: selected
                        ? Theme.of(context).colorScheme.onPrimary
                        : SaoColors.textFor(context),
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
      padding:
          const EdgeInsets.symmetric(horizontal: SaoSpacing.sm, vertical: 3),
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
