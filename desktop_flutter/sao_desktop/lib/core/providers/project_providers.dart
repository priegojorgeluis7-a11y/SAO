import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../data/repositories/backend_api_client.dart';

// ---------------------------------------------------------------------------
// Projects list
// ---------------------------------------------------------------------------

/// Loads project IDs from GET /api/v1/projects. Empty list on error.
final availableProjectsProvider =
    FutureProvider.autoDispose<List<String>>((ref) async {
  const client = BackendApiClient();
  final decoded = await client.getJson('/api/v1/projects');
  if (decoded is! List) return const [];
  return decoded
      .whereType<Map<String, dynamic>>()
      .map((p) => (p['id'] ?? p['project_id'] ?? '').toString())
      .where((id) => id.isNotEmpty)
      .toList();
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
