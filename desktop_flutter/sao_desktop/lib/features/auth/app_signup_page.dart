import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import 'app_session_controller.dart';

class AppSignupPage extends ConsumerStatefulWidget {
  final VoidCallback onBackToLogin;

  const AppSignupPage({
    required this.onBackToLogin,
    super.key,
  });

  @override
  ConsumerState<AppSignupPage> createState() => _AppSignupPageState();
}

class _AppSignupPageState extends ConsumerState<AppSignupPage> {
  static const _roles = ['OPERATIVO', 'COORD', 'SUPERVISOR', 'LECTOR'];

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _secondLastNameController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _inviteCodeController = TextEditingController();

  DateTime? _birthDate;
  String _selectedRole = 'OPERATIVO';
  bool _obscurePassword = true;
  bool _obscurePasswordConfirm = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _secondLastNameController.dispose();
    _birthDateController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
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
    if (picked == null) return;
    setState(() {
      _birthDate = picked;
      final month = picked.month.toString().padLeft(2, '0');
      final day = picked.day.toString().padLeft(2, '0');
      _birthDateController.text = '$day/$month/${picked.year}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(appSessionControllerProvider);
    final isLoading = session.loading;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary, AppColors.primaryLight],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: AppColors.gray200.withValues(alpha: 0.75)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.22),
                        blurRadius: 30,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 108,
                          height: 108,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.gray100,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.gray200),
                          ),
                          child: Image.asset(
                            'assets/images/logo_tren.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Crear Cuenta',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'SAO - Sistema de Administración Operativa',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: AppColors.gray600),
                      ),
                      const SizedBox(height: 24),
                      // Email
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        onChanged: _handleEmailChanged,
                        decoration: InputDecoration(
                          labelText: 'Correo electrónico',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.email_outlined),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _firstNameController,
                        textInputAction: TextInputAction.next,
                        textCapitalization: TextCapitalization.words,
                        onChanged: (value) => _handleNameChanged(_firstNameController, value),
                        decoration: InputDecoration(
                          labelText: 'Nombre *',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.person_outlined),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _lastNameController,
                        textInputAction: TextInputAction.next,
                        textCapitalization: TextCapitalization.words,
                        onChanged: (value) => _handleNameChanged(_lastNameController, value),
                        decoration: InputDecoration(
                          labelText: 'Apellido paterno *',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.badge_outlined),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _secondLastNameController,
                        textInputAction: TextInputAction.next,
                        textCapitalization: TextCapitalization.words,
                        onChanged: (value) => _handleNameChanged(_secondLastNameController, value),
                        decoration: InputDecoration(
                          labelText: 'Segundo apellido',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.badge_outlined),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _birthDateController,
                        readOnly: true,
                        onTap: _pickBirthDate,
                        decoration: InputDecoration(
                          labelText: 'Cumpleaños *',
                          hintText: 'dd/mm/aaaa',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.cake_outlined),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.calendar_month_outlined),
                            onPressed: _pickBirthDate,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Password
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.lock_outlined),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () {
                              setState(() => _obscurePassword = !_obscurePassword);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Confirm Password
                      TextField(
                        controller: _passwordConfirmController,
                        obscureText: _obscurePasswordConfirm,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Confirmar contraseña',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.lock_outlined),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePasswordConfirm
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () {
                              setState(() => _obscurePasswordConfirm = !_obscurePasswordConfirm);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Rol de invitación',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _roles
                            .map(
                              (role) => ChoiceChip(
                                label: Text(role),
                                selected: _selectedRole == role,
                                onSelected: (_) {
                                  setState(() => _selectedRole = role);
                                },
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 14),
                      // Invite Code
                      TextField(
                        controller: _inviteCodeController,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _doSignup(),
                        decoration: InputDecoration(
                          labelText: 'Código de invitación',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.card_giftcard_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.28)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: AppColors.primary, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Selecciona el rol que coincide con tu código de invitación.',
                                style: TextStyle(color: AppColors.primary.withValues(alpha: 0.8), fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Signup Button
                      FilledButton.icon(
                        onPressed: isLoading ? null : _doSignup,
                        icon: const Icon(Icons.person_add_rounded),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        label: isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Crear Cuenta'),
                      ),
                      const SizedBox(height: 10),
                      // Back to Login
                      OutlinedButton.icon(
                        onPressed: isLoading ? null : widget.onBackToLogin,
                        icon: const Icon(Icons.arrow_back_rounded),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        label: const Text('Volver al Login'),
                      ),
                      // Error Message
                      if (session.error != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.error.withValues(alpha: 0.28)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  session.error!,
                                  style: const TextStyle(color: AppColors.error, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _doSignup() {
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;
    final passwordConfirm = _passwordConfirmController.text;
    final firstName = _normalizeName(_firstNameController.text);
    final lastName = _normalizeName(_lastNameController.text);
    final secondLastName = _normalizeName(_secondLastNameController.text);
    final displayName = _buildFullName();
    final inviteCode = _inviteCodeController.text.trim();
    final birthDateIso = _birthDateIso();

    // Validations
    if (email.isEmpty) {
      ref.read(appSessionControllerProvider.notifier).setLoginError('Por favor ingresa un email');
      return;
    }
    if (!email.contains('@')) {
      ref.read(appSessionControllerProvider.notifier).setLoginError('Email inválido');
      return;
    }
    if (firstName.isEmpty) {
      ref.read(appSessionControllerProvider.notifier).setLoginError('Por favor ingresa el nombre');
      return;
    }
    if (lastName.isEmpty) {
      ref.read(appSessionControllerProvider.notifier).setLoginError('Por favor ingresa el apellido paterno');
      return;
    }
    if (birthDateIso == null) {
      ref.read(appSessionControllerProvider.notifier).setLoginError('Por favor selecciona el cumpleaños');
      return;
    }
    if (password.isEmpty || password.length < 6) {
      ref.read(appSessionControllerProvider.notifier).setLoginError('La contraseña debe tener al menos 6 caracteres');
      return;
    }
    if (password != passwordConfirm) {
      ref.read(appSessionControllerProvider.notifier).setLoginError('Las contraseñas no coinciden');
      return;
    }
    if (inviteCode.isEmpty) {
      ref.read(appSessionControllerProvider.notifier).setLoginError('Por favor ingresa el código de invitación');
      return;
    }

    ref.read(appSessionControllerProvider.notifier).signup(
          email: email,
          password: password,
          displayName: displayName,
          inviteCode: inviteCode,
          role: _selectedRole,
          firstName: firstName,
          lastName: lastName,
          secondLastName: secondLastName,
          birthDate: birthDateIso,
        );
  }
}
