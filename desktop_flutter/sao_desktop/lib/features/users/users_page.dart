import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers/project_providers.dart';
import '../../data/repositories/backend_api_client.dart';
import '../../ui/helpers/sao_contrast.dart';
import '../../ui/theme/sao_colors.dart';

const List<String> _localPermissionCatalog = <String>[
  'Ver actividades',
  'Crear actividades',
  'Editar actividades',
  'Eliminar actividades',
  'Aprobar actividades',
  'Rechazar actividades',
  'Crear eventos',
  'Editar eventos',
  'Ver eventos',
  'Ver catálogo',
  'Editar catálogo',
  'Publicar catálogo',
  'Crear usuarios',
  'Editar usuarios',
  'Ver usuarios',
  'Ver reportes',
  'Exportar reportes',
  'Administrar asignaciones',
  'Administrar proyectos',
  'Aprobar excepciones de flujo',
];

const Map<String, List<String>> _localRolePermissions = <String, List<String>>{
  'ADMIN': _localPermissionCatalog,
  'COORD': <String>[
    'Ver actividades',
    'Crear actividades',
    'Editar actividades',
    'Aprobar actividades',
    'Rechazar actividades',
    'Crear eventos',
    'Editar eventos',
    'Ver eventos',
    'Ver catálogo',
    'Ver reportes',
    'Exportar reportes',
    'Administrar asignaciones',
  ],
  'SUPERVISOR': <String>[
    'Ver actividades',
    'Crear actividades',
    'Editar actividades',
    'Aprobar actividades',
    'Rechazar actividades',
    'Crear eventos',
    'Editar eventos',
    'Ver eventos',
    'Ver reportes',
  ],
  'OPERATIVO': <String>[
    'Ver actividades',
    'Crear actividades',
    'Ver eventos',
    'Crear eventos',
  ],
  'LECTOR': <String>[
    'Ver actividades',
    'Ver eventos',
    'Ver catálogo',
    'Ver usuarios',
    'Ver reportes',
  ],
};

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

class _AdminUser {
  final String id;
  final String fullName;
  final String email;
  final List<String> roles;
  final String status;
  final List<String> projectIds;
  final List<_UserScope> scopes;
  final List<String> permissionCodes;
  final List<_UserPermissionScope> permissionScopes;

  const _AdminUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.roles,
    required this.status,
    required this.projectIds,
    required this.scopes,
    required this.permissionCodes,
    required this.permissionScopes,
  });

  bool get isActive => status.toLowerCase() == 'active';
  String get primaryRole => roles.isNotEmpty ? roles.first : '';
  String? get primaryProjectId =>
      projectIds.isNotEmpty ? projectIds.first : null;

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  factory _AdminUser.fromJson(Map<String, dynamic> json) {
    final roles = _stringList(json['roles']);
    final projectIds = _stringList(json['project_ids']);
    final scopesJson = json['scopes'];
    final scopes = scopesJson is List
        ? scopesJson
            .whereType<Map<String, dynamic>>()
            .map(_UserScope.fromJson)
            .toList()
        : <_UserScope>[];
    final fallbackRole =
        (json['role_name'] ?? json['role'] ?? '').toString().trim();
    final fallbackProject = (json['project_id'] ?? '').toString().trim();
    final permissionScopesJson = json['permission_scopes'];
    final permissionScopes = permissionScopesJson is List
        ? permissionScopesJson
            .whereType<Map<String, dynamic>>()
            .map(_UserPermissionScope.fromJson)
            .toList()
        : <_UserPermissionScope>[];

    return _AdminUser(
      id: (json['id'] ?? '').toString(),
      fullName: (json['full_name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      roles: roles.isNotEmpty
          ? roles
          : (fallbackRole.isNotEmpty ? <String>[fallbackRole] : const []),
      status: (json['status'] ?? 'active').toString(),
      projectIds: projectIds.isNotEmpty
          ? projectIds
          : (fallbackProject.isNotEmpty ? <String>[fallbackProject] : const []),
      scopes: scopes,
      permissionCodes: _stringList(json['permission_codes']),
      permissionScopes: permissionScopes,
    );
  }
}

class _UserScope {
  final String role;
  final String? projectId;

  const _UserScope({required this.role, required this.projectId});

  factory _UserScope.fromJson(Map<String, dynamic> json) {
    final projectRaw = (json['project_id'] ?? '').toString().trim();
    return _UserScope(
      role: (json['role_name'] ?? json['role'] ?? '').toString().trim(),
      projectId: projectRaw.isEmpty ? null : projectRaw,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'role': role,
      'project_id': projectId,
    };
  }
}

class _ScopeDraft {
  String role;
  String projectId;

  _ScopeDraft({required this.role, required this.projectId});

  factory _ScopeDraft.fromScope(_UserScope scope) {
    return _ScopeDraft(
      role: scope.role.isEmpty ? 'OPERATIVO' : scope.role.toUpperCase(),
      projectId: (scope.projectId ?? '').toUpperCase(),
    );
  }

  _UserScope toScope() {
    final normalizedProject = projectId.trim().toUpperCase();
    return _UserScope(
      role: role.trim().toUpperCase(),
      projectId: normalizedProject.isEmpty ? null : normalizedProject,
    );
  }
}

class _UserPermissionScope {
  final String permissionCode;
  final String? projectId;
  final String effect;

  const _UserPermissionScope({
    required this.permissionCode,
    required this.projectId,
    required this.effect,
  });

  factory _UserPermissionScope.fromJson(Map<String, dynamic> json) {
    final projectRaw = (json['project_id'] ?? '').toString().trim();
    return _UserPermissionScope(
      permissionCode: (json['permission_code'] ?? json['permission'] ?? '')
          .toString()
          .trim(),
      projectId: projectRaw.isEmpty ? null : projectRaw,
      effect: (json['effect'] ?? 'allow').toString().trim().toLowerCase(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'permission_code': permissionCode,
      'project_id': projectId,
      'effect': effect,
    };
  }
}

class _UserActivityItem {
  final String id;
  final String title;
  final String activityTypeCode;
  final String projectId;
  final String executionState;
  final DateTime? createdAt;
  final bool assigned;
  final bool created;

  const _UserActivityItem({
    required this.id,
    required this.title,
    required this.activityTypeCode,
    required this.projectId,
    required this.executionState,
    required this.createdAt,
    required this.assigned,
    required this.created,
  });
}

class _UserActivitySummary {
  final int assignedCount;
  final int createdCount;
  final Map<String, int> byState;
  final List<_UserActivityItem> recentItems;
  final String? error;

  const _UserActivitySummary({
    required this.assignedCount,
    required this.createdCount,
    required this.byState,
    required this.recentItems,
    this.error,
  });

  int get totalCount => assignedCount + createdCount;

  static const empty = _UserActivitySummary(
    assignedCount: 0,
    createdCount: 0,
    byState: <String, int>{},
    recentItems: <_UserActivityItem>[],
  );
}

typedef _RolePermissionsMap = Map<String, List<String>>;

class _PermissionScopeDraft {
  String permissionCode;
  String projectId;
  String effect;

  _PermissionScopeDraft({
    required this.permissionCode,
    required this.projectId,
    required this.effect,
  });

  factory _PermissionScopeDraft.fromScope(_UserPermissionScope scope) {
    return _PermissionScopeDraft(
      permissionCode: scope.permissionCode,
      projectId: (scope.projectId ?? '').toUpperCase(),
      effect: scope.effect,
    );
  }

  _UserPermissionScope toScope() {
    final normalizedProject = projectId.trim().toUpperCase();
    return _UserPermissionScope(
      permissionCode: permissionCode.trim(),
      projectId: normalizedProject.isEmpty ? null : normalizedProject,
      effect: effect.trim().toLowerCase() == 'deny' ? 'deny' : 'allow',
    );
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final _adminUsersProvider =
    FutureProvider.autoDispose<List<_AdminUser>>((ref) async {
  try {
    final decoded =
        await const BackendApiClient().getJson('/api/v1/users/admin');
    if (decoded is! List) return [];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(_AdminUser.fromJson)
        .toList();
  } on HttpException catch (e) {
    throw Exception('Error del servidor: ${e.message}');
  }
});

final _adminPermissionsProvider =
    FutureProvider.autoDispose<List<String>>((ref) async {
  try {
    final decoded = await const BackendApiClient()
        .getJson('/api/v1/users/admin/permissions');
    if (decoded is! List) return const [];
    return decoded
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  } on HttpException {
    return const [];
  }
});

final _adminRolePermissionsProvider =
    FutureProvider.autoDispose<_RolePermissionsMap>((ref) async {
  try {
    final decoded = await const BackendApiClient()
        .getJson('/api/v1/users/admin/role-permissions');
    if (decoded is! Map<String, dynamic>) return const {};
    final result = <String, List<String>>{};
    decoded.forEach((key, value) {
      final role = key.trim().toUpperCase();
      if (role.isEmpty) return;
      if (value is! List) {
        result[role] = const [];
        return;
      }
      result[role] = value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    });
    return result;
  } on HttpException {
    return const {};
  }
});

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

class UsersPage extends ConsumerStatefulWidget {
  const UsersPage({super.key});

  @override
  ConsumerState<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends ConsumerState<UsersPage> {
  String _roleFilter = 'Todos';
  String _statusFilter = 'Todos';
  String _projectFilter = 'Todos';
  String _search = '';
  String _sortBy = 'nombre'; // nombre, correo, rol, estado
  bool _sortAscending = true;
  _AdminUser? _selectedUser;
  String? _selectedUserId;
  String _activityViewFilter = 'Todas';
  int _activityRangeDays = 0;
  final Map<String, Future<_UserActivitySummary>> _activitySummaryCache =
      <String, Future<_UserActivitySummary>>{};
  final _searchCtrl = TextEditingController();
  final _detailPanelScrollCtrl = ScrollController();
  final _projectsSectionKey = GlobalKey();
  final _permissionsSectionKey = GlobalKey();
  Timer? _searchDebounce;
  final Set<String> _processingStatusIds = <String>{};

  static const _roles = [
    'Todos',
    'ADMIN',
    'SUPERVISOR',
    'COORD',
    'OPERATIVO',
    'LECTOR'
  ];
  static const _statusOptions = ['Todos', 'Activos', 'Inactivos'];

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _detailPanelScrollCtrl.dispose();
    _searchCtrl
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  bool get _hasActiveFilters =>
      _roleFilter != 'Todos' ||
      _statusFilter != 'Todos' ||
      _projectFilter != 'Todos' ||
      _search.isNotEmpty;

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() => _search = _searchCtrl.text.trim());
    });
  }

  void _clearFilters() {
    _searchDebounce?.cancel();
    _searchCtrl.clear();
    setState(() {
      _roleFilter = 'Todos';
      _statusFilter = 'Todos';
      _projectFilter = 'Todos';
      _search = '';
      _selectedUser = null;
      _selectedUserId = null;
    });
  }

  _AdminUser? _resolveSelectedUser(List<_AdminUser> users) {
    final selectedId = (_selectedUserId ?? _selectedUser?.id ?? '').trim();
    if (selectedId.isEmpty) return null;
    for (final user in users) {
      if (user.id == selectedId) return user;
    }
    return null;
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchCtrl.clear();
    setState(() => _search = '');
  }

  List<String> _resolveAvailablePermissions(List<String> remotePermissions) {
    if (remotePermissions.isNotEmpty) {
      return remotePermissions;
    }
    return _localPermissionCatalog;
  }

  _RolePermissionsMap _resolveRolePermissions(
      _RolePermissionsMap remoteRolePermissions) {
    if (remoteRolePermissions.isNotEmpty) {
      return remoteRolePermissions;
    }
    return _localRolePermissions;
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(_adminUsersProvider);
    final permissionsAsync = ref.watch(_adminPermissionsProvider);
    final rolePermissionsAsync = ref.watch(_adminRolePermissionsProvider);
    final projectsAsync = ref.watch(availableProjectsProvider);
    final allUsers = usersAsync.valueOrNull ?? const <_AdminUser>[];
    final availablePermissions = _resolveAvailablePermissions(
      permissionsAsync.valueOrNull ?? const <String>[],
    );
    final rolePermissions = _resolveRolePermissions(
      rolePermissionsAsync.valueOrNull ?? const <String, List<String>>{},
    );
    final availableProjects = projectsAsync.valueOrNull ?? const <String>[];
    final resolvedSelectedUser = _resolveSelectedUser(allUsers);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        children: [
          _buildToolbar(
            context,
            totalUsers: allUsers.length,
            filteredUsers: _applyFilters(allUsers).length,
            availableProjects: availableProjects,
          ),
          const SizedBox(height: 12),
          _buildStatsBar(allUsers),
          const SizedBox(height: 12),
          Expanded(
            child: usersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorView(
                message: e.toString(),
                onRetry: () => ref.invalidate(_adminUsersProvider),
              ),
              data: (users) {
                final filtered = _applyFilters(users);
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        margin: EdgeInsets.only(
                            right: resolvedSelectedUser == null ? 0 : 14),
                        child: _UsersTable(
                          users: filtered,
                          processingStatusIds: _processingStatusIds,
                          sortBy: _sortBy,
                          sortAscending: _sortAscending,
                          onSort: (column) => setState(() {
                            if (_sortBy == column) {
                              _sortAscending = !_sortAscending;
                            } else {
                              _sortBy = column;
                              _sortAscending = true;
                            }
                          }),
                          selectedUserId: resolvedSelectedUser?.id,
                          onSelectUser: (user) => setState(() {
                            _selectedUser = user;
                            _selectedUserId = user.id;
                          }),
                          onEdit: (u) => _openEditDialog(
                              context,
                              u,
                              availablePermissions,
                              rolePermissions,
                              availableProjects),
                          onManagePermissions: (u) => _openPermissionsDialog(
                            context,
                            u,
                            availablePermissions,
                            rolePermissions,
                            availableProjects,
                          ),
                          onToggleStatus: (u) => _toggleStatus(context, u),
                          onDelete: (u) => _deleteUser(context, u),
                        ),
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      width: resolvedSelectedUser == null ? 0 : 390,
                      decoration: BoxDecoration(
                        color: SaoColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: resolvedSelectedUser == null
                            ? null
                            : Border.all(color: SaoColors.gray200),
                        boxShadow: resolvedSelectedUser == null
                            ? null
                            : [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 12,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: resolvedSelectedUser == null
                          ? const SizedBox.shrink()
                          : Column(
                              children: [
                                Container(
                                  padding:
                                      const EdgeInsets.fromLTRB(18, 14, 14, 14),
                                  decoration: BoxDecoration(
                                    color: SaoColors.gray50,
                                    border: Border(
                                        bottom: BorderSide(
                                            color: SaoColors.gray200)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Detalle de usuario',
                                        style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close_rounded,
                                            size: 18),
                                        tooltip: 'Cerrar',
                                        onPressed: () => setState(() {
                                          _selectedUser = null;
                                          _selectedUserId = null;
                                        }),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: _buildDetailsPanel(
                                    resolvedSelectedUser,
                                    availablePermissions,
                                    rolePermissions,
                                    availableProjects,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar(List<_AdminUser> allUsers) {
    final stats = _computeRoleStats(allUsers);
    final total = allUsers.length;
    final selectedRole = _roleFilter.toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: SaoColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SaoColors.gray200),
      ),
      child: Wrap(
        spacing: 20,
        runSpacing: 8,
        children: [
          _statChip(
            'Total',
            total.toString(),
            SaoColors.primary,
            isSelected: _roleFilter == 'Todos',
            onTap: () => _setRoleFilterFromStats('Todos'),
          ),
          _statChip(
            'ADMIN',
            stats['ADMIN'].toString(),
            const Color(0xFF6366F1),
            isSelected: selectedRole == 'ADMIN',
            onTap: () => _setRoleFilterFromStats('ADMIN'),
          ),
          _statChip(
            'SUPERVISOR',
            stats['SUPERVISOR'].toString(),
            const Color(0xFF3B82F6),
            isSelected: selectedRole == 'SUPERVISOR',
            onTap: () => _setRoleFilterFromStats('SUPERVISOR'),
          ),
          _statChip(
            'COORD',
            stats['COORD'].toString(),
            const Color(0xFF64748B),
            isSelected: selectedRole == 'COORD',
            onTap: () => _setRoleFilterFromStats('COORD'),
          ),
          _statChip(
            'OPERATIVO',
            stats['OPERATIVO'].toString(),
            const Color(0xFF14B8A6),
            isSelected: selectedRole == 'OPERATIVO',
            onTap: () => _setRoleFilterFromStats('OPERATIVO'),
          ),
          _statChip(
            'LECTOR',
            stats['LECTOR'].toString(),
            SaoColors.gray600,
            isSelected: selectedRole == 'LECTOR',
            onTap: () => _setRoleFilterFromStats('LECTOR'),
          ),
        ],
      ),
    );
  }

  void _setRoleFilterFromStats(String role) {
    setState(() {
      if (role == 'Todos') {
        _roleFilter = 'Todos';
        return;
      }
      _roleFilter = _roleFilter == role ? 'Todos' : role;
    });
  }

  Widget _statChip(
    String label,
    String count,
    Color color, {
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final borderColor = isSelected ? color : color.withValues(alpha: 0.45);
    final backgroundColor = isSelected
        ? color.withValues(alpha: 0.20)
        : color.withValues(alpha: 0.10);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$label: ',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: SaoColors.gray700,
                ),
              ),
              Text(
                count,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: SaoColors.gray900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolbar(
    BuildContext context, {
    required int totalUsers,
    required int filteredUsers,
    required List<String> availableProjects,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: SaoColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SaoColors.gray200),
      ),
      child: Row(children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gestión de Usuarios',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              '$filteredUsers de $totalUsers usuarios',
              style: const TextStyle(
                color: SaoColors.gray600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: SaoColors.gray50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: SaoColors.gray200),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Buscar...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon: _searchCtrl.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Limpiar búsqueda',
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: _clearSearch,
                          ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: SaoColors.gray200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: SaoColors.gray200),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _FilterDropdown(
                label: 'Rol',
                value: _roleFilter,
                items: _roles,
                onChanged: (v) => setState(() => _roleFilter = v),
              ),
              const SizedBox(width: 8),
              _FilterDropdown(
                label: 'Estado',
                value: _statusFilter,
                items: _statusOptions,
                onChanged: (v) => setState(() => _statusFilter = v),
              ),
              const SizedBox(width: 8),
              _FilterDropdown(
                label: 'Proyecto',
                value: _projectFilter,
                items: ['Todos', ...availableProjects],
                onChanged: (v) => setState(() => _projectFilter = v),
              ),
              if (_hasActiveFilters) ...[
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
                  label: const Text('Limpiar'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Refrescar',
          onPressed: () => ref.invalidate(_adminUsersProvider),
        ),
        const SizedBox(width: 4),
        FilledButton.icon(
          icon: const Icon(Icons.person_add_rounded, size: 18),
          label: const Text('Nuevo usuario'),
          onPressed: () => _openCreateDialog(context),
        ),
      ]),
    );
  }

  List<_AdminUser> _applyFilters(List<_AdminUser> users) {
    var filtered = users.where((u) {
      if (_roleFilter != 'Todos' &&
          !u.roles
              .map((r) => r.toUpperCase())
              .contains(_roleFilter.toUpperCase())) {
        return false;
      }
      if (_statusFilter == 'Activos' && !u.isActive) return false;
      if (_statusFilter == 'Inactivos' && u.isActive) return false;
      if (_projectFilter != 'Todos' &&
          !u.projectIds
              .map((p) => p.toUpperCase())
              .contains(_projectFilter.toUpperCase())) {
        return false;
      }
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        if (!u.fullName.toLowerCase().contains(q) &&
            !u.email.toLowerCase().contains(q) &&
            !u.projectIds.join(' ').toLowerCase().contains(q) &&
            !u.permissionCodes.join(' ').toLowerCase().contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();

    // Apply sorting
    filtered.sort((a, b) {
      int comparison = 0;
      switch (_sortBy) {
        case 'nombre':
          comparison = a.fullName.compareTo(b.fullName);
          break;
        case 'correo':
          comparison = a.email.compareTo(b.email);
          break;
        case 'rol':
          comparison = a.primaryRole.compareTo(b.primaryRole);
          break;
        case 'estado':
          comparison = a.isActive ? 1 : -1;
          break;
        default:
          comparison = 0;
      }
      return _sortAscending ? comparison : -comparison;
    });

    return filtered;
  }

  Map<String, int> _computeRoleStats(List<_AdminUser> users) {
    final stats = <String, int>{
      'ADMIN': 0,
      'SUPERVISOR': 0,
      'COORD': 0,
      'OPERATIVO': 0,
      'LECTOR': 0,
    };
    for (final user in users) {
      final role = user.primaryRole;
      if (stats.containsKey(role)) {
        stats[role] = stats[role]! + 1;
      }
    }
    return stats;
  }

  Future<void> _openCreateDialog(BuildContext context) async {
    final availablePermissions = _resolveAvailablePermissions(
      ref.read(_adminPermissionsProvider).valueOrNull ?? const <String>[],
    );
    final rolePermissions = _resolveRolePermissions(
      ref.read(_adminRolePermissionsProvider).valueOrNull ??
          const <String, List<String>>{},
    );
    final availableProjects =
        ref.read(availableProjectsProvider).valueOrNull ?? const <String>[];
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _UserFormDialog.create(
        availablePermissions: availablePermissions,
        rolePermissions: rolePermissions,
        availableProjects: availableProjects,
      ),
    );
    if (result == true) {
      ref.invalidate(_adminUsersProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuario creado')),
        );
      }
    }
  }

  Future<void> _openEditDialog(
    BuildContext context,
    _AdminUser user,
    List<String> availablePermissions,
    _RolePermissionsMap rolePermissions,
    List<String> availableProjects,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _UserFormDialog.edit(
        user,
        availablePermissions: availablePermissions,
        rolePermissions: rolePermissions,
        availableProjects: availableProjects,
      ),
    );
    if (result == true) {
      ref.invalidate(_adminUsersProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuario actualizado')),
        );
      }
    }
  }

  Future<void> _openPermissionsDialog(
    BuildContext context,
    _AdminUser user,
    List<String> availablePermissions,
    _RolePermissionsMap rolePermissions,
    List<String> availableProjects,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _UserPermissionsDialog(
        user: user,
        availablePermissions: availablePermissions,
        rolePermissions: rolePermissions,
        availableProjects: availableProjects,
      ),
    );
    if (result == true) {
      ref.invalidate(_adminUsersProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permisos actualizados')),
        );
      }
    }
  }

  Future<void> _toggleStatus(BuildContext context, _AdminUser user) async {
    if (_processingStatusIds.contains(user.id)) return;
    final newStatus = user.isActive ? 'inactive' : 'active';
    final action = user.isActive ? 'desactivar' : 'activar';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿${action.capitalize()} usuario?'),
        content: Text(
          '${user.fullName} (${user.email}) será ${user.isActive ? 'desactivado' : 'activado'}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: user.isActive
                ? FilledButton.styleFrom(backgroundColor: SaoColors.error)
                : null,
            child: Text(action.capitalize()),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;

    setState(() => _processingStatusIds.add(user.id));

    try {
      await const BackendApiClient().patchJson(
        '/api/v1/users/admin/${user.id}',
        {'status': newStatus},
      );
      ref.invalidate(_adminUsersProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Usuario ${newStatus == 'active' ? 'activado' : 'desactivado'}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), backgroundColor: SaoColors.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processingStatusIds.remove(user.id));
      }
    }
  }

  Future<void> _deleteUser(BuildContext context, _AdminUser user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title:
            Text(user.isActive ? '¿Desactivar usuario?' : '¿Eliminar usuario?'),
        content: Text(
          user.isActive
              ? '${user.fullName} (${user.email}) se marcará como inactivo.\n\n'
                  'No se eliminará permanentemente para mantener trazabilidad y auditoría.'
              : '${user.fullName} (${user.email}) se eliminará permanentemente.\n\n'
                  'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: SaoColors.error),
            child: Text(user.isActive ? 'Desactivar' : 'Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;

    setState(() => _processingStatusIds.add(user.id));

    try {
      if (user.isActive) {
        await const BackendApiClient().patchJson(
          '/api/v1/users/admin/${user.id}',
          {'status': 'inactive'},
        );
      } else {
        await const BackendApiClient()
            .deleteJson('/api/v1/users/admin/${user.id}');
      }
      ref.invalidate(_adminUsersProvider);
      if (!user.isActive && mounted && _selectedUserId == user.id) {
        setState(() {
          _selectedUser = null;
          _selectedUserId = null;
        });
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              user.isActive
                  ? 'Usuario desactivado exitosamente'
                  : 'Usuario eliminado exitosamente',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), backgroundColor: SaoColors.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processingStatusIds.remove(user.id));
      }
    }
  }

  Future<_UserActivitySummary> _loadUserActivitySummary(_AdminUser user) {
    return _activitySummaryCache.putIfAbsent(
      user.id,
      () => _fetchUserActivitySummary(user),
    );
  }

  Future<_UserActivitySummary> _fetchUserActivitySummary(
      _AdminUser user) async {
    final userId = user.id.trim().toLowerCase();
    if (userId.isEmpty) return _UserActivitySummary.empty;

    final seenIds = <String>{};
    final assignedIds = <String>{};
    final createdIds = <String>{};
    final collected = <_UserActivityItem>[];
    final stateCounters = <String, int>{};
    final partialErrors = <String>{};

    final projects = <String>{
      ...user.projectIds
          .map((p) => p.trim().toUpperCase())
          .where((p) => p.isNotEmpty),
      ...user.scopes
          .map((s) => (s.projectId ?? '').trim().toUpperCase())
          .where((p) => p.isNotEmpty),
      ...user.permissionScopes
          .map((s) => (s.projectId ?? '').trim().toUpperCase())
          .where((p) => p.isNotEmpty),
    }.toList()
      ..sort();

    Future<void> collectFromActivitiesEndpoint(
      Map<String, String> roleFilter, {
      String? projectId,
      int maxPages = 20,
    }) async {
      var page = 1;
      var hasNext = true;
      while (hasNext && page <= maxPages) {
        final qp = <String>[
          'page=$page',
          'page_size=100',
          if (projectId != null && projectId.isNotEmpty)
            'project_id=${Uri.encodeQueryComponent(projectId)}',
        ];
        roleFilter.forEach((key, value) {
          final normalizedValue = value.trim();
          if (normalizedValue.isEmpty) return;
          qp.add('$key=${Uri.encodeQueryComponent(normalizedValue)}');
        });

        final path = '/api/v1/activities?${qp.join('&')}';
        final decoded = await const BackendApiClient().getJson(path);
        if (decoded is! Map<String, dynamic>) break;

        final rawItems = decoded['items'];
        if (rawItems is! List) break;

        for (final raw in rawItems.whereType<Map<String, dynamic>>()) {
          _collectUserActivityFromRaw(
            raw,
            userId: userId,
            seenIds: seenIds,
            assignedIds: assignedIds,
            createdIds: createdIds,
            stateCounters: stateCounters,
            collected: collected,
          );
        }

        hasNext = decoded['has_next'] == true;
        page++;
      }
    }

    Future<void> collectSafely(Future<void> Function() action) async {
      try {
        await action();
      } catch (e) {
        partialErrors.add(e.toString());
      }
    }

    final roleFilters = <Map<String, String>>[
      {'assigned_to_user_id': user.id},
      {'created_by_user_id': user.id},
    ];

    for (final roleFilter in roleFilters) {
      if (projects.isEmpty) {
        await collectSafely(() => collectFromActivitiesEndpoint(roleFilter));
        continue;
      }
      for (final projectId in projects) {
        await collectSafely(
          () => collectFromActivitiesEndpoint(roleFilter, projectId: projectId),
        );
      }
    }

    final lowerEmail = user.email.trim().toLowerCase();
    final lowerName = user.fullName.trim().toLowerCase();

    // Complement with assignments data because some historical activities rely on
    // effective assignee semantics (assigned_to_user_id can be null in legacy rows).
    if (projects.isNotEmpty) {
      await collectSafely(
        () => _collectUserActivitiesFromAssignments(
          projects: projects,
          userId: userId,
          lowerEmail: lowerEmail,
          lowerName: lowerName,
          seenIds: seenIds,
          assignedIds: assignedIds,
          createdIds: createdIds,
          stateCounters: stateCounters,
          collected: collected,
        ),
      );
    }

    // Fallback for mixed identity sources where IDs don't match exactly.
    if (collected.isEmpty && projects.isNotEmpty) {
      for (final projectId in projects) {
        await collectSafely(() async {
          var page = 1;
          var hasNext = true;
          while (hasNext && page <= 10) {
            final path =
                '/api/v1/activities?page=$page&page_size=100&project_id=${Uri.encodeQueryComponent(projectId)}';
            final decoded = await const BackendApiClient().getJson(path);
            if (decoded is! Map<String, dynamic>) break;

            final rawItems = decoded['items'];
            if (rawItems is! List) break;

            for (final raw in rawItems.whereType<Map<String, dynamic>>()) {
              final assignedName = (raw['assigned_to_user_name'] ?? '')
                  .toString()
                  .trim()
                  .toLowerCase();
              final assignedEmail = (raw['assigned_to_user_email'] ?? '')
                  .toString()
                  .trim()
                  .toLowerCase();
              if (assignedName != lowerName && assignedEmail != lowerEmail) {
                continue;
              }

              _collectUserActivityFromRaw(
                raw,
                userId: userId,
                seenIds: seenIds,
                assignedIds: assignedIds,
                createdIds: createdIds,
                stateCounters: stateCounters,
                collected: collected,
                forceAssigned: true,
              );
            }

            hasNext = decoded['has_next'] == true;
            page++;
          }
        });
      }
    }

    collected.sort((a, b) {
      final ad = a.createdAt;
      final bd = b.createdAt;
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;
      return bd.compareTo(ad);
    });

    return _UserActivitySummary(
      assignedCount: assignedIds.length,
      createdCount: createdIds.length,
      byState: stateCounters,
      recentItems: List<_UserActivityItem>.unmodifiable(collected),
      error: partialErrors.isEmpty ? null : partialErrors.first,
    );
  }

  Future<void> _collectUserActivitiesFromAssignments({
    required List<String> projects,
    required String userId,
    required String lowerEmail,
    required String lowerName,
    required Set<String> seenIds,
    required Set<String> assignedIds,
    required Set<String> createdIds,
    required Map<String, int> stateCounters,
    required List<_UserActivityItem> collected,
  }) async {
    final nowUtc = DateTime.now().toUtc();
    final fromUtc = nowUtc.subtract(const Duration(days: 3650));
    final toUtc = nowUtc.add(const Duration(days: 365));

    for (final projectId in projects) {
      final path =
          '/api/v1/assignments?project_id=${Uri.encodeQueryComponent(projectId)}'
          '&from=${Uri.encodeQueryComponent(fromUtc.toIso8601String())}'
          '&to=${Uri.encodeQueryComponent(toUtc.toIso8601String())}'
          '&include_all=true';

      final decoded = await const BackendApiClient().getJson(path);
      if (decoded is! List) continue;

      for (final raw in decoded.whereType<Map<String, dynamic>>()) {
        final assigneeUserId =
            (raw['assignee_user_id'] ?? '').toString().trim().toLowerCase();
        final assigneeName =
            (raw['assignee_name'] ?? '').toString().trim().toLowerCase();
        final assigneeEmail =
            (raw['assignee_email'] ?? '').toString().trim().toLowerCase();

        final matchesUser = assigneeUserId == userId ||
            (assigneeName.isNotEmpty && assigneeName == lowerName) ||
            (assigneeEmail.isNotEmpty && assigneeEmail == lowerEmail);
        if (!matchesUser) continue;

        _collectUserActivityFromRaw(
          {
            'uuid': raw['id'],
            'title': raw['title'],
            'activity_type_code': raw['activity_id'],
            'project_id': raw['project_id'],
            'execution_state': raw['status'],
            'created_at': raw['start_at'],
            'updated_at': raw['end_at'],
            'assigned_to_user_id': raw['assignee_user_id'],
          },
          userId: userId,
          seenIds: seenIds,
          assignedIds: assignedIds,
          createdIds: createdIds,
          stateCounters: stateCounters,
          collected: collected,
          forceAssigned: true,
        );
      }
    }
  }

  void _collectUserActivityFromRaw(
    Map<String, dynamic> raw, {
    required String userId,
    required Set<String> seenIds,
    required Set<String> assignedIds,
    required Set<String> createdIds,
    required Map<String, int> stateCounters,
    required List<_UserActivityItem> collected,
    bool forceAssigned = false,
  }) {
    final assignedTo =
        (raw['assigned_to_user_id'] ?? '').toString().trim().toLowerCase();
    final createdBy =
        (raw['created_by_user_id'] ?? '').toString().trim().toLowerCase();
    final isAssigned = forceAssigned || assignedTo == userId;
    final isCreated = createdBy == userId;
    if (!isAssigned && !isCreated) return;

    final id = (raw['uuid'] ?? raw['id'] ?? '').toString().trim();
    if (id.isEmpty) return;
    if (isAssigned) assignedIds.add(id);
    if (isCreated) createdIds.add(id);
    if (seenIds.contains(id)) return;
    seenIds.add(id);

    final rawState = (raw['execution_state'] ?? '').toString();
    final state = _normalizeUserActivityState(rawState);
    if (state.isNotEmpty) {
      stateCounters[state] = (stateCounters[state] ?? 0) + 1;
    }

    final createdAtRaw = (raw['created_at'] ?? '').toString().trim();
    final updatedAtRaw = (raw['updated_at'] ?? '').toString().trim();
    final createdAt = DateTime.tryParse(createdAtRaw)?.toLocal();
    final updatedAt = DateTime.tryParse(updatedAtRaw)?.toLocal();
    // Prioritize updated_at so recently reassigned activities stay visible.
    final activityDate = updatedAt ?? createdAt;

    final title = (raw['title'] ?? '').toString().trim();
    final activityType = (raw['activity_type_code'] ?? '').toString().trim();

    collected.add(
      _UserActivityItem(
        id: id,
        title: title.isNotEmpty ? title : activityType,
        activityTypeCode: activityType,
        projectId: (raw['project_id'] ?? '').toString().trim(),
        executionState: state,
        createdAt: activityDate,
        assigned: isAssigned,
        created: isCreated,
      ),
    );
  }

  List<String> _resolvedProjectIdsForView(
    _AdminUser user,
    List<_UserScope> scopes,
  ) {
    final projectSet = <String>{
      ...user.projectIds
          .map((projectId) => projectId.trim().toUpperCase())
          .where((projectId) => projectId.isNotEmpty),
      ...scopes
          .map((scope) => (scope.projectId ?? '').trim().toUpperCase())
          .where((projectId) => projectId.isNotEmpty),
      ...user.permissionScopes
          .map((scope) => (scope.projectId ?? '').trim().toUpperCase())
          .where((projectId) => projectId.isNotEmpty),
    };
    final result = projectSet.toList()..sort();
    return result;
  }

  List<String> _resolvedPermissionLabelsForView(
    _AdminUser user,
    _RolePermissionsMap rolePermissions,
  ) {
    final labels = <String>{};

    for (final role in user.roles.map((role) => role.trim().toUpperCase())) {
      if (role.isEmpty) continue;
      final rolePermissionCodes = rolePermissions[role] ?? const <String>[];
      labels.addAll(
        rolePermissionCodes
            .map((code) => code.trim())
            .where((code) => code.isNotEmpty),
      );
    }

    labels.addAll(
      user.permissionCodes
          .map((code) => code.trim())
          .where((code) => code.isNotEmpty),
    );

    for (final scope in user.permissionScopes) {
      final code = scope.permissionCode.trim();
      if (code.isEmpty) continue;
      final effect = scope.effect.trim().toLowerCase();
      if (effect == 'deny') continue;
      final projectId = (scope.projectId ?? '').trim().toUpperCase();
      if (projectId.isEmpty) {
        labels.add(code);
      } else {
        labels.add('$code · $projectId');
      }
    }

    final result = labels.toList()..sort();
    return result;
  }

  List<_UserActivityItem> _applyActivityFilters(_UserActivitySummary summary) {
    final hasRangeLimit = _activityRangeDays > 0;
    final cutoff = hasRangeLimit
        ? DateTime.now().subtract(Duration(days: _activityRangeDays))
        : null;

    return summary.recentItems.where((item) {
      if (_activityViewFilter == 'Asignadas' && !item.assigned) return false;
      if (_activityViewFilter == 'Creadas' && !item.created) return false;
      if (!hasRangeLimit) return true;
      final createdAt = item.createdAt;
      if (createdAt == null) return false;
      return !createdAt.isBefore(cutoff!);
    }).toList();
  }

  String _normalizeUserActivityState(String rawState) {
    final normalized = rawState.trim().toUpperCase();
    return switch (normalized) {
      // Operativo ya termino captura/ejecucion; para vista de usuarios
      // se presenta como completada aunque siga pendiente de revision.
      'REVISION_PENDIENTE' => 'COMPLETADA',
      // Homologa estado tecnico con etiqueta mostrada en UI.
      'EN_CURSO' => 'EN_PROGRESO',
      _ => normalized,
    };
  }

  String _activityEmptyMessage(_UserActivitySummary summary) {
    if (summary.totalCount == 0) {
      return 'Sin actividades relacionadas con este usuario.';
    }
    return 'No hay actividades para los filtros seleccionados.';
  }

  String _formatExecutionStateLabel(String state) {
    final normalized = state.trim();
    if (normalized.isEmpty) return 'Sin estado';
    final words = normalized.toLowerCase().replaceAll('_', ' ').split(' ');
    return words
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  String _formatActivityDate(DateTime? dt) {
    if (dt == null) return '—';
    return DateFormat('dd/MM/yyyy HH:mm').format(dt);
  }

  String _extractTaggedValue(String source, String label) {
    final match = RegExp('$label\\s*:\\s*([^·|,;]+)', caseSensitive: false)
        .firstMatch(source);
    if (match == null) return '';
    return (match.group(1) ?? '').trim();
  }

  String _formatActivityTypeLabel(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return '';
    switch (normalized.toUpperCase()) {
      case 'REU':
        return 'Reunion';
    }
    return normalized
        .toLowerCase()
        .split(RegExp(r'[_\-\s]+'))
        .where((token) => token.isNotEmpty)
        .map((token) => '${token[0].toUpperCase()}${token.substring(1)}')
        .join(' ');
  }

  bool _looksLikeActivityCode(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return false;
    if (normalized.contains(' ')) return false;
    return RegExp(r'^[A-Za-z_]{2,10}$').hasMatch(normalized);
  }

  bool _looksLikeLocationDecoratedTitle(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('frente:') ||
        lower.contains('estado:') ||
        lower.contains('municipio:') ||
        lower.contains('lugar:')) {
      return true;
    }
    return RegExp(r'\bpk\s*\d+\+\d+', caseSensitive: false).hasMatch(title);
  }

  String _activityDisplayTitle(_UserActivityItem item) {
    final taggedActivity = _extractTaggedValue(item.title, 'Actividad');
    if (taggedActivity.isNotEmpty) {
      final mapped = _formatActivityTypeLabel(taggedActivity);
      return mapped.isNotEmpty ? mapped : taggedActivity;
    }

    final rawTitle = item.title.trim();
    final typeLabel = _formatActivityTypeLabel(item.activityTypeCode);

    if (rawTitle.isEmpty) {
      return typeLabel.isNotEmpty ? typeLabel : 'Actividad';
    }

    if (_looksLikeLocationDecoratedTitle(rawTitle)) {
      return typeLabel.isNotEmpty ? typeLabel : 'Actividad';
    }

    if (_looksLikeActivityCode(rawTitle) && typeLabel.isNotEmpty) {
      return typeLabel;
    }

    return rawTitle;
  }

  String _activityLocationLine(_UserActivityItem item) {
    final rawTitle = item.title.trim();
    if (rawTitle.isEmpty) return '';

    final front = _extractTaggedValue(rawTitle, 'Frente');
    final estado = _extractTaggedValue(rawTitle, 'Estado');
    final municipio = _extractTaggedValue(rawTitle, 'Municipio');
    final parts = <String>[];
    if (front.isNotEmpty && !front.toLowerCase().startsWith('sin ')) {
      parts.add(front);
    }
    if (estado.isNotEmpty && !estado.toLowerCase().startsWith('sin ')) {
      parts.add(estado);
    }
    if (municipio.isNotEmpty && !municipio.toLowerCase().startsWith('sin ')) {
      parts.add(municipio);
    }
    return parts.join(' · ');
  }

  Future<void> _scrollToDetailSection(GlobalKey key) async {
    final targetContext = key.currentContext;
    if (targetContext == null) return;
    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      alignment: 0.12,
    );
  }

  void _showActivityQuickDetail(
    BuildContext context,
    _UserActivityItem item, {
    VoidCallback? onOpenActivity,
  }) {
    final shortId = item.id.length <= 8 ? item.id : item.id.substring(0, 8);
    final displayTitle = _activityDisplayTitle(item);
    final locationLine = _activityLocationLine(item);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(displayTitle),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'ID',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: SaoColors.gray500,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      shortId,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: SaoColors.gray900,
                      ),
                    ),
                  ),
                  Tooltip(
                    message: 'Copiar ID completo',
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.content_copy_rounded, size: 16),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: item.id));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('ID copiado al portapapeles'),
                            duration: Duration(milliseconds: 1200),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (locationLine.isNotEmpty) ...[
                Text(
                  locationLine,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: SaoColors.gray800,
                  ),
                ),
                const SizedBox(height: 12),
              ] else
                const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  _quickDetailCell('Proyecto',
                      item.projectId.isEmpty ? 'N/A' : item.projectId),
                  _quickDetailCellWidget('Estado',
                      _ExecutionStateBadge(state: item.executionState)),
                  _quickDetailCell(
                    'Rol en actividad',
                    item.assigned && item.created
                        ? 'Asignada y creada por este usuario'
                        : item.assigned
                            ? 'Asignada a este usuario'
                            : 'Creada por este usuario',
                  ),
                  _quickDetailCell(
                      'Fecha', _formatActivityDate(item.createdAt)),
                ],
              ),
            ],
          ),
        ),
        actions: [
          if (onOpenActivity != null)
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                onOpenActivity();
              },
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('Ir a la actividad'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _showUserActivitiesDialog(
    BuildContext context,
    _AdminUser user,
    _UserActivitySummary summary,
  ) {
    final filtered = _applyActivityFilters(summary);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Actividades de ${user.fullName}'),
        content: SizedBox(
          width: 560,
          height: 420,
          child: filtered.isEmpty
              ? Text(_activityEmptyMessage(summary))
              : Scrollbar(
                  child: ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 16),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      final dateText = _formatActivityDate(item.createdAt);
                      return InkWell(
                        onTap: () => _showActivityQuickDetail(
                          context,
                          item,
                          onOpenActivity: () =>
                              _showUserActivitiesDialog(context, user, summary),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _activityDisplayTitle(item),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: SaoColors.gray900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '[${item.projectId.isEmpty ? 'N/A' : item.projectId}] '
                                '${_formatExecutionStateLabel(item.executionState)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: SaoColors.gray700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                dateText,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: SaoColors.gray600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _showPermissionsSummaryDialog(
    BuildContext context,
    List<String> permissions,
  ) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permisos asignados'),
        content: SizedBox(
          width: 460,
          child: permissions.isEmpty
              ? const Text('No hay permisos asignados.')
              : SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: permissions
                        .map(
                          (permission) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: SaoColors.gray100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: SaoColors.gray300),
                            ),
                            child: Text(
                              permission,
                              style: const TextStyle(
                                fontSize: 12,
                                color: SaoColors.gray700,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsPanel(
    _AdminUser user,
    List<String> availablePermissions,
    _RolePermissionsMap rolePermissions,
    List<String> availableProjects,
  ) {
    final resolvedScopes = _resolvedScopesForView(user);
    final resolvedProjectIds = _resolvedProjectIdsForView(user, resolvedScopes);
    final resolvedPermissionLabels =
        _resolvedPermissionLabelsForView(user, rolePermissions);
    // Build initials avatar color from name hash
    final avatarColor =
        user.isActive ? _avatarColor(user.fullName) : SaoColors.gray400;
    final initials = _initials(user.fullName);
    final effectivePerms = resolvedPermissionLabels.length;

    return SingleChildScrollView(
      controller: _detailPanelScrollCtrl,
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: avatar + name + email + status ──────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            color: SaoColors.gray50,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: avatarColor,
                  child: Text(
                    initials,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: SaoColors.gray900,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user.email,
                        style: const TextStyle(
                          fontSize: 12,
                          color: SaoColors.gray600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      _StatusBadge(isActive: user.isActive),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Action bar ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: SaoColors.gray50,
              border: Border(
                bottom: BorderSide(color: SaoColors.gray200),
              ),
            ),
            child: Row(
              children: [
                _ActionIconBtn(
                  icon: Icons.edit_rounded,
                  label: 'Editar',
                  onPressed: () => _openEditDialog(
                    context,
                    user,
                    availablePermissions,
                    rolePermissions,
                    availableProjects,
                  ),
                ),
                const SizedBox(width: 8),
                Container(width: 1, height: 24, color: SaoColors.gray300),
                const SizedBox(width: 8),
                _ActionIconBtn(
                  icon: Icons.security_rounded,
                  label: 'Permisos',
                  onPressed: () => _openPermissionsDialog(
                    context,
                    user,
                    availablePermissions,
                    rolePermissions,
                    availableProjects,
                  ),
                ),
                const SizedBox(width: 8),
                Container(width: 1, height: 24, color: SaoColors.gray300),
                const SizedBox(width: 8),
                _ActionIconBtn(
                  icon: user.isActive
                      ? Icons.person_off_rounded
                      : Icons.person_rounded,
                  label: user.isActive ? 'Desactivar' : 'Activar',
                  color: user.isActive ? SaoColors.warning : SaoColors.success,
                  emphasized: true,
                  onPressed: () => _toggleStatus(context, user),
                ),
                const Spacer(),
                Container(width: 1, height: 24, color: SaoColors.gray300),
                const SizedBox(width: 8),
                _ActionIconBtn(
                  icon: Icons.delete_rounded,
                  label: user.isActive ? 'Desactivar' : 'Eliminar',
                  color: SaoColors.error,
                  onPressed: () => _deleteUser(context, user),
                ),
              ],
            ),
          ),

          // ── Información general ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Información general',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: SaoColors.gray800,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: SaoColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: SaoColors.gray200),
                  ),
                  child: Column(
                    children: [
                      _InfoRow(
                        label: 'Rol',
                        child: user.roles.isEmpty
                            ? const Text('—',
                                style: TextStyle(
                                    fontSize: 13, color: SaoColors.gray500))
                            : Wrap(
                                spacing: 5,
                                runSpacing: 4,
                                children: user.roles
                                    .map((r) => _RoleBadge(role: r))
                                    .toList(),
                              ),
                      ),
                      const SizedBox(height: 10),
                      _InfoRow(
                        label: 'Proyecto',
                        key: _projectsSectionKey,
                        child: resolvedProjectIds.isEmpty
                            ? const Text('—',
                                style: TextStyle(
                                    fontSize: 13, color: SaoColors.gray500))
                            : Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: resolvedProjectIds
                                    .map(
                                      (p) => Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: SaoColors.gray100,
                                          borderRadius:
                                              BorderRadius.circular(999),
                                          border: Border.all(
                                              color: SaoColors.gray300),
                                        ),
                                        child: Text(
                                          p,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: SaoColors.gray700,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                      ),
                      const SizedBox(height: 10),
                      _InfoRow(
                        label: 'Permisos',
                        key: _permissionsSectionKey,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '$effectivePerms permisos asignados',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: SaoColors.gray700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () => _showPermissionsSummaryDialog(
                                  context, resolvedPermissionLabels),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('Ver detalle'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Ámbitos
                if (resolvedScopes.isNotEmpty) ...[
                  _InfoRow(
                    label: 'Ámbitos',
                    child: Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      children: resolvedScopes
                          .map(
                            (s) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: SaoColors.gray100,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: SaoColors.gray300),
                              ),
                              child: Text(
                                s.projectId == null
                                    ? '${s.role} · Global'
                                    : '${s.role} · ${s.projectId}',
                                style: const TextStyle(
                                    fontSize: 11, color: SaoColors.gray700),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                const SizedBox(height: 20),
                const Divider(height: 1),
                const SizedBox(height: 16),

                // ── Actividades ────────────────────────────────────
                Row(
                  children: [
                    const Text(
                      'Actividades',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: SaoColors.gray800,
                      ),
                    ),
                    const Spacer(),
                    FutureBuilder<_UserActivitySummary>(
                      future: _loadUserActivitySummary(user),
                      builder: (context, snapshot) {
                        final summary = snapshot.data;
                        final lastActivity =
                            summary == null || summary.recentItems.isEmpty
                                ? null
                                : summary.recentItems.first.createdAt;
                        if (lastActivity == null)
                          return const SizedBox.shrink();
                        return Text(
                          'Última: ${DateFormat('dd/MM HH:mm').format(lastActivity)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: SaoColors.gray500,
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Actualizar actividades',
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        setState(() => _activitySummaryCache.remove(user.id));
                      },
                      icon: const Icon(
                        Icons.refresh_rounded,
                        size: 18,
                        color: SaoColors.gray500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () async {
                        final summary = await _loadUserActivitySummary(user);
                        if (!context.mounted) return;
                        _showUserActivitiesDialog(context, user, summary);
                      },
                      icon: const Icon(Icons.open_in_new_rounded, size: 14),
                      label: const Text(
                        'Ver todas',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                FutureBuilder<_UserActivitySummary>(
                  future: _loadUserActivitySummary(user),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Cargando actividades…',
                              style: TextStyle(
                                  fontSize: 12, color: SaoColors.gray500),
                            ),
                          ],
                        ),
                      );
                    }

                    final summary = snapshot.data;
                    if (summary == null) {
                      return const Text(
                        'No se pudo cargar el historial.',
                        style:
                            TextStyle(fontSize: 13, color: SaoColors.gray500),
                      );
                    }

                    final filteredItems = _applyActivityFilters(summary);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: SaoColors.gray100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: SaoColors.gray200),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _ActivityFilterDropdown(
                                  label: 'Tipo',
                                  value: _activityViewFilter,
                                  items: const [
                                    ('Todas', 'Todas'),
                                    ('Asignadas', 'Asignadas'),
                                    ('Creadas', 'Creadas'),
                                  ],
                                  onChanged: (v) {
                                    if (v == null) return;
                                    setState(() => _activityViewFilter = v);
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _ActivityFilterDropdown(
                                  label: 'Periodo',
                                  value: _activityRangeDays.toString(),
                                  items: const [
                                    ('0', 'Todo el historial'),
                                    ('7', 'Últimos 7 días'),
                                    ('30', 'Últimos 30 días'),
                                    ('90', 'Últimos 90 días'),
                                    ('365', 'Últimos 12 meses'),
                                  ],
                                  onChanged: (v) {
                                    if (v == null) return;
                                    setState(() =>
                                        _activityRangeDays = int.parse(v));
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Estado breakdown (mini)
                        if (summary.byState.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: summary.byState.entries
                                .map(
                                  (e) => _StateCountBadge(
                                    state: e.key,
                                    count: e.value,
                                    labelBuilder: _formatExecutionStateLabel,
                                  ),
                                )
                                .toList(),
                          ),
                        ],

                        const SizedBox(height: 10),

                        // Activity list
                        if (filteredItems.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                vertical: 18, horizontal: 12),
                            decoration: BoxDecoration(
                              color: SaoColors.gray50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: SaoColors.gray200),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.find_in_page_outlined,
                                  size: 26,
                                  color: SaoColors.gray400,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _activityEmptyMessage(summary),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: SaoColors.gray500,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ...filteredItems.take(6).map(
                                (item) => InkWell(
                                  borderRadius: BorderRadius.circular(6),
                                  onTap: () => _showActivityQuickDetail(
                                    context,
                                    item,
                                    onOpenActivity: () =>
                                        _showUserActivitiesDialog(
                                            context, user, summary),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 7, horizontal: 2),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 4,
                                          height: 32,
                                          margin: const EdgeInsets.only(
                                              right: 10, top: 2),
                                          decoration: BoxDecoration(
                                            color: _stateColor(
                                                item.executionState),
                                            borderRadius:
                                                BorderRadius.circular(2),
                                          ),
                                        ),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _activityDisplayTitle(item),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: SaoColors.gray800,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Row(
                                                children: [
                                                  Text(
                                                    item.projectId.isEmpty
                                                        ? 'N/A'
                                                        : item.projectId,
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      color: SaoColors.gray600,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  _ExecutionStateBadge(
                                                      state:
                                                          item.executionState),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                _formatActivityDate(
                                                    item.createdAt),
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: SaoColors.gray500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(
                                          Icons.chevron_right_rounded,
                                          size: 16,
                                          color: SaoColors.gray400,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                        if (summary.error != null) ...[
                          const SizedBox(height: 6),
                          const Text(
                            '⚠ Historial parcial — no se pudo obtener todo.',
                            style: TextStyle(
                                fontSize: 11, color: SaoColors.warning),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _avatarColor(String name) {
    final colors = [
      const Color(0xFF5C6BC0),
      const Color(0xFF26A69A),
      const Color(0xFFEF5350),
      const Color(0xFFAB47BC),
      const Color(0xFF42A5F5),
      const Color(0xFFFF7043),
      const Color(0xFF66BB6A),
      const Color(0xFF8D6E63),
    ];
    int hash = 0;
    for (final ch in name.runes) {
      hash = (hash * 31 + ch) & 0xFFFFFFFF;
    }
    return colors[hash % colors.length];
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }

  List<_UserScope> _resolvedScopesForView(_AdminUser user) {
    final normalizedScopes = user.scopes
        .map(
          (scope) => _UserScope(
            role: scope.role.trim().toUpperCase(),
            projectId: (scope.projectId ?? '').trim().toUpperCase().isEmpty
                ? null
                : (scope.projectId ?? '').trim().toUpperCase(),
          ),
        )
        .where((scope) => scope.role.isNotEmpty)
        .toList();
    if (normalizedScopes.isNotEmpty) {
      return _dedupeScopes(normalizedScopes);
    }

    final roles = user.roles
        .map((role) => role.trim().toUpperCase())
        .where((role) => role.isNotEmpty)
        .toList();
    final projects = user.projectIds
        .map((projectId) => projectId.trim().toUpperCase())
        .where((projectId) => projectId.isNotEmpty)
        .toList();
    if (roles.isEmpty) return const <_UserScope>[];

    final generated = <_UserScope>[];
    if (projects.isEmpty) {
      for (final role in roles) {
        generated.add(_UserScope(role: role, projectId: null));
      }
      return _dedupeScopes(generated);
    }

    if (roles.length == 1) {
      for (final projectId in projects) {
        generated.add(_UserScope(role: roles.first, projectId: projectId));
      }
      return _dedupeScopes(generated);
    }

    final limit =
        roles.length < projects.length ? roles.length : projects.length;
    for (var i = 0; i < limit; i++) {
      generated.add(_UserScope(role: roles[i], projectId: projects[i]));
    }
    return _dedupeScopes(generated);
  }

  List<_UserScope> _dedupeScopes(List<_UserScope> scopes) {
    final seen = <String>{};
    final result = <_UserScope>[];
    for (final scope in scopes) {
      final role = scope.role.trim().toUpperCase();
      final project = (scope.projectId ?? '').trim().toUpperCase();
      final key = '$role|$project';
      if (role.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      result.add(
        _UserScope(
          role: role,
          projectId: project.isEmpty ? null : project,
        ),
      );
    }
    return result;
  }

  Color _stateColor(String state) {
    switch (state.toUpperCase()) {
      case 'COMPLETADA':
      case 'APROBADA':
        return SaoColors.success;
      case 'EN_CURSO':
      case 'EN_PROGRESO':
      case 'EN_REVISION':
        return SaoColors.warning;
      case 'RECHAZADA':
      case 'CANCELADA':
        return SaoColors.error;
      default:
        return SaoColors.gray400;
    }
  }

  Widget _quickDetailCell(String label, String value) {
    return SizedBox(
      width: 245,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: SaoColors.gray500,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value.isEmpty ? '—' : value,
            style: const TextStyle(
              fontSize: 12,
              color: SaoColors.gray900,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickDetailCellWidget(String label, Widget child) {
    return SizedBox(
      width: 245,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: SaoColors.gray500,
            ),
          ),
          const SizedBox(height: 3),
          child,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Detail panel helper widgets
// ---------------------------------------------------------------------------

class _ActionIconBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final bool emphasized;

  const _ActionIconBtn({
    required this.icon,
    required this.label,
    this.onPressed,
    this.color,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = color ?? SaoColors.gray700;
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: emphasized ? fg.withValues(alpha: 0.14) : SaoColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color:
                  emphasized ? fg.withValues(alpha: 0.45) : SaoColors.gray300,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                    fontSize: 10, color: fg, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final Widget child;

  const _InfoRow({super.key, required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 78,
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: SaoColors.gray500,
              ),
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  const _StatPill({
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color.withValues(alpha: 0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _CountBadge(
      {required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$count ',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            TextSpan(
              text: label,
              style: TextStyle(
                fontSize: 11,
                color: color.withValues(alpha: 0.75),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityFilterDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<(String, String)> items;
  final ValueChanged<String?> onChanged;

  const _ActivityFilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: SaoColors.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: SaoColors.gray300),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            value: value,
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
            style: const TextStyle(fontSize: 12, color: SaoColors.gray800),
            onChanged: onChanged,
            items: items
                .map(
                  (item) => DropdownMenuItem<String>(
                    value: item.$1,
                    child: Text('${label}: ${item.$2}'),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

class _ExecutionStateBadge extends StatelessWidget {
  final String state;

  const _ExecutionStateBadge({required this.state});

  @override
  Widget build(BuildContext context) {
    final normalized = state.trim().toUpperCase();
    final baseColor = switch (normalized) {
      'COMPLETADA' || 'APROBADA' => SaoColors.success,
      'EN_CURSO' ||
      'EN_PROGRESO' ||
      'EN_REVISION' ||
      'REVISION_PENDIENTE' =>
        SaoColors.warning,
      'RECHAZADA' || 'CANCELADA' => SaoColors.error,
      _ => SaoColors.gray500,
    };
    final words = normalized.isEmpty
        ? 'SIN ESTADO'
        : normalized.toLowerCase().replaceAll('_', ' ');
    final label = words
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: baseColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: baseColor,
        ),
      ),
    );
  }
}

class _StateCountBadge extends StatelessWidget {
  final String state;
  final int count;
  final String Function(String) labelBuilder;

  const _StateCountBadge({
    required this.state,
    required this.count,
    required this.labelBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final normalized = state.toUpperCase();
    final color = switch (normalized) {
      'COMPLETADA' || 'APROBADA' => SaoColors.success,
      'EN_CURSO' ||
      'EN_PROGRESO' ||
      'EN_REVISION' ||
      'REVISION_PENDIENTE' =>
        const Color(0xFFB45309),
      'RECHAZADA' || 'CANCELADA' => SaoColors.error,
      _ => SaoColors.gray500,
    };
    final backgroundColor = switch (normalized) {
      'EN_CURSO' ||
      'EN_PROGRESO' ||
      'EN_REVISION' ||
      'REVISION_PENDIENTE' =>
        const Color(0xFFFDE68A),
      _ => color.withValues(alpha: 0.1),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        '${labelBuilder(state)}: $count',
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Table widget
// ---------------------------------------------------------------------------

class _UsersTable extends StatelessWidget {
  final List<_AdminUser> users;
  final Set<String> processingStatusIds;
  final String sortBy;
  final bool sortAscending;
  final String? selectedUserId;
  final void Function(String) onSort;
  final void Function(_AdminUser) onSelectUser;
  final void Function(_AdminUser) onEdit;
  final void Function(_AdminUser) onManagePermissions;
  final void Function(_AdminUser) onToggleStatus;
  final void Function(_AdminUser) onDelete;

  const _UsersTable({
    required this.users,
    required this.processingStatusIds,
    required this.sortBy,
    required this.sortAscending,
    this.selectedUserId,
    required this.onSort,
    required this.onSelectUser,
    required this.onEdit,
    required this.onManagePermissions,
    required this.onToggleStatus,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 56, color: SaoColors.gray400),
            SizedBox(height: 12),
            Text('No se encontraron usuarios',
                style: TextStyle(color: SaoColors.gray500)),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth =
            constraints.maxWidth < 920 ? 920.0 : constraints.maxWidth;
        final nameWidth = tableWidth * 0.24;
        final emailWidth = tableWidth * 0.28;
        final roleWidth = tableWidth * 0.14;
        final projectWidth = tableWidth * 0.12;
        final statusWidth = tableWidth * 0.13;
        final actionsWidth = tableWidth * 0.09;

        return Container(
          decoration: BoxDecoration(
            color: SaoColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: SaoColors.gray200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: tableWidth,
                child: DataTable(
                  horizontalMargin: 18,
                  columnSpacing: 18,
                  dataRowMinHeight: 58,
                  dataRowMaxHeight: 62,
                  headingRowHeight: 50,
                  headingRowColor:
                      WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                  columns: [
                    _sortableColumn('Nombre', 'nombre', width: nameWidth),
                    _sortableColumn('Correo', 'correo', width: emailWidth),
                    _sortableColumn('Rol', 'rol', width: roleWidth),
                    DataColumn(
                        label: SizedBox(
                            width: projectWidth,
                            child: const Text('Proyecto'))),
                    _sortableColumn('Estado', 'estado', width: statusWidth),
                    DataColumn(
                      label: SizedBox(
                        width: actionsWidth,
                        child: const Align(
                          alignment: Alignment.centerRight,
                          child: Text('Acciones'),
                        ),
                      ),
                      numeric: true,
                    ),
                  ],
                  rows: users
                      .map((u) => _buildRow(
                            u,
                            nameWidth: nameWidth,
                            emailWidth: emailWidth,
                            roleWidth: roleWidth,
                            projectWidth: projectWidth,
                            statusWidth: statusWidth,
                            actionsWidth: actionsWidth,
                          ))
                      .toList(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  DataColumn _sortableColumn(String label, String column,
      {required double width}) {
    final isActive = sortBy == column;
    final arrow = !isActive ? '' : (sortAscending ? ' ↑' : ' ↓');
    return DataColumn(
      label: SizedBox(
        width: width,
        child: GestureDetector(
          onTap: () => onSort(column),
          child: Tooltip(
            message: 'Ordenar por $label',
            child: Text(
              '$label$arrow',
              style: TextStyle(
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                color: isActive ? SaoColors.primary : null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  DataRow _buildRow(
    _AdminUser u, {
    required double nameWidth,
    required double emailWidth,
    required double roleWidth,
    required double projectWidth,
    required double statusWidth,
    required double actionsWidth,
  }) {
    final isProcessing = processingStatusIds.contains(u.id);
    final onTapRow = isProcessing ? null : () => onSelectUser(u);
    final isSelected = selectedUserId == u.id;

    return DataRow(
      color: WidgetStateProperty.resolveWith<Color?>((states) {
        if (isSelected) {
          return const Color(0xFFEFF6FF);
        }
        if (states.contains(WidgetState.hovered)) {
          return const Color(0xFFF8FAFC);
        }
        return null;
      }),
      cells: [
        DataCell(
          _clickableCell(
            SizedBox(
              width: nameWidth,
              child: Text(
                u.fullName,
                style: const TextStyle(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            onTapRow != null,
          ),
          onTap: onTapRow,
        ),
        DataCell(
          _clickableCell(
            SizedBox(
              width: emailWidth,
              child: Text(
                u.email,
                style: const TextStyle(fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            onTapRow != null,
          ),
          onTap: onTapRow,
        ),
        DataCell(
          _clickableCell(
            SizedBox(
              width: roleWidth,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _RoleBadge(
                    role: u.primaryRole.isEmpty ? '—' : u.primaryRole),
              ),
            ),
            onTapRow != null,
          ),
          onTap: onTapRow,
        ),
        DataCell(
          _clickableCell(
            SizedBox(
              width: projectWidth,
              child: Tooltip(
                message: u.projectIds.join(', '),
                child: Text(
                  u.projectIds.isEmpty ? '—' : u.projectIds.join(', '),
                  style: const TextStyle(fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            onTapRow != null,
          ),
          onTap: onTapRow,
        ),
        DataCell(
          _clickableCell(
            SizedBox(
              width: statusWidth,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _StatusBadge(isActive: u.isActive),
              ),
            ),
            onTapRow != null,
          ),
          onTap: onTapRow,
        ),
        DataCell(
          SizedBox(
            width: actionsWidth,
            child: Align(
              alignment: Alignment.centerRight,
              child: isProcessing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: Padding(
                        padding: EdgeInsets.all(4),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_horiz_rounded,
                        size: 18,
                        color:
                            isSelected ? SaoColors.primary : SaoColors.gray600,
                      ),
                      tooltip: 'Acciones',
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      onSelected: (action) {
                        switch (action) {
                          case 'editar':
                            onEdit(u);
                            break;
                          case 'permisos':
                            onManagePermissions(u);
                            break;
                          case 'togglEstatus':
                            onToggleStatus(u);
                            break;
                          case 'eliminar':
                            onDelete(u);
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'editar',
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.edit_rounded, size: 16),
                              SizedBox(width: 8),
                              Text('Editar'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'permisos',
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.security_rounded, size: 16),
                              SizedBox(width: 8),
                              Text('Permisos'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'togglEstatus',
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                u.isActive
                                    ? Icons.person_off_rounded
                                    : Icons.person_rounded,
                                size: 16,
                                color: u.isActive
                                    ? SaoColors.error
                                    : SaoColors.success,
                              ),
                              const SizedBox(width: 8),
                              Text(u.isActive ? 'Desactivar' : 'Activar'),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        PopupMenuItem(
                          value: 'eliminar',
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.delete_rounded,
                                  size: 16, color: SaoColors.error),
                              SizedBox(width: 8),
                              Text(
                                u.isActive ? 'Desactivar' : 'Eliminar',
                                style: const TextStyle(color: SaoColors.error),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _clickableCell(Widget child, bool enabled) {
    if (!enabled) return child;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// Create / Edit dialog
// ---------------------------------------------------------------------------

class _UserFormDialog extends StatefulWidget {
  final _AdminUser? user; // null = create mode
  final List<String> availablePermissions;
  final _RolePermissionsMap rolePermissions;
  final List<String> availableProjects;

  const _UserFormDialog.create({
    required this.availablePermissions,
    required this.rolePermissions,
    required this.availableProjects,
  }) : user = null;
  const _UserFormDialog.edit(
    this.user, {
    required this.availablePermissions,
    required this.rolePermissions,
    required this.availableProjects,
  });

  @override
  State<_UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<_UserFormDialog> {
  static const _birthDateLocale = Locale('es', 'MX');
  static const _roles = ['ADMIN', 'SUPERVISOR', 'COORD', 'OPERATIVO', 'LECTOR'];
  static const _statuses = ['active', 'inactive'];

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _secondLastNameCtrl = TextEditingController();
  final _birthDateCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _scopesScrollCtrl = ScrollController();

  DateTime? _birthDate;
  List<_ScopeDraft> _scopes = <_ScopeDraft>[
    _ScopeDraft(role: 'OPERATIVO', projectId: ''),
  ];
  String _status = 'active';
  bool _submitting = false;
  String? _error;
  String? _emailDomainSuggestion;
  bool _obscurePassword = true;

  bool get _isEdit => widget.user != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final u = widget.user!;
      _nameCtrl.text = u.fullName;
      _emailCtrl.text = u.email;
      _scopes = _buildInitialScopesForEdit(u);
      _status = u.isActive ? 'active' : 'inactive';
    }
    _emailDomainSuggestion = _computeEmailSuggestion(_emailCtrl.text);
  }

  List<_ScopeDraft> _buildInitialScopesForEdit(_AdminUser user) {
    final result = <_ScopeDraft>[];

    void addScope(String role, String? projectId) {
      final normalizedRole = role.trim().toUpperCase();
      final normalizedProject = (projectId ?? '').trim().toUpperCase();
      if (normalizedRole.isEmpty) return;
      final exists = result.any((scope) {
        return scope.role.trim().toUpperCase() == normalizedRole &&
            scope.projectId.trim().toUpperCase() == normalizedProject;
      });
      if (exists) return;
      result.add(
        _ScopeDraft(
          role: normalizedRole,
          projectId: normalizedProject,
        ),
      );
    }

    for (final scope in user.scopes) {
      addScope(scope.role, scope.projectId);
    }

    final roles = user.roles
        .map((role) => role.trim().toUpperCase())
        .where((role) => role.isNotEmpty)
        .toSet();
    if (roles.isEmpty) {
      roles.add(user.primaryRole.isNotEmpty
          ? user.primaryRole.trim().toUpperCase()
          : 'OPERATIVO');
    }

    final projects = <String>{
      ...user.projectIds
          .map((projectId) => projectId.trim().toUpperCase())
          .where((projectId) => projectId.isNotEmpty),
      ...user.scopes
          .map((scope) => (scope.projectId ?? '').trim().toUpperCase())
          .where((projectId) => projectId.isNotEmpty),
      ...user.permissionScopes
          .map((scope) => (scope.projectId ?? '').trim().toUpperCase())
          .where((projectId) => projectId.isNotEmpty),
    };

    if (projects.isEmpty) {
      for (final role in roles) {
        addScope(role, null);
      }
    } else {
      for (final role in roles) {
        for (final projectId in projects) {
          addScope(role, projectId);
        }
      }
    }

    if (result.isEmpty) {
      result.add(_ScopeDraft(role: 'OPERATIVO', projectId: ''));
    }
    return result;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _secondLastNameCtrl.dispose();
    _birthDateCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _scopesScrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final initialDate =
        _birthDate ?? DateTime(now.year - 18, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      locale: _birthDateLocale,
      initialDate: initialDate,
      firstDate: DateTime(1900, 1, 1),
      lastDate: now,
      helpText: 'Selecciona la fecha de cumpleaños',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
      fieldHintText: 'dd/mm/aaaa',
    );
    if (picked == null) return;
    setState(() {
      _birthDate = picked;
      _birthDateCtrl.text = DateFormat('dd/MM/yyyy', 'es_MX').format(picked);
    });
  }

  String? _computeEmailSuggestion(String rawValue) {
    final email = rawValue.trim();
    if (email.isEmpty || !email.contains('@')) return null;

    final parts = email.split('@');
    if (parts.length != 2) return null;
    final local = parts.first;
    final domain = parts.last;
    if (local.isEmpty || domain.isEmpty) return null;

    if (domain.toLowerCase().endsWith('.co')) {
      final suggested = '$local@${domain}m';
      if (suggested.toLowerCase() != email.toLowerCase()) return suggested;
    }
    return null;
  }

  void _updateEmailSuggestion(String value) {
    if (_isEdit) return;
    final nextSuggestion = _computeEmailSuggestion(value);
    if (nextSuggestion == _emailDomainSuggestion) return;
    setState(() {
      _emailDomainSuggestion = nextSuggestion;
    });
  }

  void _applyEmailSuggestion() {
    final suggestion = _emailDomainSuggestion;
    if (suggestion == null) return;
    _emailCtrl.value = TextEditingValue(
      text: suggestion,
      selection: TextSelection.collapsed(offset: suggestion.length),
    );
    setState(() {
      _emailDomainSuggestion = null;
    });
  }

  String _normalizePersonName(String raw) {
    final compact = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (compact.isEmpty) return '';
    final lowered = compact.toLowerCase();
    return lowered.replaceAllMapped(
      RegExp(r"[a-zA-ZáéíóúüñÁÉÍÓÚÜÑ]+"),
      (match) {
        final word = match.group(0)!;
        return word[0].toUpperCase() + word.substring(1);
      },
    );
  }

  void _normalizeControllerText(
    TextEditingController controller,
    String raw,
    String Function(String) normalizer,
  ) {
    final normalized = normalizer(raw);
    if (normalized == raw) return;
    controller.value = TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
    );
  }

  void _handleNameChanged(TextEditingController controller, String value) {
    _normalizeControllerText(controller, value, _normalizePersonName);
  }

  void _handleEmailChanged(String value) {
    _normalizeControllerText(
      _emailCtrl,
      value,
      (input) => input.toLowerCase(),
    );
    _updateEmailSuggestion(_emailCtrl.text);
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: SaoColors.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: SaoColors.gray700,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: SaoColors.actionPrimary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _isEdit
                      ? Icons.manage_accounts_rounded
                      : Icons.person_add_alt_1_rounded,
                  size: 18,
                  color: SaoColors.actionPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_isEdit ? 'Editar usuario' : 'Nuevo usuario'),
                    const SizedBox(height: 2),
                    Text(
                      _isEdit
                          ? 'Actualiza sus datos principales y el alcance de acceso.'
                          : 'Captura datos personales, acceso y asignaciones del usuario.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: SaoColors.gray700,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      content: SizedBox(
        width: 540,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final useTwoColumns = constraints.maxWidth >= 500;
                final fieldWidth = useTwoColumns
                    ? (constraints.maxWidth - 12) / 2
                    : constraints.maxWidth;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: SaoColors.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: SaoColors.error.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: SaoColors.error,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: SaoColors.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    _buildSectionHeader(
                      'Datos personales',
                      _isEdit
                          ? 'Edita la identidad y estado general del usuario.'
                          : 'Captura el nombre, cumpleaños y credenciales de acceso.',
                    ),
                    if (_isEdit) ...[
                      Semantics(
                        textField: true,
                        label: 'Campo de nombre completo',
                        child: TextFormField(
                          controller: _nameCtrl,
                          textCapitalization: TextCapitalization.words,
                          onChanged: (value) =>
                              _handleNameChanged(_nameCtrl, value),
                          decoration: const InputDecoration(
                            labelText: 'Nombre completo *',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 16,
                            ),
                            prefixIcon: Icon(
                              Icons.badge_outlined,
                              semanticLabel: 'Icono de nombre completo',
                            ),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Requerido'
                              : null,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ] else ...[
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: fieldWidth,
                            child: TextFormField(
                              controller: _firstNameCtrl,
                              textCapitalization: TextCapitalization.words,
                              onChanged: (value) =>
                                  _handleNameChanged(_firstNameCtrl, value),
                              decoration: const InputDecoration(
                                labelText: 'Nombre *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Requerido'
                                  : null,
                            ),
                          ),
                          SizedBox(
                            width: fieldWidth,
                            child: TextFormField(
                              controller: _lastNameCtrl,
                              textCapitalization: TextCapitalization.words,
                              onChanged: (value) =>
                                  _handleNameChanged(_lastNameCtrl, value),
                              decoration: const InputDecoration(
                                labelText: 'Apellido paterno *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Requerido'
                                  : null,
                            ),
                          ),
                          SizedBox(
                            width: fieldWidth,
                            child: TextFormField(
                              controller: _secondLastNameCtrl,
                              textCapitalization: TextCapitalization.words,
                              onChanged: (value) => _handleNameChanged(
                                  _secondLastNameCtrl, value),
                              decoration: const InputDecoration(
                                labelText: 'Segundo apellido',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: fieldWidth,
                            child: TextFormField(
                              controller: _birthDateCtrl,
                              readOnly: true,
                              decoration: InputDecoration(
                                labelText: 'Fecha de cumpleaños *',
                                hintText: 'dd/mm/aaaa',
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.cake_outlined),
                                suffixIcon: IconButton(
                                  tooltip: 'Seleccionar fecha',
                                  icon:
                                      const Icon(Icons.calendar_month_rounded),
                                  onPressed:
                                      _submitting ? null : _pickBirthDate,
                                ),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Requerido'
                                  : null,
                              onTap: _submitting ? null : _pickBirthDate,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: fieldWidth,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Semantics(
                                textField: true,
                                label: _isEdit
                                    ? 'Campo de correo electrónico, solo lectura'
                                    : 'Campo de correo electrónico',
                                child: TextFormField(
                                  controller: _emailCtrl,
                                  readOnly: _isEdit,
                                  style: TextStyle(
                                    color: _isEdit
                                        ? SaoColors.gray800
                                        : SaoColors.gray900,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'Correo electrónico *',
                                    border: const OutlineInputBorder(),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 16,
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.alternate_email_rounded,
                                      semanticLabel:
                                          'Icono de correo electrónico',
                                    ),
                                    suffixIcon: _isEdit
                                        ? const Icon(
                                            Icons.lock_outline_rounded,
                                            size: 18,
                                            semanticLabel:
                                                'Campo de correo no editable',
                                          )
                                        : null,
                                    filled: _isEdit,
                                    fillColor:
                                        _isEdit ? SaoColors.gray100 : null,
                                  ),
                                  keyboardType: TextInputType.emailAddress,
                                  autovalidateMode:
                                      AutovalidateMode.onUserInteraction,
                                  onChanged: _handleEmailChanged,
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Requerido';
                                    }
                                    final normalized = v.trim();
                                    final emailPattern =
                                        RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                                    if (!emailPattern.hasMatch(normalized)) {
                                      return 'Correo inválido';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              if (_emailDomainSuggestion != null) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.lightbulb_outline_rounded,
                                      size: 14,
                                      color: SaoColors.warning,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Sugerencia: $_emailDomainSuggestion',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: SaoColors.gray600,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: _isEdit || _submitting
                                          ? null
                                          : _applyEmailSuggestion,
                                      child: Text(
                                        _isEdit ? 'Verificar' : 'Usar .com',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (!_isEdit)
                          SizedBox(
                            width: fieldWidth,
                            child: TextFormField(
                              controller: _passwordCtrl,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: 'Contraseña *',
                                helperText: 'Mínimo 6 caracteres',
                                border: const OutlineInputBorder(),
                                prefixIcon:
                                    const Icon(Icons.lock_outline_rounded),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_rounded
                                        : Icons.visibility_rounded,
                                  ),
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Requerido';
                                if (v.length < 6) {
                                  return 'Mínimo 6 caracteres';
                                }
                                return null;
                              },
                            ),
                          ),
                      ],
                    ),
                    if (_isEdit) ...[
                      const SizedBox(height: 14),
                      SizedBox(
                        width: fieldWidth,
                        child: DropdownButtonFormField<String>(
                          initialValue: _status,
                          decoration: const InputDecoration(
                            labelText: 'Estado',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(
                              Icons.toggle_on_outlined,
                              semanticLabel: 'Icono de estado de usuario',
                            ),
                          ),
                          items: _statuses
                              .map(
                                (s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(
                                    s == 'active' ? 'Activo' : 'Inactivo',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _status = v);
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    _buildSectionHeader(
                      'Asignaciones de acceso',
                      'Define el rol principal y los proyectos donde podrá operar.',
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: SaoColors.gray100,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: SaoColors.gray300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Cada asignación combina un rol con un alcance global o por proyecto.',
                            style: TextStyle(
                              color: SaoColors.gray700,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_scopes.length <= 3) ..._buildScopeEditors(),
                          if (_scopes.length > 3)
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 220),
                              child: Scrollbar(
                                controller: _scopesScrollCtrl,
                                thumbVisibility: true,
                                child: SingleChildScrollView(
                                  controller: _scopesScrollCtrl,
                                  primary: false,
                                  child: Column(
                                    children: _buildScopeEditors(),
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: SaoColors.actionPrimary,
                                backgroundColor: SaoColors.actionPrimary
                                    .withValues(alpha: 0.05),
                                side: BorderSide(
                                  color: SaoColors.actionPrimary
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                              onPressed: _submitting
                                  ? null
                                  : () {
                                      setState(() {
                                        _scopes.add(
                                          _ScopeDraft(
                                            role: 'OPERATIVO',
                                            projectId: '',
                                          ),
                                        );
                                      });
                                    },
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: const Text('Agregar proyecto/rol'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          size: 16,
                          color: SaoColors.gray500,
                          semanticLabel: 'Información de permisos finos',
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Los permisos finos se gestionan desde el icono de seguridad en la tarjeta del usuario.',
                            style: TextStyle(
                              color: SaoColors.gray600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
              if (states.contains(WidgetState.disabled)) {
                return SaoColors.actionPrimary.withValues(alpha: 0.55);
              }
              if (states.contains(WidgetState.pressed)) {
                return SaoColors.primary;
              }
              if (states.contains(WidgetState.hovered)) {
                return SaoColors.actionPrimaryLight;
              }
              return SaoColors.actionPrimary;
            }),
            foregroundColor:
                WidgetStateProperty.all<Color>(SaoColors.onActionPrimary),
          ),
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: SaoColors.onActionPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(_isEdit ? 'Guardando...' : 'Creando...'),
                  ],
                )
              : Text(_isEdit ? 'Guardar' : 'Crear'),
        ),
      ],
    );
  }

  List<Widget> _buildScopeEditors() {
    return List<Widget>.generate(_scopes.length, (index) {
      final scope = _scopes[index];
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: SaoColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: SaoColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  initialValue:
                      _roles.contains(scope.role) ? scope.role : 'OPERATIVO',
                  decoration: const InputDecoration(
                    labelText: 'Rol',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: _roles
                      .map((role) =>
                          DropdownMenuItem(value: role, child: Text(role)))
                      .toList(),
                  onChanged: _submitting
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() => scope.role = value);
                        },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  initialValue: scope.projectId.isEmpty ? '' : scope.projectId,
                  decoration: const InputDecoration(
                    labelText: 'Proyecto',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('Global (sin proyecto)'),
                    ),
                    ...widget.availableProjects.map(
                      (id) => DropdownMenuItem(value: id, child: Text(id)),
                    ),
                  ],
                  onChanged: _submitting
                      ? null
                      : (value) {
                          setState(() => scope.projectId = value ?? '');
                        },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Eliminar asignación',
                onPressed: _submitting || _scopes.length == 1
                    ? null
                    : () {
                        setState(() {
                          _scopes.removeAt(index);
                        });
                      },
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
              ),
            ],
          ),
        ),
      );
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final normalizedScopes = _scopes
        .map((scope) => scope.toScope())
        .where((scope) => scope.role.isNotEmpty)
        .toList();

    if (normalizedScopes.isEmpty) {
      setState(() {
        _error = 'Debes agregar al menos un rol.';
      });
      return;
    }

    // Legacy compatibility: some deployed backends still require top-level
    // `role` and `project_id` even when `scopes` is sent. Others only persist
    // multi-project changes when `roles` / `project_ids` are also present.
    final primaryScope = normalizedScopes.first;
    final primaryRole = primaryScope.role.trim().toUpperCase();
    final primaryProjectId =
        (primaryScope.projectId ?? '').trim().toUpperCase();
    final requestedRoles = <String>[];
    final requestedProjectIds = <String>[];
    for (final scope in normalizedScopes) {
      final normalizedRole = scope.role.trim().toUpperCase();
      final normalizedProject = (scope.projectId ?? '').trim().toUpperCase();
      if (normalizedRole.isNotEmpty &&
          !requestedRoles.contains(normalizedRole)) {
        requestedRoles.add(normalizedRole);
      }
      if (normalizedProject.isNotEmpty &&
          !requestedProjectIds.contains(normalizedProject)) {
        requestedProjectIds.add(normalizedProject);
      }
    }
    final payload = {
      'role': primaryRole,
      'project_id': primaryProjectId,
      'roles': requestedRoles,
      'project_ids': requestedProjectIds,
      'scopes': normalizedScopes.map((scope) => scope.toJson()).toList(),
    };

    final fullName = _isEdit
        ? _normalizePersonName(_nameCtrl.text)
        : [
            _normalizePersonName(_firstNameCtrl.text),
            _normalizePersonName(_lastNameCtrl.text),
            _normalizePersonName(_secondLastNameCtrl.text),
          ].where((part) => part.isNotEmpty).join(' ');
    final normalizedEmail = _emailCtrl.text.trim().toLowerCase();
    final birthDateIso = _birthDate == null
        ? null
        : '${_birthDate!.year.toString().padLeft(4, '0')}-${_birthDate!.month.toString().padLeft(2, '0')}-${_birthDate!.day.toString().padLeft(2, '0')}';

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      if (_isEdit) {
        await const BackendApiClient().patchJson(
          '/api/v1/users/admin/${widget.user!.id}',
          {
            'full_name': fullName,
            'status': _status,
            ...payload,
          },
        );
      } else {
        await const BackendApiClient().postJson(
          '/api/v1/users/admin',
          {
            'email': normalizedEmail,
            'full_name': fullName,
            'password': _passwordCtrl.text,
            if (birthDateIso != null) 'birth_date': birthDateIso,
            ...payload,
          },
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      final msg = e.toString();
      setState(() {
        _error = msg.contains('Permission not configured:')
            ? 'El backend no tiene configurado uno de los permisos enviados. Aplica el catálogo SQL de permisos antes de guardar permisos directos.'
            : msg.contains('409')
                ? 'Ya existe un usuario con ese correo.'
                : msg.contains('400')
                    ? 'Datos inválidos. Verifica el rol, proyecto o permiso seleccionado.'
                    : 'Error al guardar: $msg';
        _submitting = false;
      });
    }
  }
}

class _UserPermissionsDialog extends StatefulWidget {
  final _AdminUser user;
  final List<String> availablePermissions;
  final _RolePermissionsMap rolePermissions;
  final List<String> availableProjects;

  const _UserPermissionsDialog({
    required this.user,
    required this.availablePermissions,
    required this.rolePermissions,
    required this.availableProjects,
  });

  @override
  State<_UserPermissionsDialog> createState() => _UserPermissionsDialogState();
}

class _UserPermissionsDialogState extends State<_UserPermissionsDialog> {
  late List<_PermissionScopeDraft> _permissionScopes;
  String _permissionsView = 'direct';
  bool _submitting = false;
  String? _error;

  bool get _hasDirectPermissionCatalog =>
      widget.availablePermissions.isNotEmpty;
  bool get _hasRolePermissionCatalog => widget.rolePermissions.isNotEmpty;

  ButtonStyle get _addDirectPermissionButtonStyle {
    return ButtonStyle(
      foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.disabled)) {
          return SaoColors.gray500;
        }
        return SaoColors.gray900;
      }),
      backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.disabled)) {
          return SaoColors.gray100;
        }
        return SaoColors.surface;
      }),
      side: WidgetStateProperty.resolveWith<BorderSide>((states) {
        if (states.contains(WidgetState.disabled)) {
          return const BorderSide(color: SaoColors.gray300);
        }
        return const BorderSide(color: SaoColors.gray400);
      }),
    );
  }

  @override
  void initState() {
    super.initState();
    _permissionScopes = widget.user.permissionScopes
        .map(_PermissionScopeDraft.fromScope)
        .toList();
    if (!_hasDirectPermissionCatalog) {
      _permissionsView = _hasRolePermissionCatalog ? 'role' : 'effective';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Permisos de ${widget.user.fullName}'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: SaoColors.error.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: SaoColors.error.withValues(alpha: 0.6)),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                        fontSize: 13,
                        color: SaoColors.error,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_hasRolePermissionCatalog)
                    ChoiceChip(
                      label: const Text('Rol base'),
                      selected: _permissionsView == 'role',
                      showCheckmark: false,
                      onSelected: (_) =>
                          setState(() => _permissionsView = 'role'),
                    ),
                  if (_hasDirectPermissionCatalog)
                    ChoiceChip(
                      label: const Text('Permisos directos'),
                      selected: _permissionsView == 'direct',
                      showCheckmark: false,
                      onSelected: (_) =>
                          setState(() => _permissionsView = 'direct'),
                    ),
                  ChoiceChip(
                    label: const Text('Permisos efectivos'),
                    selected: _permissionsView == 'effective',
                    showCheckmark: false,
                    onSelected: (_) =>
                        setState(() => _permissionsView = 'effective'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_permissionsView == 'role' && _hasRolePermissionCatalog)
                _buildRolePermissionsSummary()
              else if (_permissionsView == 'effective')
                _buildEffectivePermissionsSummary()
              else if (!_hasDirectPermissionCatalog)
                const Text(
                  'No hay catálogo de permisos disponible en el backend actual.',
                  style: TextStyle(color: SaoColors.gray700, fontSize: 12),
                )
              else ...[
                ..._buildPermissionScopeEditors(),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    style: _addDirectPermissionButtonStyle,
                    onPressed: _submitting
                        ? null
                        : () {
                            setState(() {
                              _permissionScopes.add(
                                _PermissionScopeDraft(
                                  permissionCode:
                                      widget.availablePermissions.first,
                                  projectId: '',
                                  effect: 'allow',
                                ),
                              );
                            });
                          },
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Agregar permiso directo'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar permisos'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final normalizedPermissionScopes = _permissionScopes
        .map((scope) => scope.toScope())
        .where((scope) => scope.permissionCode.isNotEmpty)
        .toList();

    final scopePayload = widget.user.scopes.isNotEmpty
        ? widget.user.scopes.map((scope) => scope.toJson()).toList()
        : [
            {
              'role': widget.user.primaryRole.isNotEmpty
                  ? widget.user.primaryRole
                  : 'OPERATIVO',
              'project_id': widget.user.primaryProjectId,
            }
          ];

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await const BackendApiClient().patchJson(
        '/api/v1/users/admin/${widget.user.id}',
        {
          'role': widget.user.primaryRole.isNotEmpty
              ? widget.user.primaryRole
              : 'OPERATIVO',
          'project_id': widget.user.primaryProjectId ?? '',
          'scopes': scopePayload,
          'permission_scopes': normalizedPermissionScopes
              .map((scope) => scope.toJson())
              .toList(),
        },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      final msg = e.toString();
      setState(() {
        _error = msg.contains('Permission not configured:')
            ? 'El backend no tiene configurado uno de los permisos enviados.'
            : 'Error al guardar permisos: $msg';
        _submitting = false;
      });
    }
  }

  List<Widget> _buildPermissionScopeEditors() {
    return List<Widget>.generate(_permissionScopes.length, (index) {
      final scope = _permissionScopes[index];
      final selectedPermission =
          widget.availablePermissions.contains(scope.permissionCode)
              ? scope.permissionCode
              : (widget.availablePermissions.isNotEmpty
                  ? widget.availablePermissions.first
                  : null);
      if (selectedPermission != null &&
          selectedPermission != scope.permissionCode) {
        scope.permissionCode = selectedPermission;
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: DropdownButtonFormField<String>(
                initialValue: selectedPermission,
                decoration: const InputDecoration(
                  labelText: 'Permiso',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: widget.availablePermissions
                    .map((permission) => DropdownMenuItem(
                          value: permission,
                          child:
                              Text(permission, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: _submitting
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() => scope.permissionCode = value);
                      },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                initialValue: scope.projectId.isEmpty ? '' : scope.projectId,
                decoration: const InputDecoration(
                  labelText: 'Proyecto',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem(
                      value: '', child: Text('Global (sin proyecto)')),
                  ...widget.availableProjects.map(
                    (id) => DropdownMenuItem(value: id, child: Text(id)),
                  ),
                ],
                onChanged: _submitting
                    ? null
                    : (value) {
                        setState(() => scope.projectId = value ?? '');
                      },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                initialValue: scope.effect == 'deny' ? 'deny' : 'allow',
                decoration: const InputDecoration(
                  labelText: 'Efecto',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: 'allow', child: Text('Permitir')),
                  DropdownMenuItem(value: 'deny', child: Text('Denegar')),
                ],
                onChanged: _submitting
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() => scope.effect = value);
                      },
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              tooltip: 'Eliminar permiso',
              onPressed: _submitting
                  ? null
                  : () {
                      setState(() {
                        _permissionScopes.removeAt(index);
                      });
                    },
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildRolePermissionsSummary() {
    final scopes = widget.user.scopes.isNotEmpty
        ? widget.user.scopes
        : [
            _UserScope(
              role: widget.user.primaryRole.isNotEmpty
                  ? widget.user.primaryRole
                  : 'OPERATIVO',
              projectId: widget.user.primaryProjectId,
            ),
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: scopes.map((scope) {
        final role = scope.role.trim().toUpperCase();
        final projectId = (scope.projectId ?? '').trim().toUpperCase();
        final permissions =
            (widget.rolePermissions[role] ?? const <String>[]).toList()..sort();

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$role · ${projectId.isEmpty ? 'Global' : 'Proyecto $projectId'}',
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
              const SizedBox(height: 6),
              if (permissions.isEmpty)
                const Text(
                  'Este rol no expone permisos base en el catálogo actual.',
                  style: TextStyle(color: SaoColors.gray700, fontSize: 12),
                )
              else
                _permissionWrap(
                  permissions,
                  background: SaoColors.gray300,
                  foreground: SaoColors.gray900,
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEffectivePermissionsSummary() {
    final effectiveByScope = <String, Set<String>>{};
    final deniedByScope = <String, Set<String>>{};

    void ensureScope(String label) {
      effectiveByScope.putIfAbsent(label, () => <String>{});
      deniedByScope.putIfAbsent(label, () => <String>{});
    }

    final roleScopes = widget.user.scopes.isNotEmpty
        ? widget.user.scopes
        : [
            _UserScope(
              role: widget.user.primaryRole.isNotEmpty
                  ? widget.user.primaryRole
                  : 'OPERATIVO',
              projectId: widget.user.primaryProjectId,
            ),
          ];

    for (final scope in roleScopes) {
      final role = scope.role.trim().toUpperCase();
      final projectId = (scope.projectId ?? '').trim().toUpperCase();
      final label = projectId.isEmpty ? 'Global' : 'Proyecto $projectId';
      ensureScope(label);
      effectiveByScope[label]!
          .addAll(widget.rolePermissions[role] ?? const <String>[]);
    }

    for (final scope in widget.user.permissionScopes) {
      final code = scope.permissionCode.trim();
      if (code.isEmpty) continue;
      final projectId = (scope.projectId ?? '').trim().toUpperCase();
      final label = projectId.isEmpty ? 'Global' : 'Proyecto $projectId';
      ensureScope(label);
      if (scope.effect.trim().toLowerCase() == 'deny') {
        effectiveByScope[label]!.remove(code);
        deniedByScope[label]!.add(code);
      } else {
        effectiveByScope[label]!.add(code);
        deniedByScope[label]!.remove(code);
      }
    }

    if (effectiveByScope.isEmpty && deniedByScope.isEmpty) {
      return const Text(
        'No hay permisos calculables para este usuario.',
        style: TextStyle(color: SaoColors.gray700, fontSize: 12),
      );
    }

    final labels = <String>{
      ...effectiveByScope.keys,
      ...deniedByScope.keys,
    }.toList()
      ..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: labels.map((label) {
        final granted = (effectiveByScope[label] ?? <String>{}).toList()
          ..sort();
        final denied = (deniedByScope[label] ?? <String>{}).toList()..sort();

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$label · ${granted.length} permisos activos',
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
              const SizedBox(height: 6),
              if (granted.isEmpty)
                const Text(
                  'Sin permisos en este alcance.',
                  style: TextStyle(color: SaoColors.gray700, fontSize: 12),
                )
              else
                _permissionWrap(
                  granted,
                  background: SaoColors.statusAprobadoBg,
                  foreground: SaoColors.success,
                ),
              if (denied.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Denegados: ${denied.join(', ')}',
                  style: const TextStyle(color: SaoColors.error, fontSize: 11),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _permissionWrap(
    List<String> codes, {
    required Color background,
    required Color foreground,
  }) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: codes
          .map(
            (code) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: foreground.withValues(alpha: 0.5)),
              ),
              child: Text(
                code,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: foreground,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Small widgets
// ---------------------------------------------------------------------------

class _FilterDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final void Function(String) onChanged;

  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 134,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: SaoColors.gray200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: SaoColors.gray200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: SaoColors.gray400),
          ),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        items: items
            .map((i) => DropdownMenuItem(value: i, child: Text(i)))
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;

  const _RoleBadge({required this.role});

  static Color _colorFor(String role) => switch (role.toUpperCase()) {
        'ADMIN' => const Color(0xFF6366F1),
        'SUPERVISOR' => const Color(0xFF2563EB),
        'COORD' => const Color(0xFF64748B),
        'OPERATIVO' => const Color(0xFF0F766E),
        'LECTOR' => const Color(0xFF475569),
        _ => SaoColors.gray500,
      };

  static Color _foregroundFor(String role) {
    // Utilizar la función de contraste automático basada en el fondo
    final bgColor = _backgroundFor(role);
    return SaoContrast.getContrastColor(bgColor);
  }

  static Color _backgroundFor(String role) => switch (role.toUpperCase()) {
        'ADMIN' => const Color(0xFFEEF2FF),
        'SUPERVISOR' => const Color(0xFFDBEAFE),
        'COORD' => const Color(0xFFF1F5F9),
        'OPERATIVO' => const Color(0xFFCCFBF1),
        'LECTOR' => const Color(0xFFF1F5F9),
        _ => SaoColors.gray500.withValues(alpha: 0.16),
      };

  @override
  Widget build(BuildContext context) {
    final backgroundColor = _backgroundFor(role);
    final foreground = _foregroundFor(role);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: _colorFor(role).withValues(alpha: 0.4),
        ),
      ),
      child: Text(
        role,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: foreground),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isActive;

  const _StatusBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? const Color(0xFF16A34A) : SaoColors.gray500;
    final bg = isActive ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? Icons.circle : Icons.circle_outlined,
            size: 10,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            isActive ? 'Activo' : 'Inactivo',
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: SaoColors.error),
          const SizedBox(height: 8),
          Text(message,
              style: const TextStyle(color: SaoColors.gray600),
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// String extension (local)
// ---------------------------------------------------------------------------

extension _StringExt on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
