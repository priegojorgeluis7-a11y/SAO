// lib/features/activities/wizard/widgets/topics_chips.dart
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../catalog/catalog_repository.dart';

class TopicsChips extends StatelessWidget {
  final String title;
  final List<CatItem> items;
  final Set<String> selectedIds;
  final void Function(String id) onToggle;

  const TopicsChips({
    super.key,
    required this.title,
    required this.items,
    required this.selectedIds,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.gray100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: const Text(
          'Sin temas sugeridos para esta actividad.',
          style: AppTypography.hint,
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map<Widget>((topic) {
        final isSelected = selectedIds.contains(topic.id);
        return ChoiceChip(
          label: Text(topic.name),
          selected: isSelected,
          onSelected: (_) => onToggle(topic.id),
          backgroundColor: const Color(0xFFF3F4F6),
          selectedColor: const Color(0xFF1F2937),
          labelStyle: TextStyle(
            color: isSelected ? const Color(0xFFFFFFFF) : const Color(0xFF374151),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
          side: BorderSide(
            color: isSelected ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB),
          ),
        );
      }).toList(),
    );
  }
}
