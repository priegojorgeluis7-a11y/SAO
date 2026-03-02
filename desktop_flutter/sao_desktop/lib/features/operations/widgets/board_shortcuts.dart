import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Intent para rechazar actividad
class _RejectIntent extends Intent {
  const _RejectIntent();
}

/// Intent para saltar a siguiente actividad
class _SkipIntent extends Intent {
  const _SkipIntent();
}

/// Wrap que proporciona atajos de teclado sin RawKeyboardListener
/// Reemplaza Enter=Aprobar, R=Rechazar, Esc=Saltar
class BoardShortcuts extends StatelessWidget {
  final Widget child;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onSkip;

  const BoardShortcuts({
    super.key,
    required this.child,
    required this.onApprove,
    required this.onReject,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      child: Shortcuts(
        shortcuts: <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.enter): const ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.keyR): const _RejectIntent(),
          SingleActivator(LogicalKeyboardKey.escape): const _SkipIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                onApprove();
                return null;
              },
            ),
            _RejectIntent: CallbackAction<_RejectIntent>(
              onInvoke: (_) {
                onReject();
                return null;
              },
            ),
            _SkipIntent: CallbackAction<_SkipIntent>(
              onInvoke: (_) {
                onSkip();
                return null;
              },
            ),
          },
          child: child,
        ),
      ),
    );
  }
}
