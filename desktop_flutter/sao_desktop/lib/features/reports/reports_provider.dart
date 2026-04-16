import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/providers/project_providers.dart';
import '../../core/settings/report_export_settings.dart';
import '../../data/catalog/activity_status.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/backend_api_client.dart';
import '../../data/repositories/evidence_repository.dart';

// ---------------------------------------------------------------------------
// Date range helper
// ---------------------------------------------------------------------------

class ReportDateRange {
  final DateTime start;
  final DateTime end;

  const ReportDateRange({required this.start, required this.end});
}

// ---------------------------------------------------------------------------
// Filter State
// ---------------------------------------------------------------------------

class ReportFilters {
  final String projectId;
  final String frontName;
  final ReportDateRange dateRange;
  final bool includeAlreadyReported;

  const ReportFilters({
    required this.projectId,
    required this.frontName,
    required this.dateRange,
    this.includeAlreadyReported = false,
  });

  ReportFilters copyWith({
    String? projectId,
    String? frontName,
    ReportDateRange? dateRange,
    bool? includeAlreadyReported,
  }) {
    return ReportFilters(
      projectId: projectId ?? this.projectId,
      frontName: frontName ?? this.frontName,
      dateRange: dateRange ?? this.dateRange,
      includeAlreadyReported: includeAlreadyReported ?? this.includeAlreadyReported,
    );
  }
}

final reportFiltersProvider = StateProvider<ReportFilters>((ref) {
  final now = DateTime.now();
  // Initial project comes from activeProjectIdProvider (set at login / project selector).
  // Falls back to empty; UI auto-selects once availableProjectsProvider resolves.
  final projectId = ref.watch(activeProjectIdProvider);
  return ReportFilters(
    projectId: projectId,
    frontName: 'Todos',
    dateRange: ReportDateRange(
      start: DateTime(now.year, now.month, 1),
      end: now,
    ),
  );
});

// Re-export shared provider under legacy name so existing UI code compiles unchanged.
final reportProjectsProvider = availableProjectsProvider;

// ---------------------------------------------------------------------------
// Activity model for reports
// ---------------------------------------------------------------------------

class ReportActivityItem {
  final String id;
  final String activityType;
  final String pk;
  final String frontName;
  final String status;
  final String? reviewDecision;
  final String? reviewStatus;
  final String createdAt;
  final String? assignedName;
  final String? projectId;
  final String? title;
  final String? purpose;
  final String? detail;
  final String? agreements;
  final String? municipality;
  final String? state;
  final String? colony;
  final String? riskLevel;
  final String? locationType;
  final String? pkStart;
  final String? pkEnd;
  final String? startTime;
  final String? endTime;
  final String? technicalLatitude;
  final String? technicalLongitude;
  final String? gpsPrecision;
  final bool isUnplanned;
  final String? unplannedReason;
  final String? referenceFolio;
  final String? subcategory;
  final List<String> topics;
  final List<String> attendees;
  final String? result;
  final String? notes;
  final bool pendingEvidence;
  final String? evidenceDueAt;
  final bool hasReport;
  final List<ReportEvidenceItem> evidences;

  const ReportActivityItem({
    required this.id,
    required this.activityType,
    required this.pk,
    required this.frontName,
    required this.status,
    this.reviewDecision,
    this.reviewStatus,
    required this.createdAt,
    this.assignedName,
    this.projectId,
    this.title,
    this.purpose,
    this.detail,
    this.agreements,
    this.municipality,
    this.state,
    this.colony,
    this.riskLevel,
    this.locationType,
    this.pkStart,
    this.pkEnd,
    this.startTime,
    this.endTime,
    this.technicalLatitude,
    this.technicalLongitude,
    this.gpsPrecision,
    this.isUnplanned = false,
    this.unplannedReason,
    this.referenceFolio,
    this.subcategory,
    this.topics = const [],
    this.attendees = const [],
    this.result,
    this.notes,
    this.pendingEvidence = false,
    this.evidenceDueAt,
    this.hasReport = false,
    this.evidences = const [],
  });

  factory ReportActivityItem.fromJson(Map<String, dynamic> json) {
    final evidencesRaw =
        (json['evidences'] ?? json['evidence'] ?? json['attachments']) as List?;
    return ReportActivityItem(
      id: (json['id'] ?? '').toString(),
      activityType: (json['activity_type'] ?? 'Actividad').toString(),
      pk: (json['pk'] ?? '-').toString(),
      frontName: (json['front'] ?? json['front_name'] ?? json['frente'] ?? 'Sin frente').toString(),
      status: (json['status'] ?? 'PENDIENTE_REVISION').toString(),
      reviewDecision: json['review_decision']?.toString(),
      reviewStatus: json['review_status']?.toString(),
      createdAt: (json['reviewed_at'] ?? json['last_reviewed_at'] ?? json['created_at'] ?? '').toString(),
      assignedName: (json['assignedName'] ?? json['assigned_name'])?.toString(),
      projectId: (json['project_id'])?.toString(),
      title: (json['title'] ?? json['activity_title'])?.toString(),
      purpose: _extractNestedString(json, const ['purpose', 'proposito', 'objetivo']),
      detail: _extractNestedString(
        json,
        const ['detail', 'description', 'descripcion', 'minuta', 'comments', 'comentarios'],
      ),
      agreements: _extractNestedString(
        json,
        const ['agreements', 'acuerdos', 'commitments', 'compromisos', 'report_agreements'],
      ),
      municipality: _extractNestedString(json, const ['municipality', 'municipio', 'localidad']),
      state: _extractNestedString(json, const ['state', 'estado']),
        colony: _extractNestedString(json, const ['colony', 'colonia']),
        riskLevel: _extractNestedString(json, const ['risk_level', 'risk', 'riesgo']),
        locationType: _extractNestedString(
          json,
          const ['location_type', 'ubicacion_tipo', 'locationScope'],
        ),
        pkStart: _extractNestedString(json, const ['pk_start', 'pk_inicio']),
        pkEnd: _extractNestedString(json, const ['pk_end', 'pk_fin']),
        startTime: _extractNestedString(
          json,
            const [
              'start_time',
              'hora_inicio',
              'horario_inicio',
              'horaatencioninicio',
              'draft_hora_inicio',
              'started_at',
              'startedAt',
            ],
        ),
        endTime: _extractNestedString(
          json,
            const [
              'end_time',
              'hora_fin',
              'horario_fin',
              'horaatencionfin',
              'draft_hora_fin',
              'finished_at',
              'finishedAt',
            ],
        ),
        technicalLatitude: _extractNestedString(
          json,
          const ['latitude', 'latitud', 'tech_latitude'],
        ),
        technicalLongitude: _extractNestedString(
          json,
          const ['longitude', 'longitud', 'tech_longitude'],
        ),
        gpsPrecision: _extractNestedString(
          json,
          const ['gps_precision', 'precision', 'precission'],
        ),
        isUnplanned: _parseBool(_extractNestedValue(json, const ['is_unplanned', 'no_planeada'])),
        unplannedReason: _extractNestedString(json, const ['unplanned_reason', 'motivo']),
        referenceFolio: _extractNestedString(json, const ['reference_folio', 'folio_referencia']),
        subcategory: _extractNestedString(json, const ['subcategory', 'subcategoria']),
        topics: _extractStringListFromJson(json, const ['topics', 'temas', 'temas_tratados']),
        attendees: _extractStringListFromJson(
          json,
          const ['attendees', 'assistants', 'involucrados', 'asistentes', 'autoridades'],
        ),
        result: _extractNestedString(json, const ['result', 'resultado', 'resultado_final']),
        notes: _extractNestedString(
          json,
          const ['notes', 'notas', 'review_notes', 'comentarios', 'report_notes'],
        ),
        pendingEvidence: _parseBool(
          _extractNestedValue(
            json,
            const ['pending_evidence', 'evidence_pending', 'requires_evidence'],
          ),
        ),
        evidenceDueAt: _extractNestedString(
          json,
          const ['evidence_due_at', 'fecha_limite_evidencia'],
        ),
        hasReport: _parseBool(
          _extractNestedValue(
            json,
            const ['has_report', 'report_generated', 'is_report_generated'],
          ),
        ),
      evidences: (evidencesRaw ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ReportEvidenceItem.fromJson)
          .toList(growable: false),
    );
  }

  bool get isApprovedForReport {
    final normalizedDecision = (reviewDecision ?? '').trim().toUpperCase();
    if (normalizedDecision == 'APPROVE' ||
        normalizedDecision == 'APPROVE_EXCEPTION') {
      return true;
    }

    final normalizedReview = (reviewStatus ?? '').trim().toUpperCase();
    if (normalizedReview == 'APPROVED' ||
        normalizedReview == 'APROBADO' ||
        normalizedReview == 'APROBADA') {
      return true;
    }

    final normalizedStatus = status.trim().toUpperCase();
    return normalizedStatus == 'APPROVED' ||
        normalizedStatus == 'APROBADO' ||
        normalizedStatus == 'APROBADA' ||
        normalizedStatus == 'VALIDATED' ||
        normalizedStatus == 'VALIDADO';
  }

  String get statusLabel {
    if (isApprovedForReport) {
      return 'Aprobado';
    }

    final normalizedReview = (reviewStatus ?? '').trim().toUpperCase();
    if (normalizedReview == 'REJECTED' || status.toUpperCase() == 'RECHAZADO') {
      return 'Rechazado';
    }
    if (normalizedReview == 'CHANGES_REQUIRED') {
      return 'Requiere cambios';
    }

    return switch (status.toUpperCase()) {
      'COMPLETADA' => 'Completada',
      'APPROVED' => 'Aprobado',
      'APROBADO' => 'Aprobado',
      'RECHAZADO' => 'Rechazado',
      'PENDIENTE_REVISION' => 'Pendiente revisión',
      _ => status,
    };
  }
}

class GeneratedReportReference {
  final String activityId;
  final String filePath;
  final String generatedAt;
  final String? generatedByUserId;
  final String? generatedByEmail;
  final String? sourceEvidenceId;
  final String source;

  const GeneratedReportReference({
    required this.activityId,
    required this.filePath,
    required this.generatedAt,
    this.generatedByUserId,
    this.generatedByEmail,
    this.sourceEvidenceId,
    this.source = 'local_generation',
  });

  String get fileName {
    final normalized = filePath.replaceAll('\\', '/');
    final segments = normalized.split('/');
    return segments.isEmpty ? filePath : segments.last;
  }
}

enum PdfStatusKind {
  cloud,       // uploaded to cloud (has sourceEvidenceId)
  localOnly,   // generated locally, not in cloud
  missingFile, // registered but file no longer on disk
}

class PdfStatusEntry {
  final String activityId;
  final String filePath;
  final String generatedAt;
  final String? generatedByEmail;
  final String? sourceEvidenceId;
  final PdfStatusKind status;

  const PdfStatusEntry({
    required this.activityId,
    required this.filePath,
    required this.generatedAt,
    this.generatedByEmail,
    this.sourceEvidenceId,
    required this.status,
  });

  String get fileName {
    final normalized = filePath.replaceAll('\\', '/');
    final segments = normalized.split('/');
    return segments.isEmpty ? filePath : segments.last;
  }
}

Future<List<PdfStatusEntry>> loadAllPdfStatusEntries() async {
  final registry = await _readReportRegistry();
  final activitiesRaw =
      (registry['activities'] as Map<String, dynamic>?) ?? const {};
  final results = <PdfStatusEntry>[];

  for (final entry in activitiesRaw.values) {
    if (entry is! Map<String, dynamic>) continue;
    final activityId = (entry['activity_id'] ?? '').toString().trim();
    final filePath = (entry['file_path'] ?? '').toString().trim();
    final generatedAt = (entry['generated_at'] ?? '').toString().trim();
    final generatedByEmail =
        (entry['generated_by_email'] ?? '').toString().trim();
    final sourceEvidenceId =
        (entry['source_evidence_id'] ?? '').toString().trim();

    if (activityId.isEmpty || filePath.isEmpty) continue;

    final fileExists = await File(filePath).exists();
    final PdfStatusKind kind;
    if (!fileExists) {
      kind = PdfStatusKind.missingFile;
    } else if (sourceEvidenceId.isNotEmpty) {
      kind = PdfStatusKind.cloud;
    } else {
      kind = PdfStatusKind.localOnly;
    }

    results.add(PdfStatusEntry(
      activityId: activityId,
      filePath: filePath,
      generatedAt: generatedAt,
      generatedByEmail: generatedByEmail.isEmpty ? null : generatedByEmail,
      sourceEvidenceId: sourceEvidenceId.isEmpty ? null : sourceEvidenceId,
      status: kind,
    ));
  }

  // Most recent first
  results.sort((a, b) => b.generatedAt.compareTo(a.generatedAt));
  return results;
}

/// Removes the registry entry for [activityId] so the PDF can be regenerated
/// and re-uploaded as a fresh evidence. Does not delete the file from disk.
Future<void> clearPdfRegistryEntry(String activityId) async {
  final trimmedId = activityId.trim();
  if (trimmedId.isEmpty) return;
  final registry = await _readReportRegistry();
  final activities = Map<String, dynamic>.from(
    (registry['activities'] as Map<String, dynamic>?) ?? const {},
  );
  activities.remove(trimmedId);
  final registryFile = await _reportRegistryFile();
  await registryFile.writeAsString(
    const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
      'activities': activities,
    }),
    flush: true,
  );
}

class ReportPdfCloudUploadResult {
  final Map<String, String> evidenceByActivityId;
  final Map<String, String> errorsByActivityId;

  const ReportPdfCloudUploadResult({
    required this.evidenceByActivityId,
    required this.errorsByActivityId,
  });
}

Future<File> _reportRegistryFile() async {
  final docsDir = await getApplicationDocumentsDirectory();
  final reportsRoot = Directory('${docsDir.path}/SAO_Reportes');
  if (!await reportsRoot.exists()) {
    await reportsRoot.create(recursive: true);
  }
  return File('${reportsRoot.path}/report_registry.json');
}

Future<Map<String, dynamic>> _readReportRegistry() async {
  final file = await _reportRegistryFile();
  if (!await file.exists()) {
    return <String, dynamic>{'activities': <String, dynamic>{}};
  }

  try {
    final raw = await file.readAsString();
    if (raw.trim().isEmpty) {
      return <String, dynamic>{'activities': <String, dynamic>{}};
    }
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      final activities = decoded['activities'];
      if (activities is Map<String, dynamic>) {
        return decoded;
      }
    }
  } catch (_) {
    // Ignore corrupt registry and rebuild it on next write.
  }

  return <String, dynamic>{'activities': <String, dynamic>{}};
}

Future<void> registerGeneratedReportReferences(
  List<ReportActivityItem> items,
  File file,
  {
    String? generatedByUserId,
    String? generatedByEmail,
    Map<String, String>? sourceEvidenceIdsByActivityId,
  }
) async {
  final registry = await _readReportRegistry();
  final activities = Map<String, dynamic>.from(
    (registry['activities'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
  );
  final now = DateTime.now().toIso8601String();

  for (final item in items) {
    final activityId = item.id.trim();
    if (activityId.isEmpty) continue;
    final sourceEvidenceId =
        (sourceEvidenceIdsByActivityId?[activityId] ?? '').trim();
    activities[activityId] = <String, dynamic>{
      'activity_id': activityId,
      'file_path': file.path,
      'generated_at': now,
      'generated_by_user_id': generatedByUserId,
      'generated_by_email': generatedByEmail,
      'source': sourceEvidenceId.isEmpty ? 'local_generation' : 'cloud_upload',
      if (sourceEvidenceId.isNotEmpty) 'source_evidence_id': sourceEvidenceId,
    };
  }

  final registryFile = await _reportRegistryFile();
  await registryFile.writeAsString(
    const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
      'activities': activities,
    }),
    flush: true,
  );
}

Future<ReportPdfCloudUploadResult> uploadGeneratedReportPdfToCloud(
  List<ReportActivityItem> items,
  File file,
) async {
  final bytes = await file.readAsBytes();
  if (bytes.isEmpty) {
    throw const FileSystemException('El PDF generado está vacío');
  }

  final fileName = file.uri.pathSegments.isEmpty
      ? 'reporte.pdf'
      : file.uri.pathSegments.last;
  final repository = EvidenceRepository();
  final evidenceByActivityId = <String, String>{};
  final errorsByActivityId = <String, String>{};

  for (final item in items) {
    final activityId = item.id.trim();
    if (activityId.isEmpty) {
      continue;
    }

    // If a report already exists for this activity and a PDF evidence is present,
    // reuse that evidence id to prevent creating duplicated report evidences.
    final existingReportEvidenceId = _pickExistingReportPdfEvidenceId(item);
    if (existingReportEvidenceId != null) {
      evidenceByActivityId[activityId] = existingReportEvidenceId;
      continue;
    }

    try {
      final init = await repository.uploadInit(
        activityId: activityId,
        fileName: fileName,
        sizeBytes: bytes.length,
      );
      await repository.uploadToSignedUrl(
        signedUrl: init.signedUrl,
        bytes: bytes,
      );
      await repository.uploadComplete(init.evidenceId);
      evidenceByActivityId[activityId] = init.evidenceId;
    } catch (error) {
      errorsByActivityId[activityId] = error.toString();
    }
  }

  return ReportPdfCloudUploadResult(
    evidenceByActivityId: evidenceByActivityId,
    errorsByActivityId: errorsByActivityId,
  );
}

String? _pickExistingReportPdfEvidenceId(ReportActivityItem item) {
  if (!item.hasReport || item.evidences.isEmpty) return null;

  final candidates = item.evidences
      .where((e) => e.id.trim().isNotEmpty)
      .where((e) {
        final typeToken = e.fileType.trim().toUpperCase();
        final pathToken = e.filePath.trim().toLowerCase();
        return typeToken.contains('PDF') ||
            typeToken.contains('DOCUMENT') ||
            pathToken.endsWith('.pdf');
      })
      .toList(growable: false);

  if (candidates.isEmpty) return null;

  final sorted = [...candidates]
    ..sort((a, b) {
      final ad = _tryParseDate(a.capturedAt ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bd = _tryParseDate(b.capturedAt ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    });

  return sorted.first.id.trim();
}

Future<void> registerDownloadedReportReference({
  required String activityId,
  required File file,
  required String sourceEvidenceId,
  String? generatedAt,
}) async {
  final trimmedActivityId = activityId.trim();
  if (trimmedActivityId.isEmpty) return;

  final trimmedEvidenceId = sourceEvidenceId.trim();
  final now = DateTime.now().toIso8601String();
  final trimmedGeneratedAt = (generatedAt ?? '').trim();
  final registry = await _readReportRegistry();
  final activities = Map<String, dynamic>.from(
    (registry['activities'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
  );

  activities[trimmedActivityId] = <String, dynamic>{
    'activity_id': trimmedActivityId,
    'file_path': file.path,
    'generated_at': trimmedGeneratedAt.isEmpty ? now : trimmedGeneratedAt,
    'source': 'evidence_download',
    'source_evidence_id': trimmedEvidenceId,
  };

  final registryFile = await _reportRegistryFile();
  await registryFile.writeAsString(
    const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
      'activities': activities,
    }),
    flush: true,
  );
}

Future<GeneratedReportReference?> findGeneratedReportReference(
  String activityId,
) async {
  final trimmedId = activityId.trim();
  if (trimmedId.isEmpty) return null;

  final registry = await _readReportRegistry();
  final activities =
      (registry['activities'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
  final entry = activities[trimmedId];
  if (entry is! Map<String, dynamic>) return null;

  final filePath = (entry['file_path'] ?? '').toString().trim();
  final generatedAt = (entry['generated_at'] ?? '').toString().trim();
  final generatedByUserId =
      (entry['generated_by_user_id'] ?? '').toString().trim();
  final generatedByEmail =
      (entry['generated_by_email'] ?? '').toString().trim();
  final sourceEvidenceId =
      (entry['source_evidence_id'] ?? '').toString().trim();
  final source = (entry['source'] ?? 'local_generation').toString().trim();
  if (filePath.isEmpty) return null;

  final file = File(filePath);
  if (!await file.exists()) {
    return null;
  }

  return GeneratedReportReference(
    activityId: trimmedId,
    filePath: filePath,
    generatedAt: generatedAt,
    generatedByUserId: generatedByUserId.isEmpty ? null : generatedByUserId,
    generatedByEmail: generatedByEmail.isEmpty ? null : generatedByEmail,
    sourceEvidenceId: sourceEvidenceId.isEmpty ? null : sourceEvidenceId,
    source: source.isEmpty ? 'local_generation' : source,
  );
}

Future<String?> findExistingLocalReportPath({
  required String activityId,
  required String projectId,
  required String front,
  required String state,
  required String municipality,
  required String activityType,
}) async {
  final reference = await findGeneratedReportReference(activityId);
  if (reference != null) {
    return reference.filePath;
  }

  final roots = <String>{};
  final appDocs = await getApplicationDocumentsDirectory();
  roots.add(appDocs.path);

  final home = Platform.isWindows
      ? Platform.environment['USERPROFILE']
      : Platform.environment['HOME'];
  if (home != null && home.trim().isNotEmpty) {
    roots.add('$home/Documents');
  }

  final projectFolder = _normalizeFolderSegment(projectId, fallback: 'GENERAL');
  final frontFolder = _normalizeFolderSegment(front, fallback: 'SIN_FRENTE');
  final stateFolder = _normalizeFolderSegment(state, fallback: 'SIN_ESTADO');
  final municipalityFolder = _normalizeFolderSegment(municipality, fallback: 'SIN_MUNICIPIO');
  final activityFolder = _normalizeFolderSegment(activityType, fallback: 'ACTIVIDAD');
  final expedienteFolder = _normalizeFolderSegment(activityId, fallback: 'SIN_ID');

  Future<String?> newestPdfIn(Directory dir) async {
    if (!await dir.exists()) return null;
    final pdfs = await dir
        .list()
        .where((entity) => entity is File && entity.path.toLowerCase().endsWith('.pdf'))
        .cast<File>()
        .toList();
    if (pdfs.isEmpty) return null;
    pdfs.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    return pdfs.first.path;
  }

  for (final root in roots) {
    final candidateDirs = <Directory>[
      Directory(
        '$root/SAO_Expedientes/$projectFolder/$frontFolder/$stateFolder/$municipalityFolder/$activityFolder/$expedienteFolder/Reportes',
      ),
      Directory(
        '$root/SAO_Expedientes/$projectFolder/$frontFolder/$stateFolder/$activityFolder/$expedienteFolder/Reportes',
      ),
      Directory(
        '$root/SAO_Expedientes/$projectFolder/$frontFolder/$activityFolder/$expedienteFolder/Reportes',
      ),
      Directory(
        '$root/SAO_Expedientes/$projectFolder/$frontFolder/$expedienteFolder/Reportes',
      ),
    ];

    for (final dir in candidateDirs) {
      final localPath = await newestPdfIn(dir);
      if (localPath != null) return localPath;
    }

    final baseDir = Directory('$root/SAO_Expedientes');
    if (!await baseDir.exists()) continue;

    final matches = <File>[];
    await for (final entity in baseDir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final lowerPath = entity.path.toLowerCase();
      if (!lowerPath.endsWith('.pdf')) continue;
      if (!entity.path.contains(expedienteFolder)) continue;
      matches.add(entity);
    }
    if (matches.isNotEmpty) {
      matches.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
      return matches.first.path;
    }
  }

  return null;
}

class ReportEvidenceItem {
  final String id;
  final String filePath;
  final String fileType;
  final String? caption;
  final String? latitude;
  final String? longitude;
  final String? capturedAt;

  const ReportEvidenceItem({
    required this.id,
    required this.filePath,
    required this.fileType,
    this.caption,
    this.latitude,
    this.longitude,
    this.capturedAt,
  });

  factory ReportEvidenceItem.fromJson(Map<String, dynamic> json) {
    return ReportEvidenceItem(
      id: (json['id'] ?? '').toString(),
      filePath: (json['file_path'] ??
              json['url'] ??
              json['path'] ??
              json['gcs_path'] ??
              json['storage_path'] ??
              '')
          .toString(),
      fileType: (json['file_type'] ?? json['type'] ?? 'IMAGE').toString(),
      caption: (json['caption'] ?? json['description'])?.toString(),
      latitude: json['latitude']?.toString(),
      longitude: json['longitude']?.toString(),
      capturedAt: (json['captured_at'] ?? json['created_at'])?.toString(),
    );
  }
}

final reportActivitiesProvider =
    FutureProvider.autoDispose<List<ReportActivityItem>>((ref) async {
  final filters = ref.watch(reportFiltersProvider);

  final backend = await _loadFromBackend(filters);
  if (backend.isNotEmpty) {
    return backend;
  }

  return _loadFromLocalDb(ref, filters);
});

bool _isAllFrontsFilter(String rawFront) {
  final normalized = rawFront.trim().toLowerCase();
  return normalized.isEmpty ||
      normalized == 'todos' ||
      normalized == 'todo' ||
      normalized == 'all' ||
      normalized == '*';
}

String _normalizeProjectFilter(String rawProject) =>
    rawProject.trim().toUpperCase();

bool _matchesSelectedProject(ReportActivityItem item, String rawProject) {
  final selectedProject = _normalizeProjectFilter(rawProject);
  if (selectedProject.isEmpty) return true;

  final itemProject = _normalizeProjectFilter(item.projectId ?? '');
  return itemProject == selectedProject;
}

bool _isWithinSelectedRange(String rawDate, ReportDateRange range) {
  final dt = _tryParseDate(rawDate);
  if (dt == null) return true;

  final start = DateTime(range.start.year, range.start.month, range.start.day);
  final end = DateTime(
    range.end.year,
    range.end.month,
    range.end.day,
    23,
    59,
    59,
    999,
  );
  return !dt.isBefore(start) && !dt.isAfter(end);
}

Future<List<ReportActivityItem>> _loadFromBackend(ReportFilters filters) async {
  const client = BackendApiClient();

  try {
    final queryParams = <String>[
      'project_id=${Uri.encodeQueryComponent(filters.projectId)}',
      'date_from=${Uri.encodeQueryComponent(filters.dateRange.start.toUtc().toIso8601String())}',
      'date_to=${Uri.encodeQueryComponent(filters.dateRange.end.toUtc().toIso8601String())}',
      'include_already_reported=${filters.includeAlreadyReported ? "true" : "false"}',
    ];
    if (!_isAllFrontsFilter(filters.frontName)) {
      queryParams.add('front=${Uri.encodeQueryComponent(filters.frontName)}');
    }

    final path = '/api/v1/reports/activities?${queryParams.join('&')}';
    final decoded = await client.getJson(path);
    if (decoded is! Map<String, dynamic>) {
      return _loadFromCompletedActivities(client, filters);
    }
    final items = decoded['items'] as List<dynamic>? ?? const [];

    final reportItems = items
        .whereType<Map<String, dynamic>>()
        .map((e) => ReportActivityItem.fromJson(e))
        .where((item) => _matchesSelectedProject(item, filters.projectId))
        .where((item) => item.isApprovedForReport)
        .where((item) => _isWithinSelectedRange(item.createdAt, filters.dateRange))
        .where((item) {
          if (!_isAllFrontsFilter(filters.frontName)) {
            return item.frontName
                .toLowerCase()
                .contains(filters.frontName.toLowerCase());
          }
          return true;
        })
        .toList(growable: false);

    if (reportItems.isNotEmpty) {
      return _hydrateReportItems(client, reportItems, filters.projectId);
    }

    return _loadFromCompletedActivities(client, filters);
  } catch (_) {
    return [];
  }
}

Future<List<ReportActivityItem>> _loadFromCompletedActivities(
  BackendApiClient client,
  ReportFilters filters,
) async {
  try {
    final queryParams = <String>[
      'project_id=${Uri.encodeQueryComponent(filters.projectId)}',
      'page=1',
      'page_size=200',
    ];
    if (!_isAllFrontsFilter(filters.frontName)) {
      queryParams.add('frente=${Uri.encodeQueryComponent(filters.frontName)}');
    }

    final decoded = await client.getJson(
      '/api/v1/completed-activities?${queryParams.join('&')}',
    );
    if (decoded is! Map<String, dynamic>) return [];
    final items = decoded['items'] as List<dynamic>? ?? const [];

    final baseItems = items
        .whereType<Map<String, dynamic>>()
        .map((raw) {
          final normalized = Map<String, dynamic>.from(raw);
          normalized['status'] ??= 'APROBADO';
          normalized['review_status'] ??= 'APPROVED';
          normalized['front_name'] ??= normalized['front'];
          normalized['activity_title'] ??= normalized['title'];
          normalized['created_at'] =
              normalized['reviewed_at'] ?? normalized['created_at'] ?? '';
          return ReportActivityItem.fromJson(normalized);
        })
        .where((item) => !item.hasReport)
        .where((item) => _matchesSelectedProject(item, filters.projectId))
        .where((item) => item.isApprovedForReport)
        .where((item) => _isWithinSelectedRange(item.createdAt, filters.dateRange))
        .toList(growable: false);

    return _hydrateReportItems(client, baseItems, filters.projectId);
  } catch (_) {
    return [];
  }
}

Future<List<ReportActivityItem>> _hydrateReportItems(
  BackendApiClient client,
  List<ReportActivityItem> items,
  String projectId,
) async {
  if (items.isEmpty) return const [];

  final enriched = await Future.wait(
    items.map((item) => _hydrateReportItem(client, item)),
  );

  final filtered = enriched
      .where((item) => _matchesSelectedProject(item, projectId))
      .toList(growable: false);

  filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return filtered;
}

Future<ReportActivityItem> _hydrateReportItem(
  BackendApiClient client,
  ReportActivityItem item,
) async {
  final needsDetails =
      (item.purpose?.trim().isNotEmpty != true) ||
      (item.detail?.trim().isNotEmpty != true) ||
      (item.agreements?.trim().isNotEmpty != true) ||
      item.topics.isEmpty ||
      item.attendees.isEmpty ||
        item.evidences.isEmpty ||
        ((item.startTime?.trim().isEmpty ?? true) &&
          (item.endTime?.trim().isEmpty ?? true));

  if (!needsDetails) {
    return item;
  }

  try {
    final decoded = await client.getJson(
      '/api/v1/completed-activities/${Uri.encodeComponent(item.id)}',
    );
    if (decoded is! Map<String, dynamic>) return item;

    final normalized = Map<String, dynamic>.from(decoded);
    try {
      final rawActivityDecoded = await client.getJson(
        '/api/v1/activities/${Uri.encodeComponent(item.id)}',
      );
      if (rawActivityDecoded is Map<String, dynamic>) {
        normalized['wizard_payload'] ??= rawActivityDecoded['wizard_payload'];
        normalized['data_fields'] ??= rawActivityDecoded['data_fields'];
        normalized['description'] ??= rawActivityDecoded['description'];
        normalized['latitude'] ??= rawActivityDecoded['latitude'];
        normalized['longitude'] ??= rawActivityDecoded['longitude'];
        normalized['activity_type'] ??= rawActivityDecoded['activity_type_code'];
        normalized['title'] ??= rawActivityDecoded['title'];
      }
    } catch (_) {}

    final detailEvidences = (normalized['evidences'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((evidence) => <String, dynamic>{
              'id': evidence['id'],
              'file_path': evidence['gcs_path'] ?? '',
              'file_type': evidence['type'] ?? 'PHOTO',
              'caption': evidence['description'] ?? '',
              'created_at': evidence['uploaded_at'] ?? '',
            })
        .toList(growable: false);
    final detailEvidenceById = <String, Map<String, dynamic>>{
      for (final evidence in detailEvidences)
        (evidence['id'] ?? '').toString(): evidence,
    };

    List<Map<String, dynamic>> reviewEvidences = const [];
    try {
      final reviewDecoded = await client.getJson(
        '/api/v1/review/activity/${Uri.encodeComponent(item.id)}/evidences',
      );
      if (reviewDecoded is List) {
        reviewEvidences = reviewDecoded
            .whereType<Map<String, dynamic>>()
            .map((evidence) {
              final evidenceId = (evidence['id'] ?? '').toString();
              final detailEvidence = detailEvidenceById[evidenceId] ?? const <String, dynamic>{};
              return <String, dynamic>{
                'id': evidence['id'],
                'file_path': evidence['gcsKey'] ?? detailEvidence['file_path'] ?? '',
                'file_type': detailEvidence['file_type'] ?? 'PHOTO',
                'caption': evidence['description'] ?? detailEvidence['caption'] ?? '',
                'captured_at': evidence['takenAt'] ?? '',
                'created_at': evidence['takenAt'] ?? detailEvidence['created_at'] ?? '',
              };
            })
            .where((evidence) => (evidence['id'] ?? '').toString().isNotEmpty)
            .toList(growable: false);
      }
    } catch (_) {}

    normalized['status'] ??= item.status;
    normalized['review_decision'] ??= item.reviewDecision;
    normalized['review_status'] ??=
        item.reviewStatus ?? (item.isApprovedForReport ? 'APPROVED' : null);
    normalized['project_id'] ??= item.projectId;
    normalized['activity_type'] ??= item.activityType;
    normalized['title'] ??= item.title ?? item.activityType;
    normalized['pk'] ??= item.pk;
    normalized['front'] ??= item.frontName;
    normalized['assigned_name'] ??= item.assignedName;
    normalized['municipality'] ??= item.municipality;
    normalized['state'] ??= item.state;
    normalized['created_at'] ??= item.createdAt;
    final resolvedEvidences = reviewEvidences.isNotEmpty ? reviewEvidences : detailEvidences;
    if (resolvedEvidences.isNotEmpty) {
      normalized['evidences'] = resolvedEvidences;
    }

    if ((normalized['start_time'] == null || normalized['start_time'].toString().trim().isEmpty) &&
        (normalized['end_time'] == null || normalized['end_time'].toString().trim().isEmpty)) {
      final evidenceTimes = resolvedEvidences
          .map((evidence) => _tryParseDate((evidence['captured_at'] ?? evidence['created_at'] ?? '').toString()))
          .whereType<DateTime>()
          .toList(growable: false)
        ..sort();
      if (evidenceTimes.isNotEmpty) {
        final first = evidenceTimes.first;
        final last = evidenceTimes.last;
        normalized['start_time'] = _formatTimeOnly(first);
        normalized['end_time'] = _formatTimeOnly(last);
      }
    }

    final enriched = ReportActivityItem.fromJson(normalized);
    return enriched.isApprovedForReport ? enriched : item;
  } catch (_) {
    return item;
  }
}

Future<List<ReportActivityItem>> _loadFromLocalDb(
  Ref ref,
    ReportFilters filters,
) async {
  final db = ref.read(databaseProvider);
  final query = db.select(db.activities)
    ..where((a) => a.status.equals(ActivityStatus.approved));

  final project = filters.projectId.trim();
  if (project.isNotEmpty) {
    query.where((a) => a.projectId.equals(project));
  }

    query.where((a) =>
      a.createdAt.isBiggerOrEqual(Variable<DateTime>(filters.dateRange.start)));
    query.where((a) => a.createdAt.isSmallerOrEqual(
      Variable<DateTime>(filters.dateRange.end.add(const Duration(days: 1)))));
  query.orderBy([(a) => OrderingTerm.desc(a.createdAt)]);

  final activities = await query.get();
  final results = <ReportActivityItem>[];
  final frontFilter = filters.frontName.trim().toLowerCase();

  for (final activity in activities) {
    final actType = await (db.select(db.activityTypes)
          ..where((t) => t.id.equals(activity.activityTypeId)))
        .getSingleOrNull();

    final front = activity.frontId == null
        ? null
        : await (db.select(db.fronts)..where((f) => f.id.equals(activity.frontId!)))
            .getSingleOrNull();

    final municipality = activity.municipalityId == null
        ? null
        : await (db.select(db.municipalities)
              ..where((m) => m.id.equals(activity.municipalityId!)))
            .getSingleOrNull();

    final evidences = await (db.select(db.evidences)
          ..where((e) => e.activityId.equals(activity.id))
          ..orderBy([(e) => OrderingTerm.asc(e.capturedAt)]))
        .get();

    final frontName = front?.name ?? 'Sin frente';
    if (frontFilter.isNotEmpty &&
        frontFilter != 'todos' &&
        !frontName.toLowerCase().contains(frontFilter)) {
      continue;
    }

    results.add(ReportActivityItem(
      id: activity.id,
      activityType: actType?.name ?? activity.title,
      pk: activity.description ?? '-',
      frontName: frontName,
      status: activity.status,
      createdAt: activity.createdAt.toIso8601String(),
      assignedName: activity.assignedTo,
      projectId: activity.projectId,
      title: activity.title,
      purpose: activity.reviewComments,
      detail: activity.description,
      agreements: activity.reviewComments,
      municipality: municipality?.name,
      state: municipality?.state,
      technicalLatitude: activity.latitude?.toString(),
      technicalLongitude: activity.longitude?.toString(),
      notes: activity.reviewComments,
      evidences: evidences
          .map((e) => ReportEvidenceItem(
                id: e.id,
                filePath: e.filePath,
                fileType: e.fileType,
                caption: e.caption,
                latitude: e.latitude?.toString(),
                longitude: e.longitude?.toString(),
                capturedAt: e.capturedAt.toIso8601String(),
              ))
          .toList(growable: false),
    ));
  }

  return results;
}

// ---------------------------------------------------------------------------
// PDF Generation
// ---------------------------------------------------------------------------

const _guinda = PdfColor.fromInt(0xFF9F2241);
const _textDark = PdfColor.fromInt(0xFF1F2937);
const _textGray = PdfColor.fromInt(0xFF6B7280);
const _borderGray = PdfColor.fromInt(0xFFE5E7EB);

const _defaultMembretePage1Asset = 'assets/images/membrete_page1.png';
const _defaultMembretePage2Asset = 'assets/images/membrete_page2.png';
const _defaultMembreteSingleAsset = 'assets/images/membrete.png';

const _membretePage1Path =
  String.fromEnvironment('SAO_MEMBRETE_PAGE1', defaultValue: '');
const _membretePage2Path =
  String.fromEnvironment('SAO_MEMBRETE_PAGE2', defaultValue: '');
const _membreteSinglePath =
  String.fromEnvironment('SAO_MEMBRETE_SINGLE', defaultValue: '');

/// Generates a PDF report for a list of activities and saves it to disk.
/// Returns the saved [File].
Future<Uint8List> buildActivitiesPdfBytes(
  List<ReportActivityItem> items,
  ReportFilters filters, {
  String executiveSummary = '',
  bool includeAudit = true,
  bool includeNotes = false,
  bool includeAttachments = true,
}) async {
  final pdf = pw.Document();
  final now = DateTime.now();
  final singleBackground = await _loadMembreteImage(
    explicitPath: _membreteSinglePath,
    fallbackAssetPath: _defaultMembreteSingleAsset,
  );
  final page1Background = await _loadMembreteImage(
    explicitPath: _membretePage1Path,
    fallbackAssetPath: _defaultMembretePage1Asset,
  ) ?? singleBackground;
  final page2Background = await _loadMembreteImage(
    explicitPath: _membretePage2Path,
    fallbackAssetPath: _defaultMembretePage2Asset,
  ) ?? singleBackground ?? page1Background;

  final hasTemplate = page1Background != null;

  final approvedItems = items.where((item) => item.isApprovedForReport).toList();
  final itemsToRender = approvedItems.isEmpty ? items : approvedItems;

  if (itemsToRender.isEmpty) {
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(56, 56, 56, 64),
        build: (_) => pw.Center(
          child: pw.Text(
            'Sin actividades aprobadas para generar reporte.',
            style: const pw.TextStyle(fontSize: 12, color: _textGray),
          ),
        ),
      ),
    );
  } else {
    for (var i = 0; i < itemsToRender.length; i++) {
      final item = itemsToRender[i];
      final activityDate = _tryParseDate(item.createdAt) ?? now;
      final allSummary = (executiveSummary.trim().isNotEmpty)
          ? executiveSummary.trim()
          : _buildNaturalDevelopmentNarrative(item);
        final agreements = item.agreements?.trim() ?? '';
      final shouldUseTwoPages =
          allSummary.length + agreements.length > 1200 && item.evidences.length >= 5;

      final firstPageMargin = _buildAdaptiveMargin(
        hasTemplate: hasTemplate,
        textLength: allSummary.length + agreements.length,
        evidenceCount: item.evidences.length,
        isAnnex: false,
      );
      final annexPageMargin = _buildAdaptiveMargin(
        hasTemplate: hasTemplate,
        textLength: allSummary.length,
        evidenceCount: item.evidences.length,
        isAnnex: true,
      );

      final resolvedEvidences = <_ResolvedEvidence>[];
      if (includeAttachments && item.evidences.isNotEmpty) {
        final sortedEvidences = item.evidences
            .where((e) => e.filePath.trim().isNotEmpty)
            .toList()
          ..sort((a, b) {
            final ad = _tryParseDate(a.capturedAt ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bd = _tryParseDate(b.capturedAt ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
            return ad.compareTo(bd);
          });
        final evidenceLimit = shouldUseTwoPages ? 5 : 2;
        for (final evidence in sortedEvidences.take(evidenceLimit)) {
          final bytes = await _loadEvidenceBytes(evidence);
          if (bytes == null || !_isSupportedImageFormat(bytes)) continue;
          pw.MemoryImage? image;
          try {
            image = pw.MemoryImage(bytes);
          } catch (_) {
            image = null;
          }
          if (image == null) continue;
          resolvedEvidences.add(
            _ResolvedEvidence(
              evidence: evidence,
              image: image,
            ),
          );
        }
      }

      pdf.addPage(
        pw.MultiPage(
          pageTheme: _buildPageTheme(page1Background, firstPageMargin),
          footer: (_) => pw.SizedBox(),
          build: (_) => [
            _buildTitleRow(item, activityDate),
            pw.SizedBox(height: 8),
            _buildGeneralData(item),
            pw.SizedBox(height: 8),
            _buildSectionTitle('2. ASUNTO Y DESARROLLO'),
            pw.SizedBox(height: 6),
            _buildNarrativeBlock(item, allSummary),
            pw.SizedBox(height: 6),
            _buildAgreementsBlock(agreements),
            pw.SizedBox(height: 8),
            _buildSectionTitle('3. INVOLUCRADOS / AUTORIDADES'),
            pw.SizedBox(height: 6),
            _buildAuthorities(item),
            if (item.pendingEvidence) ...[
              pw.SizedBox(height: 6),
              _buildPendingEvidenceBlock(item),
            ],
            if (includeAudit || includeNotes)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 8),
                child: pw.Text(
                  'Notas internas: ${includeNotes ? 'incluidas' : 'no incluidas'} · Auditoría: ${includeAudit ? 'incluida' : 'no incluida'}',
                  style: const pw.TextStyle(fontSize: 8, color: _textGray),
                ),
              ),
            if (includeAttachments &&
                resolvedEvidences.isNotEmpty &&
                !shouldUseTwoPages) ...[
              pw.SizedBox(height: 8),
              _buildSectionTitle('4. EVIDENCIA FOTOGRÁFICA'),
              pw.SizedBox(height: 6),
              ..._buildEvidenceGrid(resolvedEvidences, compact: true),
            ],
          ],
        ),
      );

      if (includeAttachments && resolvedEvidences.isNotEmpty && shouldUseTwoPages) {
        pdf.addPage(
          pw.MultiPage(
            pageTheme:
              _buildPageTheme(page2Background ?? page1Background, annexPageMargin),
            footer: (_) => pw.SizedBox(),
            build: (_) => [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Anexo fotográfico',
                    style: const pw.TextStyle(fontSize: 9, color: _textGray),
                  ),
                  pw.Text(
                    'Hoja 2 de 2',
                    style: const pw.TextStyle(fontSize: 8, color: _textGray),
                  ),
                ],
              ),
              pw.SizedBox(height: 6),
              _buildSectionTitle('4. EVIDENCIA FOTOGRÁFICA'),
              pw.SizedBox(height: 8),
              ..._buildEvidenceGrid(resolvedEvidences, compact: false),
            ],
          ),
        );
      }
    }
  }

  return pdf.save();
}

/// Generates a PDF report for a list of activities and saves it to disk.
/// Returns the saved [File].
Future<File> generateActivitiesPdf(
  List<ReportActivityItem> items,
  ReportFilters filters, {
  String executiveSummary = '',
  bool includeAudit = true,
  bool includeNotes = false,
  bool includeAttachments = true,
  String? saveRootPath,
  String? saveFilePath,
  bool keepExpedienteStructure = true,
}) async {
  final now = DateTime.now();
  final pdfBytes = await buildActivitiesPdfBytes(
    items,
    filters,
    executiveSummary: executiveSummary,
    includeAudit: includeAudit,
    includeNotes: includeNotes,
    includeAttachments: includeAttachments,
  );

  final normalizedProject = _normalizeFolderSegment(
    filters.projectId.trim().isEmpty ? 'GENERAL' : filters.projectId.trim(),
  );
  final fileName = _buildGeneratedReportFileName(
    projectId: normalizedProject,
    items: items,
    generatedAt: now,
  );

  final explicitFilePath = (saveFilePath ?? '').trim();
  if (explicitFilePath.isNotEmpty) {
    final file = File(explicitFilePath);
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    await file.writeAsBytes(pdfBytes, flush: true);
    return file;
  }

  if (!keepExpedienteStructure && (saveRootPath ?? '').trim().isNotEmpty) {
    final customDir = Directory(saveRootPath!.trim());
    if (!await customDir.exists()) {
      await customDir.create(recursive: true);
    }
    final file = File('${customDir.path}/$fileName');
    await file.writeAsBytes(pdfBytes, flush: true);
    return file;
  }

  // Save to documents / configured root using expediente structure.
  final docsRootPath = await _resolveUserDocumentsRootPath(
    customRootPath: saveRootPath,
  );
  final reportsDir = await _resolveExpedienteReportsDir(
    docsRootPath: docsRootPath,
    projectFolder: normalizedProject,
    items: items,
    generatedAt: now,
  );
  if (!await reportsDir.exists()) {
    await reportsDir.create(recursive: true);
  }

  final file = File('${reportsDir.path}/$fileName');
  await file.writeAsBytes(pdfBytes, flush: true);
  return file;
}

Future<String> _resolveUserDocumentsRootPath({String? customRootPath}) async {
  final custom = (customRootPath ?? '').trim();
  if (custom.isNotEmpty) {
    final customDir = Directory(custom);
    if (!await customDir.exists()) {
      await customDir.create(recursive: true);
    }
    return customDir.path;
  }

  final configuredRootPath = await ReportExportSettings.readDefaultRootPath();
  final configured = (configuredRootPath ?? '').trim();
  if (configured.isNotEmpty) {
    final configuredDir = Directory(configured);
    if (!await configuredDir.exists()) {
      await configuredDir.create(recursive: true);
    }
    return configuredDir.path;
  }

  String? home;
  if (Platform.isWindows) {
    home = Platform.environment['USERPROFILE'];
  } else {
    home = Platform.environment['HOME'];
  }

  if (home != null && home.trim().isNotEmpty) {
    final docsDir = Directory('$home/Documents');
    if (!await docsDir.exists()) {
      await docsDir.create(recursive: true);
    }
    return docsDir.path;
  }

  final appDocs = await getApplicationDocumentsDirectory();
  return appDocs.path;
}

String _buildGeneratedReportFileName({
  required String projectId,
  required List<ReportActivityItem> items,
  required DateTime generatedAt,
}) {
  final frontToken = _groupFolderSegment(
    items.map((item) => item.frontName),
    singleFallback: 'SIN_FRENTE',
    multiLabel: 'MULTI_FRENTE',
  );
  final stateToken = _groupFolderSegment(
    items.map((item) => item.state ?? ''),
    singleFallback: 'SIN_ESTADO',
    multiLabel: 'MULTI_ESTADO',
  );
  final activityToken = _groupFolderSegment(
    items.map((item) => item.activityType),
    singleFallback: 'ACTIVIDAD',
    multiLabel: 'MULTI_ACTIVIDAD',
  );
  final activityDateToken = _activityDateToken(items, generatedAt);
  return '${projectId}_${frontToken}_${stateToken}_${activityToken}_$activityDateToken.pdf';
}

String _activityDateToken(List<ReportActivityItem> items, DateTime generatedAt) {
  if (items.isEmpty) {
    return DateFormat('yyyyMMdd').format(generatedAt);
  }
  final dates = items
      .map((item) => _tryParseDate(item.createdAt))
      .whereType<DateTime>()
      .toList(growable: false)
    ..sort();
  if (dates.isEmpty) {
    return DateFormat('yyyyMMdd').format(generatedAt);
  }
  final first = DateFormat('yyyyMMdd').format(dates.first);
  final last = DateFormat('yyyyMMdd').format(dates.last);
  return first == last ? first : '${first}_A_$last';
}

Future<Directory> _resolveExpedienteReportsDir({
  required String docsRootPath,
  required String projectFolder,
  required List<ReportActivityItem> items,
  required DateTime generatedAt,
}) async {
  if (items.length == 1) {
    final item = items.first;
    final frontFolder = _normalizeFolderSegment(item.frontName, fallback: 'SIN_FRENTE');
    final stateFolder = _normalizeFolderSegment(item.state ?? '', fallback: 'SIN_ESTADO');
    final municipalityFolder = _normalizeFolderSegment(item.municipality ?? '', fallback: 'SIN_MUNICIPIO');
    final activityFolder = _normalizeFolderSegment(item.activityType, fallback: 'ACTIVIDAD');
    final expedienteFolder = _normalizeFolderSegment(item.id, fallback: 'SIN_ID');
    return Directory(
      '$docsRootPath/SAO_Expedientes/$projectFolder/$frontFolder/$stateFolder/$municipalityFolder/$activityFolder/$expedienteFolder/Reportes',
    );
  }

  final frontFolder = _groupFolderSegment(
    items.map((item) => item.frontName),
    singleFallback: 'SIN_FRENTE',
    multiLabel: 'MULTI_FRENTE',
  );
  final stateFolder = _groupFolderSegment(
    items.map((item) => item.state ?? ''),
    singleFallback: 'SIN_ESTADO',
    multiLabel: 'MULTI_ESTADO',
  );
  final lotFolder = 'LOTE_${DateFormat('yyyyMMdd_HHmm').format(generatedAt)}';
  return Directory(
    '$docsRootPath/SAO_Expedientes/$projectFolder/$frontFolder/$stateFolder/Lotes/$lotFolder/Reportes',
  );
}

String _groupFolderSegment(
  Iterable<String> rawValues, {
  required String singleFallback,
  required String multiLabel,
}) {
  final normalized = rawValues
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet();
  if (normalized.isEmpty) return singleFallback;
  if (normalized.length == 1) {
    return _normalizeFolderSegment(normalized.first, fallback: singleFallback);
  }
  return multiLabel;
}

String _normalizeFolderSegment(String raw, {String fallback = 'SIN_DATO'}) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return fallback;

  final sanitized = trimmed
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  if (sanitized.isEmpty) return fallback;
  return sanitized.length <= 80 ? sanitized : sanitized.substring(0, 80).trim();
}

DateTime? _tryParseDate(String raw) {
  try {
    return DateTime.parse(raw);
  } catch (_) {
    return null;
  }
}

/// Returns true only if [bytes] starts with magic bytes that the `pdf` package
/// recognises (JPEG, PNG, GIF, WebP, BMP, TIFF). Anything else (e.g. HEIC)
/// would throw "Unable to guess the image type" inside pw.MemoryImage.
bool _isSupportedImageFormat(Uint8List bytes) {
  if (bytes.length < 4) return false;
  // JPEG: FF D8 FF
  if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return true;
  // PNG: 89 50 4E 47
  if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) return true;
  // GIF87a / GIF89a: 47 49 46 38
  if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x38) return true;
  // BMP: 42 4D
  if (bytes[0] == 0x42 && bytes[1] == 0x4D) return true;
  // TIFF little-endian: 49 49 2A 00  big-endian: 4D 4D 00 2A
  if (bytes[0] == 0x49 && bytes[1] == 0x49 && bytes[2] == 0x2A && bytes[3] == 0x00) return true;
  if (bytes[0] == 0x4D && bytes[1] == 0x4D && bytes[2] == 0x00 && bytes[3] == 0x2A) return true;
  // WebP: RIFF????WEBP
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 &&
      bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50) {
    return true;
  }
  return false;
}

pw.EdgeInsets _buildAdaptiveMargin({
  required bool hasTemplate,
  required int textLength,
  required int evidenceCount,
  required bool isAnnex,
}) {
  if (!hasTemplate) {
    return const pw.EdgeInsets.fromLTRB(56, 56, 56, 64);
  }

  // Base area for the provided membretado.
  // Top margin adapts to content density to avoid large empty space.
  const leftRight = 71.0;
  const bottom = 88.0;

  if (isAnnex) {
    return const pw.EdgeInsets.fromLTRB(71, 148, 71, 88);
  }

  // Continuous model:
  // - More density => less top margin (use more page body)
  // - Less density => slightly larger top margin, but never excessive
  final density = textLength + (evidenceCount * 220);
  final normalized = (density / 1200).clamp(0.0, 1.0);
  final top = 162.0 - (normalized * 42.0); // Range ~120..162

  return pw.EdgeInsets.fromLTRB(leftRight, top, leftRight, bottom);
}

pw.Widget _buildTitleRow(ReportActivityItem item, DateTime activityDate) {
  final dateFmt = DateFormat("d 'de' MMMM, y", 'es_MX');
  return pw.Container(
    decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: _borderGray)),
    ),
    padding: const pw.EdgeInsets.only(bottom: 8),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                (item.title?.trim().isNotEmpty == true)
                    ? item.title!.trim().toUpperCase()
                    : item.activityType.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 14,
                  color: _guinda,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        pw.Text(dateFmt.format(activityDate), style: const pw.TextStyle(fontSize: 9, color: _textDark)),
      ],
    ),
  );
}

pw.Widget _buildGeneralData(ReportActivityItem item) {
  final location = [item.municipality, item.state, item.colony]
      .where((v) => (v ?? '').trim().isNotEmpty)
      .join(', ');
  final responsible = item.assignedName?.trim().isNotEmpty == true
      ? item.assignedName!.trim()
      : 'Personal operativo';

  return pw.Container(
    padding: const pw.EdgeInsets.all(8),
    decoration: pw.BoxDecoration(border: pw.Border.all(color: _borderGray)),
    child: pw.Column(
      children: [
        pw.Row(
          children: [
            _dataCell('1. Proyecto / Frente', '${item.projectId ?? '-'} / ${item.frontName}'),
            _dataCell('Ubicación administrativa', location.isEmpty ? 'Sin ubicación' : location),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          children: [
            _dataCell('Responsable', responsible),
            _dataCell('Horario atención', _formatTimeRange(item.startTime, item.endTime)),
          ],
        ),
      ],
    ),
  );
}

pw.Widget _dataCell(String label, String value) {
  return pw.Expanded(
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label.toUpperCase(), style: const pw.TextStyle(fontSize: 7, color: _textGray)),
        pw.SizedBox(height: 2),
        pw.Text(value, style: pw.TextStyle(fontSize: 9, color: _textDark, fontWeight: pw.FontWeight.bold)),
      ],
    ),
  );
}

pw.Widget _buildSectionTitle(String title) {
  return pw.Container(
    width: double.infinity,
    decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: _guinda, width: 1.5)),
    ),
    padding: const pw.EdgeInsets.only(bottom: 3),
    child: pw.Text(
      title,
      style: pw.TextStyle(
          fontSize: 10, color: _textDark, fontWeight: pw.FontWeight.bold),
    ),
  );
}

pw.Widget _buildNarrativeBlock(ReportActivityItem item, String text) {
  final topics = item.topics.isEmpty ? 'Sin temas capturados' : item.topics.join(', ');
  final purpose = item.purpose?.trim().isNotEmpty == true ? item.purpose!.trim() : 'Sin propósito capturado';
  final result = item.result?.trim().isNotEmpty == true ? item.result!.trim() : item.statusLabel;
  final notes = item.notes?.trim().isNotEmpty == true
      ? item.notes!.trim()
      : _buildNaturalDevelopmentNarrative(item, fallbackText: text);

  return pw.Container(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _kvText('Propósito', purpose),
        _kvText('Temas tratados', topics),
        _kvText('Desarrollo', notes),
        _kvText('Resultado final', result),
      ],
    ),
  );
}

pw.Widget _buildAgreementsBlock(String agreements) {
  final rows = agreements
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList(growable: false);
  return pw.Container(
    padding: const pw.EdgeInsets.all(8),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: _borderGray),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Seguimiento acordado',
            style: pw.TextStyle(fontSize: 9, color: _guinda, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        if (rows.isEmpty)
          pw.Text(
            'Sin compromisos adicionales registrados para seguimiento.',
              style: const pw.TextStyle(fontSize: 8.5, color: _textGray),
          ),
        ...rows.map((row) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                    pw.Text('• ', style: const pw.TextStyle(fontSize: 9, color: _textDark)),
                  pw.Expanded(
                      child: pw.Text(row, style: const pw.TextStyle(fontSize: 9, color: _textDark)),
                  ),
                ],
              ),
            )),
      ],
    ),
  );
}

pw.Widget _buildAuthorities(ReportActivityItem item) {
  final authorityRows = item.attendees.isNotEmpty
      ? item.attendees
      : <String>[
          if ((item.assignedName ?? '').trim().isNotEmpty)
            'Responsable operativo: ${item.assignedName!.trim()}',
          'Autoridades y participantes por confirmar',
        ];
  return pw.Wrap(
    spacing: 12,
    runSpacing: 6,
    children: authorityRows
        .map((row) => pw.Container(
              width: 220,
              padding: const pw.EdgeInsets.only(left: 6),
              decoration: const pw.BoxDecoration(
                border: pw.Border(left: pw.BorderSide(color: _borderGray, width: 2)),
              ),
              child: pw.Text(row, style: const pw.TextStyle(fontSize: 8.5, color: _textDark)),
            ))
        .toList(growable: false),
  );
}

List<pw.Widget> _buildEvidenceGrid(
  List<_ResolvedEvidence> evidences, {
  required bool compact,
}) {
  if (evidences.isEmpty) {
    return [
      pw.Text('Sin evidencia fotográfica disponible.',
          style: const pw.TextStyle(fontSize: 9, color: _textGray)),
    ];
  }

  final widgets = <pw.Widget>[];
  for (var i = 0; i < evidences.length; i += 2) {
    final left = evidences[i];
    final hasRight = i + 1 < evidences.length;

    if (!hasRight && evidences.length.isOdd && evidences.length >= 5) {
      widgets.add(_buildEvidenceCard(left, fullWidth: true, compact: compact));
      continue;
    }

    widgets.add(
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(child: _buildEvidenceCard(left, compact: compact)),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: hasRight
                ? _buildEvidenceCard(evidences[i + 1], compact: compact)
                : pw.SizedBox(),
          ),
        ],
      ),
    );
    widgets.add(pw.SizedBox(height: compact ? 6 : 10));
  }

  return widgets;
}

pw.Widget _buildEvidenceCard(
  _ResolvedEvidence evidence, {
  bool fullWidth = false,
  required bool compact,
}) {
  return pw.Container(
    width: fullWidth ? double.infinity : null,
    padding: const pw.EdgeInsets.all(4),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: _borderGray),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          height: compact ? 84 : (fullWidth ? 180 : 130),
          width: double.infinity,
          color: PdfColors.grey200,
          child: evidence.image == null
              ? pw.Center(
                  child: pw.Text('Sin imagen',
                style: const pw.TextStyle(fontSize: 9, color: _textGray)),
                )
              : pw.Image(evidence.image!, fit: pw.BoxFit.cover),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          evidence.evidence.caption?.trim().isNotEmpty == true
              ? evidence.evidence.caption!
              : 'Sin pie de foto',
          style: pw.TextStyle(fontSize: compact ? 7.5 : 8.5, color: _textDark),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          _buildEvidenceMeta(evidence.evidence),
          style: pw.TextStyle(fontSize: compact ? 6.7 : 7.4, color: _textGray),
        ),
      ],
    ),
  );
}

pw.Widget _buildPendingEvidenceBlock(ReportActivityItem item) {
  return pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(6),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: const PdfColor.fromInt(0xFFF59E0B), width: 0.7),
      color: const PdfColor.fromInt(0xFFFFFBEB),
    ),
    child: pw.Text(
      'Estatus: Pendiente de evidencia · Fecha límite: ${item.evidenceDueAt ?? 'Por definir'}',
      style: const pw.TextStyle(fontSize: 8.2, color: _textDark),
    ),
  );
}

pw.Widget _kvText(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 4),
    child: pw.RichText(
      text: pw.TextSpan(
        style: const pw.TextStyle(fontSize: 8.6, color: _textDark, lineSpacing: 2),
        children: [
          pw.TextSpan(text: '$label: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.TextSpan(text: value),
        ],
      ),
    ),
  );
}

String _buildEvidenceMeta(ReportEvidenceItem evidence) {
  final captured = _tryParseDate(evidence.capturedAt ?? '');
  final dateLabel = captured == null
      ? 's/f'
      : DateFormat('dd/MM/yyyy HH:mm', 'es_MX').format(captured);
  return 'Captura: $dateLabel';
}

String _formatTimeRange(String? start, String? end) {
  final s = _normalizeTimeValue(start);
  final e = _normalizeTimeValue(end);
  if ((s ?? '').isEmpty && (e ?? '').isEmpty) return 'N/D';
  if ((s ?? '').isNotEmpty && s == e) return s!;
  if ((s ?? '').isNotEmpty && (e ?? '').isEmpty) return s!;
  if ((s ?? '').isEmpty && (e ?? '').isNotEmpty) return e!;
  return '$s - $e';
}

String? _normalizeTimeValue(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return null;
  final parsed = _tryParseDate(value);
  if (parsed != null) {
    return _formatTimeOnly(parsed);
  }
  final hhmmMatch = RegExp(r'^(\d{1,2}:\d{2})(?::\d{2})?$').firstMatch(value);
  if (hhmmMatch != null) {
    return hhmmMatch.group(1);
  }
  return value;
}

String _formatTimeOnly(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _buildNaturalDevelopmentNarrative(
  ReportActivityItem item, {
  String? fallbackText,
}) {
  final preferredDetail = item.detail?.trim();
  if (preferredDetail != null &&
      preferredDetail.isNotEmpty &&
      !_looksSystemGeneratedNarrative(preferredDetail)) {
    return preferredDetail;
  }

  final activityLabel = _humanActivityLabel(item);
  final subcategory = item.subcategory?.trim();
  final location = _joinNonEmpty([
    item.municipality?.trim(),
    item.state?.trim(),
  ]);
  final frontLabel = _joinNonEmpty([
    item.projectId?.trim(),
    item.frontName.trim().isEmpty ? null : item.frontName.trim(),
  ], separator: ' / ');
  final purpose = item.purpose?.trim();
  final topics = item.topics.where((topic) => topic.trim().isNotEmpty).toList(growable: false);
  final attendees = item.attendees.where((attendee) => attendee.trim().isNotEmpty).toList(growable: false);
  final result = item.result?.trim();

  final sentences = <String>[];

  final openingParts = <String>[_activityOpening(item, activityLabel)];
  if (subcategory != null && subcategory.isNotEmpty) {
      openingParts.add('dentro de la subcategoría ${_lowercaseFirst(subcategory)}');
  }
  if (location.isNotEmpty) {
    openingParts.add('en $location');
  }
  if (frontLabel.isNotEmpty) {
      openingParts.add('en el proyecto $frontLabel');
  }
  sentences.add('${openingParts.join(' ')}.');

  if (purpose != null && purpose.isNotEmpty) {
    sentences.add('La actividad tuvo como propósito ${_lowercaseFirst(purpose)}.');
  }

  if (topics.isNotEmpty) {
    sentences.add('Durante su desarrollo se abordaron ${_naturalList(topics)}.');
  }

  if (attendees.isNotEmpty) {
    sentences.add('Se contó con la participación de ${_naturalList(attendees)}.');
  }

  if (result != null && result.isNotEmpty) {
    sentences.add('Como resultado, ${_lowercaseFirst(result)}.');
  }

  final generated = sentences.join(' ');
  if (generated.trim().isNotEmpty) {
    return generated.trim();
  }

  final fallback = fallbackText?.trim();
  if (fallback != null && fallback.isNotEmpty) {
    return fallback;
  }

  return 'Actividad registrada para seguimiento operativo y generación de reporte ejecutivo.';
}

String buildReportNaturalNarrative(ReportActivityItem item, {String? fallbackText}) {
  return _buildNaturalDevelopmentNarrative(item, fallbackText: fallbackText);
}

bool _looksSystemGeneratedNarrative(String value) {
  final normalized = value.trim().toLowerCase();
  return normalized.startsWith('actividad:') ||
      normalized.startsWith('actividad realizada en ') ||
      normalized.startsWith('actividad validada para emision') ||
      normalized.startsWith('actividad validada para emisión') ||
      value.contains('|');
}

String _humanActivityLabel(ReportActivityItem item) {
  final title = item.title?.trim();
  if (title != null && title.isNotEmpty) {
    return _lowercaseFirst(title);
  }
  return _lowercaseFirst(item.activityType.trim());
}

String _activityOpening(ReportActivityItem item, String activityLabel) {
  final raw = [item.title, item.activityType]
      .whereType<String>()
      .map((value) => value.trim().toLowerCase())
      .firstWhere((value) => value.isNotEmpty, orElse: () => activityLabel.toLowerCase());

  if (raw.contains('caminamiento')) {
    return 'Se llevó a cabo un caminamiento';
  }
  if (raw.contains('reun')) {
    return 'Se celebró una reunión de trabajo';
  }
  if (raw.contains('asamblea')) {
    return 'Se realizó una asamblea';
  }
  if (raw.contains('socializ')) {
    return 'Se desarrolló una jornada de socialización';
  }
  if (raw.contains('acompañamiento')) {
    return 'Se brindó acompañamiento institucional';
  }
  return 'Se realizó la actividad de $activityLabel';
}

String _lowercaseFirst(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return trimmed;
  return '${trimmed[0].toLowerCase()}${trimmed.substring(1)}';
}

String _joinNonEmpty(List<String?> values, {String separator = ', '}) {
  return values
      .whereType<String>()
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .join(separator);
}

String _naturalList(List<String> values) {
  final cleaned = values
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList(growable: false);
  if (cleaned.isEmpty) return '';
  if (cleaned.length == 1) return cleaned.first;
  if (cleaned.length == 2) return '${cleaned.first} y ${cleaned.last}';
  final head = cleaned.sublist(0, cleaned.length - 1).join(', ');
  return '$head y ${cleaned.last}';
}

final _evidenceRepository = EvidenceRepository();
final Map<String, Future<String?>> _evidenceSourceCache = {};

Future<String?> _resolveEvidenceSource(ReportEvidenceItem evidence) {
  final rawPath = evidence.filePath.trim();
  final cacheKey = '${evidence.id}|$rawPath';

  return _evidenceSourceCache.putIfAbsent(cacheKey, () async {
    if (rawPath.isNotEmpty) {
      if (rawPath.startsWith('http://') ||
          rawPath.startsWith('https://') ||
          rawPath.startsWith('file://')) {
        return rawPath;
      }

      final localFile = File(rawPath);
      if (await localFile.exists()) {
        return localFile.path;
      }
    }

    if (evidence.id.trim().isEmpty) {
      return null;
    }

    try {
      return await _evidenceRepository.getDownloadSignedUrl(evidence.id);
    } catch (_) {
      return null;
    }
  });
}

Future<Uint8List?> _loadEvidenceBytes(ReportEvidenceItem evidence) async {
  final path = await _resolveEvidenceSource(evidence);
  if (path == null || path.trim().isEmpty) {
    return null;
  }

  try {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(path));
      final response = await request.close();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final builder = BytesBuilder(copy: false);
        await for (final chunk in response) {
          builder.add(chunk);
        }
        final bytes = builder.toBytes();
        client.close(force: true);
        return bytes;
      }
      client.close(force: true);
      return null;
    }

    final file = path.startsWith('file://')
        ? File(Uri.parse(path).toFilePath())
        : File(path);
    if (await file.exists()) {
      return file.readAsBytes();
    }
  } catch (_) {
    return null;
  }
  return null;
}

Future<pw.MemoryImage?> _loadMembreteImage({
  required String explicitPath,
  required String fallbackAssetPath,
}) async {
  final cleanPath = explicitPath.trim();

  if (cleanPath.isNotEmpty) {
    final file = File(cleanPath);
    if (await file.exists()) {
      try {
        final bytes = await file.readAsBytes();
        if (_isSupportedImageFormat(bytes)) return pw.MemoryImage(bytes);
      } catch (_) {
        // Archivo de membrete inválido — usar recurso predeterminado.
      }
    }
  }

  try {
    final asset = await rootBundle.load(fallbackAssetPath);
    return pw.MemoryImage(asset.buffer.asUint8List());
  } catch (_) {
    return null;
  }
}

pw.PageTheme _buildPageTheme(
  pw.MemoryImage? background,
  pw.EdgeInsetsGeometry margin,
) {
  if (background == null) {
    return pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      margin: margin,
    );
  }

  return pw.PageTheme(
    pageFormat: PdfPageFormat.a4,
    margin: margin,
    buildBackground: (_) => pw.FullPage(
      ignoreMargins: true,
      child: pw.Image(background, fit: pw.BoxFit.fill),
    ),
  );
}

String _normalizeFieldKey(String key) =>
    key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

bool _hasMeaningfulValue(dynamic value) {
  if (value == null) return false;
  if (value is String) return value.trim().isNotEmpty;
  if (value is List) return value.isNotEmpty;
  if (value is Map) return value.isNotEmpty;
  return true;
}

dynamic _findInMap(Map<String, dynamic> source, List<String> candidates) {
  final normalized = <String, dynamic>{};
  source.forEach((key, value) {
    normalized[_normalizeFieldKey(key)] = value;
  });

  for (final candidate in candidates) {
    final value = normalized[_normalizeFieldKey(candidate)];
    if (_hasMeaningfulValue(value)) {
      return value;
    }
  }
  return null;
}

dynamic _findDeepValue(dynamic source, List<String> candidates) {
  if (source is Map) {
    final normalizedSource = source.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    final direct = _findInMap(normalizedSource, candidates);
    if (_hasMeaningfulValue(direct)) {
      return direct;
    }
    for (final value in normalizedSource.values) {
      final nested = _findDeepValue(value, candidates);
      if (_hasMeaningfulValue(nested)) {
        return nested;
      }
    }
  }

  if (source is List) {
    for (final value in source) {
      final nested = _findDeepValue(value, candidates);
      if (_hasMeaningfulValue(nested)) {
        return nested;
      }
    }
  }

  return null;
}

dynamic _extractNestedValue(Map<String, dynamic> json, List<String> candidates) {
  final topLevel = _findInMap(json, candidates);
  if (_hasMeaningfulValue(topLevel)) {
    return topLevel;
  }

  final dataFields = json['data_fields'];
  if (dataFields is Map) {
    final nested = dataFields.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    final dataFieldsValue = _findDeepValue(nested, candidates);
    if (_hasMeaningfulValue(dataFieldsValue)) {
      return dataFieldsValue;
    }
  }

  final wizardPayload = json['wizard_payload'] ?? json['wizardPayload'];
  final wizardValue = _findDeepValue(wizardPayload, candidates);
  if (_hasMeaningfulValue(wizardValue)) {
    return wizardValue;
  }

  return null;
}

String _stringifyValue(dynamic value) {
  if (value == null) return '';
  if (value is List) {
    return value
        .map(_stringifyValue)
        .where((entry) => entry.isNotEmpty)
        .join(', ');
  }
  if (value is Map) {
    final normalized = value.map(
      (key, nestedValue) => MapEntry(_normalizeFieldKey(key.toString()), nestedValue),
    );
    for (final preferredKey in const [
      'name',
      'label',
      'title',
      'descripcion',
      'description',
      'representativename',
      'reason',
      'othertext',
      'reference',
      'value',
    ]) {
      final preferredValue = normalized[preferredKey];
      final text = _stringifyValue(preferredValue);
      if (text.isNotEmpty) {
        return text;
      }
    }

    return normalized.values
        .map(_stringifyValue)
        .where((entry) => entry.isNotEmpty)
        .join(', ');
  }
  final text = value.toString().trim();
  return text == 'null' ? '' : text;
}

String? _extractNestedString(Map<String, dynamic> json, List<String> candidates) {
  final value = _extractNestedValue(json, candidates);
  final text = _stringifyValue(value);
  return text.isEmpty ? null : text;
}

List<String> _extractStringListFromJson(
  Map<String, dynamic> json,
  List<String> candidates,
) {
  return _parseStringList(_extractNestedValue(json, candidates));
}

bool _parseBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final raw = value?.toString().trim().toLowerCase();
  return raw == 'true' || raw == '1' || raw == 'si' || raw == 'sí';
}

List<String> _parseStringList(dynamic raw) {
  if (raw is List) {
    return raw
        .map((entry) {
          if (entry is Map) {
            final normalized = entry.map(
              (key, value) => MapEntry(_normalizeFieldKey(key.toString()), value),
            );
            final name = _stringifyValue(normalized['name']);
            final representativeName = _stringifyValue(normalized['representativename']);
            if (name.isNotEmpty && representativeName.isNotEmpty) {
              return '$name - $representativeName';
            }
            if (name.isNotEmpty) {
              return name;
            }
            return _stringifyValue(normalized);
          }
          return entry.toString().trim();
        })
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }
  if (raw is Map) {
    return raw.values
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }
  if (raw is String) {
    return raw
        .split(RegExp(r'[\n;,|•]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }
  return const [];
}

class _ResolvedEvidence {
  final ReportEvidenceItem evidence;
  final pw.MemoryImage? image;

  const _ResolvedEvidence({required this.evidence, required this.image});
}
