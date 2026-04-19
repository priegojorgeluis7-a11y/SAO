import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/backend_api_client.dart';
import '../../core/config/data_mode.dart';

// ── Filter state ───────────────────────────────────────────────────────────────

final completedProjectFilterProvider = StateProvider<String>((ref) => '');
final completedFrenteFilterProvider = StateProvider<String>((ref) => '');
final completedTemaFilterProvider = StateProvider<String>((ref) => '');
final completedEstadoFilterProvider = StateProvider<String>((ref) => '');
final completedMunicipioFilterProvider = StateProvider<String>((ref) => '');
final completedUsuarioFilterProvider = StateProvider<String>((ref) => '');
final completedSearchQueryProvider = StateProvider<String>((ref) => '');

// ── Models ─────────────────────────────────────────────────────────────────────

class CompletedActivity {
  final String id;
  final String projectId;
  final String title;
  final String activityType;
  final String pk;
  final String front;
  final String estado;
  final String municipio;
  final bool hasReport;
  final int documentCount;
  final String reviewedAt;
  final String createdAt;
  final int evidenceCount;
  final String assignedName;
  final String reviewedByName;
  final String reviewDecision;

  const CompletedActivity({
    required this.id,
    required this.projectId,
    required this.title,
    required this.activityType,
    required this.pk,
    required this.front,
    required this.estado,
    required this.municipio,
    required this.hasReport,
    required this.documentCount,
    required this.reviewedAt,
    required this.createdAt,
    required this.evidenceCount,
    required this.assignedName,
    required this.reviewedByName,
    required this.reviewDecision,
  });

  factory CompletedActivity.fromJson(Map<String, dynamic> json) {
    return CompletedActivity(
      id: (json['id'] ?? '').toString(),
      projectId: (json['project_id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      activityType: (json['activity_type'] ?? '').toString(),
      pk: (json['pk'] ?? '').toString(),
      front: (json['front'] ?? '').toString(),
      estado: (json['estado'] ?? '').toString(),
      municipio: (json['municipio'] ?? '').toString(),
      hasReport: (json['has_report'] as bool?) ?? false,
      documentCount: (json['document_count'] as num?)?.toInt() ??
          (((json['has_report'] as bool?) ?? false) ? 1 : 0),
      reviewedAt: (json['reviewed_at'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
      evidenceCount: (json['evidence_count'] as num?)?.toInt() ?? 0,
      assignedName: (json['assigned_name'] ?? '').toString(),
      reviewedByName: (json['reviewed_by_name'] ?? '').toString(),
      reviewDecision: (json['review_decision'] ?? '').toString(),
    );
  }
}

class AuditEntry {
  final String id;
  final String action;
  final String actorEmail;
  final String actorName;
  final Map<String, dynamic> changes;
  final String notes;
  final String timestamp;

  const AuditEntry({
    required this.id,
    required this.action,
    required this.actorEmail,
    required this.actorName,
    required this.changes,
    required this.notes,
    required this.timestamp,
  });

  factory AuditEntry.fromJson(Map<String, dynamic> json) {
    return AuditEntry(
      id: (json['id'] ?? '').toString(),
      action: (json['action'] ?? '').toString(),
      actorEmail: (json['actor_email'] ?? '').toString(),
      actorName: (json['actor_name'] ?? '').toString(),
      changes: (json['changes'] as Map<String, dynamic>?) ?? {},
      notes: (json['notes'] ?? '').toString(),
      timestamp: (json['timestamp'] ?? '').toString(),
    );
  }
}

class EvidenceItem {
  final String id;
  final String type;
  final String description;
  final String gcsPath;
  final String uploadedAt;
  final String uploaderName;

  const EvidenceItem({
    required this.id,
    required this.type,
    required this.description,
    required this.gcsPath,
    required this.uploadedAt,
    required this.uploaderName,
  });

  factory EvidenceItem.fromJson(Map<String, dynamic> json) {
    return EvidenceItem(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      gcsPath: (json['gcs_path'] ?? '').toString(),
      uploadedAt: (json['uploaded_at'] ?? '').toString(),
      uploaderName: (json['uploader_name'] ?? '').toString(),
    );
  }
}

List<String> _normalizeStringList(dynamic raw) {
  if (raw is! List) return const <String>[];

  final normalized = <String>[];
  final seen = <String>{};
  for (final item in raw) {
    final value = item?.toString().trim() ?? '';
    if (value.isEmpty || value.toLowerCase() == 'null' || !seen.add(value)) {
      continue;
    }
    normalized.add(value);
  }
  return normalized;
}

class ManualRelatedLink {
  final String activityId;
  final String relationType;
  final String status;
  final String reason;
  final String nextAction;
  final String dueDate;
  final String createdAt;
  final String createdBy;

  const ManualRelatedLink({
    required this.activityId,
    this.relationType = 'seguimiento',
    this.status = 'abierta',
    this.reason = '',
    this.nextAction = '',
    this.dueDate = '',
    this.createdAt = '',
    this.createdBy = '',
  });

  factory ManualRelatedLink.fromJson(Map<String, dynamic> json) {
    final activityId =
        (json['activity_id'] ?? json['activityId'] ?? '').toString().trim();
    return ManualRelatedLink(
      activityId: activityId,
      relationType:
          (json['relation_type'] ?? json['relationType'] ?? 'seguimiento')
              .toString()
              .trim(),
      status: (json['status'] ?? 'abierta').toString().trim(),
      reason: (json['reason'] ?? '').toString().trim(),
      nextAction:
          (json['next_action'] ?? json['nextAction'] ?? '').toString().trim(),
      dueDate: (json['due_date'] ?? json['dueDate'] ?? '').toString().trim(),
      createdAt:
          (json['created_at'] ?? json['createdAt'] ?? '').toString().trim(),
      createdBy:
          (json['created_by'] ?? json['createdBy'] ?? '').toString().trim(),
    );
  }

  ManualRelatedLink copyWith({
    String? activityId,
    String? relationType,
    String? status,
    String? reason,
    String? nextAction,
    String? dueDate,
    String? createdAt,
    String? createdBy,
  }) {
    return ManualRelatedLink(
      activityId: activityId ?? this.activityId,
      relationType: relationType ?? this.relationType,
      status: status ?? this.status,
      reason: reason ?? this.reason,
      nextAction: nextAction ?? this.nextAction,
      dueDate: dueDate ?? this.dueDate,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'activity_id': activityId,
      'relation_type': relationType,
      'status': status,
      'reason': reason,
      'next_action': nextAction,
      'due_date': dueDate,
      'created_at': createdAt,
      'created_by': createdBy,
    };
  }

  static List<ManualRelatedLink> normalizeList(
    dynamic raw, {
    String currentId = '',
  }) {
    if (raw is! List) return const <ManualRelatedLink>[];

    final normalized = <ManualRelatedLink>[];
    final seen = <String>{};
    final normalizedCurrentId = currentId.trim();

    for (final item in raw) {
      final ManualRelatedLink? link;
      if (item is Map<String, dynamic>) {
        link = ManualRelatedLink.fromJson(item);
      } else if (item is Map) {
        link = ManualRelatedLink.fromJson(
          item.map((key, value) => MapEntry(key.toString(), value)),
        );
      } else {
        final value = item?.toString().trim() ?? '';
        if (value.isEmpty || value.toLowerCase() == 'null') {
          continue;
        }
        link = ManualRelatedLink(activityId: value);
      }

      final activityId = link.activityId.trim();
      if (activityId.isEmpty ||
          activityId.toLowerCase() == 'null' ||
          activityId == normalizedCurrentId ||
          !seen.add(activityId)) {
        continue;
      }
      normalized.add(link.copyWith(activityId: activityId));
    }

    return normalized;
  }
}

class CompletedActivityDetail {
  final CompletedActivity summary;
  final String colonia;
  final String reviewNotes;
  final Map<String, dynamic> dataFields;
  final List<AuditEntry> auditTrail;
  final List<EvidenceItem> evidences;
  final List<EvidenceItem> documents;
  final List<String> relatedActivityIds;
  final List<ManualRelatedLink> relatedLinks;
  final int syncVersion;

  const CompletedActivityDetail({
    required this.summary,
    required this.colonia,
    required this.reviewNotes,
    required this.dataFields,
    required this.auditTrail,
    required this.evidences,
    this.documents = const [],
    this.relatedActivityIds = const [],
    this.relatedLinks = const [],
    required this.syncVersion,
  });

  factory CompletedActivityDetail.fromJson(Map<String, dynamic> json) {
    final relatedLinks = ManualRelatedLink.normalizeList(
      json['related_links'] ?? json['activity_links'],
    );
    final relatedActivityIds = <String>{
      ..._normalizeStringList(json['related_activity_ids']),
      ...relatedLinks.map((item) => item.activityId),
    }.toList(growable: false);

    return CompletedActivityDetail(
      summary: CompletedActivity.fromJson(json),
      colonia: (json['colonia'] ?? '').toString(),
      reviewNotes: (json['review_notes'] ?? '').toString(),
      dataFields: (json['data_fields'] as Map<String, dynamic>?) ?? {},
      auditTrail: (json['audit_trail'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(AuditEntry.fromJson)
              .toList(growable: false) ??
          const [],
      evidences: (json['evidences'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(EvidenceItem.fromJson)
              .toList(growable: false) ??
          const [],
      documents: (json['documents'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(EvidenceItem.fromJson)
              .toList(growable: false) ??
          const [],
      relatedActivityIds: relatedActivityIds,
      relatedLinks: relatedLinks,
      syncVersion: (json['sync_version'] as num?)?.toInt() ?? 0,
    );
  }
}

class RelatedActivityMatch {
  final CompletedActivity activity;
  final List<String> reasons;
  final int score;

  const RelatedActivityMatch({
    required this.activity,
    required this.reasons,
    required this.score,
  });
}

List<RelatedActivityMatch> findRelatedActivities({
  required CompletedActivity current,
  Map<String, dynamic> currentDataFields = const {},
  required List<CompletedActivity> candidates,
  int limit = 5,
}) {
  final normalizedProject = current.projectId.trim().toUpperCase();
  final currentTitle = current.title.trim().toLowerCase();
  final currentType = current.activityType.trim().toLowerCase();
  final currentFront = current.front.trim().toLowerCase();
  final currentState = current.estado.trim().toLowerCase();
  final currentMunicipio = current.municipio.trim().toLowerCase();
  final currentPk = current.pk.trim().toLowerCase();
  final currentAssigned = current.assignedName.trim().toLowerCase();
  final currentKeywords = _historyKeywordsFor(current, currentDataFields);

  final matches = <RelatedActivityMatch>[];

  for (final candidate in candidates) {
    if (candidate.id == current.id) continue;
    if (candidate.projectId.trim().toUpperCase() != normalizedProject) continue;

    var score = 0;
    final reasons = <String>{};

    final candidateTitle = candidate.title.trim().toLowerCase();
    final candidateType = candidate.activityType.trim().toLowerCase();
    final candidateFront = candidate.front.trim().toLowerCase();
    final candidateState = candidate.estado.trim().toLowerCase();
    final candidateMunicipio = candidate.municipio.trim().toLowerCase();
    final candidatePk = candidate.pk.trim().toLowerCase();
    final candidateAssigned = candidate.assignedName.trim().toLowerCase();

    if (currentPk.isNotEmpty &&
        candidatePk.isNotEmpty &&
        candidatePk == currentPk) {
      score += 5;
      reasons.add('Mismo PK');
    }

    if (currentType.isNotEmpty &&
        candidateType.isNotEmpty &&
        candidateType == currentType) {
      score += 4;
      reasons.add('Mismo tipo');
    }

    if (currentTitle.isNotEmpty &&
        candidateTitle.isNotEmpty &&
        candidateTitle == currentTitle) {
      score += 4;
      reasons.add('Mismo asunto');
    }

    if (currentFront.isNotEmpty &&
        candidateFront.isNotEmpty &&
        candidateFront == currentFront) {
      score += 3;
      reasons.add('Mismo frente');
    }

    if (currentMunicipio.isNotEmpty &&
        candidateMunicipio.isNotEmpty &&
        candidateMunicipio == currentMunicipio) {
      score += 3;
      reasons.add('Mismo municipio');
    } else if (currentState.isNotEmpty &&
        candidateState.isNotEmpty &&
        candidateState == currentState) {
      score += 1;
      reasons.add('Mismo estado');
    }

    if (currentAssigned.isNotEmpty &&
        candidateAssigned.isNotEmpty &&
        candidateAssigned == currentAssigned) {
      score += 1;
      reasons.add('Mismo responsable');
    }

    final overlap =
        currentKeywords.intersection(_historyKeywordsFor(candidate, const {}));
    if (overlap.length >= 2) {
      score += overlap.length >= 4 ? 4 : 2;
      reasons.add('Tema similar');
    }

    if (score >= 4) {
      matches.add(
        RelatedActivityMatch(
          activity: candidate,
          reasons: reasons.toList(growable: false),
          score: score,
        ),
      );
    }
  }

  matches.sort((left, right) {
    final scoreCompare = right.score.compareTo(left.score);
    if (scoreCompare != 0) return scoreCompare;
    return right.activity.createdAt.compareTo(left.activity.createdAt);
  });

  return matches.take(limit).toList(growable: false);
}

Set<String> _historyKeywordsFor(
  CompletedActivity activity,
  Map<String, dynamic> currentDataFields,
) {
  final values = <String>[
    activity.title,
    activity.activityType,
    activity.front,
    activity.estado,
    activity.municipio,
  ];

  for (final key in const [
    'topic',
    'topics',
    'tema',
    'temas',
    'subcategory',
    'subcategoria',
    'purpose',
    'proposito',
    'description',
    'descripcion',
    'comments',
    'comentarios',
    'result',
    'resultado',
  ]) {
    final raw = currentDataFields[key];
    if (raw == null) continue;
    if (raw is List) {
      values.addAll(raw.map((item) => item.toString()));
    } else if (raw is Map) {
      values.addAll(raw.values.map((item) => item.toString()));
    } else {
      values.add(raw.toString());
    }
  }

  final keywords = <String>{};
  for (final value in values) {
    keywords.addAll(_tokenizeHistoryText(value));
  }
  return keywords;
}

Set<String> _tokenizeHistoryText(String raw) {
  final normalized = raw
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9áéíóúñü\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (normalized.isEmpty) return const <String>{};

  const stopWords = {
    'de',
    'del',
    'la',
    'las',
    'el',
    'los',
    'para',
    'por',
    'con',
    'sin',
    'una',
    'uno',
    'unos',
    'unas',
    'que',
    'como',
    'mismo',
    'misma',
    'trato',
    'sobre',
  };

  return normalized
      .split(' ')
      .where((token) => token.length >= 3 && !stopWords.contains(token))
      .toSet();
}

List<CompletedActivity> resolveManualRelatedActivities({
  required CompletedActivity current,
  required List<String> relatedActivityIds,
  required List<CompletedActivity> candidates,
}) {
  final byId = <String, CompletedActivity>{
    for (final candidate in candidates) candidate.id: candidate,
  };

  final results = <CompletedActivity>[];
  final seen = <String>{};
  for (final rawId in relatedActivityIds) {
    final activityId = rawId.trim();
    if (activityId.isEmpty ||
        activityId == current.id ||
        !seen.add(activityId)) {
      continue;
    }
    final activity = byId[activityId];
    if (activity != null) {
      results.add(activity);
    }
  }
  return results;
}

// ── Filter options (for dropdowns) ────────────────────────────────────────────

class FilterOptions {
  final List<String> frentes;
  final List<String> temas;
  final List<String> estados;
  final List<String> municipios;
  final List<String> usuarios;

  const FilterOptions({
    required this.frentes,
    required this.temas,
    required this.estados,
    required this.municipios,
    required this.usuarios,
  });

  const FilterOptions.empty()
      : frentes = const [],
        temas = const [],
        estados = const [],
        municipios = const [],
        usuarios = const [];

  factory FilterOptions.fromJson(Map<String, dynamic> json) {
    List<String> parseList(String key) =>
        (json[key] as List?)?.map((e) => e.toString()).toList() ?? [];
    return FilterOptions(
      frentes: parseList('frentes'),
      temas: parseList('temas'),
      estados: parseList('estados'),
      municipios: parseList('municipios'),
      usuarios: parseList('usuarios'),
    );
  }
}

final completedFilterOptionsProvider =
    FutureProvider.autoDispose<FilterOptions>((ref) async {
  AppDataMode.requireRealBackendUrl();
  final projectId = ref.watch(completedProjectFilterProvider);
  final qs = projectId.isNotEmpty
      ? '?project_id=${Uri.encodeQueryComponent(projectId)}'
      : '';
  const client = BackendApiClient();
  final decoded =
      await client.getJson('/api/v1/completed-activities/filter-options$qs');
  if (decoded is! Map<String, dynamic>) return const FilterOptions.empty();
  return FilterOptions.fromJson(decoded);
});

// ── Data providers ─────────────────────────────────────────────────────────────

final completedActivitiesProvider =
    FutureProvider.autoDispose<List<CompletedActivity>>((ref) async {
  AppDataMode.requireRealBackendUrl();

  final projectId = ref.watch(completedProjectFilterProvider);
  final frente = ref.watch(completedFrenteFilterProvider);
  final tema = ref.watch(completedTemaFilterProvider);
  final estado = ref.watch(completedEstadoFilterProvider);
  final municipio = ref.watch(completedMunicipioFilterProvider);
  final usuario = ref.watch(completedUsuarioFilterProvider);
  final q = ref.watch(completedSearchQueryProvider);

  final params = <String, String>{};
  if (projectId.isNotEmpty) params['project_id'] = projectId;
  if (frente.isNotEmpty) params['frente'] = frente;
  if (tema.isNotEmpty) params['tema'] = tema;
  if (estado.isNotEmpty) params['estado'] = estado;
  if (municipio.isNotEmpty) params['municipio'] = municipio;
  if (usuario.isNotEmpty) params['usuario'] = usuario;
  if (q.isNotEmpty) params['q'] = q;

  final qs = params.entries
      .map((e) =>
          '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
      .join('&');
  final queryString = params.isEmpty ? '' : '?$qs';

  const client = BackendApiClient();
  final decoded =
      await client.getJson('/api/v1/completed-activities$queryString');

  if (decoded is! Map<String, dynamic>) return const [];
  final items = decoded['items'];
  if (items is! List) return const [];

  return items
      .whereType<Map<String, dynamic>>()
      .map(CompletedActivity.fromJson)
      .toList(growable: false);
});

final completedActivityDetailProvider = FutureProvider.autoDispose
    .family<CompletedActivityDetail, String>((ref, activityId) async {
  AppDataMode.requireRealBackendUrl();
  const client = BackendApiClient();
  final decoded =
      await client.getJson('/api/v1/completed-activities/$activityId');
  if (decoded is! Map<String, dynamic>) {
    throw Exception('Respuesta inesperada del servidor');
  }
  return CompletedActivityDetail.fromJson(decoded);
});

// ── Actions ────────────────────────────────────────────────────────────────────

Future<void> markReportGenerated(String activityId) async {
  const client = BackendApiClient();
  await client.postJson(
      '/api/v1/completed-activities/$activityId/mark-report-generated', {});
}

Future<List<ManualRelatedLink>> saveRelatedActivityLinks({
  required String activityId,
  required List<ManualRelatedLink> relatedLinks,
}) async {
  const client = BackendApiClient();
  final normalizedLinks = ManualRelatedLink.normalizeList(
    relatedLinks.map((item) => item.toJson()).toList(growable: false),
    currentId: activityId,
  );
  final decoded = await client.postJson(
    '/api/v1/completed-activities/$activityId/related-links',
    {
      'related_activity_ids': normalizedLinks
          .map((item) => item.activityId)
          .toList(growable: false),
      'related_links':
          normalizedLinks.map((item) => item.toJson()).toList(growable: false),
    },
  );

  if (decoded is Map<String, dynamic>) {
    return ManualRelatedLink.normalizeList(
      decoded['related_links'] ?? decoded['related_activity_ids'],
      currentId: activityId,
    );
  }

  return normalizedLinks;
}
