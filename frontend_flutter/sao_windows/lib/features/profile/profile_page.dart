// lib/features/profile/profile_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_providers.dart';
import 'profile_stats_provider.dart';
import '../../ui/theme/sao_colors.dart';
import '../../ui/theme/sao_typography.dart';
import '../../core/utils/snackbar.dart';
import 'widgets/profile_badge.dart';
import 'widgets/profile_info_row.dart';
import 'widgets/profile_stat_tile.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final authState = ref.watch(authControllerProvider);
    final profileStats = ref.watch(profileStatsProvider);

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Perfil')),
        body: const Center(child: Text('Sin sesión activa')),
      );
    }

    final initials = _initials(user.fullName);
    final isOffline = authState.isOfflineSession;
    final roleColor = _roleColor(profileStats.roleName);

    return Scaffold(
      backgroundColor: SaoColors.gray50,
      body: RefreshIndicator(
        onRefresh: () => ref.read(profileStatsProvider.notifier).loadAll(),
        child: Column(
          children: [
            if (profileStats.error != null)
              Container(
                width: double.infinity,
                color: SaoColors.error.withValues(alpha: 0.1),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: SaoColors.error, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Error al cargar datos: ${profileStats.error}',
                        style: const TextStyle(color: SaoColors.error, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  // ── Hero AppBar ────────────────────────────────────────
                  SliverAppBar(
                    expandedHeight: 240,
                    pinned: true,
                    backgroundColor: SaoColors.primary,
                    surfaceTintColor: SaoColors.primary,
                    iconTheme: const IconThemeData(color: SaoColors.onPrimary),
                    flexibleSpace: FlexibleSpaceBar(
                      background: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [SaoColors.actionPrimary, SaoColors.primary],
                          ),
                        ),
                        child: SafeArea(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(height: 48),
                              // Avatar
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: SaoColors.onPrimary.withValues(alpha: 0.15),
                                  border: Border.all(
                                    color: SaoColors.onPrimary.withValues(alpha: 0.4),
                                    width: 2,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    initials,
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                      color: SaoColors.onPrimary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Nombre
                              Text(
                                user.fullName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: SaoColors.onPrimary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                              // Email
                              Text(
                                user.email,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: SaoColors.onPrimary.withValues(alpha: 0.75),
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Badges: rol + estado + sesión
                              Wrap(
                                spacing: 8,
                                children: [
                                  if (!profileStats.loadingRole && profileStats.roleName != null)
                                    ProfileBadge(label: profileStats.roleName!, color: roleColor),
                                  ProfileBadge(
                                    label: user.isActive ? 'Activo' : 'Inactivo',
                                    color: user.isActive ? SaoColors.success : SaoColors.error,
                                  ),
                                  if (isOffline)
                                    ProfileBadge(label: 'Offline', color: SaoColors.warning),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // ── Stats propias ──────────────────────────────
                        _sectionTitle('Mis actividades'),
                        const SizedBox(height: 10),
                        profileStats.loadingStats
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : _statsGrid(profileStats),

                        const SizedBox(height: 24),

                        // ── Información de cuenta ─────────────────────
                        _sectionTitle('Información de cuenta'),
                        const SizedBox(height: 10),
                        _infoCard(children: [
                          ProfileInfoRow(
                            icon: Icons.badge_outlined,
                            label: 'ID de usuario',
                            value: user.id.length > 20
                                ? '${user.id.substring(0, 8)}…'
                                : user.id,
                            onTap: () async {
                              await Clipboard.setData(ClipboardData(text: user.id));
                              if (!mounted) return;
                              showTransientSnackBar(
                                context,
                                appSnackBar(message: 'ID copiado al portapapeles'),
                              );
                            },
                          ),
                          _divider(),
                          ProfileInfoRow(
                            icon: Icons.email_outlined,
                            label: 'Email',
                            value: user.email,
                          ),
                          _divider(),
                          ProfileInfoRow(
                            icon: Icons.person_outline_rounded,
                            label: 'Nombre',
                            value: user.fullName,
                          ),
                          _divider(),
                          ProfileInfoRow(
                            icon: Icons.shield_outlined,
                            label: 'Rol',
                            value: profileStats.loadingRole
                                ? '…'
                                : (profileStats.roleName ?? 'Sin rol asignado'),
                            valueColor: roleColor,
                          ),
                          _divider(),
                          ProfileInfoRow(
                            icon: Icons.login_rounded,
                            label: 'Último acceso',
                            value: _fmtDateTime(user.lastLoginAt),
                          ),
                          _divider(),
                          ProfileInfoRow(
                            icon: Icons.calendar_today_outlined,
                            label: 'Cuenta creada',
                            value: _fmtDateTime(user.createdAt),
                          ),
                          _divider(),
                          ProfileInfoRow(
                            icon: isOffline
                                ? Icons.cloud_off_rounded
                                : Icons.cloud_done_rounded,
                            label: 'Tipo de sesión',
                            value: isOffline ? 'Offline (PIN)' : 'Online',
                            valueColor:
                                isOffline ? SaoColors.warning : SaoColors.success,
                          ),
                        ]),

                        const SizedBox(height: 24),

                        // ── Seguridad ─────────────────────────────────
                        _sectionTitle('Seguridad'),
                        const SizedBox(height: 10),
                        _infoCard(children: [
                          _actionRow(
                            icon: Icons.pin_outlined,
                            label: 'Cambiar PIN de acceso offline',
                            onTap: () => context.push('/auth/pin-setup'),
                          ),
                          _divider(),
                          _actionRow(
                            icon: Icons.fingerprint_rounded,
                            label: 'Configurar biometría',
                            onTap: () => context.push('/settings'),
                          ),
                        ]),

                        const SizedBox(height: 24),

                        // ── Cerrar sesión ─────────────────────────────
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _logout(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: SaoColors.error,
                              side: const BorderSide(color: SaoColors.error),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            icon: const Icon(Icons.logout_rounded),
                            label: const Text(
                              'Cerrar sesión',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Stats grid ────────────────────────────────────────────────

  Widget _statsGrid(ProfileStats stats) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.2,
      children: [
        ProfileStatTile(label: 'Total', value: stats.totalActivities, color: SaoColors.primary, icon: Icons.assignment_rounded),
        ProfileStatTile(label: 'Completadas', value: stats.completedActivities, color: SaoColors.success, icon: Icons.check_circle_rounded),
        ProfileStatTile(label: 'Sincronizadas', value: stats.syncedActivities, color: SaoColors.info, icon: Icons.cloud_done_rounded),
        ProfileStatTile(label: 'Borradores', value: stats.draftActivities, color: SaoColors.gray500, icon: Icons.edit_outlined),
      ],
    );
  }

  // ── Info card helpers ─────────────────────────────────────────

  Widget _infoCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: SaoColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SaoColors.border),
        boxShadow: [
          BoxShadow(
            color: SaoColors.gray900.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _actionRow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 18, color: SaoColors.gray500),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: SaoTypography.bodyTextSmall),
            ),
            const Icon(Icons.chevron_right_rounded, size: 18, color: SaoColors.gray400),
          ],
        ),
      ),
    );
  }

  Widget _divider() => const Divider(height: 0, indent: 46);

  Widget _sectionTitle(String title) => Text(title, style: SaoTypography.sectionTitle);

  // ── Helpers ───────────────────────────────────────────────────

  String _initials(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  String _fmtDateTime(DateTime? dt) {
    if (dt == null) return '—';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Color _roleColor(String? role) {
    switch (role?.toUpperCase()) {
      case 'ADMIN': return SaoColors.riskPriority;
      case 'COORD': return SaoColors.statusEnValidacion;
      case 'SUPERVISOR': return SaoColors.info;
      case 'OPERATIVO': return SaoColors.success;
      default: return SaoColors.gray400;
    }
  }

  // ── Actions ───────────────────────────────────────────────────

  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
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
            style: FilledButton.styleFrom(backgroundColor: SaoColors.error),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    await ref.read(authControllerProvider.notifier).logout();
    ref.invalidate(authStateProvider);
    ref.invalidate(sessionProvider);
    ref.invalidate(currentUserProvider);
    ref.invalidate(isAuthenticatedProvider);
    ref.invalidate(authControllerProvider);
    if (mounted) context.go('/auth/login');
  }
}
