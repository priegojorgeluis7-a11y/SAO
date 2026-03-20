// lib/features/admin/stats/admin_activity_stats_page.dart
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/constants.dart';
import '../../../core/utils/snackbar.dart';
import '../../../data/local/app_db.dart';
import '../../../data/local/dao/activity_dao.dart';
import '../../../ui/theme/sao_colors.dart';
import '../../../ui/theme/sao_typography.dart';

class AdminActivityStatsPage extends StatefulWidget {
  const AdminActivityStatsPage({super.key});

  @override
  State<AdminActivityStatsPage> createState() => _AdminActivityStatsPageState();
}

class _AdminActivityStatsPageState extends State<AdminActivityStatsPage> {
  static const _rangeOptions = <int>[14, 30];

  ActivityStats? _stats;
  bool _loading = true;
  late final ActivityDao _dao;
  List<String> _projectOptions = const [kAllProjects];
  String _selectedProject = kAllProjects;
  int _selectedRangeDays = 14;

  @override
  void initState() {
    super.initState();
    _dao = ActivityDao(GetIt.I<AppDb>());
    _load();
  }

  DateTime _rangeStart() {
    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day);
    return dayStart.subtract(Duration(days: _selectedRangeDays - 1));
  }

  DateTime _rangeEnd() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
  }

  void _openHistory({String? projectCode, String? status, String? frente}) {
    final query = <String, String>{};
    final normalizedProject = (projectCode ?? _selectedProject).trim().toUpperCase();
    if (normalizedProject.isNotEmpty && normalizedProject != kAllProjects) {
      query['project'] = normalizedProject;
    }
    if (status != null && status.trim().isNotEmpty) {
      query['status'] = status.trim().toUpperCase();
    }
    if (frente != null && frente.trim().isNotEmpty) {
      query['frente'] = frente.trim();
    }
    final uri = Uri(path: '/admin/history', queryParameters: query.isEmpty ? null : query);
    context.push(uri.toString());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final projects = await _dao.listActiveProjects();
      final projectCodes = projects
          .map((p) => p.code.trim().toUpperCase())
          .where((c) => c.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

      final stats = await _dao.loadActivityStats(
        query: ActivityStatsQuery(
          projectCode: _selectedProject,
          fromDate: _rangeStart(),
          toDate: _rangeEnd(),
        ),
      );
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _projectOptions = [kAllProjects, ...projectCodes];
        if (!_projectOptions.contains(_selectedProject)) {
          _selectedProject = kAllProjects;
        }
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SaoColors.gray50,
      appBar: AppBar(
        backgroundColor: SaoColors.surface,
        surfaceTintColor: SaoColors.surface,
        title: const Text(
          'Estadísticas de Actividades',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Exportar CSV',
            onPressed: (_loading || _stats == null) ? null : _exportCsv,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualizar',
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _stats == null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: [
                      _buildFiltersCard(),
                      const SizedBox(height: 20),
                      _buildKpiRow(_stats!),
                      const SizedBox(height: 20),
                      _buildCompletionRate(_stats!),
                      const SizedBox(height: 20),
                      _buildProjectCompletionCard(_stats!),
                      const SizedBox(height: 20),
                      _buildStatusPieCard(_stats!),
                      const SizedBox(height: 20),
                      _buildStatusBarCard(_stats!),
                      const SizedBox(height: 20),
                      _buildDayBarCard(_stats!, _selectedRangeDays),
                      const SizedBox(height: 20),
                      _buildProjectBarCard(_stats!),
                      if (_stats!.byFrente.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _buildFrenteBarCard(_stats!),
                      ],
                      if (_stats!.byActivityType.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _buildTypeBarCard(_stats!),
                      ],
                      if (_stats!.byTopic.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _buildTopicBarCard(_stats!),
                      ],
                      if (_stats!.byRisk.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _buildRiskCard(_stats!),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _buildFiltersCard() {
    return _card(
      title: 'Contexto de análisis',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _selectedProject,
            decoration: const InputDecoration(
              labelText: 'Proyecto',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: _projectOptions
                .map(
                  (code) => DropdownMenuItem<String>(
                    value: code,
                    child: Text(code),
                  ),
                )
                .toList(),
            onChanged: _loading
                ? null
                : (value) {
                    if (value == null || value == _selectedProject) return;
                    setState(() => _selectedProject = value);
                    _load();
                  },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: _rangeOptions.map((days) {
              return ChoiceChip(
                label: Text('Últimos $days días'),
                selected: _selectedRangeDays == days,
                onSelected: _loading
                    ? null
                    : (selected) {
                        if (!selected || _selectedRangeDays == days) return;
                        setState(() => _selectedRangeDays = days);
                        _load();
                      },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── KPI cards ─────────────────────────────────────────────────

  Widget _buildKpiRow(ActivityStats s) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _kpiCard('Total', s.total, SaoColors.primary, Icons.assignment_rounded)),
            const SizedBox(width: 10),
            Expanded(child: _kpiCard('Completadas', s.completed, SaoColors.success, Icons.check_circle_rounded)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _kpiCard('Sincronizadas', s.synced, SaoColors.info, Icons.cloud_done_rounded)),
            const SizedBox(width: 10),
            Expanded(child: _kpiCard('Borradores', s.draft, SaoColors.gray500, Icons.edit_outlined)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _kpiCard('Rev. Pendiente', s.revisionPendiente, SaoColors.warning, Icons.pending_actions_rounded)),
            const SizedBox(width: 10),
            Expanded(child: _kpiCard('Listas para sync', s.readyToSync, SaoColors.statusEnCampo, Icons.upload_rounded)),
          ],
        ),
      ],
    );
  }

  Widget _kpiCard(String label, int value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SaoColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SaoColors.border),
        boxShadow: [
          BoxShadow(
            color: SaoColors.gray900.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value.toString(),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: SaoTypography.caption.copyWith(color: SaoColors.gray500),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Completion rate ───────────────────────────────────────────

  Widget _buildCompletionRate(ActivityStats s) {
    final rate = s.completionRate;
    return _card(
      title: 'Tasa de completado',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${(rate * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: rate >= 0.8
                      ? SaoColors.success
                      : rate >= 0.5
                          ? SaoColors.warning
                          : SaoColors.error,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'de ${s.total} actividades finalizadas o listas para sincronizar',
                  style: SaoTypography.caption.copyWith(color: SaoColors.gray500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: rate,
              minHeight: 10,
              backgroundColor: SaoColors.gray100,
              valueColor: AlwaysStoppedAnimation<Color>(
                rate >= 0.8
                    ? SaoColors.success
                    : rate >= 0.5
                        ? SaoColors.warning
                        : SaoColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectCompletionCard(ActivityStats s) {
    if (s.completionByProject.isEmpty) return const SizedBox.shrink();

    return _card(
      title: 'Avance por proyecto',
      child: Column(
        children: s.completionByProject.map((project) {
          final pct = project.completionRate;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 70,
                  child: Text(
                    project.projectCode,
                    style: SaoTypography.caption.copyWith(
                      color: SaoColors.gray700,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 10,
                      backgroundColor: SaoColors.gray100,
                      valueColor: const AlwaysStoppedAnimation<Color>(SaoColors.success),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 88,
                  child: Text(
                    '${project.completed}/${project.total} (${(pct * 100).toStringAsFixed(0)}%)',
                    style: SaoTypography.caption.copyWith(fontWeight: FontWeight.w700),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _exportCsv() async {
    final stats = _stats;
    if (stats == null) return;

    try {
      final now = DateTime.now();
      final safeProject = _selectedProject.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9_-]'), '_');
      final defaultBaseName = 'admin_stats_${safeProject}_${_selectedRangeDays}d';
      final directories = await _resolveExportDirectories();
      if (directories.isEmpty) {
        throw Exception('No hay directorios disponibles para exportar');
      }

      final exportConfig = await _showExportDialog(
        defaultBaseName: defaultBaseName,
        directories: directories,
      );
      if (exportConfig == null) return;

      final baseName = exportConfig.baseName.replaceAll(RegExp(r'\.csv$', caseSensitive: false), '');
      final summaryPath = p.join(exportConfig.directory.path, '${baseName}_resumen.csv');
      final detailPath = p.join(exportConfig.directory.path, '${baseName}_detalle.csv');

      final summaryFile = File(summaryPath);
      final summaryCsv = _buildCsv(stats, generatedAt: now);
      await summaryFile.writeAsString(summaryCsv, flush: true);

      final allRecords = await _dao.listAllActivitiesForAdmin();
      final detailRecords = allRecords.where(_matchesActiveFilters).toList();
      final detailCsv = _buildDetailCsv(detailRecords, generatedAt: now);
      final detailFile = File(detailPath);
      await detailFile.writeAsString(detailCsv, flush: true);

      if (!mounted) return;
      showTransientSnackBar(
        context,
        appSnackBar(
          message: 'CSV exportados:\n- ${summaryFile.path}\n- ${detailFile.path}',
          backgroundColor: SaoColors.success,
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showTransientSnackBar(
        context,
        appSnackBar(message: 'No se pudo exportar CSV: $e', backgroundColor: SaoColors.error),
      );
    }
  }

  Future<List<_ExportDirectoryOption>> _resolveExportDirectories() async {
    final results = <_ExportDirectoryOption>[];
    try {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) {
        results.add(_ExportDirectoryOption('Descargas', downloads));
      }
    } catch (_) {
      // Ignore and fallback to documentos.
    }

    try {
      final documents = await getApplicationDocumentsDirectory();
      final alreadyAdded = results.any((e) => e.directory.path == documents.path);
      if (!alreadyAdded) {
        results.add(_ExportDirectoryOption('Documentos app', documents));
      }
    } catch (_) {
      // Ignore.
    }
    return results;
  }

  Future<_ExportConfig?> _showExportDialog({
    required String defaultBaseName,
    required List<_ExportDirectoryOption> directories,
  }) async {
    final controller = TextEditingController(text: defaultBaseName);
    final formKey = GlobalKey<FormState>();
    _ExportDirectoryOption selectedDir = directories.first;

    final result = await showDialog<_ExportConfig>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Exportar estadísticas CSV'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: controller,
                      decoration: const InputDecoration(
                        labelText: 'Nombre base',
                        hintText: 'admin_stats_todos_14d',
                      ),
                      validator: (value) {
                        final trimmed = (value ?? '').trim();
                        if (trimmed.isEmpty) return 'Ingresa un nombre base';
                        if (trimmed.contains(RegExp(r'[\\/:*?"<>|]'))) {
                          return 'Nombre inválido para archivo';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedDir.label,
                      decoration: const InputDecoration(
                        labelText: 'Guardar en',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: directories
                          .map(
                            (option) => DropdownMenuItem<String>(
                              value: option.label,
                              child: Text('${option.label} (${option.directory.path})'),
                            ),
                          )
                          .toList(),
                      onChanged: (label) {
                        if (label == null) return;
                        final found = directories.firstWhere((d) => d.label == label);
                        setModalState(() => selectedDir = found);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton.icon(
                  onPressed: () {
                    if (formKey.currentState?.validate() != true) return;
                    Navigator.of(dialogContext).pop(
                      _ExportConfig(
                        baseName: controller.text.trim(),
                        directory: selectedDir.directory,
                      ),
                    );
                  },
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Exportar'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
    return result;
  }

  bool _matchesActiveFilters(AdminActivityRecord record) {
    final normalizedProjectFilter = _selectedProject.trim().toUpperCase();
    if (normalizedProjectFilter.isNotEmpty && normalizedProjectFilter != kAllProjects) {
      final recordProject = (record.projectCode ?? '').trim().toUpperCase();
      if (recordProject != normalizedProjectFilter) {
        return false;
      }
    }

    final createdAt = record.activity.createdAt;
    if (createdAt.isBefore(_rangeStart()) || createdAt.isAfter(_rangeEnd())) {
      return false;
    }

    return true;
  }

  String _buildDetailCsv(List<AdminActivityRecord> records, {required DateTime generatedAt}) {
    final rows = <List<String>>[];

    rows.add(['Detalle de actividades']);
    rows.add(['generated_at', generatedAt.toIso8601String()]);
    rows.add(['project_filter', _selectedProject]);
    rows.add(['range_days', _selectedRangeDays.toString()]);
    rows.add(['rows', records.length.toString()]);
    rows.add([]);

    rows.add([
      'activity_id',
      'project_code',
      'title',
      'status',
      'activity_type',
      'frente',
      'municipio',
      'estado',
      'assigned_to',
      'evidence_count',
      'created_at',
      'updated_at',
    ]);

    for (final r in records) {
      final a = r.activity;
      rows.add([
        a.id,
        r.projectCode ?? '',
        a.title,
        a.status,
        r.activityTypeName ?? '',
        r.frente ?? '',
        r.municipio ?? '',
        r.estado ?? '',
        r.assignedToName ?? '',
        r.evidenceCount.toString(),
        a.createdAt.toIso8601String(),
        (a.finishedAt ?? a.startedAt ?? a.createdAt).toIso8601String(),
      ]);
    }

    final buffer = StringBuffer();
    buffer.write('\uFEFF');
    for (final row in rows) {
      buffer.writeln(row.map(_csvCell).join(','));
    }
    return buffer.toString();
  }

  String _buildCsv(ActivityStats s, {required DateTime generatedAt}) {
    final rows = <List<String>>[];
    void addRow(List<String> row) => rows.add(row);
    void addSection(String title) {
      addRow([title]);
    }

    addSection('Meta');
    addRow(['generated_at', generatedAt.toIso8601String()]);
    addRow(['project_filter', _selectedProject]);
    addRow(['range_days', _selectedRangeDays.toString()]);
    addRow([]);

    addSection('Resumen');
    addRow(['metric', 'value']);
    addRow(['total', s.total.toString()]);
    addRow(['completed', s.completed.toString()]);
    addRow(['synced', s.synced.toString()]);
    addRow(['ready_to_sync', s.readyToSync.toString()]);
    addRow(['revision_pendiente', s.revisionPendiente.toString()]);
    addRow(['draft', s.draft.toString()]);
    addRow(['error', s.error.toString()]);
    addRow(['completion_rate_pct', (s.completionRate * 100).toStringAsFixed(2)]);
    addRow([]);

    addSection('Avance por proyecto');
    addRow(['project', 'completed', 'total', 'completion_rate_pct']);
    for (final p in s.completionByProject) {
      addRow([
        p.projectCode,
        p.completed.toString(),
        p.total.toString(),
        (p.completionRate * 100).toStringAsFixed(2),
      ]);
    }
    addRow([]);

    _addMapSection(rows, 'Por estado', <String, int>{
      'SYNCED': s.synced,
      'READY_TO_SYNC': s.readyToSync,
      'REVISION_PENDIENTE': s.revisionPendiente,
      'DRAFT': s.draft,
      'ERROR': s.error,
    });
    _addMapSection(rows, 'Por proyecto', s.byProject);
    _addMapSection(rows, 'Por frente', s.byFrente);
    _addMapSection(rows, 'Por tipo de actividad', s.byActivityType);
    _addMapSection(rows, 'Por tema', s.byTopic);
    _addMapSection(rows, 'Por riesgo', s.byRisk);
    _addMapSection(rows, 'Por día', s.byDay);

    final buffer = StringBuffer();
    buffer.write('\uFEFF');
    for (final row in rows) {
      buffer.writeln(row.map(_csvCell).join(','));
    }
    return buffer.toString();
  }

  void _addMapSection(List<List<String>> rows, String title, Map<String, int> map) {
    rows.add([title]);
    rows.add(['label', 'value']);
    final sorted = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    for (final entry in sorted) {
      rows.add([entry.key, entry.value.toString()]);
    }
    rows.add([]);
  }

  String _csvCell(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  // ── Pie chart por estado ───────────────────────────────────────

  Widget _buildStatusPieCard(ActivityStats s) {
    final data = <_PieSlice>[
      if (s.synced > 0) _PieSlice('Sincronizadas', s.synced, SaoColors.success),
      if (s.readyToSync > 0) _PieSlice('Listas para sync', s.readyToSync, SaoColors.info),
      if (s.revisionPendiente > 0) _PieSlice('Rev. Pendiente', s.revisionPendiente, SaoColors.warning),
      if (s.draft > 0) _PieSlice('Borrador', s.draft, SaoColors.gray400),
      if (s.error > 0) _PieSlice('Error', s.error, SaoColors.error),
    ];

    if (data.isEmpty) return const SizedBox.shrink();

    return _card(
      title: 'Distribución por estado',
      child: Row(
        children: [
          SizedBox(
            width: 160,
            height: 160,
            child: CustomPaint(
              painter: _PieChartPainter(slices: data, total: s.total),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: data.map((slice) {
                final pct = s.total == 0 ? 0.0 : slice.value / s.total * 100;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: slice.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          slice.label,
                          style: SaoTypography.caption,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${slice.value} (${pct.toStringAsFixed(0)}%)',
                        style: SaoTypography.caption.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bar chart por día ─────────────────────────────────────────

  Widget _buildDayBarCard(ActivityStats s, int daysCount) {
    final today = DateTime.now();
    final days = List.generate(daysCount, (i) {
      final d = DateTime(today.year, today.month, today.day)
          .subtract(Duration(days: (daysCount - 1) - i));
      final key =
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      return _BarItem(
        label: '${d.day}/${d.month}',
        value: s.byDay[key] ?? 0,
        color: SaoColors.info,
      );
    });

    return _card(
      title: 'Actividades últimos $daysCount días',
      child: _BarChart(items: days, maxBarHeight: 120),
    );
  }

  Widget _buildStatusBarCard(ActivityStats s) {
    final items = <_BarItem>[
      _BarItem(label: 'Sincronizadas', value: s.synced, color: SaoColors.success, tag: 'SYNCED'),
      _BarItem(label: 'Listas para sync', value: s.readyToSync, color: SaoColors.info, tag: 'READY_TO_SYNC'),
      _BarItem(label: 'Rev. Pendiente', value: s.revisionPendiente, color: SaoColors.warning, tag: 'REVISION_PENDIENTE'),
      _BarItem(label: 'Borrador', value: s.draft, color: SaoColors.gray500, tag: 'DRAFT'),
      _BarItem(label: 'Error', value: s.error, color: SaoColors.error, tag: 'ERROR'),
    ].where((it) => it.value > 0).toList();

    if (items.isEmpty) return const SizedBox.shrink();

    return _card(
      title: 'Estado operacional',
      child: _HBarChart(
        items: items,
        onTapItem: (item) => _openHistory(status: item.tag),
      ),
    );
  }

  // ── Bar chart por proyecto ────────────────────────────────────

  Widget _buildProjectBarCard(ActivityStats s) {
    if (s.byProject.isEmpty) return const SizedBox.shrink();
    final items = s.byProject.entries
        .map((e) => _BarItem(label: e.key, value: e.value, color: SaoColors.primary))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return _card(
      title: 'Actividades por proyecto',
      child: _HBarChart(
        items: items,
        onTapItem: (item) => _openHistory(projectCode: item.label),
      ),
    );
  }

  // ── Bar chart por frente (top 8) ──────────────────────────────

  Widget _buildFrenteBarCard(ActivityStats s) {
    final top = (s.byFrente.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(8)
        .map((e) => _BarItem(label: e.key, value: e.value, color: SaoColors.actionPrimary))
        .toList();

    return _card(
      title: 'Top frentes',
      child: _HBarChart(
        items: top,
        onTapItem: (item) => _openHistory(frente: item.label),
      ),
    );
  }

  // ── Bar chart por tipo de actividad (top 8) ───────────────────

  Widget _buildTypeBarCard(ActivityStats s) {
    final top = (s.byActivityType.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(8)
        .map((e) => _BarItem(label: e.key, value: e.value, color: SaoColors.statusEnValidacion))
        .toList();

    return _card(
      title: 'Por tipo de actividad',
      child: _HBarChart(items: top),
    );
  }

  Widget _buildTopicBarCard(ActivityStats s) {
    final top = (s.byTopic.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(10)
        .map((e) => _BarItem(label: e.key, value: e.value, color: SaoColors.info))
        .toList();

    if (top.isEmpty) return const SizedBox.shrink();

    return _card(
      title: 'Por tema',
      child: _HBarChart(items: top),
    );
  }

  // ── Risk chips ────────────────────────────────────────────────

  Widget _buildRiskCard(ActivityStats s) {
    final riskColors = <String, Color>{
      'bajo': SaoColors.riskLow,
      'medio': SaoColors.riskMedium,
      'alto': SaoColors.riskHigh,
      'prioritario': SaoColors.riskPriority,
    };
    final riskLabels = <String, String>{
      'bajo': 'Bajo',
      'medio': 'Medio',
      'alto': 'Alto',
      'prioritario': 'Prioritario',
    };
    final total = s.byRisk.values.fold(0, (a, b) => a + b);

    final sortedRisk = s.byRisk.entries.toList()
      ..sort((a, b) {
        const order = ['prioritario', 'alto', 'medio', 'bajo'];
        final ia = order.indexOf(a.key);
        final ib = order.indexOf(b.key);
        return (ia == -1 ? 99 : ia).compareTo(ib == -1 ? 99 : ib);
      });

    return _card(
      title: 'Distribución por riesgo',
      child: Column(
        children: sortedRisk.map((e) {
          final color = riskColors[e.key] ?? SaoColors.gray400;
          final label = riskLabels[e.key] ?? e.key;
          final pct = total == 0 ? 0.0 : e.value / total;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 80,
                  child: Text(
                    label,
                    style: SaoTypography.caption.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 8,
                      backgroundColor: color.withValues(alpha: 0.12),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  e.value.toString(),
                  style: SaoTypography.caption.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildError() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: SaoColors.gray400),
            const SizedBox(height: 12),
            Text('No se pudieron cargar las estadísticas.',
                style: SaoTypography.bodyTextSmall.copyWith(color: SaoColors.gray500)),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );

  Widget _card({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SaoColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SaoColors.border),
        boxShadow: [
          BoxShadow(
            color: SaoColors.gray900.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: SaoTypography.sectionTitle),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pie chart con CustomPainter
// ─────────────────────────────────────────────────────────────────────────────

class _PieSlice {
  final String label;
  final int value;
  final Color color;
  const _PieSlice(this.label, this.value, this.color);
}

class _PieChartPainter extends CustomPainter {
  final List<_PieSlice> slices;
  final int total;

  const _PieChartPainter({required this.slices, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    if (total == 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 4;
    const strokeWidth = 28.0;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    double startAngle = -math.pi / 2;
    for (final slice in slices) {
      final sweep = 2 * math.pi * slice.value / total;
      paint.color = slice.color;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        false,
        paint,
      );
      startAngle += sweep;
    }

    // Gap lines between slices
    final gapPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    double gapAngle = -math.pi / 2;
    for (final slice in slices) {
      final sweep = 2 * math.pi * slice.value / total;
      final innerR = radius - strokeWidth / 2;
      final outerR = radius + strokeWidth / 2;
      canvas.drawLine(
        Offset(center.dx + innerR * math.cos(gapAngle),
            center.dy + innerR * math.sin(gapAngle)),
        Offset(center.dx + outerR * math.cos(gapAngle),
            center.dy + outerR * math.sin(gapAngle)),
        gapPaint,
      );
      gapAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(_PieChartPainter old) => old.slices != slices || old.total != total;
}

// ─────────────────────────────────────────────────────────────────────────────
// Bar chart vertical (para días)
// ─────────────────────────────────────────────────────────────────────────────

class _BarItem {
  final String label;
  final int value;
  final Color color;
  final String? tag;

  const _BarItem({
    required this.label,
    required this.value,
    required this.color,
    this.tag,
  });
}

class _BarChart extends StatelessWidget {
  final List<_BarItem> items;
  final double maxBarHeight;

  const _BarChart({required this.items, this.maxBarHeight = 120});

  @override
  Widget build(BuildContext context) {
    final maxValue = items.fold(0, (m, i) => math.max(m, i.value));
    if (maxValue == 0) {
      return Center(
        child: Text('Sin datos en el período',
            style: SaoTypography.caption.copyWith(color: SaoColors.gray400)),
      );
    }

    return SizedBox(
      height: maxBarHeight + 36,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: items.map((item) {
          final frac = maxValue == 0 ? 0.0 : item.value / maxValue;
          final barH = maxBarHeight * frac;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (item.value > 0)
                    Text(
                      item.value.toString(),
                      style: SaoTypography.caption.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: item.color,
                      ),
                    ),
                  const SizedBox(height: 2),
                  Container(
                    height: math.max(barH, item.value > 0 ? 3 : 0),
                    decoration: BoxDecoration(
                      color: item.value > 0
                          ? item.color.withValues(alpha: 0.85)
                          : SaoColors.gray100,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.label,
                    style: SaoTypography.caption.copyWith(fontSize: 9, color: SaoColors.gray400),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.visible,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bar chart horizontal (para proyectos, frentes, tipos)
// ─────────────────────────────────────────────────────────────────────────────

class _HBarChart extends StatelessWidget {
  final List<_BarItem> items;
  final ValueChanged<_BarItem>? onTapItem;

  const _HBarChart({required this.items, this.onTapItem});

  @override
  Widget build(BuildContext context) {
    final maxValue = items.fold(0, (m, i) => math.max(m, i.value));
    if (maxValue == 0) {
      return Text('Sin datos', style: SaoTypography.caption.copyWith(color: SaoColors.gray400));
    }

    return Column(
      children: items.map((item) {
        final frac = maxValue == 0 ? 0.0 : item.value / maxValue;
        final row = Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              SizedBox(
                width: 100,
                child: Text(
                  item.label,
                  style: SaoTypography.caption.copyWith(color: SaoColors.gray600),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: frac,
                    minHeight: 14,
                    backgroundColor: item.color.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(item.color),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 28,
                child: Text(
                  item.value.toString(),
                  style: SaoTypography.caption.copyWith(fontWeight: FontWeight.w800),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        );

        if (onTapItem == null) {
          return row;
        }

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => onTapItem!(item),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: row,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ExportDirectoryOption {
  final String label;
  final Directory directory;

  const _ExportDirectoryOption(this.label, this.directory);
}

class _ExportConfig {
  final String baseName;
  final Directory directory;

  const _ExportConfig({required this.baseName, required this.directory});
}
