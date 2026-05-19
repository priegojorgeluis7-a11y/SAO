// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../auth/session_controller.dart';
import '../data/admin_repositories.dart';

// ─── State badge palettes ────────────────────────────────────────────────────

const _kStatePalette = {
  'PENDIENTE': (bg: Color(0xFFFEF9C3), fg: Color(0xFF92400E), label: 'Pendiente'),
  'EN_CURSO': (bg: Color(0xFFDBEAFE), fg: Color(0xFF1D4ED8), label: 'En curso'),
  'COMPLETADA': (bg: Color(0xFFD1FAE5), fg: Color(0xFF065F46), label: 'Completada'),
  'REVISION_PENDIENTE': (bg: Color(0xFFEDE9FE), fg: Color(0xFF6D28D9), label: 'En revisión'),
  'CANCELADA': (bg: Color(0xFFF1F5F9), fg: Color(0xFF475569), label: 'Cancelada'),
};

// ─── Page ────────────────────────────────────────────────────────────────────

class AdminSyncIssuesPage extends ConsumerStatefulWidget {
  const AdminSyncIssuesPage({super.key});

  @override
  ConsumerState<AdminSyncIssuesPage> createState() =>
      _AdminSyncIssuesPageState();
}

class _AdminSyncIssuesPageState extends ConsumerState<AdminSyncIssuesPage> {
  // ── Search state ─────────────────────────────────────────────────────
  List<AdminUserItem> _users = const [];
  bool _loadingUsers = true;

  AdminUserItem? _selectedUser;
  String _projectFilter = '';
  final _userSearchCtrl = TextEditingController();
  String _userSearch = '';

  // ── Activity list state ──────────────────────────────────────────────
  List<AdminActivityItem> _activities = const [];
  bool _loadingActivities = false;
  String? _activitiesError;
  bool _showOnlyStuck = false;

  // ── Sort ─────────────────────────────────────────────────────────────
  bool _sortByState = false;

  // ── Selected for bulk ops ────────────────────────────────────────────
  final Set<String> _selected = {};

  // ── Push notification ────────────────────────────────────────────────
  bool _pushLoading = false;
  String? _pushResult;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadUsers);
  }

  @override
  void dispose() {
    _userSearchCtrl.dispose();
    super.dispose();
  }

  String? get _token => ref.read(sessionControllerProvider).accessToken;

  // ─── Loaders ─────────────────────────────────────────────────────────

  Future<void> _loadUsers() async {
    final token = _token;
    if (token == null) return;
    try {
      final data = await ref.read(usersRepositoryProvider).list(token);
      if (!mounted) return;
      setState(() {
        _users = data;
        _loadingUsers = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingUsers = false);
    }
  }

  Future<void> _loadActivities() async {
    final user = _selectedUser;
    if (user == null) return;
    final token = _token;
    if (token == null) return;

    setState(() {
      _loadingActivities = true;
      _activitiesError = null;
      _activities = const [];
      _selected.clear();
      _pushResult = null;
    });

    try {
      final items = await ref.read(syncIssuesRepositoryProvider).listUserActivities(
            token,
            userId: user.id,
            projectId: _projectFilter.trim().isEmpty ? null : _projectFilter.trim(),
          );
      if (!mounted) return;
      setState(() {
        _activities = items;
        _loadingActivities = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingActivities = false;
        _activitiesError = '$e';
      });
    }
  }

  // ─── Actions ─────────────────────────────────────────────────────────

  Future<void> _deleteSelected() async {
    if (_selected.isEmpty) return;
    final count = _selected.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text(
          'Se eliminarán $count actividad${count == 1 ? '' : 'es'} del servidor.\n'
          'Esta acción es reversible sólo manualmente en Firestore.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final token = _token;
    if (token == null) return;
    final repo = ref.read(syncIssuesRepositoryProvider);
    int deleted = 0;
    int failed = 0;
    for (final uuid in List.of(_selected)) {
      try {
        await repo.deleteActivity(token, uuid);
        deleted++;
      } catch (_) {
        failed++;
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        failed == 0
            ? 'Se eliminaron $deleted actividad${deleted == 1 ? '' : 'es'}'
            : 'Eliminadas: $deleted, fallidas: $failed',
      ),
      backgroundColor: failed == 0 ? AppColors.success : AppColors.warning,
    ));
    await _loadActivities();
  }

  Future<void> _sendPush() async {
    final user = _selectedUser;
    if (user == null) return;
    final token = _token;
    if (token == null) return;

    setState(() {
      _pushLoading = true;
      _pushResult = null;
    });

    try {
      final result = await ref.read(syncIssuesRepositoryProvider).pushUser(
            token,
            userId: user.id,
            title: 'Sincronización requerida',
            body: 'Abre la app y presiona Sincronizar para actualizar tus actividades.',
            type: 'activity_update',
            projectId: _projectFilter.trim().isEmpty ? null : _projectFilter.trim(),
          );
      if (!mounted) return;
      final sent = result['sent'] ?? result['result']?['sent'] ?? '?';
      setState(() {
        _pushLoading = false;
        _pushResult = 'Push enviado — dispositivos notificados: $sent';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pushLoading = false;
        _pushResult = 'Error al enviar push: $e';
      });
    }
  }

  // ─── Filtered / sorted list ──────────────────────────────────────────

  List<AdminActivityItem> get _displayed {
    var list = _showOnlyStuck
        ? _activities.where((a) => a.isStuck).toList()
        : List.of(_activities);
    if (_sortByState) {
      list.sort((a, b) => a.executionState.compareTo(b.executionState));
    } else {
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }
    return list;
  }

  int get _stuckCount => _activities.where((a) => a.isStuck).length;

  List<AdminUserItem> get _filteredUsers {
    if (_userSearch.isEmpty) return _users;
    final q = _userSearch.toLowerCase();
    return _users.where((u) =>
        u.fullName.toLowerCase().contains(q) ||
        u.email.toLowerCase().contains(q) ||
        (u.projectId ?? '').toLowerCase().contains(q)).toList();
  }

  // ─── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.scaffoldBackgroundFor(context),
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Left: user search panel ────────────────────────────────
          SizedBox(
            width: 300,
            child: _UserPanel(
              loading: _loadingUsers,
              users: _filteredUsers,
              selected: _selectedUser,
              searchCtrl: _userSearchCtrl,
              onSearch: (v) => setState(() => _userSearch = v),
              onSelect: (user) {
                setState(() {
                  _selectedUser = user;
                  _activities = const [];
                  _selected.clear();
                  _pushResult = null;
                });
                _loadActivities();
              },
            ),
          ),
          const SizedBox(width: 16),

          // ── Right: activity manager ────────────────────────────────
          Expanded(
            child: _selectedUser == null
                ? const _EmptySelection()
                : _ActivityPanel(
                    user: _selectedUser!,
                    activities: _displayed,
                    allCount: _activities.length,
                    stuckCount: _stuckCount,
                    loading: _loadingActivities,
                    error: _activitiesError,
                    selected: _selected,
                    projectFilter: _projectFilter,
                    showOnlyStuck: _showOnlyStuck,
                    pushLoading: _pushLoading,
                    pushResult: _pushResult,
                    onProjectFilterChanged: (v) {
                      setState(() => _projectFilter = v);
                      _loadActivities();
                    },
                    onToggleStuck: () =>
                        setState(() => _showOnlyStuck = !_showOnlyStuck),
                    onToggleSort: () =>
                        setState(() => _sortByState = !_sortByState),
                    onToggleSelect: (uuid) {
                      setState(() {
                        if (_selected.contains(uuid)) {
                          _selected.remove(uuid);
                        } else {
                          _selected.add(uuid);
                        }
                      });
                    },
                    onSelectAll: () {
                      setState(() {
                        if (_selected.length == _displayed.length) {
                          _selected.clear();
                        } else {
                          _selected
                            ..clear()
                            ..addAll(_displayed.map((a) => a.uuid));
                        }
                      });
                    },
                    onDeleteSelected: _deleteSelected,
                    onSendPush: _sendPush,
                    onRefresh: _loadActivities,
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── User selection panel ─────────────────────────────────────────────────────

class _UserPanel extends StatelessWidget {
  final bool loading;
  final List<AdminUserItem> users;
  final AdminUserItem? selected;
  final TextEditingController searchCtrl;
  final ValueChanged<String> onSearch;
  final ValueChanged<AdminUserItem> onSelect;

  const _UserPanel({
    required this.loading,
    required this.users,
    required this.selected,
    required this.searchCtrl,
    required this.onSearch,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceFor(context),
        border: Border.all(color: AppColors.borderFor(context)),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Text(
              'Selecciona un usuario',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppColors.textFor(context),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: TextField(
              controller: searchCtrl,
              onChanged: onSearch,
              style:
                  TextStyle(fontSize: 13, color: AppColors.textFor(context)),
              decoration: InputDecoration(
                hintText: 'Nombre o correo…',
                hintStyle: TextStyle(
                    color: AppColors.textMutedFor(context), fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded,
                    size: 18, color: AppColors.gray400),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.borderFor(context)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.borderFor(context)),
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : users.isEmpty
                    ? Center(
                        child: Text(
                          'Sin resultados',
                          style: TextStyle(
                              color: AppColors.textMutedFor(context),
                              fontSize: 13),
                        ),
                      )
                    : ListView.builder(
                        itemCount: users.length,
                        itemBuilder: (_, i) {
                          final u = users[i];
                          final isSelected = selected?.id == u.id;
                          return InkWell(
                            onTap: () => onSelect(u),
                            child: Container(
                              color: isSelected
                                  ? AppColors.primary.withValues(alpha: 0.08)
                                  : null,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 9),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 15,
                                    backgroundColor: isSelected
                                        ? AppColors.primary
                                        : AppColors.gray200,
                                    child: Text(
                                      _initials(u.fullName),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? Colors.white
                                            : AppColors.gray600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          u.fullName,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: isSelected
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                            color: AppColors.textFor(context),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          u.email,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color:
                                                AppColors.textMutedFor(context),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (u.projectId != null &&
                                      u.projectId!.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.gray100,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        u.projectId!,
                                        style: const TextStyle(
                                            fontSize: 10,
                                            color: AppColors.gray600),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

// ─── Activity panel ───────────────────────────────────────────────────────────

class _ActivityPanel extends StatelessWidget {
  final AdminUserItem user;
  final List<AdminActivityItem> activities;
  final int allCount;
  final int stuckCount;
  final bool loading;
  final String? error;
  final Set<String> selected;
  final String projectFilter;
  final bool showOnlyStuck;
  final bool pushLoading;
  final String? pushResult;
  final ValueChanged<String> onProjectFilterChanged;
  final VoidCallback onToggleStuck;
  final VoidCallback onToggleSort;
  final ValueChanged<String> onToggleSelect;
  final VoidCallback onSelectAll;
  final VoidCallback onDeleteSelected;
  final VoidCallback onSendPush;
  final VoidCallback onRefresh;

  const _ActivityPanel({
    required this.user,
    required this.activities,
    required this.allCount,
    required this.stuckCount,
    required this.loading,
    required this.error,
    required this.selected,
    required this.projectFilter,
    required this.showOnlyStuck,
    required this.pushLoading,
    required this.pushResult,
    required this.onProjectFilterChanged,
    required this.onToggleStuck,
    required this.onToggleSort,
    required this.onToggleSelect,
    required this.onSelectAll,
    required this.onDeleteSelected,
    required this.onSendPush,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yy HH:mm');

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceFor(context),
        border: Border.all(color: AppColors.borderFor(context)),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.fullName,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AppColors.textFor(context),
                            ),
                          ),
                          Text(
                            user.email,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMutedFor(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Project filter chip
                    _ProjectFilterField(
                      value: projectFilter,
                      onChanged: onProjectFilterChanged,
                    ),
                    const SizedBox(width: 8),
                    // Refresh
                    IconButton(
                      tooltip: 'Recargar',
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      onPressed: onRefresh,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // ── Stat chips + action bar ──────────────────────────
                Row(
                  children: [
                    _StatChip(
                      label: 'Total',
                      count: allCount,
                      active: !showOnlyStuck,
                      onTap: showOnlyStuck ? onToggleStuck : null,
                    ),
                    const SizedBox(width: 6),
                    _StatChip(
                      label: 'Sin llenar',
                      count: stuckCount,
                      color: stuckCount > 0 ? AppColors.warning : null,
                      active: showOnlyStuck,
                      onTap: onToggleStuck,
                    ),
                    const Spacer(),
                    if (selected.isNotEmpty) ...[
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          textStyle: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        icon: const Icon(Icons.delete_outline_rounded,
                            size: 16),
                        label: Text(
                            'Eliminar ${selected.length} seleccionada${selected.length == 1 ? '' : 's'}'),
                        onPressed: onDeleteSelected,
                      ),
                      const SizedBox(width: 8),
                    ],
                    // Push notification button
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.gray800,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        textStyle: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      icon: pushLoading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send_to_mobile_rounded,
                              size: 16),
                      label: const Text('Forzar sync'),
                      onPressed: pushLoading ? null : onSendPush,
                    ),
                  ],
                ),
                if (pushResult != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    pushResult!,
                    style: TextStyle(
                      fontSize: 12,
                      color: pushResult!.startsWith('Error')
                          ? AppColors.error
                          : AppColors.success,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),

          // ── Table header ─────────────────────────────────────────
          Container(
            color: AppColors.gray50,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: Checkbox(
                    tristate: true,
                    value: selected.isEmpty
                        ? false
                        : selected.length == activities.length
                            ? true
                            : null,
                    onChanged: (_) => onSelectAll(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: Text('Actividad',
                      style: _headerStyle(context)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Tipo',
                      style: _headerStyle(context)),
                ),
                SizedBox(
                  width: 110,
                  child: Text('Estado',
                      style: _headerStyle(context)),
                ),
                SizedBox(
                  width: 80,
                  child: Text('Sync v',
                      style: _headerStyle(context)),
                ),
                SizedBox(
                  width: 120,
                  child: Text('Actualizado',
                      style: _headerStyle(context)),
                ),
                SizedBox(
                  width: 70,
                  child: Text('Datos',
                      style: _headerStyle(context)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── Body ─────────────────────────────────────────────────
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                    ? _ErrorState(
                        message: error!,
                        onRetry: onRefresh,
                      )
                    : activities.isEmpty
                        ? Center(
                            child: Text(
                              allCount == 0
                                  ? 'No hay actividades en el servidor para este usuario'
                                  : 'No hay actividades problemáticas',
                              style: TextStyle(
                                  color: AppColors.textMutedFor(context),
                                  fontSize: 13),
                            ),
                          )
                        : ListView.separated(
                            itemCount: activities.length,
                            separatorBuilder: (_, __) => Divider(
                                height: 1,
                                color: AppColors.borderFor(context)),
                            itemBuilder: (_, i) {
                              final a = activities[i];
                              final isSelected = selected.contains(a.uuid);
                              final palette = _kStatePalette[a.executionState
                                      .toUpperCase()] ??
                                  (
                                    bg: AppColors.gray100,
                                    fg: AppColors.gray600,
                                    label: a.executionState,
                                  );
                              return InkWell(
                                onTap: () => onToggleSelect(a.uuid),
                                child: Container(
                                  color: isSelected
                                      ? AppColors.primary.withValues(alpha: 0.06)
                                      : a.isStuck
                                          ? const Color(0xFFFFFBEB)
                                          : null,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 9),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 24,
                                        child: Checkbox(
                                          value: isSelected,
                                          onChanged: (_) =>
                                              onToggleSelect(a.uuid),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 3,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              a.title.isNotEmpty
                                                  ? a.title
                                                  : 'Sin título',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                                color:
                                                    AppColors.textFor(context),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Row(
                                              children: [
                                                SelectableText(
                                                  a.uuid.substring(0, 8),
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontFamily: 'monospace',
                                                    color: AppColors
                                                        .textMutedFor(context),
                                                  ),
                                                ),
                                                if (a.pkStart != null) ...[
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    'PK ${a.pkStart}${a.pkEnd != null ? '–${a.pkEnd}' : ''}',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: AppColors
                                                          .textMutedFor(
                                                              context),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          a.activityTypeCode,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textFor(context),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      SizedBox(
                                        width: 110,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 7, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: palette.bg,
                                            borderRadius:
                                                BorderRadius.circular(5),
                                          ),
                                          child: Text(
                                            palette.label,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: palette.fg,
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 80,
                                        child: Text(
                                          'v${a.syncVersion}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color:
                                                AppColors.textMutedFor(context),
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 120,
                                        child: Text(
                                          dateFormat.format(a.updatedAt),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color:
                                                AppColors.textMutedFor(context),
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 70,
                                        child: a.hasWizardPayload
                                            ? const Row(
                                                children: [
                                                  Icon(
                                                    Icons.check_circle_rounded,
                                                    size: 14,
                                                    color: AppColors.success,
                                                  ),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    'Llena',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: AppColors.success,
                                                    ),
                                                  ),
                                                ],
                                              )
                                            : const Row(
                                                children: [
                                                  Icon(
                                                    Icons
                                                        .warning_amber_rounded,
                                                    size: 14,
                                                    color: AppColors.warning,
                                                  ),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    'Vacía',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: AppColors.warning,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  TextStyle _headerStyle(BuildContext context) => TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.textMutedFor(context),
        letterSpacing: 0.4,
      );
}

// ─── Project filter field ─────────────────────────────────────────────────────

class _ProjectFilterField extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _ProjectFilterField({required this.value, required this.onChanged});

  @override
  State<_ProjectFilterField> createState() => _ProjectFilterFieldState();
}

class _ProjectFilterFieldState extends State<_ProjectFilterField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      child: TextField(
        controller: _ctrl,
        onSubmitted: (v) => widget.onChanged(v.trim().toUpperCase()),
        textCapitalization: TextCapitalization.characters,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Proyecto',
          hintStyle: TextStyle(
              color: AppColors.textMutedFor(context), fontSize: 13),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppColors.borderFor(context)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppColors.borderFor(context)),
          ),
          suffixIcon: widget.value.isNotEmpty
              ? IconButton(
                  iconSize: 14,
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    _ctrl.clear();
                    widget.onChanged('');
                  },
                )
              : null,
        ),
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label;
  final int count;
  final bool active;
  final Color? color;
  final VoidCallback? onTap;

  const _StatChip({
    required this.label,
    required this.count,
    this.active = false,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = active
        ? (color ?? AppColors.primary).withValues(alpha: 0.12)
        : AppColors.gray100;
    final fg = active ? (color ?? AppColors.primary) : AppColors.gray600;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: active
              ? Border.all(color: (color ?? AppColors.primary).withValues(alpha: 0.3))
              : null,
        ),
        child: Text(
          '$label  $count',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: fg,
          ),
        ),
      ),
    );
  }
}

class _EmptySelection extends StatelessWidget {
  const _EmptySelection();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.manage_search_rounded,
              size: 52,
              color: AppColors.textMutedFor(context).withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(
            'Selecciona un usuario para ver\nsus actividades en el servidor',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textMutedFor(context),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 42, color: AppColors.error),
          const SizedBox(height: 10),
          Text(message,
              style: const TextStyle(color: AppColors.gray600, fontSize: 13),
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(
              onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}
