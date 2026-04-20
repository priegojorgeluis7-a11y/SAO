import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/config/data_mode.dart';
import '../../core/navigation/role_view_access.dart';
import '../../core/providers/app_refresh_provider.dart';
import '../../core/settings/report_export_settings.dart';
import '../../data/repositories/backend_api_client.dart';
import '../../features/auth/app_session_controller.dart';

enum _ConnectionProbeStatus {
  idle,
  checking,
  online,
  error,
}

const List<String> _rolePermissionEditorRoles = <String>[
  'ADMIN',
  'COORD',
  'SUPERVISOR',
  'OPERATIVO',
  'LECTOR',
];

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  String? _defaultReportsRootPath;
  _ConnectionProbeStatus _connectionStatus = _ConnectionProbeStatus.idle;
  String _connectionMessage = 'Sin verificacion reciente';
  int? _connectionLatencyMs;
  DateTime? _lastConnectionCheck;
  String _appVersion = '1.0.0';
  String _appBuildNumber = '1';

  @override
  void initState() {
    super.initState();
    _loadInitialState();
  }

  Future<void> _loadInitialState() async {
    await Future.wait([
      _loadReportSettings(),
      _loadAppInfo(),
    ]);
  }

  Future<void> _loadReportSettings() async {
    try {
      final path = await ReportExportSettings.readDefaultRootPath();
      if (!mounted) return;
      setState(() => _defaultReportsRootPath = path);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo leer carpeta de reportes: $error')),
      );
    }
  }

  Future<void> _loadAppInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _appVersion = info.version;
        _appBuildNumber = info.buildNumber;
      });
    } catch (_) {
      // Keep safe fallback values if package metadata is unavailable.
    }
  }

  Future<void> _pickDefaultReportsFolder() async {
    try {
      final path = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Selecciona carpeta raiz para reportes',
      );
      if (!mounted) return;
      if (path == null || path.trim().isEmpty) return;

      await ReportExportSettings.writeDefaultRootPath(path.trim());
      if (!mounted) return;
      setState(() => _defaultReportsRootPath = path.trim());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Carpeta base guardada.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar carpeta base: $error')),
      );
    }
  }

  Future<void> _resetDefaultReportsFolder() async {
    try {
      await ReportExportSettings.writeDefaultRootPath(null);
      if (!mounted) return;
      setState(() => _defaultReportsRootPath = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ruta predeterminada restablecida.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo restablecer ruta: $error')),
      );
    }
  }

  Future<void> _probeConnection() async {
    setState(() {
      _connectionStatus = _ConnectionProbeStatus.checking;
      _connectionMessage = 'Verificando conexion...';
      _connectionLatencyMs = null;
    });

    final stopwatch = Stopwatch()..start();
    try {
      final baseUrl = AppDataMode.backendBaseUrl.trim();
      if (baseUrl.isEmpty) {
        throw StateError('SAO_BACKEND_URL no esta configurado');
      }

      final uri = Uri.parse('$baseUrl/health');
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
      try {
        final request = await client.getUrl(uri);
        final response = await request.close().timeout(const Duration(seconds: 12));
        final body = await response.transform(const Utf8Decoder()).join();
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw HttpException('HTTP ${response.statusCode}: $body', uri: uri);
        }
      } finally {
        client.close(force: true);
      }
      stopwatch.stop();
      if (!mounted) return;
      setState(() {
        _connectionStatus = _ConnectionProbeStatus.online;
        _connectionMessage = 'Conexion correcta con backend';
        _connectionLatencyMs = stopwatch.elapsedMilliseconds;
        _lastConnectionCheck = DateTime.now();
      });
    } catch (error) {
      stopwatch.stop();
      if (!mounted) return;
      setState(() {
        _connectionStatus = _ConnectionProbeStatus.error;
        _connectionMessage = 'Error de conexion: $error';
        _connectionLatencyMs = stopwatch.elapsedMilliseconds;
        _lastConnectionCheck = DateTime.now();
      });
    }
  }

  String _platformLabel() {
    if (Platform.isMacOS) return 'macOS Desktop';
    if (Platform.isWindows) return 'Windows Desktop';
    if (Platform.isLinux) return 'Linux Desktop';
    return '${Platform.operatingSystem} Desktop';
  }

  String _connectionStatusLabel() {
    switch (_connectionStatus) {
      case _ConnectionProbeStatus.idle:
        return 'Sin verificar';
      case _ConnectionProbeStatus.checking:
        return 'Verificando';
      case _ConnectionProbeStatus.online:
        return 'Conectado';
      case _ConnectionProbeStatus.error:
        return 'Sin conexion';
    }
  }

  Color _connectionStatusColor() {
    switch (_connectionStatus) {
      case _ConnectionProbeStatus.idle:
        return Colors.grey;
      case _ConnectionProbeStatus.checking:
        return Colors.orange;
      case _ConnectionProbeStatus.online:
        return Colors.green;
      case _ConnectionProbeStatus.error:
        return Colors.red;
    }
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return 'Sin intentos';
    final local = dt.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$dd/$mm/${local.year} $hh:$min';
  }

  bool _isAdminUser(AppUser? user) {
    return user?.isAdmin ?? false;
  }

  bool _isRootAdminUser(AppUser? user) {
    return isRootAdminUser(user);
  }

  Future<void> _openRolePermissionManager() async {
    await showDialog<void>(
      context: context,
      builder: (_) => const _RolePermissionSettingsDialog(),
    );
  }

  Future<void> _openRoleViewAccessManager() async {
    await showDialog<void>(
      context: context,
      builder: (_) => const _RoleViewAccessDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final currentUser = ref.watch(currentAppUserProvider);
    final canManageRolePermissions = _isAdminUser(currentUser);
    final canManageViewAccess = _isRootAdminUser(currentUser);
    const backendUrl = AppDataMode.backendBaseUrl;
    final reportsRootLabel =
      _defaultReportsRootPath ?? 'Documentos del usuario (predeterminado)';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Reportes ────────────────────────────────────────────────
              const _SectionHeader(
                title: 'Reportes',
                icon: Icons.folder_rounded,
              ),
              const SizedBox(height: 12),
              _SettingsCard(
                children: [
                  _CopyRow(
                    label: 'Carpeta base',
                    value: reportsRootLabel,
                  ),
                  const _Divider(),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ruta predeterminada para PDF',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: cs.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Se usa al guardar reportes cuando eliges ruta predeterminada.',
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
                          onPressed: _pickDefaultReportsFolder,
                          icon: const Icon(Icons.edit_location_alt_rounded, size: 16),
                          label: const Text('Elegir'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _defaultReportsRootPath == null
                              ? null
                              : _resetDefaultReportsFolder,
                          icon: const Icon(Icons.restore_rounded, size: 16),
                          label: const Text('Restablecer'),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 140,
                          child: Text(
                            'Estado',
                            style: TextStyle(
                              fontSize: 13,
                              color: cs.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.circle,
                                    size: 10,
                                    color: _connectionStatusColor(),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _connectionStatusLabel(),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: cs.onSurface,
                                    ),
                                  ),
                                  if (_connectionLatencyMs != null) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      '$_connectionLatencyMs ms',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: cs.onSurface.withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _connectionMessage,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Ultima verificacion: ${_formatDateTime(_lastConnectionCheck)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: cs.onSurface.withValues(alpha: 0.45),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        OutlinedButton.icon(
                          onPressed: _connectionStatus == _ConnectionProbeStatus.checking
                              ? null
                              : _probeConnection,
                          icon: _connectionStatus == _ConnectionProbeStatus.checking
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.network_check_rounded, size: 16),
                          label: Text(
                            _connectionStatus == _ConnectionProbeStatus.checking
                                ? 'Verificando...'
                                : 'Probar conexion',
                          ),
                        ),
                      ],
                    ),
                  ),
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

              if (canManageRolePermissions) ...[
                const _SectionHeader(
                  title: 'Administración',
                  icon: Icons.admin_panel_settings_rounded,
                ),
                const SizedBox(height: 12),
                _SettingsCard(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Permisos generales de roles',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: cs.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Modifica la matriz base que usan los roles del sistema.',
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
                            onPressed: _openRolePermissionManager,
                            icon: const Icon(Icons.security_rounded, size: 16),
                            label: const Text('Modificar'),
                          ),
                        ],
                      ),
                    ),
                    if (canManageViewAccess) const _Divider(),
                    if (canManageViewAccess)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Acceso a vistas del programa',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: cs.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Administra qué módulos puede ver cada rol en el escritorio.',
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
                              onPressed: _openRoleViewAccessManager,
                              icon: const Icon(Icons.view_sidebar_rounded, size: 16),
                              label: const Text('Administrar'),
                            ),
                          ],
                        ),
                      ),
                    const _Divider(),
                    _InfoRow(
                      label: 'Acceso',
                      value: canManageViewAccess
                          ? 'Solo admin@sao.mx para vistas; administradores para permisos'
                          : 'Solo administradores',
                      hint: 'Aplica cambios globales a los permisos base por rol.',
                    ),
                  ],
                ),
                const SizedBox(height: 28),
              ],

              // ── Acerca de ────────────────────────────────────────────────
              const _SectionHeader(
                  title: 'Acerca de', icon: Icons.info_outline_rounded),
              const SizedBox(height: 12),
              _SettingsCard(
                children: [
                  const _InfoRow(label: 'Sistema', value: 'SAO Desktop'),
                  const _Divider(),
                  _InfoRow(
                    label: 'Version',
                    value: _appVersion,
                    hint: 'Build $_appBuildNumber',
                  ),
                  const _Divider(),
                  const _InfoRow(
                    label: 'Organizacion',
                    value: 'ATTRAPI',
                  ),
                  const _Divider(),
                  _InfoRow(label: 'Plataforma', value: _platformLabel()),
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


class _RoleViewAccessDialog extends StatefulWidget {
  const _RoleViewAccessDialog();

  @override
  State<_RoleViewAccessDialog> createState() => _RoleViewAccessDialogState();
}

class _RoleViewAccessDialogState extends State<_RoleViewAccessDialog> {
  bool _loading = true;
  bool _saving = false;
  String? _errorMessage;
  List<String> _permissionCatalog = const <String>[];
  Map<String, Set<String>> _rolePermissions = <String, Set<String>>{};

  @override
  void initState() {
    super.initState();
    _loadRolePermissions();
  }

  Future<void> _loadRolePermissions() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final catalogResponse =
          await const BackendApiClient().getJson('/api/v1/users/admin/permissions');
      final roleResponse = await const BackendApiClient()
          .getJson('/api/v1/users/admin/role-permissions');

      final permissionCatalog = catalogResponse is List
          ? catalogResponse
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toList()
          : <String>[];

      final rolePermissions = <String, Set<String>>{
        for (final role in _rolePermissionEditorRoles) role: <String>{},
      };

      if (roleResponse is Map<String, dynamic>) {
        roleResponse.forEach((key, value) {
          final role = key.trim().toUpperCase();
          if (!rolePermissions.containsKey(role) || value is! List) return;
          rolePermissions[role] = value
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toSet();
        });
      }

      final resolvedCatalog = permissionCatalog.isNotEmpty
          ? permissionCatalog
          : rolePermissions.values.expand((items) => items).toSet().toList();
      rolePermissions['ADMIN'] = resolvedCatalog.toSet();

      if (!mounted) return;
      setState(() {
        _permissionCatalog = resolvedCatalog;
        _rolePermissions = rolePermissions;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'No se pudo cargar la configuración de vistas: $error';
        _loading = false;
      });
    }
  }

  void _toggleViewAccess(String role, String moduleLabel, bool enabled) {
    if (role == 'ADMIN') return;
    setState(() {
      _rolePermissions[role] = updateRoleShellViewAccess(
        _rolePermissions[role] ?? <String>{},
        moduleLabel,
        enabled,
      );
    });
  }

  Future<void> _saveViewAccess() async {
    setState(() => _saving = true);
    try {
      final payload = <String, List<String>>{
        for (final role in _rolePermissionEditorRoles)
          role: role == 'ADMIN'
              ? List<String>.from(_permissionCatalog)
              : ((_rolePermissions[role] ?? const <String>{}).toList()..sort()),
      };

      await const BackendApiClient().putJson(
        '/api/v1/users/admin/role-permissions',
        {'role_permissions': payload},
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Acceso a vistas actualizado. Si el usuario ya estaba dentro, debe volver a iniciar sesión.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'No se pudieron guardar los accesos: $error';
      });
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.view_sidebar_rounded),
          SizedBox(width: 8),
          Expanded(child: Text('Acceso a vistas del programa')),
        ],
      ),
      content: SizedBox(
        width: 760,
        child: _loading
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            : _errorMessage != null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _errorMessage!,
                        style: TextStyle(color: cs.error),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _loadRolePermissions,
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Reintentar'),
                      ),
                    ],
                  )
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Este panel ajusta los permisos base asociados a cada módulo del escritorio.',
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 12),
                        for (final role in _rolePermissionEditorRoles)
                          _RoleViewAccessGroup(
                            role: role,
                            selectedPermissions:
                                _rolePermissions[role] ?? const <String>{},
                            locked: role == 'ADMIN',
                            onChanged: (moduleLabel, enabled) =>
                                _toggleViewAccess(role, moduleLabel, enabled),
                          ),
                      ],
                    ),
                  ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
        FilledButton.icon(
          onPressed: _loading || _saving ? null : _saveViewAccess,
          icon: _saving
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_rounded, size: 16),
          label: Text(_saving ? 'Guardando...' : 'Guardar cambios'),
        ),
      ],
    );
  }
}

class _RoleViewAccessGroup extends StatelessWidget {
  final String role;
  final Set<String> selectedPermissions;
  final bool locked;
  final void Function(String moduleLabel, bool enabled) onChanged;

  const _RoleViewAccessGroup({
    required this.role,
    required this.selectedPermissions,
    required this.locked,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ExpansionTile(
        initiallyExpanded: role != 'LECTOR',
        title: Text(role),
        subtitle: Text(
          locked
              ? 'Acceso total protegido'
              : 'Selecciona qué módulos puede ver este rol',
        ),
        children: [
          if (locked)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'ADMIN conserva acceso total para evitar bloqueos del sistema.',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
          for (final moduleLabel in shellModuleOrder)
            CheckboxListTile(
              dense: true,
              value: roleHasShellViewAccess(role, selectedPermissions, moduleLabel),
              onChanged: locked || !configurableShellModuleLabels.contains(moduleLabel)
                  ? null
                  : (value) => onChanged(moduleLabel, value ?? false),
              title: Text(moduleLabel, style: const TextStyle(fontSize: 13)),
              subtitle: !configurableShellModuleLabels.contains(moduleLabel)
                  ? const Text('Vista protegida y siempre disponible')
                  : null,
              controlAffinity: ListTileControlAffinity.leading,
            ),
        ],
      ),
    );
  }
}

class _RolePermissionSettingsDialog extends StatefulWidget {
  const _RolePermissionSettingsDialog();

  @override
  State<_RolePermissionSettingsDialog> createState() =>
      _RolePermissionSettingsDialogState();
}

class _RolePermissionSettingsDialogState
    extends State<_RolePermissionSettingsDialog> {
  bool _loading = true;
  bool _saving = false;
  String? _errorMessage;
  List<String> _permissionCatalog = const <String>[];
  Map<String, Set<String>> _rolePermissions = <String, Set<String>>{};

  @override
  void initState() {
    super.initState();
    _loadRolePermissions();
  }

  Future<void> _loadRolePermissions() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final catalogResponse =
          await const BackendApiClient().getJson('/api/v1/users/admin/permissions');
      final roleResponse = await const BackendApiClient()
          .getJson('/api/v1/users/admin/role-permissions');

      final permissionCatalog = catalogResponse is List
          ? catalogResponse
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toList()
          : <String>[];

      final rolePermissions = <String, Set<String>>{
        for (final role in _rolePermissionEditorRoles) role: <String>{},
      };

      if (roleResponse is Map<String, dynamic>) {
        roleResponse.forEach((key, value) {
          final role = key.trim().toUpperCase();
          if (!rolePermissions.containsKey(role) || value is! List) return;
          rolePermissions[role] = value
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toSet();
        });
      }

      final resolvedCatalog = permissionCatalog.isNotEmpty
          ? permissionCatalog
          : rolePermissions.values.expand((items) => items).toSet().toList();
      rolePermissions['ADMIN'] = resolvedCatalog.toSet();

      if (!mounted) return;
      setState(() {
        _permissionCatalog = resolvedCatalog;
        _rolePermissions = rolePermissions;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'No se pudieron cargar los permisos globales: $error';
        _loading = false;
      });
    }
  }

  void _togglePermission(String role, String permissionCode, bool enabled) {
    if (role == 'ADMIN') return;
    final updated = Set<String>.from(_rolePermissions[role] ?? <String>{});
    if (enabled) {
      updated.add(permissionCode);
    } else {
      updated.remove(permissionCode);
    }
    setState(() {
      _rolePermissions[role] = updated;
    });
  }

  Future<void> _saveRolePermissions() async {
    setState(() => _saving = true);
    try {
      final payload = <String, List<String>>{
        for (final role in _rolePermissionEditorRoles)
          role: role == 'ADMIN'
              ? List<String>.from(_permissionCatalog)
              : _permissionCatalog
                  .where((permission) =>
                      (_rolePermissions[role] ?? const <String>{})
                          .contains(permission))
                  .toList(),
      };

      final response = await const BackendApiClient().putJson(
        '/api/v1/users/admin/role-permissions',
        {'role_permissions': payload},
      );

      if (response is Map<String, dynamic>) {
        final normalized = <String, Set<String>>{
          for (final role in _rolePermissionEditorRoles) role: <String>{},
        };
        response.forEach((key, value) {
          final role = key.trim().toUpperCase();
          if (!normalized.containsKey(role) || value is! List) return;
          normalized[role] = value
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toSet();
        });
        normalized['ADMIN'] = _permissionCatalog.toSet();
        _rolePermissions = normalized;
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permisos generales actualizados correctamente.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'No se pudieron guardar los cambios: $error';
      });
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.security_rounded),
          SizedBox(width: 8),
          Expanded(child: Text('Permisos generales de roles')),
        ],
      ),
      content: SizedBox(
        width: 760,
        child: _loading
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            : _errorMessage != null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _errorMessage!,
                        style: TextStyle(color: cs.error),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _loadRolePermissions,
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Reintentar'),
                      ),
                    ],
                  )
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Define qué permisos base recibe cada rol al entrar al sistema.',
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 12),
                        for (final role in _rolePermissionEditorRoles)
                          _RolePermissionGroup(
                            role: role,
                            permissionCatalog: _permissionCatalog,
                            selectedPermissions:
                                _rolePermissions[role] ?? const <String>{},
                            locked: role == 'ADMIN',
                            onChanged: (permissionCode, enabled) =>
                                _togglePermission(role, permissionCode, enabled),
                          ),
                      ],
                    ),
                  ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
        FilledButton.icon(
          onPressed: _loading || _saving || _permissionCatalog.isEmpty
              ? null
              : _saveRolePermissions,
          icon: _saving
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_rounded, size: 16),
          label: Text(_saving ? 'Guardando...' : 'Guardar cambios'),
        ),
      ],
    );
  }
}

class _RolePermissionGroup extends StatelessWidget {
  final String role;
  final List<String> permissionCatalog;
  final Set<String> selectedPermissions;
  final bool locked;
  final void Function(String permissionCode, bool enabled) onChanged;

  const _RolePermissionGroup({
    required this.role,
    required this.permissionCatalog,
    required this.selectedPermissions,
    required this.locked,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ExpansionTile(
        initiallyExpanded: role != 'LECTOR',
        title: Text(role),
        subtitle: Text(
          locked
              ? 'Acceso total protegido'
              : '${selectedPermissions.length} permisos activos',
        ),
        children: [
          if (locked)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'ADMIN conserva acceso total para evitar bloqueos del sistema.',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
          for (final permissionCode in permissionCatalog)
            CheckboxListTile(
              dense: true,
              value: selectedPermissions.contains(permissionCode),
              onChanged: locked
                  ? null
                  : (value) => onChanged(permissionCode, value ?? false),
              title: Text(
                permissionCode,
                style: const TextStyle(fontSize: 13),
              ),
              controlAffinity: ListTileControlAffinity.leading,
            ),
        ],
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
