import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_config.dart';
import '../../../ui/sao_ui.dart';
import '../../../ui/theme/sao_colors.dart';
import '../data/auth_provider.dart';

/// Pantalla de inicio de sesión mejorada para operativos de campo
/// Soporta login online/offline con biometría
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController(text: 'admin@sao.mx');
  final _passwordController = TextEditingController(text: 'admin123');
  bool _obscurePassword = true;
  bool _rememberMe = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);

    // Auto-redirect si ya está autenticado
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.isAuthenticated && !next.isLoading) {
        context.go('/');
      }
    });

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.primary,
              theme.colorScheme.primary.withOpacity(0.8),
              SaoColors.surface,
            ],
            stops: const [0.0, 0.3, 0.7],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Warning banner para modo offline
                    if (authState.isOffline)
                      _buildOfflineBanner(theme),

                    const SizedBox(height: 24),

                    // Logo y branding
                    _buildBranding(theme),

                    const SizedBox(height: 48),

                    // Card de login
                    Card(
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            // Mensaje de bienvenida si hay último usuario
                            if (authState.lastUserEmail != null && !authState.isAuthenticated)
                              _buildWelcomeBack(authState.lastUserEmail!, theme),

                            // Formulario de login
                            _buildLoginForm(theme, authState),

                            const SizedBox(height: 16),

                            // Checkbox "Recordarme"
                            _buildRememberMe(theme),

                            const SizedBox(height: 24),

                            // Botón de inicio de sesión
                            _buildLoginButton(authState),

                            // Biometría (si está disponible y hay sesión guardada)
                            if (authState.lastUserEmail != null)
                              _buildBiometricLogin(theme),

                            const SizedBox(height: 16),

                            // Enlace "Olvidé mi contraseña"
                            _buildForgotPassword(theme),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Footer con versión
                    _buildFooter(theme),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOfflineBanner(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: SaoColors.alertBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SaoColors.alertBorder),
      ),
      child: const Row(
        children: [
          Icon(Icons.wifi_off, color: SaoColors.warning, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              '⚠️ Modo Sin Conexión',
              style: TextStyle(
                color: SaoColors.alertText,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBranding(ThemeData theme) {
    return Column(
      children: [
        // Logo (usando icono de construcción/tren)
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: SaoColors.surface,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: SaoColors.primary.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Icon(
            Icons.train,
            size: 50,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 24),
        // Nombre del sistema
        const Text(
          'SAO Sistema',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: SaoColors.surface,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        // Subtítulo
        Text(
          AppConfig.appFullName,
          style: TextStyle(
            fontSize: 14,
            color: SaoColors.surface.withOpacity(0.9),
            letterSpacing: 0.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildWelcomeBack(String email, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Text(
              email[0].toUpperCase(),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Hola de nuevo',
            style: theme.textTheme.titleMedium?.copyWith(
              color: SaoColors.gray600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            email,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm(ThemeData theme, AuthState authState) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Campo de email
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            enabled: !authState.isLoading && !authState.isOffline,
            decoration: InputDecoration(
              labelText: 'Correo Electrónico',
              hintText: 'usuario@empresa.mx',
              prefixIcon: const Icon(Icons.email_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Ingresa tu correo electrónico';
              }
              if (!value.contains('@')) {
                return 'Formato de correo inválido';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          // Campo de contraseña
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            enabled: !authState.isLoading && !authState.isOffline,
            decoration: InputDecoration(
              labelText: 'Contraseña',
              hintText: '••••••••',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Ingresa tu contraseña';
              }
              if (value.length < 6) {
                return 'La contraseña debe tener al menos 6 caracteres';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRememberMe(ThemeData theme) {
    return Row(
      children: [
        Checkbox(
          value: _rememberMe,
          onChanged: (value) {
            setState(() {
              _rememberMe = value ?? false;
            });
          },
        ),
        const Text('Recordarme'),
      ],
    );
  }

  Widget _buildLoginButton(AuthState authState) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton(
        onPressed: authState.isLoading || authState.isOffline
            ? null
            : _handleLogin,
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: authState.isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: SaoColors.onActionPrimary,
                ),
              )
            : const Text(
                'INICIAR SESIÓN',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
      ),
    );
  }

  Widget _buildBiometricLogin(ThemeData theme) {
    return FutureBuilder<bool>(
      future: ref.read(authProvider.notifier).canUseBiometrics(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!) {
          return const SizedBox.shrink();
        }

        return FutureBuilder<bool>(
          future: ref.read(authProvider.notifier).isBiometricEnabled(),
          builder: (context, enabledSnapshot) {
            if (!enabledSnapshot.hasData) {
              return const SizedBox.shrink();
            }

            final isEnabled = enabledSnapshot.data!;

            return Column(
              children: [
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('o'),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: _handleBiometricLogin,
                    icon: const Icon(Icons.fingerprint, size: 28),
                    label: const Text(
                      'Ingresar con Biométricos',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                if (!isEnabled)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Habilita biometría en ajustes después de iniciar sesión',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: SaoColors.gray600,
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildForgotPassword(ThemeData theme) {
    return TextButton(
      onPressed: () {
        // TODO: Implementar recuperación de contraseña
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contacta al administrador para restablecer tu contraseña'),
            duration: Duration(seconds: 3),
          ),
        );
      },
      child: const Text('¿Olvidaste tu contraseña?'),
    );
  }

  Widget _buildFooter(ThemeData theme) {
    return const Text(
      AppConfig.appVersion,
      style: TextStyle(
        fontSize: 12,
        color: SaoColors.gray600,
      ),
    );
  }

  Future<void> _handleLogin() async {
    // Limpiar errores anteriores
    ref.read(authProvider.notifier).clearError();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final success = await ref.read(authProvider.notifier).login(
          _emailController.text.trim(),
          _passwordController.text,
        );

    if (!success && mounted) {
      final error = ref.read(authProvider).error;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text(error)),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _handleBiometricLogin() async {
    // Limpiar errores anteriores
    ref.read(authProvider.notifier).clearError();

    final success = await ref.read(authProvider.notifier).loginWithBiometrics();

    if (!success && mounted) {
      final error = ref.read(authProvider).error;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: SaoColors.surface),
                const SizedBox(width: 12),
                Expanded(child: Text(error)),
              ],
            ),
            backgroundColor: SaoColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}
