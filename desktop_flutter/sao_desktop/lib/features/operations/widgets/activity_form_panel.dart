import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../data/models/activity_model.dart';
import '../../../ui/theme/sao_colors.dart';
import '../../../ui/theme/sao_spacing.dart';
import '../../../ui/theme/sao_radii.dart';
import '../../../ui/theme/sao_typography.dart';
import '../../../ui/widgets/activity_diff_field.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/status_badge.dart';

/// Panel de detalles de actividad con diff view interactivo
/// 
/// Rediseño UX:
/// - ActivityDiffField para comparar catálogo vs campo
/// - Edición inline con hover
/// - Botones para aceptar/rechazar cambios
/// - Campos de solo lectura modernos
class ActivityFormPanel extends StatefulWidget {
  final ActivityWithDetails? activity;
  final Function(String field, String value)? onFieldChanged;
  final Function(String field)? onAcceptChange;
  final Function(String field)? onRevertChange;

  const ActivityFormPanel({
    super.key,
    required this.activity,
    this.onFieldChanged,
    this.onAcceptChange,
    this.onRevertChange,
  });

  @override
  State<ActivityFormPanel> createState() => _ActivityFormPanelState();
}

class _ActivityFormPanelState extends State<ActivityFormPanel> {
  // Simulación de datos de catálogo (en producción vendrían de la base de datos)
  Map<String, String> _catalogValues = {};
  Map<String, String> _fieldValues = {};
  final Map<String, bool> _acceptedPulse = {};

  @override
  void initState() {
    super.initState();
    _loadCatalogData();
  }

  @override
  void didUpdateWidget(ActivityFormPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activity?.activity.id != widget.activity?.activity.id) {
      _loadCatalogData();
    }
  }

  void _loadCatalogData() {
    if (widget.activity == null) return;

    // TODO: Obtener datos reales del catálogo desde la base de datos
    // Por ahora simulamos algunos cambios para demostrar la funcionalidad
    _catalogValues = {
      'activityType': widget.activity!.activityType?.name ?? 'Excavación Manual',
      'title': 'Excavación de zanja tramo 142+000',
      'description': widget.activity!.activity.description ?? 'Descripción del catálogo',
      'front': widget.activity!.front?.name ?? 'Frente Norte',
    };

    _fieldValues = {
      'activityType': widget.activity!.activityType?.name ?? 'Excavación Mecánica',
      'title': widget.activity!.activity.title,
      'description': widget.activity!.activity.description ?? 'Descripción modificada en campo - cambios detectados',
      'front': widget.activity!.front?.name ?? 'Frente Norte',
    };
  }

  void _handleAcceptChange(String field) {
    setState(() {
      _catalogValues[field] = _fieldValues[field]!;
      _acceptedPulse[field] = true;
    });
    widget.onAcceptChange?.call(field);
    Future.delayed(const Duration(milliseconds: 650), () {
      if (!mounted) return;
      setState(() {
        _acceptedPulse[field] = false;
      });
    });
  }

  void _handleRevertChange(String field) {
    setState(() {
      _fieldValues[field] = _catalogValues[field]!;
    });
    widget.onRevertChange?.call(field);
  }

  void _handleEdit(String field, String value) {
    setState(() {
      _fieldValues[field] = value;
    });
    widget.onFieldChanged?.call(field, value);
  }

  Widget _buildDiffField({
    required String fieldKey,
    required String label,
    required String catalogValue,
    required String fieldValue,
    required VoidCallback onAccept,
    required VoidCallback onRevert,
    required ValueChanged<String> onEdit,
  }) {
    final isModified = catalogValue.trim() != fieldValue.trim();
    final isAccepted = _acceptedPulse[fieldKey] ?? false;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: EdgeInsets.all(SaoSpacing.sm),
      decoration: BoxDecoration(
        color: isAccepted
            ? SaoColors.success.withOpacity(0.12)
            : isModified
                ? SaoColors.warning.withOpacity(0.08)
                : Colors.transparent,
        border: Border.all(
          color: isModified ? SaoColors.warning : SaoColors.border,
        ),
        borderRadius: BorderRadius.circular(SaoRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isModified) ...[
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 14, color: SaoColors.warning),
                SizedBox(width: SaoSpacing.xs),
                Text(
                  'Catalogo:',
                  style: SaoTypography.caption.copyWith(
                    color: SaoColors.gray600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: SaoSpacing.xs),
                Expanded(
                  child: Text(
                    catalogValue.isEmpty ? 'SIN DATO' : catalogValue,
                    style: SaoTypography.caption.copyWith(
                      color: SaoColors.gray500,
                      decoration: TextDecoration.lineThrough,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: SaoSpacing.xs),
          ],
          ActivityDiffField(
            label: label,
            catalogValue: catalogValue,
            fieldValue: fieldValue,
            onAcceptChange: onAccept,
            onRevertChange: onRevert,
            onEdit: onEdit,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.activity == null) {
      return Container(
        decoration: BoxDecoration(
          color: SaoColors.surface,
          borderRadius: BorderRadius.circular(SaoRadii.md),
          border: Border.all(color: SaoColors.border),
        ),
        child: Center(
          child: Text(
            'Selecciona una actividad',
            style: SaoTypography.bodyText.copyWith(color: SaoColors.gray500),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: SaoColors.surface,
        borderRadius: BorderRadius.circular(SaoRadii.md),
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
                Icon(Icons.assignment_rounded, size: 20, color: SaoColors.primary),
                SizedBox(width: SaoSpacing.sm),
                Text(
                  'Detalles de Actividad',
                  style: SaoTypography.sectionTitle.copyWith(fontSize: 16),
                ),
                const Spacer(),
                StatusBadge(status: widget.activity!.activity.status),
              ],
            ),
          ),
          Divider(height: 1, color: SaoColors.border),
          
          // Contenido con scroll
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(SaoSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ActivityDiffField para Tipo de Actividad
                  _buildDiffField(
                    fieldKey: 'activityType',
                    label: 'TIPO DE ACTIVIDAD',
                    catalogValue: _catalogValues['activityType'] ?? '',
                    fieldValue: _fieldValues['activityType'] ?? '',
                    onAccept: () => _handleAcceptChange('activityType'),
                    onRevert: () => _handleRevertChange('activityType'),
                    onEdit: (value) => _handleEdit('activityType', value),
                  ),
                  SizedBox(height: SaoSpacing.lg),

                  // ActivityDiffField para Título
                  _buildDiffField(
                    fieldKey: 'title',
                    label: 'TÍTULO',
                    catalogValue: _catalogValues['title'] ?? '',
                    fieldValue: _fieldValues['title'] ?? '',
                    onAccept: () => _handleAcceptChange('title'),
                    onRevert: () => _handleRevertChange('title'),
                    onEdit: (value) => _handleEdit('title', value),
                  ),
                  SizedBox(height: SaoSpacing.lg),

                  // ActivityDiffField para Descripción
                  if (widget.activity!.activity.description != null) ...[
                    _buildDiffField(
                      fieldKey: 'description',
                      label: 'DESCRIPCIÓN',
                      catalogValue: _catalogValues['description'] ?? '',
                      fieldValue: _fieldValues['description'] ?? '',
                      onAccept: () => _handleAcceptChange('description'),
                      onRevert: () => _handleRevertChange('description'),
                      onEdit: (value) => _handleEdit('description', value),
                    ),
                    SizedBox(height: SaoSpacing.lg),
                  ],

                  // Fila: Frente y Proyecto (campos de solo lectura)
                  Row(
                    children: [
                      Expanded(
                        child: _buildReadOnlyField(
                          'FRENTE',
                          widget.activity!.front?.name ?? 'N/A',
                          Icons.account_tree_rounded,
                        ),
                      ),
                      SizedBox(width: SaoSpacing.lg),
                      Expanded(
                        child: _buildReadOnlyField(
                          'PROYECTO',
                          'TMQ',
                          Icons.folder_rounded,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: SaoSpacing.lg),

                  // Fila: Municipio y Estado
                  Row(
                    children: [
                      Expanded(
                        child: _buildReadOnlyField(
                          'MUNICIPIO',
                          widget.activity!.municipality?.name ?? 'N/A',
                          Icons.location_city_rounded,
                        ),
                      ),
                      SizedBox(width: SaoSpacing.lg),
                      Expanded(
                        child: _buildReadOnlyField(
                          'ESTADO',
                          widget.activity!.municipality?.state ?? 'N/A',
                          Icons.map_rounded,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: SaoSpacing.lg),

                  // Ingeniero asignado
                  _buildReadOnlyField(
                    'INGENIERO ASIGNADO',
                    widget.activity!.assignedUser?.fullName ?? 'N/A',
                    Icons.person_rounded,
                  ),
                  SizedBox(height: SaoSpacing.lg),

                  // Fila: Fecha y Evidencias
                  Row(
                    children: [
                      Expanded(
                        child: _buildReadOnlyField(
                          'FECHA DE EJECUCIÓN',
                          widget.activity!.activity.executedAt != null
                              ? DateFormat('dd/MM/yyyy HH:mm').format(
                                  widget.activity!.activity.executedAt!)
                              : 'N/A',
                          Icons.calendar_today_rounded,
                        ),
                      ),
                      SizedBox(width: SaoSpacing.lg),
                      Expanded(
                        child: _buildReadOnlyField(
                          'EVIDENCIAS',
                          '${widget.activity!.evidences.length}',
                          Icons.photo_library_rounded,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: SaoSpacing.lg),

                  // Ubicación GPS (si existe)
                  if (widget.activity!.activity.latitude != null &&
                      widget.activity!.activity.longitude != null) ...[
                    Container(
                      padding: EdgeInsets.all(SaoSpacing.md),
                      decoration: BoxDecoration(
                        color: SaoColors.gray50,
                        border: Border.all(color: SaoColors.border),
                        borderRadius: BorderRadius.circular(SaoRadii.md),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_rounded,
                                size: 16,
                                color: SaoColors.error,
                              ),
                              SizedBox(width: SaoSpacing.xs),
                              Text(
                                'UBICACIÓN GPS',
                                style: SaoTypography.caption.copyWith(
                                  color: SaoColors.gray600,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: () {
                                  // TODO: Abrir en mapa
                                },
                                icon: Icon(Icons.open_in_new_rounded, size: 14),
                                label: Text('Ver en mapa'),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: SaoSpacing.sm,
                                    vertical: 4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: SaoSpacing.xs),
                          Text(
                            'Lat: ${widget.activity!.activity.latitude!.toStringAsFixed(6)}, '
                            'Lng: ${widget.activity!.activity.longitude!.toStringAsFixed(6)}',
                            style: SaoTypography.mono.copyWith(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Campo de solo lectura moderno
  Widget _buildReadOnlyField(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: SaoTypography.caption.copyWith(
            color: SaoColors.gray600,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        SizedBox(height: SaoSpacing.xs),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(SaoSpacing.md),
          decoration: BoxDecoration(
            color: SaoColors.gray50,
            border: Border.all(color: SaoColors.border),
            borderRadius: BorderRadius.circular(SaoRadii.md),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: SaoColors.gray500),
              SizedBox(width: SaoSpacing.sm),
              Expanded(
                child: Text(
                  value,
                  style: SaoTypography.bodyText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
