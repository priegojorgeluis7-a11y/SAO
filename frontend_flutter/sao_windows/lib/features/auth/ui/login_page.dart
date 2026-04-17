// lib/features/auth/ui/login_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/snackbar.dart';
import '../../../ui/theme/sao_colors.dart';
import '../../../ui/theme/sao_spacing.dart';
import '../../../ui/theme/sao_typography.dart';
import '../../../ui/widgets/sao_button.dart';
import '../../../ui/widgets/sao_input.dart';
import '../application/auth_providers.dart';

/// Pantalla de inicio de sesión minimalista (Phase 3C)
/// Usa authControllerProvider (Phase 3B) con tema SAO Material 3
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _biometricReady = false;
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadBiometricState();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadBiometricState() async {
    final notifier = ref.read(authControllerProvider.notifier);
    final canUse = await notifier.canUseBiometrics();
    final enabled = await notifier.isBiometricEnabled();

    if (!mounted) return;
    setState(() {
      _biometricReady = canUse;
      _biometricEnabled = enabled;
    });
  }

  void _handleEmailChanged(String value) {
    final normalized = value.toLowerCase();
    if (normalized == value) return;
    _emailController.value = TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;

    await ref.read(authControllerProvider.notifier).login(email, password);
  }

  Future<void> _handleBiometricLogin() async {
    await ref.read(authControllerProvider.notifier).loginWithBiometrics();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Ingresa tu correo electrónico';
    }
    final emailRegex = RegExp(r'^[\w.+-]+@([A-Za-z0-9-]+\.)+[A-Za-z]{2,}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Formato de correo inválido';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Ingresa tu contraseña';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    // Listen for authentication success/failure
    ref.listen(authControllerProvider, (previous, next) {
      if (next.error != null && next.error!.isNotEmpty) {
        showTransientSnackBar(
          context,
          appSnackBar(
            message: next.error!,
            backgroundColor: SaoColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    });

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[SaoColors.actionPrimary, SaoColors.brandPrimary],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -120,
              right: -70,
              child: _AmbientBlob(
                size: 260,
                color: SaoColors.warning.withValues(alpha: 0.18),
              ),
            ),
            Positioned(
              bottom: -140,
              left: -90,
              child: _AmbientBlob(
                size: 310,
                color: SaoColors.info.withValues(alpha: 0.16),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(SaoSpacing.xxl),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Container(
                      padding: const EdgeInsets.all(SaoSpacing.xxl),
                      decoration: BoxDecoration(
                        color: SaoColors.surface.withValues(alpha: 0.96),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: SaoColors.gray200.withValues(alpha: 0.7),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.22),
                            blurRadius: 32,
                            offset: const Offset(0, 18),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: Container(
                                width: 108,
                                height: 108,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: SaoColors.surface,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: SaoColors.gray200),
                                ),
                                child: Image.asset(
                                  'assets/branding/sao_logo.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            const SizedBox(height: SaoSpacing.lg),
                            const Text(
                              'SAO',
                              style: SaoTypography.pageTitle,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: SaoSpacing.xs),
                            Text(
                              'Sistema de administración Operativa',
                              style: SaoTypography.bodyText.copyWith(
                                color: SaoColors.gray600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: SaoSpacing.sm),
                            Text(
                              'Accede para continuar con tu operación diaria',
                              style: SaoTypography.bodyText.copyWith(
                                color: SaoColors.gray500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: SaoSpacing.xxxl),
                            SaoInput(
                              label: 'Correo electrónico',
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              onChanged: _handleEmailChanged,
                              prefixIcon: const Icon(Icons.email_outlined),
                              validator: _validateEmail,
                            ),
                            const SizedBox(height: SaoSpacing.lg),
                            SaoInput(
                              label: 'Contraseña',
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              prefixIcon: const Icon(Icons.lock_outlined),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              validator: _validatePassword,
                            ),
                            const SizedBox(height: SaoSpacing.xxxl),
                            SaoButton.primary(
                              label: 'Iniciar sesión',
                              onPressed: isLoading ? null : _handleLogin,
                              isLoading: isLoading,
                              icon: Icons.login,
                            ),
                            if (_biometricEnabled && _biometricReady) ...[
                              const SizedBox(height: SaoSpacing.md),
                              SaoButton.secondary(
                                label: 'Entrar con huella',
                                onPressed: isLoading
                                    ? null
                                    : _handleBiometricLogin,
                                icon: Icons.fingerprint,
                              ),
                            ],
                            const SizedBox(height: SaoSpacing.md),
                            TextButton(
                              onPressed: isLoading
                                  ? null
                                  : () => context.go('/auth/signup'),
                              child: const Text('Crear cuenta'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AmbientBlob extends StatelessWidget {
  final double size;
  final Color color;

  const _AmbientBlob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
