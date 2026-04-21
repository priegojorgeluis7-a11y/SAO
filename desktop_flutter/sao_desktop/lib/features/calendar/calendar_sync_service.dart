import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:http/http.dart' as http;

import '../../data/repositories/assignments_repository.dart';

// ---------------------------------------------------------------------------
// HTTP client wrapper that injects Google auth headers
// ---------------------------------------------------------------------------

class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _inner = http.Client();

  _GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _inner.send(request..headers.addAll(_headers));
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}

// ---------------------------------------------------------------------------
// CalendarSyncService
// ---------------------------------------------------------------------------

/// Wraps GoogleSignIn + Google Calendar API for desktop (macOS).
///
/// Requires Info.plist `GIDClientID` and URL scheme already configured.
class CalendarSyncService {
  static const _scopes = [gcal.CalendarApi.calendarScope];

  final _signIn = GoogleSignIn(scopes: _scopes);

  // ── Auth ──────────────────────────────────────────────────────────────────

  Future<GoogleSignInAccount?> signIn() => _signIn.signIn();

  Future<void> signOut() => _signIn.signOut();

  Future<bool> isSignedIn() => _signIn.isSignedIn();

  Future<GoogleSignInAccount?> get currentUser async =>
      _signIn.currentUser ?? await _signIn.signInSilently();

  // ── API access ────────────────────────────────────────────────────────────

  Future<gcal.CalendarApi?> _api() async {
    final account = await currentUser;
    if (account == null) return null;
    final headers = await account.authHeaders;
    return gcal.CalendarApi(_GoogleAuthClient(headers));
  }

  // ── Calendar list ─────────────────────────────────────────────────────────

  /// Returns all calendars the signed-in user has write access to.
  Future<List<gcal.CalendarListEntry>> listCalendars() async {
    final api = await _api();
    if (api == null) return const [];
    try {
      final result = await api.calendarList.list();
      return (result.items ?? [])
          .where((c) =>
              c.accessRole == 'owner' || c.accessRole == 'writer')
          .toList();
    } catch (_) {
      return const [];
    }
  }

  // ── Sync assignments ──────────────────────────────────────────────────────

  /// Creates or updates Google Calendar events for [items].
  ///
  /// Uses description tag `SAO-ID:{item.id}` for idempotent lookup.
  /// Returns the number of events upserted.
  Future<int> syncAssignments({
    required String calendarId,
    required List<AssignmentItem> items,
  }) async {
    final api = await _api();
    if (api == null || items.isEmpty) return 0;

    // Load existing events for the date range of the items being synced.
    final dates = items.map(_itemDate).whereType<DateTime>().toList()
      ..sort();
    if (dates.isEmpty) return 0;

    final timeMin = dates.first.subtract(const Duration(days: 1)).toUtc();
    final timeMax = dates.last.add(const Duration(days: 2)).toUtc();

    Map<String, String> existingEventIdByAssignmentId = {};
    try {
      String? pageToken;
      do {
        final page = await api.events.list(
          calendarId,
          timeMin: timeMin,
          timeMax: timeMax,
          maxResults: 2500,
          pageToken: pageToken,
        );
        for (final e in page.items ?? []) {
          final desc = e.description ?? '';
          final match = RegExp(r'SAO-ID:(\S+)').firstMatch(desc);
          if (match != null) {
            existingEventIdByAssignmentId[match.group(1)!] = e.id!;
          }
        }
        pageToken = page.nextPageToken;
      } while (pageToken != null);
    } catch (_) {
      // Proceed with insert-only if list fails.
    }

    int count = 0;
    for (final item in items) {
      final event = _buildEvent(item);
      try {
        final existingId = existingEventIdByAssignmentId[item.id];
        if (existingId != null) {
          await api.events.update(event, calendarId, existingId);
        } else {
          await api.events.insert(event, calendarId);
        }
        count++;
      } catch (_) {
        // Skip individual event failures silently.
      }
    }
    return count;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  DateTime? _itemDate(AssignmentItem item) {
    final raw = item.startAt ?? item.scheduledDate;
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  gcal.Event _buildEvent(AssignmentItem item) {
    final date = _itemDate(item);
    final start = date ?? DateTime.now();
    final end = start.add(const Duration(hours: 1));

    final location = [
      if (item.colonia != null && item.colonia!.isNotEmpty) item.colonia,
      if (item.municipio.isNotEmpty) item.municipio,
      if (item.estado.isNotEmpty) item.estado,
    ].join(', ');

    final frente =
        item.frontName.isNotEmpty ? item.frontName : 'Sin frente';

    return gcal.Event(
      summary: '[SAO] ${item.title} · $frente',
      description:
          'Actividad SAO\n'
          'Frente: $frente\n'
          'Asignado a: ${item.assigneeName}\n'
          'Estado: ${item.status}\n'
          '\nSAO-ID:${item.id}',
      location: location.isNotEmpty ? location : null,
      start: gcal.EventDateTime(
        dateTime: start.toUtc(),
        timeZone: 'UTC',
      ),
      end: gcal.EventDateTime(
        dateTime: end.toUtc(),
        timeZone: 'UTC',
      ),
    );
  }
}
