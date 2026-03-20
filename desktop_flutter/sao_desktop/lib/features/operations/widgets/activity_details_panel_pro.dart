import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../data/models/activity_model.dart';
import '../../../data/catalog/activity_status.dart';
import '../../../data/repositories/catalog_repository.dart';
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
class ActivityDetailsPanelPro extends ConsumerStatefulWidget {
  final ActivityWithDetails? activity;
  final List<ActivityTimelineEntry> timelineEntries;
  final bool timelineLoading;
  final String? timelineError;
  final Function(String field, String value)? onFieldChanged;
  final Function(String field)? onAcceptChange;
  final Function(String field)? onRevertChange;
  final Future<void> Function(String field, String capturedValue)? onCatalogAdd;
  final Future<void> Function(String field, String capturedValue, String selectedValue)? onCatalogLink;
  final Future<void> Function(String field, String capturedValue)? onCatalogCorrection;

  const ActivityDetailsPanelPro({
    super.key,
    required this.activity,
    this.timelineEntries = const [],
    this.timelineLoading = false,
    this.timelineError,
    this.onFieldChanged,
    this.onAcceptChange,
    this.onRevertChange,
    this.onCatalogAdd,
    this.onCatalogLink,
    this.onCatalogCorrection,
  });

  @override
  ConsumerState<ActivityDetailsPanelPro> createState() => _ActivityDetailsPanelProState();
}

class _ActivityDetailsPanelProState extends ConsumerState<ActivityDetailsPanelPro>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _quickTitleController;
  late TextEditingController _quickDescriptionController;
  String? _subcategoriaLink;
  String? _temaLink;
  String? _propositoLink;
  String? _municipioLink;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _quickTitleController = TextEditingController();
    _quickDescriptionController = TextEditingController();
    _syncEditorsWithActivity(widget.activity);
    _ensureCatalogLoaded(widget.activity);
  }

  @override
  void didUpdateWidget(covariant ActivityDetailsPanelPro oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activity?.activity.id != widget.activity?.activity.id) {
      _syncEditorsWithActivity(widget.activity);
      _ensureCatalogLoaded(widget.activity);
    }
  }

  Future<void> _ensureCatalogLoaded(ActivityWithDetails? activity) async {
    if (activity == null) return;
    final projectId = activity.activity.projectId.trim();
    if (projectId.isEmpty) return;
    final catalogRepo = ref.read(catalogRepositoryProvider);
    // Only reload if not yet ready or project changed
    if (!catalogRepo.isReady ||
        catalogRepo.projectId != projectId.toUpperCase()) {
      await catalogRepo.loadProject(projectId);
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _quickTitleController.dispose();
    _quickDescriptionController.dispose();
    super.dispose();
  }

  void _syncEditorsWithActivity(ActivityWithDetails? activity) {
    final title = activity?.activity.title ?? '';
    final description = activity?.activity.description ?? '';
    _quickTitleController.text = title;
    _quickDescriptionController.text = description;

    _subcategoriaLink = null;
    _temaLink = null;
    _propositoLink = null;
    _municipioLink =
        _extractLinkedMunicipality(description) ?? activity?.municipality?.name;
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
          _buildValidationStepper(activity),
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

  Widget _buildValidationStepper(ActivityWithDetails activity) {
    final hasOperationalData =
        activity.activity.title.trim().isNotEmpty &&
        activity.activity.description?.trim().isNotEmpty == true;
    final catalogResolved = !_hasCatalogGap(activity);
    final hasEvidence = activity.evidences.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: SaoSpacing.lg,
        vertical: SaoSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: SaoColors.gray50,
        border: Border(bottom: BorderSide(color: SaoColors.border)),
      ),
      child: Row(
        children: [
          _buildStepNode(
            title: 'Datos operativos',
            done: hasOperationalData,
            index: 1,
          ),
          _buildStepConnector(done: hasOperationalData),
          _buildStepNode(
            title: 'Clasificación y catálogos',
            done: catalogResolved,
            index: 2,
          ),
          _buildStepConnector(done: catalogResolved),
          _buildStepNode(
            title: 'Evidencia técnica',
            done: hasEvidence,
            index: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildStepNode({
    required String title,
    required bool done,
    required int index,
  }) {
    final color = done ? SaoColors.success : SaoColors.warning;
    return Expanded(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: color),
            ),
            child: Center(
              child: done
                  ? const Icon(Icons.check, size: 12, color: SaoColors.success)
                  : Text(
                      '$index',
                      style: SaoTypography.caption.copyWith(
                        color: SaoColors.warning,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
          SizedBox(width: SaoSpacing.xs),
          Expanded(
            child: Text(
              title,
              style: SaoTypography.caption.copyWith(
                color: SaoColors.gray700,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepConnector({required bool done}) {
    return Container(
      width: 16,
      height: 2,
      margin: EdgeInsets.symmetric(horizontal: SaoSpacing.xs),
      color: done ? SaoColors.success : SaoColors.border,
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
          _buildCatalogDecisionModule(activity),
          SizedBox(height: SaoSpacing.lg),

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
                _buildQuickEditField(
                  label: 'Título',
                  icon: Icons.title_rounded,
                  controller: _quickTitleController,
                  onSave: () => widget.onFieldChanged?.call(
                    'title',
                    _quickTitleController.text.trim(),
                  ),
                ),
                SizedBox(height: SaoSpacing.md),
                _buildQuickEditField(
                  label: 'Descripción',
                  icon: Icons.description_rounded,
                  controller: _quickDescriptionController,
                  maxLines: 2,
                  minLines: 2,
                  onSave: () => widget.onFieldChanged?.call(
                    'description',
                    _quickDescriptionController.text.trim(),
                  ),
                ),
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
                    'PK',
                    activity.pkLabel?.isNotEmpty == true
                        ? activity.pkLabel!
                        : 'Sin PK',
                    Icons.location_on_rounded),
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
    final checklist = <({String label, bool ok})>[
      (
        label: '¿Tiene coordenadas GPS?',
        ok: activity.activity.latitude != null && activity.activity.longitude != null,
      ),
      (
        label: '¿La descripción tiene más de 20 caracteres?',
        ok: (activity.activity.description ?? '').trim().length >= 20,
      ),
      (
        label: '¿La subcategoría es válida en catálogo?',
        ok: !_hasCatalogGap(activity),
      ),
      (
        label: '¿Tiene evidencia técnica?',
        ok: activity.evidences.isNotEmpty,
      ),
      (
        label: '¿PK y ubicación operativa están informados?',
        ok: (activity.activity.description ?? '').toLowerCase().contains('pk'),
      ),
    ];

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
            ...checklist.map((item) => _buildChecklistItem(item.label, isChecked: item.ok)),

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

  Widget _buildQuickEditField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required VoidCallback onSave,
    int minLines = 1,
    int maxLines = 1,
  }) {
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
          padding: EdgeInsets.all(SaoSpacing.sm),
          decoration: BoxDecoration(
            color: SaoColors.gray50,
            border: Border.all(color: SaoColors.border),
            borderRadius: BorderRadius.circular(SaoRadii.md),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Icon(icon, size: 18, color: SaoColors.gray600),
              ),
              SizedBox(width: SaoSpacing.sm),
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: minLines,
                  maxLines: maxLines,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'Editar valor...',
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Guardar cambio rápido',
                onPressed: onSave,
                icon: const Icon(Icons.save_rounded, size: 18),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCatalogDecisionModule(ActivityWithDetails activity) {
    final payload = activity.wizardPayload;
    final payloadSubcategory = _wizardPayloadText(payload, const ['subcategory', 'name']);
    final payloadTemaPrimary = _wizardPayloadText(payload, const ['topics', '0', 'name']);
    final payloadPurpose = _wizardPayloadText(payload, const ['purpose', 'name']);
    final payloadMunicipio = _wizardPayloadText(payload, const ['location', 'municipio']);

    final capturedSubcategoria =
      (payloadSubcategory ??
          _extractLabeledField(activity.activity.description, const [
                  'Subcategoría',
                  'Subcategoria',
          ]) ??
                activity.activity.title)
            .trim();
    final capturedTema =
      (payloadTemaPrimary ??
          _extractLabeledField(activity.activity.description, const [
                  'Tema',
                  'Temas',
                ]) ??
                '')
            .trim();
    final capturedProposito =
      (payloadPurpose ?? _extractPurposeFromDescription(activity.activity.description)).trim();
    final capturedMunicipio =
      (payloadMunicipio ??
          _extractLinkedMunicipality(activity.activity.description) ??
                activity.municipality?.name ??
                'Sin municipio')
            .trim();

    // Load real catalog options for current activity type
    final catalogRepo = ref.read(catalogRepositoryProvider);
    final subcatOptions = _resolveSubcategoryOptions(catalogRepo, activity);
    final temaOptions   = _resolveTemaOptions(catalogRepo, activity);
    final propOptions   = _resolvePurposeOptions(catalogRepo, activity);
    final munOptions    = catalogRepo.getMunicipalities();

    return Container(
      padding: EdgeInsets.all(SaoSpacing.md),
      decoration: BoxDecoration(
        color: SaoColors.info.withOpacity(0.06),
        border: Border.all(color: SaoColors.info.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(SaoRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.hub_rounded, color: SaoColors.primary),
              SizedBox(width: SaoSpacing.sm),
              Expanded(
                child: Text(
                  'Decisión de Catálogo',
                  style: SaoTypography.bodyTextBold.copyWith(
                    color: SaoColors.primary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: SaoSpacing.md),
          _buildCatalogDecisionRow(
            fieldLabel: 'Subcategoría',
            capturedValue: capturedSubcategoria,
            linkedValue: _subcategoriaLink,
            options: subcatOptions,
            onLinkChanged: (v) => setState(() => _subcategoriaLink = v),
            onLinkToExisting: (selected) async {
              await widget.onCatalogLink?.call('subcategoria', capturedSubcategoria, selected);
            },
            onAddToCatalog: () async {
              await widget.onCatalogAdd?.call('subcategoria', capturedSubcategoria);
            },
            onRequestCorrection: () async {
              await widget.onCatalogCorrection?.call('subcategoria', capturedSubcategoria);
            },
          ),
          SizedBox(height: SaoSpacing.sm),
          _buildCatalogDecisionRow(
            fieldLabel: 'Tema',
            capturedValue: capturedTema.isEmpty
                ? 'Sin tema capturado'
                : capturedTema,
            linkedValue: _temaLink,
            options: temaOptions,
            onLinkChanged: (v) => setState(() => _temaLink = v),
            onLinkToExisting: (selected) async {
              await widget.onCatalogLink?.call('tema', capturedTema, selected);
            },
            onAddToCatalog: () async {
              await widget.onCatalogAdd?.call('tema', capturedTema);
            },
            onRequestCorrection: () async {
              await widget.onCatalogCorrection?.call('tema', capturedTema);
            },
          ),
          SizedBox(height: SaoSpacing.sm),
          _buildCatalogDecisionRow(
            fieldLabel: 'Propósito',
            capturedValue: capturedProposito.isEmpty ? 'Sin propósito capturado' : capturedProposito,
            linkedValue: _propositoLink,
            options: propOptions,
            onLinkChanged: (v) => setState(() => _propositoLink = v),
            onLinkToExisting: (selected) async {
              await widget.onCatalogLink?.call('proposito', capturedProposito, selected);
            },
            onAddToCatalog: () async {
              await widget.onCatalogAdd?.call('proposito', capturedProposito);
            },
            onRequestCorrection: () async {
              await widget.onCatalogCorrection?.call('proposito', capturedProposito);
            },
          ),
          SizedBox(height: SaoSpacing.sm),
          _buildCatalogDecisionRow(
            fieldLabel: 'Municipio',
            capturedValue: capturedMunicipio,
            linkedValue: _municipioLink,
            options: munOptions,
            onLinkChanged: (v) => setState(() => _municipioLink = v),
            onLinkToExisting: (selected) async {
              await widget.onCatalogLink?.call('municipio', capturedMunicipio, selected);
            },
            onAddToCatalog: () async {
              await widget.onCatalogAdd?.call('municipio', capturedMunicipio);
            },
            onRequestCorrection: () async {
              await widget.onCatalogCorrection?.call('municipio', capturedMunicipio);
            },
          ),
          SizedBox(height: SaoSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _HotkeyPill(label: 'A', hint: 'Aceptar'),
              _HotkeyPill(label: 'C', hint: 'Catálogo'),
              _HotkeyPill(label: 'R', hint: 'Corrección'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCatalogDecisionRow({
    required String fieldLabel,
    required String capturedValue,
    required String? linkedValue,
    required List<String> options,
    required ValueChanged<String?> onLinkChanged,
    required Future<void> Function(String selectedValue) onLinkToExisting,
    required Future<void> Function() onAddToCatalog,
    required Future<void> Function() onRequestCorrection,
  }) {
    final normalizedCaptured = capturedValue.trim().toLowerCase();
    final isNewValue = normalizedCaptured.isNotEmpty &&
        !options.map((o) => o.toLowerCase()).contains(normalizedCaptured);

    return Container(
      padding: EdgeInsets.all(SaoSpacing.sm),
      decoration: BoxDecoration(
        color: isNewValue
            ? SaoColors.warning.withOpacity(0.12)
            : SaoColors.surface,
        border: Border.all(
          color: isNewValue ? SaoColors.warning : SaoColors.border,
        ),
        borderRadius: BorderRadius.circular(SaoRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fieldLabel,
            style: SaoTypography.caption.copyWith(
              color: SaoColors.gray700,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: SaoSpacing.xs),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(SaoSpacing.sm),
                  decoration: BoxDecoration(
                    color: SaoColors.gray50,
                    borderRadius: BorderRadius.circular(SaoRadii.sm),
                    border: Border.all(color: SaoColors.border),
                  ),
                  child: Text(
                    'Valor capturado: "$capturedValue"',
                    style: SaoTypography.caption.copyWith(
                      color: SaoColors.gray700,
                    ),
                  ),
                ),
              ),
              SizedBox(width: SaoSpacing.sm),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: linkedValue,
                  isExpanded: true,
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: 'Vincular a existente',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(SaoRadii.sm),
                    ),
                  ),
                  items: options
                      .map((option) => DropdownMenuItem<String>(
                            value: option,
                            child: Text(option),
                          ))
                      .toList(growable: false),
                  onChanged: onLinkChanged,
                ),
              ),
            ],
          ),
          SizedBox(height: SaoSpacing.sm),
          Wrap(
            spacing: SaoSpacing.sm,
            runSpacing: SaoSpacing.sm,
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  await onAddToCatalog();
                },
                icon: const Icon(Icons.add_box_rounded, size: 16),
                label: const Text('Agregar al catálogo'),
              ),
              FilledButton.icon(
                onPressed: linkedValue == null
                    ? null
                    : () async {
                        await onLinkToExisting(linkedValue);
                      },
                icon: const Icon(Icons.link_rounded, size: 16),
                label: const Text('Vincular existente'),
              ),
              OutlinedButton.icon(
                onPressed: () => _showFieldCatalogModal(
                  fieldLabel: fieldLabel,
                  capturedValue: capturedValue,
                  options: options,
                  onSelect: onLinkToExisting,
                ),
                icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                label: const Text('Elegir catálogo'),
              ),
              TextButton.icon(
                onPressed: () async {
                  await onRequestCorrection();
                },
                icon: const Icon(Icons.report_gmailerrorred_rounded, size: 16),
                label: const Text('Solicitar corrección'),
                style: TextButton.styleFrom(
                  foregroundColor: SaoColors.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<String> _resolveSubcategoryOptions(
    CatalogRepository catalogRepo,
    ActivityWithDetails activity,
  ) {
    final optionSet = <String>{};

    for (final key in _catalogLookupKeys(activity)) {
      for (final item in catalogRepo.subcategoriesFor(key)) {
        final name = item.name.trim();
        if (name.isNotEmpty) optionSet.add(name);
      }
      if (optionSet.isNotEmpty) {
        // Keep most relevant match first: stop when a key already resolved options.
        break;
      }
    }

    if (optionSet.isNotEmpty) {
      return optionSet.toList(growable: false);
    }

    // Fallback: if mapping by activity id/code failed, expose active subcategories
    // so the reviewer can still resolve the catalog mismatch.
    return catalogRepo.data.subcategories
        .where((entry) => entry.isActive)
        .map((entry) => entry.name.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  List<String> _resolveTemaOptions(
    CatalogRepository catalogRepo,
    ActivityWithDetails activity,
  ) {
    final optionSet = <String>{};

    for (final key in _catalogLookupKeys(activity)) {
      for (final item in catalogRepo.temasSugeridosFor(key)) {
        final name = item.name.trim();
        if (name.isNotEmpty) optionSet.add(name);
      }
      if (optionSet.isNotEmpty) {
        break;
      }
    }

    if (optionSet.isNotEmpty) {
      return optionSet.toList(growable: false);
    }

    return catalogRepo.data.topics
        .where((entry) => entry.isActive)
        .map((entry) => entry.name.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  List<String> _resolvePurposeOptions(
    CatalogRepository catalogRepo,
    ActivityWithDetails activity,
  ) {
    final optionSet = <String>{};

    for (final key in _catalogLookupKeys(activity)) {
      for (final item in catalogRepo.purposesFor(activityId: key)) {
        final name = item.name.trim();
        if (name.isNotEmpty) optionSet.add(name);
      }
      if (optionSet.isNotEmpty) {
        break;
      }
    }

    if (optionSet.isNotEmpty) {
      return optionSet.toList(growable: false);
    }

    return catalogRepo.data.purposes
        .where((entry) => entry.isActive)
        .map((entry) => entry.name.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  String _extractPurposeFromDescription(String? description) {
    final labeledPurpose = _extractLabeledField(
      description,
      const ['Propósito', 'Proposito'],
    );
    if (labeledPurpose != null && labeledPurpose.trim().isNotEmpty) {
      return labeledPurpose.trim();
    }

    final raw = (description ?? '').trim();
    if (raw.isEmpty) return '';

    final lines = raw
        .split(RegExp(r'[\n|]'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .where(
          (line) =>
              !line.toLowerCase().startsWith('actividad:') &&
              !line.toLowerCase().startsWith('subcategoría:') &&
              !line.toLowerCase().startsWith('subcategoria:') &&
              !line.toLowerCase().startsWith('tema:') &&
              !line.toLowerCase().startsWith('temas:') &&
              !line.toLowerCase().startsWith('resultado:') &&
              !line.toLowerCase().startsWith('municipio vinculado:') &&
              !line.toLowerCase().startsWith('municipio validado:'),
        )
        .toList(growable: false);
    return lines.join('\n').trim();
  }

  String? _extractLabeledField(String? description, List<String> labels) {
    final raw = (description ?? '').trim();
    if (raw.isEmpty || labels.isEmpty) return null;

    final normalizedLabels = labels
        .map(_normalizeLabelToken)
        .where((label) => label.isNotEmpty)
        .toList(growable: false);
    if (normalizedLabels.isEmpty) return null;

    for (final chunk in raw.split(RegExp(r'[\n|]'))) {
      final trimmed = chunk.trim();
      if (trimmed.isEmpty) continue;

      final separator = trimmed.indexOf(':');
      if (separator <= 0 || separator >= trimmed.length - 1) continue;

      final key = _normalizeLabelToken(trimmed.substring(0, separator).trim());
      if (!normalizedLabels.contains(key)) continue;

      final value = trimmed.substring(separator + 1).trim();
      if (value.isNotEmpty) return value;
    }
    return null;
  }

  String _normalizeLabelToken(String value) {
    return value
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u');
  }

  String? _wizardPayloadText(Map<String, dynamic>? payload, List<String> path) {
    if (payload == null || path.isEmpty) return null;
    dynamic current = payload;
    for (final key in path) {
      if (current is Map<String, dynamic>) {
        current = current[key];
      } else if (current is List) {
        final index = int.tryParse(key);
        if (index == null || index < 0 || index >= current.length) {
          return null;
        }
        current = current[index];
      } else {
        return null;
      }
    }

    final value = current?.toString().trim();
    if (value == null || value.isEmpty || value == 'null') {
      return null;
    }
    return value;
  }

  String? _extractLinkedMunicipality(String? description) {
    final raw = (description ?? '').trim();
    if (raw.isEmpty) return null;
    for (final line in raw.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.toLowerCase().startsWith('municipio vinculado:')) {
        final value = trimmed.substring('municipio vinculado:'.length).trim();
        if (value.isNotEmpty) return value;
      }
      if (trimmed.toLowerCase().startsWith('municipio validado:')) {
        final value = trimmed.substring('municipio validado:'.length).trim();
        if (value.isNotEmpty) return value;
      }
    }
    return null;
  }

  List<String> _catalogLookupKeys(ActivityWithDetails activity) {
    final keys = <String>{};

    void addKey(String? raw) {
      final value = (raw ?? '').trim();
      if (value.isEmpty) return;
      keys.add(value);
      keys.add(value.toUpperCase());
      keys.add(value.toLowerCase());

      final upper = value.toUpperCase();
      if (upper.startsWith('ACT-TYPE-') && value.length > 9) {
        final stripped = value.substring(9).trim();
        if (stripped.isNotEmpty) {
          keys.add(stripped);
          keys.add(stripped.toUpperCase());
          keys.add(stripped.toLowerCase());
        }
      }
    }

    addKey(activity.activityType?.id);
    addKey(activity.activityType?.code);
    addKey(activity.activityType?.name);
    return keys.toList(growable: false);
  }

  bool _hasCatalogGap(ActivityWithDetails activity) {
    final title = activity.activity.title.trim().toLowerCase();
    final description = (activity.activity.description ?? '').trim().toLowerCase();
    return title == 'otro' ||
        description.contains('no existe en catalogo') ||
        activity.flags.catalogChanged ||
        activity.flags.checklistIncomplete;
  }

  Widget _buildGPSValidationBanner(ActivityWithDetails activity) {
    final hasMismatch = activity.flags.gpsMismatch;
    final message = hasMismatch
        ? 'GPS con discrepancia respecto al PK declarado'
        : 'GPS consistente con el PK declarado';

    return Container(
      padding: EdgeInsets.all(SaoSpacing.md),
      margin: EdgeInsets.only(top: SaoSpacing.lg),
      decoration: BoxDecoration(
        color: hasMismatch
            ? SaoColors.warning.withOpacity(0.1)
            : SaoColors.success.withOpacity(0.08),
        border: Border.all(
          color: hasMismatch ? SaoColors.warning : SaoColors.success,
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
                color: hasMismatch ? SaoColors.warning : SaoColors.success,
              ),
              SizedBox(width: SaoSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: SaoTypography.bodyTextBold.copyWith(
                    color: hasMismatch ? SaoColors.warning : SaoColors.success,
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
              if (hasMismatch)
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
                : Icons.cancel_rounded,
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

  void _showFieldCatalogModal({
    required String fieldLabel,
    required String capturedValue,
    required List<String> options,
    required Future<void> Function(String selectedValue) onSelect,
  }) {
    final items = options
        .map((name) => CatalogItem(
              id: name,
              code: name,
              name: name,
              category: fieldLabel,
              description: '',
              standards: const [],
              isRecommended: false,
            ))
        .toList();

    showDialog(
      context: context,
      builder: (context) => CatalogSubstitutionModal(
        currentValue: capturedValue,
        fieldName: fieldLabel,
        items: items,
        onSubstitute: (selectedValue) {
          onSelect(selectedValue);
        },
      ),
    );
  }
}

class _HotkeyPill extends StatelessWidget {
  final String label;
  final String hint;

  const _HotkeyPill({required this.label, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: SaoColors.gray100,
        borderRadius: BorderRadius.circular(SaoRadii.sm),
        border: Border.all(color: SaoColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: SaoColors.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: SaoColors.border),
            ),
            child: Text(
              label,
              style: SaoTypography.caption.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            hint,
            style: SaoTypography.caption.copyWith(color: SaoColors.gray600),
          ),
        ],
      ),
    );
  }
}