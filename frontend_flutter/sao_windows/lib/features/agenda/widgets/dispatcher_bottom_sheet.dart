// lib/features/agenda/widgets/dispatcher_bottom_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../ui/theme/sao_colors.dart';
import '../../../ui/theme/sao_typography.dart';
import '../../../core/di/service_locator.dart';
import '../../../data/local/app_db.dart';
import '../../../data/local/dao/activity_dao.dart';
import '../../catalog/catalog_repository.dart';
import '../data/agenda_assignment_factory.dart';
import '../data/effective_catalog_version_resolver.dart';
import '../models/agenda_item.dart';
import '../models/resource.dart';

class DispatcherBottomSheet extends StatefulWidget {
  final List<Resource> resources;
  final List<AgendaItem> existingItems;
  final DateTime selectedDay;
  final String? projectId;
  final ValueChanged<AgendaItem> onCreate;

  const DispatcherBottomSheet({
    super.key,
    required this.resources,
    required this.existingItems,
    required this.selectedDay,
    this.projectId,
    required this.onCreate,
  });

  @override
  State<DispatcherBottomSheet> createState() => _DispatcherBottomSheetState();
}

class _DispatcherBottomSheetState extends State<DispatcherBottomSheet> {
  final ActivityDao _activityDao = ActivityDao(getIt<AppDb>());
  final CatalogRepository _catalogRepo = CatalogRepository();
  final AgendaAssignmentFactory _assignmentFactory = AgendaAssignmentFactory();
  final EffectiveCatalogVersionResolver _versionResolver =
      const EffectiveCatalogVersionResolver();

  int _currentStep = 0;
  String? _selectedResourceId;
  CatItem? _selectedActivity;
  RiskLevel? _selectedRisk;
  String _pk = '';
  DateTime? _startTime;
  DateTime? _endTime;

  List<CatItem> _activities = const [];
  List<String> _riskOptions = const [];
  bool _loadingActivities = true;
  String? _activitiesError;

  List<FrontOption> _frontOptions = const [];
  FrontOption? _selectedFront;
  bool _loadingFronts = true;
  String? _frontsError;
  String _frontFreeText = '';

  List<ProjectOption> _projectOptions = const [];
  ProjectOption? _selectedProject;
  bool _loadingProjects = true;
  String? _projectsError;

  final _pkController = TextEditingController();
  final _frontController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadWizardCatalogOptions();
    _loadProjectsAndFronts();
  }

  @override
  void dispose() {
    _pkController.dispose();
    _frontController.dispose();
    super.dispose();
  }

  Future<void> _loadWizardCatalogOptions() async {
    setState(() {
      _loadingActivities = true;
      _activitiesError = null;
    });

    try {
      await _catalogRepo.init();
      final activities = _catalogRepo.activities;
      final risks = _catalogRepo.matrizRiesgo
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList();

      if (!mounted) return;
      setState(() {
        _activities = activities;
        _riskOptions = risks;
        _loadingActivities = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingActivities = false;
        _activitiesError =
            'No se pudieron cargar actividades/riesgo desde catálogo del wizard.';
      });
    }
  }

  Future<void> _loadProjectsAndFronts() async {
    setState(() {
      _loadingProjects = true;
      _projectsError = null;
    });

    try {
      final rows = await _activityDao.listActiveProjects();
      final projects = rows
          .map((project) => ProjectOption(id: project.id, code: project.code, name: project.name))
          .toList()
        ..sort((a, b) => a.code.toLowerCase().compareTo(b.code.toLowerCase()));

      ProjectOption? selected;
      final incomingProject = widget.projectId?.trim();
      if (incomingProject != null && incomingProject.isNotEmpty) {
        for (final item in projects) {
          if (item.id == incomingProject || item.code == incomingProject) {
            selected = item;
            break;
          }
        }
      }
      selected ??= projects.isNotEmpty
          ? projects.first
          : (incomingProject != null && incomingProject.isNotEmpty
              ? ProjectOption(id: incomingProject, code: incomingProject, name: incomingProject)
              : null);

      if (!mounted) return;
      setState(() {
        _projectOptions = projects;
        _selectedProject = selected;
        _loadingProjects = false;
      });
    } catch (_) {
      final incomingProject = widget.projectId?.trim();
      if (!mounted) return;
      setState(() {
        _loadingProjects = false;
        _projectsError = 'No se pudieron cargar los proyectos activos.';
        if (incomingProject != null && incomingProject.isNotEmpty) {
          _selectedProject = ProjectOption(
            id: incomingProject,
            code: incomingProject,
            name: incomingProject,
          );
        }
      });
    }

    await _loadProjectFronts();
  }

  Future<void> _loadProjectFronts() async {
    final projectId = _selectedProject?.id.trim();
    if (projectId == null || projectId.isEmpty) {
      setState(() {
        _loadingFronts = false;
        _frontsError = 'No hay proyecto seleccionado para cargar frentes.';
        _frontOptions = const [];
        _selectedFront = null;
      });
      return;
    }

    setState(() {
      _loadingFronts = true;
      _frontsError = null;
    });

    try {
      final rows = await _activityDao.listActiveSegmentsByProject(projectId);
      final fronts = rows
          .map((segment) => FrontOption(id: segment.id, name: segment.segmentName))
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      if (!mounted) return;
      setState(() {
        _frontOptions = fronts;
        _selectedFront = fronts.isNotEmpty ? fronts.first : null;
        _frontFreeText = '';
        _frontController.text = '';
        _loadingFronts = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _frontsError = 'No se pudieron cargar los frentes del proyecto.';
        _frontOptions = const [];
        _selectedFront = null;
        _loadingFronts = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: SaoColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              _buildHeader(),
              const Divider(height: 0),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  child: _buildStepContent(),
                ),
              ),
              _buildFooter(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: SaoColors.gray300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                'Despachador',
                style: SaoTypography.pageTitle,
              ),
              const Spacer(),
              _StepIndicator(current: _currentStep, total: 3),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep1();
      case 1:
        return _buildStep2();
      case 2:
        return _buildStep3();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '¿A quién asignar?',
          style: SaoTypography.cardTitle,
        ),
        const SizedBox(height: 16),
        if (widget.resources.where((r) => r.isActive).isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: SaoColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: SaoColors.error.withValues(alpha: 0.25)),
            ),
            child: const Text(
              'No hay recursos operativos disponibles para asignación.',
              style: TextStyle(color: SaoColors.error, fontWeight: FontWeight.w600),
            ),
          )
        else
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: widget.resources
              .where((r) => r.isActive)
              .map((r) {
                final selected = _selectedResourceId == r.id;
                final hasConflict = _checkConflict(r.id, null, null);

                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedResourceId = r.id);
                  },
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: hasConflict != null
                                ? SaoColors.error
                                : selected
                                    ? SaoColors.actionPrimary
                                    : SaoColors.border,
                            width: selected ? 3 : 2,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 32,
                          backgroundColor: SaoColors.info,
                          backgroundImage: r.avatarUrl != null
                              ? NetworkImage(r.avatarUrl!)
                              : null,
                          child: r.avatarUrl == null
                              ? Text(
                                  r.initials,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: SaoColors.onPrimary,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: 74,
                        child: Text(
                          r.name.split(' ').first,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                            color: selected
                                ? SaoColors.actionPrimary
                                : SaoColors.primaryLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              })
              .toList(),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '¿Qué y dónde?',
          style: SaoTypography.cardTitle,
        ),
        const SizedBox(height: 16),
        if (_loadingActivities)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (_activitiesError != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: SaoColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: SaoColors.error.withValues(alpha: 0.25)),
            ),
            child: Text(
              _activitiesError!,
              style: const TextStyle(
                color: SaoColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else if (_activities.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: SaoColors.alertBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: SaoColors.alertBorder),
            ),
            child: const Text(
              'No hay actividades habilitadas en el catálogo efectivo.',
              style: TextStyle(
                color: SaoColors.alertText,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else
          DropdownButtonFormField<CatItem>(
            initialValue: _selectedActivity,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Actividad',
              border: OutlineInputBorder(),
            ),
            items: _activities
                .map(
                  (activity) => DropdownMenuItem<CatItem>(
                    value: activity,
                    child: Text(
                      activity.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                _selectedActivity = value;
              });
            },
          ),
        const SizedBox(height: 12),
        if (_loadingProjects)
          const LinearProgressIndicator(minHeight: 2)
        else if (_projectsError != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: SaoColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: SaoColors.error.withValues(alpha: 0.25)),
            ),
            child: Text(
              _projectsError!,
              style: const TextStyle(
                color: SaoColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else
          DropdownButtonFormField<ProjectOption>(
            initialValue: _selectedProject,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Proyecto',
              border: OutlineInputBorder(),
            ),
            items: _projectOptions
                .map(
                  (project) => DropdownMenuItem<ProjectOption>(
                    value: project,
                    child: Text(
                      '${project.code} - ${project.name}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) async {
              if (value == null) return;
              setState(() {
                _selectedProject = value;
                _loadingFronts = true;
                _frontsError = null;
                _frontOptions = const [];
                _selectedFront = null;
              });
              await _loadProjectFronts();
            },
          ),
        const SizedBox(height: 12),
        if (_loadingFronts)
          const LinearProgressIndicator(minHeight: 2)
        else if (_frontsError != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: SaoColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: SaoColors.error.withValues(alpha: 0.25)),
            ),
            child: Text(
              _frontsError!,
              style: const TextStyle(
                color: SaoColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else if (_frontOptions.isNotEmpty)
          DropdownButtonFormField<FrontOption>(
            initialValue: _selectedFront,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Frente',
              border: OutlineInputBorder(),
            ),
            items: _frontOptions
                .map(
                  (front) => DropdownMenuItem<FrontOption>(
                    value: front,
                    child: Text(
                      front.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                _selectedFront = value;
              });
            },
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _frontController,
                onChanged: (value) {
                  setState(() {
                    _frontFreeText = value;
                  });
                },
                decoration: const InputDecoration(
                  labelText: 'Frente',
                  hintText: 'Captura el frente',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'TODO: conectar selector de frentes desde catálogo real cuando el backend lo exponga.',
                style: SaoTypography.caption,
              ),
            ],
          ),
        const SizedBox(height: 12),
        TextField(
          controller: _pkController,
          onChanged: (v) => setState(() => _pk = v),
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'PK',
            border: OutlineInputBorder(),
            hintText: 'Ej: 142000',
          ),
        ),
        const SizedBox(height: 16),
        if (_riskOptions.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: SaoColors.alertBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: SaoColors.alertBorder),
            ),
            child: const Text(
              'No hay niveles de riesgo en catálogo del wizard.',
              style: TextStyle(
                color: SaoColors.alertText,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _riskOptions.map((label) {
              final parsed = _riskFromCatalogText(label);
              final selected = parsed != null && _selectedRisk == parsed;
              if (parsed == null) {
                return Chip(
                  label: Text(label),
                  backgroundColor: SaoColors.gray100,
                );
              }
              return _riskChip(
                label: label,
                color: _riskColor(parsed),
                selected: selected,
                onTap: () {
                  setState(() {
                    _selectedRisk = parsed;
                  });
                },
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildStep3() {
    final conflict = _checkConflict(_selectedResourceId, _startTime, _endTime);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '¿Cuándo?',
          style: SaoTypography.cardTitle,
        ),
        const SizedBox(height: 16),
        _TimePickerButton(
          label: 'Hora de inicio',
          time: _startTime,
          onTap: () => _pickTime(true),
        ),
        const SizedBox(height: 12),
        _TimePickerButton(
          label: 'Hora de fin',
          time: _endTime,
          onTap: () => _pickTime(false),
        ),
        const SizedBox(height: 16),
        const Text(
          'Duración sugerida',
          style: SaoTypography.bodyTextBold,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _DurationChip(label: '30 min', onTap: () => _setDuration(30)),
            const SizedBox(width: 8),
            _DurationChip(label: '1 hora', onTap: () => _setDuration(60)),
            const SizedBox(width: 8),
            _DurationChip(label: '2 horas', onTap: () => _setDuration(120)),
          ],
        ),
        if (conflict != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: SaoColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: SaoColors.error.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.warning_rounded,
                      color: SaoColors.error,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        conflict,
                        style: SaoTypography.bodyTextBold.copyWith(color: SaoColors.error),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _findNextFreeSlot,
                  icon: const Icon(Icons.search_rounded, size: 16),
                  label: const Text('Buscar hueco libre'),
                  style: TextButton.styleFrom(
                    foregroundColor: SaoColors.actionPrimary,
                    backgroundColor: SaoColors.surface,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFooter() {
    final canProceed = _canProceedToNextStep();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: const BoxDecoration(
        color: SaoColors.surface,
        border: Border(top: BorderSide(color: SaoColors.border)),
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _currentStep--),
                child: const Text('Atrás'),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: canProceed ? _handleNext : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: SaoColors.actionPrimary,
                disabledBackgroundColor: SaoColors.border,
                foregroundColor: SaoColors.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                _currentStep == 2 ? 'Crear Tarea' : 'Siguiente',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _canProceedToNextStep() {
    switch (_currentStep) {
      case 0:
        return _selectedResourceId != null;
      case 1:
        final hasProject = _selectedProject != null;
        final hasFront = _frontOptions.isEmpty
            ? _frontFreeText.trim().isNotEmpty
            : _selectedFront != null;
        return hasProject &&
          _selectedActivity != null &&
          _selectedRisk != null &&
          _pk.isNotEmpty &&
          hasFront;
      case 2:
        return _startTime != null && _endTime != null;
      default:
        return false;
    }
  }

  Future<void> _handleNext() async {
    if (_currentStep < 2) {
      setState(() => _currentStep++);
    } else {
      await _createItem();
    }
  }

  void _pickTime(bool isStart) async {
    final now = TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart
          ? (_startTime != null
              ? TimeOfDay(hour: _startTime!.hour, minute: _startTime!.minute)
              : now)
          : (_endTime != null
              ? TimeOfDay(hour: _endTime!.hour, minute: _endTime!.minute)
              : TimeOfDay(hour: now.hour + 1, minute: 0)),
    );
    if (picked != null) {
      setState(() {
        final dt = DateTime(
          widget.selectedDay.year,
          widget.selectedDay.month,
          widget.selectedDay.day,
          picked.hour,
          picked.minute,
        );
        if (isStart) {
          _startTime = dt;
        } else {
          _endTime = dt;
        }
      });
    }
  }

  void _setDuration(int minutes) {
    if (_startTime != null) {
      setState(() {
        _endTime = _startTime!.add(Duration(minutes: minutes));
      });
    }
  }

  String? _checkConflict(String? resourceId, DateTime? start, DateTime? end) {
    if (resourceId == null || start == null || end == null) return null;

    final conflicts = widget.existingItems.where((it) {
      return it.resourceId == resourceId && it.overlaps(start, end);
    }).toList();

    if (conflicts.isEmpty) return null;

    final c = conflicts.first;
    final endTime = '${c.end.hour.toString().padLeft(2, '0')}:${c.end.minute.toString().padLeft(2, '0')}';
    final resource = widget.resources.firstWhere(
      (r) => r.id == resourceId,
      orElse: () => const Resource(
        id: 'unknown',
        name: 'Desconocido',
        role: ResourceRole.tecnico,
        isActive: true,
      ),
    );

    return '${resource.name.split(' ').first} está ocupado hasta las $endTime';
  }

  void _findNextFreeSlot() {
    if (_selectedResourceId == null || _startTime == null || _endTime == null) {
      return;
    }

    final duration = _endTime!.difference(_startTime!);
    var candidate = _endTime!;

    // Redondear a la siguiente media hora
    final mins = candidate.minute;
    if (mins > 0 && mins < 30) {
      candidate = candidate.add(Duration(minutes: 30 - mins));
    } else if (mins > 30) {
      candidate = candidate.add(Duration(minutes: 60 - mins));
    }

    // Buscar el siguiente hueco de 30 min
    for (int i = 0; i < 24; i++) {
      final testStart = candidate.add(Duration(minutes: i * 30));
      final testEnd = testStart.add(duration);

      final hasConflict = widget.existingItems.any((it) {
        return it.resourceId == _selectedResourceId &&
            it.overlaps(testStart, testEnd);
      });

      if (!hasConflict) {
        setState(() {
          _startTime = testStart;
          _endTime = testEnd;
        });
        HapticFeedback.mediumImpact();
        return;
      }
    }
  }

  Future<void> _createItem() async {
    if (_selectedResourceId == null ||
        _selectedActivity == null ||
        _startTime == null ||
        _endTime == null) {
      return;
    }

    final effectiveVersionId = await _versionResolver.resolve(
      projectId: _selectedProject?.id,
      fallbackVersionId: null,
    );

    final selectedActivity = _selectedActivity;
    if (selectedActivity == null) return;
    final projectCode = (_selectedProject?.id ?? widget.projectId ?? '').trim();
    final frontName = (_selectedFront?.name ?? _frontFreeText).trim();

    final item = _assignmentFactory.build(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      resourceId: _selectedResourceId!,
      activity: EffectiveActivityInput(
        id: selectedActivity.id,
        name: selectedActivity.name,
        colorHex: null,
        severity: null,
      ),
      projectCode: projectCode,
      frente: frontName,
      start: _startTime!,
      end: _endTime!,
      pk: _pk.isNotEmpty ? int.tryParse(_pk) : null,
      risk: _selectedRisk!,
      effectiveVersionId: effectiveVersionId,
      municipio: null,
      estado: null,
    );

    widget.onCreate(item);
    if (!mounted) return;
    Navigator.pop(context);
  }

  RiskLevel? _riskFromCatalogText(String label) {
    final normalized = label.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    if (normalized.contains('prior')) return RiskLevel.prioritario;
    if (normalized.contains('alto') || normalized.contains('high')) return RiskLevel.alto;
    if (normalized.contains('medio') || normalized.contains('med')) return RiskLevel.medio;
    if (normalized.contains('bajo') || normalized.contains('low')) return RiskLevel.bajo;
    return null;
  }

  Color _riskColor(RiskLevel level) {
    switch (level) {
      case RiskLevel.bajo:
        return SaoColors.riskLow;
      case RiskLevel.medio:
        return SaoColors.riskMedium;
      case RiskLevel.alto:
        return SaoColors.riskHigh;
      case RiskLevel.prioritario:
        return SaoColors.riskPriority;
    }
  }

  Widget _riskChip({
    required String label,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : SaoColors.gray50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? color : SaoColors.gray300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: SaoTypography.caption.copyWith(
                fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                color: selected ? color : SaoColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int current;
  final int total;

  const _StepIndicator({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        total,
        (i) => Container(
          margin: EdgeInsets.only(left: i > 0 ? 4 : 0),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i <= current
                ? SaoColors.actionPrimary
                : SaoColors.gray300,
          ),
        ),
      ),
    );
  }
}

class _TimePickerButton extends StatelessWidget {
  final String label;
  final DateTime? time;
  final VoidCallback onTap;

  const _TimePickerButton({
    required this.label,
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: SaoColors.gray300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.schedule_rounded, color: SaoColors.gray500),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: SaoTypography.caption,
                ),
                Text(
                  time != null
                      ? '${time!.hour.toString().padLeft(2, '0')}:${time!.minute.toString().padLeft(2, '0')}'
                      : '--:--',
                  style: SaoTypography.bodyTextBold.copyWith(color: SaoColors.primary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DurationChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _DurationChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 10),
        ),
        child: Text(label),
      ),
    );
  }
}

class FrontOption {
  final String id;
  final String name;

  const FrontOption({
    required this.id,
    required this.name,
  });
}

class ProjectOption {
  final String id;
  final String code;
  final String name;

  const ProjectOption({
    required this.id,
    required this.code,
    required this.name,
  });
}
