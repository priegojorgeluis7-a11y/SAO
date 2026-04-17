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
import '../data/models/signup_request.dart';

class SignupPage extends ConsumerStatefulWidget {
  const SignupPage({super.key});

  @override
  ConsumerState<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends ConsumerState<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _secondLastNameController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _inviteCodeController = TextEditingController();

  DateTime? _birthDate;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _obscureInviteCode = true;
  String? _selectedRole;
  List<String> _roles = const [];
  bool _loadingRoles = true;
  String? _rolesError;

  @override
  void initState() {
    super.initState();
    _loadRoles();
  }

  Future<void> _loadRoles() async {
    setState(() {
      _loadingRoles = true;
      _rolesError = null;
    });

    try {
      final roles = await ref.read(authRepositoryProvider).fetchSignupRoles();
      if (!mounted) return;
      setState(() {
        _roles = roles;
        if (_selectedRole == null && roles.isNotEmpty) {
          _selectedRole = roles.first;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _rolesError = 'No se pudieron cargar los roles';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingRoles = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _secondLastNameController.dispose();
    _birthDateController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Ingresa tu correo electrónico';
    }
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Formato de correo inválido';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Ingresa tu contraseña';
    }
    if (value.length < 8) {
      return 'La contraseña debe tener al menos 8 caracteres';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Confirma tu contraseña';
    }
    if (value != _passwordController.text) {
      return 'Las contraseñas no coinciden';
    }
    return null;
  }

  String? _validateRequiredName(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return 'Ingresa $label';
    }
    return null;
  }

  String? _validateBirthDate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Selecciona tu cumpleaños';
    }
    return null;
  }

  String _normalizeName(String value) {
    final compact = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (compact.isEmpty) return '';
    return compact
        .split(' ')
        .map((word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
        .join(' ');
  }

  void _normalizeControllerText(
    TextEditingController controller,
    String raw,
    String Function(String) normalizer,
  ) {
    final normalized = normalizer(raw);
    if (normalized == raw) return;
    controller.value = TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
    );
  }

  void _handleNameChanged(TextEditingController controller, String value) {
    _normalizeControllerText(controller, value, _normalizeName);
  }

  void _handleEmailChanged(String value) {
    _normalizeControllerText(
      _emailController,
      value,
      (input) => input.toLowerCase(),
    );
  }

  String _buildFullName() {
    return [
      _normalizeName(_firstNameController.text),
      _normalizeName(_lastNameController.text),
      _normalizeName(_secondLastNameController.text),
    ].where((part) => part.isNotEmpty).join(' ');
  }

  String? _birthDateIso() {
    final selected = _birthDate;
    if (selected == null) return null;
    final month = selected.month.toString().padLeft(2, '0');
    final day = selected.day.toString().padLeft(2, '0');
    return '${selected.year}-$month-$day';
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900, 1, 1),
      lastDate: now,
      helpText: 'Selecciona la fecha de cumpleaños',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _birthDate = picked;
      final month = picked.month.toString().padLeft(2, '0');
      final day = picked.day.toString().padLeft(2, '0');
      _birthDateController.text = '$day/$month/${picked.year}';
    });
  }

  String? _validateInviteCode(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Ingresa la clave de alta';
    }
    return null;
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRole == null || _selectedRole!.isEmpty) {
      showTransientSnackBar(
        context,
        appSnackBar(message: 'Selecciona un rol', backgroundColor: SaoColors.error),
      );
      return;
    }

    final firstName = _normalizeName(_firstNameController.text);
    final lastName = _normalizeName(_lastNameController.text);
    final secondLastName = _normalizeName(_secondLastNameController.text);
    final birthDateIso = _birthDateIso();

    final request = SignupRequest(
      displayName: _buildFullName(),
      firstName: firstName,
      lastName: lastName,
      secondLastName: secondLastName,
      birthDate: birthDateIso,
      email: _emailController.text.trim().toLowerCase(),
      password: _passwordController.text,
      role: _selectedRole!,
      inviteCode: _inviteCodeController.text.trim(),
    );

    final ok = await ref.read(signupControllerProvider.notifier).signup(request);
    if (!mounted) return;

    if (ok) {
      showTransientSnackBar(
        context,
        appSnackBar(message: 'Cuenta creada', backgroundColor: SaoColors.success),
      );
      context.go('/auth/login');
    } else {
      final error = ref.read(signupControllerProvider).error ?? 'No se pudo crear la cuenta';
      showTransientSnackBar(
        context,
        appSnackBar(message: error, backgroundColor: SaoColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(signupControllerProvider);

    return Scaffold(
      backgroundColor: SaoColors.surface,
      appBar: AppBar(
        title: const Text('Crear cuenta'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(SaoSpacing.xxl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Registro de usuario',
                      style: SaoTypography.pageTitle,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: SaoSpacing.xl),
                    SaoInput(
                      label: 'Nombre',
                      controller: _firstNameController,
                      onChanged: (value) => _handleNameChanged(_firstNameController, value),
                      validator: (value) => _validateRequiredName(value, 'tu nombre'),
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                    const SizedBox(height: SaoSpacing.lg),
                    SaoInput(
                      label: 'Apellido paterno',
                      controller: _lastNameController,
                      onChanged: (value) => _handleNameChanged(_lastNameController, value),
                      validator: (value) => _validateRequiredName(value, 'tu apellido paterno'),
                      prefixIcon: const Icon(Icons.badge_outlined),
                    ),
                    const SizedBox(height: SaoSpacing.lg),
                    SaoInput(
                      label: 'Segundo apellido',
                      controller: _secondLastNameController,
                      onChanged: (value) => _handleNameChanged(_secondLastNameController, value),
                      prefixIcon: const Icon(Icons.badge_outlined),
                    ),
                    const SizedBox(height: SaoSpacing.lg),
                    SaoInput(
                      label: 'Cumpleaños',
                      controller: _birthDateController,
                      readOnly: true,
                      onTap: _pickBirthDate,
                      validator: _validateBirthDate,
                      prefixIcon: const Icon(Icons.cake_outlined),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.calendar_month_outlined),
                        onPressed: _pickBirthDate,
                      ),
                    ),
                    const SizedBox(height: SaoSpacing.lg),
                    SaoInput(
                      label: 'Correo electrónico',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      onChanged: _handleEmailChanged,
                      validator: _validateEmail,
                      prefixIcon: const Icon(Icons.email_outlined),
                    ),
                    const SizedBox(height: SaoSpacing.lg),
                    SaoInput(
                      label: 'Contraseña',
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      validator: _validatePassword,
                      prefixIcon: const Icon(Icons.lock_outline),
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
                    ),
                    const SizedBox(height: SaoSpacing.lg),
                    SaoInput(
                      label: 'Confirmar contraseña',
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      validator: _validateConfirmPassword,
                      prefixIcon: const Icon(Icons.lock_person_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: SaoSpacing.lg),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'Rol',
                        border: OutlineInputBorder(),
                      ),
                      items: _roles
                          .map((role) => DropdownMenuItem<String>(
                                value: role,
                                child: Text(role),
                              ))
                          .toList(),
                      onChanged: state.isLoading || _loadingRoles
                          ? null
                          : (value) {
                              setState(() {
                                _selectedRole = value;
                              });
                            },
                      validator: (value) => (value == null || value.isEmpty)
                          ? 'Selecciona un rol'
                          : null,
                    ),
                    if (_loadingRoles)
                      const Padding(
                        padding: EdgeInsets.only(top: SaoSpacing.sm),
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                    if (_rolesError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: SaoSpacing.sm),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _rolesError!,
                              style: SaoTypography.bodyTextSmall
                                  .copyWith(color: SaoColors.error),
                            ),
                            const SizedBox(height: SaoSpacing.xs),
                            TextButton.icon(
                              onPressed: state.isLoading || _loadingRoles
                                  ? null
                                  : _loadRoles,
                              icon: const Icon(Icons.refresh, size: 18),
                              label: const Text('Reintentar cargar roles'),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: SaoSpacing.sm),
                    if (_selectedRole == 'ADMIN')
                      Text(
                        'ADMIN requiere clave especial.',
                        style: SaoTypography.bodyTextSmall.copyWith(color: SaoColors.gray600),
                      ),
                    const SizedBox(height: SaoSpacing.lg),
                    SaoInput(
                      label: 'Clave de alta',
                      controller: _inviteCodeController,
                      obscureText: _obscureInviteCode,
                      validator: _validateInviteCode,
                      prefixIcon: const Icon(Icons.vpn_key_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureInviteCode
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureInviteCode = !_obscureInviteCode;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: SaoSpacing.xxl),
                    SaoButton.primary(
                      label: 'Crear cuenta',
                      onPressed: state.isLoading ? null : _handleSignup,
                      isLoading: state.isLoading,
                      icon: Icons.person_add_alt_1,
                    ),
                    const SizedBox(height: SaoSpacing.md),
                    TextButton(
                      onPressed:
                          state.isLoading ? null : () => context.go('/auth/login'),
                      child: const Text('Ya tengo cuenta'),
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
