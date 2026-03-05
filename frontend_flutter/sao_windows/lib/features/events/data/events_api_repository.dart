// lib/features/events/data/events_api_repository.dart
import '../../../core/network/api_client.dart';
import '../models/event_dto.dart';

class EventListPage {
  final List<EventDTO> items;
  final int total;
  final int page;
  final int pageSize;
  final bool hasNext;

  const EventListPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.hasNext,
  });
}

/// Repository for remote event operations.
/// Maps to backend /api/v1/events endpoints.
class EventsApiRepository {
  final ApiClient _apiClient;

  EventsApiRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  /// POST /api/v1/events
  /// Idempotent by UUID: returns 201 on create, 200 if UUID already exists.
  Future<EventDTO> createEvent(EventDTO event) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/events',
      data: event.toJson(),
    );
    return EventDTO.fromJson(response.data!);
  }

  /// GET /api/v1/events/{uuid}
  Future<EventDTO> getEvent(String uuid) async {
    final response =
        await _apiClient.get<Map<String, dynamic>>('/events/$uuid');
    return EventDTO.fromJson(response.data!);
  }

  /// PUT /api/v1/events/{uuid}
  Future<EventDTO> updateEvent(EventDTO event) async {
    final response = await _apiClient.put<Map<String, dynamic>>(
      '/events/${event.uuid}',
      data: event.toJson(),
    );
    return EventDTO.fromJson(response.data!);
  }

  /// DELETE /api/v1/events/{uuid}
  Future<void> deleteEvent(String uuid) async {
    await _apiClient.delete<void>('/events/$uuid');
  }

  /// GET /api/v1/events?project_id=...&since_version=...
  Future<EventListPage> listEvents({
    required String projectId,
    int? sinceVersion,
    String? severity,
    bool includeDeleted = true,
    int page = 1,
    int pageSize = 200,
  }) async {
    final query = <String, dynamic>{
      'project_id': projectId,
      'page': page,
      'page_size': pageSize,
      'include_deleted': includeDeleted,
      'since_version': sinceVersion,
      'severity': severity,
    }..removeWhere((_, v) => v == null);
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/events',
      queryParameters: query,
    );
    final data = response.data!;
    final items = (data['items'] as List<dynamic>)
        .map((e) => EventDTO.fromJson(e as Map<String, dynamic>))
        .toList();

    return EventListPage(
      items: items,
      total: (data['total'] as num?)?.toInt() ?? items.length,
      page: (data['page'] as num?)?.toInt() ?? page,
      pageSize: (data['page_size'] as num?)?.toInt() ?? pageSize,
      hasNext: (data['has_next'] as bool?) ?? false,
    );
  }
}
