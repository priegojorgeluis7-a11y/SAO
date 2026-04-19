import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../data/models/activity_model.dart';
import '../../../data/catalog/activity_status.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../data/repositories/assignments_repository.dart';
import '../../../ui/theme/sao_colors.dart';
import '../../../ui/theme/sao_spacing.dart';
import '../../../ui/theme/sao_radii.dart';
import '../../../ui/theme/sao_typography.dart';
import '../activity_queue_projection.dart';
import 'catalog_substitution_modal.dart';
import 'flag_resolution_dialog.dart';

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
  final Future<void> Function(
      String field, String capturedValue, String selectedValue)? onCatalogLink;
  final Future<void> Function(String field, String capturedValue)?
      onCatalogCorrection;

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
  ConsumerState<ActivityDetailsPanelPro> createState() =>
      _ActivityDetailsPanelProState();
}

class _ActivityDetailsPanelProState
    extends ConsumerState<ActivityDetailsPanelPro>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _quickTitleController;
  late TextEditingController _quickDescriptionController;
  String? _subcategoriaLink;
  String? _temaLink;
  String? _propositoLink;
  String? _municipioLink;
  final Set<String> _expandedCatalogFields = <String>{};
  List<String> _projectCoverageMunicipalities = const [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _quickTitleController = TextEditingController();
    _quickDescriptionController = TextEditingController();
    _syncEditorsWithActivity(widget.activity);
    _ensureCatalogLoaded(widget.activity);
    _ensureProjectCoverageLoaded(widget.activity);
  }

  @override
  void didUpdateWidget(covariant ActivityDetailsPanelPro oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activity?.activity.id != widget.activity?.activity.id) {
      _syncEditorsWithActivity(widget.activity);
      _ensureCatalogLoaded(widget.activity);
      _ensureProjectCoverageLoaded(widget.activity);
    }
  }

  Future<void> _ensureCatalogLoaded(ActivityWithDetails? activity) async {
    if (activity == null) return;
    final projectId = activity.activity.projectId.trim();
    if (projectId.isEmpty) return;
    final catalogRepo = ref.read(catalogRepositoryProvider);
    if (!catalogRepo.isReady ||
        catalogRepo.projectId != projectId.toUpperCase()) {
      await catalogRepo.loadProject(projectId);
      if (mounted) setState(() {});
    }
  }

  Future<void> _ensureProjectCoverageLoaded(
      ActivityWithDetails? activity) async {
    if (activity == null) return;
    final projectId = activity.activity.projectId.trim();
    if (projectId.isEmpty) return;

    try {
      final repo = ref.read(assignmentsRepositoryProvider);
      final coverageByFront = await repo.getFrontCoverageByFront(projectId);

      final preferredKeys = <String>{
        activity.front?.id.trim() ?? '',
        activity.front?.name.trim() ?? '',
      }..removeWhere((item) => item.isEmpty);

      final normalizedMap = <String, List<AssignmentFrontCoverageOption>>{};
      coverageByFront.forEach((key, value) {
        normalizedMap[key.trim().toLowerCase()] = value;
      });

      final selectedCoverage = <AssignmentFrontCoverageOption>[];
      for (final key in preferredKeys) {
        final entries = normalizedMap[key.toLowerCase()] ??
            const <AssignmentFrontCoverageOption>[];
        if (entries.isNotEmpty) {
          selectedCoverage.addAll(entries);
        }
      }

      final source = selectedCoverage.isNotEmpty
          ? selectedCoverage
          : normalizedMap.values.expand((items) => items);

      final municipalitiesByKey = <String, String>{};
      for (final entry in source) {
        final municipio = entry.municipio.trim();
        if (municipio.isEmpty) continue;
        municipalitiesByKey.putIfAbsent(
            municipio.toLowerCase(), () => municipio);
      }

      final municipalities = municipalitiesByKey.values.toList(growable: false)
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      if (mounted) {
        setState(() {
          _projectCoverageMunicipalities = municipalities;
        });
      }
    } catch (_) {
      // keep graceful fallback
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
    _expandedCatalogFields.clear();
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
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: SaoColors.border)),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: SaoColors.primary,
              unselectedLabelColor: SaoColors.gray600,
              indicatorColor: SaoColors.primary,
              labelStyle: SaoTypography.buttonText,
              tabs: const [
                Tab(text: '1. Revisar datos'),
                Tab(text: '2. Historial'),
                Tab(text: '3. Resolver técnico'),
              ],
            ),
          ),
          _buildValidationStepper(activity),
          _buildActionGuide(activity, decisionIssues),
          if (hasBlockers) _buildDecisionPill(decisionIssues),

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
    final normalizedStatus = ActivityStatus.normalize(
      deriveActivityQueueStatus(activity),
    );
    final statusKey = switch (normalizedStatus) {
      ActivityStatus.approved => 'success',
      ActivityStatus.rejected => 'error',
      ActivityStatus.needsFix => 'info',
      ActivityStatus.corrected => 'info',
      ActivityStatus.conflict => 'warning',
      _ => 'warning',
    };
    final statusColor = _statusColor(statusKey);
    final statusLabel = deriveActivityQueueStatusLabel(activity).toUpperCase();
    final statusMessage = deriveActivityQueueStatusMessage(activity);
    final statusIcon = switch (normalizedStatus) {
      ActivityStatus.approved => Icons.check_circle_rounded,
      ActivityStatus.rejected => Icons.cancel_rounded,
      ActivityStatus.needsFix => Icons.edit_note_rounded,
      ActivityStatus.corrected => Icons.autorenew_rounded,
      ActivityStatus.conflict => Icons.warning_amber_rounded,
      _ => Icons.pending_actions_rounded,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: SaoSpacing.lg,
        vertical: SaoSpacing.md,
      ),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.08),
        border: const Border(
          bottom: BorderSide(color: SaoColors.border),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(SaoSpacing.xs),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(SaoRadii.md),
            ),
            child: Icon(statusIcon, size: 18, color: statusColor),
          ),
          const SizedBox(width: SaoSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Validación Técnica',
                  style: SaoTypography.caption.copyWith(
                    color: SaoColors.gray600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  statusMessage,
                  style: SaoTypography.caption.copyWith(
                    color: SaoColors.gray700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: SaoSpacing.sm,
              vertical: SaoSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(SaoRadii.full),
              border: Border.all(color: statusColor),
            ),
            child: Text(
              statusLabel,
              style: SaoTypography.caption.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDecisionPill(List<String> issues) {
    final totalIssues = issues.length;
    final preview = issues.take(2).join(' · ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: SaoSpacing.lg,
        vertical: SaoSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: SaoColors.error.withValues(alpha: 0.08),
        border: Border(
          bottom: BorderSide(
            color: SaoColors.error.withValues(alpha: 0.18),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: SaoColors.error,
            size: 18,
          ),
          const SizedBox(width: SaoSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  totalIssues == 1
                      ? 'Hay 1 pendiente por resolver.'
                      : 'Hay $totalIssues pendientes por resolver.',
                  style: SaoTypography.caption.copyWith(
                    color: SaoColors.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: SaoSpacing.xs),
                Text(
                  preview.isEmpty
                      ? 'Faltan validaciones técnicas por resolver antes de aprobar.'
                      : 'Faltan validaciones técnicas por resolver antes de aprobar. $preview',
                  style: SaoTypography.caption.copyWith(
                    color: SaoColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionGuide(ActivityWithDetails activity, List<String> issues) {
    final hasCatalogChange = _hasCatalogGap(activity);
    final hasEvidence = activity.evidences.isNotEmpty;
    final readyToApprove = issues.isEmpty;
    final accentColor = readyToApprove ? SaoColors.success : SaoColors.primary;
    final nextAction = readyToApprove
        ? 'Revisa la evidencia y presiona “Validar y enviar”.'
        : hasCatalogChange
            ? 'Primero vincula o corrige los campos de catálogo marcados.'
            : !hasEvidence
                ? 'Primero espera o confirma la evidencia técnica.'
                : 'Revisa la evidencia y luego decide si validas o solicitas corrección.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: SaoSpacing.lg,
        vertical: SaoSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.05),
        border: const Border(
          bottom: BorderSide(color: SaoColors.border),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.route_rounded, size: 16, color: accentColor),
          const SizedBox(width: SaoSpacing.sm),
          Expanded(
            child: Text(
              'Qué hacer ahora: $nextAction',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: SaoTypography.caption.copyWith(
                color: SaoColors.gray700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: SaoSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: SaoSpacing.sm,
              vertical: SaoSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(SaoRadii.full),
            ),
            child: Text(
              readyToApprove ? 'Lista para aprobar' : '${issues.length} pendiente(s)',
              style: SaoTypography.caption.copyWith(
                color: accentColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValidationStepper(ActivityWithDetails activity) {
    final hasOperationalData = activity.activity.title.trim().isNotEmpty &&
        activity.activity.description?.trim().isNotEmpty == true;
    final catalogResolved = !_hasCatalogGap(activity);
    final hasEvidence = activity.evidences.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: SaoSpacing.lg,
        vertical: SaoSpacing.sm,
      ),
      decoration: const BoxDecoration(
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
              color: color.withValues(alpha: 0.15),
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
          const SizedBox(width: SaoSpacing.xs),
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SaoTypography.caption.copyWith(
                color: done ? SaoColors.gray700 : SaoColors.gray600,
                fontWeight: done ? FontWeight.w700 : FontWeight.w600,
              ),
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
      margin: const EdgeInsets.symmetric(horizontal: SaoSpacing.xs),
      color: done ? SaoColors.success : SaoColors.border,
    );
  }

  List<String> _getDecisionIssues(ActivityWithDetails activity) {
    final issues = <String>[
      ...deriveActivityBlockingIssues(activity),
    ];

    final hasCatalogChange = _hasCatalogGap(activity);
    final checklistPending = activity.flags.checklistIncomplete;
    final highRisk = (activity.activity.description ?? '')
        .toLowerCase()
        .contains('gasoducto');

    if (hasCatalogChange && !issues.contains('Cambio de catálogo pendiente')) {
      issues.add('Cambio de catálogo pendiente');
    }
    if (checklistPending && issues.isEmpty) {
      issues.add('Checklist técnico incompleto o con datos obligatorios faltantes');
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        final isWide = availableWidth >= 900;
        final halfWidth = isWide
            ? (availableWidth - SaoSpacing.md) / 2
            : availableWidth;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(SaoSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'RESUMEN OPERATIVO',
                style: SaoTypography.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: SaoColors.gray600,
                ),
              ),
              const SizedBox(height: SaoSpacing.sm),
              Wrap(
                spacing: SaoSpacing.md,
                runSpacing: SaoSpacing.md,
                children: [
                  SizedBox(
                    width: halfWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DATOS EDITABLES',
                          style: SaoTypography.caption.copyWith(
                            fontWeight: FontWeight.w700,
                            color: SaoColors.gray600,
                          ),
                        ),
                        const SizedBox(height: SaoSpacing.sm),
                        _buildSummaryGroup(
                          title: 'Edición rápida',
                          subtitle: 'Ajusta el texto capturado y guarda al momento.',
                          icon: Icons.edit_note_rounded,
                          accentColor: SaoColors.actionPrimary,
                          children: [
                            _buildQuickEditField(
                              label: 'Título',
                              icon: Icons.title_rounded,
                              controller: _quickTitleController,
                              onSave: () => widget.onFieldChanged?.call(
                                'title',
                                _quickTitleController.text.trim(),
                              ),
                              dense: true,
                              toneColor: SaoColors.actionPrimary,
                            ),
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
                              dense: true,
                              toneColor: SaoColors.actionPrimary,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: halfWidth,
                    child: _buildSummaryGroup(
                      title: 'Ubicación operativa',
                      subtitle: 'Referencia territorial y frente asignado.',
                      icon: Icons.place_rounded,
                      accentColor: SaoColors.success,
                      children: [
                        _buildReadOnlyField(
                          'Frente',
                          activity.front?.name ?? 'N/A',
                          Icons.account_tree_rounded,
                          dense: true,
                          toneColor: SaoColors.success,
                        ),
                        _buildReadOnlyField(
                          'Municipio',
                          activity.municipality?.name ?? 'N/A',
                          Icons.map_rounded,
                          dense: true,
                          toneColor: SaoColors.success,
                        ),
                        _buildReadOnlyField(
                          'Estado',
                          _resolveLocationStateLabel(activity),
                          Icons.public_rounded,
                          dense: true,
                          toneColor: SaoColors.success,
                        ),
                        _buildReadOnlyField(
                          'Colonia',
                          _resolveLocationColonyLabel(activity),
                          Icons.home_work_rounded,
                          dense: true,
                          toneColor: SaoColors.success,
                          maxLines: 2,
                        ),
                        _buildReadOnlyField(
                          'PK',
                          activity.pkLabel?.isNotEmpty == true
                              ? activity.pkLabel!
                              : 'Sin PK',
                          Icons.location_on_rounded,
                          dense: true,
                          toneColor: SaoColors.success,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: halfWidth,
                    child: _buildSummaryGroup(
                      title: 'Identidad de actividad',
                      subtitle: 'Qué se capturó y cómo debe mostrarse.',
                      icon: Icons.badge_rounded,
                      accentColor: SaoColors.info,
                      children: [
                        _buildReadOnlyField(
                          'Tipo',
                          _resolveActivityTypeLabel(activity),
                          Icons.category_rounded,
                          dense: true,
                          toneColor: SaoColors.info,
                        ),
                        _buildReadOnlyField(
                          'Proyecto',
                          activity.activity.projectId,
                          Icons.folder_rounded,
                          dense: true,
                          toneColor: SaoColors.info,
                        ),
                        _buildReadOnlyField(
                          'Personal',
                          _resolveAssignedPersonLabel(activity),
                          Icons.person_rounded,
                          dense: true,
                          toneColor: SaoColors.info,
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: SaoSpacing.md),
              _buildCatalogDecisionModule(activity),
              const SizedBox(height: SaoSpacing.md),
              _buildSummaryGroup(
                title: 'Seguimiento y evidencia',
                subtitle: 'Lo clave para decidir rápido.',
                icon: Icons.rule_folder_rounded,
                accentColor: SaoColors.warning,
                children: [
                  _buildReadOnlyField(
                    'Fecha ejecución',
                    activity.activity.executedAt != null
                        ? DateFormat('dd/MM/yyyy')
                            .format(activity.activity.executedAt!)
                        : 'N/A',
                    Icons.calendar_today_rounded,
                    dense: true,
                    toneColor: SaoColors.warning,
                  ),
                  _buildReadOnlyField(
                    'Evidencias',
                    '${activity.evidences.length}',
                    Icons.photo_library_rounded,
                    dense: true,
                    toneColor: SaoColors.warning,
                  ),
                ],
              ),
              if (activity.activity.latitude != null &&
                  activity.activity.longitude != null) ...[
                const SizedBox(height: SaoSpacing.md),
                _buildGPSValidationBanner(activity),
              ],
            ],
          ),
        );
      },
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
      padding: const EdgeInsets.all(SaoSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < widget.timelineEntries.length; i++) ...[
            _buildTimelineEvent(widget.timelineEntries[i]),
            if (i < widget.timelineEntries.length - 1)
              _buildTimelineConnector(),
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
    if (key.contains('APPROVE')) {
      return Icons.check_circle_rounded;
    }
    if (key.contains('REJECT')) {
      return Icons.cancel_rounded;
    }
    if (key.contains('CREATE')) {
      return Icons.create_rounded;
    }
    if (key.contains('UPDATE') || key.contains('PATCH')) {
      return Icons.edit_rounded;
    }
    return Icons.history_rounded;
  }

  Color _timelineColor(String action) {
    final key = action.toUpperCase();
    if (key.contains('APPROVE')) {
      return SaoColors.success;
    }
    if (key.contains('REJECT')) {
      return SaoColors.error;
    }
    if (key.contains('CREATE')) {
      return SaoColors.info;
    }
    if (key.contains('UPDATE') || key.contains('PATCH')) {
      return SaoColors.warning;
    }
    return SaoColors.gray500;
  }

  String _timelineTitle(String action) {
    final key = action.trim();
    if (key.isEmpty) return 'Evento';
    return key
        .toLowerCase()
        .split('_')
        .map((part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  // ============================================================
  // TAB 3: VALIDACIÓN TÉCNICA
  // ============================================================
  Widget _buildValidacionTecnicaTab(ActivityWithDetails activity) {
    final checklist = <({String label, bool ok})>[
      (
        label: '¿Tiene coordenadas GPS?',
        ok: activity.activity.latitude != null &&
            activity.activity.longitude != null,
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
      padding: const EdgeInsets.all(SaoSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CHECKLIST DE CALIDAD',
            style: SaoTypography.caption.copyWith(
                fontWeight: FontWeight.w600, color: SaoColors.gray600),
          ),
            const SizedBox(height: SaoSpacing.md),
          ...checklist.map(
              (item) => _buildChecklistItem(item.label, isChecked: item.ok)),

            const SizedBox(height: SaoSpacing.xl),

          // ALERTA GPS
          _buildGPSWarningPanel(activity),
        ],
      ),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  Widget _buildSummaryGroup({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(SaoSpacing.sm),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(SaoRadii.lg),
        border: Border.all(color: accentColor.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(SaoSpacing.xs),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(SaoRadii.md),
                ),
                child: Icon(icon, size: 16, color: accentColor),
              ),
              const SizedBox(width: SaoSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: SaoTypography.bodyText.copyWith(
                        fontWeight: FontWeight.w700,
                        color: SaoColors.gray900,
                      ),
                    ),
                    const SizedBox(height: SaoSpacing.xxs),
                    Text(
                      subtitle,
                      style: SaoTypography.caption.copyWith(
                        color: SaoColors.gray600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: SaoSpacing.sm),
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1) const SizedBox(height: SaoSpacing.sm),
          ],
        ],
      ),
    );
  }

  String _resolveActivityTypeLabel(ActivityWithDetails activity) {
    final rawName = (activity.activityType?.name ?? '').trim();
    final rawCode = (activity.activityType?.code ?? '').trim();
    final rawId = (activity.activityType?.id ?? '').trim();

    final catalogOptions = ref.read(catalogRepositoryProvider).getActivityTypes();
    final lookupKeys = _catalogLookupKeys(activity)
        .map((key) => key.trim().toLowerCase())
        .where((key) => key.isNotEmpty)
        .toSet();

    for (final option in catalogOptions) {
      final optionId = option.id.trim().toLowerCase();
      final optionName = option.name.trim();
      if (optionName.isEmpty) continue;
      if (lookupKeys.contains(optionId) ||
          lookupKeys.contains(optionName.toLowerCase())) {
        return optionName;
      }
    }

    if (rawName.isNotEmpty &&
        rawName.toUpperCase() != rawCode.toUpperCase() &&
        rawName.toUpperCase() != rawId.toUpperCase()) {
      return rawName;
    }
    if (rawCode.isNotEmpty) return rawCode;
    if (rawId.isNotEmpty) return rawId;
    return 'N/A';
  }

  String _resolveAssignedPersonLabel(ActivityWithDetails activity) {
    final candidates = <String?>[
      activity.assignedUser?.fullName,
      activity.assignedUser?.email,
      activity.activity.assignedTo,
    ];

    String bestMatch = '';
    int bestScore = -1;

    for (final candidate in candidates) {
      final formatted = _formatPersonDisplay(candidate);
      if (formatted.isEmpty || formatted.toLowerCase() == 'sin responsable') {
        continue;
      }

      final wordCount = formatted
          .split(' ')
          .where((part) => part.trim().isNotEmpty)
          .length;
      final score = (wordCount * 100) + formatted.length;
      if (score > bestScore) {
        bestScore = score;
        bestMatch = formatted;
      }
    }

    return bestMatch.isNotEmpty ? bestMatch : 'Sin responsable';
  }

  String _resolveLocationStateLabel(ActivityWithDetails activity) {
    return _wizardPayloadText(activity.wizardPayload, const ['location', 'estado']) ??
        _wizardPayloadText(activity.wizardPayload, const ['location', 'state']) ??
        _extractLabeledField(activity.activity.description, const ['Estado']) ??
        ((activity.municipality?.state ?? '').trim().isEmpty
            ? 'N/A'
            : activity.municipality!.state.trim());
  }

  String _resolveLocationColonyLabel(ActivityWithDetails activity) {
    return _wizardPayloadText(activity.wizardPayload, const ['location', 'colonia']) ??
        _wizardPayloadText(activity.wizardPayload, const ['location', 'colony']) ??
        _extractLabeledField(activity.activity.description, const ['Colonia', 'Col.']) ??
        'N/A';
  }

  String _formatPersonDisplay(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty || value.toLowerCase() == 'n/a') {
      return '';
    }

    final baseValue = value.contains('@') ? value.split('@').first : value;
    final cleaned = baseValue
        .replaceAll(RegExp(r'[._-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) {
      return '';
    }

    final lowered = cleaned.toLowerCase();
    if (RegExp(r'^[0-9a-f-]{8,}$', caseSensitive: false).hasMatch(cleaned) ||
        lowered == 'usr backend' ||
        lowered == 'user backend' ||
        lowered == 'backend' ||
        lowered == 'usr' ||
        lowered == 'user') {
      return '';
    }

    return cleaned
        .split(' ')
        .map((part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  Widget _buildReadOnlyField(
    String label,
    String value,
    IconData icon, {
    bool dense = false,
    Color? toneColor,
    int maxLines = 1,
  }) {
    final accent = toneColor ?? SaoColors.gray600;
    if (dense) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: SaoSpacing.sm,
          vertical: SaoSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.05),
          border: Border.all(color: accent.withValues(alpha: 0.18)),
          borderRadius: BorderRadius.circular(SaoRadii.md),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: accent),
            const SizedBox(width: SaoSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: SaoTypography.caption.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: SaoSpacing.xxs),
                  Text(
                    value,
                    style: SaoTypography.bodyText,
                    maxLines: maxLines,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

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
        const SizedBox(height: SaoSpacing.xs),
        Container(
          padding: const EdgeInsets.all(SaoSpacing.md),
          decoration: BoxDecoration(
            color: SaoColors.surfaceMutedFor(context),
            border: Border.all(color: SaoColors.borderFor(context)),
            borderRadius: BorderRadius.circular(SaoRadii.md),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: SaoColors.textMutedFor(context)),
              const SizedBox(width: SaoSpacing.sm),
              Expanded(
                child: Text(
                  value,
                  style: SaoTypography.bodyText,
                  maxLines: maxLines,
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
    bool dense = false,
    Color? toneColor,
  }) {
    final accent = toneColor ?? SaoColors.gray600;
    if (dense) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: SaoSpacing.sm,
          vertical: SaoSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.05),
          border: Border.all(color: accent.withValues(alpha: 0.18)),
          borderRadius: BorderRadius.circular(SaoRadii.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Icon(icon, size: 16, color: accent),
            ),
            const SizedBox(width: SaoSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: SaoTypography.caption.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: SaoSpacing.xxs),
                  TextField(
                    controller: controller,
                    minLines: minLines,
                    maxLines: maxLines,
                    cursorColor: accent,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'Editar valor...',
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Guardar cambio rápido',
              onPressed: onSave,
              icon: Icon(Icons.save_rounded, size: 18, color: accent),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: SaoTypography.caption.copyWith(
            color: SaoColors.textMutedFor(context),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: SaoSpacing.xs),
        Container(
          padding: const EdgeInsets.all(SaoSpacing.sm),
          decoration: BoxDecoration(
            color: SaoColors.surfaceMutedFor(context),
            border: Border.all(color: SaoColors.borderFor(context)),
            borderRadius: BorderRadius.circular(SaoRadii.md),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Icon(icon,
                    size: 18, color: SaoColors.textMutedFor(context)),
              ),
              const SizedBox(width: SaoSpacing.sm),
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
    final payloadSubcategory =
        _wizardPayloadText(payload, const ['subcategory', 'name']);
    final payloadTemaPrimary =
        _wizardPayloadText(payload, const ['topics', '0', 'name']);
    final payloadPurpose =
        _wizardPayloadText(payload, const ['purpose', 'name']);
    final payloadMunicipio =
        _wizardPayloadText(payload, const ['location', 'municipio']);

    final capturedSubcategoria = (payloadSubcategory ??
            _extractLabeledField(activity.activity.description, const [
              'Subcategoría',
              'Subcategoria',
            ]) ??
            activity.activity.title)
        .trim();
    final capturedTema = (payloadTemaPrimary ??
            _extractLabeledField(activity.activity.description, const [
              'Tema',
              'Temas',
            ]) ??
            '')
        .trim();
    final capturedProposito = (payloadPurpose ??
            _extractPurposeFromDescription(activity.activity.description))
        .trim();
    final capturedMunicipio = (payloadMunicipio ??
            _extractLinkedMunicipality(activity.activity.description) ??
            activity.municipality?.name ??
            'Sin municipio')
        .trim();

    // Load real catalog options for current activity type
    final catalogRepo = ref.read(catalogRepositoryProvider);
    if (!_isCatalogReadyForActivityProject(catalogRepo, activity)) {
      return Container(
        padding: const EdgeInsets.all(SaoSpacing.md),
        decoration: BoxDecoration(
          color: SaoColors.info.withValues(alpha: 0.06),
          border: Border.all(color: SaoColors.info.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(SaoRadii.md),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: SaoSpacing.sm),
            Expanded(
              child: Text(
                'Cargando catálogo del proyecto ${activity.activity.projectId}...',
                style:
                    SaoTypography.bodyText.copyWith(color: SaoColors.gray700),
              ),
            ),
          ],
        ),
      );
    }

    final subcatOptions = _resolveSubcategoryOptions(catalogRepo, activity);
    final effectiveSubcategoryId = _resolveEffectiveSubcategoryId(
      catalogRepo: catalogRepo,
      activity: activity,
      subcategoryOptions: subcatOptions,
      capturedSubcategory: capturedSubcategoria,
    );
    final temaOptions = _resolveTemaOptions(catalogRepo, activity);
    final propOptions = _resolvePurposeOptions(
      catalogRepo,
      activity,
      subcategoryId: effectiveSubcategoryId,
    );
    final munOptions = _resolveMunicipalityOptions(catalogRepo, activity);
    final pendingFields = <String>[
      if (_requiresCatalogDecision(capturedSubcategoria, subcatOptions)) 'Subcategoría',
      if (_requiresCatalogDecision(capturedTema, temaOptions)) 'Tema',
      if (_requiresCatalogDecision(capturedProposito, propOptions)) 'Propósito',
      if (_requiresCatalogDecision(capturedMunicipio, munOptions)) 'Municipio',
    ];

    return Container(
      padding: const EdgeInsets.all(SaoSpacing.md),
      decoration: BoxDecoration(
        color: SaoColors.info.withValues(alpha: 0.06),
        border: Border.all(color: SaoColors.info.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(SaoRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hub_rounded, color: SaoColors.primary),
              const SizedBox(width: SaoSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Decisión de Catálogo',
                      style: SaoTypography.bodyTextBold.copyWith(
                        color: SaoColors.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      pendingFields.isEmpty
                          ? 'Todos los campos coinciden con catálogo. Solo abre uno si deseas revisar.'
                          : '${pendingFields.length} campo(s) requieren decisión y ya aparecen desplegados.',
                      style: SaoTypography.caption.copyWith(
                        color: SaoColors.gray600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: SaoSpacing.sm,
                  vertical: SaoSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: (pendingFields.isEmpty ? SaoColors.success : SaoColors.warning)
                      .withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(SaoRadii.full),
                ),
                child: Text(
                  pendingFields.isEmpty ? 'Sin cambios' : '${pendingFields.length} pendiente(s)',
                  style: SaoTypography.caption.copyWith(
                    color: pendingFields.isEmpty ? SaoColors.success : SaoColors.warning,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: SaoSpacing.md),
          _buildCatalogDecisionRow(
            fieldLabel: 'Subcategoría',
            capturedValue: capturedSubcategoria,
            linkedValue: _subcategoriaLink,
            options: subcatOptions,
            onLinkChanged: (v) => setState(() => _subcategoriaLink = v),
            onLinkToExisting: (selected) async {
              await widget.onCatalogLink
                  ?.call('subcategoria', capturedSubcategoria, selected);
            },
            onAddToCatalog: () async {
              await widget.onCatalogAdd
                  ?.call('subcategoria', capturedSubcategoria);
            },
            onRequestCorrection: () async {
              await widget.onCatalogCorrection
                  ?.call('subcategoria', capturedSubcategoria);
            },
          ),
          const SizedBox(height: SaoSpacing.sm),
          _buildCatalogDecisionRow(
            fieldLabel: 'Tema',
            capturedValue:
                capturedTema.isEmpty ? 'Sin tema capturado' : capturedTema,
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
          const SizedBox(height: SaoSpacing.sm),
          _buildCatalogDecisionRow(
            fieldLabel: 'Propósito',
            capturedValue: capturedProposito.isEmpty
                ? 'Sin propósito capturado'
                : capturedProposito,
            linkedValue: _propositoLink,
            options: propOptions,
            onLinkChanged: (v) => setState(() => _propositoLink = v),
            onLinkToExisting: (selected) async {
              await widget.onCatalogLink
                  ?.call('proposito', capturedProposito, selected);
            },
            onAddToCatalog: () async {
              await widget.onCatalogAdd?.call('proposito', capturedProposito);
            },
            onRequestCorrection: () async {
              await widget.onCatalogCorrection
                  ?.call('proposito', capturedProposito);
            },
          ),
          const SizedBox(height: SaoSpacing.sm),
          _buildCatalogDecisionRow(
            fieldLabel: 'Municipio',
            capturedValue: capturedMunicipio,
            linkedValue: _municipioLink,
            options: munOptions,
            onLinkChanged: (v) => setState(() => _municipioLink = v),
            onLinkToExisting: (selected) async {
              await widget.onCatalogLink
                  ?.call('municipio', capturedMunicipio, selected);
            },
            onAddToCatalog: () async {
              await widget.onCatalogAdd?.call('municipio', capturedMunicipio);
            },
            onRequestCorrection: () async {
              await widget.onCatalogCorrection
                  ?.call('municipio', capturedMunicipio);
            },
          ),
          if (pendingFields.isNotEmpty) ...[
            const SizedBox(height: SaoSpacing.sm),
            const Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _HotkeyPill(label: 'A', hint: 'Aceptar'),
                _HotkeyPill(label: 'C', hint: 'Catálogo'),
                _HotkeyPill(label: 'R', hint: 'Corrección'),
              ],
            ),
          ],
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
    final optionsByKey = <String, String>{};
    for (final raw in options) {
      final option = raw.trim();
      if (option.isEmpty) continue;
      optionsByKey.putIfAbsent(_normalizeCatalogValue(option), () => option);
    }
    final dedupedOptions = optionsByKey.values.toList(growable: false);
    final safeLinkedValue =
        optionsByKey[_normalizeCatalogValue(linkedValue ?? '')];
    final inferredFromCaptured =
        _findBestCatalogOption(capturedValue, dedupedOptions);
    final effectiveLinkedValue = safeLinkedValue ?? inferredFromCaptured;
    final needsAttention = _requiresCatalogDecision(capturedValue, dedupedOptions);
    final isExpanded = needsAttention || _expandedCatalogFields.contains(fieldLabel);
    final statusColor = needsAttention ? SaoColors.warning : SaoColors.success;
    final statusLabel = needsAttention ? 'Requiere cambio' : 'Correcto';
    final normalizedCaptured = _normalizeCatalogValue(capturedValue);
    final summaryText = normalizedCaptured.isEmpty
        ? 'Sin valor capturado'
        : (effectiveLinkedValue ?? capturedValue).trim();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(SaoSpacing.sm),
      decoration: BoxDecoration(
        color: needsAttention
            ? SaoColors.warning.withValues(alpha: 0.12)
            : SaoColors.surfaceFor(context),
        border: Border.all(
          color: needsAttention
              ? SaoColors.warning
              : SaoColors.borderFor(context),
        ),
        borderRadius: BorderRadius.circular(SaoRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(SaoRadii.sm),
            onTap: needsAttention
                ? null
                : () {
                    setState(() {
                      if (isExpanded) {
                        _expandedCatalogFields.remove(fieldLabel);
                      } else {
                        _expandedCatalogFields.add(fieldLabel);
                      }
                    });
                  },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SaoSpacing.xs,
                vertical: SaoSpacing.xs,
              ),
              child: Row(
                children: [
                  Icon(
                    needsAttention
                        ? Icons.pending_actions_rounded
                        : Icons.check_circle_rounded,
                    size: 18,
                    color: statusColor,
                  ),
                  const SizedBox(width: SaoSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fieldLabel,
                          style: SaoTypography.caption.copyWith(
                            color: SaoColors.textFor(context),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          summaryText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SaoTypography.caption.copyWith(
                            color: SaoColors.textMutedFor(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: SaoSpacing.sm,
                      vertical: SaoSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(SaoRadii.full),
                    ),
                    child: Text(
                      statusLabel,
                      style: SaoTypography.caption.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (!needsAttention) ...[
                    const SizedBox(width: SaoSpacing.xs),
                    Icon(
                      isExpanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: SaoColors.textMutedFor(context),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const SizedBox(height: SaoSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(SaoSpacing.sm),
                    decoration: BoxDecoration(
                      color: SaoColors.surfaceMutedFor(context),
                      borderRadius: BorderRadius.circular(SaoRadii.sm),
                      border: Border.all(color: SaoColors.borderFor(context)),
                    ),
                    child: Text(
                      'Valor capturado: "$capturedValue"',
                      style: SaoTypography.caption.copyWith(
                        color: SaoColors.textFor(context),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: SaoSpacing.sm),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: effectiveLinkedValue,
                    isExpanded: true,
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: 'Vincular a existente',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(SaoRadii.sm),
                      ),
                    ),
                    items: dedupedOptions
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
            const SizedBox(height: SaoSpacing.sm),
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
                  onPressed: effectiveLinkedValue == null
                      ? null
                      : () async {
                          await onLinkToExisting(effectiveLinkedValue);
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
        ],
      ),
    );
  }

  bool _requiresCatalogDecision(String capturedValue, List<String> options) {
    final normalizedCaptured = _normalizeCatalogValue(capturedValue);
    if (normalizedCaptured.isEmpty ||
        normalizedCaptured == 'n a' ||
        normalizedCaptured.startsWith('sin ')) {
      return true;
    }
    return _findBestCatalogOption(capturedValue, options) == null;
  }

  String _normalizeCatalogValue(String value) {
    var normalized = value
        .trim()
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (normalized.startsWith('municipio de ')) {
      normalized = normalized.substring('municipio de '.length).trim();
    }
    if (normalized.startsWith('mpio de ')) {
      normalized = normalized.substring('mpio de '.length).trim();
    }
    return normalized;
  }

  String? _findBestCatalogOption(String capturedValue, List<String> options) {
    final captured = _normalizeCatalogValue(capturedValue);
    if (captured.isEmpty || options.isEmpty) return null;

    for (final option in options) {
      if (_normalizeCatalogValue(option) == captured) {
        return option;
      }
    }

    if (captured.length >= 4) {
      for (final option in options) {
        final normalizedOption = _normalizeCatalogValue(option);
        if (normalizedOption.contains(captured) ||
            captured.contains(normalizedOption)) {
          return option;
        }
      }
    }

    return null;
  }

  List<String> _resolveSubcategoryOptions(
    CatalogRepository catalogRepo,
    ActivityWithDetails activity,
  ) {
    if (!_isCatalogReadyForActivityProject(catalogRepo, activity)) {
      return const <String>[];
    }

    final optionSet = <String>{};

    for (final key in _catalogLookupKeys(activity)) {
      for (final item in catalogRepo.subcategoriesFor(key)) {
        final name = item.name.trim();
        if (name.isNotEmpty) optionSet.add(name);
      }
    }

    if (optionSet.isNotEmpty) {
      return optionSet.toList(growable: false);
    }

    return const <String>[];
  }

  List<String> _resolveTemaOptions(
    CatalogRepository catalogRepo,
    ActivityWithDetails activity,
  ) {
    if (!_isCatalogReadyForActivityProject(catalogRepo, activity)) {
      return const <String>[];
    }

    final optionSet = <String>{};

    for (final key in _catalogLookupKeys(activity)) {
      for (final item in catalogRepo.temasSugeridosFor(key)) {
        final name = item.name.trim();
        if (name.isNotEmpty) optionSet.add(name);
      }
    }

    if (optionSet.isNotEmpty) {
      return optionSet.toList(growable: false);
    }

    return const <String>[];
  }

  List<String> _resolvePurposeOptions(
    CatalogRepository catalogRepo,
    ActivityWithDetails activity, {
    String? subcategoryId,
  }) {
    if (!_isCatalogReadyForActivityProject(catalogRepo, activity)) {
      return const <String>[];
    }

    final optionSet = <String>{};

    for (final key in _catalogLookupKeys(activity)) {
      for (final item in catalogRepo.purposesFor(
        activityId: key,
        subcategoryId: subcategoryId,
      )) {
        final name = item.name.trim();
        if (name.isNotEmpty) optionSet.add(name);
      }
    }

    if (optionSet.isNotEmpty) {
      return optionSet.toList(growable: false);
    }

    return const <String>[];
  }

  List<String> _resolveMunicipalityOptions(
    CatalogRepository catalogRepo,
    ActivityWithDetails activity,
  ) {
    final valuesByKey = <String, String>{};

    void addValue(String? raw) {
      final value = (raw ?? '').trim();
      if (value.isEmpty) return;
      valuesByKey.putIfAbsent(_normalizeCatalogValue(value), () => value);
    }

    if (_isCatalogReadyForActivityProject(catalogRepo, activity)) {
      for (final item in catalogRepo.getMunicipalities()) {
        addValue(item);
      }
    }
    for (final item in _projectCoverageMunicipalities) {
      addValue(item);
    }

    addValue(activity.municipality?.name);
    addValue(_extractLinkedMunicipality(activity.activity.description));
    addValue(_wizardPayloadText(
        activity.wizardPayload, const ['location', 'municipio']));

    final values = valuesByKey.values.toList(growable: false)
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return values;
  }

  bool _isCatalogReadyForActivityProject(
    CatalogRepository catalogRepo,
    ActivityWithDetails activity,
  ) {
    final activityProjectId = activity.activity.projectId.trim().toUpperCase();
    if (activityProjectId.isEmpty) return false;
    return catalogRepo.isReady &&
        catalogRepo.projectId.trim().toUpperCase() == activityProjectId;
  }

  String? _resolveEffectiveSubcategoryId({
    required CatalogRepository catalogRepo,
    required ActivityWithDetails activity,
    required List<String> subcategoryOptions,
    required String capturedSubcategory,
  }) {
    final effectiveSubcategoryName = _subcategoriaLink ??
        _findBestCatalogOption(capturedSubcategory, subcategoryOptions);
    final normalizedTarget =
        _normalizeCatalogValue(effectiveSubcategoryName ?? '');
    if (normalizedTarget.isEmpty) {
      return null;
    }

    for (final key in _catalogLookupKeys(activity)) {
      for (final item in catalogRepo.subcategoriesFor(key)) {
        if (_normalizeCatalogValue(item.name) == normalizedTarget) {
          final id = item.id.trim();
          if (id.isNotEmpty) {
            return id;
          }
        }
      }
    }

    return null;
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
    final description =
        (activity.activity.description ?? '').trim().toLowerCase();
    return title == 'otro' ||
        description.contains('no existe en catalogo') ||
        activity.flags.catalogChanged ||
        _hasUnresolvedCatalogDecision(activity);
  }

  bool _hasUnresolvedCatalogDecision(ActivityWithDetails activity) {
    final payload = activity.wizardPayload;
    final payloadSubcategory =
        _wizardPayloadText(payload, const ['subcategory', 'name']);
    final payloadTemaPrimary =
        _wizardPayloadText(payload, const ['topics', '0', 'name']);
    final payloadPurpose =
        _wizardPayloadText(payload, const ['purpose', 'name']);
    final payloadMunicipio =
        _wizardPayloadText(payload, const ['location', 'municipio']);

    final capturedSubcategoria = (payloadSubcategory ??
            _extractLabeledField(activity.activity.description, const [
              'Subcategoría',
              'Subcategoria',
            ]) ??
            activity.activity.title)
        .trim();
    final capturedTema = (payloadTemaPrimary ??
            _extractLabeledField(activity.activity.description, const [
              'Tema',
              'Temas',
            ]) ??
            '')
        .trim();
    final capturedProposito = (payloadPurpose ??
            _extractPurposeFromDescription(activity.activity.description))
        .trim();
    final capturedMunicipio = (payloadMunicipio ??
            _extractLinkedMunicipality(activity.activity.description) ??
            activity.municipality?.name ??
            'Sin municipio')
        .trim();

    final catalogRepo = ref.read(catalogRepositoryProvider);
    final subcatOptions = _resolveSubcategoryOptions(catalogRepo, activity);
    final effectiveSubcategoryId = _resolveEffectiveSubcategoryId(
      catalogRepo: catalogRepo,
      activity: activity,
      subcategoryOptions: subcatOptions,
      capturedSubcategory: capturedSubcategoria,
    );
    final temaOptions = _resolveTemaOptions(catalogRepo, activity);
    final propOptions = _resolvePurposeOptions(
      catalogRepo,
      activity,
      subcategoryId: effectiveSubcategoryId,
    );
    final munOptions = _resolveMunicipalityOptions(catalogRepo, activity);

    bool unresolved(String captured, List<String> options) {
      final normalized = _normalizeCatalogValue(captured);
      if (normalized.isEmpty) return false;
      return _findBestCatalogOption(captured, options) == null;
    }

    return unresolved(capturedSubcategoria, subcatOptions) ||
        unresolved(capturedTema, temaOptions) ||
        unresolved(capturedProposito, propOptions) ||
        unresolved(capturedMunicipio, munOptions);
  }

  Widget _buildGPSValidationBanner(ActivityWithDetails activity) {
    final hasMismatch = activity.flags.gpsMismatch;
    final message = hasMismatch
        ? 'GPS con discrepancia respecto al PK declarado'
        : 'GPS consistente con el PK declarado';
    final justification = _extractGpsJustification(activity.activity.description);

    return Container(
      padding: const EdgeInsets.all(SaoSpacing.md),
      margin: const EdgeInsets.only(top: SaoSpacing.lg),
      decoration: BoxDecoration(
        color: hasMismatch
            ? SaoColors.warning.withValues(alpha: 0.1)
            : SaoColors.success.withValues(alpha: 0.08),
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
              const SizedBox(width: SaoSpacing.sm),
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
          if (justification != null && justification.trim().isNotEmpty) ...[
            const SizedBox(height: SaoSpacing.sm),
            Text(
              'Justificación registrada: $justification',
              style: SaoTypography.caption.copyWith(
                color: SaoColors.gray700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: SaoSpacing.md),
          Wrap(
            spacing: SaoSpacing.sm,
            runSpacing: SaoSpacing.sm,
            children: [
              ElevatedButton.icon(
                onPressed: () => _openGpsMap(activity),
                icon: const Icon(Icons.map_rounded),
                label: const Text('Ver en Mapa'),
              ),
              if (hasMismatch)
                ElevatedButton.icon(
                  onPressed: () => _handleGpsJustification(activity),
                  icon: const Icon(Icons.note_add_rounded),
                  label: const Text('Agregar Justificación'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SaoColors.error.withValues(alpha: 0.1),
                    foregroundColor: SaoColors.error,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGPSWarningPanel(ActivityWithDetails activity) {
    final hasCoordinates =
        activity.activity.latitude != null && activity.activity.longitude != null;
    final hasMismatch = activity.flags.gpsMismatch;
    final title = !hasCoordinates
        ? 'GPS pendiente de validar'
        : hasMismatch
            ? 'Discrepancia GPS crítica'
            : 'GPS validado';
    final message = !hasCoordinates
        ? 'La actividad no tiene coordenadas completas. No podrá aprobarse hasta contar con ubicación verificable.'
        : hasMismatch
            ? 'La ubicación GPS no coincide con el PK declarado. Registra una justificación técnica y revisa el flag antes de aprobar.'
            : 'La geolocalización quedó verificada y ya puedes continuar con la validación técnica.';
    final tone = !hasCoordinates
        ? SaoColors.warning
        : hasMismatch
            ? SaoColors.error
            : SaoColors.success;

    return Container(
      padding: const EdgeInsets.all(SaoSpacing.md),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.1),
        border: Border.all(color: tone),
        borderRadius: BorderRadius.circular(SaoRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasMismatch ? Icons.warning_rounded : Icons.gps_fixed_rounded,
                color: tone,
              ),
              const SizedBox(width: SaoSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: SaoTypography.bodyTextBold.copyWith(color: tone),
                ),
              ),
            ],
          ),
          const SizedBox(height: SaoSpacing.md),
          Text(
            message,
            style: SaoTypography.bodyText.copyWith(color: SaoColors.gray700),
          ),
          const SizedBox(height: SaoSpacing.md),
          Wrap(
            spacing: SaoSpacing.sm,
            runSpacing: SaoSpacing.sm,
            children: [
              if (hasCoordinates)
                OutlinedButton.icon(
                  onPressed: () => _openGpsMap(activity),
                  icon: const Icon(Icons.map_rounded),
                  label: const Text('Ver en Mapa'),
                ),
              if (hasMismatch)
                ElevatedButton.icon(
                  onPressed: () => _handleGpsJustification(activity),
                  icon: const Icon(Icons.check_circle_rounded),
                  label: const Text('Agregar Justificación'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SaoColors.error.withValues(alpha: 0.1),
                    foregroundColor: SaoColors.error,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openGpsMap(ActivityWithDetails activity) async {
    final latitude = activity.activity.latitude;
    final longitude = activity.activity.longitude;
    if (latitude == null || longitude == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esta actividad aún no tiene coordenadas GPS disponibles.'),
        ),
      );
      return;
    }

    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No fue posible abrir el mapa externo.'),
        ),
      );
    }
  }

  Future<void> _handleGpsJustification(ActivityWithDetails activity) async {
    final justification = await _showGpsJustificationDialog(activity);
    if (justification == null || justification.trim().isEmpty) return;

    final updatedDescription = _mergeGpsJustification(
      activity.activity.description,
      justification.trim(),
    );
    if (updatedDescription != (activity.activity.description ?? '').trim()) {
      widget.onFieldChanged?.call('description', updatedDescription);
    }

    if (!mounted) return;
    final flagUpdated = await showFlagResolutionDialog(
      context,
      activity: activity,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          flagUpdated
              ? 'Justificación GPS guardada y revisión actualizada.'
              : 'Justificación GPS registrada. Puedes resolver el flag cuando corresponda.',
        ),
        backgroundColor: flagUpdated ? SaoColors.success : SaoColors.info,
      ),
    );
  }

  Future<String?> _showGpsJustificationDialog(ActivityWithDetails activity) async {
    final controller = TextEditingController(
      text: _extractGpsJustification(activity.activity.description) ?? '',
    );

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Justificación GPS'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Documenta por qué la coordenada capturada difiere del PK declarado.',
                  style: SaoTypography.bodyText.copyWith(color: SaoColors.gray700),
                ),
                const SizedBox(height: SaoSpacing.md),
                TextField(
                  controller: controller,
                  autofocus: true,
                  minLines: 3,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: 'Ej. Captura tomada desde camino lateral por restricciones de acceso.',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(SaoRadii.sm),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isEmpty) return;
              Navigator.of(dialogContext).pop(value);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    return result;
  }

  String? _extractGpsJustification(String? description) {
    return _extractLabeledField(
      description,
      const ['Justificación GPS', 'Justificacion GPS'],
    );
  }

  String _mergeGpsJustification(String? description, String justification) {
    final base = (description ?? '').trim();
    final lines = base.isEmpty
        ? <String>[]
        : base
            .split('\n')
            .where((line) =>
                !_normalizeLabelToken(line).startsWith('justificacion gps:'))
            .toList(growable: true);
    lines.add('Justificación GPS: $justification');
    return lines.join('\n').trim();
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
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: SaoSpacing.md),
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
              const SizedBox(height: SaoSpacing.xs),
              Text(
                timestamp,
                style:
                    SaoTypography.chipText.copyWith(color: SaoColors.gray500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineConnector() {
    return Padding(
      padding: const EdgeInsets.only(left: 20, top: 4, bottom: 4),
      child: Container(
        width: 2,
        height: 20,
        color: SaoColors.border,
      ),
    );
  }

  Widget _buildChecklistItem(String label, {required bool isChecked}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SaoSpacing.sm),
      child: Row(
        children: [
          Icon(
            isChecked ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: isChecked ? SaoColors.success : SaoColors.gray400,
          ),
          const SizedBox(width: SaoSpacing.sm),
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
        color: SaoColors.surfaceRaisedFor(context),
        borderRadius: BorderRadius.circular(SaoRadii.sm),
        border: Border.all(color: SaoColors.borderFor(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: SaoColors.surfaceFor(context),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: SaoColors.borderFor(context)),
            ),
            child: Text(
              label,
              style:
                  SaoTypography.caption.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            hint,
            style: SaoTypography.caption.copyWith(
              color: SaoColors.textMutedFor(context),
            ),
          ),
        ],
      ),
    );
  }
}
