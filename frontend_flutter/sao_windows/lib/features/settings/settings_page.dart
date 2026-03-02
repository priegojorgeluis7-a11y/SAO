import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/data/auth_provider.dart';
import '../sync/data/sync_api_repository.dart';
import '../catalog/data/catalog_api_repository.dart';
import '../catalog/data/catalog_local_repository.dart';
import '../catalog/application/catalog_sync_service.dart';
import '../../ui/theme/sao_colors.dart';
import '../../core/utils/logger.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);
    final isTutorialGuest = GoRouterState.of(context).uri.queryParameters['tutorial'] == '1';
    final syncRoute = isTutorialGuest ? '/sync?tutorial=1' : '/sync';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajustes'),
        elevation: 0,
      ),
      body: ListView(
        children: [
          if (isTutorialGuest)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.school_outlined, size: 18, color: Color(0xFF1D4ED8)),
                      SizedBox(width: 6),
                      Text(
                        'Modo tutorial · Vista Ajustes',
                        style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1E3A8A)),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text('Aquí se configuran seguridad, sync y datos locales.'),
                  Text('En operación real, verifica biometría y reglas de sincronización.'),
                ],
              ),
            ),

          // Información del usuario
          if (authState.user != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: theme.colorScheme.primary,
                        child: Text(
                          authState.user!.fullName[0].toUpperCase(),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              authState.user!.fullName,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              authState.user!.email,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer
                                    .withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: authState.user!.isActive
                          ? SaoColors.success.withOpacity(0.12)
                          : SaoColors.gray300,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          authState.user!.isActive
                              ? Icons.check_circle
                              : Icons.block,
                          size: 16,
                          color: authState.user!.isActive
                              ? SaoColors.success
                              : SaoColors.gray700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          authState.user!.status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: authState.user!.isActive
                                ? SaoColors.success
                                : SaoColors.gray700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
          ],

          // Sección de cuenta
          const ListTile(
            leading: Icon(Icons.account_circle_outlined),
            title: Text('Cuenta'),
            subtitle: Text('Información de usuario'),
            enabled: false,
          ),
          const ListTile(
            leading: Icon(Icons.lock_outline),
            title: Text('Cambiar contraseña'),
            subtitle: Text('Actualizar credenciales'),
            enabled: false,
          ),
          const Divider(),

          // Sección de seguridad
          ListTile(
            leading: const Icon(Icons.fingerprint),
            title: const Text('Inicio rápido con biometría'),
            subtitle: const Text('Usa huella o Face ID para entrar'),
            trailing: StatefulBuilder(
              builder: (context, setState) {
                return FutureBuilder<bool>(
                  future: ref.read(authProvider.notifier).canUseBiometrics(),
                  builder: (context, canUseSnapshot) {
                    if (!canUseSnapshot.hasData || !canUseSnapshot.data!) {
                      return const SizedBox.shrink();
                    }

                    return FutureBuilder<bool>(
                      future:
                          ref.read(authProvider.notifier).isBiometricEnabled(),
                      builder: (context, enabledSnapshot) {
                        if (!enabledSnapshot.hasData) {
                          return const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          );
                        }

                        return Switch(
                          value: enabledSnapshot.data!,
                          onChanged: (value) async {
                            await ref
                                .read(authProvider.notifier)
                                .setBiometricEnabled(value);
                            // Refrescar el estado
                            setState(() {});
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          const Divider(),

          // Sección de aplicación
          ListTile(
            leading: const Icon(Icons.sync_outlined),
            title: const Text('Sincronización'),
            subtitle: const Text('Configurar sync automático'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(syncRoute),
          ),
          ListTile(
            leading: const Icon(Icons.storage_outlined),
            title: const Text('Almacenamiento'),
            subtitle: const Text('Gestionar datos locales'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(syncRoute),
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Acerca de'),
            subtitle: Text('Versión 1.0.0'),
            enabled: false,
          ),
          const Divider(),

          // DEBUG ONLY: Sync smoke test (Phase 3D)
          if (kDebugMode) ...[
            ListTile(
              leading: const Icon(Icons.bug_report, color: SaoColors.warning),
              title: const Text(
                '🧪 DEBUG: Test Sync Pull',
                style: TextStyle(color: SaoColors.warning),
              ),
              subtitle: const Text('Pull activities from TMQ (Phase 3D smoke test)'),
              trailing: const Icon(Icons.play_arrow),
              onTap: () async {
                try {
                  appLogger.i('🧪 Starting Sync Pull smoke test...');
                  
                  final syncRepo = SyncApiRepository();
                  final response = await syncRepo.pullActivities(
                    projectId: 'TMQ',
                    sinceVersion: 0,
                    limit: 50,
                  );
                  
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '✅ Sync Pull Success!\n'
                          'Current version: ${response.currentVersion}\n'
                          'Activities pulled: ${response.activities.length}',
                        ),
                        backgroundColor: SaoColors.success,
                        duration: const Duration(seconds: 5),
                      ),
                    );
                  }
                } catch (e) {
                  appLogger.e('❌ Sync Pull smoke test failed: $e');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('❌ Sync Pull Failed:\n$e'),
                        backgroundColor: SaoColors.error,
                        duration: const Duration(seconds: 5),
                      ),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.bug_report, color: SaoColors.info),
              title: const Text(
                '🧪 DEBUG: Test Catalog Fetch',
                style: TextStyle(color: SaoColors.info),
              ),
              subtitle: const Text('Fetch latest catalog from TMQ (Phase 4A smoke test)'),
              trailing: const Icon(Icons.play_arrow),
              onTap: () async {
                try {
                  appLogger.i('🧪 Starting Catalog Fetch smoke test...');
                  
                  final catalogRepo = CatalogApiRepository();
                  final catalog = await catalogRepo.fetchLatestCatalog(
                    projectId: 'TMQ',
                  );
                  
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '✅ Catalog Fetch Success!\n'
                          'Version: ${catalog.versionNumber}\n'
                          'Hash: ${catalog.hash.substring(0, 8)}...\n'
                          'Activity Types: ${catalog.activityTypes.length}\n'
                          'Event Types: ${catalog.eventTypes.length}\n'
                          'Form Fields: ${catalog.formFields.length}',
                        ),
                        backgroundColor: SaoColors.success,
                        duration: const Duration(seconds: 5),
                      ),
                    );
                  }
                } catch (e) {
                  appLogger.e('❌ Catalog Fetch smoke test failed: $e');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('❌ Catalog Fetch Failed:\n$e'),
                        backgroundColor: SaoColors.error,
                        duration: const Duration(seconds: 5),
                      ),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.save, color: SaoColors.info),
              title: const Text(
                '🧪 DEBUG: Test Catalog Persist',
                style: TextStyle(color: SaoColors.info),
              ),
              subtitle: const Text('Fetch + save catalog to Drift DB (Phase 4B smoke test)'),
              trailing: const Icon(Icons.play_arrow),
              onTap: () async {
                try {
                  appLogger.i('🧪 Starting Catalog Persist smoke test...');
                  
                  // Phase 4A: Fetch from API
                  final catalogRepo = CatalogApiRepository();
                  final catalog = await catalogRepo.fetchLatestCatalog(
                    projectId: 'TMQ',
                  );
                  
                  appLogger.i('📦 Fetched catalog v${catalog.versionNumber}, saving to DB...');
                  
                  // Phase 4B: Save to Drift DB
                  final localRepo = CatalogLocalRepository();
                  await localRepo.saveCatalogPackage(catalog, projectId: 'TMQ');
                  
                  // Verify save
                  final currentVersion = await localRepo.getCurrentCatalogVersion(projectId: 'TMQ');
                  final activityTypes = await localRepo.getActivityTypes(projectId: 'TMQ');
                  
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '✅ Catalog Persist Success!\n'
                          'Saved version: ${currentVersion?.versionNumber}\n'
                          'Activity Types in DB: ${activityTypes.length}\n'
                          'Hash: ${currentVersion?.checksum?.substring(0, 8) ?? "n/a"}...',
                        ),
                        backgroundColor: SaoColors.success,
                        duration: const Duration(seconds: 6),
                      ),
                    );
                  }
                } catch (e) {
                  appLogger.e('❌ Catalog Persist smoke test failed: $e');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('❌ Catalog Persist Failed:\n$e'),
                        backgroundColor: SaoColors.error,
                        duration: const Duration(seconds: 5),
                      ),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.sync, color: SaoColors.primary),
              title: const Text(
                '🧪 DEBUG: Descargar Catálogo',
                style: TextStyle(color: SaoColors.primary, fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Smart sync: check updates + fetch + persist (Phase 4C)'),
              trailing: const Icon(Icons.download),
              onTap: () async {
                try {
                  appLogger.i('🔄 Starting Catalog Sync (Phase 4C)...');
                  
                  final syncService = CatalogSyncService();
                  final result = await syncService.syncCatalog('TMQ');
                  
                  if (context.mounted) {
                    if (result.isSuccess) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            result.hasChanges
                                ? '✅ Catálogo Actualizado!\n'
                                    'Versión: ${result.localVersion ?? "?"}  ${result.newVersion ?? "?"}\n'
                                    'Tipos de Actividad: ${result.activityTypeCount}\n'
                                    'Campos: ${result.formFieldCount}\n'
                                    'Hash: ${result.newHash?.substring(0, 8) ?? "n/a"}...\n'
                                    'Duración: ${result.durationMs}ms'
                                : '✅ ${result.message}\n'
                                    'Versión actual: ${result.localVersion}',
                          ),
                          backgroundColor: result.hasChanges ? SaoColors.success : SaoColors.info,
                          duration: Duration(seconds: result.hasChanges ? 7 : 4),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('❌ Error de Sincronización:\n${result.message}'),
                          backgroundColor: SaoColors.error,
                          duration: const Duration(seconds: 5),
                        ),
                      );
                    }
                  }
                } catch (e) {
                  appLogger.e('❌ Catalog sync failed: $e');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('❌ Sync Failed:\n$e'),
                        backgroundColor: SaoColors.error,
                        duration: const Duration(seconds: 5),
                      ),
                    );
                  }
                }
              },
            ),
            const Divider(),
          ],

          // Cerrar sesión
          ListTile(
            leading: const Icon(Icons.logout, color: SaoColors.error),
            title: const Text(
              'Cerrar sesión',
              style: TextStyle(color: SaoColors.error),
            ),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Cerrar sesión'),
                  content: const Text(
                    '¿Estás seguro de que deseas cerrar sesión?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: SaoColors.error,
                      ),
                      child: const Text('Cerrar sesión'),
                    ),
                  ],
                ),
              );

              if (confirm == true && context.mounted) {
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) {
                  context.go('/login');
                }
              }
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
