// lib/features/agenda/widgets/dispatcher_bottom_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/agenda_item.dart';
import '../models/resource.dart';

class DispatcherBottomSheet extends StatefulWidget {
  final List<Resource> resources;
  final List<AgendaItem> existingItems;
  final DateTime selectedDay;
  final ValueChanged<AgendaItem> onCreate;

  const DispatcherBottomSheet({
    super.key,
    required this.resources,
    required this.existingItems,
    required this.selectedDay,
    required this.onCreate,
  });

  @override
  State<DispatcherBottomSheet> createState() => _DispatcherBottomSheetState();
}

class _DispatcherBottomSheetState extends State<DispatcherBottomSheet> {
  int _currentStep = 0;
  String? _selectedResourceId;
  String _title = '';
  String _pk = '';
  DateTime? _startTime;
  DateTime? _endTime;
  RiskLevel _riskLevel = RiskLevel.bajo;

  final _titleController = TextEditingController();
  final _pkController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _pkController.dispose();
    super.dispose();
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
            color: Colors.white,
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
              color: const Color(0xFFD1D5DB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                'Despachador',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
                ),
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
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 16),
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
                                ? const Color(0xFFEF4444)
                                : selected
                                    ? const Color(0xFF1E40AF)
                                    : const Color(0xFFE5E7EB),
                            width: selected ? 3 : 2,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 32,
                          backgroundColor: const Color(0xFF3B82F6),
                          backgroundImage: r.avatarUrl != null
                              ? NetworkImage(r.avatarUrl!)
                              : null,
                          child: r.avatarUrl == null
                              ? Text(
                                  r.initials,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
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
                            fontSize: 12,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                            color: selected
                                ? const Color(0xFF1E40AF)
                                : const Color(0xFF374151),
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
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _titleController,
          onChanged: (v) => setState(() => _title = v),
          decoration: const InputDecoration(
            labelText: 'Actividad',
            border: OutlineInputBorder(),
          ),
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
        const Text(
          'Nivel de riesgo',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _RiskChip(
                label: 'Bajo',
                color: const Color(0xFF10B981),
                selected: _riskLevel == RiskLevel.bajo,
                onTap: () => setState(() => _riskLevel = RiskLevel.bajo),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _RiskChip(
                label: 'Medio',
                color: const Color(0xFFFBBF24),
                selected: _riskLevel == RiskLevel.medio,
                onTap: () => setState(() => _riskLevel = RiskLevel.medio),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _RiskChip(
                label: 'Alto',
                color: const Color(0xFFF97316),
                selected: _riskLevel == RiskLevel.alto,
                onTap: () => setState(() => _riskLevel = RiskLevel.alto),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _RiskChip(
                label: 'Prioritario',
                color: const Color(0xFFEF4444),
                selected: _riskLevel == RiskLevel.prioritario,
                onTap: () => setState(() => _riskLevel = RiskLevel.prioritario),
              ),
            ),
          ],
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
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: Color(0xFF111827),
          ),
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
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF374151),
          ),
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
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.warning_rounded,
                      color: Color(0xFFEF4444),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        conflict,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF991B1B),
                        ),
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
                    foregroundColor: const Color(0xFF1E40AF),
                    backgroundColor: Colors.white,
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
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
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
                backgroundColor: const Color(0xFF691C32),
                disabledBackgroundColor: const Color(0xFFE5E7EB),
                foregroundColor: Colors.white,
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
        return _title.isNotEmpty && _pk.isNotEmpty;
      case 2:
        return _startTime != null && _endTime != null;
      default:
        return false;
    }
  }

  void _handleNext() {
    if (_currentStep < 2) {
      setState(() => _currentStep++);
    } else {
      _createItem();
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

  void _createItem() {
    if (_selectedResourceId == null ||
        _startTime == null ||
        _endTime == null) {
      return;
    }

    final item = AgendaItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      resourceId: _selectedResourceId!,
      title: _title,
      projectCode: 'P-001',
      frente: 'Frente 1',
      municipio: 'Municipio',
      estado: 'Estado',
      pk: _pk.isNotEmpty ? int.tryParse(_pk) : null,
      start: _startTime!,
      end: _endTime!,
      risk: _riskLevel,
      syncStatus: SyncStatus.pending,
    );

    widget.onCreate(item);
    Navigator.pop(context);
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
                ? const Color(0xFF1E40AF)
                : const Color(0xFFD1D5DB),
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
          border: Border.all(color: const Color(0xFFD1D5DB)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.schedule_rounded, color: Color(0xFF6B7280)),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
                Text(
                  time != null
                      ? '${time!.hour.toString().padLeft(2, '0')}:${time!.minute.toString().padLeft(2, '0')}'
                      : '--:--',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
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

class _RiskChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _RiskChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.1) : Colors.white,
          border: Border.all(
            color: selected ? color : const Color(0xFFD1D5DB),
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? color : const Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
