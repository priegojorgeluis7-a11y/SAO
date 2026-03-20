import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/backend_api_client.dart';
import '../../core/config/data_mode.dart';

// ── Filter state ───────────────────────────────────────────────────────────────

final completedProjectFilterProvider   = StateProvider<String>((ref) => '');
final completedFrenteFilterProvider    = StateProvider<String>((ref) => '');
final completedTemaFilterProvider      = StateProvider<String>((ref) => '');
final completedEstadoFilterProvider    = StateProvider<String>((ref) => '');
final completedMunicipioFilterProvider = StateProvider<String>((ref) => '');
final completedUsuarioFilterProvider   = StateProvider<String>((ref) => '');
final completedSearchQueryProvider     = StateProvider<String>((ref) => '');

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
    required this.reviewedAt,
    required this.createdAt,
    required this.evidenceCount,
    required this.assignedName,
    required this.reviewedByName,
    required this.reviewDecision,
  });

  factory CompletedActivity.fromJson(Map<String, dynamic> json) {
    return CompletedActivity(
      id:             (json['id'] ?? '').toString(),
      projectId:      (json['project_id'] ?? '').toString(),
      title:          (json['title'] ?? '').toString(),
      activityType:   (json['activity_type'] ?? '').toString(),
      pk:             (json['pk'] ?? '').toString(),
      front:          (json['front'] ?? '').toString(),
      estado:         (json['estado'] ?? '').toString(),
      municipio:      (json['municipio'] ?? '').toString(),
      hasReport:      (json['has_report'] as bool?) ?? false,
      reviewedAt:     (json['reviewed_at'] ?? '').toString(),
      createdAt:      (json['created_at'] ?? '').toString(),
      evidenceCount:  (json['evidence_count'] as num?)?.toInt() ?? 0,
      assignedName:   (json['assigned_name'] ?? '').toString(),
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
      id:         (json['id'] ?? '').toString(),
      action:     (json['action'] ?? '').toString(),
      actorEmail: (json['actor_email'] ?? '').toString(),
      actorName:  (json['actor_name'] ?? '').toString(),
      changes:    (json['changes'] as Map<String, dynamic>?) ?? {},
      notes:      (json['notes'] ?? '').toString(),
      timestamp:  (json['timestamp'] ?? '').toString(),
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
      id:           (json['id'] ?? '').toString(),
      type:         (json['type'] ?? '').toString(),
      description:  (json['description'] ?? '').toString(),
      gcsPath:      (json['gcs_path'] ?? '').toString(),
      uploadedAt:   (json['uploaded_at'] ?? '').toString(),
      uploaderName: (json['uploader_name'] ?? '').toString(),
    );
  }
}

class CompletedActivityDetail {
  final CompletedActivity summary;
  final String colonia;
  final String reviewNotes;
  final Map<String, dynamic> dataFields;
  final List<AuditEntry> auditTrail;
  final List<EvidenceItem> evidences;
  final int syncVersion;

  const CompletedActivityDetail({
    required this.summary,
    required this.colonia,
    required this.reviewNotes,
    required this.dataFields,
    required this.auditTrail,
    required this.evidences,
    required this.syncVersion,
  });

  factory CompletedActivityDetail.fromJson(Map<String, dynamic> json) {
    return CompletedActivityDetail(
      summary:     CompletedActivity.fromJson(json),
      colonia:     (json['colonia'] ?? '').toString(),
      reviewNotes: (json['review_notes'] ?? '').toString(),
      dataFields:  (json['data_fields'] as Map<String, dynamic>?) ?? {},
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
      syncVersion: (json['sync_version'] as num?)?.toInt() ?? 0,
    );
  }
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
      : frentes    = const [],
        temas      = const [],
        estados    = const [],
        municipios = const [],
        usuarios   = const [];

  factory FilterOptions.fromJson(Map<String, dynamic> json) {
    List<String> _list(String key) =>
        (json[key] as List?)?.map((e) => e.toString()).toList() ?? [];
    return FilterOptions(
      frentes:    _list('frentes'),
      temas:      _list('temas'),
      estados:    _list('estados'),
      municipios: _list('municipios'),
      usuarios:   _list('usuarios'),
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
  final frente    = ref.watch(completedFrenteFilterProvider);
  final tema      = ref.watch(completedTemaFilterProvider);
  final estado    = ref.watch(completedEstadoFilterProvider);
  final municipio = ref.watch(completedMunicipioFilterProvider);
  final usuario   = ref.watch(completedUsuarioFilterProvider);
  final q         = ref.watch(completedSearchQueryProvider);

  final params = <String, String>{};
  if (projectId.isNotEmpty) params['project_id'] = projectId;
  if (frente.isNotEmpty)    params['frente']      = frente;
  if (tema.isNotEmpty)      params['tema']        = tema;
  if (estado.isNotEmpty)    params['estado']      = estado;
  if (municipio.isNotEmpty) params['municipio']   = municipio;
  if (usuario.isNotEmpty)   params['usuario']     = usuario;
  if (q.isNotEmpty)         params['q']           = q;

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

final completedActivityDetailProvider =
    FutureProvider.autoDispose.family<CompletedActivityDetail, String>(
        (ref, activityId) async {
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
