// lib/features/agenda/widgets/filter_chips_row.dart

import 'package:flutter/material.dart';
import '../models/resource.dart';

class FilterChipsRow extends StatelessWidget {
  final List<Resource> resources;
  final String selectedFilterId;
  final ValueChanged<String> onFilterChange;

  const FilterChipsRow({
    super.key,
    required this.resources,
    required this.selectedFilterId,
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
      color: Colors.white,
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
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: chips.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final c = chips[i];
                final selected = selectedFilterId == c.$1;
                
                return ChoiceChip(
                  selected: selected,
                  onSelected: (_) => onFilterChange(c.$1),
                  backgroundColor: const Color(0xFFF3F4F6),
                  selectedColor: const Color(0xFF1F2937),
                  side: BorderSide(
                    color: selected
                        ? const Color(0xFF1F2937)
                        : const Color(0xFFE5E7EB),
                  ),
                  labelStyle: TextStyle(
                    color: selected
                        ? const Color(0xFFFFFFFF)
                        : const Color(0xFF374151),
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    fontSize: 13,
                  ),
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        c.$3,
                        size: 16,
                        color: selected
                            ? const Color(0xFFFFFFFF)
                            : const Color(0xFF6B7280),
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
