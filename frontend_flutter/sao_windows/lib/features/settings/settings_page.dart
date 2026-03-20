import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/application/auth_providers.dart';
import '../auth/data/auth_service.dart';
import '../sync/data/sync_api_repository.dart';
import '../catalog/data/catalog_api_repository.dart';
import '../catalog/data/catalog_local_repository.dart';
import '../../core/di/service_locator.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_config.dart';
import '../../core/catalog/state/catalog_providers.dart';
import '../../ui/theme/sao_colors.dart';
import '../../core/utils/logger.dart';
import '../../core/utils/snackbar.dart';

// ---------------------------------------------------------------------------
// Providers de ajustes
// ---------------------------------------------------------------------------

/// Estado combinado de biometría: si el dispositivo la soporta y si está activa.
final _biometricStateProvider =
    FutureProvider.autoDispose<({bool canUse, bool enabled})>((ref) async {
  final notifier = ref.read(authControllerProvider.notifier);
  final canUse = await notifier.canUseBiometrics();
  if (!canUse) return (canUse: false, enabled: false);
  final enabled = await notifier.isBiometricEnabled();
  return (canUse: canUse, enabled: enabled);
});

// ---------------------------------------------------------------------------
// SettingsPage
// ---------------------------------------------------------------------------

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  static const _apiBaseUrlKey = 'api_base_url_override';

  String _safeInitial(String? fullName) {
    final trimmed = (fullName ?? '').trim();
    if (trimmed.isEmpty) return '?';
    return trimmed[0].toUpperCase();
  }

  // ---- Dialogo: cambiar contraseña ----------------------------------------

  Future<void> _showChangePasswordDialog(
      BuildContext context, WidgetRef ref) async {
    final formKey = GlobalKey<FormState>();
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => _ChangePasswordDialog(
          formKey: formKey,
          currentCtrl: currentCtrl,
          newCtrl: newCtrl,
          confirmCtrl: confirmCtrl,
        ),
      );

      if (confirmed != true || !context.mounted) return;

      await ref
          .read(authControllerProvider.notifier)
          .changePassword(currentCtrl.text, newCtrl.text);

      if (context.mounted) {
        showTransientSnackBar(
          context,
          appSnackBar(
            message: 'Contraseña actualizada correctamente',
            backgroundColor: SaoColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        final message = e
            .toString()
            .replaceFirst(RegExp(r'^[A-Za-z]+Exception:\s*'), '');
        showTransientSnackBar(
          context,
          appSnackBar(
            message: message,
            backgroundColor: SaoColors.error,
          ),
        );
      }
    } finally {
      currentCtrl.dispose();
      newCtrl.dispose();
      confirmCtrl.dispose();
    }
  }

  // ---- Dialogo: configurar backend URL ------------------------------------

  Future<void> _configureBackendUrl(BuildContext context) async {
    final prefs = getIt<SharedPreferences>();
    final apiConfig = getIt<ApiConfig>();
    final apiClient = getIt<ApiClient>();
    final authService = getIt<AuthService>();
    final stored = prefs.getString(_apiBaseUrlKey)?.trim();
    final current = (stored != null && stored.isNotEmpty)
        ? stored
        : apiConfig.baseUrl;

    final controller = TextEditingController(text: current);
    final formKey = GlobalKey<FormState>();

    final submittedUrl = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Configurar backend API'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Base URL',
                hintText: 'https://host/api/v1',
              ),
              validator: (value) {
                final candidate = (value ?? '').trim();
                if (candidate.isEmpty) {
                  return 'Ingresa una URL';
                }
                final uri = Uri.tryParse(candidate);
                if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
                  return 'URL inválida';
                }
                if (uri.scheme != 'http' && uri.scheme != 'https') {
                  return 'La URL debe usar http o https';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop('__RESET__'),
              child: const Text('Usar predeterminada'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() != true) return;
                Navigator.of(dialogContext).pop(controller.text.trim());
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (submittedUrl == null) return;

    if (submittedUrl == '__RESET__') {
      await prefs.remove(_apiBaseUrlKey);
      apiConfig.resetBaseUrl();
      const defaultUrl = ApiConfig.defaultBaseUrl;
      apiClient.updateBaseUrl(defaultUrl);
      authService.updateBaseUrl(defaultUrl);
      if (context.mounted) {
        showTransientSnackBar(
          context,
          appSnackBar(
            message: 'Backend restablecido a: $defaultUrl',
            backgroundColor: SaoColors.info,
          ),
        );
      }
      return;
    }

    await prefs.setString(_apiBaseUrlKey, submittedUrl);
    apiClient.updateBaseUrl(submittedUrl);
  authService.updateBaseUrl(submittedUrl);
    if (context.mounted) {
      showTransientSnackBar(
        context,
        appSnackBar(
          message: 'Backend actualizado a: $submittedUrl',
          backgroundColor: SaoColors.success,
        ),
      );
    }
  }

  // ---- Build --------------------------------------------------------------

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final theme = Theme.of(context);
    final isTutorialGuest =
        GoRouterState.of(context).uri.queryParameters['tutorial'] == '1';
    final syncRoute = isTutorialGuest ? '/sync?tutorial=1' : '/sync';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajustes'),
        elevation: 0,
      ),
      body: ListView(
        children: [
          // Banner modo tutorial
          if (isTutorialGuest)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: SaoColors.infoBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: SaoColors.infoBorder),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.school_outlined,
                          size: 18, color: SaoColors.infoIcon),
                      SizedBox(width: 6),
                      Text(
                        'Modo tutorial · Vista Ajustes',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: SaoColors.infoText),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text('Aquí se configuran seguridad, sync y datos locales.'),
                  Text(
                      'En operación real, verifica biometría y reglas de sincronización.'),
                ],
              ),
            ),

          // Tarjeta de usuario (tappable → /profile)
          if (authState.user != null) ...[
            Material(
              color: theme.colorScheme.primaryContainer,
              child: InkWell(
                onTap: () => context.push('/profile'),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: theme.colorScheme.primary,
                            child: Text(
                              _safeInitial(authState.user!.fullName),
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
                                        .withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: theme.colorScheme.onPrimaryContainer
                                .withValues(alpha: 0.5),
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
                              ? SaoColors.success.withValues(alpha: 0.12)
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
              ),
            ),
            const Divider(),
          ],

          // Cambiar contraseña
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Cambiar contraseña'),
            subtitle: const Text('Actualizar credenciales'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showChangePasswordDialog(context, ref),
          ),
          const Divider(),

          // Biometría
          const _BiometricTile(),
          const Divider(),

          // Sección de aplicación
          ListTile(
            leading: const Icon(Icons.dns_outlined),
            title: const Text('Backend API'),
            subtitle: const Text('Cambiar endpoint (entorno)'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _configureBackendUrl(context),
          ),
          const _CatalogVersionTile(),
          ListTile(
            leading: const Icon(Icons.sync_outlined),
            title: const Text('Sincronización'),
            subtitle: const Text('Configurar sync automático'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(syncRoute),
          ),
          const Divider(),

          // DEBUG ONLY
          if (kDebugMode) ...[
            ListTile(
              leading: const Icon(Icons.bug_report, color: SaoColors.warning),
              title: const Text(
                '🧪 DEBUG: Test Sync Pull',
                style: TextStyle(color: SaoColors.warning),
              ),
              subtitle: const Text(
                  'Pull activities from TMQ (Phase 3D smoke test)'),
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
                    showTransientSnackBar(
                      context,
                      appSnackBar(
                        message: 'Sync Pull Success!\n'
                            'Current version: ${response.currentVersion}\n'
                            'Activities pulled: ${response.activities.length}',
                        backgroundColor: SaoColors.success,
                        duration: const Duration(seconds: 5),
                      ),
                    );
                  }
                } catch (e) {
                  appLogger.e('❌ Sync Pull smoke test failed: $e');
                  if (context.mounted) {
                    showTransientSnackBar(
                      context,
                      appSnackBar(
                        message: 'Sync Pull Failed:\n$e',
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
              subtitle: const Text(
                  'Fetch latest catalog from TMQ (Phase 4A smoke test)'),
              trailing: const Icon(Icons.play_arrow),
              onTap: () async {
                try {
                  appLogger.i('🧪 Starting Catalog Fetch smoke test...');

                  final catalogRepo = CatalogApiRepository();
                  final catalog = await catalogRepo.fetchLatestCatalog(
                    projectId: 'TMQ',
                  );

                  if (context.mounted) {
                    showTransientSnackBar(
                      context,
                      appSnackBar(
                        message: 'Catalog Fetch Success!\n'
                            'Version: ${catalog.versionNumber}\n'
                            'Hash: ${catalog.hash.substring(0, 8)}...\n'
                            'Activity Types: ${catalog.activityTypes.length}\n'
                            'Event Types: ${catalog.eventTypes.length}\n'
                            'Form Fields: ${catalog.formFields.length}',
                        backgroundColor: SaoColors.success,
                        duration: const Duration(seconds: 5),
                      ),
                    );
                  }
                } catch (e) {
                  appLogger.e('❌ Catalog Fetch smoke test failed: $e');
                  if (context.mounted) {
                    showTransientSnackBar(
                      context,
                      appSnackBar(
                        message: 'Catalog Fetch Failed:\n$e',
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
              subtitle: const Text(
                  'Fetch + save catalog to Drift DB (Phase 4B smoke test)'),
              trailing: const Icon(Icons.play_arrow),
              onTap: () async {
                try {
                  appLogger.i('🧪 Starting Catalog Persist smoke test...');

                  final catalogRepo = CatalogApiRepository();
                  final catalog = await catalogRepo.fetchLatestCatalog(
                    projectId: 'TMQ',
                  );

                  appLogger.i(
                      '📦 Fetched catalog v${catalog.versionNumber}, saving to DB...');

                  final localRepo = CatalogLocalRepository();
                  await localRepo.saveCatalogPackage(catalog,
                      projectId: 'TMQ');

                  final currentVersion =
                      await localRepo.getCurrentCatalogVersion(
                          projectId: 'TMQ');
                  final activityTypes =
                      await localRepo.getActivityTypes(projectId: 'TMQ');

                  if (context.mounted) {
                    showTransientSnackBar(
                      context,
                      appSnackBar(
                        message: 'Catalog Persist Success!\n'
                            'Saved version: ${currentVersion?.versionNumber}\n'
                            'Activity Types in DB: ${activityTypes.length}\n'
                            'Hash: ${currentVersion?.checksum?.substring(0, 8) ?? "n/a"}...',
                        backgroundColor: SaoColors.success,
                        duration: const Duration(seconds: 6),
                      ),
                    );
                  }
                } catch (e) {
                  appLogger.e('❌ Catalog Persist smoke test failed: $e');
                  if (context.mounted) {
                    showTransientSnackBar(
                      context,
                      appSnackBar(
                        message: 'Catalog Persist Failed:\n$e',
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
                style: TextStyle(
                    color: SaoColors.primary, fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                  'Smart sync: check updates + fetch + persist (Phase 4C)'),
              trailing: const Icon(Icons.download),
              onTap: () async {
                try {
                  appLogger.i('🔄 Starting Catalog Sync (effective flow)...');

                  final selectedProject =
                      (await ref.read(kvStoreProvider).getString(
                                  'selected_project'))
                              ?.trim()
                              .toUpperCase();
                  final projectId =
                      (selectedProject != null && selectedProject.isNotEmpty)
                          ? selectedProject
                          : 'TMQ';
                  final versionKey = 'catalog_version:$projectId';
                  final kv = ref.read(kvStoreProvider);
                  final previousVersion = await kv.getString(versionKey);

                  final syncService = ref.read(catalogSyncServiceProvider);
                  await syncService.ensureCatalogUpToDate(projectId);
                  final currentVersion = await kv.getString(versionKey);

                  if (context.mounted) {
                    if (currentVersion != null &&
                        currentVersion != previousVersion) {
                      showTransientSnackBar(
                        context,
                        appSnackBar(
                          message: 'Catalogo actualizado para $projectId.\n'
                              'Version: $currentVersion',
                          backgroundColor: SaoColors.success,
                          duration: const Duration(seconds: 5),
                        ),
                      );
                    } else {
                      showTransientSnackBar(
                        context,
                        appSnackBar(
                          message:
                              'No hay cambios de catalogo para $projectId.\n'
                              'Version actual: ${currentVersion ?? previousVersion ?? 'sin catalogo local'}',
                          backgroundColor: SaoColors.info,
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    }
                  }
                } catch (e) {
                  appLogger.e('❌ Catalog sync failed: $e');
                  if (context.mounted) {
                    showTransientSnackBar(
                      context,
                      appSnackBar(
                        message: 'Sync Failed:\n$e',
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
                await ref.read(authControllerProvider.notifier).logout();
                ref.invalidate(authStateProvider);
                ref.invalidate(sessionProvider);
                ref.invalidate(currentUserProvider);
                ref.invalidate(isAuthenticatedProvider);
                ref.invalidate(authControllerProvider);
                if (context.mounted) {
                  context.go('/auth/login');
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

// ---------------------------------------------------------------------------
// Widget: tile de biometría reactivo
// ---------------------------------------------------------------------------

class _BiometricTile extends ConsumerWidget {
  const _BiometricTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bioAsync = ref.watch(_biometricStateProvider);
    return bioAsync.when(
      loading: () => const ListTile(
        leading: Icon(Icons.fingerprint),
        title: Text('Inicio rápido con biometría'),
        subtitle: Text('Cargando configuración...'),
        trailing: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, __) => ListTile(
        leading: const Icon(Icons.fingerprint, color: SaoColors.warning),
        title: const Text('Inicio rápido con biometría'),
        subtitle: const Text('No se pudo cargar el estado de biometría'),
        trailing: TextButton(
          onPressed: () => ref.invalidate(_biometricStateProvider),
          child: const Text('Reintentar'),
        ),
      ),
      data: (bio) {
        if (!bio.canUse) {
          return const ListTile(
            leading: Icon(Icons.fingerprint, color: SaoColors.gray400),
            title: Text('Inicio rápido con biometría'),
            subtitle: Text('No disponible en este dispositivo'),
          );
        }
        return SwitchListTile(
          secondary: const Icon(Icons.fingerprint),
          title: const Text('Inicio rápido con biometría'),
          subtitle: const Text('Usa huella o Face ID para entrar'),
          value: bio.enabled,
          onChanged: (value) async {
            try {
              await ref
                  .read(authControllerProvider.notifier)
                  .setBiometricEnabled(value);
            } catch (e) {
              if (context.mounted) {
                final message = e
                    .toString()
                    .replaceFirst(RegExp(r'^[A-Za-z]+Exception:\s*'), '');
                showTransientSnackBar(
                  context,
                  appSnackBar(
                    message: message,
                    backgroundColor: SaoColors.error,
                  ),
                );
              }
            } finally {
              ref.invalidate(_biometricStateProvider);
            }
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Widget: tile de versión de catálogo con acción de sync
// ---------------------------------------------------------------------------

class _CatalogVersionTile extends ConsumerWidget {
  const _CatalogVersionTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectAsync = ref.watch(selectedProjectIdProvider);

    return projectAsync.when(
      loading: () => const ListTile(
        leading: Icon(Icons.menu_book_outlined),
        title: Text('Catálogo'),
        subtitle: Text('Cargando...'),
      ),
      error: (_, __) => ListTile(
        leading: const Icon(Icons.menu_book_outlined, color: SaoColors.warning),
        title: const Text('Catálogo'),
        subtitle: const Text('No se pudo cargar el proyecto seleccionado'),
        trailing: TextButton(
          onPressed: () => ref.invalidate(selectedProjectIdProvider),
          child: const Text('Reintentar'),
        ),
      ),
      data: (projectId) {
        if (projectId == null || projectId.isEmpty) {
          return const ListTile(
            leading: Icon(Icons.menu_book_outlined),
            title: Text('Catálogo'),
            subtitle: Text('Sin proyecto seleccionado'),
          );
        }
        final versionAsync =
            ref.watch(catalogActiveVersionProvider(projectId));
        return versionAsync.when(
          loading: () => const ListTile(
            leading: Icon(Icons.menu_book_outlined),
            title: Text('Catálogo'),
            subtitle: Text('Cargando versión...'),
          ),
          error: (_, __) => ListTile(
            leading: const Icon(Icons.menu_book_outlined, color: SaoColors.warning),
            title: Text('Catálogo · $projectId'),
            subtitle: const Text('No se pudo cargar la versión local'),
            trailing: TextButton(
              onPressed: () => ref.invalidate(catalogActiveVersionProvider(projectId)),
              child: const Text('Reintentar'),
            ),
          ),
          data: (versionId) {
            final hasVersion = versionId != null && versionId.isNotEmpty;
            final label = hasVersion
                ? versionId.length > 16
                    ? '${versionId.substring(0, 8)}…'
                    : versionId
                : 'Sin catálogo local';
            final statusColor =
                hasVersion ? SaoColors.success : SaoColors.warning;
            final statusText = hasVersion ? 'actualizado' : 'pendiente';

            return ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: Text('Catálogo · $projectId'),
              subtitle: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('$label · $statusText'),
                ],
              ),
              trailing: const Icon(Icons.refresh),
              onTap: () async {
                try {
                  await ref
                      .read(catalogSyncServiceProvider)
                      .ensureCatalogUpToDate(projectId);
                  ref.invalidate(catalogActiveVersionProvider(projectId));
                  if (context.mounted) {
                    showTransientSnackBar(
                      context,
                      appSnackBar(
                        message: 'Catálogo sincronizado',
                        backgroundColor: SaoColors.success,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    showTransientSnackBar(
                      context,
                      appSnackBar(
                        message: 'Error al sincronizar catálogo',
                        backgroundColor: SaoColors.error,
                      ),
                    );
                  }
                }
              },
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Widget: diálogo de cambio de contraseña (stateful para visibilidad)
// ---------------------------------------------------------------------------

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog({
    required this.formKey,
    required this.currentCtrl,
    required this.newCtrl,
    required this.confirmCtrl,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController currentCtrl;
  final TextEditingController newCtrl;
  final TextEditingController confirmCtrl;

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cambiar contraseña'),
      content: Form(
        key: widget.formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: widget.currentCtrl,
              obscureText: !_showCurrent,
              decoration: InputDecoration(
                labelText: 'Contraseña actual',
                suffixIcon: IconButton(
                  icon: Icon(
                      _showCurrent ? Icons.visibility_off : Icons.visibility),
                  onPressed: () =>
                      setState(() => _showCurrent = !_showCurrent),
                ),
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: widget.newCtrl,
              obscureText: !_showNew,
              decoration: InputDecoration(
                labelText: 'Nueva contraseña',
                suffixIcon: IconButton(
                  icon: Icon(
                      _showNew ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _showNew = !_showNew),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Requerido';
                if (v.length < 8) return 'Mínimo 8 caracteres';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: widget.confirmCtrl,
              obscureText: !_showConfirm,
              decoration: InputDecoration(
                labelText: 'Confirmar contraseña',
                suffixIcon: IconButton(
                  icon: Icon(_showConfirm
                      ? Icons.visibility_off
                      : Icons.visibility),
                  onPressed: () =>
                      setState(() => _showConfirm = !_showConfirm),
                ),
              ),
              validator: (v) => v != widget.newCtrl.text
                  ? 'Las contraseñas no coinciden'
                  : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (widget.formKey.currentState?.validate() != true) return;
            Navigator.of(context).pop(true);
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
