import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../auth/session_controller.dart';
import '../data/admin_repositories.dart';
import '../../../core/theme/app_colors.dart';

// ---------------------------------------------------------------------------
// Data model
// ---------------------------------------------------------------------------

class _AdminDashboardData {
  final int totalUsers;
  final int activeUsers;
  final int totalProjects;
  final int activeProjects;
  final List<AuditItem> recentAudit;

  const _AdminDashboardData({
    required this.totalUsers,
    required this.activeUsers,
    required this.totalProjects,
    required this.activeProjects,
    required this.recentAudit,
  });
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final _adminDashboardProvider =
    FutureProvider.autoDispose<_AdminDashboardData>((ref) async {
  final session = ref.watch(sessionControllerProvider);
  final token = session.accessToken ?? '';

  final usersRepo = ref.read(usersRepositoryProvider);
  final projectsRepo = ref.read(projectsRepositoryProvider);
  final auditRepo = ref.read(auditRepositoryProvider);

  final results = await Future.wait([
    usersRepo.list(token).catchError((_) => <AdminUserItem>[]),
    projectsRepo.list(token).catchError((_) => <AdminProject>[]),
    auditRepo.list(token).catchError((_) => <AuditItem>[]),
  ]);

  final users = results[0] as List<AdminUserItem>;
  final projects = results[1] as List<AdminProject>;
  final audit = results[2] as List<AuditItem>;

  return _AdminDashboardData(
    totalUsers: users.length,
    activeUsers: users.where((u) => u.status.toLowerCase() == 'active').length,
    totalProjects: projects.length,
    activeProjects:
        projects.where((p) => p.status.toLowerCase() == 'active').length,
    recentAudit: audit.take(20).toList(),
  );
});

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(_adminDashboardProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: dataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text('Error al cargar: $e'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(_adminDashboardProvider),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
        data: (data) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Text(
                  'Panel de Administración',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Actualizar',
                  onPressed: () => ref.invalidate(_adminDashboardProvider),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // KPI cards
            Row(
              children: [
                _KpiCard(
                  icon: Icons.people_rounded,
                  label: 'Usuarios totales',
                  value: data.totalUsers.toString(),
                  sub: '${data.activeUsers} activos',
                  color: AppColors.primary,
                ),
                const SizedBox(width: 16),
                _KpiCard(
                  icon: Icons.person_off_rounded,
                  label: 'Usuarios inactivos',
                  value: (data.totalUsers - data.activeUsers).toString(),
                  sub: 'de ${data.totalUsers} registrados',
                  color: Colors.orange,
                ),
                const SizedBox(width: 16),
                _KpiCard(
                  icon: Icons.folder_rounded,
                  label: 'Proyectos',
                  value: data.totalProjects.toString(),
                  sub: '${data.activeProjects} activos',
                  color: Colors.teal,
                ),
                const SizedBox(width: 16),
                _KpiCard(
                  icon: Icons.manage_history_rounded,
                  label: 'Eventos de auditoría',
                  value: data.recentAudit.length >= 20
                      ? '20+'
                      : data.recentAudit.length.toString(),
                  sub: 'últimos registros',
                  color: Colors.purple,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Recent audit
            const Text(
              'Actividad reciente',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: data.recentAudit.isEmpty
                  ? const Center(
                      child: Text(
                        'Sin eventos de auditoría registrados.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceFor(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderFor(context)),
                      ),
                      child: SingleChildScrollView(
                        child: DataTable(
                          headingRowColor: WidgetStatePropertyAll(AppColors.surfaceMutedFor(context)),
                          columnSpacing: 20,
                          columns: const [
                            DataColumn(label: Text('Fecha')),
                            DataColumn(label: Text('Actor')),
                            DataColumn(label: Text('Acción')),
                            DataColumn(label: Text('Entidad')),
                            DataColumn(label: Text('ID')),
                          ],
                          rows: data.recentAudit
                              .map(
                                (item) => DataRow(cells: [
                                  DataCell(
                                      Text(_formatDate(item.createdAt))),
                                  DataCell(Text(
                                    item.actorEmail ?? '—',
                                    style: const TextStyle(fontSize: 12),
                                  )),
                                  DataCell(_ActionChip(item.action)),
                                  DataCell(Text(item.entity)),
                                  DataCell(
                                    Text(
                                      item.entityId.length > 12
                                          ? '${item.entityId.substring(0, 8)}…'
                                          : item.entityId,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontFamily: 'monospace',
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                ]),
                              )
                              .toList(),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      return DateFormat('dd/MM HH:mm', 'es').format(dt);
    } catch (_) {
      return raw.length > 16 ? raw.substring(0, 16) : raw;
    }
  }
}

// ---------------------------------------------------------------------------
// Widgets
// ---------------------------------------------------------------------------

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String sub;
  final Color color;

  const _KpiCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceFor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderFor(context)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      sub,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMutedFor(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String action;

  const _ActionChip(this.action);

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (action) {
      String a when a.contains('CREATED') =>
        (Colors.green, Icons.add_circle_outline),
      String a when a.contains('UPDATED') || a.contains('CHANGED') =>
        (Colors.blue, Icons.edit_outlined),
      String a when a.contains('DELETED') || a.contains('CANCELED') =>
        (Colors.red, Icons.remove_circle_outline),
      String a when a.contains('LOGIN') || a.contains('AUTH') =>
        (Colors.purple, Icons.login_rounded),
      _ => (Colors.grey, Icons.info_outline),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            action,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
