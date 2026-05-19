// lib/features/notifications/screens/notifications_screen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';

import '../../../data/local/app_db.dart';
import '../../../ui/theme/sao_colors.dart';
import '../../../core/utils/snackbar.dart';
import '../data/notifications_repository.dart';
import '../state/notifications_provider.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  Future<void> _sync() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      await GetIt.I<NotificationsRepository>().sync();
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsStreamProvider);

    return Scaffold(
      backgroundColor: SaoColors.gray50,
      appBar: AppBar(
        backgroundColor: SaoColors.primary,
        foregroundColor: SaoColors.onPrimary,
        title: const Text('Notificaciones',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        actions: [
          if (_syncing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Actualizar',
              onPressed: _sync,
            ),
          TextButton(
            onPressed: _markAllRead,
            child: const Text('Leídas',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
          ),
        ],
      ),
      body: notificationsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) {
          if (items.isEmpty) {
            return const _EmptyState();
          }
          return RefreshIndicator(
            onRefresh: _sync,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, indent: 72, endIndent: 16),
              itemBuilder: (context, i) =>
                  _NotificationTile(notification: items[i]),
            ),
          );
        },
      ),
    );
  }

  Future<void> _markAllRead() async {
    await GetIt.I<NotificationsRepository>().markAllRead();
    if (mounted) showTransientSnackBar(context, appSnackBar(message: 'Notificaciones marcadas como leídas'));
  }
}

// ---------------------------------------------------------------------------
// Tile
// ---------------------------------------------------------------------------

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.notification});

  final UserNotification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUnread = notification.status == 'unread';
    final requiresAction =
        notification.requiresAcceptance && notification.status == 'unread';

    return InkWell(
      onTap: () {
        if (isUnread) {
          GetIt.I<NotificationsRepository>().markRead(notification.id);
        }
      },
      child: Container(
        color: isUnread ? SaoColors.actionPrimary.withValues(alpha: 0.04) : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TypeIcon(type: notification.type),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _titleFor(notification.type),
                          style: TextStyle(
                            fontWeight: isUnread
                                ? FontWeight.w700
                                : FontWeight.w500,
                            fontSize: 13,
                            color: SaoColors.gray900,
                          ),
                        ),
                      ),
                      if (isUnread)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: SaoColors.actionPrimary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notification.activityTitle.isNotEmpty
                        ? notification.activityTitle
                        : 'Actividad',
                    style: const TextStyle(
                        fontSize: 13, color: SaoColors.gray700),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (notification.fromUserName != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Por: ${notification.fromUserName}',
                      style: const TextStyle(
                          fontSize: 12, color: SaoColors.gray500),
                    ),
                  ],
                  _MetaInfo(notification: notification),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(notification.createdAt),
                    style: const TextStyle(
                        fontSize: 11, color: SaoColors.gray400),
                  ),
                  if (requiresAction) ...[
                    const SizedBox(height: 8),
                    _ActionButtons(notification: notification),
                  ] else if (notification.status == 'accepted') ...[
                    const SizedBox(height: 4),
                    const _StatusChip(label: 'Aceptada', color: SaoColors.riskLow),
                  ] else if (notification.status == 'declined') ...[
                    const SizedBox(height: 4),
                    const _StatusChip(
                        label: 'Rechazada', color: SaoColors.riskPriority),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _titleFor(String type) {
    switch (type) {
      case 'new_assignment':
        return 'Nueva asignación';
      case 'co_responsable_added':
        return 'Co-responsable añadido';
      case 'assignment_transferred':
        return 'Actividad transferida a ti';
      default:
        return 'Notificación';
    }
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);
    if (diff.inMinutes < 1) return 'Ahora mismo';
    if (diff.inHours < 1) return 'Hace ${diff.inMinutes} min';
    if (diff.inDays < 1) return 'Hace ${diff.inHours} h';
    if (diff.inDays == 1) return 'Ayer';
    return DateFormat('d MMM', 'es').format(local);
  }
}

// ---------------------------------------------------------------------------
// Accept / Decline buttons
// ---------------------------------------------------------------------------

class _ActionButtons extends StatefulWidget {
  const _ActionButtons({required this.notification});
  final UserNotification notification;

  @override
  State<_ActionButtons> createState() => _ActionButtonsState();
}

class _ActionButtonsState extends State<_ActionButtons> {
  bool _loading = false;

  Future<void> _respond(bool accept) async {
    if (_loading) return;
    setState(() => _loading = true);
    final repo = GetIt.I<NotificationsRepository>();
    final success = accept
        ? await repo.accept(
            activityId: widget.notification.activityId,
            notificationId: widget.notification.id,
          )
        : await repo.decline(
            activityId: widget.notification.activityId,
            notificationId: widget.notification.id,
          );
    if (mounted) {
      setState(() => _loading = false);
      if (success) {
        showTransientSnackBar(
          context,
          appSnackBar(message: accept ? 'Actividad aceptada' : 'Actividad rechazada'),
        );
      } else {
        showTransientSnackBar(context, appSnackBar(message: 'Error al procesar. Intenta de nuevo.'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 28,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => _respond(false),
            style: OutlinedButton.styleFrom(
              foregroundColor: SaoColors.riskPriority,
              side: const BorderSide(color: SaoColors.riskPriority),
              visualDensity: VisualDensity.compact,
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: const Text('Rechazar'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton(
            onPressed: () => _respond(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: SaoColors.actionPrimary,
              foregroundColor: Colors.white,
              visualDensity: VisualDensity.compact,
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: const Text('Aceptar'),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _TypeIcon extends StatelessWidget {
  const _TypeIcon({required this.type});
  final String type;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (type) {
      'new_assignment' => (Icons.assignment_turned_in_rounded, SaoColors.actionPrimary),
      'co_responsable_added' => (Icons.group_add_rounded, SaoColors.riskMedium),
      'assignment_transferred' => (Icons.swap_horiz_rounded, SaoColors.riskHigh),
      _ => (Icons.notifications_rounded, SaoColors.gray500),
    };
    return CircleAvatar(
      radius: 20,
      backgroundColor: color.withValues(alpha: 0.12),
      child: Icon(icon, size: 20, color: color),
    );
  }
}

class _MetaInfo extends StatelessWidget {
  const _MetaInfo({required this.notification});
  final UserNotification notification;

  @override
  Widget build(BuildContext context) {
    final meta = _parseMeta(notification.metadataJson);
    final parts = <String>[];
    final frente = meta['frente'] as String?;
    final municipio = meta['municipio'] as String?;
    if (frente != null && frente.isNotEmpty) parts.add(frente);
    if (municipio != null && municipio.isNotEmpty) parts.add(municipio);
    if (parts.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        parts.join(' · '),
        style: const TextStyle(fontSize: 12, color: SaoColors.gray500),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  static Map<String, dynamic> _parseMeta(String? json) {
    if (json == null || json.isEmpty) return {};
    try {
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none_rounded,
              size: 64, color: SaoColors.gray300),
          SizedBox(height: 16),
          Text(
            'Sin notificaciones',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: SaoColors.gray600),
          ),
          SizedBox(height: 8),
          Text(
            'Aquí verás asignaciones,\ntransferencias y co-responsabilidades.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: SaoColors.gray400),
          ),
        ],
      ),
    );
  }
}
