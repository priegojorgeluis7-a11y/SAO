import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/providers/project_providers.dart';
import '../../data/models/activity_model.dart';
import '../../data/repositories/activity_repository.dart';
import '../../ui/sao_ui.dart';
import '../../ui/widgets/sao_validation_search_bar.dart';
import 'widgets/activity_queue_panel.dart';
import 'widgets/activity_form_panel.dart';
import 'widgets/evidence_gallery_panel.dart';
import 'widgets/review_actions.dart';
import 'widgets/gps_validation_banner.dart';

class ValidationPage extends ConsumerStatefulWidget {
  const ValidationPage({super.key});

  @override
  ConsumerState<ValidationPage> createState() => _ValidationPageState();
}

class _ValidationPageState extends ConsumerState<ValidationPage> {
  ActivityWithDetails? _selectedActivity;
  int _selectedEvidenceIndex = 0;
  String _searchQuery = '';

  final _reviewCommentsController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _reviewCommentsController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // Atajos de teclado
  void _handleKeyPress(RawKeyEvent event) {
    if (event is! RawKeyDownEvent) return;
    if (_selectedActivity == null) return;

    if (event.logicalKey == LogicalKeyboardKey.enter) {
      _approveAndNext();
    } else if (event.logicalKey == LogicalKeyboardKey.keyR) {
      _showRejectDialog();
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      _loadNextActivity();
    }
  }

  Future<void> _approveAndNext() async {
    if (_selectedActivity == null) return;

    final repo = ref.read(activityRepositoryProvider);
    await repo.approveActivity(_selectedActivity!.activity.id, 'usr-admin-001');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: SaoColors.onPrimary),
              SizedBox(width: SaoSpacing.md),
              Text('Actividad aprobada', style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          backgroundColor: SaoColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SaoRadii.sm)),
          duration: Duration(seconds: 1),
        ),
      );
      _loadNextActivity();
    }
  }

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
                          'La solicitud llegará al móvil',
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

  Widget _buildReasonChip(String reason) {
    return ActionChip(
      label: Text(reason, style: SaoTypography.chipText),
      onPressed: () => _reviewCommentsController.text = reason,
      backgroundColor: SaoColors.gray100,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: SaoColors.gray300),
      ),
    );
  }

  Future<void> _rejectActivity() async {
    if (_selectedActivity == null) return;

    final comments = _reviewCommentsController.text.trim();
    if (comments.isEmpty) return;

    final repo = ref.read(activityRepositoryProvider);
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
              Icon(Icons.info_outline_rounded, color: SaoColors.onPrimary),
              SizedBox(width: SaoSpacing.md),
              Text('Notificación enviada al ingeniero'),
            ],
          ),
          backgroundColor: SaoColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SaoRadii.sm)),
          duration: Duration(seconds: 2),
        ),
      );
      _reviewCommentsController.clear();
      _loadNextActivity();
    }
  }

  void _loadNextActivity() {
    final activitiesAsync = ref.read(pendingActivitiesProvider);
    activitiesAsync.whenData((activities) {
      if (activities.isEmpty) {
        setState(() => _selectedActivity = null);
        return;
      }

      if (_selectedActivity != null) {
        final currentIndex = activities.indexWhere(
          (a) => a.activity.id == _selectedActivity!.activity.id,
        );
        if (currentIndex >= 0 && currentIndex < activities.length - 1) {
          setState(() {
            _selectedActivity = activities[currentIndex + 1];
            _selectedEvidenceIndex = 0;
          });
        } else if (activities.isNotEmpty) {
          setState(() {
            _selectedActivity = activities.first;
            _selectedEvidenceIndex = 0;
          });
        }
      } else {
        setState(() {
          _selectedActivity = activities.first;
          _selectedEvidenceIndex = 0;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final activitiesAsync = ref.watch(pendingActivitiesProvider);

    return RawKeyboardListener(
      focusNode: _focusNode,
      onKey: _handleKeyPress,
      child: Scaffold(
        backgroundColor: SaoColors.gray50,
        body: Column(
          children: [
            _buildTopBar(activitiesAsync),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Panel Izquierdo: Cola de Actividades (redesigned)
                    SizedBox(
                      width: 320,
                      child: ActivityQueuePanel(
                        activitiesAsync: activitiesAsync,
                        selectedActivity: _selectedActivity,
                        searchQuery: _searchQuery,
                        onSelectActivity: (activity) {
                          setState(() {
                            _selectedActivity = activity;
                            _selectedEvidenceIndex = 0;
                          });
                        },
                      ),
                    ),
                    SizedBox(width: 16),
                    
                    // Panel Central: Detalles con Diff View (redesigned)
                    Expanded(
                      flex: 3,
                      child: ActivityFormPanel(
                        activity: _selectedActivity,
                        onFieldChanged: (field, value) {
                          print('Campo $field cambiado a: $value');
                        },
                        onAcceptChange: (field) {
                          print('Cambio aceptado en campo: $field');
                        },
                        onRevertChange: (field) {
                          print('Cambio revertido en campo: $field');
                        },
                      ),
                    ),
                    SizedBox(width: 16),
                    
                    // Panel Derecho: Evidencias con Zoom y GPS (redesigned)
                    Expanded(
                      flex: 5,
                      child: Column(
                        children: [
                          Expanded(
                            child: EvidenceGalleryPanel(
                              activity: _selectedActivity,
                              selectedIndex: _selectedEvidenceIndex,
                              onSelectEvidence: (index) =>
                                  setState(() => _selectedEvidenceIndex = index),
                            ),
                          ),
                          SizedBox(height: 16),
                          ReviewActions(
                            activity: _selectedActivity,
                            onApprove: _approveAndNext,
                            onReject: _showRejectDialog,
                            onSkip: _loadNextActivity,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(AsyncValue<List<ActivityWithDetails>> activitiesAsync) {
    final total = activitiesAsync.maybeWhen(
      data: (activities) => activities.length,
      orElse: () => 0,
    );
    
    final currentIndex = _selectedActivity != null
        ? activitiesAsync.maybeWhen(
            data: (activities) => activities.indexWhere(
              (a) => a.activity.id == _selectedActivity!.activity.id,
            ) + 1,
            orElse: () => 0,
          )
        : 0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
        children: [
          // Header with title and progress
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Validación de Actividades',
                    style: SaoTypography.pageTitle,
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on_rounded, size: 14, color: SaoColors.gray600),
                      SizedBox(width: 6),
                      Text(
                        'Proyecto: ${ref.watch(activeProjectIdProvider)}',
                        style: SaoTypography.caption.copyWith(color: SaoColors.gray600),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(width: 48),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Progreso',
                          style: SaoTypography.caption.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Revisados: $currentIndex / $total',
                          style: SaoTypography.caption.copyWith(
                            fontWeight: FontWeight.bold,
                            color: SaoColors.primary,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: total > 0 ? currentIndex / total : 0,
                        minHeight: 8,
                        backgroundColor: SaoColors.gray200,
                        valueColor: AlwaysStoppedAnimation<Color>(SaoColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 48),
              Tooltip(
                message: 'Enter: Aprobar | R: Rechazar | Esc: Saltar',
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: SaoColors.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.keyboard_rounded, size: 20, color: SaoColors.primary),
                ),
              ),
            ],
          ),
          
          SizedBox(height: 16),
          
          // Barra de búsqueda inteligente (NEW!)
          SizedBox(
            width: double.infinity,
            child: SaoValidationSearchBar(
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
                  SnackBar(content: Text('Filtros avanzados próximamente')),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

final pendingActivitiesProvider = StreamProvider<List<ActivityWithDetails>>((ref) {
  final repo = ref.watch(activityRepositoryProvider);
  return repo.watchPendingReview();
});