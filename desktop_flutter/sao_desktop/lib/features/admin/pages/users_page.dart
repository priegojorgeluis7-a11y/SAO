// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../auth/session_controller.dart';
import '../data/admin_repositories.dart';

// ─── Design tokens (Tailwind / Shadcn equivalents) ────────────────────────────

const _kRoles = ['ADMIN', 'SUPERVISOR', 'OPERATIVO', 'LECTOR'];

/// Role badge palette — pastel fills, semibold text
const _kRolePalette = {
  'ADMIN': (bg: Color(0xFFEDE9FE), fg: Color(0xFF6D28D9)),
  'SUPERVISOR': (bg: Color(0xFFDBEAFE), fg: Color(0xFF1D4ED8)),
  'OPERATIVO': (bg: Color(0xFFD1FAE5), fg: Color(0xFF065F46)),
  'LECTOR': (bg: Color(0xFFF1F5F9), fg: Color(0xFF475569)),
};

/// Status palette
const _kStatusPalette = {
  'active': (
    label: 'Activo',
    bg: Color(0xFFDCFCE7),
    fg: Color(0xFF16A34A),
    icon: Icons.check_circle_rounded,
  ),
  'inactive': (
    label: 'Inactivo',
    bg: Color(0xFFF1F5F9),
    fg: Color(0xFF64748B),
    icon: Icons.cancel_rounded,
  ),
  'suspended': (
    label: 'Suspendido',
    bg: Color(0xFFFEE2E2),
    fg: Color(0xFFDC2626),
    icon: Icons.block_rounded,
  ),
};

Color _roleColor(String role) =>
    _kRolePalette[role.toUpperCase()]?.fg ?? AppColors.gray500;

String _userInitials(String fullName) {
  final parts = fullName.trim().split(' ');
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

// ─── Page ─────────────────────────────────────────────────────────────────────

class AdminUsersPage extends ConsumerStatefulWidget {
  const AdminUsersPage({super.key});

  @override
  ConsumerState<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends ConsumerState<AdminUsersPage> {
  List<AdminUserItem> _users = const [];
  bool _loading = true;
  String? _error;
  String _roleFilter = '';
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  String? _selectedUserId;
  final Map<String, Future<List<AuditItem>>> _activityCache = {};

  int _countByRole(String role) =>
      _users.where((u) => u.roleName.toUpperCase() == role.toUpperCase()).length;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadUsers);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final token = ref.read(sessionControllerProvider).accessToken;
    if (token == null) {
      setState(() {
        _loading = false;
        _error = 'Sesión no disponible';
      });
      return;
    }
    try {
      final data = await ref.read(usersRepositoryProvider).list(token);
      if (!mounted) return;
      setState(() {
        _users = data;
        _loading = false;
        if (_selectedUserId != null &&
            !_users.any((user) => user.id == _selectedUserId)) {
          _selectedUserId = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  List<AdminUserItem> get _filtered {
    var list = _users;
    if (_roleFilter.isNotEmpty) {
      list = list
          .where((u) => u.roleName.toUpperCase() == _roleFilter.toUpperCase())
          .toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((u) {
        return u.fullName.toLowerCase().contains(q) ||
            u.email.toLowerCase().contains(q) ||
            (u.projectId ?? '').toLowerCase().contains(q) ||
            u.roleName.toLowerCase().contains(q);
      }).toList();
    }
    return list;
  }

  bool get _hasFilter => _roleFilter.isNotEmpty || _searchQuery.isNotEmpty;

  String? _resolveToken() {
    return ref.read(sessionControllerProvider).accessToken;
  }

  AdminUserItem? get _selectedUser {
    final selectedId = _selectedUserId;
    if (selectedId == null) return null;
    for (final user in _users) {
      if (user.id == selectedId) return user;
    }
    return null;
  }

  void _selectUser(AdminUserItem user) {
    setState(() {
      _selectedUserId = user.id;
    });
  }

  void _closeDetails() {
    setState(() {
      _selectedUserId = null;
    });
  }

  Future<List<AuditItem>> _loadUserActivity(AdminUserItem user) async {
    final token = _resolveToken();
    if (token == null) return const [];

    final items = await ref.read(auditRepositoryProvider).list(
          token,
          actorEmail: user.email,
        );

    final sorted = [...items]
      ..sort((a, b) => _parseAuditDate(b.createdAt)
          .compareTo(_parseAuditDate(a.createdAt)));
    return sorted.take(12).toList();
  }

  Future<List<AuditItem>> _activityFutureFor(AdminUserItem user) {
    return _activityCache.putIfAbsent(user.id, () => _loadUserActivity(user));
  }

  Future<List<AdminAssignmentItem>> _loadUserAssignments(
    AdminUserItem user,
    String token,
  ) async {
    final projectIds = (user.projectId ?? '').trim().isNotEmpty
        ? [user.projectId!.trim().toUpperCase()]
        : ['TMQ', 'TAP'];
    final from = DateTime(2024, 1, 1);
    final to = DateTime(2027, 12, 31);
    final repo = ref.read(assignmentsAdminRepositoryProvider);
    final all = <AdminAssignmentItem>[];
    for (final pid in projectIds) {
      try {
        final items =
            await repo.list(token, projectId: pid, from: from, to: to);
        all.addAll(items.where((i) => i.assigneeUserId == user.id));
      } catch (_) {}
    }
    all.sort((a, b) => b.startAt.compareTo(a.startAt));
    return all;
  }

  DateTime _parseAuditDate(String raw) {
    return DateTime.tryParse(raw)?.toLocal() ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  Future<void> _toggleStatus(AdminUserItem user) async {
    final token = _resolveToken();
    if (token == null) return;

    final nextStatus = user.status.toLowerCase() == 'active' ? 'inactive' : 'active';
    try {
      await ref.read(usersRepositoryProvider).update(
            token,
            user.id,
            status: nextStatus,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nextStatus == 'active'
                ? 'Usuario activado'
                : 'Usuario desactivado',
          ),
        ),
      );
      await _loadUsers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  // ─── Modal ─────────────────────────────────────────────────────────────────

  Future<void> _openModal(AdminUserItem user, {int initialTab = 0}) async {
    final token = _resolveToken();
    if (token == null) return;
    final reload = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar',
      barrierColor: Colors.black.withOpacity(0.35),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, _, __) => _UserModal(
        user: user,
        initialTab: initialTab,
        assignmentsFuture: _loadUserAssignments(user, token),
        onSave: (fullName, role, projectId, status) async {
          await ref.read(usersRepositoryProvider).update(
                token,
                user.id,
                fullName: fullName,
                role: role,
                projectId: projectId,
                status: status,
              );
        },
      ),
      transitionBuilder: (ctx, anim, _, child) {
        final curved =
            CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
    if (reload == true && mounted) await _loadUsers();
  }

  Future<void> _openCreateDialog() async {
    final emailCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final projCtrl = TextEditingController();
    String role = 'SUPERVISOR';
    bool obscure = true;

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Nuevo usuario'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Field(ctrl: emailCtrl, label: 'Correo electrónico', icon: Icons.email_outlined, keyboard: TextInputType.emailAddress),
                const SizedBox(height: 12),
                _Field(ctrl: nameCtrl, label: 'Nombre completo', icon: Icons.person_outline),
                const SizedBox(height: 12),
                TextField(
                  controller: passCtrl,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    labelText: 'Contraseña inicial',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setLocal(() => obscure = !obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: role,
                  items: _kRoles.map((r) => DropdownMenuItem(value: r, child: _RoleBadge(r))).toList(),
                  onChanged: (v) { if (v != null) setLocal(() => role = v); },
                  decoration: const InputDecoration(labelText: 'Rol', prefixIcon: Icon(Icons.badge_outlined)),
                ),
                const SizedBox(height: 12),
                _Field(ctrl: projCtrl, label: 'Proyecto (opcional)', icon: Icons.folder_outlined, hint: 'TMQ'),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.person_add),
              label: const Text('Crear'),
            ),
          ],
        ),
      ),
    );
    if (created != true) return;
    final token = ref.read(sessionControllerProvider).accessToken;
    if (token == null) return;
    try {
      await ref.read(usersRepositoryProvider).create(
            token,
            email: emailCtrl.text.trim(),
            fullName: nameCtrl.text.trim(),
            password: passCtrl.text,
            role: role,
            projectId: projCtrl.text.trim().isEmpty ? null : projCtrl.text.trim(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuario creado'), backgroundColor: Colors.green),
        );
        await _loadUsers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: AppColors.gray700)),
            const SizedBox(height: 12),
            FilledButton(onPressed: _loadUsers, child: const Text('Reintentar')),
          ],
        ),
      );
    }

    final displayed = _filtered;
    final selectedUser = _selectedUser;

    return Container(
      color: AppColors.gray50,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Stat cards row ─────────────────────────────────────────────
          Row(
            children: [
              _StatCard(
                label: 'Total',
                count: _users.length,
                icon: Icons.people_outline_rounded,
                active: _roleFilter.isEmpty,
                onTap: () => setState(() {
                  _roleFilter = '';
                  _searchQuery = '';
                  _searchCtrl.clear();
                }),
              ),
              ..._kRoles
                  .where((r) => _countByRole(r) > 0)
                  .map((r) => Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: _StatCard(
                          label: r,
                          count: _countByRole(r),
                          rolePalette: _kRolePalette[r],
                          active: _roleFilter == r,
                          onTap: () =>
                              setState(() => _roleFilter = _roleFilter == r ? '' : r),
                        ),
                      )),
              const Spacer(),
              FilledButton.icon(
                onPressed: _openCreateDialog,
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                label: const Text('Nuevo usuario'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.gray800,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Unified search toolbar (Shadcn CommandBar style) ───────────
          _SearchToolbar(
            controller: _searchCtrl,
            roleFilter: _roleFilter,
            totalShown: displayed.length,
            totalAll: _users.length,
            hasFilter: _hasFilter,
            onSearch: (v) => setState(() => _searchQuery = v),
            onClearRole: () => setState(() => _roleFilter = ''),
            onClearAll: () => setState(() {
              _roleFilter = '';
              _searchQuery = '';
              _searchCtrl.clear();
            }),
            onRefresh: _loadUsers,
          ),
          const SizedBox(height: 12),

          // ── Table card ─────────────────────────────────────────────────
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    margin: EdgeInsets.only(right: selectedUser == null ? 0 : 12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        _TableHeader(showActionsHint: selectedUser == null),
                        Divider(height: 1, color: AppColors.border),
                        Expanded(
                          child: displayed.isEmpty
                              ? _EmptyState(
                                  hasFilter: _hasFilter,
                                  onClear: () => setState(() {
                                    _roleFilter = '';
                                    _searchQuery = '';
                                    _searchCtrl.clear();
                                  }),
                                )
                              : ListView.separated(
                                  itemCount: displayed.length,
                                  separatorBuilder: (_, __) => Divider(
                                    height: 1,
                                    color: AppColors.border,
                                    indent: 56,
                                  ),
                                  itemBuilder: (_, i) => _UserRow(
                                    user: displayed[i],
                                    selected: displayed[i].id == _selectedUserId,
                                    onTap: () => _selectUser(displayed[i]),
                                    onEdit: () => _openModal(displayed[i]),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  width: selectedUser == null ? 0 : 388,
                  child: selectedUser == null
                      ? const SizedBox.shrink()
                      : _DetailsSidebar(
                          user: selectedUser,
                          activityFuture: _activityFutureFor(selectedUser),
                          onClose: _closeDetails,
                          onEdit: () => _openModal(selectedUser),
                          onPermissions: () => _openModal(selectedUser, initialTab: 1),
                          onActivity: () => _openModal(selectedUser, initialTab: 2),
                          onToggleStatus: () => _toggleStatus(selectedUser),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Search Toolbar ───────────────────────────────────────────────────────────

class _SearchToolbar extends StatelessWidget {
  final TextEditingController controller;
  final String roleFilter;
  final int totalShown;
  final int totalAll;
  final bool hasFilter;
  final ValueChanged<String> onSearch;
  final VoidCallback onClearRole;
  final VoidCallback onClearAll;
  final VoidCallback onRefresh;

  const _SearchToolbar({
    required this.controller,
    required this.roleFilter,
    required this.totalShown,
    required this.totalAll,
    required this.hasFilter,
    required this.onSearch,
    required this.onClearRole,
    required this.onClearAll,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 18, color: AppColors.gray400),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onSearch,
              style: TextStyle(
                  fontSize: 13, color: AppColors.gray800),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, correo, rol o proyecto…',
                hintStyle: TextStyle(color: AppColors.gray400, fontSize: 13),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            _ToolbarAction(
              icon: Icons.close_rounded,
              tooltip: 'Limpiar búsqueda',
              onTap: () {
                controller.clear();
                onSearch('');
              },
            ),
          // Active filter chip
          if (roleFilter.isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _roleColor(roleFilter).withOpacity(0.10),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _roleColor(roleFilter).withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(roleFilter,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _roleColor(roleFilter))),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: onClearRole,
                    child: Icon(Icons.close_rounded,
                        size: 13, color: _roleColor(roleFilter)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(width: 8),
          // Counter
          Text(
            hasFilter
                ? '$totalShown / $totalAll'
                : '$totalAll',
            style: TextStyle(
                fontSize: 12,
                color: AppColors.gray500,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 4),
          Text('usuarios',
              style: TextStyle(fontSize: 12, color: AppColors.gray400)),
          const SizedBox(width: 8),
          Container(width: 1, height: 18, color: AppColors.border),
          const SizedBox(width: 4),
          _ToolbarAction(
            icon: Icons.refresh_rounded,
            tooltip: 'Actualizar',
            onTap: onRefresh,
          ),
        ],
      ),
    );
  }
}

class _ToolbarAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ToolbarAction(
      {required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 16, color: AppColors.gray500),
        ),
      ),
    );
  }
}

// ─── Stat card ────────────────────────────────────────────────────────────────

class _StatCard extends StatefulWidget {
  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;
  final IconData? icon;
  final ({Color bg, Color fg})? rolePalette;

  const _StatCard({
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
    this.icon,
    this.rolePalette,
  });

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = widget.rolePalette;
    final accentColor = palette?.fg ?? AppColors.gray700;
    final bgColor =
        widget.active ? (palette?.bg ?? AppColors.gray100) : AppColors.surface;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.active
                  ? accentColor.withOpacity(0.4)
                  : (_hovered ? AppColors.borderStrong : AppColors.border),
              width: widget.active ? 1.5 : 1,
            ),
            boxShadow: _hovered || widget.active
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 15, color: accentColor),
                const SizedBox(width: 6),
              ],
              Text(
                '${widget.count}',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  color: widget.active ? accentColor : AppColors.gray500,
                  fontWeight:
                      widget.active ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Table header ─────────────────────────────────────────────────────────────

class _TableHeader extends StatelessWidget {
  final bool showActionsHint;

  const _TableHeader({this.showActionsHint = true});

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.gray500,
        letterSpacing: 0.5);
    return Container(
      color: AppColors.gray50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const SizedBox(width: 40),
          const Expanded(flex: 3, child: Text('NOMBRE', style: style)),
          const Expanded(flex: 2, child: Text('ROL', style: style)),
          const Expanded(flex: 2, child: Text('PROYECTO', style: style)),
          const Expanded(flex: 2, child: Text('ESTADO', style: style)),
          SizedBox(
            width: 88,
            child: Text(
              showActionsHint ? 'ACCIONES' : '',
              textAlign: TextAlign.right,
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── User row ─────────────────────────────────────────────────────────────────

class _UserRow extends StatefulWidget {
  final AdminUserItem user;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final bool selected;

  const _UserRow({
    required this.user,
    required this.onTap,
    required this.onEdit,
    required this.selected,
  });

  @override
  State<_UserRow> createState() => _UserRowState();
}

class _UserRowState extends State<_UserRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = _kRolePalette[widget.user.roleName.toUpperCase()];
    final roleColor = palette?.fg ?? AppColors.gray500;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          decoration: BoxDecoration(
            color: widget.selected
                ? const Color(0xFFF0F7FF)
                : (_hovered ? const Color(0xFFF8FAFC) : AppColors.surface),
            border: widget.selected
                ? const Border(
                    left: BorderSide(color: Color(0xFF3B82F6), width: 3),
                  )
                : null,
            boxShadow: _hovered || widget.selected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              // Avatar
              _UserAvatar(name: widget.user.fullName, color: roleColor),
              const SizedBox(width: 10),
              // Name + email
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.user.fullName,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppColors.gray800),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 1),
                    Text(widget.user.email,
                        style: TextStyle(
                            color: AppColors.gray500, fontSize: 11),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Expanded(flex: 2, child: _RoleBadge(widget.user.roleName)),
              Expanded(flex: 2, child: _ProjectChip(widget.user)),
              Expanded(flex: 2, child: _StatusBadge(widget.user.status)),
              // Hover actions
              SizedBox(
                width: 88,
                child: AnimatedOpacity(
                  opacity: _hovered ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 100),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _RowAction(
                        icon: Icons.chevron_right_rounded,
                        tooltip: 'Ver detalles',
                        onTap: widget.onTap,
                      ),
                      const SizedBox(width: 4),
                      _RowAction(
                        icon: Icons.edit_rounded,
                        tooltip: 'Editar',
                        onTap: widget.onEdit,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RowAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _RowAction(
      {required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 16, color: AppColors.gray600),
        ),
      ),
    );
  }
}

class _DetailsSidebar extends StatelessWidget {
  final AdminUserItem user;
  final Future<List<AuditItem>> activityFuture;
  final VoidCallback onClose;
  final VoidCallback onEdit;
  final VoidCallback onPermissions;
  final VoidCallback onActivity;
  final VoidCallback onToggleStatus;

  const _DetailsSidebar({
    required this.user,
    required this.activityFuture,
    required this.onClose,
    required this.onEdit,
    required this.onPermissions,
    required this.onActivity,
    required this.onToggleStatus,
  });

  @override
  Widget build(BuildContext context) {
    final palette = _kRolePalette[user.roleName.toUpperCase()];
    final roleColor = palette?.fg ?? AppColors.gray700;
    final roleBg = palette?.bg ?? AppColors.gray100;
    final active = user.status.toLowerCase() == 'active';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 12, 16),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(
                bottom: BorderSide(color: AppColors.border),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: roleBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: roleColor.withOpacity(0.24), width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _userInitials(user.fullName),
                    style: TextStyle(
                      color: roleColor,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
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
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.gray900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.gray500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _StatusBadge(user.status),
                          _RoleBadge(user.roleName),
                          _ProjectChip(user),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  tooltip: 'Cerrar',
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: AppColors.gray600,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SidebarLabel('Acciones'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _SidebarActionButton(
                        icon: Icons.edit_outlined,
                        label: 'Editar perfil',
                        onTap: onEdit,
                      ),
                      _SidebarActionButton(
                        icon: Icons.shield_outlined,
                        label: 'Permisos',
                        onTap: onPermissions,
                      ),
                      _SidebarActionButton(
                        icon: active
                            ? Icons.person_off_outlined
                            : Icons.person_outline_rounded,
                        label: active ? 'Desactivar' : 'Activar',
                        tone: active ? _ActionTone.warning : _ActionTone.success,
                        onTap: onToggleStatus,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const _SidebarLabel('Resumen'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _DetailMetricCard(
                          label: 'Rol actual',
                          value: user.roleName,
                          accent: roleColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _DetailMetricCard(
                          label: 'Proyecto',
                          value: (user.projectId?.isNotEmpty ?? false)
                              ? user.projectId!
                              : 'Global',
                          accent: const Color(0xFF2563EB),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const _SidebarLabel('Actividad'),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.gray50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: FutureBuilder<List<AuditItem>>(
                      future: activityFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Row(
                            children: [
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Cargando actividad reciente…',
                                style: TextStyle(fontSize: 12, color: AppColors.gray500),
                              ),
                            ],
                          );
                        }

                        if (snapshot.hasError) {
                          return const Text(
                            'No se pudo cargar la actividad.',
                            style: TextStyle(fontSize: 12, color: AppColors.gray500),
                          );
                        }

                        final items = snapshot.data ?? const [];
                        if (items.isEmpty) {
                          return Column(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: const BoxDecoration(
                                  color: AppColors.gray100,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.timeline_rounded,
                                  size: 20,
                                  color: AppColors.gray400,
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Sin actividad reciente',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.gray700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Las acciones del usuario aparecerán en esta línea de tiempo.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12, color: AppColors.gray500),
                              ),
                            ],
                          );
                        }

                        return Column(
                          children: [
                            for (var i = 0; i < items.length; i++)
                              _TimelineEntry(
                                item: items[i],
                                isLast: i == items.length - 1,
                              ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: onActivity,
                                icon: const Icon(Icons.open_in_new_rounded, size: 15),
                                label: const Text('Ver detalle'),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  foregroundColor: AppColors.gray700,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarLabel extends StatelessWidget {
  final String text;
  const _SidebarLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.gray500,
        letterSpacing: 0.4,
      ),
    );
  }
}

enum _ActionTone { neutral, success, warning }

class _SidebarActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final _ActionTone tone;

  const _SidebarActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.tone = _ActionTone.neutral,
  });

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (tone) {
      _ActionTone.success => (
          const Color(0xFFDCFCE7),
          const Color(0xFF15803D),
          const Color(0xFF86EFAC)
        ),
      _ActionTone.warning => (
          const Color(0xFFFFF7ED),
          const Color(0xFFEA580C),
          const Color(0xFFFED7AA)
        ),
      _ActionTone.neutral => (
          const Color(0xFFF8FAFC),
          AppColors.gray700,
          AppColors.border
        ),
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;

  const _DetailMetricCard({
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.gray500,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  final AuditItem item;
  final bool isLast;

  const _TimelineEntry({required this.item, required this.isLast});

  String _formatDate(String raw) {
    final parsed = DateTime.tryParse(raw)?.toLocal();
    if (parsed == null) return raw;
    return DateFormat('dd/MM/yyyy · HH:mm').format(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Color(0xFF3B82F6),
                shape: BoxShape.circle,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 42,
                color: AppColors.border,
                margin: const EdgeInsets.symmetric(vertical: 4),
              ),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.action,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.gray800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.entity} · ${item.entityId}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.gray600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(item.createdAt),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.gray500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── User avatar ──────────────────────────────────────────────────────────────

class _UserAvatar extends StatelessWidget {
  final String name;
  final Color color;

  const _UserAvatar({required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      alignment: Alignment.center,
      child: Text(
        _userInitials(name),
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool hasFilter;
  final VoidCallback onClear;

  const _EmptyState({required this.hasFilter, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.gray100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasFilter ? Icons.search_off_rounded : Icons.people_outline_rounded,
              size: 32,
              color: AppColors.gray400,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            hasFilter
                ? 'Sin resultados para los filtros aplicados'
                : 'No hay usuarios registrados',
            style: TextStyle(
                color: AppColors.gray700,
                fontWeight: FontWeight.w500,
                fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            hasFilter ? 'Intenta con otros términos de búsqueda' : '',
            style: TextStyle(color: AppColors.gray500, fontSize: 12),
          ),
          if (hasFilter) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: onClear,
              child: const Text('Limpiar filtros'),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── User modal ───────────────────────────────────────────────────────────────

typedef _SaveFn = Future<void> Function(
    String? fullName, String role, String? projectId, String status);

class _UserModal extends StatefulWidget {
  final AdminUserItem user;
  final _SaveFn onSave;
  final int initialTab;
  final Future<List<AdminAssignmentItem>>? assignmentsFuture;

  const _UserModal({
    required this.user,
    required this.onSave,
    this.initialTab = 0,
    this.assignmentsFuture,
  });

  @override
  State<_UserModal> createState() => _UserModalState();
}

class _UserModalState extends State<_UserModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  late TextEditingController _nameCtrl;
  late TextEditingController _projectCtrl;
  late String _role;
  late String _status;
  bool _saving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this, initialIndex: widget.initialTab);
    _nameCtrl = TextEditingController(text: widget.user.fullName);
    _projectCtrl = TextEditingController(text: widget.user.projectId ?? '');
    _role = _kRoles.contains(widget.user.roleName)
        ? widget.user.roleName
        : 'OPERATIVO';
    _status = widget.user.status;
  }

  @override
  void dispose() {
    _tabs.dispose();
    _nameCtrl.dispose();
    _projectCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await widget.onSave(
        _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
        _role,
        _projectCtrl.text.trim().isEmpty ? null : _projectCtrl.text.trim(),
        _status,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _saveError = '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = _kRolePalette[widget.user.roleName.toUpperCase()];
    final roleColor = palette?.fg ?? AppColors.gray700;
    final roleBg = palette?.bg ?? AppColors.gray100;

    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      onKeyEvent: (e) {
        if (e is KeyDownEvent &&
            e.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.of(context).pop(false);
        }
      },
      child: Center(
        child: Material(
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          elevation: 32,
          shadowColor: Colors.black.withOpacity(0.15),
          child: SizedBox(
            width: 780,
            height: MediaQuery.of(context).size.height * 0.80,
            child: Column(
              children: [
                // ── Modal header ─────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 22, 16, 18),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border(
                        bottom: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    children: [
                      // Avatar — larger in header
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: roleBg,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: roleColor.withOpacity(0.25), width: 2),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _userInitials(widget.user.fullName),
                          style: TextStyle(
                              color: roleColor,
                              fontSize: 17,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  widget.user.fullName,
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.gray800),
                                ),
                                const SizedBox(width: 8),
                                _StatusBadge(widget.user.status),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(widget.user.email,
                                style: TextStyle(
                                    color: AppColors.gray500,
                                    fontSize: 13)),
                          ],
                        ),
                      ),
                      // Close button
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.gray100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () => Navigator.of(context).pop(false),
                          tooltip: 'Cerrar (ESC)',
                          color: AppColors.gray600,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                ),
                // ── Tabs ─────────────────────────────────────────────────
                Container(
                  color: AppColors.surface,
                  child: TabBar(
                    controller: _tabs,
                    labelColor: AppColors.gray800,
                    unselectedLabelColor: AppColors.gray500,
                    labelStyle: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                    unselectedLabelStyle: const TextStyle(fontSize: 13),
                    indicatorColor: AppColors.gray800,
                    indicatorWeight: 2,
                    tabs: const [
                      Tab(text: 'Perfil'),
                      Tab(text: 'Permisos'),
                      Tab(text: 'Actividad'),
                    ],
                  ),
                ),
                Divider(height: 1, color: AppColors.border),
                // ── Content ──────────────────────────────────────────────
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _buildPerfilTab(),
                      _buildPermisosTab(),
                      _buildActividadTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Perfil tab ─────────────────────────────────────────────────────────────

  Widget _buildPerfilTab() {
    return Container(
      color: AppColors.gray50,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Form card
            _ModalCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ModalSectionLabel('Información básica'),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _LabeledField(
                          label: 'Nombre completo',
                          child: TextField(
                            controller: _nameCtrl,
                            decoration: _inputDeco(
                                hint: widget.user.fullName,
                                icon: Icons.person_outline),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _LabeledField(
                          label: 'Correo electrónico',
                          child: TextField(
                            readOnly: true,
                            decoration: _inputDeco(
                              hint: widget.user.email,
                              icon: Icons.email_outlined,
                              filled: true,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _LabeledField(
                          label: 'Rol',
                          child: DropdownButtonFormField<String>(
                            value: _role,
                            items: _kRoles
                                .map((r) => DropdownMenuItem(
                                      value: r,
                                      child: _RoleBadge(r),
                                    ))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) setState(() => _role = v);
                            },
                            decoration: _inputDeco(icon: Icons.badge_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _LabeledField(
                          label: 'Proyecto',
                          child: TextField(
                            controller: _projectCtrl,
                            decoration: _inputDeco(
                                hint: 'TMQ (opcional)',
                                icon: Icons.folder_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _LabeledField(
                          label: 'Estado',
                          child: DropdownButtonFormField<String>(
                            value: _status,
                            items: const [
                              DropdownMenuItem(
                                  value: 'active', child: Text('Activo')),
                              DropdownMenuItem(
                                  value: 'inactive', child: Text('Inactivo')),
                              DropdownMenuItem(
                                  value: 'suspended',
                                  child: Text('Suspendido')),
                            ],
                            onChanged: (v) {
                              if (v != null) setState(() => _status = v);
                            },
                            decoration:
                                _inputDeco(icon: Icons.toggle_on_outlined),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_saveError != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: Color(0xFFDC2626), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_saveError!,
                          style: const TextStyle(
                              color: Color(0xFFDC2626), fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            // Actions bar
            Row(
              children: [
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Guardar cambios'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.gray800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 11),
                    textStyle: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.gray600,
                    side: BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 11),
                  ),
                  child: const Text('Cancelar'),
                ),
                const Spacer(),
                // Destructive — visually isolated
                OutlinedButton.icon(
                  onPressed: () => _confirmDelete(context),
                  icon: const Icon(Icons.delete_outline_rounded, size: 15),
                  label: const Text('Eliminar usuario'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 11),
                    textStyle: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Permisos tab ───────────────────────────────────────────────────────────

  Widget _buildPermisosTab() {
    final palette = _kRolePalette[widget.user.roleName.toUpperCase()];
    final roleColor = palette?.fg ?? AppColors.gray700;
    final roleBg = palette?.bg ?? AppColors.gray100;

    return Container(
      color: AppColors.gray50,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ModalCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _ModalSectionLabel('Permisos efectivos'),
                      const Spacer(),
                      OutlinedButton.icon(
                        onPressed: null,
                        icon: const Icon(Icons.add_rounded, size: 14),
                        label: const Text('Agregar'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.gray600,
                          side: BorderSide(color: AppColors.border),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: roleBg,
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: roleColor.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.shield_outlined,
                            size: 16, color: roleColor),
                        const SizedBox(width: 8),
                        _RoleBadge(widget.user.roleName),
                        const SizedBox(width: 8),
                        Text('Permisos heredados del rol',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.gray600)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Column(
                      children: [
                        Icon(Icons.security_outlined,
                            size: 40, color: AppColors.gray300),
                        const SizedBox(height: 10),
                        Text('Gestión de permisos disponible próximamente',
                            style: TextStyle(
                                color: AppColors.gray500, fontSize: 13)),
                      ],
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

  // ── Actividad tab ──────────────────────────────────────────────────────────

  Widget _buildActividadTab() {
    return Container(
      color: AppColors.gray50,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: _ModalCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ModalSectionLabel('Actividades asignadas'),
              const SizedBox(height: 20),
              FutureBuilder<List<AdminAssignmentItem>>(
                future: widget.assignmentsFuture,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snap.hasError) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Error al cargar actividades: ${snap.error}',
                        style: const TextStyle(
                            color: Color(0xFFEF4444), fontSize: 12),
                      ),
                    );
                  }
                  final items = snap.data ?? const [];
                  if (items.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: const BoxDecoration(
                              color: AppColors.gray100,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.task_alt_rounded,
                                size: 30, color: AppColors.gray400),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Sin actividades asignadas',
                            style: TextStyle(
                              color: AppColors.gray700,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Las actividades aparecerán aquí cuando sean asignadas al usuario.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: AppColors.gray500, fontSize: 12),
                          ),
                        ],
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final item in items)
                        _AssignmentCard(item: item),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar usuario'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Eliminar permanentemente a ${widget.user.fullName}?'),
            const SizedBox(height: 8),
            Text(widget.user.email,
                style: TextStyle(color: AppColors.gray500, fontSize: 13)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Color(0xFFDC2626), size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Esta acción no se puede deshacer.',
                        style: TextStyle(
                            color: Color(0xFFDC2626), fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626)),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Eliminación no implementada en esta versión')),
      );
      if (mounted) Navigator.of(context).pop(false);
    }
  }
}

// ─── Modal helpers ────────────────────────────────────────────────────────────

class _ModalCard extends StatelessWidget {
  final Widget child;

  const _ModalCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _ModalSectionLabel extends StatelessWidget {
  final String text;
  const _ModalSectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.gray700));
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;

  const _LabeledField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.gray500,
                letterSpacing: 0.3)),
        const SizedBox(height: 5),
        child,
      ],
    );
  }
}

InputDecoration _inputDeco({
  String? hint,
  IconData? icon,
  bool filled = false,
}) {
  return InputDecoration(
    hintText: hint,
    prefixIcon: icon != null ? Icon(icon, size: 16) : null,
    isDense: true,
    filled: filled,
    fillColor: filled ? AppColors.gray50 : null,
    contentPadding:
        const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: AppColors.gray700, width: 1.5),
    ),
  );
}

// ─── Shared form helper ───────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData? icon;
  final String? hint;
  final TextInputType? keyboard;

  const _Field(
      {required this.ctrl,
      required this.label,
      this.icon,
      this.hint,
      this.keyboard});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      decoration: _inputDeco(hint: hint ?? label, icon: icon),
    );
  }
}

// ─── Shared badges ────────────────────────────────────────────────────────────

class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge(this.role);

  @override
  Widget build(BuildContext context) {
    final palette = _kRolePalette[role.toUpperCase()];
    final bg = palette?.bg ?? AppColors.gray100;
    final fg = palette?.fg ?? AppColors.gray600;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withOpacity(0.14)),
      ),
      child: Text(
        role.toUpperCase(),
        style: TextStyle(
            color: fg,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    final p = _kStatusPalette[status.toLowerCase()] ??
        (
          label: status,
          bg: AppColors.gray100,
          fg: AppColors.gray500,
          icon: Icons.help_outline,
        );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.fg.withOpacity(0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(p.icon, size: 12, color: p.fg),
          const SizedBox(width: 4),
          Text(p.label,
              style: TextStyle(
                  color: p.fg,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ProjectChip extends StatelessWidget {
  final AdminUserItem user;
  const _ProjectChip(this.user);

  @override
  Widget build(BuildContext context) {
    final id = user.projectId;
    if (id != null && id.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFDBEAFE),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF93C5FD)),
        ),
        child: Text(id,
            style: const TextStyle(
                color: Color(0xFF1D4ED8),
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      );
    }
    if (user.roleName.toUpperCase() == 'ADMIN') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFEDE9FE),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFC4B5FD)),
        ),
        child: const Text('Todos',
            style: TextStyle(
                color: Color(0xFF6D28D9),
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      );
    }
    return Text('Sin asignar',
        style: TextStyle(color: AppColors.gray400, fontSize: 12));
  }
}

// ─── Assignment card ───────────────────────────────────────────────────────────

class _AssignmentCard extends StatelessWidget {
  final AdminAssignmentItem item;
  const _AssignmentCard({required this.item});

  Color get _statusColor {
    switch (item.status.toUpperCase()) {
      case 'PROGRAMADA':
      case 'PENDIENTE':
        return const Color(0xFFF59E0B);
      case 'INICIADA':
      case 'EN_CAMPO':
        return const Color(0xFF3B82F6);
      case 'EN_VALIDACION':
        return const Color(0xFF8B5CF6);
      case 'TERMINADA':
      case 'APROBADO':
        return const Color(0xFF10B981);
      case 'RECHAZADA':
        return const Color(0xFFEF4444);
      default:
        return AppColors.gray400;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy', 'es');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 48,
            decoration: BoxDecoration(
              color: _statusColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title.isNotEmpty ? item.title : item.id,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.gray800),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (item.frente != null && item.frente!.isNotEmpty) ...[
                      Icon(Icons.route_rounded,
                          size: 12, color: AppColors.gray500),
                      const SizedBox(width: 4),
                      Text(item.frente!,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.gray500)),
                      const SizedBox(width: 10),
                    ],
                    Icon(Icons.calendar_today_rounded,
                        size: 12, color: AppColors.gray500),
                    const SizedBox(width: 4),
                    Text(fmt.format(item.startAt),
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.gray500)),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              item.status,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _statusColor),
            ),
          ),
        ],
      ),
    );
  }
}
