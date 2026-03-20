// lib/features/agenda/widgets/week_strip.dart

import 'package:flutter/material.dart';
import '../../../ui/theme/sao_colors.dart';
import '../../../ui/theme/sao_typography.dart';

class WeekStrip extends StatelessWidget {
  final DateTime selectedDay;
  final int weekOffset;
  // Async porque el controller hace await en la carga de asignaciones
  final Future<void> Function(int) onChangeWeek;
  final ValueChanged<DateTime> onSelectDay;
  /// Callback para volver a la semana actual. Solo visible cuando
  /// [weekOffset] != 0.
  final VoidCallback? onGoToToday;

  const WeekStrip({
    super.key,
    required this.selectedDay,
    required this.weekOffset,
    required this.onChangeWeek,
    required this.onSelectDay,
    this.onGoToToday,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final base = DateTime(now.year, now.month, now.day)
        .add(Duration(days: weekOffset * 7));
    final startOfWeek =
        base.subtract(Duration(days: (base.weekday - 1) % 7));
    final days = List.generate(7, (i) => startOfWeek.add(Duration(days: i)));

    return Container(
      color: SaoColors.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => onChangeWeek(-1),
                  icon: const Icon(Icons.chevron_left_rounded),
                  tooltip: 'Semana anterior',
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      _getWeekLabel(days.first, days.last),
                      style: SaoTypography.bodyTextBold
                          .copyWith(color: SaoColors.gray500),
                    ),
                  ),
                ),
                // Botón "Hoy": solo visible cuando no estamos en la semana actual
                if (weekOffset != 0 && onGoToToday != null)
                  TextButton(
                    onPressed: onGoToToday,
                    style: TextButton.styleFrom(
                      foregroundColor: SaoColors.actionPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 36),
                    ),
                    child: const Text(
                      'Hoy',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                IconButton(
                  onPressed: () => onChangeWeek(1),
                  icon: const Icon(Icons.chevron_right_rounded),
                  tooltip: 'Semana siguiente',
                ),
              ],
            ),
          ),
          SizedBox(
            height: 76,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              scrollDirection: Axis.horizontal,
              itemCount: days.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final d = days[i];
                final isSelected = d.year == selectedDay.year &&
                    d.month == selectedDay.month &&
                    d.day == selectedDay.day;

                final isToday = d.year == now.year &&
                    d.month == now.month &&
                    d.day == now.day;

                final label = _dowShort(d.weekday);

                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onSelectDay(d),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeInOut,
                    width: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: isSelected
                          ? SaoColors.actionPrimary
                          : SaoColors.surfaceDim,
                      border: Border.all(
                        color: isSelected
                            ? SaoColors.actionPrimary
                            : SaoColors.border,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? SaoColors.onActionPrimary
                                : SaoColors.gray500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${d.day}',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: isSelected
                                ? SaoColors.onActionPrimary
                                : SaoColors.primary,
                          ),
                        ),
                        if (isToday && !isSelected)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                              color: SaoColors.actionPrimary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 0),
        ],
      ),
    );
  }

  String _dowShort(int weekday) {
    switch (weekday) {
      case 1:
        return 'LUN';
      case 2:
        return 'MAR';
      case 3:
        return 'MIE';
      case 4:
        return 'JUE';
      case 5:
        return 'VIE';
      case 6:
        return 'SÁB';
      case 7:
        return 'DOM';
      default:
        return '';
    }
  }

  String _getWeekLabel(DateTime start, DateTime end) {
    if (start.month == end.month) {
      return '${start.day} - ${end.day} ${_monthShort(start.month)} ${start.year}';
    }
    return '${start.day} ${_monthShort(start.month)} - ${end.day} ${_monthShort(end.month)} ${start.year}';
  }

  String _monthShort(int month) {
    const months = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic'
    ];
    return months[month - 1];
  }
}
