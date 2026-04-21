import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../../../core/network/api_client.dart';

const _kFallbackCalendarId =
    '7874f5cb85c43eba5ba24e8b710c1b2fac0d8f64106f0cdfddb6bb14441bc151'
    '@group.calendar.google.com';

/// Reads the system-wide Google Calendar ID configured by the admin.
/// Falls back to the hardcoded default if the backend is unreachable.
final systemCalendarIdProvider = FutureProvider<String>((ref) async {
  try {
    final apiClient = GetIt.I<ApiClient>();
    final response =
        await apiClient.get<Map<String, dynamic>>('/v1/system/config');
    final data = response.data;
    final id = (data?['google_calendar_id'] as String?)?.trim() ?? '';
    return id.isNotEmpty ? id : _kFallbackCalendarId;
  } catch (_) {
    return _kFallbackCalendarId;
  }
});
