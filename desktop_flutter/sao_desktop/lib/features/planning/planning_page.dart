import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../../core/providers/project_providers.dart';
import '../../data/repositories/backend_api_client.dart';
import '../../data/repositories/assignments_repository.dart';
import '../../ui/theme/sao_colors.dart';
import 'planning_provider.dart';

class _ToggleCalendarIntent extends Intent {
  const _ToggleCalendarIntent();
}

class PlanningPage extends ConsumerStatefulWidget {
  const PlanningPage({super.key});

  @override
  ConsumerState<PlanningPage> createState() => _PlanningPageState();
}

class _PlanningPageState extends ConsumerState<PlanningPage> {
  static const List<String> _fallbackProjects = ['TMQ', 'TAP'];
  bool _calendarCollapsed = false;

  void _refreshPlanning() {
    ref.invalidate(planningAssignmentsProvider);
    ref.invalidate(planningMonthlyAssignmentsProvider);
  }

  Future<void> _pickDate(DateTime selectedDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      ref.read(selectedPlanningDateProvider.notifier).state = picked;
    }
  }

  Future<void> _openCreateAssignmentDialog({
    required String selectedProject,
    required DateTime selectedDate,
    required List<AssignmentItem> existingAssignments,
  }) async {
    if (selectedProject.isEmpty) return;
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _CreateAssignmentDialog(
        projectId: selectedProject,
        selectedDate: selectedDate,
        existingAssignments: existingAssignments,
      ),
    );
    if (created == true && mounted) {
      _refreshPlanning();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Asignación creada')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final assignmentsAsync = ref.watch(planningAssignmentsProvider);
    final monthlyAssignmentsAsync = ref.watch(planningMonthlyAssignmentsProvider);
    final selectedDate = ref.watch(selectedPlanningDateProvider);
    final selectedProject = ref.watch(activeProjectIdProvider);
    final projectsAsync = ref.watch(availableProjectsProvider);
    final dateLabel = DateFormat('EEEE, d MMM yyyy', 'es').format(selectedDate);

    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.keyC): _ToggleCalendarIntent(),
      },
      child: Actions(
        actions: {
          _ToggleCalendarIntent: CallbackAction<_ToggleCalendarIntent>(
            onInvoke: (intent) {
              setState(() {
                _calendarCollapsed = !_calendarCollapsed;
              });
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: SaoColors.surfaceFor(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: SaoColors.borderFor(context)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Planeación del Día',
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        dateLabel,
                        style: TextStyle(
                          fontSize: 12,
                          color: SaoColors.textMutedFor(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 168,
                  child: projectsAsync.when(
                    loading: () => const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    error: (_, __) => _ProjectDropdown(
                      projects: _fallbackProjects,
                      selectedProject: selectedProject,
                      onSelected: (project) {
                        ref.read(activeProjectIdProvider.notifier).select(project);
                      },
                    ),
                    data: (projects) {
                      final options = projects.isEmpty ? _fallbackProjects : projects;
                      if (selectedProject.isEmpty && options.isNotEmpty) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          ref.read(activeProjectIdProvider.notifier).select(options.first);
                        });
                      }
                      return _ProjectDropdown(
                        projects: options,
                        selectedProject: selectedProject,
                        onSelected: (project) {
                          ref.read(activeProjectIdProvider.notifier).select(project);
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _pickDate(selectedDate),
                  icon: const Icon(Icons.calendar_today_rounded, size: 15),
                  label: const Text('Fecha'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: SaoColors.info,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: selectedProject.isEmpty
                      ? null
                      : () => _openCreateAssignmentDialog(
                          selectedProject: selectedProject,
                          selectedDate: selectedDate,
                          existingAssignments:
                              assignmentsAsync.valueOrNull ?? const <AssignmentItem>[],
                        ),
                  icon: const Icon(Icons.add_task_rounded, size: 15),
                  label: const Text('Asignar actividad'),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Refrescar',
                  onPressed: _refreshPlanning,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 1080;
                final showCalendar = isNarrow || !_calendarCollapsed;

                final calendarPanel = showCalendar
                    ? Card(
                        child: monthlyAssignmentsAsync.when(
                          loading: () => const SizedBox(
                            height: 320,
                            child: Center(child: CircularProgressIndicator()),
                          ),
                          error: (e, _) => Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text('Error calendario: $e'),
                          ),
                          data: (items) => _PlanningMonthCalendar(
                            selectedDate: selectedDate,
                            items: items,
                            onSelectedDate: (value) {
                              ref.read(selectedPlanningDateProvider.notifier).state = value;
                            },
                          ),
                        ),
                      )
                    : Card(
                        child: _CollapsedCalendarRail(
                          selectedDate: selectedDate,
                          onExpand: () {
                            setState(() {
                              _calendarCollapsed = false;
                            });
                          },
                        ),
                      );

                final assignmentsPanel = assignmentsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 8),
                        Text('Error: $e'),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () => ref.invalidate(planningAssignmentsProvider),
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                  data: (assignments) {
                    final uniqueAssignments = _dedupeAssignments(assignments);

                    if (uniqueAssignments.isEmpty) {
                      return Center(
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 520),
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: SaoColors.surfaceFor(context),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: SaoColors.borderFor(context)),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.event_busy_rounded,
                                size: 64,
                                color: SaoColors.textMutedFor(context),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Sin actividades para $dateLabel',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: SaoColors.textFor(context),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Crea la primera actividad para comenzar la planeación del dia.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: SaoColors.textMutedFor(context)),
                              ),
                              const SizedBox(height: 14),
                              FilledButton.icon(
                                onPressed: selectedProject.isEmpty
                                    ? null
                                    : () => _openCreateAssignmentDialog(
                                        selectedProject: selectedProject,
                                        selectedDate: selectedDate,
                                        existingAssignments: uniqueAssignments,
                                      ),
                                icon: const Icon(Icons.add_task_rounded, size: 16),
                                label: const Text('Crear primera actividad'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return SizedBox(
                      height: constraints.maxHeight,
                      child: Card(
                        child: _HourlyAssignmentsView(
                          projectId: selectedProject,
                          assignments: uniqueAssignments,
                          selectedDate: selectedDate,
                          onEdited: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Edicion disponible en la siguiente iteracion.'),
                              ),
                            );
                          },
                          onDuplicated: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Duplicado rapido disponible en la siguiente iteracion.'),
                              ),
                            );
                          },
                          onDeleted: (_) => _refreshPlanning(),
                          totalAssignments: uniqueAssignments.length,
                        ),
                      ),
                    );
                  },
                );

                if (isNarrow) {
                  return Column(
                    children: [
                      SizedBox(height: 300, child: calendarPanel),
                      const SizedBox(height: 10),
                      Expanded(child: assignmentsPanel),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: _calendarCollapsed ? 74 : 380,
                      child: Column(
                        children: [
                          if (!_calendarCollapsed)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _calendarCollapsed = true;
                                  });
                                },
                                icon: const Icon(Icons.keyboard_double_arrow_left_rounded, size: 16),
                                label: const Text('Contraer calendario'),
                              ),
                            ),
                          Expanded(child: calendarPanel),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: assignmentsPanel),
                  ],
                );
              },
            ),
          ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<AssignmentItem> _dedupeAssignments(List<AssignmentItem> items) {
    final byId = <String, AssignmentItem>{};
    for (final item in items) {
      final key = item.id.trim();
      if (key.isEmpty) continue;
      byId[key] = item;
    }
    return byId.values.toList();
  }
}

class _CreateAssignmentDialog extends ConsumerStatefulWidget {
  final String projectId;
  final DateTime selectedDate;
  final List<AssignmentItem> existingAssignments;

  const _CreateAssignmentDialog({
    required this.projectId,
    required this.selectedDate,
    required this.existingAssignments,
  });

  @override
  ConsumerState<_CreateAssignmentDialog> createState() =>
      _CreateAssignmentDialogState();
}

class _ProjectDropdown extends StatelessWidget {
  final List<String> projects;
  final String selectedProject;
  final ValueChanged<String> onSelected;

  const _ProjectDropdown({
    required this.projects,
    required this.selectedProject,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final currentValue = projects.contains(selectedProject) ? selectedProject : null;
    return DropdownButtonFormField<String>(
      initialValue: currentValue,
      decoration: const InputDecoration(
        labelText: 'Proyecto',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: projects
          .map((id) => DropdownMenuItem(value: id, child: Text(id)))
          .toList(),
      onChanged: (value) {
        if (value != null && value.isNotEmpty) {
          onSelected(value);
        }
      },
    );
  }
}

class _CreateAssignmentDialogState extends ConsumerState<_CreateAssignmentDialog> {
  static const String _tipoPuntual = 'puntual';
  static const String _tipoTramo = 'tramo';
  static const String _tipoLugar = 'lugar';

  final _titleController = TextEditingController();
  final _pkController = TextEditingController(text: '0+000');
  final _pkFocusNode = FocusNode();
  final _pkFinController = TextEditingController();
  final _pkFinFocusNode = FocusNode();
  final _lugarController = TextEditingController();
  final _startController = TextEditingController(text: '08:00');
  final _endController = TextEditingController(text: '09:00');

  final _coloniaController = TextEditingController();
  Timer? _geocodeDebounce;
  bool _geocoding = false;
  bool _isAutoPinned = false;
  bool _mapExpanded = false;

  double? _lat;
  double? _lon;
  final _mapController = MapController();

  List<AssignmentAssigneeOption> _assignees = const [];
  List<AssignmentFrontOption> _fronts = const [];
  List<AssignmentActivityTypeOption> _activityTypes = const [];
  Map<String, List<AssignmentFrontCoverageOption>> _frontCoverageByKey = const {};

  String? _assigneeId;
  String? _frontId;
  String? _activityTypeCode;
  String? _selectedEstado;
  String? _selectedMunicipio;
  List<String> _estadoOptions = const [];
  List<String> _municipioOptions = const [];
  String _tipoUbicacion = _tipoPuntual;
  int _currentStep = 0;
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  DateTime? _lastPkNormalizeAt;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _pkController.dispose();
    _pkFocusNode.dispose();
    _pkFinController.dispose();
    _pkFinFocusNode.dispose();
    _lugarController.dispose();
    _startController.dispose();
    _endController.dispose();
    _coloniaController.dispose();
    _geocodeDebounce?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _handlePkEnter(TextEditingController controller) async {
    if (_loading || _submitting) return;
    final normalized = _normalizePkInput(controller.text);
    if (normalized != controller.text) {
      controller.value = controller.value.copyWith(
        text: normalized,
        selection: TextSelection.collapsed(offset: normalized.length),
        composing: TextRange.empty,
      );
      _lastPkNormalizeAt = DateTime.now();
      return;
    }

    final normalizedAt = _lastPkNormalizeAt;
    if (normalizedAt != null &&
        DateTime.now().difference(normalizedAt).inMilliseconds < 180) {
      return;
    }

    await _handleEnterAdvance();
  }

  Future<void> _loadOptions() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(assignmentsRepositoryProvider);
      final results = await Future.wait([
        repo.getAssignees(widget.projectId),
        repo.getFronts(widget.projectId),
        repo.getActivityTypes(widget.projectId),
        repo.getFrontCoverageByFront(widget.projectId),
      ]);
      if (!mounted) return;
      _assignees = results[0] as List<AssignmentAssigneeOption>;
      _fronts = results[1] as List<AssignmentFrontOption>;
      _activityTypes = results[2] as List<AssignmentActivityTypeOption>;
        _frontCoverageByKey =
          results[3] as Map<String, List<AssignmentFrontCoverageOption>>;
      _assigneeId = null;
      _frontId = null;
      _activityTypeCode = null;
      _selectedEstado = null;
      _selectedMunicipio = null;
      _estadoOptions = const [];
      _municipioOptions = const [];
      _loading = false;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  DateTime? _composeDateTime(String value) {
    final parts = value.trim().split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
      hour,
      minute,
    );
  }

  int? _parsePkMeters(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;

    final compact = value.replaceAll(' ', '');
    final chainage = RegExp(r'^(\d+)\+(\d{1,3})$').firstMatch(compact);
    if (chainage != null) {
      final km = int.parse(chainage.group(1)!);
      final meters = int.parse(chainage.group(2)!.padRight(3, '0'));
      return (km * 1000) + meters;
    }

    if (RegExp(r'^\d+$').hasMatch(compact)) {
      return int.parse(compact);
    }

    return null;
  }

  String _normalizePkInput(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';
    final compact = value.replaceAll(' ', '');

    final chainage = RegExp(r'^(\d+)\+(\d{1,3})$').firstMatch(compact);
    if (chainage != null) {
      return '${chainage.group(1)}+${chainage.group(2)!.padRight(3, '0')}';
    }

    final chainageNoMeters = RegExp(r'^(\d+)\+$').firstMatch(compact);
    if (chainageNoMeters != null) {
      return '${chainageNoMeters.group(1)}+000';
    }

    if (RegExp(r'^\d+$').hasMatch(compact)) {
      if (compact.length <= 3) {
        return '$compact+000';
      }
      final km = compact.substring(0, 3);
      final meters = compact.length > 3
          ? compact.substring(3, compact.length > 6 ? 6 : compact.length)
          : '';
      return '$km+${meters.padRight(3, '0')}';
    }

    return compact;
  }

  String _formatTimeValue(DateTime value) {
    final hh = value.hour.toString().padLeft(2, '0');
    final mm = value.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  Future<void> _pickTime(bool isStart) async {
    final source = isStart ? _startController.text : _endController.text;
    final initialDate = _composeDateTime(source) ??
        DateTime(widget.selectedDate.year, widget.selectedDate.month, widget.selectedDate.day, isStart ? 8 : 9);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initialDate.hour, minute: initialDate.minute),
    );
    if (picked == null || !mounted) return;
    setState(() {
      final value = _formatTimeValue(
        DateTime(
          widget.selectedDate.year,
          widget.selectedDate.month,
          widget.selectedDate.day,
          picked.hour,
          picked.minute,
        ),
      );
      if (isStart) {
        _startController.text = value;
      } else {
        _endController.text = value;
      }
    });
  }

  void _setDuration(int minutes) {
    final start = _composeDateTime(_startController.text);
    if (start == null) return;
    final end = start.add(Duration(minutes: minutes));
    setState(() {
      _endController.text = _formatTimeValue(end);
    });
  }

  DateTime? _parseAssignmentStart(AssignmentItem item) {
    if ((item.startAt ?? '').isNotEmpty) {
      return DateTime.tryParse(item.startAt!)?.toLocal();
    }
    if (item.scheduledTime.contains('T')) {
      return DateTime.tryParse(item.scheduledTime)?.toLocal();
    }
    final datePart = DateTime.tryParse(item.scheduledDate);
    final timePart = item.scheduledTime.trim();
    if (datePart != null && timePart.contains(':')) {
      final parts = timePart.split(':');
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts.length > 1 ? parts[1] : '0');
      if (hour != null && minute != null) {
        return DateTime(datePart.year, datePart.month, datePart.day, hour, minute);
      }
    }
    return null;
  }

  DateTime? _parseAssignmentEnd(AssignmentItem item, DateTime start) {
    if ((item.endAt ?? '').isNotEmpty) {
      return DateTime.tryParse(item.endAt!)?.toLocal();
    }
    return start.add(const Duration(hours: 1));
  }

  String? _checkConflict() {
    final assigneeId = _assigneeId;
    final startAt = _composeDateTime(_startController.text);
    final endAt = _composeDateTime(_endController.text);
    if (assigneeId == null || startAt == null || endAt == null) {
      return null;
    }

    for (final item in widget.existingAssignments) {
      if (item.assigneeUserId != assigneeId) {
        continue;
      }
      final start = _parseAssignmentStart(item);
      if (start == null) continue;
      final end = _parseAssignmentEnd(item, start);
      if (end == null) continue;
      final overlaps = startAt.isBefore(end) && endAt.isAfter(start);
      if (!overlaps) continue;
      final endLabel = _formatTimeValue(end);
      return 'Conflicto detectado: este responsable ya tiene una asignacion hasta $endLabel.';
    }
    return null;
  }

  void _findNextFreeSlot() {
    final startAt = _composeDateTime(_startController.text);
    final endAt = _composeDateTime(_endController.text);
    final assigneeId = _assigneeId;
    if (startAt == null || endAt == null || assigneeId == null) return;
    final duration = endAt.difference(startAt);

    var candidate = endAt;
    final mins = candidate.minute;
    if (mins > 0 && mins < 30) {
      candidate = candidate.add(Duration(minutes: 30 - mins));
    } else if (mins > 30) {
      candidate = candidate.add(Duration(minutes: 60 - mins));
    }

    for (var i = 0; i < 24; i++) {
      final nextStart = candidate.add(Duration(minutes: i * 30));
      final nextEnd = nextStart.add(duration);
      final hasConflict = widget.existingAssignments.any((item) {
        if (item.assigneeUserId != assigneeId) return false;
        final itemStart = _parseAssignmentStart(item);
        if (itemStart == null) return false;
        final itemEnd = _parseAssignmentEnd(item, itemStart);
        if (itemEnd == null) return false;
        return nextStart.isBefore(itemEnd) && nextEnd.isAfter(itemStart);
      });
      if (!hasConflict) {
        setState(() {
          _startController.text = _formatTimeValue(nextStart);
          _endController.text = _formatTimeValue(nextEnd);
        });
        return;
      }
    }
  }

  String _normalizeCoverageKey(String value) => value.trim().toLowerCase();

  List<String> _normalizedUniqueOptions(Iterable<String> values) {
    final uniqueByKey = <String, String>{};
    for (final raw in values) {
      final value = raw.trim();
      if (value.isEmpty) continue;
      uniqueByKey.putIfAbsent(value.toLowerCase(), () => value);
    }
    final result = uniqueByKey.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return result;
  }

  String? _selectedOptionFromList(String? selected, List<String> options) {
    final value = (selected ?? '').trim();
    if (value.isEmpty) return null;
    final normalized = value.toLowerCase();
    for (final option in options) {
      if (option.toLowerCase() == normalized) return option;
    }
    return null;
  }

  List<AssignmentFrontCoverageOption> _coverageForFront(String? frontId) {
    if (frontId == null || frontId.trim().isEmpty) {
      return const [];
    }

    AssignmentFrontOption? selectedFront;
    for (final item in _fronts) {
      if (item.id == frontId) {
        selectedFront = item;
        break;
      }
    }
    final specificCandidates = <String>{
      _normalizeCoverageKey(frontId),
      if (selectedFront != null) ...[
        _normalizeCoverageKey(selectedFront.code),
        _normalizeCoverageKey(selectedFront.name),
      ],
    }..removeWhere((item) => item.isEmpty);

    final merged = <AssignmentFrontCoverageOption>[];
    for (final key in specificCandidates) {
      final entries = _frontCoverageByKey[key] ?? const <AssignmentFrontCoverageOption>[];
      for (final entry in entries) {
        final exists = merged.any(
          (item) =>
              item.estado.toLowerCase() == entry.estado.toLowerCase() &&
              item.municipio.toLowerCase() == entry.municipio.toLowerCase(),
        );
        if (!exists) {
          merged.add(entry);
        }
      }
    }

    return merged;
  }

  void _syncCoverageForFront(String? frontId) {
    final coverage = _coverageForFront(frontId);
    final estados = _normalizedUniqueOptions(
      coverage.map((item) => item.estado),
    );

    final estado = _selectedOptionFromList(_selectedEstado, estados);
    final municipios = _normalizedUniqueOptions(
      coverage
          .where((item) =>
              estado != null &&
              item.estado.trim().toLowerCase() == estado.toLowerCase())
          .map((item) => item.municipio),
    );

    final municipio = _selectedOptionFromList(_selectedMunicipio, municipios);

    _estadoOptions = estados;
    _municipioOptions = municipios;
    _selectedEstado = estado;
    _selectedMunicipio = municipio;
  }

  bool _canProceedToNextStep() {
    switch (_currentStep) {
      case 0:
        return _assigneeId != null;
      case 1:
        final pkInicio = _parsePkMeters(_pkController.text);
        final pkFin = _parsePkMeters(_pkFinController.text);
        final hasPk = switch (_tipoUbicacion) {
          _tipoPuntual => pkInicio != null,
          _tipoTramo => pkInicio != null && pkFin != null && pkFin >= pkInicio,
          _tipoLugar => _lugarController.text.trim().isNotEmpty,
          _ => false,
        };
        final hasFront = _frontId != null && _frontId!.trim().isNotEmpty;
        final requiresEstado = _estadoOptions.isNotEmpty;
        final requiresMunicipio = _municipioOptions.isNotEmpty;
        final hasEstado = !requiresEstado || _selectedEstado != null;
        final hasMunicipio = !requiresMunicipio || _selectedMunicipio != null;
        return _activityTypeCode != null && hasFront && hasPk && hasEstado && hasMunicipio;
      case 2:
        final startAt = _composeDateTime(_startController.text);
        final endAt = _composeDateTime(_endController.text);
        return startAt != null && endAt != null && endAt.isAfter(startAt);
      default:
        return false;
    }
  }

  Future<void> _handlePrimaryAction() async {
    if (!_canProceedToNextStep()) {
      setState(() {
        _error = _requiredErrorForCurrentStep();
      });
      return;
    }
    if (_currentStep < 2) {
      setState(() {
        _error = null;
        _currentStep += 1;
      });
      return;
    }
    await _submit();
  }

  Future<void> _handleEnterAdvance() async {
    if (_loading || _submitting) return;
    if (!_canProceedToNextStep()) {
      setState(() {
        _error = _requiredErrorForCurrentStep();
      });
      return;
    }
    await _handlePrimaryAction();
  }

  void _triggerGeocode() {
    _geocodeDebounce?.cancel();
    _geocodeDebounce = Timer(const Duration(milliseconds: 300), _runGeocode);
  }

  Future<void> _runGeocode() async {
    final estado = (_selectedEstado ?? '').trim();
    final municipio = (_selectedMunicipio ?? '').trim();
    if (estado.isEmpty || municipio.isEmpty) return;
    final colonia = _coloniaController.text.trim();
    final parts = <String>[
      if (colonia.isNotEmpty) colonia,
      municipio,
      estado,
      'Mexico',
    ];
    if (!mounted) return;
    setState(() => _geocoding = true);
    final result = await _geocodeNominatim(parts.join(', '));
    if (!mounted) return;
    setState(() => _geocoding = false);
    if (result == null) return;
    // Siempre actualizar si no hay pin manual previo o si fue auto-pinned
    if (_lat == null || _isAutoPinned) {
      setState(() {
        _lat = result.latitude;
        _lon = result.longitude;
        _isAutoPinned = true;
      });
      // Center map after a short delay to allow setState to complete
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted) {
        try {
          _mapController.move(result, 13.0);
        } catch (e) {
          // Map not ready yet
        }
      }
    }
  }

  Future<LatLng?> _geocodeNominatim(String query) async {
    try {
      final uri = Uri.https(
        'nominatim.openstreetmap.org',
        '/search',
        {'q': query, 'format': 'json', 'limit': '1', 'countrycodes': 'mx'},
      );
      final httpClient = HttpClient();
      final request = await httpClient.getUrl(uri);
      request.headers.set('User-Agent', 'SAO-Desktop/1.0 (mx.sao.desktop)');
      final response = await request.close().timeout(const Duration(seconds: 6));
      final body = await response.transform(const Utf8Decoder()).join();
      httpClient.close(force: false);
      if (response.statusCode != 200) return null;
      final list = jsonDecode(body) as List<dynamic>;
      if (list.isEmpty) return null;
      final first = list.first as Map<String, dynamic>;
      final lat = double.tryParse(first['lat'].toString());
      final lon = double.tryParse(first['lon'].toString());
      if (lat == null || lon == null) return null;
      return LatLng(lat, lon);
    } catch (_) {
      return null;
    }
  }

  String _requiredErrorForCurrentStep() {
    switch (_currentStep) {
      case 0:
        return 'Selecciona responsable.';
      case 1:
        if (_activityTypeCode == null) return 'Selecciona tipo de actividad.';
        if (_frontId == null || _frontId!.trim().isEmpty) return 'Selecciona frente.';
        if (_tipoUbicacion == _tipoPuntual && _parsePkMeters(_pkController.text) == null) {
          return 'Captura PK valido.';
        }
        if (_tipoUbicacion == _tipoTramo) {
          final pkInicio = _parsePkMeters(_pkController.text);
          final pkFin = _parsePkMeters(_pkFinController.text);
          if (pkInicio == null || pkFin == null) return 'Captura PK inicio y PK fin validos.';
          if (pkFin < pkInicio) return 'PK fin debe ser mayor o igual a PK inicio.';
        }
        if (_tipoUbicacion == _tipoLugar && _lugarController.text.trim().isEmpty) {
          return 'Captura lugar/referencia.';
        }
        if (_estadoOptions.isNotEmpty && _selectedEstado == null) return 'Selecciona estado.';
        if (_municipioOptions.isNotEmpty && _selectedMunicipio == null) return 'Selecciona municipio.';
        return 'Completa todos los campos obligatorios.';
      case 2:
        final startAt = _composeDateTime(_startController.text);
        final endAt = _composeDateTime(_endController.text);
        if (startAt == null || endAt == null) return 'Captura horario valido.';
        if (!endAt.isAfter(startAt)) return 'La hora fin debe ser mayor a la hora inicio.';
        final conflict = _checkConflict();
        if (conflict != null) return conflict;
        return 'Completa todos los campos obligatorios.';
      default:
        return 'Completa todos los campos obligatorios.';
    }
  }

  Widget _buildStep1() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '1. ¿A quien asignar?',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: _assigneeId,
          decoration: const InputDecoration(
            labelText: 'Responsable',
            border: OutlineInputBorder(),
          ),
          items: _assignees
              .map(
                (item) => DropdownMenuItem(
                  value: item.userId,
                  child: Text(item.fullName),
                ),
              )
              .toList(),
          onChanged:
              _submitting ? null : (value) => setState(() => _assigneeId = value),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    String selectedFrontName() {
      for (final front in _fronts) {
        if (front.id == _frontId) {
          return front.name.trim().isEmpty ? 'Sin frente' : front.name.trim();
        }
      }
      return 'Sin frente';
    }

    String selectedEstado() {
      final value = (_selectedEstado ?? '').trim();
      return value.isEmpty ? 'Sin estado' : value;
    }

    String selectedMunicipio() {
      final value = (_selectedMunicipio ?? '').trim();
      return value.isEmpty ? 'Sin municipio' : value;
    }

    String locationModeLabel() {
      if (_tipoUbicacion == _tipoTramo) return 'De PK a PK';
      if (_tipoUbicacion == _tipoLugar) return 'Lugar';
      return 'Puntual';
    }

    String locationDetailLabel() {
      if (_tipoUbicacion == _tipoTramo) {
        final start = _normalizePkInput(_pkController.text);
        final end = _normalizePkInput(_pkFinController.text);
        final startLabel = start.trim().isEmpty ? '0+000' : start;
        final endLabel = end.trim().isEmpty ? '0+000' : end;
        return 'PK inicio: $startLabel | PK fin: $endLabel';
      }
      if (_tipoUbicacion == _tipoLugar) {
        final lugar = _lugarController.text.trim();
        return lugar.isEmpty ? 'Lugar: Sin referencia' : 'Lugar: $lugar';
      }
      final pk = _normalizePkInput(_pkController.text);
      return 'PK: ${pk.trim().isEmpty ? '0+000' : pk}';
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '2. ¿Que y donde?',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: _activityTypeCode,
          decoration: const InputDecoration(
            labelText: 'Tipo de actividad',
            border: OutlineInputBorder(),
          ),
          items: _activityTypes
              .map(
                (item) => DropdownMenuItem(
                  value: item.code,
                  child: Text(item.label),
                ),
              )
              .toList(),
          onChanged: _submitting
              ? null
              : (value) => setState(() => _activityTypeCode = value),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: _frontId,
          decoration: const InputDecoration(
            labelText: 'Frente',
            border: OutlineInputBorder(),
          ),
          items: _fronts
              .map(
                (item) => DropdownMenuItem(
                  value: item.id,
                  child: Text(item.name),
                ),
              )
              .toList(),
          onChanged: _submitting
              ? null
              : (value) => setState(() {
                    _frontId = value;
                    _syncCoverageForFront(value);
                  }),
        ),
        const SizedBox(height: 10),
        if (_estadoOptions.isEmpty)
          const InputDecorator(
            decoration: InputDecoration(
              labelText: 'Estado',
              border: OutlineInputBorder(),
            ),
            child: Text(
              'Sin cobertura de estado para este frente',
              style: TextStyle(color: SaoColors.gray500),
            ),
          )
        else
          DropdownButtonFormField<String>(
            initialValue: _selectedOptionFromList(_selectedEstado, _estadoOptions),
            decoration: const InputDecoration(
              labelText: 'Estado',
              border: OutlineInputBorder(),
            ),
            items: _estadoOptions
                .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                .toList(),
            onChanged: _submitting
                ? null
                : (value) {
                    setState(() {
                      _selectedEstado = _selectedOptionFromList(value, _estadoOptions);
                      final coverage = _coverageForFront(_frontId);
                      _municipioOptions = _normalizedUniqueOptions(
                        coverage
                            .where((entry) =>
                                value != null &&
                                entry.estado.trim().toLowerCase() == value.toLowerCase())
                            .map((entry) => entry.municipio),
                      );
                      _selectedMunicipio =
                          _selectedOptionFromList(_selectedMunicipio, _municipioOptions) ??
                          (_municipioOptions.isNotEmpty ? _municipioOptions.first : null);
                    });
                    _triggerGeocode();
                  },
          ),
        const SizedBox(height: 10),
        if (_selectedEstado == null || _municipioOptions.isEmpty)
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Municipio',
              border: OutlineInputBorder(),
            ),
            child: Text(
              _selectedEstado == null
                  ? 'Selecciona estado primero'
                  : 'Sin municipios para el estado seleccionado',
              style: const TextStyle(color: SaoColors.gray500),
            ),
          )
        else
          DropdownButtonFormField<String>(
            initialValue: _selectedOptionFromList(_selectedMunicipio, _municipioOptions),
            decoration: const InputDecoration(
              labelText: 'Municipio',
              border: OutlineInputBorder(),
            ),
            items: _municipioOptions
                .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                .toList(),
            onChanged: _submitting
                ? null
                : (value) {
                    setState(() => _selectedMunicipio = value);
                    _triggerGeocode();
                  },
          ),
        const SizedBox(height: 10),
        TextField(
          controller: _coloniaController,
          enabled: !_submitting,
          onChanged: (_) {
            setState(() {});
            _triggerGeocode();
          },
          decoration: InputDecoration(
            labelText: 'Colonia (opcional)',
            border: const OutlineInputBorder(),
            suffixIcon: _geocoding
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: ChoiceChip(
                  label: const Text('Puntual'),
                  selected: _tipoUbicacion == _tipoPuntual,
                  onSelected: (_) {
                    if (_submitting) return;
                    setState(() {
                      _tipoUbicacion = _tipoPuntual;
                      _pkFinController.clear();
                      _lugarController.clear();
                    });
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: ChoiceChip(
                  label: const Text('De PK a PK'),
                  selected: _tipoUbicacion == _tipoTramo,
                  onSelected: (_) {
                    if (_submitting) return;
                    setState(() {
                      _tipoUbicacion = _tipoTramo;
                      _lugarController.clear();
                    });
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: ChoiceChip(
                  label: const Text('Lugar'),
                  selected: _tipoUbicacion == _tipoLugar,
                  onSelected: (_) {
                    if (_submitting) return;
                    setState(() {
                      _tipoUbicacion = _tipoLugar;
                      _pkFinController.clear();
                    });
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_tipoUbicacion == _tipoPuntual)
          TextField(
            controller: _pkController,
            focusNode: _pkFocusNode,
            enabled: !_submitting,
            keyboardType: TextInputType.text,
            inputFormatters: const [_PkChainageInputFormatter()],
            onChanged: (_) {
              if (mounted) {
                setState(() {});
              }
            },
            onTap: () {
              if (_pkController.text.trim() == '0+000') {
                _pkController.clear();
              }
            },
            onSubmitted: (_) => _handlePkEnter(_pkController),
            decoration: const InputDecoration(
              labelText: 'PK',
              hintText: '0+000',
              border: OutlineInputBorder(),
            ),
          )
        else if (_tipoUbicacion == _tipoTramo) ...[
          TextField(
            controller: _pkController,
            focusNode: _pkFocusNode,
            enabled: !_submitting,
            keyboardType: TextInputType.text,
            inputFormatters: const [_PkChainageInputFormatter()],
            onChanged: (_) {
              if (mounted) {
                setState(() {});
              }
            },
            onTap: () {
              if (_pkController.text.trim() == '0+000') {
                _pkController.clear();
              }
            },
            onSubmitted: (_) => _handlePkEnter(_pkController),
            decoration: const InputDecoration(
              labelText: 'PK inicio',
              hintText: '0+000',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _pkFinController,
            focusNode: _pkFinFocusNode,
            enabled: !_submitting,
            keyboardType: TextInputType.text,
            inputFormatters: const [_PkChainageInputFormatter()],
            onChanged: (_) {
              if (mounted) {
                setState(() {});
              }
            },
            onSubmitted: (_) => _handlePkEnter(_pkFinController),
            decoration: const InputDecoration(
              labelText: 'PK fin',
              hintText: '0+000',
              border: OutlineInputBorder(),
            ),
          ),
        ] else
          TextField(
            controller: _lugarController,
            enabled: !_submitting,
            onChanged: (_) {
              if (mounted) {
                setState(() {});
              }
            },
            onSubmitted: (_) {
              _handleEnterAdvance();
            },
            decoration: const InputDecoration(
              labelText: 'Lugar / Referencia',
              hintText: 'Ej. Estación central, patio, acceso principal',
              border: OutlineInputBorder(),
            ),
          ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: SaoColors.gray50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: SaoColors.gray200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Detalles de ubicación',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: SaoColors.gray600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                selectedFrontName(),
                style: const TextStyle(color: SaoColors.gray700),
              ),
              const SizedBox(height: 2),
              Text(
                '${selectedEstado()} / ${selectedMunicipio()}',
                style: const TextStyle(color: SaoColors.gray700),
              ),
              const SizedBox(height: 2),
              Text(
                'Tipo: ${locationModeLabel()}',
                style: const TextStyle(color: SaoColors.gray700),
              ),
              const SizedBox(height: 2),
              Text(
                locationDetailLabel(),
                style: const TextStyle(color: SaoColors.gray700),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _titleController,
          enabled: !_submitting,
          onSubmitted: (_) {
            _handleEnterAdvance();
          },
          decoration: const InputDecoration(
            labelText: 'Titulo (opcional)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        _buildMapPickerCollapsible(),
      ],
    );
  }

  Widget _buildMapPickerCollapsible() {
    final pinPoint = (_lat != null && _lon != null) ? LatLng(_lat!, _lon!) : null;
    final hasPinLabel = pinPoint != null
        ? '${_isAutoPinned ? "Geocodificado" : "Pin manual"}: ${_lat!.toStringAsFixed(5)}, ${_lon!.toStringAsFixed(5)}'
        : 'Sin pin GPS';

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: SaoColors.gray200),
        borderRadius: BorderRadius.circular(8),
        color: SaoColors.gray50,
      ),
      child: Column(
        children: [
          // Header toggle row
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _mapExpanded = !_mapExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    pinPoint != null ? Icons.location_on_rounded : Icons.location_off_outlined,
                    size: 16,
                    color: pinPoint != null ? SaoColors.primary : SaoColors.gray500,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hasPinLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: pinPoint != null ? SaoColors.primary : SaoColors.gray500,
                      ),
                    ),
                  ),
                  if (pinPoint != null && !_mapExpanded)
                    GestureDetector(
                      onTap: () => setState(() { _lat = null; _lon = null; _isAutoPinned = false; }),
                      child: const Icon(Icons.close, size: 14, color: SaoColors.error),
                    ),
                  const SizedBox(width: 6),
                  Icon(
                    _mapExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: SaoColors.gray500,
                  ),
                ],
              ),
            ),
          ),
          if (_mapExpanded) _buildMapPicker(),
        ],
      ),
    );
  }

  Widget _buildMapPicker() {
    // Default center: Mexico
    const defaultCenter = LatLng(23.634, -102.552);
    final pinPoint = (_lat != null && _lon != null) ? LatLng(_lat!, _lon!) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  pinPoint != null
                      ? 'Toca el mapa para mover el pin'
                      : 'Toca el mapa para marcar el punto. Al llenar estado/municipio/colonia se posiciona automaticamente.',
                  style: const TextStyle(fontSize: 11, color: SaoColors.gray500),
                ),
              ),
              if (pinPoint != null)
                TextButton.icon(
                  onPressed: () => setState(() { _lat = null; _lon = null; _isAutoPinned = false; }),
                  icon: const Icon(Icons.close, size: 14),
                  label: const Text('Limpiar'),
                  style: TextButton.styleFrom(
                    foregroundColor: SaoColors.error,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
        ),
        ClipRRect(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(8),
            bottomRight: Radius.circular(8),
          ),
          child: SizedBox(
            height: 220,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: pinPoint ?? defaultCenter,
                initialZoom: pinPoint != null ? 12.0 : 5.0,
                onTap: (_, latlng) {
                  setState(() {
                    _lat = latlng.latitude;
                    _lon = latlng.longitude;
                    _isAutoPinned = false;
                  });
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'mx.sao.desktop',
                ),
                if (pinPoint != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: pinPoint,
                        width: 36,
                        height: 36,
                        child: const Icon(
                          Icons.location_pin,
                          size: 36,
                          color: SaoColors.error,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep3() {
    final conflict = _checkConflict();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '3. ¿Cuando?',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _submitting ? null : () => _pickTime(true),
                icon: const Icon(Icons.schedule_rounded, size: 16),
                label: Text('Inicio: ${_startController.text}'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _submitting ? null : () => _pickTime(false),
                icon: const Icon(Icons.schedule_rounded, size: 16),
                label: Text('Fin: ${_endController.text}'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _submitting ? null : () => _setDuration(30),
                child: const Text('30 min'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: _submitting ? null : () => _setDuration(60),
                child: const Text('1 hora'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: _submitting ? null : () => _setDuration(120),
                child: const Text('2 horas'),
              ),
            ),
          ],
        ),
        if (conflict != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(conflict, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _submitting ? null : _findNextFreeSlot,
                  icon: const Icon(Icons.search_rounded, size: 16),
                  label: const Text('Buscar hueco libre'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _submit() async {
    if (_assigneeId == null || _activityTypeCode == null) {
      setState(() => _error = 'Selecciona responsable y tipo de actividad.');
      return;
    }
    final startAt = _composeDateTime(_startController.text);
    final endAt = _composeDateTime(_endController.text);
    if (startAt == null || endAt == null || !endAt.isAfter(startAt)) {
      setState(() => _error = 'Horario inválido. Usa formato HH:MM y fin mayor a inicio.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final pkInicio = _parsePkMeters(_pkController.text);
      final conflict = _checkConflict();
      if (conflict != null) {
        setState(() {
          _submitting = false;
          _error = conflict;
        });
        return;
      }

      final effectivePk = switch (_tipoUbicacion) {
        _tipoPuntual => pkInicio ?? 0,
        _tipoTramo => pkInicio ?? 0,
        _tipoLugar => 0,
        _ => 0,
      };

          final selectedActivityName = _activityTypes
            .where((item) => item.code == _activityTypeCode)
              .map((item) => item.name.trim())
            .firstOrNull ??
          '';
        final typedTitle = _titleController.text.trim();
        final effectiveTitle = typedTitle.isNotEmpty
          ? typedTitle
            : (selectedActivityName.isNotEmpty ? selectedActivityName : null);

      final repo = ref.read(assignmentsRepositoryProvider);
      await repo.createAssignment(
        projectId: widget.projectId,
        assigneeUserId: _assigneeId!,
        activityTypeCode: _activityTypeCode!,
        startAt: startAt,
        endAt: endAt,
        title: effectiveTitle,
        frontId: _frontId,
        estado: _selectedEstado,
        municipio: _selectedMunicipio,
        colonia: _coloniaController.text.trim().isNotEmpty ? _coloniaController.text.trim() : null,
        pk: effectivePk,
        risk: 'bajo',
        latitude: _lat,
        longitude: _lon,
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canProceed = !_loading && !_submitting && _canProceedToNextStep();

    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (intent) {
              if (_pkFocusNode.hasFocus) {
                _handlePkEnter(_pkController);
                return null;
              }
              if (_pkFinFocusNode.hasFocus) {
                _handlePkEnter(_pkFinController);
                return null;
              }
              _handleEnterAdvance();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: AlertDialog(
            title: Row(
              children: [
                const Text('Asignar actividad'),
                const Spacer(),
                Text(
                  'Paso ${_currentStep + 1}/3',
                  style: const TextStyle(fontSize: 12, color: SaoColors.gray500),
                ),
              ],
            ),
            content: SizedBox(
              width: 560,
              child: _loading
                  ? const SizedBox(
                      height: 120,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_error != null) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _error!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                          if (_currentStep == 0) _buildStep1(),
                          if (_currentStep == 1) _buildStep2(),
                          if (_currentStep == 2) _buildStep3(),
                        ],
                      ),
                    ),
            ),
            actions: [
              if (_currentStep > 0)
                TextButton(
                  onPressed: _submitting
                      ? null
                      : () => setState(() {
                            if (_currentStep == 2) {
                              _activityTypeCode ??=
                                  _activityTypes.isNotEmpty ? _activityTypes.first.code : null;
                              _frontId ??= _fronts.isNotEmpty ? _fronts.first.id : null;
                              _syncCoverageForFront(_frontId);
                            }
                            _error = null;
                            _currentStep -= 1;
                          }),
                  child: const Text('Atras'),
                ),
              TextButton(
                onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: canProceed ? _handlePrimaryAction : null,
                child: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_currentStep == 2 ? 'Crear tarea' : 'Siguiente'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssignmentActionsMenu extends ConsumerStatefulWidget {
  final AssignmentItem item;
  final VoidCallback onEdited;
  final VoidCallback onDuplicated;
  final ValueChanged<String> onDeleted;

  const _AssignmentActionsMenu({
    required this.item,
    required this.onEdited,
    required this.onDuplicated,
    required this.onDeleted,
  });

  @override
  ConsumerState<_AssignmentActionsMenu> createState() =>
      _AssignmentActionsMenuState();
}

class _AssignmentActionsMenuState extends ConsumerState<_AssignmentActionsMenu> {
  bool _loading = false;

  Future<void> _confirm() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar asignación'),
        content: Text(
          '¿Cancelar la asignación de "${widget.item.activityTypeName}" '
          'a ${widget.item.assigneeName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancelar asignación'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _loading = true);
    try {
      const apiClient = BackendApiClient();
      try {
        await apiClient.deleteJson('/api/v1/activities/${widget.item.id}');
      } catch (_) {
        final assignmentsRepo = ref.read(assignmentsRepositoryProvider);
        await assignmentsRepo.cancelAssignment(widget.item.id, reason: 'deleted_from_planning');
      }
      if (mounted) widget.onDeleted(widget.item.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cancelar: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return PopupMenuButton<String>(
      tooltip: 'Acciones',
      onSelected: (value) {
        if (value == 'edit') {
          widget.onEdited();
          return;
        }
        if (value == 'duplicate') {
          widget.onDuplicated();
          return;
        }
        if (value == 'delete') {
          _confirm();
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem<String>(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 16),
              SizedBox(width: 8),
              Text('Editar'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'duplicate',
          child: Row(
            children: [
              Icon(Icons.copy_rounded, size: 16),
              SizedBox(width: 8),
              Text('Duplicar'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
              SizedBox(width: 8),
              Text('Eliminar', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
      child: const Icon(Icons.more_horiz_rounded, size: 18),
    );
  }
}

class _HoverAssignmentActions extends StatefulWidget {
  final AssignmentItem item;
  final VoidCallback onEdited;
  final VoidCallback onDuplicated;
  final ValueChanged<String> onDeleted;

  const _HoverAssignmentActions({
    required this.item,
    required this.onEdited,
    required this.onDuplicated,
    required this.onDeleted,
  });

  @override
  State<_HoverAssignmentActions> createState() => _HoverAssignmentActionsState();
}

class _HoverAssignmentActionsState extends State<_HoverAssignmentActions> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: SizedBox(
        width: 28,
        height: 28,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 140),
          opacity: _hovered ? 1 : 0,
          child: IgnorePointer(
            ignoring: !_hovered,
            child: _AssignmentActionsMenu(
              item: widget.item,
              onEdited: widget.onEdited,
              onDuplicated: widget.onDuplicated,
              onDeleted: widget.onDeleted,
            ),
          ),
        ),
      ),
    );
  }
}

String _planningNormalizedStatus(String rawStatus) {
  return rawStatus
      .trim()
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll(' ', '_');
}

Color _planningStatusColor(String rawStatus) {
  final normalized = _planningNormalizedStatus(rawStatus);
  switch (normalized) {
    case 'pendiente':
    case 'pending':
      return SaoColors.statusPendiente;
    case 'asignada':
    case 'asignado':
    case 'programada':
    case 'programado':
      return SaoColors.statusEnCampo;
    case 'iniciada':
    case 'iniciado':
    case 'iniciando':
    case 'en_proceso':
    case 'in_progress':
    case 'en_curso':
      return SaoColors.statusEnValidacion;
    case 'terminada':
    case 'terminado':
    case 'finalizada':
    case 'finalizado':
    case 'confirmada':
    case 'confirmed':
    case 'completada':
    case 'completed':
      return SaoColors.statusAprobado;
    case 'cancelada':
    case 'cancelado':
    case 'rechazada':
    case 'rechazado':
      return SaoColors.statusRechazado;
    default:
      return SaoColors.getStatusColor(rawStatus);
  }
}

String _planningStatusLabel(String rawStatus) {
  final normalized = _planningNormalizedStatus(rawStatus);
  switch (normalized) {
    case 'pending':
    case 'pendiente':
      return 'Pendiente';
    case 'asignada':
    case 'asignado':
      return 'Asignada';
    case 'programada':
    case 'programado':
      return 'Programada';
    case 'iniciada':
    case 'iniciado':
    case 'iniciando':
      return 'Iniciada';
    case 'en_proceso':
    case 'in_progress':
      return 'En proceso';
    case 'en_curso':
      return 'En curso';
    case 'terminada':
    case 'terminado':
      return 'Terminada';
    case 'finalizada':
    case 'finalizado':
      return 'Finalizada';
    case 'confirmada':
    case 'confirmed':
      return 'Confirmada';
    case 'completada':
    case 'completed':
      return 'Completada';
    case 'cancelada':
    case 'cancelado':
      return 'Cancelada';
    case 'rechazada':
    case 'rechazado':
      return 'Rechazada';
    default:
      final fallback = SaoColors.getStatusLabel(rawStatus);
      return fallback[0] + fallback.substring(1).toLowerCase();
  }
}

class _StatusPill extends StatelessWidget {
  final String label;

  const _StatusPill({required this.label});

  @override
  Widget build(BuildContext context) {
    final color = _planningStatusColor(label);
    final display = _planningStatusLabel(label);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(display,
          style: TextStyle(color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _PkChainageInputFormatter extends TextInputFormatter {
  const _PkChainageInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var raw = newValue.text;
    final isDeleting = newValue.text.length < oldValue.text.length;

    // If default placeholder is still present and user starts typing at the end,
    // keep only the newly typed chunk.
    if (oldValue.text == '0+000' && raw.startsWith(oldValue.text)) {
      raw = raw.substring(oldValue.text.length);
    }

    final cleaned = raw.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleaned.isEmpty) {
      return const TextEditingValue(text: '');
    }

    String formatted;
    if (cleaned.contains('+')) {
      final parts = cleaned.split('+');
      final left = parts.first.replaceAll(RegExp(r'[^0-9]'), '');
      final right = parts.skip(1).join().replaceAll(RegExp(r'[^0-9]'), '');
      final rightLimited = right.length > 3 ? right.substring(0, 3) : right;
      formatted = '$left+$rightLimited';
    } else {
      final digits = cleaned.replaceAll('+', '');
      if (digits.length < 3) {
        formatted = digits;
      } else if (digits.length == 3) {
        formatted = isDeleting ? digits : '$digits+';
      } else {
        final right = digits.substring(3, digits.length > 6 ? 6 : digits.length);
        formatted = '${digits.substring(0, 3)}+$right';
      }
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _PlanningMonthCalendar extends StatelessWidget {
  final DateTime selectedDate;
  final List<AssignmentItem> items;
  final ValueChanged<DateTime> onSelectedDate;

  const _PlanningMonthCalendar({
    required this.selectedDate,
    required this.items,
    required this.onSelectedDate,
  });

  DateTime? _itemDay(AssignmentItem item) {
    if ((item.scheduledDate).trim().isNotEmpty) {
      return DateTime.tryParse(item.scheduledDate)?.toLocal();
    }
    if (item.scheduledTime.contains('T')) {
      return DateTime.tryParse(item.scheduledTime)?.toLocal();
    }
    if ((item.startAt ?? '').trim().isNotEmpty) {
      return DateTime.tryParse(item.startAt!)?.toLocal();
    }
    return null;
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Color _statusColor(String status) {
    return _planningStatusColor(status);
  }

  @override
  Widget build(BuildContext context) {
    final monthStart = DateTime(selectedDate.year, selectedDate.month, 1);
    final daysInMonth = DateTime(selectedDate.year, selectedDate.month + 1, 0).day;
    final leading = monthStart.weekday - 1;
    final today = DateTime.now();

    final monthMap = <DateTime, List<AssignmentItem>>{};
    for (final item in items) {
      final day = _itemDay(item);
      if (day == null) continue;
      final key = DateTime(day.year, day.month, day.day);
      monthMap.putIfAbsent(key, () => <AssignmentItem>[]).add(item);
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_month_rounded, size: 18),
              const SizedBox(width: 8),
              Text(
                DateFormat('MMMM yyyy', 'es').format(selectedDate),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => onSelectedDate(DateTime(selectedDate.year, selectedDate.month - 1, 1)),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              IconButton(
                onPressed: () => onSelectedDate(DateTime(selectedDate.year, selectedDate.month + 1, 1)),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Row(
            children: [
              Expanded(child: Center(child: Text('L'))),
              Expanded(child: Center(child: Text('M'))),
              Expanded(child: Center(child: Text('M'))),
              Expanded(child: Center(child: Text('J'))),
              Expanded(child: Center(child: Text('V'))),
              Expanded(child: Center(child: Text('S'))),
              Expanded(child: Center(child: Text('D'))),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: ((leading + daysInMonth + 6) ~/ 7) * 7,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                childAspectRatio: 0.85,
              ),
              itemBuilder: (context, index) {
                final dayNum = index - leading + 1;
                if (dayNum < 1 || dayNum > daysInMonth) {
                  return const SizedBox.shrink();
                }

                final day = DateTime(selectedDate.year, selectedDate.month, dayNum);
                final selected = _sameDay(day, selectedDate);
                final isToday = _sameDay(day, today);
                final dayItems = monthMap[day] ?? const <AssignmentItem>[];
                final count = dayItems.length;
                final statusColors = <Color>{
                  for (final item in dayItems) _statusColor(item.status),
                }.toList();

                return InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => onSelectedDate(day),
                  child: Container(
                    decoration: BoxDecoration(
                      color: selected
                          ? SaoColors.info.withValues(alpha: 0.20)
                          : (isToday ? SaoColors.primary.withValues(alpha: 0.06) : Colors.transparent),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selected
                            ? SaoColors.info
                            : (isToday ? SaoColors.primary.withValues(alpha: 0.45) : SaoColors.gray200),
                        width: selected ? 2 : (isToday ? 1.2 : 1),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Número del día
                        Text(
                          '$dayNum',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: selected || isToday
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: selected
                                ? SaoColors.info
                                : (isToday ? SaoColors.primary : SaoColors.gray700),
                          ),
                        ),
                        if (isToday && !selected)
                          Container(
                            width: 4,
                            height: 4,
                            margin: const EdgeInsets.only(top: 2),
                            decoration: const BoxDecoration(
                              color: SaoColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        // Puntos de estado (máx 3), solo si caben
                        if (statusColors.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (final color in statusColors.take(3))
                                  Container(
                                    width: 6,
                                    height: 6,
                                    margin: const EdgeInsets.symmetric(horizontal: 1.2),
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        // Badge de conteo con fuente pequeña
                        if (count > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              '$count',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: SaoColors.primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          const Wrap(
            spacing: 10,
            runSpacing: 6,
            children: [
              _CalendarLegendDot(color: SaoColors.statusPendiente, label: 'Pendiente'),
              _CalendarLegendDot(color: SaoColors.statusEnCampo, label: 'Asignada/Programada'),
              _CalendarLegendDot(color: SaoColors.statusEnValidacion, label: 'Iniciada/En proceso'),
              _CalendarLegendDot(color: SaoColors.statusAprobado, label: 'Terminada/Finalizada'),
            ],
          ),
        ],
      ),
    );
  }
}

class _CalendarLegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _CalendarLegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11, color: SaoColors.gray600)),
      ],
    );
  }
}

class _CollapsedCalendarRail extends StatelessWidget {
  final DateTime selectedDate;
  final VoidCallback onExpand;

  const _CollapsedCalendarRail({
    required this.selectedDate,
    required this.onExpand,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Column(
        children: [
          IconButton(
            onPressed: onExpand,
            tooltip: 'Expandir calendario',
            icon: const Icon(Icons.keyboard_double_arrow_right_rounded),
          ),
          const SizedBox(height: 12),
          const Icon(Icons.calendar_month_rounded, color: SaoColors.gray600),
          const SizedBox(height: 8),
          Text(
            DateFormat('d', 'es').format(selectedDate),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: SaoColors.gray700,
            ),
          ),
          Text(
            DateFormat('MMM', 'es').format(selectedDate),
            style: const TextStyle(
              fontSize: 12,
              color: SaoColors.gray500,
            ),
          ),
        ],
      ),
    );
  }
}

class _HourlyAssignmentsView extends StatefulWidget {
  final String projectId;
  final List<AssignmentItem> assignments;
  final DateTime selectedDate;
  final VoidCallback onEdited;
  final VoidCallback onDuplicated;
  final ValueChanged<String> onDeleted;
  final int totalAssignments;

  const _HourlyAssignmentsView({
    required this.projectId,
    required this.assignments,
    required this.selectedDate,
    required this.onEdited,
    required this.onDuplicated,
    required this.onDeleted,
    required this.totalAssignments,
  });

  @override
  State<_HourlyAssignmentsView> createState() => _HourlyAssignmentsViewState();
}

class _HourlyAssignmentsViewState extends State<_HourlyAssignmentsView> {
  bool _showEmptySlots = false;
  final Set<String> _activeStatusFilters = <String>{};
  final Set<String> _dismissedAssignmentIds = <String>{};
  final Map<String, ({DateTime start, DateTime end})> _manualScheduleById = {};
  final Map<String, String> _notesByAssignmentId = {};
  final Map<String, String> _statusOverrideByAssignmentId = {};
  final List<AssignmentFrontOption> _frontOptions = <AssignmentFrontOption>[];
  final Map<String, List<AssignmentFrontCoverageOption>> _coverageByFront =
      <String, List<AssignmentFrontCoverageOption>>{};
  final TextEditingController _pkFilterController = TextEditingController();
  bool _overdueBlinkOn = false;
  String? _hoveredAssignmentId;
  Timer? _overdueBlinkTimer;

  @override
  void initState() {
    super.initState();
    _loadLocationMetadata();
    _overdueBlinkTimer = Timer.periodic(const Duration(milliseconds: 700), (_) {
      if (!mounted) return;
      setState(() {
        _overdueBlinkOn = !_overdueBlinkOn;
      });
    });
  }

  @override
  void didUpdateWidget(covariant _HourlyAssignmentsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projectId != widget.projectId) {
      _frontOptions.clear();
      _coverageByFront.clear();
      _loadLocationMetadata();
      return;
    }

    // If assignments arrived but metadata stayed empty (temporary endpoint failure), retry once.
    if (widget.assignments.isNotEmpty &&
        _frontOptions.isEmpty &&
        _coverageByFront.isEmpty) {
      _loadLocationMetadata();
    }
  }

  Future<void> _loadLocationMetadata() async {
    if (widget.projectId.trim().isEmpty) return;
    const repo = AssignmentsRepository(BackendApiClient());
    var fronts = const <AssignmentFrontOption>[];
    var coverage = const <String, List<AssignmentFrontCoverageOption>>{};

    try {
      fronts = await repo.getFronts(widget.projectId);
    } catch (_) {
      // Continue with any remaining fallback source.
    }

    try {
      coverage = await repo.getFrontCoverageByFront(widget.projectId);
    } catch (_) {
      // Continue with whatever metadata was available.
    }

    if (!mounted) return;
    setState(() {
      _frontOptions
        ..clear()
        ..addAll(fronts);
      _coverageByFront
        ..clear()
        ..addAll(coverage);
    });
  }

  @override
  void dispose() {
    _overdueBlinkTimer?.cancel();
    _pkFilterController.dispose();
    super.dispose();
  }

  String _effectiveStatus(AssignmentItem item) {
    return _statusOverrideByAssignmentId[item.id] ?? item.status;
  }

  int? _parsePkMeters(String raw) {
    final compact = raw.trim().replaceAll(' ', '');
    if (compact.isEmpty || compact == '—') return null;

    final chainage = RegExp(r'^(\d+)\+(\d{1,3})$').firstMatch(compact);
    if (chainage != null) {
      final km = int.tryParse(chainage.group(1)!);
      final meters = int.tryParse(chainage.group(2)!.padRight(3, '0'));
      if (km == null || meters == null || meters > 999) return null;
      return km * 1000 + meters;
    }

    final chainageNoMeters = RegExp(r'^(\d+)\+$').firstMatch(compact);
    if (chainageNoMeters != null) {
      final km = int.tryParse(chainageNoMeters.group(1)!);
      if (km == null) return null;
      return km * 1000;
    }

    return int.tryParse(compact);
  }

  (int?, int?) _pkFilterRange() {
    final query = _pkFilterController.text.trim().replaceAll(' ', '');
    if (query.isEmpty) return (null, null);
    if (query.contains('-')) {
      final parts = query.split('-');
      if (parts.length != 2) return (null, null);
      final start = _parsePkMeters(parts[0]);
      final end = _parsePkMeters(parts[1]);
      if (start == null || end == null) return (null, null);
      return start <= end ? (start, end) : (end, start);
    }
    final exact = _parsePkMeters(query);
    if (exact == null) return (null, null);
    return (exact, exact);
  }

  bool _matchesPkFilter(AssignmentItem item) {
    final (start, end) = _pkFilterRange();
    if (start == null || end == null) return true;
    final value = _parsePkMeters(item.pk);
    if (value == null) return false;
    return value >= start && value <= end;
  }

  Future<void> _updateStatus(AssignmentItem item, String newStatus) async {
    setState(() {
      _statusOverrideByAssignmentId[item.id] = newStatus;
    });
  }

  /// Convierte "20+630" → 20630 (metros). Devuelve null si no es parseable.
  int? _pkToMeters(String raw) {
    final s = raw.trim();
    if (s.isEmpty || s == '—') return null;
    final parts = s.split('+');
    if (parts.length == 2) {
      final km = int.tryParse(parts[0].trim());
      final m = int.tryParse(parts[1].trim());
      if (km != null && m != null) return km * 1000 + m;
    }
    return int.tryParse(s);
  }

  Future<void> _generateDailyReport(
    List<({AssignmentItem item, DateTime start, DateTime end})> entries,
  ) async {
    final nowStamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final dateStamp = DateFormat('yyyy-MM-dd').format(widget.selectedDate);

    // Esquema normalizado:
    // - responsable_id es el lookup key; nombre eliminado (redundante)
    // - estado_geo  = ubicación física (Guerrero, Oaxaca…)
    // - workflow_status = estado del flujo (PROGRAMADA, CANCELADA…)
    // - valores vacíos en lugar de "Sin frente", "Sin estado", "—"
    final csv = StringBuffer()
      ..writeln('id_log,fecha,timestamp_ini,timestamp_fin,duracion_min,'
          'actividad_cod,frente,pk_m,estado_geo,municipio,'
          'responsable_id,workflow_status,nota');

    // helper: devuelve cadena vacía si el valor es placeholder
    String clean(String v) {
      final t = v.trim();
      if (t.isEmpty || t == '—') return '';
      final lower = t.toLowerCase();
      if (lower.startsWith('sin ') || lower == 'n/a') return '';
      return t;
    }

    for (final entry in entries) {
      // Quoted field – escapa comillas internas
      String q(String v) {
        final c = clean(v);
        if (c.isEmpty) return '';          // NULL semántico → celda vacía sin comillas
        return '"${c.replaceAll('"', '""')}"';
      }

      final tsIni = entry.start.toIso8601String();
      final tsFin = entry.end.toIso8601String();
      final durMin = entry.end.difference(entry.start).inMinutes;
      final pkM = _pkToMeters(entry.item.pk)?.toString() ?? '';

      csv.writeln(
        '${q(entry.item.id)},$dateStamp,$tsIni,$tsFin,$durMin,'
        '${q(entry.item.activityTypeName)},${q(_locationFront(entry.item))},$pkM,'
        '${q(_locationEstado(entry.item))},${q(_locationMunicipio(entry.item))},'
        '${q(entry.item.assigneeUserId)},${q(_effectiveStatus(entry.item))},'
        '${q(_notesByAssignmentId[entry.item.id] ?? '')}',
      );
    }

    final userProfile = Platform.environment['USERPROFILE'];
    final downloadsPath = userProfile == null || userProfile.isEmpty
        ? Directory.current.path
        : '$userProfile\\Downloads';
    final dir = Directory(downloadsPath);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    final file = File('${dir.path}\\reporte_planeacion_${dateStamp}_$nowStamp.csv');
    file.writeAsStringSync(csv.toString());

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Reporte guardado: ${file.path}'),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: 'Abrir carpeta',
          onPressed: () {
            Process.run('explorer.exe', [dir.path]);
          },
        ),
      ),
    );
  }

  DateTime? _parseAssignmentStart(AssignmentItem item) {
    if ((item.startAt ?? '').isNotEmpty) {
      return DateTime.tryParse(item.startAt!)?.toLocal();
    }
    if (item.scheduledTime.contains('T')) {
      return DateTime.tryParse(item.scheduledTime)?.toLocal();
    }
    final datePart = DateTime.tryParse(item.scheduledDate);
    final timePart = item.scheduledTime.trim();
    if (datePart != null && timePart.contains(':')) {
      final parts = timePart.split(':');
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts.length > 1 ? parts[1] : '0');
      if (hour != null && minute != null) {
        return DateTime(datePart.year, datePart.month, datePart.day, hour, minute);
      }
    }
    return null;
  }

  DateTime _parseAssignmentEnd(AssignmentItem item, DateTime start) {
    if ((item.endAt ?? '').isNotEmpty) {
      final parsed = DateTime.tryParse(item.endAt!);
      if (parsed != null) return parsed.toLocal();
    }
    return start.add(const Duration(hours: 1));
  }

  ({DateTime start, DateTime end}) _effectiveScheduleFor(AssignmentItem item) {
    final override = _manualScheduleById[item.id];
    if (override != null) {
      return (start: override.start, end: override.end);
    }
    final start = _parseAssignmentStart(item);
    if (start == null) {
      final fallback = DateTime(
        widget.selectedDate.year,
        widget.selectedDate.month,
        widget.selectedDate.day,
      );
      return (start: fallback, end: fallback.add(const Duration(hours: 1)));
    }
    return (start: start, end: _parseAssignmentEnd(item, start));
  }

  ({DateTime start, DateTime end}) _fallbackScheduleFor(AssignmentItem item) {
    final raw = '${item.scheduledTime} ${item.startAt ?? ''}';
    final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(raw);
    final hour = int.tryParse(match?.group(1) ?? '');
    final minute = int.tryParse(match?.group(2) ?? '') ?? 0;
    final safeHour = (hour != null && hour >= 0 && hour <= 23) ? hour : 8;
    final safeMinute = minute >= 0 && minute <= 59 ? minute : 0;

    final start = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
      safeHour,
      safeMinute,
    );
    return (start: start, end: start.add(const Duration(hours: 1)));
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _formatHour(DateTime value) {
    final hh = value.hour.toString().padLeft(2, '0');
    final mm = value.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _statusGroup(String status) {
    final normalized = _planningNormalizedStatus(status);
    switch (normalized) {
      case 'pendiente':
      case 'pending':
        return 'pendiente';
      case 'asignada':
      case 'asignado':
      case 'programada':
      case 'programado':
        return 'asignada';
      case 'iniciada':
      case 'iniciado':
      case 'iniciando':
      case 'en_proceso':
      case 'in_progress':
      case 'en_curso':
        return 'iniciada';
      case 'terminada':
      case 'terminado':
      case 'finalizada':
      case 'finalizado':
      case 'confirmada':
      case 'confirmed':
      case 'completada':
      case 'completed':
        return 'terminada';
      case 'cancelada':
      case 'cancelado':
      case 'rechazada':
      case 'rechazado':
        return 'cancelada';
      default:
        return 'otro';
    }
  }

  bool _matchesStatusFilters(AssignmentItem item) {
    if (_activeStatusFilters.isEmpty) return true;
    return _activeStatusFilters.contains(_statusGroup(_effectiveStatus(item)));
  }

  Color _filterColorForGroup(String group) {
    switch (group) {
      case 'pendiente':
        return _planningStatusColor('PENDIENTE');
      case 'asignada':
        return _planningStatusColor('PROGRAMADA');
      case 'iniciada':
        return _planningStatusColor('INICIADA');
      case 'terminada':
        return _planningStatusColor('FINALIZADA');
      default:
        return SaoColors.gray500;
    }
  }

  void _openGpsMapDialog(AssignmentItem item) {
    if (item.latitude == null || item.longitude == null) return;
    final point = LatLng(item.latitude!, item.longitude!);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.gps_fixed_rounded, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _displayActivityName(item),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_locationEstado(item)} / ${_locationMunicipio(item)}  •  PK ${_locationPk(item)}',
                style: const TextStyle(fontSize: 12, color: SaoColors.gray600),
              ),
              const SizedBox(height: 4),
              Text(
                'GPS: ${item.latitude!.toStringAsFixed(6)}, ${item.longitude!.toStringAsFixed(6)}',
                style: const TextStyle(fontSize: 11, color: SaoColors.gray500, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  height: 340,
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: point,
                      initialZoom: 14.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'mx.sao.desktop',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: point,
                            width: 40,
                            height: 40,
                            child: const Icon(
                              Icons.location_pin,
                              size: 40,
                              color: SaoColors.error,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _addQuickNote(AssignmentItem item) async {
    final controller = TextEditingController(text: _notesByAssignmentId[item.id] ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Incidencia rápida'),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: controller,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Nota operativa',
              hintText: 'Ej: Lluvia intensa en PK 0+123',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (saved != true) return;

    setState(() {
      final value = controller.text.trim();
      if (value.isEmpty) {
        _notesByAssignmentId.remove(item.id);
      } else {
        _notesByAssignmentId[item.id] = value;
      }
    });
  }

  void _handleAssignmentDeleted(String assignmentId) {
    setState(() {
      _dismissedAssignmentIds.add(assignmentId);
      _manualScheduleById.remove(assignmentId);
      _notesByAssignmentId.remove(assignmentId);
      _statusOverrideByAssignmentId.remove(assignmentId);
    });
    widget.onDeleted(assignmentId);
  }

  Future<void> _confirmDeleteAssignment(AssignmentItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar actividad'),
        content: Text(
          '¿Eliminar la actividad "${_displayActivityName(item)}" asignada a ${item.assigneeName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      const apiClient = BackendApiClient();
      try {
        await apiClient.deleteJson('/api/v1/activities/${item.id}');
      } catch (_) {
        const assignmentsRepo = AssignmentsRepository(BackendApiClient());
        await assignmentsRepo.cancelAssignment(item.id, reason: 'deleted_from_planning');
      }
      if (!mounted) return;
      _handleAssignmentDeleted(item.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Actividad eliminada correctamente.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo eliminar la actividad: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  ({int hour, int minute})? _parseHourMinute(String raw) {
    final compact = raw.trim();
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(compact);
    if (match == null) return null;
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return (hour: hour, minute: minute);
  }

  Future<void> _openAssignmentDetailsEditor(
    AssignmentItem item, {
    required DateTime currentStart,
    required DateTime currentEnd,
  }) async {
    final startController = TextEditingController(text: _formatHour(currentStart));
    final endController = TextEditingController(text: _formatHour(currentEnd));
    final noteController = TextEditingController(text: _notesByAssignmentId[item.id] ?? '');
    final estadoVal = _valueOrDash(_locationEstado(item));
    final municipioVal = _valueOrDash(_locationMunicipio(item));
    final pkVal = _locationPk(item);
    // Extraer coords GPS
    final mapPoint = (item.latitude != null && item.longitude != null)
        ? LatLng(item.latitude!, item.longitude!)
        : null;

    var deleteRequested = false;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.edit_rounded, size: 18),
            SizedBox(width: 8),
            Text(
              'Editar Actividad',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        content: SizedBox(
          width: 620,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info box with location, date, time
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: SaoColors.gray50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: SaoColors.gray200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 6,
                  children: [
                    // Status row
                    Row(
                      children: [
                        const Text(
                          'Estatus',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: SaoColors.gray600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusPill(label: _effectiveStatus(item)),
                      ],
                    ),
                    // Location rows with icons
                    Row(
                      children: [
                        const Icon(Icons.place_rounded, size: 14, color: SaoColors.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '$estadoVal  •  $municipioVal',
                            style: const TextStyle(fontSize: 12, color: SaoColors.gray700, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.straighten_rounded, size: 14, color: SaoColors.gray600),
                        const SizedBox(width: 6),
                        Text(
                          'PK: $pkVal',
                          style: const TextStyle(fontSize: 12, color: SaoColors.gray700),
                        ),
                      ],
                    ),
                    // Date row with icon
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 14, color: SaoColors.gray600),
                        const SizedBox(width: 6),
                        Text(
                          DateFormat('d \'de\' MMMM, yyyy', 'es').format(currentStart),
                          style: const TextStyle(fontSize: 12, color: SaoColors.gray700),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // Time inputs
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: startController,
                      decoration: const InputDecoration(
                        labelText: 'Hora inicio',
                        hintText: '08:00',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.schedule_rounded, size: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: endController,
                      decoration: const InputDecoration(
                        labelText: 'Hora fin',
                        hintText: '09:00',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.schedule_rounded, size: 14),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Notes field - expanded
              TextField(
                controller: noteController,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Nota / Incidencia',
                  hintText: 'Ej: Lluvia intensa, tráfico, detalle de lo encontrado...',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 14),
              // Map - always shown
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 220,
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: mapPoint ?? const LatLng(23.634, -102.552),
                      initialZoom: mapPoint != null ? 14.0 : 5.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'mx.sao.desktop',
                      ),
                      if (mapPoint != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: mapPoint,
                              width: 40,
                              height: 40,
                              child: const Icon(
                                Icons.location_pin,
                                size: 40,
                                color: SaoColors.error,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              if (mapPoint != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.gps_fixed_rounded, size: 12, color: SaoColors.gray500),
                      const SizedBox(width: 4),
                      Text(
                        '${mapPoint.latitude.toStringAsFixed(6)}, ${mapPoint.longitude.toStringAsFixed(6)}',
                        style: const TextStyle(fontSize: 10, color: SaoColors.gray500, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                )
              else
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'Sin ubicación GPS - se muestra región general',
                    style: TextStyle(fontSize: 10, color: SaoColors.gray500, fontStyle: FontStyle.italic),
                  ),
                ),
              const SizedBox(height: 14),
              // Action buttons - reorganized
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () {
                      deleteRequested = true;
                      Navigator.pop(ctx, false);
                    },
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    label: const Text('Eliminar'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cerrar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Guardar cambios'),
                  ),
                ],
              ),
            ],
          ),
        ),
        contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        actions: const [],
      ),
    );

    if (deleteRequested) {
      await _confirmDeleteAssignment(item);
      return;
    }

    if (saved != true) return;
    if (!mounted) return;

    final startParsed = _parseHourMinute(startController.text);
    final endParsed = _parseHourMinute(endController.text);
    if (startParsed == null || endParsed == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Captura horas válidas en formato HH:mm.')),
      );
      return;
    }

    final newStart = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
      startParsed.hour,
      startParsed.minute,
    );
    final newEnd = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
      endParsed.hour,
      endParsed.minute,
    );

    if (!newEnd.isAfter(newStart)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La hora fin debe ser mayor a hora inicio.')),
      );
      return;
    }

    setState(() {
      _manualScheduleById[item.id] = (start: newStart, end: newEnd);
      final note = noteController.text.trim();
      if (note.isEmpty) {
        _notesByAssignmentId.remove(item.id);
      } else {
        _notesByAssignmentId[item.id] = note;
      }
    });
  }

  String _formatPk(String raw) {
    final compact = raw.trim().replaceAll(' ', '');
    if (compact.isEmpty || compact == '—') return '—';

    final chainage = RegExp(r'^(\d+)\+(\d{1,3})$').firstMatch(compact);
    if (chainage != null) {
      final km = int.parse(chainage.group(1)!);
      final meters = chainage.group(2)!.padRight(3, '0');
      return '$km+$meters';
    }

    final chainageNoMeters = RegExp(r'^(\d+)\+$').firstMatch(compact);
    if (chainageNoMeters != null) {
      final km = int.parse(chainageNoMeters.group(1)!);
      return '$km+000';
    }

    final valueInMeters = int.tryParse(compact);
    if (valueInMeters != null) {
      final km = valueInMeters ~/ 1000;
      final meters = (valueInMeters % 1000).toString().padLeft(3, '0');
      return '$km+$meters';
    }

    return raw;
  }

  String _locationFront(AssignmentItem item) {
    final front = item.frontName.trim();
    if (front.isNotEmpty && front.toLowerCase() != 'sin frente') {
      return front;
    }

    final fromTitle = _extractTaggedValue(item.title, 'Frente');
    if (fromTitle.isNotEmpty && fromTitle.toLowerCase() != 'sin frente') {
      return fromTitle;
    }

    final fromFrontId = _frontOptions.where((option) => option.id == item.frontId).firstOrNull;
    if (fromFrontId != null) {
      return fromFrontId.name;
    }

    final pkMeters = _parsePkMeters(item.pk);
    if (pkMeters != null) {
      for (final option in _frontOptions) {
        final start = option.pkStart;
        final end = option.pkEnd;
        if (start == null || end == null) continue;
        if (pkMeters >= start && pkMeters <= end) {
          return option.name;
        }
      }
    }

    return 'Sin frente';
  }

  String _normalizeKey(String value) => value.trim().toLowerCase();

  List<AssignmentFrontCoverageOption> _coverageForItem(AssignmentItem item) {
    final keys = <String>{
      _normalizeKey(item.frontId),
      _normalizeKey(item.frontName),
      _normalizeKey(_locationFront(item)),
    }..remove('');

    final frontById =
        _frontOptions.where((option) => option.id == item.frontId).firstOrNull;
    if (frontById != null) {
      keys.add(_normalizeKey(frontById.code));
      keys.add(_normalizeKey(frontById.name));
    }

    for (final key in keys) {
      final coverage = _coverageByFront[key];
      if (coverage != null && coverage.isNotEmpty) {
        return coverage;
      }
    }
    return const [];
  }

  String _extractTaggedValue(String source, String label) {
    final match = RegExp('$label\\s*:\\s*([^·]+)', caseSensitive: false).firstMatch(source);
    if (match == null) return '';
    return (match.group(1) ?? '').trim();
  }

  String _locationEstado(AssignmentItem item) {
    final fromApi = item.estado.trim();
    if (fromApi.isNotEmpty) return fromApi;
    final fromTitle = _extractTaggedValue(item.title, 'Estado');
    if (fromTitle.isNotEmpty) return fromTitle;
    final coverage = _coverageForItem(item);
    if (coverage.isNotEmpty) return coverage.first.estado;
    return 'Sin estado';
  }

  String _locationMunicipio(AssignmentItem item) {
    final fromApi = item.municipio.trim();
    if (fromApi.isNotEmpty) return fromApi;
    final fromTitle = _extractTaggedValue(item.title, 'Municipio');
    if (fromTitle.isNotEmpty) return fromTitle;
    final coverage = _coverageForItem(item);
    if (coverage.isNotEmpty) return coverage.first.municipio;
    return 'Sin municipio';
  }

  String _displayActivityName(AssignmentItem item) {
    String normalizeActivityText(String input) {
      var value = input.trim();
      if (value.contains('·')) {
        final parts = value
            .split('·')
            .map((part) => part.trim())
            .where((part) => part.isNotEmpty)
            .toList();
        if (parts.length >= 2) {
          value = parts.last;
        }
      }
      return value
          .replaceAll('_', ' ')
          .replaceAll(RegExp(r'\s{2,}'), ' ')
          .trim();
    }

    String resolveActivityLabel(String input) {
      final normalized = normalizeActivityText(input);
      if (normalized.isEmpty) return '';

      switch (normalized.toLowerCase()) {
        case 'reu':
          return 'Reunion';
      }
      return normalized;
    }

    final taggedActividad = _extractTaggedValue(item.title, 'Actividad');
    if (taggedActividad.isNotEmpty) return resolveActivityLabel(taggedActividad);
    final taggedTipo = _extractTaggedValue(item.title, 'Tipo');
    if (taggedTipo.isNotEmpty) return resolveActivityLabel(taggedTipo);

    String activityTypeFallback() {
      final rawType = resolveActivityLabel(item.activityTypeName);
      if (rawType.isEmpty) return '';
      final lower = rawType.toLowerCase();
      if (lower == 'actividad') return '';
      return rawType;
    }

    final preferred = item.title.trim();
    final fallback = item.activityTypeName.trim();
    if (preferred.isEmpty && fallback.isEmpty) return 'Actividad operativa';

    String clean(String input) {
      final resolvedFront = _locationFront(item);
      final resolvedEstado = _locationEstado(item);
      final resolvedMunicipio = _locationMunicipio(item);
      var result = input
          .replaceAll(RegExp(r'estado/municipio\s*:\s*', caseSensitive: false), '')
          .replaceAll(RegExp(r'frente\s*:\s*', caseSensitive: false), '')
          .replaceAll(RegExp(r'estado\s*:\s*', caseSensitive: false), '')
          .replaceAll(RegExp(r'municipio\s*:\s*', caseSensitive: false), '')
          .replaceAll(RegExp(r'\bpk\s*\d+\+\d+\b', caseSensitive: false), '');

      void stripToken(String token) {
        final t = token.trim();
        if (t.isEmpty || t.toLowerCase().startsWith('sin ')) return;
        result = result.replaceAll(RegExp(RegExp.escape(t), caseSensitive: false), '');
      }

      stripToken(item.frontName);
      stripToken(item.estado);
      stripToken(item.municipio);
      stripToken(resolvedFront);
      stripToken(resolvedEstado);
      stripToken(resolvedMunicipio);

      return result
          .replaceAll(RegExp(r'\s*/\s*'), ' ')
          .replaceAll(RegExp(r'\s*·\s*'), ' ')
          .replaceAll(RegExp(r'\s*-\s*'), ' ')
          .replaceAll(RegExp(r'[\s,.-]+$'), '')
          .replaceAll(RegExp(r'^[\s,.-]+'), '')
          .replaceAll(RegExp(r'\s{2,}'), ' ')
          .trim();
    }

    bool looksLikeLocationText(String text) {
      final lower = text.toLowerCase();
      if (lower.contains('frente') || lower.contains('pk')) return true;
      final estado = _locationEstado(item).trim().toLowerCase();
      final municipio = _locationMunicipio(item).trim().toLowerCase();
      if (estado.isNotEmpty && !estado.startsWith('sin ') && lower.contains(estado)) {
        return true;
      }
      if (municipio.isNotEmpty && !municipio.startsWith('sin ') && lower.contains(municipio)) {
        return true;
      }
      return false;
    }

    final fromTitle = clean(preferred);
    if (fromTitle.length >= 3 && !looksLikeLocationText(fromTitle)) {
      return resolveActivityLabel(fromTitle);
    }

    final fromType = clean(fallback);
    if (fromType.length >= 3 && !looksLikeLocationText(fromType)) {
      return resolveActivityLabel(fromType);
    }

    final typeFallback = activityTypeFallback();
    if (typeFallback.isNotEmpty) return typeFallback;

    return 'Actividad';
  }

  String _locationPk(AssignmentItem item) {
    return _formatPk(item.pk);
  }

  /// Returns '—' when the value represents a missing/unknown location.
  String _valueOrDash(String value) {
    final lower = value.trim().toLowerCase();
    if (lower.isEmpty || lower.startsWith('sin ') || lower == '—') return '—';
    return value.trim();
  }

  /// Returns estado / municipio line, empty string when both are missing.
  String _initials(String fullName) {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'SR';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final activeAssignments = widget.assignments
        .where((item) => !_dismissedAssignmentIds.contains(item.id))
        .toList(growable: false);

    final rows = activeAssignments
        .where((item) => _matchesStatusFilters(item) && _matchesPkFilter(item))
        .map((item) {
          final schedule = _effectiveScheduleFor(item);
          return (item: item, start: schedule.start, end: schedule.end);
        })
        .where((row) => _sameDay(row.start, widget.selectedDate))
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    final visibleRows = rows.isNotEmpty
        ? rows
      : activeAssignments.map((item) {
            final schedule = _fallbackScheduleFor(item);
            return (item: item, start: schedule.start, end: schedule.end);
          }).toList()
          ..sort((a, b) => a.start.compareTo(b.start));

    final groupedByHour = <int, List<({AssignmentItem item, DateTime start, DateTime end})>>{};
    for (final row in visibleRows) {
      groupedByHour.putIfAbsent(row.start.hour, () => <({AssignmentItem item, DateTime start, DateTime end})>[]).add(row);
    }

    final hoursToRender = _showEmptySlots
        ? List<int>.generate(24, (index) => index)
        : (groupedByHour.keys.toList()..sort());

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.schedule_rounded, size: 18),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Detalle por hora (${DateFormat('d MMM yyyy', 'es').format(widget.selectedDate)})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${activeAssignments.length} actividades',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: SaoColors.gray600,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Exportar CSV',
                    onPressed: visibleRows.isEmpty
                        ? null
                        : () => _generateDailyReport(visibleRows),
                    icon: const Icon(Icons.download_rounded),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: const [
              ('pendiente', 'Pendiente'),
              ('asignada', 'Programada'),
              ('iniciada', 'Iniciada'),
              ('terminada', 'Finalizada'),
            ].map((entry) {
              return entry;
            }).toList().map((entry) {
              final key = entry.$1;
              final label = entry.$2;
              final selected = _activeStatusFilters.contains(key);
              final statusColor = _filterColorForGroup(key);
              return FilterChip(
                label: Text(label),
                selected: selected,
                showCheckmark: false,
                backgroundColor: Colors.white,
                selectedColor: statusColor,
                side: BorderSide(
                  color: selected
                      ? statusColor
                      : SaoColors.gray300,
                ),
                labelStyle: TextStyle(
                  fontSize: 12,
                  color: selected ? Colors.white : SaoColors.gray700,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
                onSelected: (value) {
                  setState(() {
                    if (value) {
                      _activeStatusFilters.add(key);
                    } else {
                      _activeStatusFilters.remove(key);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.hourglass_bottom_rounded, size: 16, color: SaoColors.gray500),
              const SizedBox(width: 6),
              const Text(
                'Mostrar huecos de agenda',
                style: TextStyle(fontSize: 12, color: SaoColors.gray600),
              ),
              const SizedBox(width: 6),
              Switch.adaptive(
                value: _showEmptySlots,
                onChanged: (value) => setState(() => _showEmptySlots = value),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: visibleRows.isEmpty
                ? const Center(
                    child: Text(
                      'Sin actividades en este dia',
                      style: TextStyle(color: SaoColors.gray500),
                    ),
                  )
                : ListView.builder(
                    itemCount: hoursToRender.length,
                    itemBuilder: (context, hourIndex) {
                      final hour = hoursToRender[hourIndex];
                      final slotRows = groupedByHour[hour] ?? const <({AssignmentItem item, DateTime start, DateTime end})>[];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: SaoColors.gray200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                              decoration: const BoxDecoration(
                                color: Color(0xFFF8F9FA),
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  topRight: Radius.circular(12),
                                ),
                                border: Border(
                                  bottom: BorderSide(color: SaoColors.gray200),
                                  left: BorderSide(color: SaoColors.primary, width: 3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    '${hour.toString().padLeft(2, '0')}:00',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: SaoColors.gray800,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  if (slotRows.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: SaoColors.primary.withValues(alpha: 0.10),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        '${slotRows.length} actividad${slotRows.length == 1 ? '' : 'es'}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: SaoColors.primary,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (slotRows.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.schedule_outlined,
                                      size: 14,
                                      color: SaoColors.gray400,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Bloque libre',
                                      style: TextStyle(fontSize: 12, color: SaoColors.gray400),
                                    ),
                                    const SizedBox(width: 10),
                                    TextButton.icon(
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      onPressed: () {},
                                      icon: const Icon(Icons.add_rounded, size: 14),
                                      label: const Text(
                                        'Añadir actividad',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              ...slotRows.map((row) {
                                final item = row.item;
                                final isHovered = _hoveredAssignmentId == item.id;
                                final hasNote = _notesByAssignmentId.containsKey(item.id);
                                final estadoVal = _valueOrDash(_locationEstado(item));
                                final municipioVal = _valueOrDash(_locationMunicipio(item));
                                final pkVal = _locationPk(item);
                                final showTime = row.start.minute != 0;

                                final cs = Theme.of(context).colorScheme;
                                return MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  onEnter: (_) => setState(() => _hoveredAssignmentId = item.id),
                                  onExit: (_) => setState(() => _hoveredAssignmentId = null),
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onDoubleTap: () => _openAssignmentDetailsEditor(
                                      item,
                                      currentStart: row.start,
                                      currentEnd: row.end,
                                    ),
                                    child: Container(
                                      margin: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isHovered
                                            ? Color.alphaBlend(cs.onSurface.withValues(alpha: 0.06), cs.surface)
                                            : cs.surface,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isHovered ? cs.outline : cs.outlineVariant,
                                        ),
                                      ),
                                      child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        // Col A – titulo actividad + hora opcional
                                        Expanded(
                                          flex: 3,
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      _displayActivityName(item),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        color: cs.onSurface,
                                                        fontWeight: FontWeight.w700,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                    if (showTime)
                                                      Text(
                                                        _formatHour(row.start),
                                                        style: TextStyle(
                                                          color: cs.onSurface.withValues(alpha: 0.5),
                                                          fontSize: 10.5,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        // Col B – estado y municipio
                                        Expanded(
                                          flex: 4,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.place_rounded,
                                                    size: 12,
                                                    color: cs.primary,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      '$estadoVal / $municipioVal',
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        color: cs.onSurface.withValues(alpha: 0.78),
                                                        fontSize: 11.3,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Text(
                                                'PK: $pkVal',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: cs.onSurface.withValues(alpha: 0.58),
                                                  fontSize: 10,
                                                  fontFeatures: const [
                                                    FontFeature.tabularFigures(),
                                                  ],
                                                ),
                                              ),
                                              if (item.latitude != null && item.longitude != null)
                                                GestureDetector(
                                                  onTap: () => _openGpsMapDialog(item),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.gps_fixed_rounded, size: 11, color: cs.primary),
                                                      const SizedBox(width: 3),
                                                      Text(
                                                        '${item.latitude!.toStringAsFixed(4)}, ${item.longitude!.toStringAsFixed(4)}',
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          color: cs.primary,
                                                          fontFeatures: const [FontFeature.tabularFigures()],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        // Col C – responsable
                                        Expanded(
                                          flex: 3,
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            children: [
                                              CircleAvatar(
                                                radius: 11,
                                                backgroundColor: cs.primary
                                                    .withValues(alpha: 0.12),
                                                child: Text(
                                                  _initials(item.assigneeName),
                                                  style: TextStyle(
                                                    color: cs.primary,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  item.assigneeName,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: cs.onSurface.withValues(alpha: 0.7),
                                                    fontSize: 11.5,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // Col D – estado (pill)
                                        SizedBox(
                                          width: 110,
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: _StatusPill(
                                              label: _effectiveStatus(item),
                                            ),
                                          ),
                                        ),
                                          // Nota + acciones (extremo derecho)
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              iconSize: 15,
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints.tightFor(
                                                width: 28,
                                                height: 28,
                                              ),
                                              visualDensity: VisualDensity.compact,
                                              tooltip: hasNote ? 'Ver nota' : 'Añadir nota',
                                              onPressed: () => _addQuickNote(item),
                                              icon: Icon(
                                                hasNote
                                                    ? Icons.comment_rounded
                                                    : Icons.comment_outlined,
                                                color: hasNote
                                                    ? SaoColors.statusEnCampo
                                                    : SaoColors.gray400,
                                              ),
                                            ),
                                            PopupMenuButton<String>(
                                              tooltip: 'Acciones',
                                              onSelected: (value) {
                                                if (value == 'RESCHEDULE') {
                                                  _openAssignmentDetailsEditor(
                                                    item,
                                                    currentStart: row.start,
                                                    currentEnd: row.end,
                                                  );
                                                  return;
                                                }
                                                if (value == 'CANCELADA') {
                                                  _updateStatus(item, 'CANCELADA');
                                                  return;
                                                }
                                                if (value == 'DELETE') {
                                                  _confirmDeleteAssignment(item);
                                                  return;
                                                }
                                              },
                                              itemBuilder: (context) => const [
                                                PopupMenuItem<String>(
                                                  value: 'RESCHEDULE',
                                                  child: Text('Reprogramar'),
                                                ),
                                                PopupMenuDivider(),
                                                PopupMenuItem<String>(
                                                  value: 'CANCELADA',
                                                  child: Text('Cancelada'),
                                                ),
                                                PopupMenuDivider(),
                                                PopupMenuItem<String>(
                                                  value: 'DELETE',
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        Icons.delete_outline_rounded,
                                                        size: 16,
                                                        color: Colors.red,
                                                      ),
                                                      SizedBox(width: 8),
                                                      Text(
                                                        'Eliminar',
                                                        style: TextStyle(color: Colors.red),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                              icon: Icon(
                                                Icons.more_horiz_rounded,
                                                color: cs.onSurface.withValues(alpha: 0.5),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  ),
                                );
                              }),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
