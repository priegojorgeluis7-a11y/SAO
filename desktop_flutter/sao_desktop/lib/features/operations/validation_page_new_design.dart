import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  int _selectedEvidenceIndex = 0;
  String _searchQuery = '';
  bool _filterPending = false;
  bool _filterRejected = false;
  bool _filterGps = false;
  bool _filterChanges = false;
  late TextEditingController _reviewCommentsController;

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
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
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
                    projectName: 'TMQ',
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
                        filterPending: _filterPending,
                        filterRejected: _filterRejected,
                        filterGps: _filterGps,
                        filterChanges: _filterChanges,
                        onSelectActivity: (activity) {
                          setState(() {
                            _selectedActivity = activity;
                            _selectedEvidenceIndex = 0;
                          });
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
                          print('Caption actualizado: $caption');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Pie de foto guardado'),
                              duration: Duration(seconds: 1),
                              backgroundColor: SaoColors.success,
                            ),
                          );
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
                color: Colors.white,
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
                      foregroundColor: Colors.white,
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
                      foregroundColor: Colors.white,
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

  Widget _buildShortcutPill(String label) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: SaoSpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(SaoRadii.sm),
        border: Border.all(color: Colors.white.withOpacity(0.6)),
      ),
      child: Text(
        label,
        style: SaoTypography.caption.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 10,
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

    final repo = ref.read(activityRepositoryProvider);
    try {
      await repo.approveActivity(_selectedActivity!.activity.id, 'usr-admin-001');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
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
        _loadNextActivity();
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
              Wrap(
                spacing: SaoSpacing.sm,
                runSpacing: SaoSpacing.sm,
                children: [
                  _buildReasonChip('La foto está borrosa'),
                  _buildReasonChip('No se observa el elemento'),
                  _buildReasonChip('GPS incorrecto'),
                  _buildReasonChip('Falta información'),
                ],
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
  Widget _buildReasonChip(String reason) {
    return ActionChip(
      label: Text(reason, style: SaoTypography.caption.copyWith(fontSize: 11)),
      onPressed: () => _reviewCommentsController.text = reason,
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

    final comments = _reviewCommentsController.text.trim();
    if (comments.isEmpty) return;

    final repo = ref.read(activityRepositoryProvider);
    try {
      await repo.rejectActivity(
        _selectedActivity!.activity.id,
        'usr-admin-001',
        comments,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.cancel_rounded, color: Colors.white),
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
        _loadNextActivity();
        
        // Limpiar controles
        _reviewCommentsController.clear();
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

  /// Carga la siguiente actividad en la cola
  void _loadNextActivity() {
    // Simplemente limpiar la selección actual
    // El stream provider actualizará automáticamente cuando se refresquen los datos
    setState(() {
      _selectedActivity = null;
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
            Icon(Icons.edit_rounded, color: Colors.white),
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