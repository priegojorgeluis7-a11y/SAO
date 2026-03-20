import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/catalog/state/catalog_providers.dart';
import '../../core/catalog/api/catalog_api.dart';
import '../../data/local/dao/activity_dao.dart';
import '../../ui/theme/sao_colors.dart';
import '../../core/utils/snackbar.dart';
import '../home/models/today_activity.dart';
import 'catalog_update_summary.dart';
import 'data/sync_provider.dart';
import 'models/sync_models.dart';

class SyncCenterPage extends ConsumerStatefulWidget {
  const SyncCenterPage({super.key});

  @override
  ConsumerState<SyncCenterPage> createState() => _SyncCenterPageState();
}

class _SyncCenterPageState extends ConsumerState<SyncCenterPage> {
  static const _lastSyncHeaderStateKey = 'sync_center:last_manual_result:v1';
  static const _wifiOnlyKey = 'sync:wifi_only';
  static const _catalogUpdatedAtKey = 'sync:catalog_updated_at';

  SyncConfig _config = const SyncConfig(
    wifiOnly: true,
    usedSpaceMb: 150,
    availableSpaceMb: 2048,
  );

  bool _catalogSyncing = false;
  DownloadResourceStatus? _catalogStatusOverride;
  DateTime? _catalogUpdatedAtOverride;
  SyncHealth? _lastManualSyncStatus;
  int? _lastPushed;
  int? _lastCreated;
  int? _lastUpdated;
  int? _lastConflicts;
  int? _lastErrors;
  bool _checkingCatalogUpdate = false;
  bool _catalogUpdateAvailable = false;
  String? _catalogLocalVersion;
  String? _catalogRemoteVersion;
  CatalogUpdateSummary _catalogUpdateSummary =
      const CatalogUpdateSummary(upserts: 0, deletes: 0);
  String? _catalogProjectChecked;
  String? _pendingPrefillSignature;
  String _pendingProjectFilter = 'ALL';
  String _pendingStatusFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _loadPersistedManualSyncStatus();
    _loadWifiOnlyPreference();
    _loadCatalogUpdatedAt();
  }

  Future<void> _loadCatalogUpdatedAt() async {
    final raw = await ref.read(kvStoreProvider).getString(_catalogUpdatedAtKey);
    if (!mounted || raw == null) return;
    final dt = DateTime.tryParse(raw);
    if (dt != null) {
      setState(() {
        _catalogUpdatedAtOverride = dt;
        _catalogStatusOverride = DownloadResourceStatus.upToDate;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final query = GoRouterState.of(context).uri.queryParameters;
    _applyPendingPrefiltersFromRoute(query);
    final projectId =
        (query['project'] ?? 'TMQ')
            .trim()
            .toUpperCase();
    if (_catalogProjectChecked == projectId) return;
    _catalogProjectChecked = projectId;
    _checkCatalogUpdateAvailability(projectId);
  }

  void _applyPendingPrefiltersFromRoute(Map<String, String> query) {
    final incomingProject =
        (query['pending_project'] ?? '').trim().toUpperCase();
    final incomingStatus =
        (query['pending_status'] ?? '').trim().toUpperCase();
    final signature = '$incomingProject|$incomingStatus';
    if (_pendingPrefillSignature == signature) return;
    _pendingPrefillSignature = signature;

    final nextProject = incomingProject.isEmpty ? 'ALL' : incomingProject;
    final nextStatus = incomingStatus.isEmpty ? 'ALL' : incomingStatus;
    if (_pendingProjectFilter == nextProject && _pendingStatusFilter == nextStatus) {
      return;
    }

    setState(() {
      _pendingProjectFilter = nextProject;
      _pendingStatusFilter = nextStatus;
    });
  }

  Future<void> _loadWifiOnlyPreference() async {
    final raw = await ref.read(kvStoreProvider).getString(_wifiOnlyKey);
    if (!mounted) return;
    // Si nunca se guardó, queda el default true; '0' == false
    final wifiOnly = raw == null ? true : raw != '0';
    if (wifiOnly != _config.wifiOnly) {
      setState(() {
        _config = SyncConfig(
          wifiOnly: wifiOnly,
          usedSpaceMb: _config.usedSpaceMb,
          availableSpaceMb: _config.availableSpaceMb,
        );
      });
    }
  }

  // =================== Actions ===================

  Future<void> _forceSync() async {
    setState(() {
      _lastManualSyncStatus = SyncHealth(
        status: SyncHealthStatus.syncing,
        message: 'Sincronizando...',
        lastSyncAt: DateTime.now(),
      );
    });

    await ref.read(syncStateProvider.notifier).sync();

    if (!mounted) return;

    final syncState = ref.read(syncStateProvider);
    syncState.when(
      data: (result) {
        if (result == null) return;
        final hasErrors = !result.success || result.errors > 0;
        final hasConflicts = result.conflicts > 0;
        final wasSuccessful = !hasErrors && !hasConflicts;

        _setManualSyncResult(
          health: SyncHealth(
            status:
                wasSuccessful ? SyncHealthStatus.allSynced : SyncHealthStatus.error,
            message: wasSuccessful
                ? (result.pushed > 0
                    ? 'Sincronización completada: ${result.pushed} elemento${result.pushed == 1 ? '' : 's'} enviado${result.pushed == 1 ? '' : 's'}'
                    : 'Sincronización completada: no había pendientes')
                : (result.errorMessage != null && result.errorMessage!.trim().isNotEmpty
                    ? 'Falló la sincronización: ${result.errorMessage}'
                    : 'Sincronización con incidencias: ${result.conflicts} conflicto${result.conflicts == 1 ? '' : 's'}, ${result.errors} error${result.errors == 1 ? '' : 'es'}'),
            lastSyncAt: result.completedAt,
            pendingCount: 0,
            syncingCount: 0,
            errorCount: hasErrors || hasConflicts ? (result.errors + result.conflicts) : 0,
          ),
          pushed: result.pushed,
          created: result.created,
          updated: result.updated,
          conflicts: result.conflicts,
          errors: result.errors,
        );

        final msg = result.success
            ? 'Sincronización completada (${result.pushed} enviados)'
            : 'Sync con errores: ${result.errorMessage}';
        showTransientSnackBar(
          context,
          appSnackBar(
            message: msg,
            backgroundColor:
                result.success ? SaoColors.success : SaoColors.error,
            duration: const Duration(seconds: 3),
          ),
        );
      },
      loading: () {},
      error: (e, _) {
        _setManualSyncResult(
          health: SyncHealth(
            status: SyncHealthStatus.error,
            message: 'Falló la sincronización: $e',
            lastSyncAt: DateTime.now(),
            errorCount: 1,
          ),
          pushed: 0,
          created: 0,
          updated: 0,
          conflicts: 0,
          errors: 1,
        );
        showTransientSnackBar(
          context,
          appSnackBar(
            message: 'Error: $e',
            backgroundColor: SaoColors.error,
          ),
        );
      },
    );
  }

  Future<void> _retryItem(UploadQueueItem item) async {
    await ref.read(syncRepositoryProvider).retryItem(item.id);
    // Auto-trigger sync after marking as retryable
    await ref.read(syncStateProvider.notifier).sync();
  }

  Future<void> _resolveConflictUseLocal(UploadQueueItem item) async {
    await ref.read(syncStateProvider.notifier).resolveConflictUseLocal(item.id);
    if (!mounted) return;
    showTransientSnackBar(
      context,
      appSnackBar(
        message: 'Se reenviara la version local con override.',
        backgroundColor: SaoColors.warning,
      ),
    );
  }

  Future<void> _resolveConflictUseServer(UploadQueueItem item) async {
    await ref.read(syncStateProvider.notifier).resolveConflictUseServer(item.id);
    if (!mounted) return;
    showTransientSnackBar(
      context,
      appSnackBar(
        message: 'Se aplico la version del servidor.',
        backgroundColor: SaoColors.info,
      ),
    );
  }

  Future<void> _showConflictDialog(UploadQueueItem item) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Conflicto de sincronización'),
        content: const Text(
          'Esta actividad cambió en servidor. Puedes usar tu versión local o tomar la versión del servidor.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _resolveConflictUseServer(item);
            },
            child: const Text('Usar servidor'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _resolveConflictUseLocal(item);
            },
            child: const Text('Usar mi versión'),
          ),
        ],
      ),
    );
  }

  void _toggleWifiOnly(bool value) {
    setState(() {
      _config = SyncConfig(
        wifiOnly: value,
        usedSpaceMb: _config.usedSpaceMb,
        availableSpaceMb: _config.availableSpaceMb,
      );
    });
    // Persiste la preferencia entre sesiones
    ref.read(kvStoreProvider).setString(_wifiOnlyKey, value ? '1' : '0');
  }

  Future<void> _syncCatalogConcepts() async {
    final projectId =
        (GoRouterState.of(context).uri.queryParameters['project'] ?? 'TMQ')
            .trim()
            .toUpperCase();
    final versionKey = 'catalog_version:$projectId';
    final kv = ref.read(kvStoreProvider);
    final previousVersion = await kv.getString(versionKey);

    setState(() {
      _catalogSyncing = true;
      _catalogStatusOverride = DownloadResourceStatus.downloading;
    });

    try {
      final syncService = ref.read(catalogSyncServiceProvider);
      await syncService.ensureCatalogUpToDate(projectId);
      final currentVersion = await kv.getString(versionKey);

      if (!mounted) return;

      final now = DateTime.now();
      setState(() {
        _catalogStatusOverride = DownloadResourceStatus.upToDate;
        _catalogUpdatedAtOverride = now;
      });
      // Persiste la fecha para que sobreviva navegaciones
      unawaited(kv.setString(_catalogUpdatedAtKey, now.toIso8601String()));

      if (currentVersion != null && currentVersion != previousVersion) {
        showTransientSnackBar(
          context,
          appSnackBar(
            message: 'Catalogo actualizado a version $currentVersion.',
            backgroundColor: SaoColors.success,
          ),
        );
      } else {
        showTransientSnackBar(
          context,
          appSnackBar(
            message: 'Ya cuentas con la ultima version del catalogo.',
            backgroundColor: SaoColors.info,
          ),
        );
      }
      await _checkCatalogUpdateAvailability(projectId);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _catalogStatusOverride = DownloadResourceStatus.error;
      });
      showTransientSnackBar(
        context,
        appSnackBar(
          message: 'Error al verificar catalogo: $e',
          backgroundColor: SaoColors.error,
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _catalogSyncing = false;
      });
    }
  }

  Future<void> _checkCatalogUpdateAvailability(String projectId) async {
    if (!mounted) return;
    setState(() => _checkingCatalogUpdate = true);
    try {
      final kv = ref.read(kvStoreProvider);
      final api = ref.read(catalogApiProvider);
      final localVersion = await kv.getString('catalog_version:$projectId');
      final remoteVersion = await api.getCurrentVersion(projectId: projectId);

      var summary = const CatalogUpdateSummary(upserts: 0, deletes: 0);
      final hasUpdate =
          localVersion == null || localVersion.trim().isEmpty || localVersion != remoteVersion;

      if (hasUpdate && localVersion != null && localVersion.trim().isNotEmpty) {
        try {
          final diff = await api.getDiff(
            projectId: projectId,
            fromVersionId: localVersion,
            toVersionId: remoteVersion,
          );
          summary = summarizeCatalogDiff(diff);
        } catch (_) {
          // Fallback silencioso: mostrar solo comparación de versiones.
        }
      }

      if (!mounted) return;
      setState(() {
        _catalogLocalVersion = localVersion;
        _catalogRemoteVersion = remoteVersion;
        _catalogUpdateAvailable = hasUpdate;
        _catalogUpdateSummary = summary;
      });
    } catch (_) {
      // Ignorar errores de conectividad para no bloquear la pantalla.
    } finally {
      if (mounted) {
        setState(() => _checkingCatalogUpdate = false);
      }
    }
  }

  // =================== Build ===================

  @override
  Widget build(BuildContext context) {
    // Watch providers (auto-rebuild on changes)
    final syncHealthAsync = ref.watch(syncHealthProvider);
    final uploadQueueAsync = ref.watch(uploadQueueProvider);
    final syncState = ref.watch(syncStateProvider);
    final pendingEvidenceAsync = ref.watch(pendingEvidenceActivitiesProvider);

    final baseSyncHealth = syncHealthAsync.valueOrNull ??
        const SyncHealth(
          status: SyncHealthStatus.allSynced,
          message: 'Cargando...',
        );
    final isSyncing = syncState.isLoading;
    final uploadQueue = uploadQueueAsync.valueOrNull ?? [];
    final pendingCount =
        uploadQueue.where((i) => i.status == UploadItemStatus.pending).length;
    final syncHealth = _resolveHealthForHeader(
      baseSyncHealth: baseSyncHealth,
      isSyncing: isSyncing,
      pendingCount: pendingCount,
    );

    final isTutorialGuest =
        GoRouterState.of(context).uri.queryParameters['tutorial'] == '1';

    return Scaffold(
      backgroundColor: SaoColors.gray50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Centro de Sincronización',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: _showInfoDialog,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _forceSync,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (isTutorialGuest) ...[
              Container(
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
                          'Modo tutorial · Vista Sincronización',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: SaoColors.infoText),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text('1) Revisa cuántos pendientes tienes por subir.'),
                    Text('2) Usa Sincronizar Ahora para forzar envío.'),
                    Text('3) Si falla, reintenta desde la cola.'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            _buildCatalogUpdateBanner(),
            const SizedBox(height: 16),

            // Encabezado de Estado Global
            _buildHealthHeader(syncHealth, isSyncing),
            const SizedBox(height: 24),

            _buildPendingEvidenceTray(pendingEvidenceAsync.valueOrNull ?? const []),
            const SizedBox(height: 24),

            // Cola de Subida
            _buildUploadQueue(uploadQueue),
            const SizedBox(height: 24),

            // Cola de Bajada
            _buildDownloadManagement(),
            const SizedBox(height: 24),

            // Configuración
            _buildConfigSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildCatalogUpdateBanner() {
    if (_checkingCatalogUpdate) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: SaoColors.infoBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: SaoColors.infoBorder),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Expanded(child: Text('Verificando versión de catálogo publicada...')),
          ],
        ),
      );
    }

    if (!_catalogUpdateAvailable) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: SaoColors.successBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: SaoColors.success.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.verified_rounded, color: SaoColors.success),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _catalogRemoteVersion == null
                    ? 'Catálogo sin cambios detectados.'
                    : 'Catálogo al día (${_catalogRemoteVersion!}).',
              ),
            ),
          ],
        ),
      );
    }

    final summaryText = _catalogUpdateSummary.hasChanges
        ? _catalogUpdateSummary.shortLabel
        : 'Cambios publicados disponibles';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SaoColors.warningBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SaoColors.warning.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.system_update_alt_rounded, color: SaoColors.warning),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Nueva versión de catálogo publicada',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              FilledButton.tonal(
                onPressed: _catalogSyncing ? null : _syncCatalogConcepts,
                child: const Text('Actualizar ahora'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Local: ${_catalogLocalVersion ?? 'sin versión'} → Publicada: ${_catalogRemoteVersion ?? 'desconocida'}'),
          Text(
            'Resumen: $summaryText',
            style: const TextStyle(color: SaoColors.gray600),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingEvidenceTray(List<PendingEvidenceActivityRecord> pendingEvidence) {
    if (pendingEvidence.isEmpty) {
      return const SizedBox.shrink();
    }

    final projectOptions = pendingEvidence
        .map((item) => (item.projectCode ?? 'TMQ').trim().toUpperCase())
        .toSet()
        .toList()
      ..sort();
    final statusOptions = pendingEvidence
        .map((item) => item.status.trim().toUpperCase())
        .where((status) => status.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    final effectiveProjectFilter = projectOptions.contains(_pendingProjectFilter)
        ? _pendingProjectFilter
        : 'ALL';
    final effectiveStatusFilter = statusOptions.contains(_pendingStatusFilter)
        ? _pendingStatusFilter
        : 'ALL';

    final filteredPendingEvidence = pendingEvidence.where((item) {
      final projectCode = (item.projectCode ?? 'TMQ').trim().toUpperCase();
      final status = item.status.trim().toUpperCase();
      final matchProject =
          effectiveProjectFilter == 'ALL' || projectCode == effectiveProjectFilter;
      final matchStatus =
          effectiveStatusFilter == 'ALL' || status == effectiveStatusFilter;
      return matchProject && matchStatus;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.assignment_late_outlined, size: 20, color: SaoColors.warning),
            const SizedBox(width: 8),
            Text(
              'Pendientes por completar (${pendingEvidence.length})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Actividades guardadas sin evidencia completa',
          style: TextStyle(fontSize: 13, color: SaoColors.gray400),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              width: 180,
              child: DropdownButtonFormField<String>(
                initialValue: effectiveProjectFilter,
                decoration: const InputDecoration(
                  labelText: 'Proyecto',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem(value: 'ALL', child: Text('Todos')),
                  ...projectOptions.map(
                    (code) => DropdownMenuItem(value: code, child: Text(code)),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _pendingProjectFilter = value);
                },
              ),
            ),
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String>(
                initialValue: effectiveStatusFilter,
                decoration: const InputDecoration(
                  labelText: 'Estado',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem(value: 'ALL', child: Text('Todos')),
                  ...statusOptions.map(
                    (status) => DropdownMenuItem(
                      value: status,
                      child: Text(_labelForPendingStatus(status)),
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _pendingStatusFilter = value);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (filteredPendingEvidence.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: SaoColors.gray200),
            ),
            child: const Text(
              'No hay actividades pendientes para los filtros seleccionados.',
              style: TextStyle(color: SaoColors.gray500),
            ),
          ),
        ...filteredPendingEvidence.take(8).map((item) {
          final projectCode = (item.projectCode ?? 'TMQ').trim().toUpperCase();
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                final activity = TodayActivity(
                  id: item.activityId,
                  title: item.title,
                  frente: '',
                  municipio: '',
                  estado: '',
                  status: ActivityStatus.hoy,
                  createdAt: item.createdAt,
                );
                context.push(
                  '/activity/${item.activityId}/wizard?project=${Uri.encodeQueryComponent(projectCode)}',
                  extra: activity,
                );
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: SaoColors.gray200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.photo_camera_back_outlined, color: SaoColors.warning),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title.trim().isNotEmpty
                              ? item.title
                                : 'Actividad sin título',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            'Proyecto: $projectCode',
                            style: const TextStyle(fontSize: 12, color: SaoColors.gray500),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  String _labelForPendingStatus(String status) {
    switch (status) {
      case 'DRAFT':
        return 'Borrador';
      case 'REVISION_PENDIENTE':
        return 'Revision pendiente';
      case 'READY_TO_SYNC':
        return 'Lista para sincronizar';
      case 'SYNCED':
        return 'Sincronizada';
      default:
        return status;
    }
  }

  // =================== Widgets ===================

  Widget _buildHealthHeader(SyncHealth syncHealth, bool isSyncing) {
    final (bgColor, iconColor, icon) = _getHealthVisuals(syncHealth);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: iconColor.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          // Icono animado
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: Icon(
              icon,
              key: Key(icon.toString()),
              size: 64,
              color: iconColor,
            ),
          ),
          const SizedBox(height: 16),

          // Mensaje principal
          Text(
            syncHealth.message,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: iconColor.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 8),

          // Última sincronización
          if (syncHealth.lastSyncAt != null)
            Text(
              'Última sincronización: ${_formatRelative(syncHealth.lastSyncAt!)}',
              style: TextStyle(
                fontSize: 13,
                color: iconColor.withValues(alpha: 0.6),
              ),
            ),

          if (_hasManualSummary)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _buildSyncSummaryChips(),
            ),

          // Botón gigante de sincronizar
          const SizedBox(height: 20),
          SizedBox(
            height: 56,
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isSyncing ? null : _forceSync,
              style: ElevatedButton.styleFrom(
                backgroundColor: iconColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: iconColor.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: isSyncing ? 0 : 2,
              ),
              icon: isSyncing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Icon(Icons.sync_rounded),
              label: Text(
                isSyncing ? 'Sincronizando...' : 'Sincronizar Ahora',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  SyncHealth _resolveHealthForHeader({
    required SyncHealth baseSyncHealth,
    required bool isSyncing,
    required int pendingCount,
  }) {
    if (isSyncing) {
      return SyncHealth(
        status: SyncHealthStatus.syncing,
        message: 'Sincronizando...',
        lastSyncAt: _lastManualSyncStatus?.lastSyncAt,
      );
    }

    // Si hay errores en cola, priorizar estado real de DB.
    if (baseSyncHealth.status == SyncHealthStatus.error) {
      return baseSyncHealth;
    }

    // Si hay pendientes reales, mostrar estado intermedio aunque el último sync fue ok.
    if (pendingCount > 0) {
      return SyncHealth(
        status: SyncHealthStatus.hasPending,
        message: '$pendingCount elemento${pendingCount == 1 ? '' : 's'} por sincronizar',
        lastSyncAt: _lastManualSyncStatus?.lastSyncAt,
        pendingCount: pendingCount,
      );
    }

    // Si no hay pendientes y hubo un sync manual, mostrar su resultado.
    final manual = _lastManualSyncStatus;
    if (manual != null) return manual;

    return baseSyncHealth;
  }

  bool get _hasManualSummary =>
      _lastPushed != null ||
      _lastCreated != null ||
      _lastUpdated != null ||
      _lastConflicts != null ||
      _lastErrors != null;

  void _setManualSyncResult({
    required SyncHealth health,
    required int pushed,
    required int created,
    required int updated,
    required int conflicts,
    required int errors,
  }) {
    if (!mounted) return;
    setState(() {
      _lastManualSyncStatus = health;
      _lastPushed = pushed;
      _lastCreated = created;
      _lastUpdated = updated;
      _lastConflicts = conflicts;
      _lastErrors = errors;
    });
    _persistManualSyncStatus();
  }

  Future<void> _persistManualSyncStatus() async {
    final health = _lastManualSyncStatus;
    if (health == null) return;

    final payload = <String, dynamic>{
      'status': health.status.name,
      'message': health.message,
      'lastSyncAt': health.lastSyncAt?.toIso8601String(),
      'pendingCount': health.pendingCount,
      'syncingCount': health.syncingCount,
      'errorCount': health.errorCount,
      'pushed': _lastPushed ?? 0,
      'created': _lastCreated ?? 0,
      'updated': _lastUpdated ?? 0,
      'conflicts': _lastConflicts ?? 0,
      'errors': _lastErrors ?? 0,
    };

    await ref
        .read(kvStoreProvider)
        .setString(_lastSyncHeaderStateKey, jsonEncode(payload));
  }

  Future<void> _loadPersistedManualSyncStatus() async {
    final raw = await ref.read(kvStoreProvider).getString(_lastSyncHeaderStateKey);
    if (raw == null || raw.trim().isEmpty) return;

    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final statusName = (map['status'] ?? '').toString();
      final status = SyncHealthStatus.values.firstWhere(
        (s) => s.name == statusName,
        orElse: () => SyncHealthStatus.allSynced,
      );

      final lastSyncRaw = (map['lastSyncAt'] ?? '').toString();
      final lastSyncAt =
          lastSyncRaw.isNotEmpty ? DateTime.tryParse(lastSyncRaw) : null;

      final restored = SyncHealth(
        status: status,
        message: (map['message'] ?? 'Sin estado de sincronización').toString(),
        lastSyncAt: lastSyncAt,
        pendingCount: (map['pendingCount'] as num?)?.toInt() ?? 0,
        syncingCount: (map['syncingCount'] as num?)?.toInt() ?? 0,
        errorCount: (map['errorCount'] as num?)?.toInt() ?? 0,
      );

      if (!mounted) return;
      setState(() {
        _lastManualSyncStatus = restored;
        _lastPushed = (map['pushed'] as num?)?.toInt() ?? 0;
        _lastCreated = (map['created'] as num?)?.toInt() ?? 0;
        _lastUpdated = (map['updated'] as num?)?.toInt() ?? 0;
        _lastConflicts = (map['conflicts'] as num?)?.toInt() ?? 0;
        _lastErrors = (map['errors'] as num?)?.toInt() ?? 0;
      });
    } catch (_) {
      await ref.read(kvStoreProvider).remove(_lastSyncHeaderStateKey);
    }
  }

  Widget _buildSyncSummaryChips() {
    final chips = <(IconData, Color, String)>[
      (Icons.cloud_upload_rounded, SaoColors.info, '${_lastPushed ?? 0} enviados'),
    ];
    if ((_lastCreated ?? 0) > 0) {
      chips.add((Icons.add_circle_outline_rounded, SaoColors.success, '${_lastCreated} creados'));
    }
    if ((_lastUpdated ?? 0) > 0) {
      chips.add((Icons.edit_outlined, SaoColors.info, '${_lastUpdated} actualizados'));
    }
    if ((_lastConflicts ?? 0) > 0) {
      chips.add((Icons.merge_type_rounded, SaoColors.warning, '${_lastConflicts} conflictos'));
    }
    if ((_lastErrors ?? 0) > 0) {
      chips.add((Icons.error_outline_rounded, SaoColors.error, '${_lastErrors} errores'));
    }

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      alignment: WrapAlignment.center,
      children: chips.map((c) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: c.$2.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(c.$1, size: 13, color: c.$2),
              const SizedBox(width: 4),
              Text(
                c.$3,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: c.$2,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildUploadQueue(List<UploadQueueItem> uploadQueue) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.cloud_upload_rounded, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Cola de Subida',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Text(
              '(${uploadQueue.length})',
              style: const TextStyle(
                fontSize: 14,
                color: SaoColors.statusBorrador,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Mi trabajo pendiente de subir',
          style: TextStyle(
            fontSize: 13,
            color: SaoColors.gray400,
          ),
        ),
        const SizedBox(height: 12),

        if (uploadQueue.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: SaoColors.gray200,
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  color: SaoColors.success,
                  size: 28,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No hay elementos pendientes',
                    style: TextStyle(
                      fontSize: 14,
                      color: SaoColors.statusBorrador,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          ...uploadQueue.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildUploadItem(item),
              )),
      ],
    );
  }

  Widget _buildUploadItem(UploadQueueItem item) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: SaoColors.gray200,
        ),
      ),
      child: Row(
        children: [
          // Icono
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              item.icon,
              size: 22,
              color: item.color,
            ),
          ),
          const SizedBox(width: 14),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: SaoColors.gray400,
                  ),
                ),

                // Progress bar para uploading
                if (item.status == UploadItemStatus.uploading && item.progress != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: item.progress,
                        backgroundColor: SaoColors.gray200,
                        valueColor: AlwaysStoppedAnimation(item.color),
                        minHeight: 6,
                      ),
                    ),
                  ),

                // Error message
                if (item.status == UploadItemStatus.error && item.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      item.errorMessage!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: SaoColors.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Estado o botón de retry
          if (item.status == UploadItemStatus.pending)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: SaoColors.warningBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                children: [
                  Icon(Icons.hourglass_empty_rounded, size: 14, color: SaoColors.warning),
                  SizedBox(width: 4),
                  Text(
                    'Esperando',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: SaoColors.warning,
                    ),
                  ),
                ],
              ),
            )
          else if (item.status == UploadItemStatus.uploading)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: SaoColors.infoLight,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(item.color),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${(item.progress! * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: item.color,
                    ),
                  ),
                ],
              ),
            )
          else if (item.status == UploadItemStatus.error)
            IconButton(
              icon: Icon(
                item.isConflict ? Icons.merge_type_rounded : Icons.refresh_rounded,
                size: 20,
              ),
              color: SaoColors.error,
              onPressed: () => item.isConflict
                  ? _showConflictDialog(item)
                  : _retryItem(item),
              tooltip: item.isConflict ? 'Resolver conflicto' : 'Reintentar',
            ),
        ],
      ),
    );
  }

  Widget _buildDownloadManagement() {
    final downloadResources = ref.watch(downloadResourcesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.cloud_download_rounded, size: 20),
            SizedBox(width: 8),
            Text(
              'Recursos del Proyecto',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Datos disponibles offline',
          style: TextStyle(
            fontSize: 13,
            color: SaoColors.gray400,
          ),
        ),
        const SizedBox(height: 12),

        // Lista de recursos
        ...downloadResources.map((resource) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildDownloadResource(resource),
            )),
      ],
    );
  }

  Widget _buildDownloadResource(DownloadResource resource) {
    final effectiveResource = resource.type == DownloadResourceType.catalogo
        ? DownloadResource(
            type: resource.type,
            name: resource.name,
            sizeMb: resource.sizeMb,
            status: _catalogSyncing
                ? DownloadResourceStatus.downloading
                : (_catalogStatusOverride ?? resource.status),
            lastUpdatedAt: _catalogUpdatedAtOverride ?? resource.lastUpdatedAt,
          )
        : resource;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: effectiveResource.type == DownloadResourceType.catalogo
          ? _syncCatalogConcepts
          : null,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: SaoColors.gray200,
          ),
        ),
        child: Row(
          children: [
            // Icono
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: SaoColors.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                effectiveResource.icon,
                size: 22,
                color: SaoColors.info,
              ),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    effectiveResource.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${effectiveResource.sizeMb} MB',
                    style: const TextStyle(
                      fontSize: 12,
                      color: SaoColors.gray400,
                    ),
                  ),
                  if (effectiveResource.lastUpdatedAt != null &&
                      effectiveResource.status == DownloadResourceStatus.upToDate)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Actualizado ${_formatRelative(effectiveResource.lastUpdatedAt!)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: SaoColors.success,
                        ),
                      ),
                    ),

                  // Progress bar para downloading
                  if (effectiveResource.status == DownloadResourceStatus.downloading &&
                      effectiveResource.progress != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: effectiveResource.progress,
                          backgroundColor: SaoColors.gray200,
                          valueColor: const AlwaysStoppedAnimation(SaoColors.info),
                          minHeight: 6,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Estado
            _buildDownloadStatusBadge(effectiveResource.status),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadStatusBadge(DownloadResourceStatus status) {
    final (color, icon, text) = switch (status) {
      DownloadResourceStatus.upToDate => (
          SaoColors.success,
          Icons.check_circle_rounded,
          'Al día',
        ),
      DownloadResourceStatus.downloading => (
          SaoColors.info,
          Icons.downloading_rounded,
          'Descargando',
        ),
      DownloadResourceStatus.pending => (
          SaoColors.warning,
          Icons.pending_rounded,
          'Pendiente',
        ),
      DownloadResourceStatus.error => (
          SaoColors.error,
          Icons.error_rounded,
          'Error',
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          if (status == DownloadResourceStatus.downloading)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            )
          else
            Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.settings_rounded, size: 20),
            SizedBox(width: 8),
            Text(
              'Configuración',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: SaoColors.gray200,
            ),
          ),
          child: Column(
            children: [
              // WiFi Only
              SwitchListTile(
                value: _config.wifiOnly,
                onChanged: _toggleWifiOnly,
                title: const Text(
                  'Solo con WiFi',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Sincronizar solo con WiFi',
                  style: TextStyle(fontSize: 12),
                ),
                activeThumbColor: SaoColors.success,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // =================== Helpers ===================

  (Color, Color, IconData) _getHealthVisuals(SyncHealth syncHealth) {
    switch (syncHealth.status) {
      case SyncHealthStatus.allSynced:
        return (SaoColors.successBg, SaoColors.success, Icons.cloud_done_rounded);
      case SyncHealthStatus.hasPending:
        return (SaoColors.warningBg, SaoColors.warning, Icons.cloud_upload_rounded);
      case SyncHealthStatus.syncing:
        return (SaoColors.infoLight, SaoColors.info, Icons.cloud_sync_rounded);
      case SyncHealthStatus.error:
        return (SaoColors.errorLight, SaoColors.error, Icons.cloud_off_rounded);
    }
  }

  String _formatRelative(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'hace un momento';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours}h';
    if (diff.inDays == 1) return 'ayer';
    return '${time.day}/${time.month} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  void _showInfoDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cómo funciona?'),
        content: const Text(
          'El Centro de Sincronización es el corazón de SAO. '
          'Aquí puedes ver qué datos están pendientes de subir al servidor, '
          'qué recursos están disponibles offline, y configurar cuándo sincronizar.\n\n'
          'Tip: Usa sincronización solo con WiFi para ahorrar datos móviles.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }
}
