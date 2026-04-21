import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/backend_api_client.dart';

const _kFallbackCalendarId =
    '7874f5cb85c43eba5ba24e8b710c1b2fac0d8f64106f0cdfddb6bb14441bc151'
    '@group.calendar.google.com';

// ── Read provider ──────────────────────────────────────────────────────────

/// Provides the Google Calendar ID configured by the admin.
/// Falls back to the hardcoded default if the backend is unreachable.
final systemCalendarIdProvider = FutureProvider<String>((ref) async {
  try {
    final client = const BackendApiClient();
    final data = await client.getJson('/v1/system/config') as Map<String, dynamic>;
    final id = (data['google_calendar_id'] as String?)?.trim() ?? '';
    return id.isNotEmpty ? id : _kFallbackCalendarId;
  } catch (_) {
    return _kFallbackCalendarId;
  }
});

// ── Write service ──────────────────────────────────────────────────────────

class SystemConfigService {
  const SystemConfigService();

  Future<String> getCalendarId() async {
    try {
      final client = const BackendApiClient();
      final data = await client.getJson('/v1/system/config') as Map<String, dynamic>;
      final id = (data['google_calendar_id'] as String?)?.trim() ?? '';
      return id.isNotEmpty ? id : _kFallbackCalendarId;
    } catch (_) {
      return _kFallbackCalendarId;
    }
  }

  /// Returns the new calendar ID on success. Throws on failure.
  Future<String> updateCalendarId(String calendarId) async {
    final client = const BackendApiClient();
    final data = await client.putJson(
      '/v1/system/config',
      {'google_calendar_id': calendarId.trim()},
    ) as Map<String, dynamic>;
    return (data['google_calendar_id'] as String?) ?? calendarId;
  }
}

final systemConfigServiceProvider = Provider<SystemConfigService>(
  (_) => const SystemConfigService(),
);
