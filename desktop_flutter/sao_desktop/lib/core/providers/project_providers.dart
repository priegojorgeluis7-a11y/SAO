import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../data/repositories/backend_api_client.dart';

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

/// Loads project IDs from the user-scoped endpoint and falls back to the
/// admin listing endpoint when needed. Returns an empty list on error.
final availableProjectsProvider =
    FutureProvider.autoDispose<List<String>>((ref) async {
  final client = ref.read(backendApiClientProvider);

  try {
    final decoded = await client.getJson('/api/v1/me/projects');
    final scopedProjects = parseAvailableProjectIds(decoded);
    if (scopedProjects.isNotEmpty) {
      return scopedProjects;
    }
  } catch (_) {
    // Fallback for admin-only screens or legacy backend contracts.
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
