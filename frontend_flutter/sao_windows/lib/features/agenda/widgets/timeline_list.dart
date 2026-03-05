// lib/features/agenda/widgets/timeline_list.dart

import 'package:flutter/material.dart';
import '../../../ui/theme/sao_colors.dart';
import '../../../ui/theme/sao_typography.dart';
import '../models/agenda_item.dart';
import '../models/resource.dart';
import 'agenda_mini_card.dart';

class TimelineList extends StatelessWidget {
  final List<AgendaItem> items;
  final List<Resource> resources;
  final int startHour;
  final int endHour;

  const TimelineList({
    super.key,
    required this.items,
    required this.resources,
    this.startHour = 7,
    this.endHour = 19,
  });

  @override
  Widget build(BuildContext context) {
    final hourSlots = List.generate(
      endHour - startHour + 1,
      (i) => startHour + i,
    );

    return ListView.builder(
      itemCount: hourSlots.length,
      itemBuilder: (_, i) {
        final h = hourSlots[i];
        final slotItems = _filterItemsByHour(h);

        return Container(
          color: SaoColors.surface,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 58,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4, left: 12),
                  child: Text(
                    '${h.toString().padLeft(2, '0')}:00',
                    style: SaoTypography.monoSmall.copyWith(color: SaoColors.gray500),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (slotItems.isNotEmpty)
                      ...slotItems.map(
                        (it) {
                          final resource = resources.firstWhere(
                            (r) => r.id == it.resourceId,
                            orElse: () => const Resource(
                              id: 'unknown',
                              name: 'Desconocido',
                              role: ResourceRole.tecnico,
                              isActive: true,
                            ),
                          );
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(8, 0, 12, 8),
                            child: AgendaMiniCard(
                              item: it,
                              resource: resource,
                              onTap: () => _showItemDetails(context, it, resource),
                            ),
                          );
                        },
                      )
                    else
                      Container(
                        height: 48,
                        margin: const EdgeInsets.fromLTRB(8, 0, 12, 0),
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: SaoColors.border,
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<AgendaItem> _filterItemsByHour(int hour) {
    return items.where((it) {
      final startH = it.start.hour;
      final endH = it.end.hour;
      final endMin = it.end.minute;
      
      // Incluir si el item empieza en esta hora o la cruza
      return (startH == hour) || 
             (startH < hour && (endH > hour || (endH == hour && endMin > 0)));
    }).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  void _showItemDetails(
    BuildContext context,
    AgendaItem item,
    Resource resource,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: SaoColors.info,
                  backgroundImage: resource.avatarUrl != null
                      ? NetworkImage(resource.avatarUrl!)
                      : null,
                  child: resource.avatarUrl == null
                      ? Text(
                          resource.initials,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: SaoColors.onPrimary,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        resource.name,
                        style: SaoTypography.bodyTextBold.copyWith(color: SaoColors.primary),
                      ),
                      Text(
                        resource.roleLabel,
                        style: SaoTypography.bodyTextSmall.copyWith(color: SaoColors.gray500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Text(
              item.title,
              style: SaoTypography.frontTitle.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            _DetailRow(
              icon: Icons.location_on_rounded,
              label: item.location,
            ),
            const SizedBox(height: 4),
            _DetailRow(
              icon: Icons.schedule_rounded,
              label:
                  '${_fTime(item.start)} - ${_fTime(item.end)}',
            ),
            const SizedBox(height: 4),
            _DetailRow(
              icon: Icons.calendar_today_rounded,
              label:
                  '${item.start.day}/${item.start.month}/${item.start.year}',
            ),
          ],
        ),
      ),
    );
  }

  String _fTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _DetailRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: SaoColors.gray500),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: SaoTypography.bodyText.copyWith(color: SaoColors.primaryLight),
          ),
        ),
      ],
    );
  }
}
