import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;

import '../auth/app_session_controller.dart';
import '../calendar/calendar_settings_provider.dart';

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
    if (n.isEmpty) return ('Sin rol', cs.outline);
    if (n.contains('admin')) return ('Administrador', cs.primary);
    if (n.contains('coord')) return ('Coordinador', Colors.indigo);
    if (n.contains('supervisor')) return ('Supervisor', Colors.orange);
    if (n.contains('lector') || n.contains('view') || n.contains('lectura')) {
      return ('Lector', Colors.grey);
    }
    if (
      n.contains('operat') ||
      n.contains('operador') ||
      n.contains('tecnico') ||
      n.contains('técnico') ||
      n.contains('ingeniero') ||
      n.contains('topografo') ||
      n.contains('topógrafo')
    ) {
      return ('Operativo', Colors.teal);
    }
    return ('Operativo', cs.secondary);
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
            final canUseCalendar =
                user?.isAdmin == true || user?.hasRole('COORD') == true;
            final leftCard = _LeftCard(
              name: name,
              role: role,
              roleLabel: roleLabel,
              roleColor: roleColor,
              initials: initials,
              onLogout: () => _confirmLogout(context, ref),
            );
            final rightCards = _RightCards(
              email: email,
              userId: userId,
              showCalendar: canUseCalendar,
            );

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
  final bool showCalendar;

  const _RightCards({
    required this.email,
    required this.userId,
    this.showCalendar = false,
  });

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
        if (widget.showCalendar) ...[          const SizedBox(height: 16),
          const _GoogleCalendarCard(),
        ],
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

// ── Google Calendar card ───────────────────────────────────────────────────

/// Shown only to ADMIN and COORD users.
/// Allows connecting a Google account and selecting a target calendar
/// so that planning assignments are automatically synced.
class _GoogleCalendarCard extends ConsumerStatefulWidget {
  const _GoogleCalendarCard();

  @override
  ConsumerState<_GoogleCalendarCard> createState() =>
      _GoogleCalendarCardState();
}

class _GoogleCalendarCardState extends ConsumerState<_GoogleCalendarCard> {
  bool _loading = false;
  String? _error;

  Future<void> _connect() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = ref.read(desktopCalendarSyncServiceProvider);
      final account = await service.signIn();
      if (account == null) {
        setState(() => _loading = false);
        return;
      }
      final calendars = await service.listCalendars();
      if (!mounted) return;

      if (calendars.isEmpty) {
        setState(() {
          _error = 'No se encontraron calendarios con acceso de escritura.';
          _loading = false;
        });
        return;
      }

      final picked = await _showCalendarPicker(calendars);
      if (picked == null) {
        setState(() => _loading = false);
        return;
      }

      await ref.read(desktopCalendarSettingsProvider.notifier).connect(
            calendarId: picked.id!,
            calendarName: picked.summary ?? picked.id!,
            accountEmail: account.email,
          );
    } catch (e) {
      if (mounted) setState(() => _error = 'Error al conectar: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _disconnect() async {
    setState(() => _loading = true);
    try {
      await ref.read(desktopCalendarSyncServiceProvider).signOut();
      await ref.read(desktopCalendarSettingsProvider.notifier).disconnect();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<gcal.CalendarListEntry?> _showCalendarPicker(
      List<gcal.CalendarListEntry> calendars) {
    return showDialog<gcal.CalendarListEntry>(
      context: context,
      builder: (ctx) => _CalendarPickerDialog(calendars: calendars),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final settings = ref.watch(desktopCalendarSettingsProvider);
    final connected = settings.isConnected;

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
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 13, 16, 11),
            child: Row(
              children: [
                Icon(Icons.calendar_month_outlined,
                    size: 15, color: cs.primary),
                const SizedBox(width: 7),
                Text(
                  'Google Calendar',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: connected
                        ? Colors.green.withValues(alpha: 0.12)
                        : cs.outline.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: connected
                          ? Colors.green.withValues(alpha: 0.4)
                          : cs.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    connected ? 'Conectado' : 'Desconectado',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: connected ? Colors.green.shade700 : cs.outline,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Theme.of(context).dividerColor),

          // Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (connected) ...[
                  _Row(
                    label: 'Calendario',
                    value: settings.calendarName ?? '—',
                  ),
                  const SizedBox(height: 4),
                  _Row(
                    label: 'Cuenta',
                    value: settings.accountEmail ?? '—',
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _loading ? null : _connect,
                        icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                        label: const Text('Cambiar'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _loading ? null : _disconnect,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: cs.error,
                          side:
                              BorderSide(color: cs.error.withValues(alpha: 0.5)),
                        ),
                        icon: const Icon(Icons.link_off_rounded, size: 16),
                        label: const Text('Desconectar'),
                      ),
                    ],
                  ),
                ] else ...[
                  Text(
                    'Sincroniza las asignaciones de planeación con tu Google Calendar.',
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _loading ? null : _connect,
                    icon: _loading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.add_link_rounded, size: 16),
                    label: Text(_loading ? 'Conectando…' : 'Conectar con Google'),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style: TextStyle(fontSize: 12, color: cs.error),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;

  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _CalendarPickerDialog extends StatefulWidget {
  final List<gcal.CalendarListEntry> calendars;

  const _CalendarPickerDialog({required this.calendars});

  @override
  State<_CalendarPickerDialog> createState() => _CalendarPickerDialogState();
}

class _CalendarPickerDialogState extends State<_CalendarPickerDialog> {
  gcal.CalendarListEntry? _selected;

  @override
  void initState() {
    super.initState();
    if (widget.calendars.isNotEmpty) _selected = widget.calendars.first;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Seleccionar calendario'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Elige el calendario de Google donde se sincronizarán las asignaciones de planeación.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            ...widget.calendars.map(
              (cal) {
                final isSelected = _selected == cal;
                return InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => setState(() => _selected = cal),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Icon(
                          isSelected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          size: 18,
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(cal.summary ?? cal.id ?? '—',
                                  style: const TextStyle(fontSize: 13)),
                              Text(cal.id ?? '',
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _selected == null
              ? null
              : () => Navigator.pop(context, _selected),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
