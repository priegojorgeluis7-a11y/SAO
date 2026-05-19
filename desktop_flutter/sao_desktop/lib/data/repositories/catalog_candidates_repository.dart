import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'backend_api_client.dart';

/// Modelo de un candidato de catálogo propuesto por un operativo.
class CatalogCandidate {
  const CatalogCandidate({
    required this.id,
    required this.customId,
    required this.type,
    required this.name,
    required this.projectId,
    required this.proposedByUserId,
    required this.activityId,
    required this.status,
    this.proposedAt,
    this.lastSeenAt,
    this.reviewedAt,
    this.reviewedByUserId,
    this.reviewComment,
  });

  final String id;
  final String customId;
  final String type;
  final String name;
  final String projectId;
  final String proposedByUserId;
  final String activityId;
  final String status;
  final String? proposedAt;
  final String? lastSeenAt;
  final String? reviewedAt;
  final String? reviewedByUserId;
  final String? reviewComment;

  factory CatalogCandidate.fromJson(Map<String, dynamic> json) {
    return CatalogCandidate(
      id: json['id']?.toString() ?? '',
      customId: json['custom_id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      projectId: json['project_id']?.toString() ?? '',
      proposedByUserId: json['proposed_by_user_id']?.toString() ?? '',
      activityId: json['activity_id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      proposedAt: json['proposed_at']?.toString(),
      lastSeenAt: json['last_seen_at']?.toString(),
      reviewedAt: json['reviewed_at']?.toString(),
      reviewedByUserId: json['reviewed_by_user_id']?.toString(),
      reviewComment: json['review_comment']?.toString(),
    );
  }

  String get typeLabel {
    switch (type) {
      case 'activity':
        return 'Tipo de actividad';
      case 'subcategory':
        return 'Subcategoría';
      case 'purpose':
        return 'Propósito';
      case 'result':
        return 'Resultado';
      case 'topic':
        return 'Tema';
      case 'attendee':
        return 'Asistente';
      default:
        return type;
    }
  }
}

class CatalogCandidatesRepository {
  const CatalogCandidatesRepository();

  final BackendApiClient _api = const BackendApiClient();

  Future<List<CatalogCandidate>> listCandidates(
    String projectId, {
    String candidateStatus = 'pending',
  }) async {
    final encoded = Uri.encodeQueryComponent(projectId);
    final statusEncoded = Uri.encodeQueryComponent(candidateStatus);
    final raw = await _api.getJson(
      '/api/v1/catalog/candidates?project_id=$encoded&status=$statusEncoded',
    );
    if (raw is! List) return [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(CatalogCandidate.fromJson)
        .toList();
  }

  Future<void> approve(String candidateId, {String? comment}) async {
    final encoded = Uri.encodeComponent(candidateId);
    final body = <String, dynamic>{};
    if (comment != null && comment.trim().isNotEmpty) {
      body['comment'] = comment.trim();
    }
    await _api.postJson('/api/v1/catalog/candidates/$encoded/approve', body);
  }

  Future<void> reject(String candidateId, {String? comment}) async {
    final encoded = Uri.encodeComponent(candidateId);
    final body = <String, dynamic>{};
    if (comment != null && comment.trim().isNotEmpty) {
      body['comment'] = comment.trim();
    }
    await _api.postJson('/api/v1/catalog/candidates/$encoded/reject', body);
  }
}

// ---------------------------------------------------------------------------
// Riverpod
// ---------------------------------------------------------------------------

final catalogCandidatesRepoProvider = Provider<CatalogCandidatesRepository>(
  (ref) => const CatalogCandidatesRepository(),
);
