import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class _RejectIntent extends Intent {
  const _RejectIntent();
}

class _SkipIntent extends Intent {
  const _SkipIntent();
}

class _ValidateIntent extends Intent {
  const _ValidateIntent();
}

/// Atajos de teclado del tablero de validación:
/// V = Validar/Aprobar  |  Enter = Validar  |  R = Rechazar  |  Esc = Saltar
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
          const SingleActivator(LogicalKeyboardKey.keyV): const _ValidateIntent(),
          const SingleActivator(LogicalKeyboardKey.escape): const _SkipIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            _ValidateIntent: CallbackAction<_ValidateIntent>(
              onInvoke: (_) { onApprove(); return null; },
            ),
            _SkipIntent: CallbackAction<_SkipIntent>(
              onInvoke: (_) { onSkip(); return null; },
            ),
          },
          child: child,
        ),
      ),
    );
  }
}
