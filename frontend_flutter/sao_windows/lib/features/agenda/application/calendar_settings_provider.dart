// lib/features/agenda/application/calendar_settings_provider.dart
//
// Estado de configuración de sincronización con Google Calendar.
//
// Persiste en SharedPreferences:
//   'gcal_enabled'     → bool  (sync activada)
//   'gcal_calendar_id' → String (id del calendario elegido)
//   'gcal_calendar_name' → String (nombre display del calendario elegido)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/calendar_sync_service.dart';

const _kEnabled = 'gcal_enabled';
const _kCalendarId = 'gcal_calendar_id';
const _kCalendarName = 'gcal_calendar_name';

// ── modelo ────────────────────────────────────────────────────────────────────

class CalendarSettings {
  const CalendarSettings({
    this.enabled = false,
    this.calendarId,
    this.calendarName,
  });

  final bool enabled;
  final String? calendarId;
  final String? calendarName;

  bool get isConfigured => enabled && calendarId != null && calendarId!.isNotEmpty;

  CalendarSettings copyWith({
    bool? enabled,
    String? calendarId,
    String? calendarName,
  }) =>
      CalendarSettings(
        enabled: enabled ?? this.enabled,
        calendarId: calendarId ?? this.calendarId,
        calendarName: calendarName ?? this.calendarName,
      );
}

// ── notifier ──────────────────────────────────────────────────────────────────

class CalendarSettingsNotifier extends StateNotifier<CalendarSettings> {
  CalendarSettingsNotifier() : super(const CalendarSettings()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = CalendarSettings(
      enabled: prefs.getBool(_kEnabled) ?? false,
      calendarId: prefs.getString(_kCalendarId),
      calendarName: prefs.getString(_kCalendarName),
    );
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, value);
    state = state.copyWith(enabled: value);
  }

  Future<void> setCalendar({
    required String calendarId,
    required String calendarName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCalendarId, calendarId);
    await prefs.setString(_kCalendarName, calendarName);
    state = state.copyWith(
      enabled: true,
      calendarId: calendarId,
      calendarName: calendarName,
    );
  }

  Future<void> disconnect() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kEnabled);
    await prefs.remove(_kCalendarId);
    await prefs.remove(_kCalendarName);
    state = const CalendarSettings();
  }
}

// ── providers públicos ────────────────────────────────────────────────────────

final calendarSettingsProvider =
    StateNotifierProvider<CalendarSettingsNotifier, CalendarSettings>(
  (ref) => CalendarSettingsNotifier(),
);

final calendarSyncServiceProvider = Provider<CalendarSyncService>(
  (ref) => CalendarSyncService(),
);
