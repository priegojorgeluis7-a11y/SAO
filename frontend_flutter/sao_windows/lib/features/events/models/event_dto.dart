// lib/features/events/models/event_dto.dart

/// Severities for field events (matches backend EventSeverity enum)
enum EventSeverity {
  low,
  medium,
  high,
  critical;

  String get value => name.toUpperCase();

  static EventSeverity fromString(String s) {
    return EventSeverity.values.firstWhere(
      (e) => e.value == s.toUpperCase(),
      orElse: () => EventSeverity.medium,
    );
  }

  String get label {
    return switch (this) {
      EventSeverity.low => 'BAJO',
      EventSeverity.medium => 'MEDIO',
      EventSeverity.high => 'ALTO',
      EventSeverity.critical => 'CRÍTICO',
    };
  }
}

/// DTO matching the backend EventDTO (used for API calls and sync queue payload)
class EventDTO {
  final String uuid;
  final int? serverId;
  final String projectId;
  final String reportedByUserId;
  final String eventTypeCode;
  final String title;
  final String? description;
  final String severity; // LOW | MEDIUM | HIGH | CRITICAL
  final int? locationPkMeters;
  final String occurredAt; // ISO 8601
  final String? resolvedAt;
  final String? deletedAt;
  final String? formFieldsJson;
  final int syncVersion;

  const EventDTO({
    required this.uuid,
    this.serverId,
    required this.projectId,
    required this.reportedByUserId,
    required this.eventTypeCode,
    required this.title,
    this.description,
    required this.severity,
    this.locationPkMeters,
    required this.occurredAt,
    this.resolvedAt,
    this.deletedAt,
    this.formFieldsJson,
    this.syncVersion = 0,
  });

  factory EventDTO.fromJson(Map<String, dynamic> json) => EventDTO(
      uuid: (json['uuid'] ?? '').toString(),
        serverId: json['server_id'] as int?,
      projectId: (json['project_id'] ?? '').toString(),
      reportedByUserId: (json['reported_by_user_id'] ?? '').toString(),
      eventTypeCode: (json['event_type_code'] ?? 'UNKNOWN').toString(),
      title: (json['title'] ?? '').toString(),
      description: json['description']?.toString(),
      severity: (json['severity'] ?? 'MEDIUM').toString(),
        locationPkMeters: json['location_pk_meters'] as int?,
      occurredAt: (json['occurred_at'] ?? DateTime.now().toUtc().toIso8601String()).toString(),
      resolvedAt: json['resolved_at']?.toString(),
      deletedAt: json['deleted_at']?.toString(),
      formFieldsJson: json['form_fields_json']?.toString(),
        syncVersion: (json['sync_version'] as int?) ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'uuid': uuid,
        'server_id': serverId,
        'project_id': projectId,
        'reported_by_user_id': reportedByUserId,
        'event_type_code': eventTypeCode,
        'title': title,
        'description': description,
        'severity': severity,
        'location_pk_meters': locationPkMeters,
        'occurred_at': occurredAt,
        'resolved_at': resolvedAt,
        'deleted_at': deletedAt,
        'form_fields_json': formFieldsJson,
        'sync_version': syncVersion,
      };
}
