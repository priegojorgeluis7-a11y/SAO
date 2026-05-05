import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../core/network/api_client.dart';
import '../../../ui/theme/sao_colors.dart';
import '../../../ui/widgets/special/sao_role_badge.dart';

class _OnlineUserItem {
  const _OnlineUserItem({
    required this.id,
    required this.fullName,
    required this.email,
    required this.roleName,
    required this.projectIds,
    required this.isOnline,
    required this.lastActivityAt,
  });

  final String id;
  final String fullName;
  final String email;
  final String roleName;
  final List<String> projectIds;
  final bool isOnline;
  final DateTime? lastActivityAt;

  factory _OnlineUserItem.fromJson(Map<String, dynamic> json) {
    return _OnlineUserItem(
      id: (json['id'] ?? '').toString(),
      fullName: (json['full_name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      roleName: (json['role_name'] ?? '').toString(),
      projectIds: ((json['project_ids'] as List?) ?? const <dynamic>[])
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList(),
      isOnline: json['is_online'] == true,
      lastActivityAt: DateTime.tryParse((json['last_activity_at'] ?? '').toString()),
    );
  }
}

class AdminOnlineUsersPage extends StatefulWidget {
  const AdminOnlineUsersPage({super.key});

  @override
  State<AdminOnlineUsersPage> createState() => _AdminOnlineUsersPageState();
}

class _AdminOnlineUsersPageState extends State<AdminOnlineUsersPage> {
  final ApiClient _apiClient = GetIt.I<ApiClient>();
  bool _loading = true;
  String? _error;
  List<_OnlineUserItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await _apiClient.get<dynamic>('/users/online');
      final raw = response.data;
      final rows = raw is List ? raw : const <dynamic>[];
      final items = rows
          .whereType<Map<Object?, Object?>>()
          .map((row) => _OnlineUserItem.fromJson(Map<String, dynamic>.from(row)))
          .toList();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No se pudo cargar la presencia de usuarios.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SaoColors.gray50,
      appBar: AppBar(
        title: const Text('Usuarios en línea'),
        backgroundColor: SaoColors.surface,
        surfaceTintColor: SaoColors.surface,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: SaoColors.error),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: SaoColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: SaoColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: item.isOnline
                                        ? SaoColors.success
                                        : SaoColors.gray400,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    item.fullName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                SaoRoleBadge(role: item.roleName),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(item.email),
                            const SizedBox(height: 6),
                            Text(
                              item.projectIds.isEmpty
                                  ? 'Sin proyectos'
                                  : 'Proyectos: ${item.projectIds.join(', ')}',
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item.isOnline
                                  ? 'En línea ahora'
                                  : 'Última actividad: ${_formatLastActivity(item.lastActivityAt)}',
                              style: TextStyle(
                                color: item.isOnline
                                    ? SaoColors.success
                                    : SaoColors.gray600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  String _formatLastActivity(DateTime? value) {
    if (value == null) return 'sin registro';
    final diff = DateTime.now().difference(value.toLocal());
    if (diff.inMinutes < 1) {
      return 'hace unos segundos';
    }
    if (diff.inMinutes < 60) {
      return 'hace ${diff.inMinutes} min';
    }
    if (diff.inHours < 24) {
      return 'hace ${diff.inHours} h';
    }
    return 'hace ${diff.inDays} d';
  }
}