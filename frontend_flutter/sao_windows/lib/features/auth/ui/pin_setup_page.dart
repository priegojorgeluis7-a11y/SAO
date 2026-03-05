// lib/features/auth/ui/pin_setup_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../ui/theme/sao_colors.dart';
import '../../../ui/theme/sao_typography.dart';
import '../application/auth_providers.dart';

/// Pantalla de configuración de PIN offline (4 dígitos).
/// Se muestra tras el primer login online exitoso si el PIN no está configurado.
/// El usuario puede omitirla; podrá configurar el PIN más tarde en Ajustes.
class PinSetupPage extends ConsumerStatefulWidget {
  const PinSetupPage({super.key});

  @override
  ConsumerState<PinSetupPage> createState() => _PinSetupPageState();
}

enum _PinSetupStep { enter, confirm }

class _PinSetupPageState extends ConsumerState<PinSetupPage> {
  static const _pinLength = 4;

  _PinSetupStep _step = _PinSetupStep.enter;
  String _firstPin = '';
  String _pin = '';
  bool _mismatch = false;

  void _onDigit(String digit) {
    if (_pin.length >= _pinLength) return;
    setState(() {
      _pin += digit;
      _mismatch = false;
    });
    if (_pin.length == _pinLength) {
      _advance();
    }
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _advance() async {
    if (_step == _PinSetupStep.enter) {
      setState(() {
        _firstPin = _pin;
        _pin = '';
        _step = _PinSetupStep.confirm;
      });
    } else {
      // Confirmar
      if (_pin != _firstPin) {
        setState(() {
          _mismatch = true;
          _pin = '';
          _step = _PinSetupStep.enter;
          _firstPin = '';
        });
        return;
      }
      await ref.read(authControllerProvider.notifier).setupPin(_pin);
      if (mounted) context.go('/');
    }
  }

  void _skip() {
    ref.read(authControllerProvider.notifier).skipPinSetup();
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final isEnter = _step == _PinSetupStep.enter;

    return Scaffold(
      backgroundColor: SaoColors.surface,
      appBar: AppBar(
        backgroundColor: SaoColors.surface,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: _skip,
            child: Text(
              'Omitir',
              style: SaoTypography.bodyText.copyWith(color: SaoColors.gray500),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.shield_outlined,
                  size: 56,
                  color: SaoColors.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Configura tu PIN offline',
                  style: SaoTypography.pageTitle,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  isEnter
                      ? 'Elige un PIN de 4 dígitos para acceder sin internet'
                      : 'Confirma tu PIN',
                  style: SaoTypography.bodyText.copyWith(
                    color: SaoColors.gray600,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (_mismatch) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Los PINs no coinciden. Intenta de nuevo.',
                    style: SaoTypography.bodyTextSmall.copyWith(
                      color: SaoColors.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 32),

                // PIN dots
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(4, (i) {
                    final filled = i < _pin.length;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: filled ? SaoColors.primary : Colors.transparent,
                          border: Border.all(
                            color: filled ? SaoColors.primary : SaoColors.gray400,
                            width: 2,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 40),

                // Keypad
                _Keypad(onDigit: _onDigit, onBackspace: _onBackspace),

                const SizedBox(height: 24),
                Text(
                  'Podrás cambiar o eliminar el PIN en Ajustes',
                  style: SaoTypography.bodyTextSmall.copyWith(
                    color: SaoColors.gray400,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Keypad widget (duplicado local para no crear dependencia extra)
// ---------------------------------------------------------------------------
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
