// lib/features/agenda/widgets/filter_chips_row.dart

import 'package:flutter/material.dart';
import '../../../ui/theme/sao_colors.dart';
import '../models/resource.dart';

class FilterChipsRow extends StatelessWidget {
  final List<Resource> resources;
  final String selectedFilterId;
  final bool loading;
  final ValueChanged<String> onFilterChange;

  const FilterChipsRow({
    super.key,
    required this.resources,
    required this.selectedFilterId,
    this.loading = false,
    required this.onFilterChange,
  });

  @override
  Widget build(BuildContext context) {
    final chips = <(String id, String label, IconData icon)>[
      ('Todos', 'Todos', Icons.apps_rounded),
      ...resources
          .where((r) => r.isActive)
          .map((r) => (r.id, r.name.split(' ').first, Icons.person_rounded)),
    ];

    return Container(
      color: SaoColors.surface,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Filtrar por:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: SaoColors.statusBorrador,
              ),
            ),
          ),
          SizedBox(
            height: 38,
            child: loading
                ? const Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: chips.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final c = chips[i];
                final selected = selectedFilterId == c.$1;

                return ChoiceChip(
                  selected: selected,
                  onSelected: (_) => onFilterChange(c.$1),
                  backgroundColor: SaoColors.gray100,
                  selectedColor: SaoColors.gray800,
                  side: BorderSide(
                    color: selected ? SaoColors.gray800 : SaoColors.gray200,
                  ),
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : SaoColors.primaryLight,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    fontSize: 13,
                  ),
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        c.$3,
                        size: 16,
                        color: selected ? Colors.white : SaoColors.statusBorrador,
                      ),
                      const SizedBox(width: 6),
                      Text(c.$2),
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
