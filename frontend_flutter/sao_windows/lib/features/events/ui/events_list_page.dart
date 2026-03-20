// lib/features/events/ui/events_list_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/snackbar.dart';
import '../../../ui/theme/sao_colors.dart';
import '../../../features/auth/application/auth_providers.dart';
import '../data/events_provider.dart';
import '../models/event_dto.dart';
import 'report_event_sheet.dart';
import '../../../data/local/app_db.dart';

class EventsListPage extends ConsumerWidget {
  final String projectId;

  const EventsListPage({super.key, this.projectId = 'TMQ'});

  Future<void> _editEvent(
    BuildContext context,
    WidgetRef ref,
    LocalEvent event,
  ) async {
    final titleCtrl = TextEditingController(text: event.title);
    final descCtrl = TextEditingController(text: event.description ?? '');
    final pkCtrl = TextEditingController(
      text: event.locationPkMeters?.toString() ?? '',
    );
    final formKey = GlobalKey<FormState>();
    var selectedSeverity = event.severity;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Editar evento'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(labelText: 'Titulo'),
                      validator: (value) => (value == null || value.trim().isEmpty)
                          ? 'El titulo es obligatorio'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descCtrl,
                      decoration: const InputDecoration(labelText: 'Descripcion'),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedSeverity,
                      decoration: const InputDecoration(labelText: 'Severidad'),
                      items: EventSeverity.values
                          .map(
                            (s) => DropdownMenuItem<String>(
                              value: s.value,
                              child: Text(s.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() => selectedSeverity = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: pkCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'PK (metros, opcional)',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    if (formKey.currentState?.validate() != true) return;
                    Navigator.of(dialogContext).pop(true);
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true) {
      final dto = EventDTO(
        uuid: event.id,
        serverId: event.serverId,
        projectId: event.projectId,
        reportedByUserId: event.reportedByUserId,
        eventTypeCode: event.eventTypeCode,
        title: titleCtrl.text.trim(),
        description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
        severity: selectedSeverity,
        locationPkMeters:
            pkCtrl.text.trim().isEmpty ? null : int.tryParse(pkCtrl.text.trim()),
        occurredAt: event.occurredAt.toUtc().toIso8601String(),
        resolvedAt: event.resolvedAt?.toUtc().toIso8601String(),
        deletedAt: event.deletedAt?.toUtc().toIso8601String(),
        formFieldsJson: event.formFieldsJson,
        syncVersion: event.syncVersion,
      );

      await ref.read(eventsLocalRepositoryProvider).updateEvent(dto);
      if (context.mounted) {
        showTransientSnackBar(context,
          appSnackBar(message: 'Evento actualizado. Se sincronizará al tener red.', backgroundColor: SaoColors.success));
      }
    }

    titleCtrl.dispose();
    descCtrl.dispose();
    pkCtrl.dispose();
  }

  Future<void> _deleteEvent(
    BuildContext context,
    WidgetRef ref,
    LocalEvent event,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar evento'),
        content: Text('Se eliminara "${event.title}". Esta accion no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: SaoColors.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await ref.read(eventsLocalRepositoryProvider).deleteEvent(event.id);
    if (context.mounted) {
      showTransientSnackBar(context,
        appSnackBar(message: 'Evento eliminado. Se sincronizará al tener red.', backgroundColor: SaoColors.info));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(eventsStreamProvider(projectId));
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: SaoColors.background,
      appBar: AppBar(
        backgroundColor: SaoColors.surface,
        elevation: 0,
        title: const Text(
          'Eventos',
          style: TextStyle(
            color: SaoColors.onSurface,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              projectId,
              style: const TextStyle(
                color: SaoColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
      body: eventsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text('Error al cargar eventos: $e',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: SaoColors.onSurface)),
            ],
          ),
        ),
        data: (events) {
          final active = events.where((e) => e.deletedAt == null).toList()
            ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

          if (active.isEmpty) {
            return _EmptyState(
              projectId: projectId,
              userId: currentUser?.id ?? '',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: active.length,
            itemBuilder: (context, index) {
              final event = active[index];
              return _EventCard(
                event: event,
                onEdit: () => _editEvent(context, ref, event),
                onDelete: () => _deleteEvent(context, ref, event),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (currentUser == null) return;
          showReportEventSheet(
            context,
            projectId: projectId,
            reportedByUserId: currentUser.id,
          );
        },
        backgroundColor: SaoColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_alert_outlined),
        label: const Text('Reportar'),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Event card
// ─────────────────────────────────────────────

class _EventCard extends StatelessWidget {
  final LocalEvent event;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _EventCard({
    required this.event,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final severity = EventSeverity.fromString(event.severity);
    final severityColor = _severityColor(severity);

    return Card(
      color: SaoColors.surface,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: severityColor.withValues(alpha: 0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Severity indicator bar
            Container(
              width: 4,
              height: 56,
              decoration: BoxDecoration(
                color: severityColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          event.title,
                          style: const TextStyle(
                            color: SaoColors.onSurface,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _SeverityChip(severity: severity, color: severityColor),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        event.eventTypeCode,
                        style: const TextStyle(
                          color: SaoColors.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      if (event.locationPkMeters != null) ...[
                        const Text(
                          ' · ',
                          style: TextStyle(color: SaoColors.onSurfaceVariant),
                        ),
                        Text(
                          'PK ${_formatPk(event.locationPkMeters!)}',
                          style: const TextStyle(
                            color: SaoColors.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time,
                          size: 12, color: SaoColors.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        _formatDateTime(event.occurredAt),
                        style: const TextStyle(
                          color: SaoColors.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                      const Spacer(),
                      _SyncBadge(syncStatus: event.syncStatus),
                      PopupMenuButton<String>(
                        onSelected: (action) {
                          if (action == 'edit') {
                            onEdit();
                          } else if (action == 'delete') {
                            onDelete();
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem<String>(
                            value: 'edit',
                            child: Text('Editar'),
                          ),
                          PopupMenuItem<String>(
                            value: 'delete',
                            child: Text('Eliminar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _severityColor(EventSeverity s) => switch (s) {
        EventSeverity.low => const Color(0xFF4CAF50),
        EventSeverity.medium => const Color(0xFFFFC107),
        EventSeverity.high => const Color(0xFFFF9800),
        EventSeverity.critical => const Color(0xFFF44336),
      };

  String _formatPk(int meters) {
    final km = meters ~/ 1000;
    final m = meters % 1000;
    return '$km+${m.toString().padLeft(3, '0')}';
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}

// ─────────────────────────────────────────────
// Severity chip
// ─────────────────────────────────────────────

class _SeverityChip extends StatelessWidget {
  final EventSeverity severity;
  final Color color;

  const _SeverityChip({required this.severity, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        severity.label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Sync status badge
// ─────────────────────────────────────────────

class _SyncBadge extends StatelessWidget {
  final String syncStatus;

  const _SyncBadge({required this.syncStatus});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (syncStatus) {
      'SYNCED' => (Icons.cloud_done_outlined, const Color(0xFF4CAF50)),
      'ERROR' => (Icons.cloud_off_outlined, const Color(0xFFF44336)),
      _ => (Icons.cloud_upload_outlined, const Color(0xFFFFC107)),
    };

    return Icon(icon, size: 14, color: color);
  }
}

// ─────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String projectId;
  final String userId;

  const _EmptyState({required this.projectId, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.campaign_outlined,
              size: 64, color: SaoColors.onSurfaceVariant.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          const Text(
            'Sin eventos reportados',
            style: TextStyle(
              color: SaoColors.onSurface,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Usa el botón "Reportar" para registrar\nun evento de campo.',
            textAlign: TextAlign.center,
            style: TextStyle(color: SaoColors.onSurfaceVariant, fontSize: 14),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: () => showReportEventSheet(
              context,
              projectId: projectId,
              reportedByUserId: userId,
            ),
            icon: const Icon(Icons.add_alert_outlined),
            label: const Text('Reportar evento'),
            style: FilledButton.styleFrom(
              backgroundColor: SaoColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
