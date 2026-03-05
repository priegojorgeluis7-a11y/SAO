// lib/features/activities/wizard/widgets/attendees_group.dart
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../catalog/catalog_repository.dart';

class AttendeesGroup extends StatelessWidget {
  final String title;
  final List<CatItem> items;
  final Set<String> selectedIds;
  final void Function(String id) onToggle;
  final VoidCallback? onAddNew;

  const AttendeesGroup({
    super.key,
    required this.title,
    required this.items,
    required this.selectedIds,
    required this.onToggle,
    this.onAddNew,
  });

  @override
  Widget build(BuildContext context) {
    final selectedCount = items.where((item) => selectedIds.contains(item.id)).length;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: AppTypography.bodyTextBold),
              if (onAddNew != null)
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  onPressed: onAddNew,
                  tooltip: 'Agregar nuevo',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          if (items.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Sin asistentes registrados',
              style: AppTypography.hint,
            ),
            const SizedBox(height: 4),
            if (onAddNew != null)
              TextButton.icon(
                onPressed: onAddNew,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Agregar primero'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                ),
              ),
          ] else ...[
            const SizedBox(height: 8),
            if (selectedCount == 0)
              Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Ninguno seleccionado',
                  style: AppTypography.hint.copyWith(fontStyle: FontStyle.italic),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '$selectedCount seleccionado${selectedCount > 1 ? 's' : ''}',
                  style: AppTypography.caption.copyWith(color: AppColors.info, fontWeight: FontWeight.w600),
                ),
              ),
            ...items.map<Widget>((attendee) {
              final isSelected = selectedIds.contains(attendee.id);
              return CheckboxListTile(
                value: isSelected,
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  attendee.name,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyTextBold,
                ),
                onChanged: (_) => onToggle(attendee.id),
              );
            }),
          ],
        ],
      ),
    );
  }
}
