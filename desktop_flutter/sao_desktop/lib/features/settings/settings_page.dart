import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/data_mode.dart';
import '../../core/providers/app_refresh_provider.dart';
import '../../core/theme/theme_provider.dart';
import '../../features/auth/app_session_controller.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark    = themeMode == ThemeMode.dark;
    final cs        = Theme.of(context).colorScheme;
    const backendUrl = AppDataMode.backendBaseUrl;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Apariencia ───────────────────────────────────────────────
              const _SectionHeader(
                  title: 'Apariencia', icon: Icons.palette_rounded),
              const SizedBox(height: 12),
              _SettingsCard(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 140,
                          child: Text(
                            'Tema',
                            style: TextStyle(
                              fontSize: 13,
                              color: cs.onSurface.withValues(alpha: 0.55),
                            ),
                          ),
                        ),
                        Expanded(
                          child: SegmentedButton<ThemeMode>(
                            segments: const [
                              ButtonSegment(
                                value: ThemeMode.light,
                                icon: Icon(Icons.light_mode_rounded, size: 16),
                                label: Text('Claro'),
                              ),
                              ButtonSegment(
                                value: ThemeMode.dark,
                                icon: Icon(Icons.dark_mode_rounded, size: 16),
                                label: Text('Oscuro'),
                              ),
                              ButtonSegment(
                                value: ThemeMode.system,
                                icon: Icon(Icons.contrast_rounded, size: 16),
                                label: Text('Sistema'),
                              ),
                            ],
                            selected: {themeMode},
                            onSelectionChanged: (s) => ref
                                .read(themeModeProvider.notifier)
                                .setMode(s.first),
                            style: ButtonStyle(
                              textStyle:
                                  WidgetStateProperty.all(const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              )),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const _Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 140,
                          child: Text(
                            'Acceso rápido',
                            style: TextStyle(
                              fontSize: 13,
                              color: cs.onSurface.withValues(alpha: 0.55),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              _ThemePreviewTile(
                                label: 'Claro',
                                selected: !isDark,
                                bg: Colors.white,
                                fg: const Color(0xFF111827),
                                onTap: () => ref
                                    .read(themeModeProvider.notifier)
                                    .setMode(ThemeMode.light),
                              ),
                              const SizedBox(width: 10),
                              _ThemePreviewTile(
                                label: 'Oscuro',
                                selected: isDark,
                                bg: const Color(0xFF1E293B),
                                fg: const Color(0xFFF1F5F9),
                                onTap: () => ref
                                    .read(themeModeProvider.notifier)
                                    .setMode(ThemeMode.dark),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // ── Conexión ─────────────────────────────────────────────────
                const _SectionHeader(
                  title: 'Conexión', icon: Icons.cloud_rounded),
              const SizedBox(height: 12),
              _SettingsCard(
                children: [
                  const _CopyRow(label: 'Backend URL', value: backendUrl),
                  const _Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Actualizar vistas',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: cs.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Recarga la vista actual y datos en módulos abiertos.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurface.withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        OutlinedButton.icon(
                          onPressed: () {
                            ref.read(appRefreshTokenProvider.notifier).state++;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Vistas actualizadas.')),
                            );
                          },
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('Actualizar'),
                        ),
                      ],
                    ),
                  ),
                  const _Divider(),
                  const _InfoRow(
                    label: 'Configuración',
                    value: 'dart-define',
                    hint: '--dart-define=SAO_BACKEND_URL=https://…',
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // ── Acerca de ────────────────────────────────────────────────
              const _SectionHeader(
                  title: 'Acerca de', icon: Icons.info_outline_rounded),
              const SizedBox(height: 12),
              const _SettingsCard(
                children: [
                  _InfoRow(label: 'Sistema', value: 'SAO Desktop'),
                  _Divider(),
                  _InfoRow(label: 'Versión', value: '1.0.0'),
                  _Divider(),
                  _InfoRow(
                      label: 'Organización', value: 'Tren Maya — TMQ / SAO'),
                  _Divider(),
                  _InfoRow(label: 'Plataforma', value: 'Windows Desktop'),
                ],
              ),
              const SizedBox(height: 28),

              // ── Sesión ───────────────────────────────────────────────────
              const _SectionHeader(
                  title: 'Sesión', icon: Icons.logout_rounded),
              const SizedBox(height: 12),
              _SettingsCard(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cerrar sesión',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: cs.onSurface),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Termina la sesión actual en este dispositivo.',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: cs.onSurface.withValues(alpha: 0.5)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        OutlinedButton.icon(
                          onPressed: () => _confirmLogout(context, ref),
                          icon: const Icon(Icons.logout_rounded, size: 16),
                          label: const Text('Cerrar sesión'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
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
}

// ── Helpers ────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45);
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 7),
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final String? hint;

  const _InfoRow({
    required this.label,
    required this.value,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                  fontSize: 13, color: cs.onSurface.withValues(alpha: 0.5)),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                ),
                if (hint != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    hint!,
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurface.withValues(alpha: 0.35),
                      fontFamily: 'monospace',
                    ),
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

class _CopyRow extends StatefulWidget {
  final String label;
  final String value;
  const _CopyRow({required this.label, required this.value});

  @override
  State<_CopyRow> createState() => _CopyRowState();
}

class _CopyRowState extends State<_CopyRow> {
  bool _copied = false;

  void _copy() {
    Clipboard.setData(ClipboardData(text: widget.value));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              widget.label,
              style: TextStyle(
                  fontSize: 13, color: cs.onSurface.withValues(alpha: 0.5)),
            ),
          ),
          Expanded(
            child: Text(
              widget.value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                fontFamily: 'monospace',
                color: cs.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              _copied ? Icons.check_rounded : Icons.copy_rounded,
              size: 16,
              color: _copied ? Colors.green : cs.onSurface.withValues(alpha: 0.4),
            ),
            tooltip: _copied ? 'Copiado' : 'Copiar',
            onPressed: _copy,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }
}

class _ThemePreviewTile extends StatelessWidget {
  final String label;
  final bool selected;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;

  const _ThemePreviewTile({
    required this.label,
    required this.selected,
    required this.bg,
    required this.fg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 80,
        height: 52,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).dividerColor,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 8,
              decoration: BoxDecoration(
                color: fg.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 48,
              height: 6,
              decoration: BoxDecoration(
                color: fg.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w600, color: fg),
            ),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 16,
      endIndent: 16,
      color: Theme.of(context).dividerColor,
    );
  }
}
