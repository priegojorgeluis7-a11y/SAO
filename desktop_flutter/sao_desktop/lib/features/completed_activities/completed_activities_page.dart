import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/widgets.dart' as pw;
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers/project_providers.dart';
import '../../data/repositories/evidence_repository.dart';
import '../../ui/sao_ui.dart';
import 'completed_activities_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Page root
// ─────────────────────────────────────────────────────────────────────────────

class CompletedActivitiesPage extends ConsumerStatefulWidget {
  const CompletedActivitiesPage({super.key});

  @override
  ConsumerState<CompletedActivitiesPage> createState() =>
      _CompletedActivitiesPageState();
}

class _CompletedActivitiesPageState
    extends ConsumerState<CompletedActivitiesPage> {
  final _searchCtrl = TextEditingController();
  String? _selectedActivityId;
  DateTime _lastSearch = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final globalProject = ref.read(activeProjectIdProvider);
      if (globalProject.isNotEmpty) {
        ref.read(completedProjectFilterProvider.notifier).state = globalProject;
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _clearAll() {
    _searchCtrl.clear();
    ref.read(completedSearchQueryProvider.notifier).state    = '';
    ref.read(completedFrenteFilterProvider.notifier).state   = '';
    ref.read(completedTemaFilterProvider.notifier).state     = '';
    ref.read(completedEstadoFilterProvider.notifier).state   = '';
    ref.read(completedMunicipioFilterProvider.notifier).state = '';
    ref.read(completedUsuarioFilterProvider.notifier).state  = '';
  }

  void _resetDependentFilters() {
    ref.read(completedFrenteFilterProvider.notifier).state   = '';
    ref.read(completedTemaFilterProvider.notifier).state     = '';
    ref.read(completedEstadoFilterProvider.notifier).state   = '';
    ref.read(completedMunicipioFilterProvider.notifier).state = '';
    ref.read(completedUsuarioFilterProvider.notifier).state  = '';
  }

  @override
  Widget build(BuildContext context) {
    final projectsAsync   = ref.watch(availableProjectsProvider);
    final selectedProject = ref.watch(completedProjectFilterProvider);
    final activitiesAsync = ref.watch(completedActivitiesProvider);
    final frente = ref.watch(completedFrenteFilterProvider);
    final tema = ref.watch(completedTemaFilterProvider);
    final estado = ref.watch(completedEstadoFilterProvider);
    final municipio = ref.watch(completedMunicipioFilterProvider);
    final usuario = ref.watch(completedUsuarioFilterProvider);
    final query = ref.watch(completedSearchQueryProvider);

    final activeFilters = <String, String>{
      if (selectedProject.isNotEmpty) 'Proyecto': selectedProject,
      if (frente.isNotEmpty) 'Frente': frente,
      if (tema.isNotEmpty) 'Tema/Tipo': tema,
      if (estado.isNotEmpty) 'Estado': estado,
      if (municipio.isNotEmpty) 'Municipio': municipio,
      if (usuario.isNotEmpty) 'Responsable': usuario,
      if (query.isNotEmpty) 'B\u00fasqueda': query,
    };

    // Reset dependent filters when project changes
    ref.listen(completedProjectFilterProvider, (_, __) {
      _resetDependentFilters();
    });

    return Scaffold(
      backgroundColor: SaoColors.gray50,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PageHeader(
            total: activitiesAsync.maybeWhen(
                data: (d) => d.length, orElse: () => null),
            hasSelection: _selectedActivityId != null,
            onRefresh: () {
              ref.invalidate(completedActivitiesProvider);
              ref.invalidate(completedFilterOptionsProvider);
            },
          ),

          _FilterBar(
            projectsAsync:    projectsAsync,
            selectedProject:  selectedProject,
            searchCtrl:       _searchCtrl,
            searchSuggestions: activitiesAsync.maybeWhen(
              data: (items) => items
                  .expand((a) => [a.pk, a.title, a.activityType])
                  .where((v) => v.trim().isNotEmpty)
                  .toSet()
                  .toList(growable: false),
              orElse: () => const <String>[],
            ),
            activeFilters: activeFilters,
            onProjectChanged: (v) {
              ref.read(completedProjectFilterProvider.notifier).state = v ?? '';
            },
            onSearchChanged: (v) {
              final now = DateTime.now();
              if (now.difference(_lastSearch) >
                  const Duration(milliseconds: 350)) {
                _lastSearch = now;
                ref.read(completedSearchQueryProvider.notifier).state = v;
              }
            },
            onClearAll: _clearAll,
            onRemoveFilter: (key) {
              switch (key) {
                case 'Proyecto':
                  ref.read(completedProjectFilterProvider.notifier).state = '';
                  break;
                case 'Frente':
                  ref.read(completedFrenteFilterProvider.notifier).state = '';
                  break;
                case 'Tema/Tipo':
                  ref.read(completedTemaFilterProvider.notifier).state = '';
                  break;
                case 'Estado':
                  ref.read(completedEstadoFilterProvider.notifier).state = '';
                  break;
                case 'Municipio':
                  ref.read(completedMunicipioFilterProvider.notifier).state = '';
                  break;
                case 'Responsable':
                  ref.read(completedUsuarioFilterProvider.notifier).state = '';
                  break;
                case 'B\u00fasqueda':
                  _searchCtrl.clear();
                  ref.read(completedSearchQueryProvider.notifier).state = '';
                  break;
              }
            },
          ),

          const Divider(height: 1),

          Expanded(
            child: activitiesAsync.when(
              loading: () => const _TableSkeletonState(),
              error: (e, _) => _ErrorState(message: e.toString()),
              data: (items) => items.isEmpty
                  ? const _EmptyState()
                  : _SplitView(
                      items:              items,
                      selectedActivityId: _selectedActivityId,
                      onSelectActivity:   (id) =>
                          setState(() => _selectedActivityId = id),
                      onCloseDetail: () =>
                          setState(() => _selectedActivityId = null),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────

class _PageHeader extends StatelessWidget {
  final int? total;
  final bool hasSelection;
  final VoidCallback onRefresh;

  const _PageHeader({
    this.total,
    required this.hasSelection,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(
        children: [
          Icon(Icons.task_alt_rounded, color: SaoColors.success, size: 20),
          const SizedBox(width: 10),
          Text('Actividades Completadas',
              style: SaoTypography.pageTitle.copyWith(fontSize: 17)),
          const SizedBox(width: 8),
          if (total != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: SaoColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('$total',
                  style: SaoTypography.bodyTextBold
                      .copyWith(color: SaoColors.success, fontSize: 12)),
            ),
          const Spacer(),
          if (hasSelection)
            Text('Trazabilidad completa →',
                style: SaoTypography.caption
                    .copyWith(color: SaoColors.actionPrimary, fontSize: 12)),
          const SizedBox(width: 16),
          Text('Solo actividades APROBADAS',
              style: SaoTypography.caption
                  .copyWith(color: SaoColors.gray400, fontSize: 11)),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 18),
            tooltip: 'Actualizar',
            onPressed: onRefresh,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter bar  — all dropdowns, options loaded from backend
// ─────────────────────────────────────────────────────────────────────────────

class _FilterBar extends ConsumerWidget {
  final AsyncValue<List<String>> projectsAsync;
  final String selectedProject;
  final TextEditingController searchCtrl;
  final List<String> searchSuggestions;
  final Map<String, String> activeFilters;
  final ValueChanged<String?> onProjectChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearAll;
  final ValueChanged<String> onRemoveFilter;

  const _FilterBar({
    required this.projectsAsync,
    required this.selectedProject,
    required this.searchCtrl,
    required this.searchSuggestions,
    required this.activeFilters,
    required this.onProjectChanged,
    required this.onSearchChanged,
    required this.onClearAll,
    required this.onRemoveFilter,
  });

  static InputDecoration _deco(String label) => InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 12, color: SaoColors.gray400),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: SaoColors.gray200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: SaoColors.gray200),
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = projectsAsync.maybeWhen(
        data: (d) => d, orElse: () => <String>[]);

    final optAsync = ref.watch(completedFilterOptionsProvider);
    final opts = optAsync.maybeWhen(
        data: (o) => o, orElse: () => const FilterOptions.empty());
    final isLoading = optAsync.isLoading;

    final frente    = ref.watch(completedFrenteFilterProvider);
    final tema      = ref.watch(completedTemaFilterProvider);
    final estado    = ref.watch(completedEstadoFilterProvider);
    final municipio = ref.watch(completedMunicipioFilterProvider);
    final usuario   = ref.watch(completedUsuarioFilterProvider);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
          // ── Proyecto ────────────────────────────────────────────────────────
          SizedBox(
            width: 160,
            child: DropdownButtonFormField<String>(
              value: selectedProject.isEmpty ? null : selectedProject,
              decoration: _deco('Proyecto'),
              isExpanded: true,
              items: [
                const DropdownMenuItem(value: '', child: Text('Todos')),
                ...projects.map((p) =>
                    DropdownMenuItem(value: p, child: Text(p))),
              ],
              onChanged: onProjectChanged,
            ),
          ),

          // ── Búsqueda libre ──────────────────────────────────────────────────
              SizedBox(
                width: 260,
                child: _SearchAutocompleteField(
                  controller: searchCtrl,
                  suggestions: searchSuggestions,
                  onChanged: onSearchChanged,
                ),
              ),

          // ── Frente ──────────────────────────────────────────────────────────
          _OptionDropdown(
            label: 'Frente',
            width: 150,
            value: frente.isEmpty ? null : frente,
            options: opts.frentes,
            loading: isLoading,
            onChanged: (v) =>
                ref.read(completedFrenteFilterProvider.notifier).state = v ?? '',
          ),

          // ── Tema / Tipo ─────────────────────────────────────────────────────
          _OptionDropdown(
            label: 'Tema / Tipo',
            width: 150,
            value: tema.isEmpty ? null : tema,
            options: opts.temas,
            loading: isLoading,
            onChanged: (v) =>
                ref.read(completedTemaFilterProvider.notifier).state = v ?? '',
          ),

          // ── Estado ──────────────────────────────────────────────────────────
          _OptionDropdown(
            label: 'Estado',
            width: 140,
            value: estado.isEmpty ? null : estado,
            options: opts.estados,
            loading: isLoading,
            onChanged: (v) =>
                ref.read(completedEstadoFilterProvider.notifier).state = v ?? '',
          ),

          // ── Municipio ───────────────────────────────────────────────────────
          _OptionDropdown(
            label: 'Municipio',
            width: 150,
            value: municipio.isEmpty ? null : municipio,
            options: opts.municipios,
            loading: isLoading,
            onChanged: (v) =>
                ref.read(completedMunicipioFilterProvider.notifier).state =
                    v ?? '',
          ),

          // ── Responsable ─────────────────────────────────────────────────────
          _OptionDropdown(
            label: 'Responsable',
            width: 170,
            value: usuario.isEmpty ? null : usuario,
            options: opts.usuarios,
            loading: isLoading,
            icon: Icons.person_outlined,
            onChanged: (v) =>
                ref.read(completedUsuarioFilterProvider.notifier).state =
                    v ?? '',
          ),

          // ── Limpiar ─────────────────────────────────────────────────────────
              TextButton.icon(
                onPressed: onClearAll,
                icon: const Icon(Icons.filter_alt_off_rounded, size: 15),
                label: const Text('Limpiar'),
                style: TextButton.styleFrom(
                  foregroundColor: SaoColors.gray500,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ),
          if (activeFilters.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: activeFilters.entries
                  .map(
                    (e) => InputChip(
                      label: Text('${e.key}: ${e.value}'),
                      onDeleted: () => onRemoveFilter(e.key),
                      deleteIcon: const Icon(Icons.close_rounded, size: 14),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      labelStyle: SaoTypography.caption.copyWith(
                        color: SaoColors.gray700,
                        fontSize: 11,
                      ),
                      backgroundColor: SaoColors.gray100,
                      side: BorderSide(color: SaoColors.gray200),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }
}

// Reusable options dropdown with "Todos" as first element
class _OptionDropdown extends StatelessWidget {
  final String label;
  final double width;
  final String? value;
  final List<String> options;
  final bool loading;
  final IconData? icon;
  final ValueChanged<String?> onChanged;

  const _OptionDropdown({
    required this.label,
    required this.width,
    required this.value,
    required this.options,
    required this.onChanged,
    this.loading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedOptions = <String, String>{};
    for (final raw in options) {
      final option = raw.trim();
      if (option.isEmpty) continue;
      normalizedOptions.putIfAbsent(option.toLowerCase(), () => option);
    }
    final dedupedOptions = normalizedOptions.values.toList();

    String? safeValue;
    final current = (value ?? '').trim();
    if (current.isNotEmpty) {
      safeValue = normalizedOptions[current.toLowerCase()];
    }

    return SizedBox(
      width: width,
      child: DropdownButtonFormField<String>(
        value: safeValue,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: loading ? '$label…' : label,
          labelStyle: TextStyle(fontSize: 12, color: SaoColors.gray400),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          prefixIcon: icon != null
              ? Icon(icon, size: 15, color: SaoColors.gray400)
              : null,
          prefixIconConstraints:
              const BoxConstraints(minWidth: 28, minHeight: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: SaoColors.gray200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: SaoColors.gray200),
          ),
          suffixIcon: loading
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  ),
                )
              : null,
        ),
        items: [
          const DropdownMenuItem<String>(
              value: null, child: Text('Todos', style: TextStyle(fontSize: 13))),
          ...dedupedOptions.map((o) => DropdownMenuItem<String>(
                value: o,
                child:
                    Text(o, style: const TextStyle(fontSize: 13)),
              )),
        ],
        onChanged: loading ? null : onChanged,
      ),
    );
  }
}

class _SearchAutocompleteField extends StatelessWidget {
  final TextEditingController controller;
  final List<String> suggestions;
  final ValueChanged<String> onChanged;

  const _SearchAutocompleteField({
    required this.controller,
    required this.suggestions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: controller.text),
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.trim().toLowerCase();
        if (query.isEmpty) return const Iterable<String>.empty();
        return suggestions.where(
          (s) => s.toLowerCase().contains(query),
        ).take(8);
      },
      onSelected: (value) {
        controller.text = value;
        onChanged(value);
      },
      fieldViewBuilder: (context, textCtrl, focusNode, onFieldSubmitted) {
        if (textCtrl.text != controller.text) {
          textCtrl.value = TextEditingValue(
            text: controller.text,
            selection: TextSelection.collapsed(offset: controller.text.length),
          );
        }
        return TextField(
          controller: textCtrl,
          focusNode: focusNode,
          decoration: _FilterBar._deco('Buscar PK / título…'),
          onChanged: (value) {
            controller.text = value;
            onChanged(value);
          },
          onSubmitted: onChanged,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Split view: table ← → detail panel
// ─────────────────────────────────────────────────────────────────────────────

class _SplitView extends StatelessWidget {
  final List<CompletedActivity> items;
  final String? selectedActivityId;
  final ValueChanged<String> onSelectActivity;
  final VoidCallback onCloseDetail;

  const _SplitView({
    required this.items,
    required this.selectedActivityId,
    required this.onSelectActivity,
    required this.onCloseDetail,
  });

  static const _panelWidth = 440.0;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _ActivitiesTable(
                  items: items,
                  selectedActivityId: selectedActivityId,
                  onTap: onSelectActivity,
                ),
              ),
            ],
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          width: selectedActivityId != null ? _panelWidth : 0,
          clipBehavior: Clip.hardEdge,
          decoration: const BoxDecoration(),
          child: selectedActivityId != null
              ? _DetailPanel(
                  activityId: selectedActivityId!,
                  onClose: onCloseDetail,
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _TopSummaryStrip extends StatelessWidget {
  final List<CompletedActivity> items;
  const _TopSummaryStrip({required this.items});

  @override
  Widget build(BuildContext context) {
    final approved = items.where((i) => i.reviewDecision == 'APPROVE').length;
    final approvedException =
        items.where((i) => i.reviewDecision == 'APPROVE_EXCEPTION').length;
    final rejected = items
        .where((i) => i.reviewDecision.toUpperCase().contains('REJECT'))
        .length;
    final withEvidence = items.where((i) => i.evidenceCount > 0).length;
    final withReport = items.where((i) => i.hasReport).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SaoColors.gray200),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: _MiniPieChart(
              approved: approved,
              approvedException: approvedException,
              rejected: rejected,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _SummaryChip(
                  color: SaoColors.success,
                  label: 'Aprobadas',
                  count: approved,
                ),
                _SummaryChip(
                  color: const Color(0xFFD97706),
                  label: 'Con observaciones',
                  count: approvedException,
                ),
                _SummaryChip(
                  color: SaoColors.error,
                  label: 'Rechazadas',
                  count: rejected,
                ),
                _SummaryChip(
                  color: SaoColors.actionPrimary,
                  label: 'Total',
                  count: items.length,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 280,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CoverageBar(
                  label: 'Con evidencias',
                  value: '$withEvidence/${items.length}',
                  ratio: items.isEmpty ? 0 : withEvidence / items.length,
                  color: SaoColors.actionPrimary,
                ),
                const SizedBox(height: 6),
                _CoverageBar(
                  label: 'Con reporte',
                  value: '$withReport/${items.length}',
                  ratio: items.isEmpty ? 0 : withReport / items.length,
                  color: const Color(0xFF7C3AED),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final Color color;
  final String label;
  final int count;

  const _SummaryChip({
    required this.color,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $count',
        style: SaoTypography.caption.copyWith(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MiniPieChart extends StatelessWidget {
  final int approved;
  final int approvedException;
  final int rejected;

  const _MiniPieChart({
    required this.approved,
    required this.approvedException,
    required this.rejected,
  });

  @override
  Widget build(BuildContext context) {
    final total = approved + approvedException + rejected;
    if (total == 0) {
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: SaoColors.gray200),
        ),
        child: Center(
          child: Text(
            '0',
            style: SaoTypography.caption.copyWith(color: SaoColors.gray400),
          ),
        ),
      );
    }

    return CustomPaint(
      painter: _PiePainter(
        slices: [
          (approved / total, SaoColors.success),
          (approvedException / total, const Color(0xFFD97706)),
          (rejected / total, SaoColors.error),
        ],
      ),
      child: Center(
        child: Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _PiePainter extends CustomPainter {
  final List<(double, Color)> slices;
  const _PiePainter({required this.slices});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.butt;

    double start = -1.57079632679;
    for (final (portion, color) in slices) {
      if (portion <= 0) continue;
      stroke.color = color;
      final sweep = 6.28318530718 * portion;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 5),
        start,
        sweep,
        false,
        stroke,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _PiePainter oldDelegate) {
    return oldDelegate.slices != slices;
  }
}

class _TableSkeletonState extends StatelessWidget {
  const _TableSkeletonState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: List.generate(
          8,
          (index) => Container(
            height: 36,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: SaoColors.gray100,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      ),
    );
  }
}

class _CoverageBar extends StatelessWidget {
  final String label;
  final String value;
  final double ratio;
  final Color color;

  const _CoverageBar({
    required this.label,
    required this.value,
    required this.ratio,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: SaoTypography.caption.copyWith(
                  fontSize: 11,
                  color: SaoColors.gray600,
                ),
              ),
            ),
            Text(
              value,
              style: SaoTypography.caption.copyWith(
                fontSize: 11,
                color: SaoColors.gray700,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: ratio.clamp(0, 1),
            minHeight: 7,
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Activities table
// ─────────────────────────────────────────────────────────────────────────────

class _ActivitiesTable extends StatefulWidget {
  final List<CompletedActivity> items;
  final String? selectedActivityId;
  final ValueChanged<String> onTap;

  const _ActivitiesTable({
    required this.items,
    required this.selectedActivityId,
    required this.onTap,
  });

  @override
  State<_ActivitiesTable> createState() => _ActivitiesTableState();
}

class _ActivitiesTableState extends State<_ActivitiesTable> {
  final _vertCtrl  = ScrollController();
  final _horizCtrl = ScrollController();
  final Map<String, bool> _columnVisible = {
    'Proyecto': true,
    'PK': true,
    'Actividad / Tema': true,
    'Frente': true,
    'Estado': true,
    'Municipio': true,
    'Responsable': true,
    'Revisó': true,
    'Duración': true,
    'Decisión': true,
    'Reporte': true,
    'Evidencias': true,
    'Fecha revisión': true,
  };

  @override
  void dispose() {
    _vertCtrl.dispose();
    _horizCtrl.dispose();
    super.dispose();
  }

  String _fmtDate(String raw) {
    if (raw.isEmpty) return '—';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return DateFormat('dd/MM/yy HH:mm').format(dt.toLocal());
  }

  String _durationBetween(String startRaw, String endRaw) {
    final start = DateTime.tryParse(startRaw);
    final end = DateTime.tryParse(endRaw);
    if (start == null || end == null) return '—';
    final diff = end.toLocal().difference(start.toLocal());
    if (diff.inMinutes < 0) return '—';
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    if (h == 0) return '${diff.inMinutes}m';
    return '${h}h ${m}m';
  }

  bool _isMissing(String text) {
    final t = text.trim();
    if (t.isEmpty || t == '—') return true;
    return t.toLowerCase().startsWith('sin ');
  }

  @override
  Widget build(BuildContext context) {
    final visible = _columnVisible.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList(growable: false);

    final columns = visible
        .map((name) => DataColumn(label: Text(name)))
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
          child: Row(
            children: [
              const Spacer(),
              PopupMenuButton<String>(
                tooltip: 'Ocultar/mostrar columnas',
                icon: const Icon(Icons.tune_rounded, size: 18),
                itemBuilder: (context) => _columnVisible.entries
                    .map(
                      (e) => CheckedPopupMenuItem<String>(
                        value: e.key,
                        checked: e.value,
                        child: Text(e.key),
                      ),
                    )
                    .toList(growable: false),
                onSelected: (value) {
                  setState(() {
                    final currentlyVisible =
                        _columnVisible.values.where((v) => v).length;
                    final isOn = _columnVisible[value] ?? true;
                    if (isOn && currentlyVisible == 1) return;
                    _columnVisible[value] = !isOn;
                  });
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, viewport) {
              return Scrollbar(
                controller: _vertCtrl,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _vertCtrl,
                  child: Scrollbar(
                    controller: _horizCtrl,
                    thumbVisibility: true,
                    notificationPredicate: (n) => n.depth == 1,
                    child: SingleChildScrollView(
                      controller: _horizCtrl,
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: viewport.maxWidth),
                        child: DataTable(
                          showCheckboxColumn: false,
                          columnSpacing: 12,
                          headingRowHeight: 38,
                          dataRowMinHeight: 40,
                          dataRowMaxHeight: 50,
                          headingRowColor:
                              WidgetStateProperty.all(SaoColors.gray100),
                          border: TableBorder(
                            horizontalInside:
                                BorderSide(color: SaoColors.gray200, width: 0.5),
                          ),
                          columns: columns,
                          rows: widget.items
                              .map((a) => _buildRow(a, visible))
                              .toList(growable: false),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  DataRow _buildRow(CompletedActivity a, List<String> visible) {
    final isSelected = a.id == widget.selectedActivityId;
    final allCells = <String, DataCell>{
      'Proyecto': DataCell(_pill(a.projectId,
          SaoColors.actionPrimary.withValues(alpha: 0.1),
          SaoColors.actionPrimary)),
      'PK': DataCell(Text(a.pk,
          style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: Color(0xFF475569)))),
      'Actividad / Tema': DataCell(SizedBox(
        width: 190,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              a.title.isNotEmpty ? a.title : a.activityType,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: SaoTypography.bodyText.copyWith(fontSize: 12),
            ),
            if (a.activityType.isNotEmpty && a.title.isNotEmpty)
              Text(a.activityType,
                  style: SaoTypography.caption
                      .copyWith(color: SaoColors.gray400)),
          ],
        ),
      )),
      'Frente': DataCell(_txt(a.front, w: 110)),
      'Estado': DataCell(_txt(a.estado, w: 100)),
      'Municipio': DataCell(_txt(a.municipio, w: 110)),
      'Responsable': DataCell(_txt(a.assignedName, w: 120)),
      'Revisó': DataCell(_txt(a.reviewedByName, w: 120)),
      'Duración': DataCell(Text(
        _durationBetween(a.createdAt, a.reviewedAt),
        style: SaoTypography.caption.copyWith(fontSize: 11, color: SaoColors.gray600),
      )),
      'Decisión': DataCell(_DecisionBadge(decision: a.reviewDecision)),
      'Reporte': DataCell(
        Icon(
          a.hasReport ? Icons.description_outlined : Icons.remove_circle_outline_rounded,
          size: 14,
          color: a.hasReport ? SaoColors.actionPrimary : SaoColors.gray300,
        ),
      ),
      'Evidencias': DataCell(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.photo_library_outlined,
              size: 13, color: SaoColors.gray400),
          const SizedBox(width: 3),
          Text('${a.evidenceCount}',
              style: SaoTypography.caption.copyWith(fontSize: 12)),
        ],
      )),
      'Fecha revisión': DataCell(Text(_fmtDate(a.reviewedAt),
          style: SaoTypography.caption
              .copyWith(fontSize: 11, color: SaoColors.gray500))),
    };

    return DataRow(
      selected: isSelected,
      color: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return SaoColors.actionPrimary.withValues(alpha: 0.08);
        }
        return null;
      }),
      onSelectChanged: (_) => widget.onTap(a.id),
      cells: visible.map((name) => allCells[name]!).toList(growable: false),
    );
  }

  Widget _pill(String text, Color bg, Color fg) {
    if (text.isEmpty) return const Text('—');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(text,
          style: SaoTypography.caption.copyWith(color: fg, fontSize: 11)),
    );
  }

  Widget _txt(String text, {double? w}) {
    final content = !_isMissing(text)
        ? Text(text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SaoTypography.bodyText.copyWith(fontSize: 12))
        : Text('—',
            style: SaoTypography.caption
                .copyWith(color: SaoColors.gray200));
    return w != null ? SizedBox(width: w, child: content) : content;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Detail panel — full traceability
// ─────────────────────────────────────────────────────────────────────────────

class _DetailPanel extends ConsumerWidget {
  final String activityId;
  final VoidCallback onClose;

  const _DetailPanel({required this.activityId, required this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync =
        ref.watch(completedActivityDetailProvider(activityId));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border:
            Border(left: BorderSide(color: SaoColors.gray200, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PanelHeader(onClose: onClose),
          const Divider(height: 1),
          Expanded(
            child: detailAsync.when(
              loading: () => const _DetailSkeleton(),
              error: (e, _) => _PanelError(message: e.toString()),
              data: (detail) => _PanelContent(detail: detail),
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  final VoidCallback onClose;
  const _PanelHeader({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: SaoColors.gray50,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.manage_search_rounded,
              size: 16, color: SaoColors.actionPrimary),
          const SizedBox(width: 8),
          Text('Trazabilidad completa',
              style: SaoTypography.bodyTextBold
                  .copyWith(fontSize: 13, color: SaoColors.gray700)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 16),
            tooltip: 'Cerrar panel',
            onPressed: onClose,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }
}

class _PanelError extends StatelessWidget {
  final String message;
  const _PanelError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, size: 40, color: SaoColors.error),
          const SizedBox(height: 10),
          Text('Error al cargar detalle',
              style: SaoTypography.sectionTitle
                  .copyWith(color: SaoColors.error)),
          const SizedBox(height: 6),
          Text(message,
              textAlign: TextAlign.center,
              style: SaoTypography.caption
                  .copyWith(color: SaoColors.gray500)),
        ],
      ),
    );
  }
}

class _PanelContent extends StatelessWidget {
  final CompletedActivityDetail detail;
  const _PanelContent({required this.detail});

  String _fmtDate(String raw) {
    if (raw.isEmpty) return '—';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return DateFormat('dd/MM/yyyy HH:mm').format(dt.toLocal());
  }

  bool _hasValue(String raw) {
    final v = raw.trim();
    if (v.isEmpty || v == '—') return false;
    return !v.toLowerCase().startsWith('sin ');
  }

  @override
  Widget build(BuildContext context) {
    final s = detail.summary;
    final generalRows = <_InfoRow>[
      _InfoRow('Proyecto', s.projectId),
      _InfoRow('Tipo', s.activityType),
      _InfoRow('PK', s.pk),
      _InfoRow('Sync v.', '${detail.syncVersion}'),
    ].where((r) => _hasValue(r.value)).toList(growable: false);

    final locationRows = <_InfoRow>[
      _InfoRow('Frente', s.front),
      _InfoRow('Estado', s.estado),
      _InfoRow('Municipio', s.municipio),
      _InfoRow('Colonia', detail.colonia),
    ].where((r) => _hasValue(r.value)).toList(growable: false);

    final actorsRows = <_InfoRow>[
      _InfoRow('Responsable', s.assignedName),
      _InfoRow('Revisó', s.reviewedByName),
    ].where((r) => _hasValue(r.value)).toList(growable: false);

    final timingRows = <_InfoRow>[
      _InfoRow('Creado', _fmtDate(s.createdAt)),
      _InfoRow('Revisado', _fmtDate(s.reviewedAt)),
    ].where((r) => _hasValue(r.value)).toList(growable: false);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // Activity header
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.title.isNotEmpty ? s.title : s.activityType,
                    style: SaoTypography.sectionTitle.copyWith(fontSize: 14),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${s.pk}  ·  ${s.projectId}',
                    style: SaoTypography.caption
                        .copyWith(color: SaoColors.gray400, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _DecisionBadge(decision: s.reviewDecision, large: true),
          ],
        ),

        const SizedBox(height: 14),
        _PanelQuickActions(detail: detail),
        const SizedBox(height: 10),
        const Divider(height: 1),
        const SizedBox(height: 12),

        _SectionTitle(icon: Icons.info_outline_rounded, label: 'Datos generales'),
        const SizedBox(height: 8),
        if (generalRows.isNotEmpty) ...[
          _SubsectionLabel(label: 'General'),
          const SizedBox(height: 6),
          _InfoGrid(rows: generalRows),
        ],
        if (locationRows.isNotEmpty) ...[
          const SizedBox(height: 10),
          _SubsectionLabel(label: 'Ubicación'),
          const SizedBox(height: 6),
          _InfoGrid(rows: locationRows),
        ],
        if (actorsRows.isNotEmpty) ...[
          const SizedBox(height: 10),
          _SubsectionLabel(label: 'Responsables'),
          const SizedBox(height: 6),
          _InfoGrid(rows: actorsRows),
        ],
        if (timingRows.isNotEmpty) ...[
          const SizedBox(height: 10),
          _SubsectionLabel(label: 'Tiempos'),
          const SizedBox(height: 6),
          _InfoGrid(rows: timingRows),
        ],

        if (detail.reviewNotes.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),
          _SectionTitle(
              icon: Icons.comment_outlined, label: 'Notas de revisión'),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: SaoColors.gray50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: SaoColors.gray200),
            ),
            child: Text(detail.reviewNotes,
                style: SaoTypography.bodyText.copyWith(fontSize: 12)),
          ),
        ],

        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 10),
        _SectionTitle(
          icon: Icons.photo_library_outlined,
          label: 'Evidencias (${detail.evidences.length})',
        ),
        const SizedBox(height: 6),
        if (detail.evidences.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text('Sin evidencias registradas',
                style: SaoTypography.caption
                    .copyWith(color: SaoColors.gray400)),
          )
        else
          ...detail.evidences
              .map((e) => _EvidenceRow(ev: e, fmtDate: _fmtDate)),

        if (detail.dataFields.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),
          _SectionTitle(
              icon: Icons.list_alt_rounded, label: 'Campos registrados'),
          const SizedBox(height: 6),
          _DataFieldsTable(fields: detail.dataFields),
        ],

        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 10),
        _SectionTitle(
          icon: Icons.timeline_rounded,
          label: 'Trazabilidad (${detail.auditTrail.length})',
        ),
        const SizedBox(height: 8),
        if (detail.auditTrail.isEmpty)
          _TimelinePlaceholder(status: s.reviewDecision)
        else
          _AuditTimeline(
              entries: detail.auditTrail, fmtDate: _fmtDate),

        const SizedBox(height: 24),
      ],
    );
  }
}

class _SubsectionLabel extends StatelessWidget {
  final String label;
  const _SubsectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: SaoTypography.caption.copyWith(
        fontSize: 11,
        color: SaoColors.gray500,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _PanelQuickActions extends StatelessWidget {
  final CompletedActivityDetail detail;
  const _PanelQuickActions({required this.detail});

  String _sanitizeSegment(String value) {
    final cleaned = value.trim().replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_');
    final compact = cleaned.replaceAll(RegExp(r'\s+'), '_');
    return compact.isEmpty ? 'evidencia' : compact;
  }

  String _safeLabel(String value, String fallback) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }

  String _resolvedFrontForExport() {
    final candidates = [
      detail.summary.front,
      detail.dataFields['front'],
      detail.dataFields['front_name'],
      detail.dataFields['frente'],
      detail.dataFields['frente_name'],
      detail.dataFields['frenteNombre'],
    ];

    for (final candidate in candidates) {
      final value = (candidate?.toString() ?? '').trim();
      if (value.isNotEmpty && value.toLowerCase() != 'null') {
        return value;
      }
    }
    return 'SIN_FRENTE';
  }

  Directory _buildActivityDirectory(CompletedActivity summary) {
    final userProfile = Platform.environment['USERPROFILE'];
    final documentsRoot = userProfile == null || userProfile.isEmpty
        ? Directory.current.path
        : p.join(userProfile, 'Documents');

    final projectDir = _sanitizeSegment(_safeLabel(summary.projectId, 'SIN_PROYECTO'));
    final frontDir = _sanitizeSegment(_resolvedFrontForExport());
    final stateDir = _sanitizeSegment(_safeLabel(summary.estado, 'SIN_ESTADO'));
    final activityName = _sanitizeSegment(_safeLabel(summary.title, 'ACTIVIDAD'));
    final pkPart = summary.pk.trim().isNotEmpty ? '__${_sanitizeSegment(summary.pk)}' : '';

    return Directory(
      p.join(documentsRoot, 'SAO', projectDir, frontDir, stateDir, '$activityName$pkPart'),
    );
  }

  String _guessExtension(EvidenceItem evidence, String signedUrl) {
    String extractExtension(String raw) {
      if (raw.trim().isEmpty) return '';
      final withoutQuery = raw.split('?').first;
      return p.extension(withoutQuery);
    }

    final fromPath = extractExtension(evidence.gcsPath);
    if (fromPath.isNotEmpty) return fromPath;

    final fromUrl = extractExtension(signedUrl);
    if (fromUrl.isNotEmpty) return fromUrl;

    switch (evidence.type.toUpperCase()) {
      case 'PDF':
      case 'DOCUMENT':
        return '.pdf';
      case 'VIDEO':
        return '.mp4';
      default:
        return '.jpg';
    }
  }

  String _buildFileName(
    CompletedActivity summary,
    EvidenceItem evidence,
    int index,
    String signedUrl,
  ) {
    final pkPart = _sanitizeSegment(summary.pk.isNotEmpty ? summary.pk : summary.id);
    final descPart = _sanitizeSegment(
      evidence.description.isNotEmpty ? evidence.description : 'evidencia_${index + 1}',
    );
    final ext = _guessExtension(evidence, signedUrl);
    return '${(index + 1).toString().padLeft(2, '0')}_${pkPart}_$descPart$ext';
  }

  Map<String, dynamic> _buildActivitySnapshot() {
    final s = detail.summary;
    return {
      'exported_at': DateTime.now().toIso8601String(),
      'summary': {
        'id': s.id,
        'project_id': s.projectId,
        'title': s.title,
        'activity_type': s.activityType,
        'pk': s.pk,
        'front': s.front,
        'estado': s.estado,
        'municipio': s.municipio,
        'created_at': s.createdAt,
        'reviewed_at': s.reviewedAt,
        'assigned_name': s.assignedName,
        'reviewed_by_name': s.reviewedByName,
        'review_decision': s.reviewDecision,
        'has_report': s.hasReport,
        'evidence_count': s.evidenceCount,
      },
      'detail': {
        'colonia': detail.colonia,
        'review_notes': detail.reviewNotes,
        'sync_version': detail.syncVersion,
        'data_fields': detail.dataFields,
        'audit_trail': detail.auditTrail
            .map((entry) => {
                  'id': entry.id,
                  'action': entry.action,
                  'actor_email': entry.actorEmail,
                  'actor_name': entry.actorName,
                  'changes': entry.changes,
                  'notes': entry.notes,
                  'timestamp': entry.timestamp,
                })
            .toList(growable: false),
        'evidences': detail.evidences
            .map((evidence) => {
                  'id': evidence.id,
                  'type': evidence.type,
                  'description': evidence.description,
                  'gcs_path': evidence.gcsPath,
                  'uploaded_at': evidence.uploadedAt,
                  'uploader_name': evidence.uploaderName,
                })
            .toList(growable: false),
      },
    };
  }

  Future<void> _writeActivityFiles(Directory activityDir) async {
    final dataDir = Directory(p.join(activityDir.path, 'datos'));
    final pdfDir = Directory(p.join(activityDir.path, 'pdfs'));
    await dataDir.create(recursive: true);
    await pdfDir.create(recursive: true);

    final snapshot = _buildActivitySnapshot();
    final encoder = const JsonEncoder.withIndent('  ');
    await File(p.join(dataDir.path, 'actividad_detalle.json'))
        .writeAsString(encoder.convert(snapshot), flush: true);

    final s = detail.summary;
    final resumen = StringBuffer()
      ..writeln('SAO - Resumen de actividad')
      ..writeln('Proyecto: ${s.projectId}')
      ..writeln('Frente: ${s.front}')
      ..writeln('Estado: ${s.estado}')
      ..writeln('Municipio: ${s.municipio}')
      ..writeln('Colonia: ${detail.colonia}')
      ..writeln('Actividad: ${s.title}')
      ..writeln('Tipo: ${s.activityType}')
      ..writeln('PK: ${s.pk}')
      ..writeln('Responsable: ${s.assignedName}')
      ..writeln('Revisó: ${s.reviewedByName}')
      ..writeln('Decisión: ${s.reviewDecision}')
      ..writeln('Creado: ${s.createdAt}')
      ..writeln('Revisado: ${s.reviewedAt}')
      ..writeln('Versión sync: ${detail.syncVersion}')
      ..writeln('Notas: ${detail.reviewNotes.isEmpty ? 'Sin notas' : detail.reviewNotes}');

    await File(p.join(dataDir.path, 'actividad_resumen.txt'))
        .writeAsString(resumen.toString(), flush: true);

    final pdf = pw.Document();
    final dataRows = detail.dataFields.entries
        .where((entry) => entry.value != null && entry.value.toString().trim().isNotEmpty)
        .map((entry) => [entry.key, entry.value.toString()])
        .toList(growable: false);

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text(
            'SAO - Resumen de actividad',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.Text('Proyecto: ${s.projectId}'),
          pw.Text('Frente: ${s.front}'),
          pw.Text('Estado: ${s.estado}'),
          pw.Text('Municipio: ${s.municipio}'),
          pw.Text('Colonia: ${detail.colonia}'),
          pw.Text('Actividad: ${s.title}'),
          pw.Text('Tipo: ${s.activityType}'),
          pw.Text('PK: ${s.pk}'),
          pw.Text('Responsable: ${s.assignedName}'),
          pw.Text('Revisó: ${s.reviewedByName}'),
          pw.Text('Decisión: ${s.reviewDecision}'),
          pw.Text('Creado: ${s.createdAt}'),
          pw.Text('Revisado: ${s.reviewedAt}'),
          pw.Text('Versión sync: ${detail.syncVersion}'),
          if (detail.reviewNotes.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            pw.Text(
              'Notas de revisión',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(detail.reviewNotes),
          ],
          if (dataRows.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Text(
              'Campos registrados',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Table.fromTextArray(
              headers: const ['Campo', 'Valor'],
              data: dataRows,
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellAlignment: pw.Alignment.centerLeft,
              headerDecoration: const pw.BoxDecoration(),
            ),
          ],
          if (detail.evidences.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Text(
              'Evidencias',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            ...detail.evidences.take(50).map(
                  (evidence) => pw.Bullet(
                    text:
                        '${evidence.type} • ${evidence.description.isEmpty ? 'Sin descripción' : evidence.description} • ${evidence.uploadedAt}',
                  ),
                ),
          ],
        ],
      ),
    );

    await File(p.join(pdfDir.path, 'resumen_actividad.pdf'))
        .writeAsBytes(await pdf.save(), flush: true);
  }

  Directory _targetDirectoryForEvidence(Directory activityDir, EvidenceItem evidence) {
    final upper = evidence.type.toUpperCase();
    final folderName = upper == 'PDF' || upper == 'DOCUMENT' ? 'pdfs' : 'evidencias';
    return Directory(p.join(activityDir.path, folderName));
  }

  Future<List<int>> _downloadBytes(String signedUrl) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20)
      ..idleTimeout = const Duration(seconds: 20);
    try {
      final request = await client.getUrl(Uri.parse(signedUrl));
      request.followRedirects = true;
      request.maxRedirects = 5;
      request.headers.set(HttpHeaders.userAgentHeader, 'SAO-Desktop/1.0');
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('HTTP ${response.statusCode} al descargar evidencia');
      }
      return response.fold<List<int>>(<int>[], (buffer, chunk) {
        buffer.addAll(chunk);
        return buffer;
      });
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _downloadFileWithFallback(String signedUrl, File targetFile) async {
    Object? lastError;

    try {
      final bytes = await _downloadBytes(signedUrl);
      if (bytes.isEmpty) {
        throw StateError('La evidencia regresó 0 bytes');
      }
      await targetFile.writeAsBytes(bytes, flush: true);
      if (await targetFile.exists() && await targetFile.length() > 0) {
        return;
      }
      throw StateError('El archivo descargado quedó vacío');
    } catch (error) {
      lastError = error;
    }

    if (Platform.isWindows) {
      final curlResult = await Process.run(
        'curl.exe',
        ['-L', '--fail', '--silent', '--show-error', '-o', targetFile.path, signedUrl],
      );
      if (curlResult.exitCode == 0 && await targetFile.exists() && await targetFile.length() > 0) {
        return;
      }
      final stderr = (curlResult.stderr ?? '').toString().trim();
      if (stderr.isNotEmpty) {
        lastError = stderr;
      }
    }

    throw Exception('No se pudo descargar ${targetFile.path}: $lastError');
  }

  Future<void> _downloadEvidences(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final summary = detail.summary;
    final activityDir = _buildActivityDirectory(summary);

    try {
      if (!await activityDir.exists()) {
        await activityDir.create(recursive: true);
      }

      final evidencesDir = Directory(p.join(activityDir.path, 'evidencias'));
      final pdfDir = Directory(p.join(activityDir.path, 'pdfs'));
      if (!await evidencesDir.exists()) {
        await evidencesDir.create(recursive: true);
      }
      if (!await pdfDir.exists()) {
        await pdfDir.create(recursive: true);
      }

      await _writeActivityFiles(activityDir);

      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Actualizando paquete SAO en ${activityDir.path}...'),
            duration: const Duration(seconds: 2),
          ),
        );

      final repository = EvidenceRepository();
      int savedCount = 0;
      int skippedCount = 0;
      final failedDescriptions = <String>[];

      for (var i = 0; i < detail.evidences.length; i++) {
        final evidence = detail.evidences[i];
        try {
          final signedUrl = await repository.getDownloadSignedUrl(evidence.id);
          final fileName = _buildFileName(summary, evidence, i, signedUrl);
          final targetDir = _targetDirectoryForEvidence(activityDir, evidence);
          if (!await targetDir.exists()) {
            await targetDir.create(recursive: true);
          }
          final file = File(p.join(targetDir.path, fileName));

          if (await file.exists() && await file.length() > 0) {
            skippedCount++;
            continue;
          }

          await _downloadFileWithFallback(signedUrl, file);
          savedCount++;
        } catch (error) {
          failedDescriptions.add(
            '${evidence.description.isNotEmpty ? evidence.description : 'Evidencia ${i + 1}'} -> $error',
          );
        }
      }

      final dataDir = Directory(p.join(activityDir.path, 'datos'));
      if (!await dataDir.exists()) {
        await dataDir.create(recursive: true);
      }
      final failedFile = File(p.join(dataDir.path, 'evidencias_no_descargadas.txt'));
      if (failedDescriptions.isNotEmpty) {
        await failedFile.writeAsString(
          failedDescriptions.join('\n'),
          flush: true,
        );
      } else if (await failedFile.exists()) {
        await failedFile.delete();
      }

      if (!context.mounted) return;

      final message = detail.evidences.isEmpty
          ? 'Carpeta SAO actualizada en ${activityDir.path}'
          : failedDescriptions.isEmpty
              ? 'Actividad actualizada: $savedCount nuevas, $skippedCount ya existentes.'
              : 'Actividad actualizada: $savedCount nuevas, $skippedCount existentes, ${failedDescriptions.length} con error.';

      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 10),
            action: SnackBarAction(
              label: 'Abrir carpeta',
              onPressed: () {
                Process.run('explorer.exe', [activityDir.path]);
              },
            ),
          ),
        );
    } catch (e) {
      if (!context.mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('No se pudo actualizar la carpeta SAO: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = detail.summary;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Edición rápida disponible próximamente.')),
            );
          },
          icon: const Icon(Icons.edit_outlined, size: 15),
          label: const Text('Editar'),
        ),
        OutlinedButton.icon(
          onPressed: s.hasReport
              ? () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Exportación PDF en integración.')),
                  );
                }
              : null,
          icon: const Icon(Icons.picture_as_pdf_outlined, size: 15),
          label: const Text('Exportar PDF'),
        ),
        OutlinedButton.icon(
          onPressed: () async {
            final query = [s.pk, s.estado, s.municipio]
                .where((v) => v.trim().isNotEmpty)
                .join(' ');
            final uri = Uri.https('www.google.com', '/maps/search/', {
              'api': '1',
              'query': query,
            });
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          },
          icon: const Icon(Icons.map_outlined, size: 15),
          label: const Text('Ver en mapa'),
        ),
        if (s.reviewDecision == 'APPROVE' && detail.evidences.isNotEmpty)
          FilledButton.tonalIcon(
            onPressed: () => _downloadEvidences(context),
            icon: const Icon(Icons.download_rounded, size: 15),
            label: const Text('Descargar evidencias'),
          ),
      ],
    );
  }
}

class _TimelinePlaceholder extends StatelessWidget {
  final String status;
  const _TimelinePlaceholder({required this.status});

  @override
  Widget build(BuildContext context) {
    final steps = [
      ('Creado', true),
      ('Revisado', status.isNotEmpty),
      ('Aprobado', status == 'APPROVE' || status == 'APPROVE_EXCEPTION'),
    ];
    return Column(
      children: List.generate(steps.length, (i) {
        final (label, done) = steps[i];
        final isLast = i == steps.length - 1;
        final color = done ? SaoColors.success : SaoColors.gray300;
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 20,
                child: Column(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: done ? color.withValues(alpha: 0.15) : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: color, width: 1.5),
                      ),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(width: 1.5, color: SaoColors.gray200),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
                child: Text(
                  label,
                  style: SaoTypography.bodyText.copyWith(
                    fontSize: 12,
                    color: done ? SaoColors.gray700 : SaoColors.gray400,
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: List.generate(
          10,
          (index) => Container(
            height: index == 0 ? 44 : 30,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: SaoColors.gray100,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Detail sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _InfoRow {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);
}

class _InfoGrid extends StatelessWidget {
  final List<_InfoRow> rows;
  const _InfoGrid({required this.rows});

  @override
  Widget build(BuildContext context) {
    final pairs = <Widget>[];
    for (var i = 0; i < rows.length; i += 2) {
      final a = rows[i];
      final b = i + 1 < rows.length ? rows[i + 1] : null;
      pairs.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _InfoCell(label: a.label, value: a.value)),
          if (b != null) ...[
            const SizedBox(width: 8),
            Expanded(child: _InfoCell(label: b.label, value: b.value)),
          ],
        ],
      ));
    }
    return Column(
      children: pairs
          .expand((w) => [w, const SizedBox(height: 4)])
          .toList(growable: false),
    );
  }
}

class _InfoCell extends StatelessWidget {
  final String label;
  final String value;
  const _InfoCell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: SaoColors.gray50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: SaoColors.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: SaoTypography.caption
                  .copyWith(color: SaoColors.gray400, fontSize: 10)),
          const SizedBox(height: 2),
          Text(
            value.isNotEmpty ? value : '—',
            style: SaoTypography.bodyText.copyWith(fontSize: 12),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionTitle({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: SaoColors.gray500),
        const SizedBox(width: 6),
        Text(label,
            style: SaoTypography.bodyTextBold
                .copyWith(fontSize: 12, color: SaoColors.gray600)),
      ],
    );
  }
}

class _EvidenceRow extends StatelessWidget {
  final EvidenceItem ev;
  final String Function(String) fmtDate;
  const _EvidenceRow({required this.ev, required this.fmtDate});

  @override
  Widget build(BuildContext context) {
    final isPhoto = ev.type.toUpperCase().contains('PHOTO') ||
        ev.type.toUpperCase().contains('FOTO');
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: SaoColors.gray50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: SaoColors.gray200),
      ),
      child: Row(
        children: [
          Icon(
            isPhoto
                ? Icons.camera_alt_outlined
                : Icons.attach_file_rounded,
            size: 14,
            color: SaoColors.actionPrimary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ev.description.isNotEmpty ? ev.description : ev.type,
                  style: SaoTypography.bodyText.copyWith(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${ev.uploaderName.isNotEmpty ? ev.uploaderName : "—"}  ·  ${fmtDate(ev.uploadedAt)}',
                  style: SaoTypography.caption
                      .copyWith(color: SaoColors.gray400, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DataFieldsTable extends StatelessWidget {
  final Map<String, dynamic> fields;
  const _DataFieldsTable({required this.fields});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: fields.entries.map((e) {
        return Container(
          margin: const EdgeInsets.only(bottom: 3),
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: SaoColors.gray50,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: SaoColors.gray200),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 120,
                child: Text(e.key,
                    style: SaoTypography.caption
                        .copyWith(color: SaoColors.gray500, fontSize: 11),
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  e.value?.toString() ?? '—',
                  style: SaoTypography.bodyText.copyWith(fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Audit timeline
// ─────────────────────────────────────────────────────────────────────────────

class _AuditTimeline extends StatelessWidget {
  final List<AuditEntry> entries;
  final String Function(String) fmtDate;
  const _AuditTimeline({required this.entries, required this.fmtDate});

  static const _actionColors = <String, Color>{
    'CREATE':  Color(0xFF3B82F6),
    'CREATED': Color(0xFF3B82F6),
    'UPDATE':  Color(0xFFF59E0B),
    'UPDATED': Color(0xFFF59E0B),
    'DELETE':  Color(0xFFEF4444),
    'DELETED': Color(0xFFEF4444),
    'APPROVE': Color(0xFF10B981),
    'REVIEW':  Color(0xFF10B981),
    'REJECT':  Color(0xFFEF4444),
    'SYNC':    Color(0xFF8B5CF6),
  };

  Color _colorFor(String action) {
    final key = action.toUpperCase().split('_').first;
    return _actionColors[key] ??
        _actionColors[action.toUpperCase()] ??
        SaoColors.gray400;
  }

  IconData _iconFor(String action) {
    final up = action.toUpperCase();
    if (up.contains('APPROVE') || up.contains('DECISION')) {
      return Icons.check_circle_outline_rounded;
    }
    if (up.contains('REJECT'))  return Icons.cancel_outlined;
    if (up.contains('CREATE'))  return Icons.add_circle_outline_rounded;
    if (up.contains('UPDATE') || up.contains('EDIT')) {
      return Icons.edit_outlined;
    }
    if (up.contains('DELETE'))  return Icons.delete_outline_rounded;
    if (up.contains('SYNC'))    return Icons.sync_rounded;
    if (up.contains('EVIDENCE') || up.contains('PHOTO')) {
      return Icons.camera_alt_outlined;
    }
    return Icons.circle_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(entries.length, (i) {
        final e = entries[i];
        final color = _colorFor(e.action);
        final isLast = i == entries.length - 1;
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 24,
                child: Column(
                  children: [
                    const SizedBox(height: 2),
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: color, width: 1.5),
                      ),
                      child: Icon(_iconFor(e.action), size: 10, color: color),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Center(
                          child: Container(
                              width: 1.5, color: SaoColors.gray200),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(
                            _friendlyAction(e.action),
                            style: SaoTypography.bodyTextBold
                                .copyWith(fontSize: 12, color: color),
                          ),
                        ),
                        Text(fmtDate(e.timestamp),
                            style: SaoTypography.caption.copyWith(
                                color: SaoColors.gray400, fontSize: 10)),
                      ]),
                      if (e.actorName.isNotEmpty || e.actorEmail.isNotEmpty)
                        Text(
                          e.actorName.isNotEmpty
                              ? e.actorName
                              : e.actorEmail,
                          style: SaoTypography.caption.copyWith(
                              color: SaoColors.gray500, fontSize: 11),
                        ),
                      if (e.notes.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: SaoColors.gray50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: SaoColors.gray200),
                          ),
                          child: Text(e.notes,
                              style: SaoTypography.caption
                                  .copyWith(fontSize: 11)),
                        ),
                      ],
                      if (e.changes.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        _ChangesChips(changes: e.changes),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  String _friendlyAction(String action) {
    return action
        .replaceAll('_', ' ')
        .toLowerCase()
        .split(' ')
        .map((w) =>
            w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}

class _ChangesChips extends StatefulWidget {
  final Map<String, dynamic> changes;
  const _ChangesChips({required this.changes});

  @override
  State<_ChangesChips> createState() => _ChangesChipsState();
}

class _ChangesChipsState extends State<_ChangesChips> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 13,
                color: SaoColors.gray400,
              ),
              Text(
                '${widget.changes.length} campo(s) modificado(s)',
                style: SaoTypography.caption
                    .copyWith(color: SaoColors.gray500, fontSize: 10),
              ),
            ],
          ),
        ),
        if (_expanded)
          ...widget.changes.entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 2, left: 16),
                child: Text(
                  '${e.key}: ${e.value}',
                  style: SaoTypography.caption
                      .copyWith(fontSize: 10, color: SaoColors.gray500),
                  overflow: TextOverflow.ellipsis,
                ),
              )),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Decision badge
// ─────────────────────────────────────────────────────────────────────────────

class _DecisionBadge extends StatelessWidget {
  final String decision;
  final bool large;
  const _DecisionBadge({required this.decision, this.large = false});

  @override
  Widget build(BuildContext context) {
    Color bg, fg;
    String label;
    IconData icon;

    final upper = decision.toUpperCase();
    if (upper == 'APPROVE_EXCEPTION') {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFFD97706);
      label = large ? 'Aprobado con observaciones' : 'Aprobado*';
      icon = Icons.warning_amber_rounded;
    } else if (upper.contains('REJECT')) {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFDC2626);
      label = 'Rechazado';
      icon = Icons.cancel_rounded;
    } else if (upper.contains('PENDING') || upper.contains('REVIEW')) {
      bg = const Color(0xFFFFF7ED);
      fg = const Color(0xFFEA580C);
      label = 'Revisión pendiente';
      icon = Icons.schedule_rounded;
    } else {
      bg = SaoColors.success.withValues(alpha: 0.12);
      fg = SaoColors.success;
      label = 'Aprobado';
      icon = Icons.check_circle_rounded;
    }

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: large ? 10 : 7, vertical: large ? 4 : 2),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(large ? 6 : 4)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: large ? 13 : 11, color: fg),
          SizedBox(width: large ? 5 : 3),
          Text(label,
              style: SaoTypography.caption
                  .copyWith(color: fg, fontSize: large ? 12 : 10)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty / Error full-page states
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline_rounded,
              size: 56, color: SaoColors.gray200),
          const SizedBox(height: 16),
          Text('Sin actividades completadas',
              style: SaoTypography.sectionTitle
                  .copyWith(color: SaoColors.gray400)),
          const SizedBox(height: 8),
          Text(
            'Ajusta los filtros o verifica que existan actividades aprobadas.',
            style: SaoTypography.caption.copyWith(color: SaoColors.gray400),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, size: 48, color: SaoColors.error),
          const SizedBox(height: 12),
          Text('Error al cargar actividades',
              style: SaoTypography.sectionTitle
                  .copyWith(color: SaoColors.error)),
          const SizedBox(height: 8),
          SizedBox(
            width: 400,
            child: Text(message,
                textAlign: TextAlign.center,
                style: SaoTypography.caption
                    .copyWith(color: SaoColors.gray500)),
          ),
        ],
      ),
    );
  }
}
