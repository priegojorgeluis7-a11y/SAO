import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/backend_api_client.dart';

const _kFallbackCalendarId =
    '7874f5cb85c43eba5ba24e8b710c1b2fac0d8f64106f0cdfddb6bb14441bc151'
    '@group.calendar.google.com';

// ── Read providers ─────────────────────────────────────────────────────────

/// Provides the global Google Calendar ID configured by the admin.
/// Falls back to the hardcoded default if the backend is unreachable.
final systemCalendarIdProvider = FutureProvider<String>((ref) async {
  try {
    const client = BackendApiClient();
    final data = await client.getJson('/v1/system/config') as Map<String, dynamic>;
    final id = (data['google_calendar_id'] as String?)?.trim() ?? '';
    return id.isNotEmpty ? id : _kFallbackCalendarId;
  } catch (_) {
    return _kFallbackCalendarId;
  }
});

/// Feature flags devueltos por el backend en GET /v1/system/config.
/// Si el backend es inalcanzable se usa el mapa vacío (comportamiento conservador).
///
/// Flags disponibles (booleanos):
///   - allow_schedule_overlap  : true → no se bloquea el traslape de horario en planeación
///   (agregar más aquí conforme se definen en backend)
final systemFeatureFlagsProvider = FutureProvider<Map<String, bool>>((ref) async {
  try {
    const client = BackendApiClient();
    final data = await client.getJson('/v1/system/config') as Map<String, dynamic>;
    final raw = data['feature_flags'];
    if (raw is Map) {
      return {
        for (final entry in raw.entries)
          if (entry.value is bool) entry.key.toString(): entry.value as bool,
      };
    }
  } catch (_) {
    // Backend inalcanzable → sin flags activos (comportamiento conservador)
  }
  return const {};
});

// ── Write service ──────────────────────────────────────────────────────────

class SystemConfigService {
  const SystemConfigService();

  Future<String> getCalendarId() async {
    try {
      const client = BackendApiClient();
      final data = await client.getJson('/v1/system/config') as Map<String, dynamic>;
      final id = (data['google_calendar_id'] as String?)?.trim() ?? '';
      return id.isNotEmpty ? id : _kFallbackCalendarId;
    } catch (_) {
      return _kFallbackCalendarId;
    }
  }

  /// Returns the new calendar ID on success. Throws on failure.
  Future<String> updateCalendarId(String calendarId) async {
    const client = BackendApiClient();
    final data = await client.putJson(
      '/v1/system/config',
      {'google_calendar_id': calendarId.trim()},
    ) as Map<String, dynamic>;
    return (data['google_calendar_id'] as String?) ?? calendarId;
  }

  /// Activa o desactiva un feature flag en el backend.
  /// El admin puede llamar esto desde la UI sin redistribuir el cliente.
  Future<void> setFeatureFlag(String flagName, {required bool value}) async {
    const client = BackendApiClient();
    await client.putJson(
      '/v1/system/config',
      {
        'feature_flags': {flagName: value},
      },
    );
  }

}

final systemConfigServiceProvider = Provider<SystemConfigService>(
  (_) => const SystemConfigService(),
);
