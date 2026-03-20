import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/app_session_controller.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  static const Color _softBorder = Color(0xFFE5E7EB);
  static const List<BoxShadow> _softShadow = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || name.trim().isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  (String label, Color color) _roleInfo(String role, ColorScheme cs) {
    final n = role.toLowerCase().trim();
    if (n.contains('admin')) return ('Admin', cs.primary);
    if (n.contains('supervisor')) return ('Supervisor', Colors.orange);
    if (n.contains('tecnico') || n.contains('técnico')) return ('Técnico', Colors.teal);
    if (n.contains('operador')) return ('Operador', Colors.indigo);
    if (n.contains('viewer') || n.contains('lectura')) return ('Solo lectura', Colors.grey);
    if (n.isEmpty) return ('Sin rol', cs.outline);
    // Return text-cased version of whatever role the backend sends
    return (role[0].toUpperCase() + role.substring(1).toLowerCase(), cs.secondary);
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true) {
        ref.read(appSessionControllerProvider.notifier).logout();
      }
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentAppUserProvider);
    final cs = Theme.of(context).colorScheme;

    final name = user?.fullName.isNotEmpty == true ? user!.fullName : '—';
    final email = user?.email ?? '—';
    final role = user?.role ?? '';
    final userId = user?.id ?? '—';
    final initials = user != null && user.fullName.isNotEmpty
        ? _initials(user.fullName)
        : '?';
    final (roleLabel, roleColor) = _roleInfo(role, cs);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Page header ────────────────────────────────────────────────
          Row(
            children: [
              Icon(Icons.person_rounded, size: 20, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                'Perfil',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Two-column layout ──────────────────────────────────────────
          LayoutBuilder(builder: (context, constraints) {
            final wide = constraints.maxWidth > 680;
            final leftCard = _LeftCard(
              name: name,
              role: role,
              roleLabel: roleLabel,
              roleColor: roleColor,
              initials: initials,
              onLogout: () => _confirmLogout(context, ref),
            );
            final rightCards = _RightCards(email: email, userId: userId);

            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 252, child: leftCard),
                  const SizedBox(width: 20),
                  Expanded(child: rightCards),
                ],
              );
            }
            return Column(
              children: [leftCard, const SizedBox(height: 20), rightCards],
            );
          }),
        ],
      ),
    );
  }
}

// ── Left card ──────────────────────────────────────────────────────────────

class _LeftCard extends StatelessWidget {
  final String name;
  final String role;
  final String roleLabel;
  final Color roleColor;
  final String initials;
  final VoidCallback onLogout;

  const _LeftCard({
    required this.name,
    required this.role,
    required this.roleLabel,
    required this.roleColor,
    required this.initials,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border.all(color: ProfilePage._softBorder),
        borderRadius: BorderRadius.circular(14),
        boxShadow: ProfilePage._softShadow,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        children: [
          // Avatar
          CircleAvatar(
            radius: 46,
            backgroundColor: cs.primary.withValues(alpha: 0.13),
            child: Text(
              initials,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: cs.primary,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Name (largest element)
          Text(
            name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 10),

          // Role badge
          if (role.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: roleColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: roleColor.withValues(alpha: 0.4)),
              ),
              child: Text(
                roleLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: roleColor,
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: cs.outline.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
              ),
              child: Text(
                'Sin rol asignado',
                style: TextStyle(
                  fontSize: 12,
                  color: cs.outline,
                ),
              ),
            ),

          const SizedBox(height: 24),
          Divider(color: Theme.of(context).dividerColor),
          const SizedBox(height: 16),

          // Actions
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Editar perfil'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.lock_outline, size: 16),
              label: const Text('Cambiar contraseña'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onLogout,
              style: OutlinedButton.styleFrom(
                foregroundColor: cs.error,
                side: BorderSide(color: cs.error.withValues(alpha: 0.5)),
              ),
              icon: const Icon(Icons.logout_rounded, size: 16),
              label: const Text('Cerrar sesión'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Right cards ────────────────────────────────────────────────────────────

class _RightCards extends StatefulWidget {
  final String email;
  final String userId;

  const _RightCards({required this.email, required this.userId});

  @override
  State<_RightCards> createState() => _RightCardsState();
}

class _RightCardsState extends State<_RightCards> {
  bool _idCopied = false;

  Future<void> _copyId() async {
    await Clipboard.setData(ClipboardData(text: widget.userId));
    setState(() => _idCopied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _idCopied = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final divColor = Theme.of(context).dividerColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Información de Contacto
        _SectionCard(
          title: 'Información de Contacto',
          icon: Icons.contact_mail_outlined,
          children: [
            _LabelValueGrid(label: 'Correo electrónico', value: widget.email),
          ],
        ),
        const SizedBox(height: 16),

        // Cuenta
        _SectionCard(
          title: 'Cuenta',
          icon: Icons.manage_accounts_outlined,
          children: [
            _LabelValueGrid(
              label: 'ID de usuario',
              value: widget.userId,
              monospace: true,
              trailing: Tooltip(
                message: _idCopied ? '¡Copiado!' : 'Copiar ID',
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: _copyId,
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: Icon(
                      _idCopied ? Icons.check_rounded : Icons.copy_rounded,
                      size: 16,
                      color: _idCopied
                          ? Colors.green
                          : cs.onSurface.withValues(alpha: 0.35),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Preferencias
        _SectionCard(
          title: 'Preferencias',
          icon: Icons.tune_outlined,
          children: [
            const _LabelValueGrid(label: 'Tema de interfaz', value: 'Sistema'),
            Divider(height: 1, color: divColor),
            const _LabelValueGrid(label: 'Idioma', value: 'Español'),
          ],
        ),
      ],
    );
  }
}

// ── Shared sub-widgets ─────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border.all(color: ProfilePage._softBorder),
        borderRadius: BorderRadius.circular(14),
        boxShadow: ProfilePage._softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 13, 16, 11),
            child: Row(
              children: [
                Icon(icon, size: 15, color: cs.primary),
                const SizedBox(width: 7),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Theme.of(context).dividerColor),
          ...children,
        ],
      ),
    );
  }
}

class _LabelValueGrid extends StatelessWidget {
  final String label;
  final String value;
  final bool monospace;
  final Widget? trailing;

  const _LabelValueGrid({
    required this.label,
    required this.value,
    this.monospace = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final labelWidth = constraints.maxWidth * 0.30;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              SizedBox(
                width: labelWidth,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: monospace ? 'monospace' : null,
                    color: cs.onSurface,
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
        );
      },
    );
  }
}
