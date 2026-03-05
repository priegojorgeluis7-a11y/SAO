import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/activity_model.dart';
import '../../../ui/theme/sao_colors.dart';
import '../../../ui/theme/sao_spacing.dart';
import '../../../ui/theme/sao_radii.dart';
import '../../../ui/theme/sao_typography.dart';
import '../../../ui/widgets/sao_activity_card.dart';
import '../../../data/catalog/activity_status.dart';
import '../../../catalog/risk_catalog.dart';
import '../../../catalog/status_catalog.dart';

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
  final bool filterPending;
  final bool filterRejected;
  final bool filterGps;
  final bool filterChanges;
  final String queueTab;
  final ValueChanged<String>? onQueueTabChanged;
  final ValueChanged<List<ActivityWithDetails>>? onVisibleActivitiesChanged;

  const ActivityQueuePanel({
    super.key,
    required this.activitiesAsync,
    required this.selectedActivity,
    required this.onSelectActivity,
    this.searchQuery,
    this.filterPending = false,
    this.filterRejected = false,
    this.filterGps = false,
    this.filterChanges = false,
    this.queueTab = 'PENDING',
    this.onQueueTabChanged,
    this.onVisibleActivitiesChanged,
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

  /// Filtra actividades por búsqueda y estado
  List<ActivityWithDetails> _filterActivities(
    List<ActivityWithDetails> activities,
  ) {
    var filtered = activities;

    // Filtro por búsqueda
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
          return status == ActivityStatus.conflict || hasCatalogChange || hasChecklistIncomplete;
        case 'GPS':
          return hasGpsConflict;
        case 'REJECTED':
          return status == ActivityStatus.rejected;
        default:
          return true;
      }
    }).toList();

    // Filtro por estado
    if (widget.filterPending || widget.filterRejected || widget.filterGps || widget.filterChanges) {
      filtered = filtered.where((activity) {
        final status = _deriveStatus(activity);
        
        // Filtro Pendiente
        if (widget.filterPending) {
          if (status == ActivityStatus.pendingReview) return true;
        }
        
        // Filtro Rechazado
        if (widget.filterRejected) {
          if (status == ActivityStatus.rejected) return true;
        }
        
        // Filtro GPS Crítico (más de 800m de diferencia)
        if (widget.filterGps) {
          if (activity.flags.gpsMismatch) return true;
        }
        
        // Filtro Con Cambios
        if (widget.filterChanges) {
          if (status == ActivityStatus.conflict ||
              activity.flags.catalogChanged ||
              activity.flags.checklistIncomplete) {
            return true;
          }
        }
        
        return false; // Si algún filtro está activo pero no coincide, excluir
      }).toList();
    }

    return filtered;
  }

  Map<String, int> _buildTabCounters(List<ActivityWithDetails> activities) {
    final counters = <String, int>{
      'ALL': activities.length,
      'PENDING': 0,
      'CHANGED': 0,
      'GPS': 0,
      'REJECTED': 0,
    };

    for (final activity in activities) {
      final status = _deriveStatus(activity);
      final hasGpsConflict = activity.flags.gpsMismatch;
      final hasCatalogChange = activity.flags.catalogChanged;
      final hasChecklistIncomplete = activity.flags.checklistIncomplete;

      if (status == ActivityStatus.pendingReview) {
        counters['PENDING'] = (counters['PENDING'] ?? 0) + 1;
      }
      if (status == ActivityStatus.conflict || hasCatalogChange || hasChecklistIncomplete) {
        counters['CHANGED'] = (counters['CHANGED'] ?? 0) + 1;
      }
      if (hasGpsConflict) {
        counters['GPS'] = (counters['GPS'] ?? 0) + 1;
      }
      if (status == ActivityStatus.rejected) {
        counters['REJECTED'] = (counters['REJECTED'] ?? 0) + 1;
      }
    }

    return counters;
  }

  Color _getRiskColor(ActivityWithDetails activity) {
    return _deriveRisk(activity).color;
  }

  RiskLevel _deriveRisk(ActivityWithDetails activity) {
    final description = (activity.activity.description ?? '').toLowerCase();
    if (description.contains('prioritario') || description.contains('crítico')) {
      return RiskCatalog.prioritario;
    }
    if (description.contains('alto')) {
      return RiskCatalog.alto;
    }
    if (description.contains('medio')) {
      return RiskCatalog.medio;
    }
    if (description.contains('bajo')) {
      return RiskCatalog.bajo;
    }

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
    final description = (activity.activity.description ?? '').trim().toLowerCase();

    // Mostrar diferentes estados según la descripción
    if (description.contains('rechazada') || description.contains('rechazado')) {
      return ActivityStatus.rejected;
    }
    
    if (description.contains('corregida') || description.contains('corregido')) {
      return ActivityStatus.corrected;
    }
    
    if (description.contains('necesita') || description.contains('falta')) {
      return ActivityStatus.needsFix;
    }
    
    if (description.contains('cambios') || description.contains('discrepancia')) {
      return ActivityStatus.conflict;
    }

    if (activity.flags.checklistIncomplete) {
      return ActivityStatus.conflict;
    }
    
    if (description.contains('aprobada') || description.contains('aprobado')) {
      return ActivityStatus.approved;
    }

    return activity.activity.status;
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
                  style: SaoTypography.pageTitle,
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
                        borderRadius: BorderRadius.circular(SaoRadii.full),
                      ),
                      child: Text(
                        '${filtered.length}',
                        style: SaoTypography.caption.copyWith(
                          color: SaoColors.statusPendiente,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  },
                  loading: () => SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  error: (_, __) => Icon(Icons.error_outline, size: 20),
                ),
              ],
            ),
          ),

          widget.activitiesAsync.when(
            data: (activities) {
              final counters = _buildTabCounters(activities);
              final tabs = const <(String key, String label)>[
                ('PENDING', 'Pendientes'),
                ('CHANGED', 'Con cambios'),
                ('GPS', 'GPS crítico'),
                ('REJECTED', 'Rechazadas'),
                ('ALL', 'Todas'),
              ];

              return SizedBox(
                height: 40,
                child: ListView.separated(
                  padding: EdgeInsets.symmetric(horizontal: SaoSpacing.lg),
                  scrollDirection: Axis.horizontal,
                  itemCount: tabs.length,
                  separatorBuilder: (_, __) => SizedBox(width: SaoSpacing.xs),
                  itemBuilder: (context, index) {
                    final tab = tabs[index];
                    final selected = widget.queueTab == tab.$1;
                    final count = counters[tab.$1] ?? 0;
                    return ChoiceChip(
                      label: Text('${tab.$2} ($count)'),
                      selected: selected,
                      onSelected: (_) => widget.onQueueTabChanged?.call(tab.$1),
                      selectedColor: SaoColors.primary.withOpacity(0.16),
                      backgroundColor: SaoColors.gray100,
                      labelStyle: SaoTypography.caption.copyWith(
                        color: selected ? SaoColors.primary : SaoColors.gray700,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  },
                ),
              );
            },
            loading: () => SizedBox.shrink(),
            error: (_, __) => SizedBox.shrink(),
          ),

          // Lista de actividades agrupadas por frente
          Expanded(
            child: widget.activitiesAsync.when(
              data: (activities) {
                final filtered = _filterActivities(activities);
                widget.onVisibleActivitiesChanged?.call(filtered);

                if (filtered.isEmpty) {
                  return _buildEmptyState();
                }

                final grouped = _groupByFront(filtered);
                return ListView.builder(
                  padding: EdgeInsets.only(bottom: SaoSpacing.md),
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
        padding: EdgeInsets.all(SaoSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasSearch ? Icons.search_off_rounded : Icons.inbox_rounded,
              size: 48,
              color: SaoColors.gray400,
            ),
            SizedBox(height: SaoSpacing.lg),
            Text(
              hasSearch ? 'Sin resultados' : 'Sin actividades pendientes',
              style: SaoTypography.sectionTitle.copyWith(color: SaoColors.gray600),
            ),
            SizedBox(height: SaoSpacing.sm),
            Text(
              hasSearch
                  ? 'Intenta con otros términos'
                  : '¡Excelente trabajo! No hay nada pendiente por revisar.',
              style: SaoTypography.bodyText.copyWith(color: SaoColors.gray500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(SaoSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: SaoSpacing.lg),
            Text(
              'Cargando actividades...',
              style: SaoTypography.bodyText.copyWith(color: SaoColors.gray600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(SaoSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: SaoColors.error,
            ),
            SizedBox(height: SaoSpacing.lg),
            Text(
              'Error al cargar',
              style: SaoTypography.sectionTitle.copyWith(color: SaoColors.error),
            ),
            SizedBox(height: SaoSpacing.sm),
            Text(
              error,
              style: SaoTypography.bodyText.copyWith(color: SaoColors.gray600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Sección colapsable de un frente con sus actividades
class _FrontSection extends StatelessWidget {
  final String frontName;
  final List<ActivityWithDetails> activities;
  final ActivityWithDetails? selectedActivity;
  final bool isCollapsed;
  final VoidCallback onToggleCollapse;
  final Function(ActivityWithDetails) onSelectActivity;
  final Color Function(ActivityWithDetails) getRiskColor;
  final RiskLevel Function(ActivityWithDetails) deriveRisk;
  final String Function(ActivityWithDetails) deriveStatus;

  const _FrontSection({
    required this.frontName,
    required this.activities,
    required this.selectedActivity,
    required this.isCollapsed,
    required this.onToggleCollapse,
    required this.onSelectActivity,
    required this.getRiskColor,
    required this.deriveRisk,
    required this.deriveStatus,
  });

  static const Map<String, List<String>> _validSubcategoriesByActivity = {
    'Caminamiento': [
      'Verificación de DDV',
      'Marcaje de afectaciones',
      'Revisión de accesos / BDT',
      'Seguimiento técnico',
    ],
    'Reunión': [
      'Técnica / Interinstitucional',
      'Ejidal / Comisariado',
      'Municipal / Estatal / Protección Civil',
      'Seguimiento / Evaluación',
      'Informativa',
      'Mesa Técnica',
    ],
    'Asamblea Protocolizada': [
      '1ª Asamblea Protocolizada (1AP)',
      '1ª Asamblea Protocolizada Permanente',
      '2ª Asamblea Protocolizada (2AP)',
      '2ª Asamblea Protocolizada Permanente',
      'Asamblea Informativa',
    ],
    'Consulta Indígena': [
      'Etapa Informativa',
      'Etapa de Construcción de Acuerdos',
      'Etapa de Actos y Acuerdos',
    ],
    'Socialización': [
      'Presentación Comunitaria',
      'Difusión de Información',
      'Atención a Inquietudes',
    ],
    'Acompañamiento Institucional': [
      'Técnico',
      'Social',
      'Documental',
    ],
  };

  String _pkRange(ActivityWithDetails activity) {
    final title = activity.activity.title;
    final description = activity.activity.description ?? '';
    final text = '$title $description';

    final rangeMatch = RegExp(r'PK\s*\d+\+\d{3}\s*[\-–]\s*\d+\+\d{3}', caseSensitive: false)
        .firstMatch(text);
    if (rangeMatch != null) {
      return rangeMatch.group(0)!.toUpperCase().replaceAll(RegExp(r'\s+'), ' ');
    }

    final singleMatch = RegExp(r'PK\s*\d+\+\d{3}', caseSensitive: false).firstMatch(text);
    if (singleMatch != null) {
      return singleMatch.group(0)!.toUpperCase().replaceAll(RegExp(r'\s+'), ' ');
    }

    return 'PK no registrado';
  }

  String _stateMunicipality(ActivityWithDetails activity) {
    final state = activity.municipality?.state ?? 'N/A';
    final municipality = activity.municipality?.name ?? 'Sin municipio';
    return '$municipality, $state';
  }

  String _subcategory(ActivityWithDetails activity) {
    final title = activity.activity.title.trim();
    final activityName = activity.activityType?.name?.trim() ?? '';
    if (activityName.isEmpty) return '';

    String raw = '';
    if (title.contains(' – ')) {
      raw = title.split(' – ').last.trim();
    } else if (title.contains(' - ')) {
      raw = title.split(' - ').last.trim();
    }

    if (raw.isEmpty) return '';
    final valid = _validSubcategoriesByActivity[activityName] ?? const <String>[];
    final match = valid.where((item) => item.toLowerCase() == raw.toLowerCase());
    return match.isNotEmpty ? match.first : '';
  }

  String _relativeTime(DateTime when) {
    final now = DateTime.now();
    final diff = now.difference(when);
    if (diff.inMinutes < 1) return 'hace 0 min';
    if (diff.inHours < 1) return 'hace ${diff.inMinutes} min';
    if (diff.inDays < 1) return 'hace ${diff.inHours} h';
    return 'hace ${diff.inDays} días';
  }

  StatusType _officialStatusFor(String derivedStatus) {
    switch (ActivityStatus.normalize(derivedStatus)) {
      case ActivityStatus.approved:
        return StatusCatalog.aprobado;
      case ActivityStatus.rejected:
        return StatusCatalog.rechazado;
      case ActivityStatus.needsFix:
        return StatusCatalog.requiereCambios;
      case ActivityStatus.conflict:
        return StatusCatalog.conflicto;
      case ActivityStatus.corrected:
        return StatusCatalog.enRevision;
      case ActivityStatus.pendingReview:
      default:
        return StatusCatalog.enRevision;
    }
  }

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
              horizontal: SaoSpacing.lg,
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
                    style: SaoTypography.bodyText.copyWith(
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

            final derivedStatus = deriveStatus(activity);
            final risk = deriveRisk(activity);
            final activityMainName = activity.activityType?.name ?? 'Actividad';
            final activityMain = activityMainName;
            final responsible = activity.assignedUser?.fullName ?? activity.activity.assignedTo;
            final officialStatus = _officialStatusFor(derivedStatus);
            final validSubcategory = _subcategory(activity);
            final eventTime = activity.activity.executedAt ?? activity.activity.createdAt;

            return Padding(
              padding: EdgeInsets.only(
                left: SaoSpacing.lg,
                right: SaoSpacing.lg,
                bottom: SaoSpacing.sm,
              ),
              child: GestureDetector(
                onTap: () => onSelectActivity(activity),
                child: SaoActivityCard(
                  title: activityMain,
                  risk: risk,
                  status: officialStatus,
                  activityLabel: activityMain,
                  subcategoryLabel: validSubcategory.isEmpty ? null : validSubcategory,
                  pkLabel: _pkRange(activity).toUpperCase(),
                  locationLabel: _stateMunicipality(activity),
                  relativeTime: _relativeTime(eventTime),
                  actorName: responsible,
                  statusText: officialStatus.label,
                  statusIcon: officialStatus.icon,
                  accentColor: getRiskColor(activity),
                  highlightPriority: risk.priority == RiskCatalog.prioritario.priority,
                  isSelected: isSelected,
                  needsAttention: ActivityStatus.normalize(derivedStatus) == ActivityStatus.pendingReview ||
                      ActivityStatus.normalize(derivedStatus) == ActivityStatus.conflict,
                  onTap: () => onSelectActivity(activity),
                ),
              ),
            );
          }).toList(),

        if (!isCollapsed) SizedBox(height: SaoSpacing.sm),
      ],
    );
  }
}
