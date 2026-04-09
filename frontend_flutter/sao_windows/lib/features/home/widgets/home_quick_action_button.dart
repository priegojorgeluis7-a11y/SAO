import 'package:flutter/material.dart';
import '../models/today_activity.dart';

/// Action details model for quick actions
class _ActionDetail {
  final String label;
  final IconData icon;
  final Color color;
  final String actionName;

  _ActionDetail({
    required this.label,
    required this.icon,
    required this.color,
    required this.actionName,
  });
}

/// Context-aware quick action button for different activity states
///
/// Returns different buttons/actions based on nextAction field:
/// - INICIAR_ACTIVIDAD → "Iniciar" button
/// - TERMINAR_ACTIVIDAD → "Terminar" button
/// - COMPLETAR_WIZARD → "Completar" button
/// - CORREGIR_Y_REENVIAR → "Reabrir y Corregir" button
/// - SINCRONIZAR_PENDIENTE → "Sincronizar" button
/// - REVISAR_ERROR_SYNC → "Revisar Error" button
class QuickActionButton extends StatelessWidget {
  /// Activity to get action from
  final TodayActivity activity;

  /// Callback when action button is tapped
  /// Returns the action name as parameter
  final Function(String actionName) onPressed;

  /// Whether button is in loading state
  final bool isLoading;

  /// Custom size
  final double? height;
  final double? width;

  /// Show as outlined or filled
  final bool outlined;

  const QuickActionButton({
    super.key,
    required this.activity,
    required this.onPressed,
    this.isLoading = false,
    this.height = 36,
    this.width,
    this.outlined = true,
  });

  /// Get action details (button text, icon, color) from activity's nextAction
  _ActionDetail _getActionDetails() {
    switch (activity.nextAction.toUpperCase().trim()) {
      case 'INICIAR_ACTIVIDAD':
        return _ActionDetail(
          label: 'Iniciar',
          icon: Icons.play_arrow_rounded,
          color: Colors.green.shade600,
          actionName: 'INICIAR',
        );
      case 'TERMINAR_ACTIVIDAD':
        return _ActionDetail(
          label: 'Terminar',
          icon: Icons.stop_rounded,
          color: Colors.blue.shade600,
          actionName: 'TERMINAR',
        );
      case 'COMPLETAR_WIZARD':
        return _ActionDetail(
          label: 'Completar',
          icon: Icons.check_circle_rounded,
          color: Colors.amber.shade600,
          actionName: 'COMPLETAR',
        );
      case 'CORREGIR_Y_REENVIAR':
      case 'CERRADA_RECHAZADA':
        return _ActionDetail(
          label: 'Corregir',
          icon: Icons.edit_rounded,
          color: Colors.red.shade600,
          actionName: 'CORREGIR',
        );
      case 'SINCRONIZAR_PENDIENTE':
        return _ActionDetail(
          label: 'Sincronizar',
          icon: Icons.cloud_upload_rounded,
          color: Colors.purple.shade600,
          actionName: 'SINCRONIZAR',
        );
      case 'REVISAR_ERROR_SYNC':
        return _ActionDetail(
          label: 'Revisar',
          icon: Icons.error_outline_rounded,
          color: Colors.red.shade700,
          actionName: 'REVISAR_ERROR',
        );
      default:
        return _ActionDetail(
          label: 'Abrir',
          icon: Icons.open_in_new_rounded,
          color: Colors.grey.shade600,
          actionName: 'ABRIR',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final details = _getActionDetails();
    final theme = Theme.of(context);

    if (outlined) {
      return SizedBox(
        height: height,
        width: width,
        child: OutlinedButton.icon(
          onPressed: isLoading ? null : () => onPressed(details.actionName),
          icon: isLoading
              ? SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(details.color),
                  ),
                )
              : Icon(details.icon, size: 16),
          label: Text(
            details.label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: details.color,
            side: BorderSide(color: details.color),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      );
    }

    // Filled button
    return SizedBox(
      height: height,
      width: width,
      child: FilledButton.icon(
        onPressed: isLoading ? null : () => onPressed(details.actionName),
        icon: isLoading
            ? SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Icon(details.icon, size: 16),
        label: Text(
          details.label,
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: details.color,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
    );
  }
}

/// Action menu for more options
class QuickActionMenu extends StatelessWidget {
  final TodayActivity activity;
  final VoidCallback onOpen;
  final VoidCallback onShare;
  final VoidCallback onMarkComplete;
  final VoidCallback? onDelete;

  const QuickActionMenu({
    super.key,
    required this.activity,
    required this.onOpen,
    required this.onShare,
    required this.onMarkComplete,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<void>(
      icon: const Icon(Icons.more_vert_rounded, size: 20),
      itemBuilder: (context) => <PopupMenuEntry<void>>[
        PopupMenuItem<void>(
          onTap: onOpen,
          child: const Row(
            children: [
              Icon(Icons.open_in_new_rounded, size: 18),
              SizedBox(width: 8),
              Text('Abrir detalle'),
            ],
          ),
        ),
        PopupMenuItem<void>(
          onTap: onShare,
          child: const Row(
            children: [
              Icon(Icons.share_rounded, size: 18),
              SizedBox(width: 8),
              Text('Compartir'),
            ],
          ),
        ),
        PopupMenuItem<void>(
          onTap: onMarkComplete,
          child: const Row(
            children: [
              Icon(Icons.check_rounded, size: 18),
              SizedBox(width: 8),
              Text('Marcar completado'),
            ],
          ),
        ),
        if (onDelete != null) ...[
          const PopupMenuDivider(),
          PopupMenuItem<void>(
            onTap: onDelete,
            child: Row(
              children: [
                Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: Colors.red.shade600,
                ),
                const SizedBox(width: 8),
                Text('Eliminar', style: TextStyle(color: Colors.red.shade600)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
