import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers/project_providers.dart';
import '../../data/repositories/assignments_repository.dart';
import '../../ui/theme/sao_colors.dart';
import 'planning_provider.dart';

class PlanningPage extends ConsumerWidget {
  const PlanningPage({super.key});

  static const List<String> _fallbackProjects = ['TMQ', 'TAP'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignmentsAsync = ref.watch(planningAssignmentsProvider);
    final selectedDate = ref.watch(selectedPlanningDateProvider);
    final selectedProject = ref.watch(activeProjectIdProvider);
    final projectsAsync = ref.watch(availableProjectsProvider);
    final dateLabel = DateFormat('EEEE, d MMM yyyy', 'es').format(selectedDate);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Toolbar
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Planeación del Día',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  Text(dateLabel,
                      style: const TextStyle(fontSize: 13, color: SaoColors.gray500)),
                ],
              ),
              const Spacer(),
              // Project selector — loaded from backend
              SizedBox(
                width: 140,
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
                      ref.read(activeProjectIdProvider.notifier).state = project;
                    },
                  ),
                  data: (projects) {
                    final options = projects.isEmpty ? _fallbackProjects : projects;
                    if (selectedProject.isEmpty && options.isNotEmpty) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        ref.read(activeProjectIdProvider.notifier).state =
                            options.first;
                      });
                    }
                    return _ProjectDropdown(
                      projects: options,
                      selectedProject: selectedProject,
                      onSelected: (project) {
                        ref.read(activeProjectIdProvider.notifier).state = project;
                      },
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Date picker
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2024),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    ref.read(selectedPlanningDateProvider.notifier).state = picked;
                  }
                },
                icon: const Icon(Icons.calendar_today_rounded, size: 16),
                label: const Text('Fecha'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: selectedProject.isEmpty
                    ? null
                    : () async {
                        final created = await showDialog<bool>(
                          context: context,
                          builder: (_) => _CreateAssignmentDialog(
                            projectId: selectedProject,
                            selectedDate: selectedDate,
                          ),
                        );
                        if (created == true && context.mounted) {
                          ref.invalidate(planningAssignmentsProvider);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Asignación creada')),
                          );
                        }
                      },
                icon: const Icon(Icons.add_task_rounded, size: 16),
                label: const Text('Asignar actividad'),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Refrescar',
                onPressed: () => ref.invalidate(planningAssignmentsProvider),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Content
          Expanded(
            child: assignmentsAsync.when(
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
                if (assignments.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.event_available_rounded,
                            size: 56, color: SaoColors.gray400),
                        const SizedBox(height: 12),
                        Text(
                          'Sin asignaciones para $dateLabel',
                          style: const TextStyle(
                              fontSize: 16, color: SaoColors.gray500),
                        ),
                      ],
                    ),
                  );
                }

                return Card(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Hora')),
                        DataColumn(label: Text('Actividad')),
                        DataColumn(label: Text('PK')),
                        DataColumn(label: Text('Frente')),
                        DataColumn(label: Text('Responsable')),
                        DataColumn(label: Text('Estado')),
                      ],
                      rows: assignments
                          .map(
                            (item) => DataRow(cells: [
                              DataCell(Text(_formatTime(item.scheduledTime))),
                              DataCell(Text(item.activityTypeName)),
                              DataCell(Text(item.pk)),
                              DataCell(Text(item.frontName)),
                              DataCell(Text(item.assigneeName)),
                              DataCell(_StatusPill(label: item.status)),
                            ]),
                          )
                          .toList(),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String raw) {
    if (raw.isEmpty) return '—';
    // If it's an ISO datetime, extract the time portion
    if (raw.contains('T')) {
      final parts = raw.split('T');
      if (parts.length >= 2) {
        return parts[1].substring(0, 5); // HH:MM
      }
    }
    return raw.length > 5 ? raw.substring(0, 5) : raw;
  }
}

class _CreateAssignmentDialog extends ConsumerStatefulWidget {
  final String projectId;
  final DateTime selectedDate;

  const _CreateAssignmentDialog({
    required this.projectId,
    required this.selectedDate,
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
  final _titleController = TextEditingController();
  final _pkController = TextEditingController(text: '0');
  final _startController = TextEditingController(text: '08:00');
  final _endController = TextEditingController(text: '09:00');

  List<AssignmentAssigneeOption> _assignees = const [];
  List<AssignmentFrontOption> _fronts = const [];
  List<AssignmentActivityTypeOption> _activityTypes = const [];

  String? _assigneeId;
  String? _frontId;
  String? _activityTypeCode;
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _pkController.dispose();
    _startController.dispose();
    _endController.dispose();
    super.dispose();
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
      ]);
      if (!mounted) return;
      _assignees = results[0] as List<AssignmentAssigneeOption>;
      _fronts = results[1] as List<AssignmentFrontOption>;
      _activityTypes = results[2] as List<AssignmentActivityTypeOption>;
      _assigneeId = _assignees.isNotEmpty ? _assignees.first.userId : null;
      _frontId = _fronts.isNotEmpty ? _fronts.first.id : null;
      _activityTypeCode =
          _activityTypes.isNotEmpty ? _activityTypes.first.code : null;
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
      final repo = ref.read(assignmentsRepositoryProvider);
      await repo.createAssignment(
        projectId: widget.projectId,
        assigneeUserId: _assigneeId!,
        activityTypeCode: _activityTypeCode!,
        startAt: startAt,
        endAt: endAt,
        title: _titleController.text.trim().isEmpty
            ? null
            : _titleController.text.trim(),
        frontId: _frontId,
        pk: int.tryParse(_pkController.text.trim()) ?? 0,
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
    return AlertDialog(
      title: const Text('Asignar actividad'),
      content: SizedBox(
        width: 480,
        child: _loading
            ? const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_error != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(_error!,
                            style: const TextStyle(color: Colors.red)),
                      ),
                      const SizedBox(height: 10),
                    ],
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
                      onChanged: _submitting
                          ? null
                          : (value) => setState(() => _assigneeId = value),
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
                              child: Text(item.label),
                            ),
                          )
                          .toList(),
                      onChanged: _submitting
                          ? null
                          : (value) => setState(() => _frontId = value),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _titleController,
                      enabled: !_submitting,
                      decoration: const InputDecoration(
                        labelText: 'Título (opcional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _pkController,
                            enabled: !_submitting,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'PK',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _startController,
                            enabled: !_submitting,
                            decoration: const InputDecoration(
                              labelText: 'Inicio (HH:MM)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _endController,
                            enabled: !_submitting,
                            decoration: const InputDecoration(
                              labelText: 'Fin (HH:MM)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _loading || _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;

  const _StatusPill({required this.label});

  @override
  Widget build(BuildContext context) {
    final color = switch (label.toUpperCase()) {
      'CONFIRMADA' || 'CONFIRMED' => SaoColors.success,
      'PENDIENTE' || 'PENDING' || 'PROGRAMADA' => SaoColors.info,
      _ => SaoColors.warning,
    };
    final display = switch (label.toUpperCase()) {
      'CONFIRMADA' || 'CONFIRMED' => 'Confirmada',
      'PENDIENTE' || 'PENDING' => 'Pendiente',
      'PROGRAMADA' => 'Programada',
      _ => label,
    };

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
