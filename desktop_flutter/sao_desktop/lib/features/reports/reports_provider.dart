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

  const ReportFilters({
    required this.projectId,
    required this.frontName,
    required this.dateRange,
  });

  ReportFilters copyWith({
    String? projectId,
    String? frontName,
    ReportDateRange? dateRange,
  }) {
    return ReportFilters(
      projectId: projectId ?? this.projectId,
      frontName: frontName ?? this.frontName,
      dateRange: dateRange ?? this.dateRange,
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
        const ['agreements', 'acuerdos', 'commitments', 'compromisos'],
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
          const ['start_time', 'hora_inicio', 'horario_inicio', 'horaatencioninicio'],
        ),
        endTime: _extractNestedString(
          json,
          const ['end_time', 'hora_fin', 'horario_fin', 'horaatencionfin'],
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
        notes: _extractNestedString(json, const ['notes', 'notas', 'review_notes', 'comentarios']),
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
      return _hydrateReportItems(client, reportItems);
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
        .where((item) => item.isApprovedForReport)
        .where((item) => _isWithinSelectedRange(item.createdAt, filters.dateRange))
        .toList(growable: false);

    return _hydrateReportItems(client, baseItems);
  } catch (_) {
    return [];
  }
}

Future<List<ReportActivityItem>> _hydrateReportItems(
  BackendApiClient client,
  List<ReportActivityItem> items,
) async {
  if (items.isEmpty) return const [];

  final enriched = await Future.wait(
    items.map((item) => _hydrateReportItem(client, item)),
  );

  enriched.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return enriched;
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
      item.evidences.isEmpty;

  if (!needsDetails) {
    return item;
  }

  try {
    final decoded = await client.getJson(
      '/api/v1/completed-activities/${Uri.encodeComponent(item.id)}',
    );
    if (decoded is! Map<String, dynamic>) return item;

    final normalized = Map<String, dynamic>.from(decoded);
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
    if (detailEvidences.isNotEmpty) {
      normalized['evidences'] = detailEvidences;
    }

    final enriched = ReportActivityItem.fromJson(normalized);
    return enriched.isApprovedForReport ? enriched : item;
  } catch (_) {
    return item;
  }
}

Future<List<ReportActivityItem>> _loadFromLocalDb(
    AutoDisposeFutureProviderRef<List<ReportActivityItem>> ref,
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
Future<File> generateActivitiesPdf(
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
            style: pw.TextStyle(fontSize: 12, color: _textGray),
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
          : (item.detail?.trim().isNotEmpty == true
              ? item.detail!.trim()
              : 'Actividad registrada para seguimiento operativo y generación de reporte ejecutivo.');
      final agreements = (item.agreements?.trim().isNotEmpty == true)
          ? item.agreements!.trim()
          : '1. Dar seguimiento semanal.\n2. Integrar evidencia de campo.\n3. Confirmar cierre operativo.';
      final shouldUseTwoPages =
          allSummary.length + agreements.length > 860 || item.evidences.length >= 4;

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
        final sortedEvidences = [...item.evidences]
          ..sort((a, b) {
            final ad = _tryParseDate(a.capturedAt ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bd = _tryParseDate(b.capturedAt ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
            return ad.compareTo(bd);
          });
        final evidenceLimit = shouldUseTwoPages ? 5 : 2;
        for (final evidence in sortedEvidences.take(evidenceLimit)) {
          final bytes = await _loadEvidenceBytes(evidence);
          resolvedEvidences.add(
            _ResolvedEvidence(
              evidence: evidence,
              image: bytes == null ? null : pw.MemoryImage(bytes),
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
            _buildExecutiveHeader(item, activityDate),
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
                  style: pw.TextStyle(fontSize: 8, color: _textGray),
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
                    style: pw.TextStyle(fontSize: 9, color: _textGray),
                  ),
                  pw.Text(
                    'Hoja 2 de 2',
                    style: pw.TextStyle(fontSize: 8, color: _textGray),
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

  // Save to documents
  final docsDir = await getApplicationDocumentsDirectory();
  final reportsDir = Directory('${docsDir.path}/SAO_Reportes');
  if (!await reportsDir.exists()) {
    await reportsDir.create(recursive: true);
  }

  final fileName =
      'SAO_${filters.projectId}_${DateFormat('yyyyMMdd_HHmm').format(now)}.pdf';
  final file = File('${reportsDir.path}/$fileName');
  await file.writeAsBytes(await pdf.save());
  return file;
}

DateTime? _tryParseDate(String raw) {
  try {
    return DateTime.parse(raw);
  } catch (_) {
    return null;
  }
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
  final leftRight = 71.0;
  final bottom = 88.0;

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

pw.Widget _buildMembreteHeader(int year) {
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Comunicaciones',
                  style: pw.TextStyle(
                      fontSize: 12, fontWeight: pw.FontWeight.bold, color: _textDark)),
              pw.Text(
                'Secretaría de Infraestructura,\nComunicaciones y Transportes',
                style: pw.TextStyle(fontSize: 8, color: _textGray),
              ),
            ],
          ),
          pw.SizedBox(width: 10),
          pw.Container(width: 1, height: 30, color: _borderGray),
          pw.SizedBox(width: 10),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('TRENES',
                  style: pw.TextStyle(
                      fontSize: 12, fontWeight: pw.FontWeight.bold, color: _textDark)),
              pw.Text(
                'Agencia de Trenes y Transporte\nPúblico Integrada',
                style: pw.TextStyle(fontSize: 8, color: _textGray),
              ),
            ],
          ),
        ],
      ),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('$year',
              style: pw.TextStyle(
                  fontSize: 16, fontWeight: pw.FontWeight.bold, color: _guinda)),
          pw.SizedBox(width: 4),
          pw.Text('año de\nMargarita\nMaza', style: pw.TextStyle(fontSize: 8, color: _textGray)),
        ],
      ),
    ],
  );
}

pw.Widget _buildMembreteFooter() {
  return pw.Column(
    mainAxisSize: pw.MainAxisSize.min,
    children: [
      pw.Divider(color: _borderGray, height: 6),
      pw.Text(
        'Avenida Universidad 1738, Colonia Santa Catarina, C.P. 04010, Alcaldía Coyoacán, Ciudad de México.',
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(fontSize: 8, color: _textGray),
      ),
      pw.SizedBox(height: 2),
      pw.Text(
        'Tel: (55) 5723 9300 | www.gob.mx/attrapi',
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(fontSize: 8, color: _textGray),
      ),
    ],
  );
}

pw.Widget _buildTitleRow(ReportActivityItem item, DateTime activityDate) {
  final dateFmt = DateFormat("d 'de' MMMM, y", 'es_MX');
  return pw.Container(
    decoration: pw.BoxDecoration(
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
        pw.Text(dateFmt.format(activityDate), style: pw.TextStyle(fontSize: 9, color: _textDark)),
      ],
    ),
  );
}

pw.Widget _buildExecutiveHeader(
  ReportActivityItem item,
  DateTime activityDate,
) {
  final dateFmt = DateFormat('dd/MM/yyyy HH:mm', 'es_MX');

  return pw.Container(
    padding: const pw.EdgeInsets.all(8),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: _borderGray),
      color: const PdfColor.fromInt(0xFFF8FAFC),
    ),
    child: pw.Column(
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Resumen Ejecutivo',
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: _guinda,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    '${item.activityType} · ${item.subcategory ?? 'Sin subcategoría'}',
                    style: pw.TextStyle(fontSize: 8.5, color: _textDark),
                  ),
                  pw.Text(
                    '${item.projectId ?? '-'} / ${item.frontName} · ${item.municipality ?? '-'}, ${item.state ?? '-'}',
                    style: pw.TextStyle(fontSize: 8.5, color: _textGray),
                  ),
                  pw.Text(
                    'Ventana: ${_formatTimeRange(item.startTime, item.endTime)} · Registro: ${dateFmt.format(activityDate)}',
                    style: pw.TextStyle(fontSize: 8, color: _textGray),
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        _kvText('Resultado', (item.result ?? item.statusLabel).trim()),
        if (item.isUnplanned)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 5),
            child: pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.Text(
                'No planeada: ${item.unplannedReason?.trim().isNotEmpty == true ? item.unplannedReason : 'Sin motivo capturado'}',
                style: pw.TextStyle(fontSize: 8, color: _textDark),
              ),
            ),
          ),
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
        pw.Text(label.toUpperCase(), style: pw.TextStyle(fontSize: 7, color: _textGray)),
        pw.SizedBox(height: 2),
        pw.Text(value, style: pw.TextStyle(fontSize: 9, color: _textDark, fontWeight: pw.FontWeight.bold)),
      ],
    ),
  );
}

pw.Widget _buildSectionTitle(String title) {
  return pw.Container(
    width: double.infinity,
    decoration: pw.BoxDecoration(
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
  final notes = item.notes?.trim().isNotEmpty == true ? item.notes!.trim() : text;

  return pw.Container(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _kvText('Propósito', purpose),
        _kvText('Temas tratados', topics),
        _kvText('Resultado final', result),
        _kvText('Minuta / notas', notes),
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
        pw.Text('Acuerdos / Pendientes',
            style: pw.TextStyle(fontSize: 9, color: _guinda, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        ...rows.map((row) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('• ', style: pw.TextStyle(fontSize: 9, color: _textDark)),
                  pw.Expanded(
                    child: pw.Text(row, style: pw.TextStyle(fontSize: 9, color: _textDark)),
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
          'SICT Vinculación - ${item.assignedName ?? 'Por definir'}',
          'ATTRAPI - Representante operativo',
        ];
  return pw.Wrap(
    spacing: 12,
    runSpacing: 6,
    children: authorityRows
        .map((row) => pw.Container(
              width: 220,
              padding: const pw.EdgeInsets.only(left: 6),
              decoration: pw.BoxDecoration(
                border: pw.Border(left: pw.BorderSide(color: _borderGray, width: 2)),
              ),
              child: pw.Text(row, style: pw.TextStyle(fontSize: 8.5, color: _textDark)),
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
          style: pw.TextStyle(fontSize: 9, color: _textGray)),
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
                      style: pw.TextStyle(fontSize: 9, color: _textGray)),
                )
              : pw.Image(evidence.image!, fit: pw.BoxFit.cover),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          evidence.evidence.caption?.trim().isNotEmpty == true
              ? evidence.evidence.caption!
              : 'Evidencia ${evidence.evidence.id}',
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
      style: pw.TextStyle(fontSize: 8.2, color: _textDark),
    ),
  );
}

pw.Widget _kvText(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 4),
    child: pw.RichText(
      text: pw.TextSpan(
        style: pw.TextStyle(fontSize: 8.6, color: _textDark, lineSpacing: 2),
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

String _buildCadenamiento(ReportActivityItem item) {
  final type = item.locationType?.trim().toLowerCase() ?? '';
  if (type == 'tramo') {
    final start = item.pkStart?.trim().isNotEmpty == true ? item.pkStart!.trim() : item.pk;
    final end = item.pkEnd?.trim().isNotEmpty == true ? item.pkEnd!.trim() : 'N/D';
    return '$start - $end';
  }
  if (type == 'general') {
    return 'General';
  }
  return item.pk.trim().isNotEmpty ? item.pk : (item.pkStart ?? 'N/D');
}

String _formatTimeRange(String? start, String? end) {
  final s = start?.trim();
  final e = end?.trim();
  if ((s ?? '').isEmpty && (e ?? '').isEmpty) return 'N/D';
  return '${s?.isNotEmpty == true ? s : 'N/D'} - ${e?.isNotEmpty == true ? e : 'N/D'}';
}

String _normalizeRisk(String? raw) {
  final risk = raw?.trim().toLowerCase() ?? '';
  if (risk == 'prioritario') return 'prioritario';
  if (risk == 'alto') return 'alto';
  if (risk == 'medio') return 'medio';
  if (risk == 'bajo') return 'bajo';
  return 'sin dato';
}

pw.Widget _buildRiskBadge(String risk) {
  final color = switch (risk) {
    'prioritario' => const PdfColor.fromInt(0xFFB42318),
    'alto' => const PdfColor.fromInt(0xFFE11D48),
    'medio' => const PdfColor.fromInt(0xFFF59E0B),
    'bajo' => const PdfColor.fromInt(0xFF16A34A),
    _ => _textGray,
  };

  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: pw.BoxDecoration(
      color: color,
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
    ),
    child: pw.Text(
      'Riesgo: ${risk.toUpperCase()}',
      style: pw.TextStyle(fontSize: 7.2, color: PdfColors.white, fontWeight: pw.FontWeight.bold),
    ),
  );
}

final _evidenceRepository = EvidenceRepository();
final Map<String, Future<String?>> _evidenceSourceCache = {};

Future<String?> _resolveEvidenceSource(ReportEvidenceItem evidence) {
  final rawPath = evidence.filePath.trim();
  final cacheKey = '${evidence.id}|$rawPath';

  return _evidenceSourceCache.putIfAbsent(cacheKey, () async {
    if (rawPath.isEmpty) {
      return null;
    }

    if (rawPath.startsWith('http://') ||
        rawPath.startsWith('https://') ||
        rawPath.startsWith('file://')) {
      return rawPath;
    }

    final localFile = File(rawPath);
    if (await localFile.exists()) {
      return localFile.path;
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
      final bytes = await file.readAsBytes();
      return pw.MemoryImage(bytes);
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

bool _isApprovedStatus(String status) {
  final normalized = status.toUpperCase();
  return normalized == 'APROBADO' || normalized == 'APPROVED';
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
    return _findInMap(nested, candidates);
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
    return value.values
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
        .map((e) => e.toString().trim())
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
