import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/project_providers.dart';
import '../../data/models/activity_model.dart';
import '../../data/repositories/activity_repository.dart';
import '../../ui/sao_ui.dart';
import '../../ui/widgets/sao_validation_search_bar.dart';
import 'widgets/activity_queue_panel.dart';
import 'widgets/activity_details_panel_pro.dart';
import 'widgets/evidence_gallery_panel_pro.dart';
import 'widgets/board_shortcuts.dart';

class ValidationPageNewDesign extends ConsumerStatefulWidget {
  const ValidationPageNewDesign({super.key});

  @override
  ConsumerState<ValidationPageNewDesign> createState() => _ValidationPageNewDesignState();
}

class _ValidationPageNewDesignState extends ConsumerState<ValidationPageNewDesign> {
  ActivityWithDetails? _selectedActivity;
  List<ActivityWithDetails> _visibleActivities = const [];
  int _selectedEvidenceIndex = 0;
  String _searchQuery = '';
  String _queueTab = 'PENDING';
  bool _filterPending = false;
  bool _filterRejected = false;
  bool _filterGps = false;
  bool _filterChanges = false;
  String? _selectedRejectReasonCode;
  late TextEditingController _reviewCommentsController;
  List<ActivityTimelineEntry> _timelineEntries = const [];
  bool _timelineLoading = false;
  String? _timelineError;

  @override
  void initState() {
    super.initState();
    _reviewCommentsController = TextEditingController();
  }

  @override
  void dispose() {
    _reviewCommentsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activitiesAsync = ref.watch(pendingActivitiesProvider);

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
        backgroundColor: SaoColors.gray50,
        body: Column(
          children: [
            // Top bar con nueva busqueda inteligente
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.shadow.withOpacity(0.05),
                    blurRadius: 8,
                    offset: Offset(0, 2),
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
                           color: SaoColors.primary, size: 28),
                      SizedBox(width: 12),
                      Text(
                        'Validación de Actividades - Nuevo Diseño',
                        style: SaoTypography.pageTitle.copyWith(
                          color: SaoColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                    ],
                  ),
                  SizedBox(height: 16),
                  
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
                          return searchableText.contains(_searchQuery.toLowerCase());
                        }).toList();
                        return filtered.length;
                      },
                      orElse: () => null,
                    ),
                    projectName: ref.watch(activeProjectIdProvider),
                    onFilterPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Filtros avanzados - Próximamente'),
                          backgroundColor: SaoColors.info,
                        ),
                      );
                    },
                ),
                SizedBox(height: 12),
                Wrap(
                  spacing: SaoSpacing.sm,
                  runSpacing: SaoSpacing.sm,
                  children: [
                    _buildFilterChip(
                      label: 'Pendiente',
                      selected: _filterPending,
                      onSelected: (v) => setState(() => _filterPending = v),
                    ),
                    _buildFilterChip(
                      label: 'Rechazado',
                      selected: _filterRejected,
                      onSelected: (v) => setState(() => _filterRejected = v),
                    ),
                    _buildFilterChip(
                      label: 'GPS Critico',
                      selected: _filterGps,
                      onSelected: (v) => setState(() => _filterGps = v),
                    ),
                    _buildFilterChip(
                      label: 'Con Cambios',
                      selected: _filterChanges,
                      onSelected: (v) => setState(() => _filterChanges = v),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Paneles principales con nuevo diseno
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Panel izquierdo: tarjetas inteligentes
                  SizedBox(
                    width: 320,
                    child: Container(
                      decoration: BoxDecoration(
                        color: SaoColors.surface,
                        borderRadius: BorderRadius.circular(SaoRadii.lg),
                        border: Border.all(color: SaoColors.primary.withOpacity(0.4), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: SaoColors.primary.withOpacity(0.08),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ActivityQueuePanel(
                        activitiesAsync: activitiesAsync,
                        selectedActivity: _selectedActivity,
                        searchQuery: _searchQuery,
                        queueTab: _queueTab,
                        filterPending: _filterPending,
                        filterRejected: _filterRejected,
                        filterGps: _filterGps,
                        filterChanges: _filterChanges,
                        onQueueTabChanged: (tab) {
                          setState(() => _queueTab = tab);
                        },
                        onVisibleActivitiesChanged: (activities) {
                          _visibleActivities = activities;
                        },
                        onSelectActivity: (activity) {
                          setState(() {
                            _selectedActivity = activity;
                            _selectedEvidenceIndex = 0;
                          });
                          _loadTimelineForActivity(activity.activity.id);
                        },
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  
                  // Panel central: verdad tecnica interactiva
                  Expanded(
                    flex: 3,
                    child: Container(
                      decoration: BoxDecoration(
                        color: SaoColors.surface,
                        borderRadius: BorderRadius.circular(SaoRadii.lg),
                        border: Border.all(
                          color: SaoColors.info.withOpacity(0.4),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: SaoColors.info.withOpacity(0.08),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ActivityDetailsPanelPro(
                        activity: _selectedActivity,
                        timelineEntries: _timelineEntries,
                        timelineLoading: _timelineLoading,
                        timelineError: _timelineError,
                        onFieldChanged: (field, value) {
                          print('Campo $field cambiado a: $value');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Campo "$field" modificado'),
                              duration: Duration(seconds: 1),
                              backgroundColor: SaoColors.info,
                            ),
                          );
                        },
                        onAcceptChange: (field) {
                          print('Cambio aceptado en campo: $field');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Cambio aceptado: $field'),
                              backgroundColor: SaoColors.success,
                            ),
                          );
                        },
                        onRevertChange: (field) {
                          print('Cambio revertido en campo: $field');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Cambio revertido: $field'),
                              backgroundColor: SaoColors.warning,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  
                  // Panel derecho: visor profesional de evidencias
                  Expanded(
                    flex: 2,
                    child: Container(
                      decoration: BoxDecoration(
                        color: SaoColors.surface,
                        borderRadius: BorderRadius.circular(SaoRadii.lg),
                        border: Border.all(color: SaoColors.success.withOpacity(0.4), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: SaoColors.success.withOpacity(0.08),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: EvidenceGalleryPanelPro(
                        activity: _selectedActivity,
                        selectedIndex: _selectedEvidenceIndex,
                        onSelectEvidence: (index) {
                          setState(() => _selectedEvidenceIndex = index);
                        },
                        onCaptionChanged: (evidenceId, caption) {
                          _saveEvidenceCaption(evidenceId, caption);
                        },
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                ],
              ),
            ),
          ),
          
          // Footer con acciones rapidas
          if (_selectedActivity != null)
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(color: SaoColors.border),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.keyboard_rounded, color: SaoColors.gray600),
                  SizedBox(width: 8),
                  Text(
                    'Atajos: Enter = Aprobar | R = Rechazar | Esc = Siguiente',
                    style: SaoTypography.caption.copyWith(color: SaoColors.gray600),
                  ),
                  Spacer(),
                  ElevatedButton.icon(
                    onPressed: _selectedActivity == null ? null : () => _showRejectDialog(),
                    icon: Icon(Icons.cancel_rounded),
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Rechazar'),
                        SizedBox(width: SaoSpacing.xs),
                        _buildShortcutPill('R'),
                      ],
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SaoColors.error,
                      foregroundColor: SaoColors.onPrimary,
                      disabledBackgroundColor: SaoColors.gray300,
                    ),
                  ),
                  SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _selectedActivity == null ? null : () => _approveActivity(),
                    icon: Icon(Icons.check_circle_rounded),
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Aprobar'),
                        SizedBox(width: SaoSpacing.xs),
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
              ),
            ),
        ],
      ),
      ),
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
      if (!mounted || _selectedActivity?.activity.id != activityId) return;
      setState(() {
        _timelineLoading = false;
      });
    }
  }

  Widget _buildShortcutPill(String label) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: SaoSpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: SaoColors.onPrimary.withOpacity(0.2),
        borderRadius: BorderRadius.circular(SaoRadii.sm),
        border: Border.all(color: SaoColors.onPrimary.withOpacity(0.6)),
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

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required ValueChanged<bool> onSelected,
  }) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      selectedColor: SaoColors.primary.withOpacity(0.15),
      labelStyle: SaoTypography.caption.copyWith(
        color: selected ? SaoColors.primary : SaoColors.gray600,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? SaoColors.primary : SaoColors.border,
        ),
      ),
      backgroundColor: SaoColors.surface,
    );
  }

  /// Aprueba la actividad seleccionada y carga la siguiente
  Future<void> _approveActivity() async {
    if (_selectedActivity == null) return;
    final previousActivityId = _selectedActivity!.activity.id;

    final repo = ref.read(activityRepositoryProvider);
    try {
      await repo.approveActivity(previousActivityId, 'usr-admin-001');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: SaoColors.onPrimary),
                SizedBox(width: SaoSpacing.md),
                Expanded(
                  child: Text(
                    'Actividad aprobada correctamente',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: SaoColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SaoRadii.sm)),
            duration: Duration(seconds: 2),
          ),
        );
        
        // Cargar siguiente actividad
        _loadNextActivity(previousActivityId);
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
    }
  }

  /// Muestra diálogo para rechazar la actividad
  void _showRejectDialog() {
    final repo = ref.read(activityRepositoryProvider);
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SaoRadii.xl)),
        child: Container(
          width: 550,
          padding: EdgeInsets.all(SaoSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(SaoSpacing.md),
                    decoration: BoxDecoration(
                      color: SaoColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(SaoRadii.md),
                    ),
                    child: Icon(Icons.cancel_rounded, color: SaoColors.error, size: 28),
                  ),
                  SizedBox(width: SaoSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rechazar Actividad',
                          style: SaoTypography.pageTitle,
                        ),
                        Text(
                          'Se enviará solicitud de corrección al móvil',
                          style: SaoTypography.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: SaoSpacing.xxl),
              Text(
                'Motivo del rechazo:',
                style: SaoTypography.bodyTextBold,
              ),
              SizedBox(height: SaoSpacing.md),
              TextField(
                controller: _reviewCommentsController,
                maxLines: 4,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Ej: La foto está borrosa, tomar de nuevo',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(SaoRadii.md)),
                  filled: true,
                  fillColor: SaoColors.gray50,
                ),
              ),
              SizedBox(height: SaoSpacing.lg),
              Text(
                'Motivos comunes:',
                style: SaoTypography.caption.copyWith(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: SaoSpacing.md),
              FutureBuilder<List<RejectionPlaybookItem>>(
                future: repo.getRejectPlaybook(projectId: _selectedActivity?.activity.projectId),
                builder: (context, snapshot) {
                  final items = (snapshot.data != null && snapshot.data!.isNotEmpty)
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
              SizedBox(height: SaoSpacing.xxl),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      _reviewCommentsController.clear();
                      Navigator.pop(ctx);
                    },
                    child: Text('Cancelar'),
                  ),
                  SizedBox(width: SaoSpacing.md),
                  FilledButton.icon(
                    onPressed: () async {
                      if (_reviewCommentsController.text.trim().isEmpty) return;
                      Navigator.pop(ctx);
                      await _rejectActivity();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: SaoColors.error,
                      padding: EdgeInsets.symmetric(horizontal: SaoSpacing.xxl, vertical: SaoSpacing.md),
                    ),
                    icon: Icon(Icons.send_rounded, size: 18),
                    label: Text('Enviar Rechazo'),
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
      backgroundColor: SaoColors.gray100,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: SaoColors.gray300),
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
            content: Row(
              children: [
                Icon(Icons.cancel_rounded, color: SaoColors.onPrimary),
                SizedBox(width: SaoSpacing.md),
                Expanded(
                  child: Text(
                    'Actividad rechazada correctamente',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: SaoColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SaoRadii.sm)),
            duration: Duration(seconds: 2),
          ),
        );

        // Cargar siguiente actividad
        _loadNextActivity(previousActivityId);
        
        // Limpiar controles
        _reviewCommentsController.clear();
        _selectedRejectReasonCode = null;
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
        SnackBar(
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

  /// Carga la siguiente actividad en la cola
  void _loadNextActivity(String processedActivityId) {
    final queue = _visibleActivities;
    final currentIndex = queue.indexWhere((item) => item.activity.id == processedActivityId);

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

  /// Maneja cuando se arrastra una tarjeta a la zona de revisar
  void _handleDropForReview(ActivityWithDetails activity) {
    setState(() => _selectedActivity = activity);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.edit_rounded, color: SaoColors.onPrimary),
            SizedBox(width: SaoSpacing.md),
            Text('Revisando: ${activity.activity.title}'),
          ],
        ),
        backgroundColor: SaoColors.info,
        duration: Duration(seconds: 1),
      ),
    );
  }
}

// Provider para obtener actividades pendientes
final pendingActivitiesProvider = StreamProvider<List<ActivityWithDetails>>((ref) {
  final repo = ref.watch(activityRepositoryProvider);
  return repo.watchPendingReview();
});