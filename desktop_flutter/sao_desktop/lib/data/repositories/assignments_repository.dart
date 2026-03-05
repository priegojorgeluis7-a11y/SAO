import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'backend_api_client.dart';

class AssignmentItem {
  final String id;
  final String activityTypeName;
  final String pk;
  final String frontName;
  final String assigneeName;
  final String assigneeEmail;
  final String scheduledDate;
  final String scheduledTime;
  final String status;

  const AssignmentItem({
    required this.id,
    required this.activityTypeName,
    required this.pk,
    required this.frontName,
    required this.assigneeName,
    required this.assigneeEmail,
    required this.scheduledDate,
    required this.scheduledTime,
    required this.status,
  });

  factory AssignmentItem.fromJson(Map<String, dynamic> json) {
    return AssignmentItem(
      id: (json['id'] ?? '').toString(),
      activityTypeName: (json['activity_type_name'] ?? json['activity_type'] ?? 'Actividad').toString(),
      pk: (json['pk'] ?? '—').toString(),
      frontName: (json['front_name'] ?? json['front'] ?? 'Sin frente').toString(),
      assigneeName: (json['assignee_name'] ?? json['full_name'] ?? 'Sin responsable').toString(),
      assigneeEmail: (json['assignee_email'] ?? json['email'] ?? '').toString(),
      scheduledDate: (json['scheduled_date'] ?? '').toString(),
      scheduledTime: (json['scheduled_time'] ?? json['scheduled_date'] ?? '').toString(),
      status: (json['status'] ?? 'PROGRAMADA').toString(),
    );
  }
}

class AssignmentAssigneeOption {
  final String userId;
  final String fullName;
  final String email;
  final String roleName;

  const AssignmentAssigneeOption({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.roleName,
  });

  factory AssignmentAssigneeOption.fromJson(Map<String, dynamic> json) {
    return AssignmentAssigneeOption(
      userId: (json['user_id'] ?? '').toString(),
      fullName: (json['full_name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      roleName: (json['role_name'] ?? '').toString(),
    );
  }
}

class AssignmentFrontOption {
  final String id;
  final String code;
  final String name;

  const AssignmentFrontOption({
    required this.id,
    required this.code,
    required this.name,
  });

  factory AssignmentFrontOption.fromJson(Map<String, dynamic> json) {
    return AssignmentFrontOption(
      id: (json['id'] ?? '').toString(),
      code: (json['code'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
    );
  }

  String get label => code.isEmpty ? name : '$code · $name';
}

class AssignmentActivityTypeOption {
  final String code;
  final String name;

  const AssignmentActivityTypeOption({
    required this.code,
    required this.name,
  });

  factory AssignmentActivityTypeOption.fromJson(Map<String, dynamic> json) {
    return AssignmentActivityTypeOption(
      code: (json['code'] ?? '').toString(),
      name: (json['name_effective'] ?? json['name'] ?? '').toString(),
    );
  }

  String get label => '$code · $name';
}

class AssignmentsRepository {
  final BackendApiClient _client;

  const AssignmentsRepository(this._client);

  Future<List<AssignmentItem>> getForDate({
    required String projectId,
    required DateTime date,
  }) async {
    final dateStr = date.toIso8601String().split('T').first;
    try {
      final decoded = await _client.getJson(
        '/api/v1/assignments?project_id=${Uri.encodeQueryComponent(projectId)}'
        '&from=$dateStr&to=$dateStr',
      );

      if (decoded is! List) return [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map((e) => AssignmentItem.fromJson(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<AssignmentAssigneeOption>> getAssignees(String projectId) async {
    final decoded = await _client.getJson(
      '/api/v1/assignments/assignees?project_id=${Uri.encodeQueryComponent(projectId)}',
    );
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(AssignmentAssigneeOption.fromJson)
        .toList();
  }

  Future<List<AssignmentFrontOption>> getFronts(String projectId) async {
    final decoded = await _client.getJson(
      '/api/v1/fronts?project_id=${Uri.encodeQueryComponent(projectId)}',
    );
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(AssignmentFrontOption.fromJson)
        .toList();
  }

  Future<List<AssignmentActivityTypeOption>> getActivityTypes(String projectId) async {
    final decoded = await _client.getJson(
      '/api/v1/catalog/effective?project_id=${Uri.encodeQueryComponent(projectId)}',
    );
    if (decoded is! Map<String, dynamic>) return const [];
    final activities = decoded['activities'];
    if (activities is! List) return const [];
    return activities
        .whereType<Map<String, dynamic>>()
        .map(AssignmentActivityTypeOption.fromJson)
        .where((item) => item.code.isNotEmpty)
        .toList();
  }

  Future<AssignmentItem> createAssignment({
    required String projectId,
    required String assigneeUserId,
    required String activityTypeCode,
    required DateTime startAt,
    required DateTime endAt,
    String? title,
    String? frontId,
    int pk = 0,
    String risk = 'bajo',
  }) async {
    final decoded = await _client.postJson('/api/v1/assignments', {
      'project_id': projectId,
      'assignee_user_id': assigneeUserId,
      'activity_type_code': activityTypeCode,
      'title': title,
      'front_id': frontId,
      'pk': pk,
      'start_at': startAt.toUtc().toIso8601String(),
      'end_at': endAt.toUtc().toIso8601String(),
      'risk': risk,
    });
    return AssignmentItem.fromJson((decoded as Map).cast<String, dynamic>());
  }
}

final assignmentsRepositoryProvider = Provider<AssignmentsRepository>((ref) {
  return const AssignmentsRepository(BackendApiClient());
});
