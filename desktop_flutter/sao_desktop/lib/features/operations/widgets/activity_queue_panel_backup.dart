import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../data/models/activity_model.dart';
import '../../../ui/theme/sao_colors.dart';
import '../../../ui/theme/sao_spacing.dart';
import '../../../ui/theme/sao_radii.dart';
import '../../../ui/theme/sao_typography.dart';
import '../../../ui/widgets/sao_activity_card.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';

/// Panel de cola de actividades con agrupación por frentes
/// 
/// Rediseño UX:
/// - Tarjetas completas (SaoActivityCard) en lugar de lista simple
/// - Agrupación por frentes con headers colapsables
/// - Franja de color según riesgo/estado
/// - PK badge visible en cada tarjeta
/// - Contadores de pendientes por frente
class ActivityQueuePanel extends StatefulWidget {
  final AsyncValue<List<ActivityWithDetails>> activitiesAsync;
  final ActivityWithDetails? selectedActivity;
  final Function(ActivityWithDetails) onSelectActivity;
  final String? searchQuery;

  const ActivityQueuePanel({
    super.key,
    required this.activitiesAsync,
    required this.selectedActivity,
    required this.onSelectActivity,
    this.searchQuery,
  });

  @override
  State<ActivityQueuePanel> createState() => _ActivityQueuePanelState();
}

class _ActivityQueuePanelState extends State<ActivityQueuePanel> {
  final Set<String> _collapsedFronts = {};

  /// Agrupa actividades por frente
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

  /// Filtra actividades según búsqueda
  List<ActivityWithDetails> _filterActivities(
    List<ActivityWithDetails> activities,
  ) {
    if (widget.searchQuery == null || widget.searchQuery!.isEmpty) {
      return activities;
    }

    final query = widget.searchQuery!.toLowerCase();

    return activities.where((activity) {
      final searchableText = [
        activity.activity.id,
        activity.activity.title,
        activity.front?.name ?? '',
        activity.municipality?.name ?? '',
        activity.activityType?.name ?? '',
        'pk', // Placeholder para búsqueda de PK
      ].join(' ').toLowerCase();

      return searchableText.contains(query);
    }).toList();
  }

  Color _getRiskColor(ActivityWithDetails activity) {
    // TODO: Implementar lógica real de riesgo basada en datos
    // Por ahora usamos estado como proxy
    switch (activity.activity.status) {
      case 'pending_review':
        return SaoColors.statusPendiente;
      case 'approved':
        return SaoColors.success;
      case 'rejected':
        return SaoColors.error;
      case 'needs_fix':
        return SaoColors.warning;
      default:
        return SaoColors.info;
    }
  }

  Color _getRiskColor(ActivityWithDetails activity) {
    // TODO: Implementar lógica real de riesgo basada en datos
    // Por ahora usamos estado como proxy
    switch (activity.activity.status) {
      case 'pending_review':
        return SaoColors.statusPendiente;
      case 'approved':
        return SaoColors.success;
      case 'rejected':
        return SaoColors.error;
      case 'needs_fix':
        return SaoColors.warning;
      default:
        return SaoColors.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: SaoColors.surface,
        borderRadius: BorderRadius.circular(SaoRadii.lg),
        border: Border.all(color: SaoColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: EdgeInsets.all(SaoSpacing.lg),
            child: Row(
              children: [
                Icon(
                  Icons.pending_actions_rounded,
                  size: 20,
                  color: SaoColors.primary,
                ),
                SizedBox(width: SaoSpacing.sm),
                Text(
                  'Cola de Revisión',
                  style: SaoTypography.h3,
                ),
                const Spacer(),
                widget.activitiesAsync.when(
                  data: (activities) {
                    final filtered = _filterActivities(activities);
                    return Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: SaoSpacing.sm,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: SaoColors.statusPendiente.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(SaoRadii.sm),
                      ),
                      child: Text(
                        '${filtered.length}',
                        style: SaoTypography.caption.copyWith(
                          color: SaoColors.statusPendiente,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: SaoColors.border),

          // Lista de actividades agrupadas
          Expanded(
            child: widget.activitiesAsync.when(
              data: (activities) {
                final filtered = _filterActivities(activities);

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          size: 64,
                          color: SaoColors.success.withOpacity(0.3),
                        ),
                        SizedBox(height: SaoSpacing.lg),
                        Text(
                          widget.searchQuery != null && widget.searchQuery!.isNotEmpty
                              ? 'No se encontraron\nresultados'
                              : 'No hay actividades\npendientes',
                          textAlign: TextAlign.center,
                          style: SaoTypography.body.copyWith(
                            color: SaoColors.gray500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final grouped = _groupByFront(filtered);
                final frontNames = grouped.keys.toList()..sort();

                return ListView.builder(
                  padding: EdgeInsets.all(SaoSpacing.md),
                  itemCount: frontNames.length,
                  itemBuilder: (context, index) {
                    final frontName = frontNames[index];
                    final frontActivities = grouped[frontName]!;
                    final isCollapsed = _collapsedFronts.contains(frontName);

                    return _FrontSection(
                      frontName: frontName,
                      activities: frontActivities,
                      isCollapsed: isCollapsed,
                      selectedActivity: widget.selectedActivity,
                      onToggleCollapse: () {
                        setState(() {
                          if (isCollapsed) {
                            _collapsedFronts.remove(frontName);
                          } else {
                            _collapsedFronts.add(frontName);
                          }
                        });
                      },
                      onSelectActivity: widget.onSelectActivity,
                      getRiskColor: _getRiskColor,
                    );
                  },
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 64,
                      color: SaoColors.error.withOpacity(0.3),
                    ),
                    SizedBox(height: SaoSpacing.lg),
                    Text(
                      'Error al cargar',
                      style: SaoTypography.body.copyWith(
                        color: SaoColors.error,
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

/// Widget para mostrar una sección de frente con actividades
class _FrontSection extends StatelessWidget {
  final String frontName;
  final List<ActivityWithDetails> activities;
  final bool isCollapsed;
  final ActivityWithDetails? selectedActivity;
  final VoidCallback onToggleCollapse;
  final Function(ActivityWithDetails) onSelectActivity;
  final Color Function(ActivityWithDetails) getRiskColor;

  const _FrontSection({
    required this.frontName,
    required this.activities,
    required this.isCollapsed,
    required this.selectedActivity,
    required this.onToggleCollapse,
    required this.onSelectActivity,
    required this.getRiskColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header del frente (colapsable)
        InkWell(
          onTap: onToggleCollapse,
          borderRadius: BorderRadius.circular(SaoRadii.sm),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: SaoSpacing.sm,
              vertical: SaoSpacing.sm,
            ),
            child: Row(
              children: [
                Icon(
                  isCollapsed
                      ? Icons.chevron_right_rounded
                      : Icons.expand_more_rounded,
                  size: 20,
                  color: SaoColors.gray600,
                ),
                SizedBox(width: SaoSpacing.xs),
                Expanded(
                  child: Text(
                    'Frente: $frontName',
                    style: SaoTypography.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: SaoColors.gray700,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: SaoSpacing.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: SaoColors.gray100,
                    borderRadius: BorderRadius.circular(SaoRadii.full),
                  ),
                  child: Text(
                    '${activities.length} Pendiente${activities.length != 1 ? 's' : ''}',
                    style: SaoTypography.caption.copyWith(
                      color: SaoColors.gray600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Lista de tarjetas
        if (!isCollapsed)
          ...activities.map((activity) {
            final isSelected =
                selectedActivity?.activity.id == activity.activity.id;
            final df = DateFormat('HH:mm', 'es');

            return Padding(
              padding: EdgeInsets.only(
                left: SaoSpacing.md,
                right: 0,
                bottom: SaoSpacing.sm,
              ),
              child: SaoActivityCard(
                title: activity.activity.title,
                pkLabel: 'PK 142+${(activities.indexOf(activity) * 100).toString().padLeft(3, '0')}', // TODO: PK real
                subtitle: activity.activityType?.name ?? 'Sin tipo',
                location: activity.municipality?.name ?? 'Sin ubicación',
                statusText: activity.statusLabel,
                statusIcon: Icons.schedule_rounded,
                accentColor: getRiskColor(activity),
                isSelected: isSelected,
                needsAttention: activity.activity.status == 'pending_review',
                onTap: () => onSelectActivity(activity),
                badge: activity.activity.executedAt != null
                    ? Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: SaoColors.gray100,
                          borderRadius: BorderRadius.circular(SaoRadii.sm),
                        ),
                        child: Text(
                          df.format(activity.activity.executedAt!),
                          style: SaoTypography.caption.copyWith(
                            color: SaoColors.gray600,
                          ),
                        ),
                      )
                    : null,
              ),
            );
          }).toList(),

        SizedBox(height: SaoSpacing.sm),
      ],
    );
  }
}
