// lib/features/agenda/services/calendar_sync_service.dart
//
// Servicio de sincronización de asignaciones SAO → calendario del dispositivo.
// Usa el plugin device_calendar para escribir eventos en cualquier calendario
// configurado en el dispositivo (incluye cuentas de Google Calendar).
//
// Flujo:
//   1. CalendarSyncService.requestPermissions()  → solicita permisos
//   2. CalendarSyncService.listCalendars()        → lista calendarios disponibles
//   3. Guardar el id del calendario elegido (ver CalendarSettingsNotifier)
//   4. CalendarSyncService.syncItems(items)       → crea/actualiza eventos
//   5. CalendarSyncService.deleteEvent(externalId)→ elimina evento si se cancela

import 'package:device_calendar/device_calendar.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/agenda_item.dart';
import '../../../core/utils/logger.dart';

class CalendarSyncService {
  CalendarSyncService() {
    tz_data.initializeTimeZones();
  }

  final DeviceCalendarPlugin _plugin = DeviceCalendarPlugin();

  // ── permisos ─────────────────────────────────────────────────────────────

  /// Solicita READ_CALENDAR + WRITE_CALENDAR.
  /// Retorna true si fueron concedidos.
  Future<bool> requestPermissions() async {
    try {
      final result = await _plugin.requestPermissions();
      return result.isSuccess && (result.data ?? false);
    } catch (e) {
      appLogger.e('CalendarSyncService.requestPermissions: $e');
      return false;
    }
  }

  Future<bool> hasPermissions() async {
    try {
      final result = await _plugin.hasPermissions();
      return result.isSuccess && (result.data ?? false);
    } catch (e) {
      return false;
    }
  }

  // ── calendarios disponibles ───────────────────────────────────────────────

  /// Retorna la lista de calendarios del dispositivo (Google, Exchange, local…).
  Future<List<Calendar>> listCalendars() async {
    try {
      final result = await _plugin.retrieveCalendars();
      if (!result.isSuccess) return const [];
      final calendars = result.data ?? [];
      // Filtra calendarios de sólo lectura
      return calendars
          .where((c) => c.isReadOnly != true)
          .toList()
          .cast<Calendar>();
    } catch (e) {
      appLogger.e('CalendarSyncService.listCalendars: $e');
      return const [];
    }
  }

  // ── sincronización ────────────────────────────────────────────────────────

  /// Sincroniza la lista de [items] al calendario con id [calendarId].
  /// Por cada item:
  ///   • Si ya existe un evento (buscado por título+fecha), lo actualiza.
  ///   • Si no existe, lo crea.
  /// Retorna el número de eventos creados/actualizados con éxito.
  Future<int> syncItems({
    required String calendarId,
    required List<AgendaItem> items,
  }) async {
    int count = 0;
    for (final item in items) {
      try {
        final ok = await _upsertEvent(calendarId: calendarId, item: item);
        if (ok) count++;
      } catch (e) {
        appLogger.w('CalendarSyncService.syncItems error for ${item.id}: $e');
      }
    }
    return count;
  }

  // ── upsert individual ─────────────────────────────────────────────────────

  Future<bool> _upsertEvent({
    required String calendarId,
    required AgendaItem item,
  }) async {
    final existing = await _findEventByExternalId(calendarId, item.id);

    final event = Event(
      calendarId,
      eventId: existing?.eventId,
      title: _buildTitle(item),
      description: _buildDescription(item),
      start: TZDateTime.from(item.start, tz.local),
      end: TZDateTime.from(item.end, tz.local),
    );

    final result = await _plugin.createOrUpdateEvent(event);
    return result?.isSuccess ?? false;
  }

  Future<Event?> _findEventByExternalId(
    String calendarId,
    String agendaItemId,
  ) async {
    try {
      // Buscamos eventos en un rango amplio por el descriptionPattern
      final from = DateTime.now().subtract(const Duration(days: 90));
      final to = DateTime.now().add(const Duration(days: 365));
      final result = await _plugin.retrieveEvents(
        calendarId,
        RetrieveEventsParams(startDate: from, endDate: to),
      );
      if (!result.isSuccess) return null;
      final events = (result.data ?? []).cast<Event>();
      for (final e in events) {
        if ((e.description ?? '').contains('SAO-ID:$agendaItemId')) return e;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Elimina el evento del calendario que coincide con [agendaItemId].
  Future<void> deleteEvent({
    required String calendarId,
    required String agendaItemId,
  }) async {
    try {
      final event = await _findEventByExternalId(calendarId, agendaItemId);
      if (event?.eventId != null) {
        await _plugin.deleteEvent(calendarId, event!.eventId!);
      }
    } catch (e) {
      appLogger.w('CalendarSyncService.deleteEvent: $e');
    }
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  String _buildTitle(AgendaItem item) {
    final parts = <String>['[SAO]', item.title];
    if (item.frente.isNotEmpty) parts.add('· ${item.frente}');
    return parts.join(' ');
  }

  String _buildDescription(AgendaItem item) {
    final lines = <String>[
      'SAO-ID:${item.id}',
      'Proyecto: ${item.projectCode}',
      if (item.frente.isNotEmpty) 'Frente: ${item.frente}',
      if (item.municipio.isNotEmpty) 'Municipio: ${item.municipio}',
      if (item.estado.isNotEmpty) 'Estado: ${item.estado}',
      if (item.pk != null) 'PK: ${item.pk}',
    ];
    return lines.join('\n');
  }
}

// Extensión mínima ya no necesaria (removida, loop explícito en su lugar).
