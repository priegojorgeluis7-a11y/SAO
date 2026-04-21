import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'calendar_sync_service.dart';

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

class DesktopCalendarSettings {
  final bool isEnabled;
  final String? calendarId;
  final String? calendarName;
  final String? accountEmail;

  const DesktopCalendarSettings({
    this.isEnabled = false,
    this.calendarId,
    this.calendarName,
    this.accountEmail,
  });

  DesktopCalendarSettings copyWith({
    bool? isEnabled,
    String? calendarId,
    String? calendarName,
    String? accountEmail,
  }) {
    return DesktopCalendarSettings(
      isEnabled: isEnabled ?? this.isEnabled,
      calendarId: calendarId ?? this.calendarId,
      calendarName: calendarName ?? this.calendarName,
      accountEmail: accountEmail ?? this.accountEmail,
    );
  }

  bool get isConnected => calendarId != null && calendarId!.isNotEmpty;
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

const _kEnabled = 'gcal_desktop_enabled';
const _kCalendarId = 'gcal_desktop_calendar_id';
const _kCalendarName = 'gcal_desktop_calendar_name';
const _kAccountEmail = 'gcal_desktop_account_email';

class DesktopCalendarSettingsNotifier
    extends StateNotifier<DesktopCalendarSettings> {
  final FlutterSecureStorage _storage;

  DesktopCalendarSettingsNotifier(this._storage)
      : super(const DesktopCalendarSettings()) {
    _load();
  }

  Future<void> _load() async {
    final enabled = await _storage.read(key: _kEnabled) == 'true';
    final calId = await _storage.read(key: _kCalendarId);
    final calName = await _storage.read(key: _kCalendarName);
    final email = await _storage.read(key: _kAccountEmail);
    state = DesktopCalendarSettings(
      isEnabled: enabled,
      calendarId: calId,
      calendarName: calName,
      accountEmail: email,
    );
  }

  Future<void> connect({
    required String calendarId,
    required String calendarName,
    required String accountEmail,
  }) async {
    await _storage.write(key: _kEnabled, value: 'true');
    await _storage.write(key: _kCalendarId, value: calendarId);
    await _storage.write(key: _kCalendarName, value: calendarName);
    await _storage.write(key: _kAccountEmail, value: accountEmail);
    state = DesktopCalendarSettings(
      isEnabled: true,
      calendarId: calendarId,
      calendarName: calendarName,
      accountEmail: accountEmail,
    );
  }

  Future<void> disconnect() async {
    await _storage.delete(key: _kEnabled);
    await _storage.delete(key: _kCalendarId);
    await _storage.delete(key: _kCalendarName);
    await _storage.delete(key: _kAccountEmail);
    state = const DesktopCalendarSettings();
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _secureStorageProvider = Provider<FlutterSecureStorage>(
  (_) => const FlutterSecureStorage(),
);

final desktopCalendarSettingsProvider = StateNotifierProvider<
    DesktopCalendarSettingsNotifier, DesktopCalendarSettings>(
  (ref) => DesktopCalendarSettingsNotifier(
    ref.watch(_secureStorageProvider),
  ),
);

final desktopCalendarSyncServiceProvider = Provider<CalendarSyncService>(
  (_) => CalendarSyncService(),
);
