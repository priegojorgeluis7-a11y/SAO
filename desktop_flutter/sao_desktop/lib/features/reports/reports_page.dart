import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../ui/theme/sao_colors.dart';
import '../../ui/theme/sao_spacing.dart';
import '../../ui/theme/sao_typography.dart';
import '../../ui/theme/sao_radii.dart';
import 'reports_provider.dart';

// Short month names — avoids intl locale initialization issues
const _kMonths = [
  'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
  'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
];

String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')} ${_kMonths[d.month - 1]} ${d.year}';

// ===========================================================================
// Root page
// ===========================================================================

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  // Options state (local — not filters)
  bool _includeAudit = true;
  bool _includeNotes = false;
  bool _includeAttachments = true;
  final _summaryController = TextEditingController();

  bool _isGenerating = false;
  String? _lastSavedPath;

  @override
  void dispose() {
    _summaryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(reportFiltersProvider);
    final activitiesAsync = ref.watch(reportActivitiesProvider);

    return Row(
      children: [
        // Panel 1: Filtros
        SizedBox(
          width: 230,
          child: _FiltersPanel(filters: filters),
        ),
        const VerticalDivider(width: 1, thickness: 1),

        // Panel 2: Vista Previa (flexible)
        Expanded(
          child: _PreviewPanel(
            activitiesAsync: activitiesAsync,
            filters: filters,
            onRefresh: () => ref.invalidate(reportActivitiesProvider),
          ),
        ),
        const VerticalDivider(width: 1, thickness: 1),

        // Panel 3: Opciones
        SizedBox(
          width: 260,
          child: _OptionsPanel(
            includeAudit: _includeAudit,
            includeNotes: _includeNotes,
            includeAttachments: _includeAttachments,
            summaryController: _summaryController,
            isGenerating: _isGenerating,
            lastSavedPath: _lastSavedPath,
            canGenerate: activitiesAsync.hasValue && !_isGenerating,
            onIncludeAuditChanged: (v) => setState(() => _includeAudit = v),
            onIncludeNotesChanged: (v) => setState(() => _includeNotes = v),
            onIncludeAttachmentsChanged: (v) =>
                setState(() => _includeAttachments = v),
            onGeneratePdf: () =>
                _generatePdf(activitiesAsync.value ?? [], filters),
            onExportZip: _showComingSoon,
            onSendEmail: () => _showEmailDialog(context, filters),
          ),
        ),
      ],
    );
  }

  Future<void> _generatePdf(
      List<ReportActivityItem> items, ReportFilters filters) async {
    setState(() {
      _isGenerating = true;
      _lastSavedPath = null;
    });
    try {
      final file = await generateActivitiesPdf(
        items,
        filters,
        executiveSummary: _summaryController.text.trim(),
        includeAudit: _includeAudit,
        includeNotes: _includeNotes,
        includeAttachments: _includeAttachments,
      );
      setState(() => _lastSavedPath = file.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF guardado: ${file.path}'),
            duration: const Duration(seconds: 5),
            backgroundColor: SaoColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar PDF: $e'),
            backgroundColor: SaoColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Exportar ZIP — próximamente')),
    );
  }

  void _showEmailDialog(BuildContext context, ReportFilters filters) {
    showDialog<void>(
      context: context,
      builder: (_) => _EmailDialog(filters: filters),
    );
  }
}

// ===========================================================================
// Panel 1: Filtros
// ===========================================================================

class _FiltersPanel extends ConsumerWidget {
  final ReportFilters filters;

  const _FiltersPanel({required this.filters});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(reportProjectsProvider);

    void updateFilters(ReportFilters f) =>
        ref.read(reportFiltersProvider.notifier).state = f;

    return Container(
      color: SaoColors.gray50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: SaoSpacing.md, vertical: SaoSpacing.sm + 2),
            color: SaoColors.surface,
            child: Row(
              children: [
                const Icon(Icons.tune_rounded,
                    color: SaoColors.primary, size: 16),
                const SizedBox(width: SaoSpacing.sm),
                Text('Filtros', style: SaoTypography.sectionTitle),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(SaoSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Proyecto
                  _FilterLabel('Proyecto'),
                  const SizedBox(height: SaoSpacing.xs),
                  projectsAsync.when(
                    loading: () =>
                        const LinearProgressIndicator(minHeight: 2),
                    error: (_, __) => _DropdownField(
                      value: filters.projectId,
                      items: const [],
                      onChanged: (v) =>
                          updateFilters(filters.copyWith(projectId: v ?? '')),
                    ),
                    data: (projects) {
                      final safeVal = projects.contains(filters.projectId)
                          ? filters.projectId
                          : (projects.isNotEmpty ? projects.first : '');
                      return _DropdownField(
                        value: safeVal,
                        items: projects,
                        onChanged: (v) =>
                            updateFilters(filters.copyWith(projectId: v)),
                      );
                    },
                  ),
                  const SizedBox(height: SaoSpacing.lg),

                  // Frente
                  _FilterLabel('Frente'),
                  const SizedBox(height: SaoSpacing.xs),
                  _DropdownField(
                    value: filters.frontName,
                    items: const ['Todos', 'Frente A', 'Frente B', 'Frente C'],
                    onChanged: (v) =>
                        updateFilters(filters.copyWith(frontName: v)),
                  ),
                  const SizedBox(height: SaoSpacing.lg),

                  // Rango de fechas
                  _FilterLabel('Rango de Fechas'),
                  const SizedBox(height: SaoSpacing.xs),
                  _DateRangeChip(range: filters.dateRange),
                  const SizedBox(height: SaoSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2024),
                          lastDate: DateTime(2030),
                          initialDateRange: DateTimeRange(
                            start: filters.dateRange.start,
                            end: filters.dateRange.end,
                          ),
                        );
                        if (picked != null) {
                          updateFilters(filters.copyWith(
                            dateRange: ReportDateRange(
                                start: picked.start, end: picked.end),
                          ));
                        }
                      },
                      icon: const Icon(Icons.calendar_today_rounded, size: 14),
                      label: const Text('Cambiar rango'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            vertical: SaoSpacing.sm),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterLabel extends StatelessWidget {
  final String text;
  const _FilterLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: SaoTypography.caption.copyWith(
          fontWeight: FontWeight.w600,
          color: SaoColors.gray700,
        ),
      );
}

class _DateRangeChip extends StatelessWidget {
  final ReportDateRange range;
  const _DateRangeChip({required this.range});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: SaoSpacing.sm, vertical: SaoSpacing.xs),
      decoration: BoxDecoration(
        color: SaoColors.info.withOpacity(0.08),
        border: Border.all(color: SaoColors.info.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(SaoRadii.sm),
      ),
      child: Row(
        children: [
          const Icon(Icons.date_range_rounded,
              size: 14, color: SaoColors.info),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${_fmtDate(range.start)}  →  ${_fmtDate(range.end)}',
              style: SaoTypography.caption.copyWith(
                color: SaoColors.info,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  const _DropdownField({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final safeVal =
        items.contains(value) ? value : (items.isNotEmpty ? items.first : null);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: SaoColors.border),
        borderRadius: BorderRadius.circular(SaoRadii.md),
        color: SaoColors.surface,
      ),
      child: DropdownButton<String>(
        isExpanded: true,
        value: safeVal,
        underline: const SizedBox(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
        items: items
            .map((p) => DropdownMenuItem(
                  value: p,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: SaoSpacing.sm),
                    child: Text(p),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

// ===========================================================================
// Panel 2: Vista Previa
// ===========================================================================

class _PreviewPanel extends StatelessWidget {
  final AsyncValue<List<ReportActivityItem>> activitiesAsync;
  final ReportFilters filters;
  final VoidCallback onRefresh;

  const _PreviewPanel({
    required this.activitiesAsync,
    required this.filters,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: SaoColors.gray100,
      child: Column(
        children: [
          // Header with result counter
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: SaoSpacing.md, vertical: SaoSpacing.sm + 2),
            color: SaoColors.surface,
            child: Row(
              children: [
                const Icon(Icons.preview_rounded,
                    color: SaoColors.primary, size: 16),
                const SizedBox(width: SaoSpacing.sm),
                Text('Vista Previa', style: SaoTypography.sectionTitle),
                const SizedBox(width: SaoSpacing.sm),
                activitiesAsync.when(
                  loading: () => const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: SaoColors.primary),
                  ),
                  error: (_, __) => const SizedBox(),
                  data: (items) => _ResultBadge(items: items, filters: filters),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  tooltip: 'Actualizar',
                  onPressed: onRefresh,
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Content
          Expanded(
            child: activitiesAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorState(
                error: e.toString(),
                onRetry: onRefresh,
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const _EmptyState();
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(SaoSpacing.md),
                  itemCount: items.length,
                  itemBuilder: (_, i) =>
                      _ActivityPreviewCard(item: items[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultBadge extends StatelessWidget {
  final List<ReportActivityItem> items;
  final ReportFilters filters;

  const _ResultBadge({required this.items, required this.filters});

  @override
  Widget build(BuildContext context) {
    final label = StringBuffer('${items.length} actividades · ${filters.projectId}');
    if (filters.frontName != 'Todos') label.write(' · ${filters.frontName}');

    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: SaoColors.primary.withOpacity(0.07),
        borderRadius: BorderRadius.circular(SaoRadii.full),
      ),
      child: Text(
        label.toString(),
        style: SaoTypography.caption.copyWith(
          color: SaoColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ActivityPreviewCard extends StatelessWidget {
  final ReportActivityItem item;
  const _ActivityPreviewCard({required this.item});

  String _fmtCreatedAt(String raw) {
    try {
      final dt = DateTime.parse(raw);
      return _fmtDate(dt);
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = SaoColors.getStatusColor(item.status);
    final statusBg = SaoColors.getStatusBackground(item.status);

    return Card(
      margin: const EdgeInsets.only(bottom: SaoSpacing.sm),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SaoRadii.md),
        side: const BorderSide(color: SaoColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(SaoSpacing.md),
        child: Row(
          children: [
            // Colored status bar
            Container(
              width: 3,
              height: 52,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: SaoSpacing.sm),

            // Main info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.activityType,
                    style: SaoTypography.bodyText
                        .copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.place_rounded,
                          size: 12, color: SaoColors.gray500),
                      const SizedBox(width: 2),
                      Text(
                        '${item.pk}  ·  ${item.frontName}',
                        style: SaoTypography.caption
                            .copyWith(color: SaoColors.gray500),
                      ),
                    ],
                  ),
                  if (item.createdAt.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      _fmtCreatedAt(item.createdAt),
                      style: SaoTypography.caption.copyWith(
                        color: SaoColors.gray400,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Status chip
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(SaoRadii.full),
              ),
              child: Text(
                item.statusLabel,
                style: SaoTypography.caption.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.receipt_long_outlined,
              size: 56, color: SaoColors.gray400),
          const SizedBox(height: 12),
          Text(
            'Sin actividades para los filtros seleccionados',
            style: SaoTypography.bodyText.copyWith(color: SaoColors.gray500),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: SaoColors.error),
          const SizedBox(height: 8),
          Text('Error: $error',
              style: SaoTypography.caption.copyWith(color: SaoColors.error)),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onRetry,
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Panel 3: Opciones
// ===========================================================================

class _OptionsPanel extends StatelessWidget {
  final bool includeAudit;
  final bool includeNotes;
  final bool includeAttachments;
  final TextEditingController summaryController;
  final bool isGenerating;
  final String? lastSavedPath;
  final bool canGenerate;
  final ValueChanged<bool> onIncludeAuditChanged;
  final ValueChanged<bool> onIncludeNotesChanged;
  final ValueChanged<bool> onIncludeAttachmentsChanged;
  final VoidCallback onGeneratePdf;
  final VoidCallback onExportZip;
  final VoidCallback onSendEmail;

  const _OptionsPanel({
    required this.includeAudit,
    required this.includeNotes,
    required this.includeAttachments,
    required this.summaryController,
    required this.isGenerating,
    this.lastSavedPath,
    required this.canGenerate,
    required this.onIncludeAuditChanged,
    required this.onIncludeNotesChanged,
    required this.onIncludeAttachmentsChanged,
    required this.onGeneratePdf,
    required this.onExportZip,
    required this.onSendEmail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: SaoColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: SaoSpacing.md, vertical: SaoSpacing.sm + 2),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: SaoColors.border)),
            ),
            child: Row(
              children: [
                const Icon(Icons.settings_rounded,
                    color: SaoColors.primary, size: 16),
                const SizedBox(width: SaoSpacing.sm),
                Text('Opciones', style: SaoTypography.sectionTitle),
              ],
            ),
          ),

          // Scrollable options body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(SaoSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sections label
                  Text(
                    'Secciones a incluir',
                    style: SaoTypography.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: SaoColors.gray700,
                    ),
                  ),
                  const SizedBox(height: SaoSpacing.xs),

                  _OptionTile(
                    title: 'Auditoría',
                    subtitle: 'Timeline de cambios',
                    icon: Icons.history_rounded,
                    value: includeAudit,
                    onChanged: onIncludeAuditChanged,
                  ),
                  _OptionTile(
                    title: 'Notas Internas',
                    subtitle: 'Solo revisión interna',
                    icon: Icons.sticky_note_2_outlined,
                    value: includeNotes,
                    onChanged: onIncludeNotesChanged,
                  ),
                  _OptionTile(
                    title: 'Anexos',
                    subtitle: 'Fotos y documentos',
                    icon: Icons.photo_library_outlined,
                    value: includeAttachments,
                    onChanged: onIncludeAttachmentsChanged,
                  ),

                  const SizedBox(height: SaoSpacing.sm),
                  const Divider(),
                  const SizedBox(height: SaoSpacing.sm),

                  // Executive summary
                  Text(
                    'Resumen Ejecutivo',
                    style: SaoTypography.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: SaoColors.gray700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Se incluirá en la portada del PDF',
                    style: SaoTypography.caption.copyWith(
                      color: SaoColors.gray500,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: SaoSpacing.xs),
                  TextField(
                    controller: summaryController,
                    maxLines: 4,
                    style: SaoTypography.caption,
                    decoration: InputDecoration(
                      hintText: 'Agregar resumen...',
                      hintStyle: SaoTypography.caption
                          .copyWith(color: SaoColors.gray400),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(SaoRadii.sm),
                        borderSide:
                            const BorderSide(color: SaoColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(SaoRadii.sm),
                        borderSide:
                            const BorderSide(color: SaoColors.border),
                      ),
                      contentPadding: const EdgeInsets.all(SaoSpacing.sm),
                      isDense: true,
                    ),
                  ),

                  // Success banner
                  if (lastSavedPath != null) ...[
                    const SizedBox(height: SaoSpacing.md),
                    Container(
                      padding: const EdgeInsets.all(SaoSpacing.sm),
                      decoration: BoxDecoration(
                        color: SaoColors.success.withOpacity(0.08),
                        border: Border.all(color: SaoColors.success),
                        borderRadius: BorderRadius.circular(SaoRadii.sm),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              color: SaoColors.success, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              lastSavedPath!,
                              style: SaoTypography.caption.copyWith(
                                color: SaoColors.success,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Action buttons pinned to bottom
          Container(
            padding: const EdgeInsets.all(SaoSpacing.md),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: SaoColors.border)),
            ),
            child: Column(
              children: [
                // Primary: Descargar PDF
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: canGenerate ? onGeneratePdf : null,
                    icon: isGenerating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.download_rounded, size: 18),
                    label: Text(isGenerating ? 'Generando…' : 'Descargar PDF'),
                    style: FilledButton.styleFrom(
                      backgroundColor: SaoColors.success,
                      padding: const EdgeInsets.symmetric(
                          vertical: SaoSpacing.md),
                    ),
                  ),
                ),
                const SizedBox(height: SaoSpacing.xs),

                // Secondary: Exportar ZIP
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onExportZip,
                    icon: const Icon(Icons.folder_zip_outlined, size: 16),
                    label: const Text('Exportar ZIP'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          vertical: SaoSpacing.sm),
                    ),
                  ),
                ),
                const SizedBox(height: SaoSpacing.xs),

                // Tertiary: Enviar Email
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: onSendEmail,
                    icon: const Icon(Icons.email_outlined, size: 16),
                    label: const Text('Enviar Email'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          vertical: SaoSpacing.sm),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Option tile: icon + title/subtitle + checkbox
class _OptionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _OptionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(SaoRadii.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: SaoSpacing.xs),
        child: Row(
          children: [
            Icon(icon, size: 18, color: SaoColors.gray500),
            const SizedBox(width: SaoSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: SaoTypography.bodyText
                          .copyWith(fontWeight: FontWeight.w500, fontSize: 13)),
                  Text(subtitle,
                      style: SaoTypography.caption
                          .copyWith(color: SaoColors.gray500)),
                ],
              ),
            ),
            Checkbox(
              value: value,
              onChanged: (v) => onChanged(v ?? false),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// Email dialog — opens default mail client via url_launcher
// ===========================================================================

class _EmailDialog extends StatefulWidget {
  final ReportFilters filters;
  const _EmailDialog({required this.filters});

  @override
  State<_EmailDialog> createState() => _EmailDialogState();
}

class _EmailDialogState extends State<_EmailDialog> {
  final _toController = TextEditingController();
  final _subjectController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _subjectController.text = 'Reporte SAO — ${widget.filters.projectId}';
  }

  @override
  void dispose() {
    _toController.dispose();
    _subjectController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.email_rounded, size: 20),
          SizedBox(width: 8),
          Text('Enviar por Email'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _toController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Para',
                hintText: 'destinatario@ejemplo.com',
                border: OutlineInputBorder(),
                isDense: true,
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _subjectController,
              decoration: const InputDecoration(
                labelText: 'Asunto',
                border: OutlineInputBorder(),
                isDense: true,
                prefixIcon: Icon(Icons.subject_rounded),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: SaoColors.info.withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 14, color: SaoColors.info),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Se abrirá tu cliente de correo con el asunto y '
                      'destinatario precargados.',
                      style: SaoTypography.caption.copyWith(
                        color: SaoColors.info,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: () async {
            final to = _toController.text.trim();
            if (to.isEmpty) return;
            final subject =
                Uri.encodeComponent(_subjectController.text.trim());
            final uri = Uri.parse('mailto:$to?subject=$subject');
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri);
            }
            if (context.mounted) Navigator.pop(context);
          },
          icon: const Icon(Icons.send_rounded, size: 16),
          label: const Text('Abrir en correo'),
        ),
      ],
    );
  }
}
