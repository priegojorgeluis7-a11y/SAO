import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../data/models/activity_model.dart';
import '../../../data/catalog/activity_status.dart';
import '../../../ui/theme/sao_colors.dart';
import '../../../ui/theme/sao_spacing.dart';
import '../../../ui/theme/sao_radii.dart';
import '../../../ui/theme/sao_typography.dart';
import '../../../ui/widgets/activity_diff_field.dart';
import 'catalog_substitution_modal.dart';

/// Panel Central PRO con 3 Tabs:
/// 1. Detalles (editable con diff view)
/// 2. Historial (timeline auditoría)
/// 3. Validación Técnica (checklist + GPS)
class ActivityDetailsPanelPro extends StatefulWidget {
  final ActivityWithDetails? activity;
  final List<ActivityTimelineEntry> timelineEntries;
  final bool timelineLoading;
  final String? timelineError;
  final Function(String field, String value)? onFieldChanged;
  final Function(String field)? onAcceptChange;
  final Function(String field)? onRevertChange;

  const ActivityDetailsPanelPro({
    super.key,
    required this.activity,
    this.timelineEntries = const [],
    this.timelineLoading = false,
    this.timelineError,
    this.onFieldChanged,
    this.onAcceptChange,
    this.onRevertChange,
  });

  @override
  State<ActivityDetailsPanelPro> createState() => _ActivityDetailsPanelProState();
}

class _ActivityDetailsPanelProState extends State<ActivityDetailsPanelPro>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _showCatalogSubstitute = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

    final activity = widget.activity!;
    final decisionIssues = _getDecisionIssues(activity);
    final hasBlockers = decisionIssues.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: SaoColors.surface,
        borderRadius: BorderRadius.circular(SaoRadii.md),
        border: Border.all(color: SaoColors.border),
      ),
      child: Column(
        children: [
          _buildStatusRow(activity),
          // Header con Tabs
          Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: SaoColors.border)),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: SaoColors.primary,
              unselectedLabelColor: SaoColors.gray600,
              indicatorColor: SaoColors.primary,
              labelStyle: SaoTypography.buttonText,
              tabs: const [
                Tab(text: 'Detalles'),
                Tab(text: 'Historial'),
                Tab(text: 'Validación Técnica'),
              ],
            ),
          ),
          if (hasBlockers)
            _buildDecisionPill(decisionIssues),
          
          // Contenido de tabs
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: DETALLES
                _buildDetallesTab(activity),
                
                // TAB 2: HISTORIAL
                _buildHistorialTab(activity),
                
                // TAB 3: VALIDACIÓN TÉCNICA
                _buildValidacionTecnicaTab(activity),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(ActivityWithDetails activity) {
    final statusColor = _statusColor(activity.statusColor);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: SaoSpacing.lg,
        vertical: SaoSpacing.sm,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: SaoColors.border),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Validación Técnica',
              style: SaoTypography.caption.copyWith(
                color: SaoColors.gray600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: SaoSpacing.sm,
              vertical: SaoSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(SaoRadii.full),
              border: Border.all(color: statusColor),
            ),
            child: Text(
              activity.statusLabel.toUpperCase(),
              style: SaoTypography.caption.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDecisionPill(List<String> issues) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: SaoSpacing.lg,
        vertical: SaoSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: SaoColors.error.withOpacity(0.08),
        border: Border(
          bottom: BorderSide(color: SaoColors.border),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_rounded, size: 18, color: SaoColors.error),
          SizedBox(width: SaoSpacing.sm),
          Expanded(
            child: Text(
              'NO APROBABLE: ${issues.join(' · ')}',
              style: SaoTypography.caption.copyWith(
                color: SaoColors.error,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Resolver pendientes - pendiente de flujo'),
                  backgroundColor: SaoColors.info,
                ),
              );
            },
            icon: Icon(Icons.playlist_add_check_rounded, size: 16),
            label: Text('Resolver'),
            style: TextButton.styleFrom(
              foregroundColor: SaoColors.error,
              padding: EdgeInsets.symmetric(horizontal: SaoSpacing.sm),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _getDecisionIssues(ActivityWithDetails activity) {
    final issues = <String>[];

    final hasCatalogChange =
        (activity.activity.description ?? '').trim() != 'Descripción original';
    final gpsCritical = activity.activity.status == ActivityStatus.needsFix;
    final checklistPending = activity.activity.status == ActivityStatus.pendingReview;
    final highRisk = (activity.activity.description ?? '')
        .toLowerCase()
        .contains('gasoducto');

    if (gpsCritical) {
      issues.add('Discrepancia GPS critica');
    }
    if (hasCatalogChange) {
      issues.add('Cambio de catalogo pendiente');
    }
    if (checklistPending) {
      issues.add('Checklist de calidad incompleto');
    }
    if (highRisk) {
      issues.add('Actividad en riesgo alto');
    }

    return issues;
  }

  Color _statusColor(String statusKey) {
    switch (statusKey) {
      case 'success':
        return SaoColors.success;
      case 'warning':
        return SaoColors.warning;
      case 'error':
        return SaoColors.error;
      case 'info':
        return SaoColors.info;
      default:
        return SaoColors.gray500;
    }
  }

  // ============================================================
  // TAB 1: DETALLES
  // ============================================================
  Widget _buildDetallesTab(ActivityWithDetails activity) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(SaoSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // BANNER: Gestión de Catálogo (si hay cambios)
          if (activity.activity.description != 'Descripción original') ...[
            Container(
              padding: EdgeInsets.all(SaoSpacing.md),
              decoration: BoxDecoration(
                color: SaoColors.info.withOpacity(0.1),
                border: Border.all(color: SaoColors.info),
                borderRadius: BorderRadius.circular(SaoRadii.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_rounded, color: SaoColors.info),
                      SizedBox(width: SaoSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Campo modificado en campo - Decisión requerida',
                              style: SaoTypography.bodyText
                                  .copyWith(color: SaoColors.primary),
                            ),
                            SizedBox(height: SaoSpacing.xs),
                            Text(
                              activity.activity.description ?? 'Sin descripción',
                              style: SaoTypography.caption.copyWith(
                                color: SaoColors.gray700,
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: SaoSpacing.md),
                  Wrap(
                    spacing: SaoSpacing.sm,
                    runSpacing: SaoSpacing.sm,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () =>
                            widget.onAcceptChange?.call('description'),
                        icon: Icon(Icons.check_rounded),
                        label: Text('Aceptar este cambio'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () =>
                            widget.onRevertChange?.call('description'),
                        icon: Icon(Icons.restore_rounded),
                        label: Text('Restaurar original'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => CatalogSubstitutionModal(
                              currentValue: activity.activity.description ?? 'Sin descripción',
                              fieldName: 'Descripción',
                              onSubstitute: (selectedValue) {
                                widget.onFieldChanged?.call('description', selectedValue);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Descripción actualizada'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                        icon: Icon(Icons.swap_horiz_rounded),
                        label: Text('Elegir de catálogo'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: SaoSpacing.lg),
          ],

          // SECCIÓN: Información Operativa
          Text(
            'INFORMACIÓN OPERATIVA',
            style: SaoTypography.caption
                .copyWith(fontWeight: FontWeight.w600, color: SaoColors.gray600),
          ),
          SizedBox(height: SaoSpacing.md),
          Container(
            padding: EdgeInsets.all(SaoSpacing.md),
            decoration: BoxDecoration(
              color: SaoColors.gray50,
              borderRadius: BorderRadius.circular(SaoRadii.md),
              border: Border.all(color: SaoColors.border),
            ),
            child: Column(
              children: [
                _buildReadOnlyField('Tipo', activity.activityType?.name ?? 'N/A',
                    Icons.category_rounded),
                SizedBox(height: SaoSpacing.md),
                _buildReadOnlyField('Título', activity.activity.title,
                    Icons.title_rounded),
                SizedBox(height: SaoSpacing.md),
                _buildReadOnlyField('Descripción',
                    activity.activity.description ?? 'N/A', Icons.description_rounded),
              ],
            ),
          ),

          SizedBox(height: SaoSpacing.xl),

          // SECCIÓN: Contexto Territorial
          Text(
            'CONTEXTO TERRITORIAL',
            style: SaoTypography.caption
                .copyWith(fontWeight: FontWeight.w600, color: SaoColors.gray600),
          ),
          SizedBox(height: SaoSpacing.md),
          Row(
            children: [
              Expanded(
                child: _buildReadOnlyField(
                    'Proyecto', activity.activity.projectId, Icons.folder_rounded),
              ),
              SizedBox(width: SaoSpacing.lg),
              Expanded(
                child: _buildReadOnlyField('Frente', activity.front?.name ?? 'N/A',
                    Icons.account_tree_rounded),
              ),
            ],
          ),
          SizedBox(height: SaoSpacing.md),
          Row(
            children: [
              Expanded(
                child: _buildReadOnlyField(
                    'PK', activity.front?.name != null ? 'PK 142+000' : 'N/A', Icons.location_on_rounded),
              ),
              SizedBox(width: SaoSpacing.lg),
              Expanded(
                child: _buildReadOnlyField('Municipio',
                    activity.municipality?.name ?? 'N/A', Icons.map_rounded),
              ),
            ],
          ),

          SizedBox(height: SaoSpacing.xl),

          // SECCIÓN: Responsabilidad
          Text(
            'RESPONSABILIDAD',
            style: SaoTypography.caption
                .copyWith(fontWeight: FontWeight.w600, color: SaoColors.gray600),
          ),
          SizedBox(height: SaoSpacing.md),
          _buildReadOnlyField('Ingeniero',
              activity.assignedUser?.fullName ?? 'N/A', Icons.person_rounded),
          SizedBox(height: SaoSpacing.md),
          Row(
            children: [
              Expanded(
                child: _buildReadOnlyField(
                    'Fecha Ejecución',
                    activity.activity.executedAt != null
                        ? DateFormat('dd/MM/yyyy').format(
                            activity.activity.executedAt!)
                        : 'N/A',
                    Icons.calendar_today_rounded),
              ),
              SizedBox(width: SaoSpacing.lg),
              Expanded(
                child: _buildReadOnlyField('Evidencias',
                    '${activity.evidences.length}', Icons.photo_library_rounded),
              ),
            ],
          ),

          SizedBox(height: SaoSpacing.xl),

          // SECCIÓN: GPS vs PK (Validación Crítica)
          if (activity.activity.latitude != null &&
              activity.activity.longitude != null)
            _buildGPSValidationBanner(activity),
        ],
      ),
    );
  }

  // ============================================================
  // TAB 2: HISTORIAL (Timeline)
  // ============================================================
  Widget _buildHistorialTab(ActivityWithDetails activity) {
    if (widget.timelineLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (widget.timelineError != null) {
      return Center(
        child: Text(
          widget.timelineError!,
          style: SaoTypography.bodyText.copyWith(color: SaoColors.error),
        ),
      );
    }

    if (widget.timelineEntries.isEmpty) {
      return Center(
        child: Text(
          'Sin historial disponible',
          style: SaoTypography.bodyText.copyWith(color: SaoColors.gray500),
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(SaoSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < widget.timelineEntries.length; i++) ...[
            _buildTimelineEvent(widget.timelineEntries[i]),
            if (i < widget.timelineEntries.length - 1) _buildTimelineConnector(),
          ],
        ],
      ),
    );
  }

  Widget _buildTimelineEvent(ActivityTimelineEntry entry) {
    final icon = _timelineIcon(entry.action);
    final color = _timelineColor(entry.action);
    final title = _timelineTitle(entry.action);
    final subtitle = entry.actor == null || entry.actor!.trim().isEmpty
        ? 'Sin actor'
        : 'Por: ${entry.actor}';
    final timestamp = DateFormat('dd/MM/yyyy HH:mm').format(entry.at.toLocal());

    return _buildTimelineItem(
      icon: icon,
      color: color,
      title: title,
      subtitle: subtitle,
      timestamp: timestamp,
    );
  }

  IconData _timelineIcon(String action) {
    final key = action.toUpperCase();
    if (key.contains('APPROVE')) return Icons.check_circle_rounded;
    if (key.contains('REJECT')) return Icons.cancel_rounded;
    if (key.contains('CREATE')) return Icons.create_rounded;
    if (key.contains('UPDATE') || key.contains('PATCH')) return Icons.edit_rounded;
    return Icons.history_rounded;
  }

  Color _timelineColor(String action) {
    final key = action.toUpperCase();
    if (key.contains('APPROVE')) return SaoColors.success;
    if (key.contains('REJECT')) return SaoColors.error;
    if (key.contains('CREATE')) return SaoColors.info;
    if (key.contains('UPDATE') || key.contains('PATCH')) return SaoColors.warning;
    return SaoColors.gray500;
  }

  String _timelineTitle(String action) {
    final key = action.trim();
    if (key.isEmpty) return 'Evento';
    return key
        .toLowerCase()
        .split('_')
        .map((part) => part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  // ============================================================
  // TAB 3: VALIDACIÓN TÉCNICA
  // ============================================================
  Widget _buildValidacionTecnicaTab(ActivityWithDetails activity) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(SaoSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CHECKLIST DE CALIDAD',
            style: SaoTypography.caption
                .copyWith(fontWeight: FontWeight.w600, color: SaoColors.gray600),
          ),
          SizedBox(height: SaoSpacing.md),
          _buildChecklistItem('Evidencia clara y legible', isChecked: true),
          _buildChecklistItem('Ubicación GPS válida', isChecked: true),
          _buildChecklistItem(
              'Concepto coincide con catálogo', isChecked: false),
          _buildChecklistItem('Fecha coherente', isChecked: true),
          _buildChecklistItem('Responsable identificado', isChecked: true),

          SizedBox(height: SaoSpacing.xl),

          // ALERTA GPS
          _buildGPSWarningPanel(),
        ],
      ),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  Widget _buildReadOnlyField(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: SaoTypography.caption.copyWith(
            color: SaoColors.gray600,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: SaoSpacing.xs),
        Container(
          padding: EdgeInsets.all(SaoSpacing.md),
          decoration: BoxDecoration(
            color: SaoColors.gray50,
            border: Border.all(color: SaoColors.border),
            borderRadius: BorderRadius.circular(SaoRadii.md),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: SaoColors.gray600),
              SizedBox(width: SaoSpacing.sm),
              Expanded(
                child: Text(
                  value,
                  style: SaoTypography.bodyText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGPSValidationBanner(ActivityWithDetails activity) {
    // Simulamos discrepancia 400m
    const discrepancia = 400;

    return Container(
      padding: EdgeInsets.all(SaoSpacing.md),
      margin: EdgeInsets.only(top: SaoSpacing.lg),
      decoration: BoxDecoration(
        color: discrepancia > 800
            ? SaoColors.error.withOpacity(0.1)
            : SaoColors.warning.withOpacity(0.1),
        border: Border.all(
          color: discrepancia > 800 ? SaoColors.error : SaoColors.warning,
        ),
        borderRadius: BorderRadius.circular(SaoRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.location_on_rounded,
                color: discrepancia > 800 ? SaoColors.error : SaoColors.warning,
              ),
              SizedBox(width: SaoSpacing.sm),
              Expanded(
                child: Text(
                  'GPS a ${discrepancia}m del PK declarado',
                  style: SaoTypography.bodyTextBold.copyWith(
                    color: discrepancia > 800
                        ? SaoColors.error
                        : SaoColors.warning,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: SaoSpacing.md),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  // TODO: Abrir mapa
                },
                icon: Icon(Icons.map_rounded),
                label: Text('Ver en Mapa'),
              ),
              SizedBox(width: SaoSpacing.sm),
              if (discrepancia > 800)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // TODO: Abrir modal de justificación
                    },
                    icon: Icon(Icons.note_add_rounded),
                    label: Text('Agregar Justificación'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SaoColors.error.withOpacity(0.1),
                      foregroundColor: SaoColors.error,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGPSWarningPanel() {
    return Container(
      padding: EdgeInsets.all(SaoSpacing.md),
      decoration: BoxDecoration(
        color: SaoColors.error.withOpacity(0.1),
        border: Border.all(color: SaoColors.error),
        borderRadius: BorderRadius.circular(SaoRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_rounded, color: SaoColors.error),
              SizedBox(width: SaoSpacing.sm),
              Expanded(
                child: Text(
                  'Discrepancia GPS crítica',
                  style: SaoTypography.bodyTextBold
                      .copyWith(color: SaoColors.error),
                ),
              ),
            ],
          ),
          SizedBox(height: SaoSpacing.md),
          Text(
            'La ubicación GPS está a más de 800m del PK declarado. Se requiere justificación técnica antes de aprobar.',
            style: SaoTypography.bodyText.copyWith(color: SaoColors.gray700),
          ),
          SizedBox(height: SaoSpacing.md),
          ElevatedButton.icon(
            onPressed: () {
              // TODO: Modal de justificación
            },
            icon: Icon(Icons.check_circle_rounded),
            label: Text('Agregar Justificación'),
            style: ElevatedButton.styleFrom(
              backgroundColor: SaoColors.error.withOpacity(0.1),
              foregroundColor: SaoColors.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String timestamp,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icono
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        SizedBox(width: SaoSpacing.md),
        // Contenido
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: SaoTypography.bodyTextBold,
              ),
              Text(
                subtitle,
                style: SaoTypography.caption.copyWith(color: SaoColors.gray600),
              ),
              SizedBox(height: SaoSpacing.xs),
              Text(
                timestamp,
                style: SaoTypography.chipText.copyWith(color: SaoColors.gray500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineConnector() {
    return Padding(
      padding: EdgeInsets.only(left: 20, top: 4, bottom: 4),
      child: Container(
        width: 2,
        height: 20,
        color: SaoColors.border,
      ),
    );
  }

  Widget _buildChecklistItem(String label, {required bool isChecked}) {
    return Padding(
      padding: EdgeInsets.only(bottom: SaoSpacing.sm),
      child: Row(
        children: [
          Icon(
            isChecked
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: isChecked ? SaoColors.success : SaoColors.gray400,
          ),
          SizedBox(width: SaoSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: SaoTypography.bodyText.copyWith(
                color: isChecked ? SaoColors.gray700 : SaoColors.gray600,
                decoration:
                    isChecked ? TextDecoration.none : TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}