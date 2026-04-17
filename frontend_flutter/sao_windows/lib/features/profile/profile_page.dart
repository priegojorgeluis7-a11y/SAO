// lib/features/profile/profile_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/snackbar.dart';
import '../../features/auth/application/auth_providers.dart';
import '../../ui/theme/sao_colors.dart';
import '../../ui/theme/sao_typography.dart';
import 'profile_stats_provider.dart';
import 'widgets/profile_badge.dart';
import 'widgets/profile_info_row.dart';
import 'widgets/profile_stat_tile.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
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
    final roleLabel = _roleLabel(profileStats.roleName);
    final roleColor = _roleColor(roleLabel);
    final completionRatio = _ratio(
      profileStats.completedActivities,
      profileStats.totalActivities,
    );
    final syncRatio = _ratio(
      profileStats.syncedActivities,
      profileStats.totalActivities,
    );

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
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 16,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: SaoColors.error,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Error al cargar datos: ${profileStats.error}',
                        style: const TextStyle(
                          color: SaoColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverAppBar(
                    expandedHeight: 260,
                    pinned: true,
                    backgroundColor: SaoColors.primary,
                    surfaceTintColor: SaoColors.primary,
                    iconTheme: const IconThemeData(color: SaoColors.onPrimary),
                    title: const Text(
                      'Perfil',
                      style: TextStyle(
                        color: SaoColors.onPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    actions: [
                      IconButton(
                        tooltip: 'Actualizar perfil',
                        onPressed: () {
                          ref.read(profileStatsProvider.notifier).loadAll();
                        },
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      background: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              SaoColors.actionPrimary,
                              SaoColors.primary,
                            ],
                          ),
                        ),
                        child: SafeArea(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(height: 52),
                              Container(
                                width: 82,
                                height: 82,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: SaoColors.onPrimary.withValues(
                                    alpha: 0.15,
                                  ),
                                  border: Border.all(
                                    color: SaoColors.onPrimary.withValues(
                                      alpha: 0.35,
                                    ),
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
                              Text(
                                user.email,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: SaoColors.onPrimary.withValues(
                                    alpha: 0.78,
                                  ),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (!profileStats.loadingRole &&
                                      profileStats.roleName != null)
                                    ProfileBadge(
                                      label: roleLabel,
                                      color: roleColor,
                                    ),
                                  ProfileBadge(
                                    label: user.isActive ? 'Activo' : 'Inactivo',
                                    color: user.isActive
                                        ? SaoColors.success
                                        : SaoColors.error,
                                  ),
                                  ProfileBadge(
                                    label: isOffline ? 'Offline' : 'Online',
                                    color: isOffline
                                        ? SaoColors.warning
                                        : SaoColors.info,
                                  ),
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
                        _overviewCard(
                          isOffline: isOffline,
                          stats: profileStats,
                          completionRatio: completionRatio,
                          syncRatio: syncRatio,
                        ),
                        const SizedBox(height: 24),
                        _sectionTitle(
                          'Accesos rápidos',
                          subtitle: 'Lo más usado desde tu perfil',
                        ),
                        const SizedBox(height: 10),
                        _infoCard(
                          children: [
                            _actionRow(
                              icon: Icons.history_rounded,
                              label: 'Ver historial de actividades',
                              onTap: () => context.push('/history/completed'),
                            ),
                            _divider(),
                            _actionRow(
                              icon: Icons.sync_rounded,
                              label: 'Ir al centro de sincronización',
                              onTap: () => context.push('/sync'),
                            ),
                            _divider(),
                            _actionRow(
                              icon: Icons.pin_outlined,
                              label: 'Cambiar PIN de acceso offline',
                              onTap: () => context.push('/auth/pin-setup'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _sectionTitle(
                          'Mi actividad',
                          subtitle: 'Resumen actual de tu operación',
                        ),
                        const SizedBox(height: 10),
                        profileStats.loadingStats
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : _statsGrid(profileStats),
                        const SizedBox(height: 24),
                        _sectionTitle(
                          'Información de cuenta',
                          subtitle: 'Datos personales y estado de acceso',
                        ),
                        const SizedBox(height: 10),
                        _infoCard(
                          children: [
                            ProfileInfoRow(
                              icon: isOffline
                                  ? Icons.cloud_off_rounded
                                  : Icons.cloud_done_rounded,
                              label: 'Tipo de sesión',
                              value: isOffline ? 'Offline (PIN)' : 'Online',
                              valueColor: isOffline
                                  ? SaoColors.warning
                                  : SaoColors.success,
                            ),
                            _divider(),
                            ProfileInfoRow(
                              icon: Icons.shield_outlined,
                              label: 'Rol',
                              value: profileStats.loadingRole
                                  ? '…'
                                  : roleLabel,
                              valueColor: roleColor,
                            ),
                            _divider(),
                            ProfileInfoRow(
                              icon: Icons.badge_outlined,
                              label: 'ID de usuario',
                              value: user.id.length > 20
                                  ? '${user.id.substring(0, 8)}…'
                                  : user.id,
                              onTap: () async {
                                await Clipboard.setData(
                                  ClipboardData(text: user.id),
                                );
                                if (!context.mounted) return;
                                showTransientSnackBar(
                                  context,
                                  appSnackBar(
                                    message: 'ID copiado al portapapeles',
                                  ),
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
                          ],
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _logout,
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

  Widget _statsGrid(ProfileStats stats) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.55,
      children: [
        ProfileStatTile(
          label: 'Asignadas',
          value: stats.totalActivities,
          color: SaoColors.primary,
          icon: Icons.assignment_rounded,
        ),
        ProfileStatTile(
          label: 'Completadas',
          value: stats.completedActivities,
          color: SaoColors.success,
          icon: Icons.check_circle_rounded,
        ),
        ProfileStatTile(
          label: 'Sincronizadas',
          value: stats.syncedActivities,
          color: SaoColors.info,
          icon: Icons.cloud_done_rounded,
        ),
        ProfileStatTile(
          label: 'Pendientes',
          value: stats.draftActivities,
          color: SaoColors.warning,
          icon: Icons.edit_note_rounded,
        ),
      ],
    );
  }

  Widget _overviewCard({
    required bool isOffline,
    required ProfileStats stats,
    required double completionRatio,
    required double syncRatio,
  }) {
    final statusColor = isOffline ? SaoColors.warning : SaoColors.success;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SaoColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SaoColors.border),
        boxShadow: [
          BoxShadow(
            color: SaoColors.gray900.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isOffline
                      ? Icons.cloud_off_rounded
                      : Icons.verified_user_rounded,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isOffline ? 'Modo offline activo' : 'Cuenta en buen estado',
                      style: SaoTypography.sectionTitle.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _activitySummary(stats),
                      style: SaoTypography.bodyTextSmall.copyWith(
                        color: SaoColors.gray600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _miniMetric(
                  label: 'Rol',
                  value: stats.loadingRole
                      ? 'Cargando'
                      : _roleLabel(stats.roleName),
                  color: _roleColor(_roleLabel(stats.roleName)),
                  icon: Icons.shield_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _miniMetric(
                  label: 'Sesión',
                  value: isOffline ? 'Offline' : 'Online',
                  color: statusColor,
                  icon: isOffline
                      ? Icons.cloud_off_rounded
                      : Icons.cloud_done_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _progressLine(
            label: 'Avance completado',
            value: completionRatio,
            caption:
                '${stats.completedActivities} de ${stats.totalActivities} actividades',
            color: SaoColors.success,
          ),
          const SizedBox(height: 10),
          _progressLine(
            label: 'Sincronización',
            value: syncRatio,
            caption: '${stats.syncedActivities} actividades sincronizadas',
            color: SaoColors.info,
          ),
        ],
      ),
    );
  }

  Widget _miniMetric({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: SaoTypography.caption.copyWith(
                    color: SaoColors.gray600,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SaoTypography.bodyTextSmall.copyWith(
                    fontWeight: FontWeight.w800,
                    color: SaoColors.gray900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressLine({
    required String label,
    required double value,
    required String caption,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: SaoTypography.bodyTextSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: SaoColors.gray800,
                ),
              ),
            ),
            Text(
              '${(value * 100).round()}%',
              style: SaoTypography.caption.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 8,
            backgroundColor: SaoColors.gray100,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          caption,
          style: SaoTypography.caption.copyWith(color: SaoColors.gray500),
        ),
      ],
    );
  }

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
            Icon(icon, size: 18, color: SaoColors.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: SaoTypography.bodyTextSmall)),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: SaoColors.gray400,
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() => const Divider(height: 0, indent: 46);

  Widget _sectionTitle(String title, {String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: SaoTypography.sectionTitle),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: SaoTypography.caption.copyWith(color: SaoColors.gray500),
          ),
        ],
      ],
    );
  }

  String _initials(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  String _activitySummary(ProfileStats stats) {
    if (stats.totalActivities == 0) {
      return 'Aún no tienes actividades registradas.';
    }
    if (stats.draftActivities > 0) {
      return 'Tienes ${stats.draftActivities} pendientes por revisar.';
    }
    if (stats.completedActivities == stats.totalActivities) {
      return 'Excelente, todo tu trabajo actual está completado.';
    }
    return 'Has completado ${stats.completedActivities} de ${stats.totalActivities} actividades.';
  }

  String _fmtDateTime(DateTime? dt) {
    if (dt == null) return '—';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  double _ratio(int value, int total) {
    if (total <= 0) return 0;
    final ratio = value / total;
    if (ratio < 0) return 0;
    if (ratio > 1) return 1;
    return ratio;
  }

  String _roleLabel(String? role) {
    final normalized = (role ?? '').trim().toUpperCase();
    if (normalized.isEmpty) return 'Sin rol asignado';
    if (normalized.contains('ADMIN')) return 'Administrador';
    if (normalized.contains('COORD')) return 'Coordinador';
    if (normalized.contains('SUPERVISOR')) return 'Supervisor';
    if (normalized.contains('LECTOR') || normalized.contains('VIEW')) return 'Lector';
    if (normalized.contains('OPERAT') || normalized.contains('OPERAR') || normalized.contains('TECN') || normalized.contains('ING') || normalized.contains('TOP')) {
      return 'Operativo';
    }
    return 'Operativo';
  }

  Color _roleColor(String? role) {
    switch (_roleLabel(role).toUpperCase()) {
      case 'ADMINISTRADOR':
        return SaoColors.riskPriority;
      case 'COORDINADOR':
        return SaoColors.statusEnValidacion;
      case 'SUPERVISOR':
        return SaoColors.info;
      case 'LECTOR':
        return SaoColors.gray500;
      case 'OPERATIVO':
        return SaoColors.success;
      default:
        return SaoColors.gray400;
    }
  }

  Future<void> _logout() async {
    final router = GoRouter.of(context);
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

    if (!mounted) return;
    router.go('/auth/login');
  }
}
