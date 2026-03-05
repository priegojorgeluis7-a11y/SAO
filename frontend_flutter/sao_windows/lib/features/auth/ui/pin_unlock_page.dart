// lib/features/auth/ui/pin_unlock_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../ui/theme/sao_colors.dart';
import '../../../ui/theme/sao_typography.dart';
import '../application/auth_providers.dart';
import '../application/auth_controller.dart';

/// Pantalla de desbloqueo offline con PIN de 4 dígitos.
/// Se muestra cuando hay tokens locales pero sin conexión a la red
/// y el usuario ha configurado previamente un PIN.
class PinUnlockPage extends ConsumerStatefulWidget {
  const PinUnlockPage({super.key});

  @override
  ConsumerState<PinUnlockPage> createState() => _PinUnlockPageState();
}

class _PinUnlockPageState extends ConsumerState<PinUnlockPage> {
  static const _pinLength = 4;

  String _pin = '';
  bool _shaking = false;

  void _onDigit(String digit) {
    if (_pin.length >= _pinLength) return;
    setState(() => _pin += digit);
    if (_pin.length == _pinLength) {
      _submit();
    }
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submit() async {
    final pin = _pin;
    await ref.read(authControllerProvider.notifier).loginWithPin(pin);

    // Check for error (PIN incorrecto → state.requiresPinUnlock sigue true)
    final authState = ref.read(authControllerProvider);
    if (authState.requiresPinUnlock) {
      _triggerShake();
    }
  }

  void _triggerShake() {
    setState(() {
      _pin = '';
      _shaking = true;
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _shaking = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;
    final userName = authState.user?.fullName.split(' ').first ?? 'Usuario';

    return Scaffold(
      backgroundColor: SaoColors.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.lock_outline,
                  size: 56,
                  color: SaoColors.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Bienvenido, $userName',
                  style: SaoTypography.pageTitle,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Ingresa tu PIN para continuar sin conexión',
                  style: SaoTypography.bodyText.copyWith(
                    color: SaoColors.gray600,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (authState.error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    authState.error!,
                    style: SaoTypography.bodyTextSmall.copyWith(
                      color: SaoColors.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 32),

                // PIN dots
                _PinDots(
                  filled: _pin.length,
                  shaking: _shaking,
                ),
                const SizedBox(height: 40),

                // Keypad
                if (isLoading)
                  const CircularProgressIndicator()
                else
                  _Keypad(
                    onDigit: _onDigit,
                    onBackspace: _onBackspace,
                  ),

                const SizedBox(height: 32),
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () => ref
                          .read(authControllerProvider.notifier)
                          .logout(),
                  child: Text(
                    'Cerrar sesión e iniciar en línea',
                    style: SaoTypography.bodyTextSmall.copyWith(
                      color: SaoColors.gray500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PinDots extends StatelessWidget {
  final int filled;
  final bool shaking;

  const _PinDots({required this.filled, required this.shaking});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 80),
      transform: shaking
          ? (Matrix4.identity()..translate(8.0))
          : Matrix4.identity(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(4, (i) {
          final isFilled = i < filled;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isFilled ? SaoColors.primary : Colors.transparent,
                border: Border.all(
                  color: isFilled ? SaoColors.primary : SaoColors.gray400,
                  width: 2,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  final void Function(String) onDigit;
  final VoidCallback onBackspace;

  const _Keypad({required this.onDigit, required this.onBackspace});

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
    ];

    return Column(
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: row.map((d) => _KeypadButton(label: d, onTap: () => onDigit(d))).toList(),
            ),
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 80),
            _KeypadButton(label: '0', onTap: () => onDigit('0')),
            _BackspaceButton(onTap: onBackspace),
          ],
        ),
      ],
    );
  }
}

class _KeypadButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _KeypadButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SizedBox(
        width: 64,
        height: 64,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            shape: const CircleBorder(),
            side: const BorderSide(color: SaoColors.border),
            padding: EdgeInsets.zero,
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w500,
              color: SaoColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _BackspaceButton extends StatelessWidget {
  final VoidCallback onTap;

  const _BackspaceButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SizedBox(
        width: 64,
        height: 64,
        child: IconButton(
          onPressed: onTap,
          icon: const Icon(Icons.backspace_outlined),
          color: SaoColors.gray600,
          iconSize: 24,
        ),
      ),
    );
  }
}
