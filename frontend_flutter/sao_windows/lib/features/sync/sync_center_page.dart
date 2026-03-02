import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../ui/theme/sao_colors.dart';
import 'data/sync_provider.dart';
import 'models/sync_models.dart';

class SyncCenterPage extends ConsumerStatefulWidget {
  const SyncCenterPage({super.key});

  @override
  ConsumerState<SyncCenterPage> createState() => _SyncCenterPageState();
}

class _SyncCenterPageState extends ConsumerState<SyncCenterPage> {
  // Config local (no necesita ser persistida en Drift por ahora)
  SyncConfig _config = const SyncConfig(
    wifiOnly: true,
    downloadPlanos: false,
    usedSpaceMb: 150,
    availableSpaceMb: 2048,
  );

  // =================== Actions ===================

  Future<void> _forceSync() async {
    await ref.read(syncStateProvider.notifier).sync();

    if (!mounted) return;

    final syncState = ref.read(syncStateProvider);
    syncState.when(
      data: (result) {
        if (result == null) return;
        final msg = result.success
            ? '✓ Sincronización completada (${result.pushed} enviados)'
            : '⚠ Sync con errores: ${result.errorMessage}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor:
                result.success ? SaoColors.success : SaoColors.error,
            duration: const Duration(seconds: 3),
          ),
        );
      },
      loading: () {},
      error: (e, _) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: SaoColors.error,
        ),
      ),
    );
  }

  Future<void> _retryItem(UploadQueueItem item) async {
    await ref.read(syncRepositoryProvider).retryItem(item.id);
    // Auto-trigger sync after marking as retryable
    await ref.read(syncStateProvider.notifier).sync();
  }

  void _toggleWifiOnly(bool value) {
    setState(() {
      _config = SyncConfig(
        wifiOnly: value,
        downloadPlanos: _config.downloadPlanos,
        usedSpaceMb: _config.usedSpaceMb,
        availableSpaceMb: _config.availableSpaceMb,
      );
    });
  }

  void _liberarEspacio() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Liberar Espacio',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.delete_sweep_rounded),
                title: const Text('Eliminar evidencias subidas'),
                subtitle: const Text('~80 MB'),
                onTap: () => Navigator.pop(ctx),
              ),
              ListTile(
                leading: const Icon(Icons.cleaning_services_rounded),
                title: const Text('Limpiar caché de imágenes'),
                subtitle: const Text('~25 MB'),
                onTap: () => Navigator.pop(ctx),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // =================== Build ===================

  @override
  Widget build(BuildContext context) {
    // Watch providers (auto-rebuild on changes)
    final syncHealthAsync = ref.watch(syncHealthProvider);
    final uploadQueueAsync = ref.watch(uploadQueueProvider);
    final syncState = ref.watch(syncStateProvider);

    final syncHealth = syncHealthAsync.valueOrNull ??
        const SyncHealth(
          status: SyncHealthStatus.allSynced,
          message: 'Cargando...',
        );
    final uploadQueue = uploadQueueAsync.valueOrNull ?? [];
    final isSyncing = syncState.isLoading;

    final isTutorialGuest =
        GoRouterState.of(context).uri.queryParameters['tutorial'] == '1';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
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
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.school_outlined,
                            size: 18, color: Color(0xFF1D4ED8)),
                        SizedBox(width: 6),
                        Text(
                          'Modo tutorial · Vista Sincronización',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E3A8A)),
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

            // Encabezado de Estado Global
            _buildHealthHeader(syncHealth, isSyncing),
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

  // =================== Widgets ===================

  Widget _buildHealthHeader(SyncHealth syncHealth, bool isSyncing) {
    final (bgColor, iconColor, icon) = _getHealthVisuals(syncHealth);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: iconColor.withOpacity(0.2),
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
              color: iconColor.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 8),

          // Última sincronización
          if (syncHealth.lastSyncAt != null)
            Text(
              'Última sincronización: ${_formatTime(syncHealth.lastSyncAt!)}',
              style: TextStyle(
                fontSize: 13,
                color: iconColor.withOpacity(0.6),
              ),
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
                disabledBackgroundColor: iconColor.withOpacity(0.5),
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
                color: Color(0xFF6B7280),
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
            color: Color(0xFF9CA3AF),
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
                color: const Color(0xFFE5E7EB),
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  color: Color(0xFF10B981),
                  size: 28,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No hay elementos pendientes',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
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
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        children: [
          // Icono
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: item.color.withOpacity(0.1),
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
                    color: Color(0xFF9CA3AF),
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
                        backgroundColor: const Color(0xFFE5E7EB),
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
                        color: Color(0xFFEF4444),
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
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                children: [
                  Icon(Icons.hourglass_empty_rounded, size: 14, color: Color(0xFFF59E0B)),
                  SizedBox(width: 4),
                  Text(
                    'Esperando',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                ],
              ),
            )
          else if (item.status == UploadItemStatus.uploading)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFDBEAFE),
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
              icon: const Icon(Icons.refresh_rounded, size: 20),
              color: const Color(0xFFEF4444),
              onPressed: () => _retryItem(item),
              tooltip: 'Reintentar',
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
            color: Color(0xFF9CA3AF),
          ),
        ),
        const SizedBox(height: 12),

        // Uso de almacenamiento
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFE5E7EB),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.sd_storage_rounded, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    _config.usageText,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _config.usagePercentage,
                  backgroundColor: const Color(0xFFE5E7EB),
                  valueColor: AlwaysStoppedAnimation(
                    _config.usagePercentage > 0.8
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF3B82F6),
                  ),
                  minHeight: 8,
                ),
              ),
            ],
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        children: [
          // Icono
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              resource.icon,
              size: 22,
              color: const Color(0xFF3B82F6),
            ),
          ),
          const SizedBox(width: 14),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  resource.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${resource.sizeMb} MB',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
                if (resource.lastUpdatedAt != null && resource.status == DownloadResourceStatus.upToDate)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Actualizado ${_formatRelativeTime(resource.lastUpdatedAt!)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ),

                // Progress bar para downloading
                if (resource.status == DownloadResourceStatus.downloading && resource.progress != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: resource.progress,
                        backgroundColor: const Color(0xFFE5E7EB),
                        valueColor: const AlwaysStoppedAnimation(Color(0xFF3B82F6)),
                        minHeight: 6,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Estado
          _buildDownloadStatusBadge(resource.status),
        ],
      ),
    );
  }

  Widget _buildDownloadStatusBadge(DownloadResourceStatus status) {
    final (color, icon, text) = switch (status) {
      DownloadResourceStatus.upToDate => (
          const Color(0xFF10B981),
          Icons.check_circle_rounded,
          'Al día',
        ),
      DownloadResourceStatus.downloading => (
          const Color(0xFF3B82F6),
          Icons.downloading_rounded,
          'Descargando',
        ),
      DownloadResourceStatus.pending => (
          const Color(0xFFF59E0B),
          Icons.pending_rounded,
          'Pendiente',
        ),
      DownloadResourceStatus.error => (
          const Color(0xFFEF4444),
          Icons.error_rounded,
          'Error',
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
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
              color: const Color(0xFFE5E7EB),
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
                activeThumbColor: const Color(0xFF10B981),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Botón de liberar espacio
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _liberarEspacio,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
            ),
            icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
            label: const Text(
              'Liberar espacio en dispositivo',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFFEF4444),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // =================== Helpers ===================

  (Color, Color, IconData) _getHealthVisuals(SyncHealth syncHealth) {
    switch (syncHealth.status) {
      case SyncHealthStatus.allSynced:
        return (
          const Color(0xFFF0FDF4),
          const Color(0xFF10B981),
          Icons.cloud_done_rounded,
        );
      case SyncHealthStatus.syncing:
        return (
          const Color(0xFFDBEAFE),
          const Color(0xFF3B82F6),
          Icons.cloud_sync_rounded,
        );
      case SyncHealthStatus.error:
        return (
          const Color(0xFFFEE2E2),
          const Color(0xFFEF4444),
          Icons.cloud_off_rounded,
        );
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'Hace un momento';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours}h';
    return '${time.day}/${time.month} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatRelativeTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inHours < 1) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours}h';
    if (diff.inDays == 1) return 'ayer';
    return 'hace ${diff.inDays} días';
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
