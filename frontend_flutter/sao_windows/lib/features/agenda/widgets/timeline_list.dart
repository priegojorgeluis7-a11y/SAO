// lib/features/agenda/widgets/timeline_list.dart

import 'package:flutter/material.dart';
import '../../../ui/theme/sao_colors.dart';
import '../../../ui/theme/sao_typography.dart';
import '../models/agenda_item.dart';
import '../models/resource.dart';
import 'agenda_mini_card.dart';

class TimelineList extends StatefulWidget {
  final List<AgendaItem> items;
  final List<Resource> resources;
  final int startHour;
  final int endHour;
  /// Invocado cuando el usuario confirma cancelar una asignación pendiente.
  final void Function(AgendaItem)? onCancelItem;

  const TimelineList({
    super.key,
    required this.items,
    required this.resources,
    this.startHour = 7,
    this.endHour = 19,
    this.onCancelItem,
  });

  @override
  State<TimelineList> createState() => _TimelineListState();
}

class _TimelineListState extends State<TimelineList> {
  final ScrollController _scrollController = ScrollController();
  /// Key para el row de la hora actual — usado para ensureVisible.
  final GlobalKey _currentHourKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Scroll a la hora actual después del primer frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrentHour());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrentHour() {
    final ctx = _currentHourKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.25, // mostrar la hora actual en el 25% superior de la vista
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final hourSlots = List.generate(
      widget.endHour - widget.startHour + 1,
      (i) => widget.startHour + i,
    );

    return ListView.builder(
      controller: _scrollController,
      itemCount: hourSlots.length,
      itemBuilder: (_, i) {
        final h = hourSlots[i];
        final slotItems = _filterItemsByHour(h);
        final isCurrentHour =
            h == now.hour && now.hour >= widget.startHour && now.hour <= widget.endHour;

        return Container(
          key: isCurrentHour ? _currentHourKey : null,
          color: SaoColors.surface,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---- Etiqueta de hora ----
              SizedBox(
                width: 58,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4, left: 12),
                  child: Text(
                    '${h.toString().padLeft(2, '0')}:00',
                    style: SaoTypography.monoSmall.copyWith(
                      color: isCurrentHour
                          ? SaoColors.error
                          : SaoColors.gray500,
                      fontWeight: isCurrentHour
                          ? FontWeight.w700
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
              // ---- Contenido de la franja ----
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Indicador de hora actual: línea roja + tiempo exacto
                    if (isCurrentHour)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 2, 12, 4),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: SaoColors.error,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
                              style: SaoTypography.monoSmall.copyWith(
                                color: SaoColors.error,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Expanded(
                              child: Divider(
                                color: SaoColors.error,
                                thickness: 1.2,
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (slotItems.isNotEmpty)
                      ...slotItems.map(
                        (it) {
                          final resource = widget.resources.firstWhere(
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
    // Solo mostrar el item en la franja de su hora de inicio.
    // Mostrarlo también en horas que "cruza" causaría duplicados visuales.
    return widget.items
        .where((it) => it.start.hour == hour)
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  void _showItemDetails(
    BuildContext context,
    AgendaItem item,
    Resource resource,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ItemDetailSheet(
        item: item,
        resource: resource,
        onCancelItem: widget.onCancelItem,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sheet de detalle con acciones
// ---------------------------------------------------------------------------

class _ItemDetailSheet extends StatelessWidget {
  const _ItemDetailSheet({
    required this.item,
    required this.resource,
    this.onCancelItem,
  });

  final AgendaItem item;
  final Resource resource;
  final void Function(AgendaItem)? onCancelItem;

  @override
  Widget build(BuildContext context) {
    final canCancel = item.syncStatus == SyncStatus.pending ||
        item.syncStatus == SyncStatus.error;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado: recurso
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
                      style: SaoTypography.bodyTextBold
                          .copyWith(color: SaoColors.primary),
                    ),
                    Text(
                      resource.roleLabel,
                      style: SaoTypography.bodyTextSmall
                          .copyWith(color: SaoColors.gray500),
                    ),
                  ],
                ),
              ),
              // Badge de estado de sync
              _SyncBadge(status: item.syncStatus),
            ],
          ),
          const Divider(height: 24),

          // Datos de la asignación
          Text(
            item.title,
            style:
                SaoTypography.frontTitle.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          _DetailRow(
            icon: Icons.location_on_rounded,
            label: item.location,
          ),
          const SizedBox(height: 4),
          _DetailRow(
            icon: Icons.schedule_rounded,
            label: '${_fTime(item.start)} - ${_fTime(item.end)}',
          ),
          const SizedBox(height: 4),
          _DetailRow(
            icon: Icons.calendar_today_rounded,
            label:
                '${item.start.day}/${item.start.month}/${item.start.year}',
          ),
          if (item.notes != null && item.notes!.isNotEmpty) ...[
            const SizedBox(height: 4),
            _DetailRow(
              icon: Icons.notes_rounded,
              label: item.notes!,
            ),
          ],
          const SizedBox(height: 20),

          // Acciones
          if (onCancelItem != null) ...[
            if (canCancel)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Cancelar asignación'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: SaoColors.error,
                    side: const BorderSide(color: SaoColors.error),
                  ),
                  onPressed: () => _confirmCancel(context),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: SaoColors.infoBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: SaoColors.infoBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        size: 16, color: SaoColors.infoIcon),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Esta asignación ya fue sincronizada. '
                        'Coordina con el despachador para cancelarla.',
                        style: SaoTypography.bodyTextSmall
                            .copyWith(color: SaoColors.infoText),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar asignación'),
        content: Text(
          '¿Cancelar "${item.title}" asignada a ${resource.name}? '
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style:
                FilledButton.styleFrom(backgroundColor: SaoColors.error),
            child: const Text('Cancelar asignación'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      Navigator.of(context).pop(); // cerrar sheet
      onCancelItem?.call(item);
    }
  }

  String _fTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

// ---------------------------------------------------------------------------
// Widgets auxiliares
// ---------------------------------------------------------------------------

class _SyncBadge extends StatelessWidget {
  const _SyncBadge({required this.status});
  final SyncStatus status;

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (status) {
      SyncStatus.synced => (Icons.cloud_done_rounded, SaoColors.success, 'Sync'),
      SyncStatus.pending =>
        (Icons.cloud_upload_rounded, SaoColors.info, 'Pendiente'),
      SyncStatus.uploading =>
        (Icons.cloud_upload_rounded, SaoColors.warning, 'Subiendo'),
      SyncStatus.error => (Icons.cloud_off_rounded, SaoColors.error, 'Error'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
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
            style:
                SaoTypography.bodyText.copyWith(color: SaoColors.primaryLight),
          ),
        ),
      ],
    );
  }
}
