import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../data/repositories/backend_api_client.dart';
import '../../features/auth/app_session_controller.dart';

// ---------------------------------------------------------------------------
// Projects list
// ---------------------------------------------------------------------------

final backendApiClientProvider = Provider<BackendApiClient>(
  (_) => const BackendApiClient(),
);

List<String> parseAvailableProjectIds(dynamic decoded) {
  final projectIds = <String>[];

  void addProjectId(dynamic rawValue) {
    final normalized = (rawValue ?? '').toString().trim().toUpperCase();
    if (normalized.isEmpty || projectIds.contains(normalized)) {
      return;
    }
    projectIds.add(normalized);
  }

  if (decoded is List) {
    for (final item in decoded.whereType<Map<String, dynamic>>()) {
      addProjectId(item['id'] ?? item['project_id'] ?? item['code']);
    }
    return projectIds;
  }

  if (decoded is Map<String, dynamic>) {
    final nested =
        decoded['projects'] ?? decoded['items'] ?? decoded['results'] ?? decoded['data'];
    if (nested != null) {
      return parseAvailableProjectIds(nested);
    }
    addProjectId(decoded['id'] ?? decoded['project_id'] ?? decoded['code']);
  }

  return projectIds;
}

List<String> _scopedProjectIdsForUser(AppUser? user) {
  if (user == null || user.isAdmin) return const <String>[];
  final ids = <String>{
    for (final scope in user.permissionScopes)
      if (scope.effect != 'deny' && (scope.projectId ?? '').trim().isNotEmpty)
        scope.projectId!.trim().toUpperCase(),
  }.toList()
    ..sort();
  return ids;
}

List<String> _restrictProjectsToUser(
  List<String> projectIds,
  AppUser? user,
) {
  if (user == null || user.isAdmin) {
    return projectIds;
  }
  final scopedProjectIds = _scopedProjectIdsForUser(user);
  if (scopedProjectIds.isEmpty) {
    return projectIds;
  }
  final allowed = projectIds
      .where((projectId) => scopedProjectIds.contains(projectId))
      .toList();
  return allowed.isNotEmpty ? allowed : scopedProjectIds;
}

/// Loads project IDs from the user-scoped endpoint and falls back to the
/// admin listing endpoint only for administrators. Returns an empty list on error.
final availableProjectsProvider =
    FutureProvider.autoDispose<List<String>>((ref) async {
  final client = ref.read(backendApiClientProvider);
  final currentUser = ref.watch(currentAppUserProvider);

  try {
    final decoded = await client.getJson('/api/v1/me/projects');
    final scopedProjects = _restrictProjectsToUser(
      parseAvailableProjectIds(decoded),
      currentUser,
    );
    if (scopedProjects.isNotEmpty) {
      return scopedProjects;
    }
  } catch (_) {
    // For non-admin users, prefer session-scoped project IDs over broad fallbacks.
  }

  final sessionScopedProjects = _scopedProjectIdsForUser(currentUser);
  if (sessionScopedProjects.isNotEmpty) {
    return sessionScopedProjects;
  }

  if (currentUser != null && !currentUser.isAdmin) {
    return const <String>[];
  }

  try {
    final decoded = await client.getJson('/api/v1/projects');
    return parseAvailableProjectIds(decoded);
  } catch (_) {
    return const <String>[];
  }
});

// ---------------------------------------------------------------------------
// Active project — persisted across sessions via secure storage
// ---------------------------------------------------------------------------

const _kProjectKey = 'sao_active_project_id';
const _storage = FlutterSecureStorage();

class _ActiveProjectNotifier extends StateNotifier<String> {
  _ActiveProjectNotifier() : super('') {
    _load();
  }

  Future<void> _load() async {
    try {
      final saved = await _storage.read(key: _kProjectKey);
      if (!mounted) return;
      final normalized = _normalizeProjectId(saved);
      if (normalized.isNotEmpty) {
        state = normalized;
      }
    } catch (_) {
      // Ignore read errors — stays empty
    }
  }

  void select(String projectId) {
    final normalized = _normalizeProjectId(projectId);
    if (normalized == state) return;
    state = normalized;
    if (normalized.isEmpty) {
      _storage.delete(key: _kProjectKey).ignore();
    } else {
      _storage.write(key: _kProjectKey, value: normalized).ignore();
    }
  }

  String _normalizeProjectId(String? projectId) {
    final value = (projectId ?? '').trim().toUpperCase();
    if (value.isEmpty || value == 'ALL' || value == 'TODOS') {
      return '';
    }
    return value;
  }
}

final activeProjectIdProvider =
    StateNotifierProvider<_ActiveProjectNotifier, String>(
  (_) => _ActiveProjectNotifier(),
);
