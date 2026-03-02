// lib/features/events/data/events_api_repository.dart
import '../../../core/network/api_client.dart';
import '../models/event_dto.dart';

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

  /// GET /api/v1/events?project_id=...&since_version=...
  Future<List<EventDTO>> listEvents({
    required String projectId,
    int? sinceVersion,
    String? severity,
    int limit = 200,
  }) async {
    final query = <String, dynamic>{
      'project_id': projectId,
      'limit': limit,
      'since_version': sinceVersion,
      'severity': severity,
    }..removeWhere((_, v) => v == null);
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/events',
      queryParameters: query,
    );
    final items = response.data!['items'] as List<dynamic>;
    return items
        .map((e) => EventDTO.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
