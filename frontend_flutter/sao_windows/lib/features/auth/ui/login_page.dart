// lib/features/auth/ui/login_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
  bool _tutorialMode = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_tutorialMode) {
      if (mounted) {
        context.go('/tutorial');
      }
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    await ref
      .read(authControllerProvider.notifier)
      .login(email, password);
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Ingresa tu correo electrónico';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: SaoColors.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: SaoColors.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(SaoSpacing.xxl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo/Branding
                    const Icon(
                      Icons.account_balance_outlined,
                      size: 64,
                      color: SaoColors.primary,
                    ),
                    const SizedBox(height: SaoSpacing.lg),

                    // Title
                    const Text(
                      'SAO',
                      style: SaoTypography.pageTitle,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: SaoSpacing.xs),

                    // Subtitle
                    Text(
                      'Sistema de Administración de Obras',
                      style: SaoTypography.bodyText.copyWith(
                        color: SaoColors.gray600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: SaoSpacing.xxxl),

                    // Email Input
                    SaoInput(
                      label: 'Correo electrónico',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: const Icon(Icons.email_outlined),
                      validator: _validateEmail,
                    ),
                    const SizedBox(height: SaoSpacing.lg),

                    // Password Input
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
                    const SizedBox(height: SaoSpacing.md),

                    SwitchListTile.adaptive(
                      value: _tutorialMode,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Entrar en modo tutorial'),
                      subtitle: Text(
                        'Al iniciar sesión se abrirá una guía del flujo operativo',
                        style: SaoTypography.bodyTextSmall.copyWith(
                          color: SaoColors.gray600,
                        ),
                      ),
                      onChanged: isLoading
                          ? null
                          : (value) {
                              setState(() {
                                _tutorialMode = value;
                              });
                            },
                    ),
                    const SizedBox(height: SaoSpacing.xxxl),

                    // Login Button
                    SaoButton.primary(
                      label: _tutorialMode ? 'Entrar a tutorial' : 'Iniciar sesión',
                      onPressed: isLoading ? null : _handleLogin,
                      isLoading: isLoading,
                      icon: _tutorialMode ? Icons.school_outlined : Icons.login,
                    ),
                    const SizedBox(height: SaoSpacing.md),
                    TextButton(
                      onPressed: isLoading ? null : () => context.go('/auth/signup'),
                      child: const Text('Crear cuenta'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
