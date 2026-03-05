import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/backend_api_client.dart';

// ---------------------------------------------------------------------------
// Projects list — loaded from backend, no hardcoded fallback
// ---------------------------------------------------------------------------

/// Loads the list of project IDs the user has access to from GET /api/v1/projects.
/// Returns an empty list on error (caller decides how to handle).
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
// Active project — set by login flow or user selection
// ---------------------------------------------------------------------------

/// The currently selected project ID.
/// Initialized to empty; set when [availableProjectsProvider] resolves
/// (auto-selects first project) or when the user explicitly changes it.
final activeProjectIdProvider = StateProvider<String>((ref) => '');
